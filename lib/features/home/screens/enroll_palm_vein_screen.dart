import 'dart:convert';
import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const String _amenPayApiBaseUrl = String.fromEnvironment(
  'AMENPAY_API_BASE_URL',
  defaultValue: 'https://amenpay.org',
);

class EnrollPalmVeinScreen extends StatefulWidget {
  const EnrollPalmVeinScreen({super.key});

  @override
  State<EnrollPalmVeinScreen> createState() => _EnrollPalmVeinScreenState();
}

class _EnrollPalmVeinScreenState extends State<EnrollPalmVeinScreen> {
  int _step = 1;

  final _qrDataController = TextEditingController();
  final _hidQrBufferController = TextEditingController();
  final _hidQrFocusNode = FocusNode();
  Timer? _hidFinalizeTimer;
  final _deviceIdController = TextEditingController(text: 'POS-001');
  final _deviceApiKeyController = TextEditingController();

  StreamSubscription<Map<String, dynamic>>? _qrSubscription;
  bool _manualMode = false;

  bool _busy = false;
  String? _errorText;
  final List<String> _logLines = <String>[];
  String? _pendingSnackMessage;
  bool _pendingSnackIsError = false;

  String? _sessionId;
  Map<String, dynamic>? _claimResponse;
  Map<String, dynamic>? _submitResponse;
  String? _lastAutoClaimQr;
  DateTime? _lastAutoClaimAt;

  bool get _effectiveManualMode => kDebugMode && _manualMode;

  String _userFacingError(Object error) {
    final raw = error.toString().trim();
    if (raw.isEmpty) return 'Unknown error';
    final firstLine = raw.split('\n').first.trim();
    if (firstLine.length <= 180) return firstLine;
    return '${firstLine.substring(0, 180)}...';
  }

  void _showSnackBar(String message, {required bool isError}) {
    if (!mounted) {
      _pendingSnackMessage = message;
      _pendingSnackIsError = isError;
      return;
    }

    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) {
      _pendingSnackMessage = message;
      _pendingSnackIsError = isError;
      return;
    }

    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError
            ? const Color(0xFFB91C1C)
            : const Color(0xFF065F46),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _copyLogs() async {
    try {
      if (Platform.isAndroid) {
        final diag = await _PalmHardware.getQrNativeDiagnostics();
        _log(
          'Native QR diagnostics',
          _redactMap(Map<String, Object?>.from(diag)),
        );
      }
    } catch (e) {
      _log('Native QR diagnostics failed', <String, Object?>{
        'error': e.toString(),
      });
    }

    if (_logLines.isEmpty) {
      _log('Logs export requested', <String, Object?>{'has_logs': false});
    }
    await Clipboard.setData(ClipboardData(text: _logLines.join('\n')));
    _showSnackBar('Logs copied to clipboard', isError: false);
  }

  void _log(String message, [Map<String, Object?>? data]) {
    final now = DateTime.now().toIso8601String();
    final suffix = data == null
        ? ''
        : ' ${const JsonEncoder.withIndent('  ').convert(data)}';
    debugPrint('[$now] [PalmEnroll] $message$suffix');

    final line = '[$now] $message${data == null ? '' : ' ${jsonEncode(data)}'}';
    _logLines.add(line);
    if (_logLines.length > 250) {
      _logLines.removeRange(0, _logLines.length - 250);
    }
  }

  String _redactText(String value, {int head = 6, int tail = 4}) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return '';
    if (trimmed.length <= head + tail) return '*' * trimmed.length;
    return '${trimmed.substring(0, head)}...${trimmed.substring(trimmed.length - tail)}';
  }

  Map<String, Object?> _redactMap(Map<String, Object?> input) {
    bool shouldRedactKey(String key) {
      final k = key.toLowerCase();
      return k.contains('api') && k.contains('key') ||
          k == 'authorization' ||
          k == 'token' ||
          k == 'qr_data' ||
          k == 'template_id' ||
          k == 'templateid' ||
          k == 'sig' ||
          k.contains('secret');
    }

    Object? redactValue(String key, Object? value) {
      if (!shouldRedactKey(key)) {
        if (value is Map) {
          return _redactMap(Map<String, Object?>.from(value));
        }
        return value;
      }
      if (value == null) return null;
      if (value is String) return _redactText(value);
      return '***';
    }

    final out = <String, Object?>{};
    for (final e in input.entries) {
      out[e.key] = redactValue(e.key, e.value);
    }
    return out;
  }

  @override
  void initState() {
    super.initState();
    _initHardware();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ensureHidQrFocus();
    });
  }

  @override
  void dispose() {
    _qrSubscription?.cancel();
    _hidFinalizeTimer?.cancel();
    _qrDataController.dispose();
    _hidQrBufferController.dispose();
    _hidQrFocusNode.dispose();
    _deviceIdController.dispose();
    _deviceApiKeyController.dispose();
    super.dispose();
  }

  void _finalizeHidPayload(String raw, {int? cutIndex}) {
    if (!mounted) return;
    if (_effectiveManualMode) return;
    if (_step != 1) return;

    final end = (cutIndex == null || cutIndex < 0 || cutIndex > raw.length)
        ? raw.length
        : cutIndex;
    final value = raw.substring(0, end).trim();

    _hidFinalizeTimer?.cancel();
    _hidFinalizeTimer = null;
    _hidQrBufferController.clear();
    _ensureHidQrFocus();
    if (value.isEmpty) return;

    setState(() {
      _qrDataController.text = value;
    });
    _log('QR payload received (hid)', <String, Object?>{
      'qr_data': _redactText(value),
    });
    _maybeAutoClaim(value);
  }

  void _ensureHidQrFocus() {
    if (!mounted) return;
    if (!Platform.isAndroid) return;
    if (_effectiveManualMode) return;
    if (_step != 1) return;
    if (_hidQrFocusNode.hasFocus) return;
    FocusScope.of(context).requestFocus(_hidQrFocusNode);
  }

  void _onHidQrBufferChanged(String raw) {
    if (!mounted) return;
    if (_effectiveManualMode) return;
    if (_step != 1) return;

    _hidFinalizeTimer?.cancel();

    if (raw.length > 2048) {
      _hidQrBufferController.clear();
      return;
    }

    final terminatorIndex = raw.indexOf(RegExp(r'[\r\n\t]'));
    if (terminatorIndex >= 0) {
      _finalizeHidPayload(raw, cutIndex: terminatorIndex);
      return;
    }

    if (raw.trim().isEmpty) return;

    _hidFinalizeTimer = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      if (_effectiveManualMode) return;
      if (_step != 1) return;
      final current = _hidQrBufferController.text;
      if (current.trim().isEmpty) return;
      _finalizeHidPayload(current);
    });
  }

  Future<void> _initHardware() async {
    try {
      final deviceId = await _PalmHardware.getDeviceId();
      if (mounted && deviceId != null && deviceId.trim().isNotEmpty) {
        setState(() {
          _deviceIdController.text = deviceId.trim();
        });
        _log('Device id loaded', <String, Object?>{
          'device_id': deviceId.trim(),
        });
      }
    } catch (e) {
      _log('Device id load failed', <String, Object?>{'error': e.toString()});
      _showSnackBar('Hardware device id unavailable', isError: true);
    }

    try {
      final apiKey = await _PalmHardware.getDeviceApiKey();
      if (mounted && apiKey != null && apiKey.trim().isNotEmpty) {
        setState(() {
          _deviceApiKeyController.text = apiKey.trim();
        });
        _log('Device api key loaded', <String, Object?>{
          'device_api_key': _redactText(apiKey),
        });
      }
    } catch (e) {
      _log('Device api key load failed', <String, Object?>{
        'error': e.toString(),
      });
      _showSnackBar('Hardware device API key unavailable', isError: true);
    }

    try {
      if (Platform.isAndroid) {
        final currentPath = await _PalmHardware.getQrDevicePath();
        final candidates = await _PalmHardware.listQrDeviceCandidates();
        _log('QR device diagnostics', <String, Object?>{
          'qr_device_path': currentPath ?? '',
          'qr_device_candidates': candidates,
        });

        final currentInfo = candidates.isEmpty ? null : candidates.first;
        final currentExists = currentInfo?['exists'] == true;
        final currentReadable = currentInfo?['can_read'] == true;
        if (!currentExists || !currentReadable) {
          final fallback = candidates
              .skip(1)
              .cast<Map<String, dynamic>>()
              .firstWhere(
                (e) => e['exists'] == true && e['can_read'] == true,
                orElse: () => const <String, dynamic>{},
              );
          final nextPath = fallback['path']?.toString().trim() ?? '';
          if (nextPath.isNotEmpty) {
            await _PalmHardware.setQrDevicePath(nextPath);
            _log('QR device path updated', <String, Object?>{
              'qr_device_path': nextPath,
            });
          }
        }
      }
    } catch (e) {
      _log('QR device diagnostics failed', <String, Object?>{
        'error': e.toString(),
      });
    }

    try {
      _qrSubscription = _PalmHardware.qrEvents().listen(
        (event) {
          final payload = event['payload']?.toString() ?? '';
          final source = event['source']?.toString() ?? '';
          final action = event['action']?.toString();
          final devicePath = event['device_path']?.toString();
          final extraKey = event['extra_key']?.toString();

          final value = payload.trim();
          if (!mounted || value.isEmpty) return;
          setState(() {
            _qrDataController.text = value;
          });
          _log('QR payload received', <String, Object?>{
            'qr_data': _redactText(value),
            if (source.isNotEmpty) 'source': source,
            if (action != null && action.isNotEmpty) 'action': action,
            if (devicePath != null && devicePath.isNotEmpty)
              'device_path': devicePath,
            if (extraKey != null && extraKey.isNotEmpty) 'extra_key': extraKey,
          });
          _maybeAutoClaim(value);
        },
        onError: (Object error, StackTrace stackTrace) {
          if (!mounted) return;
          setState(() {
            _errorText = error.toString();
            if (kDebugMode) {
              _manualMode = true;
            }
          });
          _log('QR stream error', <String, Object?>{'error': error.toString()});
          _showSnackBar(
            'QR scanner error: ${_userFacingError(error)}',
            isError: true,
          );
        },
      );
    } catch (e) {
      _log('QR stream subscribe failed', <String, Object?>{
        'error': e.toString(),
      });
      if (mounted) {
        setState(() {
          if (kDebugMode) {
            _manualMode = true;
          }
        });
      }
      _showSnackBar('QR scanner unavailable', isError: true);
    }
  }

  void _maybeAutoClaim(String qrData) {
    if (_effectiveManualMode) return;
    if (_busy) return;
    if (_step != 1) return;

    final deviceId = _deviceIdController.text.trim();
    final deviceApiKey = _deviceApiKeyController.text.trim();
    if (deviceId.isEmpty || deviceApiKey.isEmpty) return;

    final now = DateTime.now();
    final lastQr = _lastAutoClaimQr;
    final lastAt = _lastAutoClaimAt;
    if (lastQr == qrData &&
        lastAt != null &&
        now.difference(lastAt).inSeconds < 5) {
      return;
    }

    _lastAutoClaimQr = qrData;
    _lastAutoClaimAt = now;

    _log('Auto-claim triggered', <String, Object?>{
      'device_id': deviceId,
      'qr_data': _redactText(qrData),
    });
    unawaited(_claimSession());
  }

  Future<Map<String, dynamic>> _postJson({
    required Uri uri,
    required Map<String, String> headers,
    required Map<String, dynamic> body,
  }) async {
    _log(
      'HTTP POST',
      _redactMap(<String, Object?>{
        'url': uri.toString(),
        'headers': headers,
        'body': body,
      }),
    );
    final client = HttpClient();
    try {
      final request = await client.postUrl(uri);
      headers.forEach(request.headers.set);
      request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      request.add(utf8.encode(jsonEncode(body)));
      final response = await request.close();
      final raw = await response.transform(utf8.decoder).join();
      final contentType = response.headers.contentType?.mimeType;
      _log('HTTP response', <String, Object?>{
        'url': uri.toString(),
        'status_code': response.statusCode,
        'content_type': contentType,
        'raw_len': raw.length,
        'raw': raw.length > 1200 ? '${raw.substring(0, 1200)}...' : raw,
      });
      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (raw.isEmpty) return <String, dynamic>{};
        if (contentType == 'application/json') {
          final decoded = jsonDecode(raw);
          if (decoded is Map<String, dynamic>) {
            _log(
              'HTTP json decoded',
              _redactMap(decoded.map((k, v) => MapEntry(k, v as Object?))),
            );
            return decoded;
          }
          return <String, dynamic>{'data': decoded};
        }
        return <String, dynamic>{'raw': raw};
      }

      if (raw.isNotEmpty && contentType == 'application/json') {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          final pretty = const JsonEncoder.withIndent('  ').convert(decoded);
          throw HttpException(
            '${response.statusCode} ${response.reasonPhrase}\n$pretty'.trim(),
            uri: uri,
          );
        }
      }

      throw HttpException(
        raw.isEmpty
            ? '${response.statusCode} ${response.reasonPhrase}'.trim()
            : '${response.statusCode} ${response.reasonPhrase}\n$raw'.trim(),
        uri: uri,
      );
    } finally {
      client.close(force: true);
    }
  }

  Future<void> _scanQrOnce() async {
    setState(() {
      _busy = true;
      _errorText = null;
    });

    try {
      _log('scanQrOnce started');
      final qr = await _PalmHardware.scanQrOnce(timeoutMs: 15000);
      final value = qr?.trim();
      if (value == null || value.isEmpty) {
        if (mounted) {
          setState(() {
            _errorText = 'No QR payload received from hardware.';
          });
        }
        _log('scanQrOnce empty');
        _showSnackBar('No QR payload received', isError: true);
        return;
      }
      if (!mounted) return;
      setState(() {
        _qrDataController.text = value;
      });
      _log('scanQrOnce received', <String, Object?>{
        'qr_data': _redactText(value),
      });
      final shouldAutoClaim =
          !_effectiveManualMode &&
          _step == 1 &&
          _deviceIdController.text.trim().isNotEmpty &&
          _deviceApiKeyController.text.trim().isNotEmpty;
      if (shouldAutoClaim) {
        await _claimSession();
      }
    } on PlatformException catch (e) {
      if (mounted) {
        setState(() {
          _errorText = e.message ?? e.code;
          if (kDebugMode) {
            _manualMode = true;
          }
        });
      }
      _log('scanQrOnce platform error', <String, Object?>{
        'code': e.code,
        'message': e.message,
      });
      _showSnackBar('${e.code}: ${e.message ?? ''}'.trim(), isError: true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorText = e.toString();
          if (kDebugMode) {
            _manualMode = true;
          }
        });
      }
      _log('scanQrOnce error', <String, Object?>{'error': e.toString()});
      _showSnackBar(_userFacingError(e), isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> _claimSession() async {
    final qrData = _qrDataController.text.trim();
    final deviceId = _deviceIdController.text.trim();
    final deviceApiKey = _deviceApiKeyController.text.trim();

    if (qrData.isEmpty || deviceId.isEmpty || deviceApiKey.isEmpty) {
      setState(() {
        _errorText = 'QR data, Device ID, and Device API key are required.';
      });
      _log('Claim blocked: missing fields', <String, Object?>{
        'has_qr': qrData.isNotEmpty,
        'has_device_id': deviceId.isNotEmpty,
        'has_device_api_key': deviceApiKey.isNotEmpty,
      });
      return;
    }

    setState(() {
      _busy = true;
      _errorText = null;
    });

    try {
      try {
        await _PalmHardware.setDeviceApiKey(deviceApiKey);
      } catch (_) {}
      _log('Claim session start', <String, Object?>{
        'device_id': deviceId,
        'qr_data': _redactText(qrData),
        'device_api_key': _redactText(deviceApiKey),
      });
      final res = await _postJson(
        uri: Uri.parse('$_amenPayApiBaseUrl/api/palm/enroll/sessions/claim'),
        headers: <String, String>{'X-Device-API-Key': deviceApiKey},
        body: <String, dynamic>{'qr_data': qrData, 'device_id': deviceId},
      );

      final sessionId = (res['sessionId'] ?? res['session_id'] ?? res['id'])
          ?.toString();

      setState(() {
        _claimResponse = res;
        _sessionId = sessionId;
        _step = 2;
      });
      _log(
        'Claim session success',
        _redactMap(<String, Object?>{'session_id': sessionId, 'response': res}),
      );
      _showSnackBar('Session claimed successfully', isError: false);
    } catch (e) {
      setState(() {
        _errorText = e.toString();
      });
      _log('Claim session failed', <String, Object?>{'error': e.toString()});
      _showSnackBar(_userFacingError(e), isError: true);
    } finally {
      setState(() {
        _busy = false;
      });
    }
  }

  Future<void> _startEnrollmentAndSubmit() async {
    final sessionId = _sessionId?.trim();
    final deviceId = _deviceIdController.text.trim();
    final deviceApiKey = _deviceApiKeyController.text.trim();

    if (sessionId == null || sessionId.isEmpty) {
      setState(() {
        _errorText = 'Missing session id. Claim session first.';
      });
      return;
    }

    if (deviceId.isEmpty || deviceApiKey.isEmpty) {
      setState(() {
        _errorText = 'Device ID and Device API key are required.';
      });
      return;
    }

    setState(() {
      _busy = true;
      _errorText = null;
    });

    try {
      _log('Palm enrollment start', <String, Object?>{
        'session_id': sessionId,
        'device_id': deviceId,
      });
      final enrollment = await _PalmHardware.startPalmEnrollment();
      _log(
        'Palm enrollment result',
        _redactMap(enrollment.map((k, v) => MapEntry(k, v as Object?))),
      );

      final templateId = (enrollment['template_id'] ?? enrollment['templateId'])
          ?.toString();

      final errorCode = (enrollment['error_code'] ?? enrollment['errorCode'])
          ?.toString();

      final errorMessage =
          (enrollment['error_message'] ?? enrollment['errorMessage'])
              ?.toString();

      final body = <String, dynamic>{'device_id': deviceId};
      if (templateId != null && templateId.trim().isNotEmpty) {
        body['result'] = 'success';
        body['template_id'] = templateId.trim();
        if (enrollment['quality_score'] is num) {
          body['quality_score'] = enrollment['quality_score'];
        }
        if (enrollment['liveness'] != null) {
          body['liveness'] = enrollment['liveness'];
        }
      } else {
        body['result'] = 'failed';
        if (errorCode != null && errorCode.trim().isNotEmpty) {
          body['error_code'] = errorCode.trim();
        }
        if (errorMessage != null && errorMessage.trim().isNotEmpty) {
          body['error_message'] = errorMessage.trim();
        }
      }

      _log(
        'Submit result start',
        _redactMap(<String, Object?>{
          'session_id': sessionId,
          'device_id': deviceId,
          'device_api_key': _redactText(deviceApiKey),
          'body': body,
        }),
      );
      final res = await _postJson(
        uri: Uri.parse(
          '$_amenPayApiBaseUrl/api/palm/enroll/sessions/$sessionId/submit-result',
        ),
        headers: <String, String>{'X-Device-API-Key': deviceApiKey},
        body: body,
      );

      setState(() {
        _submitResponse = res;
        _step = 3;
      });
      _log(
        'Submit result success',
        _redactMap(<String, Object?>{'response': res}),
      );
      _showSnackBar('Enrollment submitted successfully', isError: false);
    } on PlatformException catch (e) {
      setState(() {
        _errorText = e.message ?? e.code;
        if (kDebugMode) {
          _manualMode = true;
        }
      });
      _log('Enrollment/submit platform error', <String, Object?>{
        'code': e.code,
        'message': e.message,
      });
      _showSnackBar('${e.code}: ${e.message ?? ''}'.trim(), isError: true);
    } catch (e) {
      setState(() {
        _errorText = e.toString();
        if (kDebugMode) {
          _manualMode = true;
        }
      });
      _log('Enrollment/submit error', <String, Object?>{'error': e.toString()});
      _showSnackBar(_userFacingError(e), isError: true);
    } finally {
      setState(() {
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final pendingSnack = _pendingSnackMessage;
    if (pendingSnack != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final msg = _pendingSnackMessage;
        if (msg == null) return;
        final isError = _pendingSnackIsError;
        _pendingSnackMessage = null;
        _pendingSnackIsError = false;
        _showSnackBar(msg, isError: isError);
      });
    }

    if (Platform.isAndroid && !_effectiveManualMode && _step == 1) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _ensureHidQrFocus();
      });
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: SizedBox(
            width: 17,
            height: 15,
            child: FittedBox(
              fit: BoxFit.contain,
              child: Icon(
                Icons.arrow_back,
                color: const Color(0xFF333333),
                textDirection: Directionality.of(context),
              ),
            ),
          ),
        ),
        title: Text('Enroll PalmVein'),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: _logLines.isEmpty ? null : _copyLogs,
            icon: const Icon(Icons.copy_all, color: Color(0xFF333333)),
            tooltip: 'Copy logs',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(24, 24, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (Platform.isAndroid && !_effectiveManualMode && _step == 1)
              SizedBox(
                width: 1,
                height: 1,
                child: TextField(
                  focusNode: _hidQrFocusNode,
                  controller: _hidQrBufferController,
                  autofocus: true,
                  autocorrect: false,
                  enableSuggestions: false,
                  showCursor: false,
                  keyboardType: TextInputType.visiblePassword,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    isCollapsed: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  onChanged: _onHidQrBufferChanged,
                  onTap: _ensureHidQrFocus,
                ),
              ),
            _StepIndicator(step: _step),
            if (_errorText != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFECACA)),
                ),
                child: Text(
                  _errorText!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF991B1B),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),
            Expanded(
              child: _step == 1
                  ? _StepOne(
                      busy: _busy,
                      qrDataController: _qrDataController,
                      deviceIdController: _deviceIdController,
                      deviceApiKeyController: _deviceApiKeyController,
                      manualMode: _effectiveManualMode,
                      onRequestScannerFocus: _ensureHidQrFocus,
                      onToggleManualMode: () {
                        if (!kDebugMode) return;
                        setState(() {
                          _manualMode = !_manualMode;
                        });
                      },
                      onScanQr: _scanQrOnce,
                      onClaim: _claimSession,
                    )
                  : _step == 2
                  ? _StepTwo(
                      busy: _busy,
                      sessionId: _sessionId,
                      onStartEnrollment: _startEnrollmentAndSubmit,
                    )
                  : _StepThree(
                      onDone: () {
                        Navigator.of(context).pop();
                      },
                      claimResponse: _claimResponse,
                      submitResponse: _submitResponse,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepIndicator extends StatelessWidget {
  final int step;

  const _StepIndicator({required this.step});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            _StepCircle(number: 1, active: step >= 1, current: step == 1),
            Expanded(
              child: Container(
                height: 4,
                color: step >= 2
                    ? const Color(0xFF238EC2)
                    : const Color(0xFFE5E7EB),
              ),
            ),
            _StepCircle(number: 2, active: step >= 2, current: step == 2),
            Expanded(
              child: Container(
                height: 4,
                color: step >= 3
                    ? const Color(0xFF238EC2)
                    : const Color(0xFFE5E7EB),
              ),
            ),
            _StepCircle(number: 3, active: step >= 3, current: step == 3),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const _StepLabel(label: 'QR Code'),
            const _StepLabel(label: 'Scanning'),
            const _StepLabel(label: 'Complete'),
          ],
        ),
      ],
    );
  }
}

class _StepLabel extends StatelessWidget {
  final String label;

  const _StepLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        height: 16 / 12,
        letterSpacing: -0.5,
        color: const Color(0xFF4B5563),
      ),
    );
  }
}

class _StepCircle extends StatelessWidget {
  final int number;
  final bool active;
  final bool current;

  const _StepCircle({
    required this.number,
    required this.active,
    required this.current,
  });

  @override
  Widget build(BuildContext context) {
    final bg = current
        ? const Color(0xFF238EC2)
        : active
        ? const Color(0xFFEFF6FF)
        : const Color(0xFFF3F4F6);

    final fg = current
        ? Colors.white
        : active
        ? const Color(0xFF238EC2)
        : const Color(0xFF9CA3AF);

    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
      child: Center(
        child: Text(
          number.toString(),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: fg,
          ),
        ),
      ),
    );
  }
}

class _StepOne extends StatelessWidget {
  final bool busy;
  final TextEditingController qrDataController;
  final TextEditingController deviceIdController;
  final TextEditingController deviceApiKeyController;
  final Future<void> Function() onClaim;
  final bool manualMode;
  final VoidCallback onToggleManualMode;
  final Future<void> Function() onScanQr;
  final VoidCallback onRequestScannerFocus;

  const _StepOne({
    required this.busy,
    required this.qrDataController,
    required this.deviceIdController,
    required this.deviceApiKeyController,
    required this.onClaim,
    required this.manualMode,
    required this.onToggleManualMode,
    required this.onScanQr,
    required this.onRequestScannerFocus,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
            ),
            padding: const EdgeInsets.all(24),
            child: Center(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      height: 220,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFF238EC2),
                          width: 2,
                        ),
                        color: const Color(0xFFEFF6FF),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.qr_code,
                          size: 120,
                          color: Color(0xFF238EC2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Scan the QR code from the POS enrollment portal to begin.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        height: 23 / 14,
                        letterSpacing: -0.5,
                        color: const Color(0xFF333333),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    if (!manualMode) ...[
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: busy ? null : onScanQr,
                          icon: const Icon(Icons.qr_code_scanner),
                          label: const Text('Scan Enrollment QR'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      InkWell(
                        onTap: busy ? null : onRequestScannerFocus,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF3F4F6),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            qrDataController.text.trim().isEmpty
                                ? 'Waiting for QR payload... (tap to focus scanner)'
                                : qrDataController.text.trim(),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          deviceIdController.text.trim().isEmpty
                              ? 'Device ID not loaded'
                              : 'Device ID: ${deviceIdController.text.trim()}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          deviceApiKeyController.text.trim().isEmpty
                              ? 'Device API key not loaded'
                              : 'Device API key loaded',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                      if (kDebugMode) ...[
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: TextButton(
                            onPressed: busy ? null : onToggleManualMode,
                            child: const Text('Enter manually'),
                          ),
                        ),
                      ],
                    ] else ...[
                      TextFormField(
                        controller: qrDataController,
                        minLines: 2,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          hintText: 'Paste qr_data (PALMENROLL:...)',
                          prefixIcon: Icon(Icons.qr_code_2),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: deviceIdController,
                        decoration: const InputDecoration(
                          hintText: 'Device ID (e.g., POS-001)',
                          prefixIcon: Icon(Icons.devices),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: deviceApiKeyController,
                        decoration: const InputDecoration(
                          hintText: 'Device API Key',
                          prefixIcon: Icon(Icons.vpn_key),
                        ),
                        obscureText: true,
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: TextButton(
                          onPressed: busy ? null : onToggleManualMode,
                          child: const Text('Use hardware'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          height: 56,
          child: ElevatedButton(
            onPressed: busy ? null : onClaim,
            child: busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Claim Enrollment Session'),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.shield, color: Color(0xFF238EC2), size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Your biometric data is securely processed for POS authentication.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  height: 16 / 12,
                  letterSpacing: -0.5,
                  color: const Color(0xFF4B5563),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _StepTwo extends StatelessWidget {
  final bool busy;
  final String? sessionId;
  final Future<void> Function() onStartEnrollment;

  const _StepTwo({
    required this.busy,
    required this.sessionId,
    required this.onStartEnrollment,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Step 2 of 3',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            height: 20 / 14,
            letterSpacing: -0.5,
            color: const Color(0xFF238EC2),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Container(
                height: 6,
                decoration: BoxDecoration(
                  color: const Color(0xFF00AA44),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Container(
                height: 6,
                decoration: BoxDecoration(
                  color: const Color(0xFF238EC2),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Container(
                height: 6,
                decoration: BoxDecoration(
                  color: const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x1A000000),
                  offset: Offset(0, 10),
                  blurRadius: 15,
                ),
              ],
            ),
            padding: const EdgeInsets.all(24),
            child: Center(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 120,
                      height: 120,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFF312E81),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.pan_tool,
                          color: Colors.white,
                          size: 56,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Place your palm',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        height: 28 / 18,
                        letterSpacing: -0.5,
                        color: const Color(0xFF333333),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Align your palm over the scanner and hold steady until completed.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        height: 23 / 14,
                        letterSpacing: -0.5,
                        color: const Color(0xFF4B5563),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 18),
                    if (sessionId != null && sessionId!.isNotEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Session: $sessionId',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Scanning progress',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w400,
                                  height: 16 / 12,
                                  letterSpacing: -0.5,
                                  color: const Color(0xFF4B5563),
                                ),
                          ),
                        ),
                        Text(
                          '75%',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                height: 16 / 12,
                                letterSpacing: -0.5,
                                color: const Color(0xFF4B5563),
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: 0.75,
                        minHeight: 8,
                        backgroundColor: const Color(0xFFE5E7EB),
                        valueColor: const AlwaysStoppedAnimation(
                          Color(0xFF00AA44),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Center(
                        child: Text(
                          'Keep your hand steady',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            letterSpacing: -0.5,
                            color: Color(0xFF238EC2),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: busy ? null : onStartEnrollment,
                        icon: const Icon(Icons.pan_tool_alt_outlined),
                        label: const Text('Start Palm Enrollment'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          height: 56,
          child: ElevatedButton(
            onPressed: null,
            child: busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Awaiting enrollment'),
          ),
        ),
      ],
    );
  }
}

class _PalmHardware {
  static const MethodChannel _posDeviceMethods = MethodChannel(
    'posDevice/methods',
  );
  static const MethodChannel _qrScannerMethods = MethodChannel(
    'qrScanner/methods',
  );
  static const EventChannel _qrScannerEvents = EventChannel('qrScanner/events');
  static const MethodChannel _palmEnrollmentMethods = MethodChannel(
    'palmEnrollment/methods',
  );

  static Future<String?> getDeviceId() async {
    final res = await _posDeviceMethods.invokeMethod<dynamic>('getDeviceId');
    return res?.toString();
  }

  static Future<String?> getDeviceApiKey() async {
    final res = await _posDeviceMethods.invokeMethod<dynamic>(
      'getDeviceApiKey',
    );
    return res?.toString();
  }

  static Future<void> setDeviceApiKey(String apiKey) async {
    await _posDeviceMethods.invokeMethod<dynamic>(
      'setDeviceApiKey',
      <String, dynamic>{'api_key': apiKey},
    );
  }

  static Stream<Map<String, dynamic>> qrEvents() {
    return _qrScannerEvents.receiveBroadcastStream().map((event) {
      if (event is Map) {
        return Map<String, dynamic>.from(event);
      }
      return <String, dynamic>{'payload': event.toString(), 'source': 'raw'};
    });
  }

  static Future<String?> getQrDevicePath() async {
    final res = await _qrScannerMethods.invokeMethod<dynamic>(
      'getQrDevicePath',
    );
    return res?.toString();
  }

  static Future<void> setQrDevicePath(String qrDevicePath) async {
    await _qrScannerMethods.invokeMethod<dynamic>(
      'setQrDevicePath',
      <String, dynamic>{'qr_device_path': qrDevicePath},
    );
  }

  static Future<List<Map<String, dynamic>>> listQrDeviceCandidates() async {
    final res = await _qrScannerMethods.invokeMethod<dynamic>(
      'listQrDeviceCandidates',
    );
    if (res is List) {
      return res
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList(growable: false);
    }
    return const <Map<String, dynamic>>[];
  }

  static Future<String?> scanQrOnce({required int timeoutMs}) async {
    final res = await _qrScannerMethods.invokeMethod<dynamic>(
      'scanQrOnce',
      <String, dynamic>{'timeout_ms': timeoutMs},
    );
    return res?.toString();
  }

  static Future<Map<String, dynamic>> getQrNativeDiagnostics() async {
    final res = await _qrScannerMethods.invokeMethod<dynamic>(
      'getQrNativeDiagnostics',
    );
    if (res is Map) {
      return Map<String, dynamic>.from(res);
    }
    return const <String, dynamic>{};
  }

  static Future<Map<String, dynamic>> startPalmEnrollment() async {
    final res = await _palmEnrollmentMethods.invokeMethod<dynamic>(
      'startEnrollment',
    );
    if (res is Map) {
      return Map<String, dynamic>.from(res);
    }
    throw PlatformException(
      code: 'INVALID_RESULT',
      message: 'Palm enrollment returned invalid payload.',
    );
  }
}

class _StepThree extends StatelessWidget {
  final VoidCallback onDone;
  final Map<String, dynamic>? claimResponse;
  final Map<String, dynamic>? submitResponse;

  const _StepThree({
    required this.onDone,
    required this.claimResponse,
    required this.submitResponse,
  });

  @override
  Widget build(BuildContext context) {
    final claimJson = claimResponse == null
        ? null
        : const JsonEncoder.withIndent('  ').convert(claimResponse);
    final submitJson = submitResponse == null
        ? null
        : const JsonEncoder.withIndent('  ').convert(submitResponse);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
            ),
            padding: const EdgeInsets.all(24),
            child: Center(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 96,
                      height: 96,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFF00AA44),
                      ),
                      child: const Icon(
                        Icons.check,
                        color: Colors.white,
                        size: 48,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Enrollment complete',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        height: 28 / 18,
                        letterSpacing: -0.5,
                        color: const Color(0xFF333333),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'PalmVein enrollment completed successfully for this cashier profile.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        height: 23 / 14,
                        letterSpacing: -0.5,
                        color: const Color(0xFF4B5563),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    if (claimJson != null || submitJson != null) ...[
                      const SizedBox(height: 20),
                      if (claimJson != null)
                        _JsonPanel(title: 'Claim Response', json: claimJson),
                      if (submitJson != null) ...[
                        const SizedBox(height: 12),
                        _JsonPanel(title: 'Submit Response', json: submitJson),
                      ],
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          height: 56,
          child: ElevatedButton(onPressed: onDone, child: const Text('Done')),
        ),
      ],
    );
  }
}

class _JsonPanel extends StatelessWidget {
  final String title;
  final String json;

  const _JsonPanel({required this.title, required this.json});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          Text(
            json,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(fontFamily: 'Menlo'),
          ),
        ],
      ),
    );
  }
}
