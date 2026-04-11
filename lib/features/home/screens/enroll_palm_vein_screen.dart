import 'dart:convert';
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:amenpay_cashir_app/services/palm_matcher_service.dart';
import 'package:amenpay_cashir_app/l10n/app_localizations.dart';

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
  Timer? _scannerStatusTimer;
  final _deviceIdController = TextEditingController(text: 'POS-001');

  StreamSubscription<Map<String, dynamic>>? _qrSubscription;

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
  String _scannerStatusLabel = 'Checking scanner status...';
  bool _scannerArmed = false;
  bool _scannerReceiving = false;
  String _scannerMode = 'unknown';
  bool _scannerHidRecent = false;
  bool _scannerSerialRecent = false;
  int _scannerSerialBytesTotal = 0;
  String _lastDecodedSource = '';
  String _lastDecodedPayloadRedacted = '';
  DateTime? _lastDecodedAt;
  String _stepTwoStatusTitle = '';
  String _stepTwoStatusMessage = '';
  Locale? _lastLocale;

  _PalmStepTwoStatus _stepTwoStatus = _PalmStepTwoStatus.placePalm;
  String? _stepTwoMessageOverride;

  String _userFacingError(Object error) {
    final raw = error.toString().trim();
    if (raw.isEmpty) return 'Unknown error';
    final firstLine = raw.split('\n').first.trim();
    if (firstLine.length <= 180) return firstLine;
    return '${firstLine.substring(0, 180)}...';
  }


  int? _tryParseInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  dynamic _deepRead(dynamic root, List<String> path) {
    dynamic current = root;
    for (final segment in path) {
      if (current is Map) {
        current = current[segment];
      } else {
        return null;
      }
    }
    return current;
  }

  Future<int?> _extractMatcherUserId() async {
    final response = _claimResponse;
    final candidates = <dynamic>[
      response?['user_id'],
      response?['userId'],
      response?['customer_id'],
      response?['customerId'],
      _deepRead(response, <String>['user', 'id']),
      _deepRead(response, <String>['customer', 'id']),
      _deepRead(response, <String>['data', 'user_id']),
      _deepRead(response, <String>['data', 'customer_id']),
      _deepRead(response, <String>['data', 'user', 'id']),
      _deepRead(response, <String>['data', 'customer', 'id']),
    ];
    for (final candidate in candidates) {
      final parsed = _tryParseInt(candidate);
      if (parsed != null) return parsed;
    }
    return null;
  }

  String _extractMatcherVoucher(String fallback) {
    final response = _claimResponse;
    final candidates = <dynamic>[
      response?['voucher'],
      response?['payment_method_id'],
      response?['paymentMethodId'],
      response?['card_id'],
      _deepRead(response, <String>['payment_method', 'id']),
      _deepRead(response, <String>['paymentMethod', 'id']),
      _deepRead(response, <String>['data', 'voucher']),
      _deepRead(response, <String>['data', 'payment_method_id']),
      _deepRead(response, <String>['data', 'payment_method', 'id']),
    ];
    for (final candidate in candidates) {
      final value = candidate?.toString().trim() ?? '';
      if (value.isNotEmpty) return value;
    }
    return fallback;
  }

  String _friendlyMatcherMessage(PalmMatcherException error) {
    switch (error.code) {
      case 'MATCHER_USER_ID_MISSING':
        return 'Enrollment session is missing the customer id required by the local matcher.';
      case 'MATCHER_KEY_MISSING':
        return 'Local palm matcher key is missing in this cashier app build.';
      case 'MATCHER_UNAVAILABLE':
        return 'Local palm matcher is unavailable. Ensure the matcher app is running on this POS device.';
      case 'MATCHER_NOT_READY':
        return error.message.isNotEmpty
            ? error.message
            : 'Local palm matcher startup sync is still in progress.';
      case 'MATCHER_ENROLL_FAILED':
        return error.message.isNotEmpty
            ? error.message
            : 'Local palm matcher could not enroll this palm.';
      default:
        return error.message.isNotEmpty
            ? error.message
            : 'Local palm matcher request failed.';
    }
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
    _startScannerStatusPolling();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ensureHidQrFocus();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final locale = Localizations.localeOf(context);
    if (_lastLocale == locale) return;
    _lastLocale = locale;
    _applyStepTwoStatusLocalization();
  }

  @override
  void dispose() {
    _qrSubscription?.cancel();
    _hidFinalizeTimer?.cancel();
    _scannerStatusTimer?.cancel();
    _qrDataController.dispose();
    _hidQrBufferController.dispose();
    _hidQrFocusNode.dispose();
    _deviceIdController.dispose();
    super.dispose();
  }

  void _finalizeHidPayload(String raw, {int? cutIndex}) {
    if (!mounted) return;
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
    if (_shouldIgnoreHidPayload(value)) return;

    setState(() {
      _qrDataController.text = value;
      _scannerReceiving = true;
      _scannerStatusLabel = 'Scanner input detected (HID).';
      _scannerMode = 'hid';
      _lastDecodedSource = 'hid';
      _lastDecodedPayloadRedacted = _redactText(value);
      _lastDecodedAt = DateTime.now();
    });
    _log('QR payload received (hid)', <String, Object?>{
      'qr_data': _redactText(value),
    });
    _maybeAutoClaim(value);
  }

  void _setStepTwoStatus(
    _PalmStepTwoStatus status, {
    String? messageOverride,
  }) {
    _stepTwoStatus = status;
    _stepTwoMessageOverride = messageOverride;
    _applyStepTwoStatusLocalization();
  }

  void _applyStepTwoStatusLocalization() {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    late final String title;
    late final String message;

    switch (_stepTwoStatus) {
      case _PalmStepTwoStatus.placePalm:
        title = l10n.placeYourPalm;
        message = l10n.placeYourPalmBody;
        break;
      case _PalmStepTwoStatus.scanning:
        title = l10n.scanningPalmVeinTitle;
        message = l10n.scanningPalmVeinBody;
        break;
      case _PalmStepTwoStatus.waitingMatcher:
        title = l10n.waitingForLocalMatcherTitle;
        message = l10n.waitingForLocalMatcherBody;
        break;
      case _PalmStepTwoStatus.submitting:
        title = l10n.submittingEnrollmentTitle;
        message = l10n.submittingEnrollmentBody;
        break;
      case _PalmStepTwoStatus.matcherUnavailable:
        title = l10n.matcherUnavailableTitle;
        message = _stepTwoMessageOverride ?? l10n.matcherUnavailableTitle;
        break;
      case _PalmStepTwoStatus.failed:
        title = l10n.enrollmentFailedTitle;
        message = _stepTwoMessageOverride ?? l10n.enrollmentFailedTitle;
        break;
    }

    if (!mounted) return;
    setState(() {
      _stepTwoStatusTitle = title;
      _stepTwoStatusMessage = message;
    });
  }

  bool _shouldIgnoreHidPayload(String value) {
    final v = value.trim();
    if (v.isEmpty) return true;
    if (v.length > 1024) return true;
    if (v.contains('\n') || v.contains('\r') || v.contains('\t')) return true;
    if (v.contains('{') || v.contains('}')) return true;
    if (RegExp(r'^\[\d{4}-\d{2}-\d{2}T').hasMatch(v)) return true;
    if (v.contains('Native QR diagnostics') ||
        v.contains('QR device diagnostics')) {
      return true;
    }
    return false;
  }

  void _ensureHidQrFocus() {
    if (!mounted) return;
    if (!Platform.isAndroid) return;
    if (_step != 1) return;
    if (_hidQrFocusNode.hasFocus) return;
    FocusScope.of(context).requestFocus(_hidQrFocusNode);
  }

  void _onHidQrBufferChanged(String raw) {
    if (!mounted) return;
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
            _scannerReceiving = true;
            _scannerArmed = true;
            _scannerMode = source.isEmpty ? _scannerMode : source;
            _scannerStatusLabel = source.isEmpty
                ? 'Scanner input detected.'
                : 'Scanner input detected ($source).';
            _lastDecodedSource = source.isEmpty ? 'unknown' : source;
            _lastDecodedPayloadRedacted = _redactText(value);
            _lastDecodedAt = DateTime.now();
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
        setState(() {});
      }
      _showSnackBar('QR scanner unavailable', isError: true);
    }
  }

  void _startScannerStatusPolling() {
    if (!Platform.isAndroid) return;
    _scannerStatusTimer?.cancel();
    _scannerStatusTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      unawaited(_refreshScannerStatus());
    });
    unawaited(_refreshScannerStatus());
  }

  Future<void> _refreshScannerStatus() async {
    if (!mounted || !Platform.isAndroid) return;
    if (_step != 1) return;
    try {
      final diag = await _PalmHardware.getQrNativeDiagnostics();
      if (!mounted) return;
      final readerRunning = diag['qr_reader_running'] == true;
      final driver = (diag['qr_serial_driver']?.toString() ?? '').trim();
      final lastByteAge = (diag['qr_last_byte_age_ms'] as num?)?.toInt() ?? -1;
      final hidKeyAge = (diag['hid_last_key_age_ms'] as num?)?.toInt() ?? -1;
      final broadcastAge =
          (diag['broadcast_last_age_ms'] as num?)?.toInt() ?? -1;
      final bytesTotal = (diag['qr_reader_bytes_total'] as num?)?.toInt() ?? 0;
      final serialRecent = lastByteAge >= 0 && lastByteAge < 2500;
      final hidRecent = hidKeyAge >= 0 && hidKeyAge < 2500;
      final hasRecentSignal =
          serialRecent ||
          hidRecent ||
          (broadcastAge >= 0 && broadcastAge < 2500);
      final nextMode = driver.isEmpty ? 'unknown' : driver;
      final nextStatus = hasRecentSignal
          ? 'Scanner active: receiving input (${nextMode.toUpperCase()}).'
          : readerRunning
          ? 'Scanner armed: ready to scan (${nextMode.toUpperCase()}).'
          : 'Scanner not armed. Tap scanner area to focus.';
      setState(() {
        _scannerArmed = readerRunning;
        _scannerReceiving = hasRecentSignal;
        _scannerMode = nextMode;
        _scannerStatusLabel = nextStatus;
        _scannerHidRecent = hidRecent;
        _scannerSerialRecent = serialRecent;
        _scannerSerialBytesTotal = bytesTotal;
      });
    } catch (_) {}
  }

  void _maybeAutoClaim(String qrData) {
    if (_busy) return;
    if (_step != 1) return;

    final deviceId = _deviceIdController.text.trim();
    if (deviceId.isEmpty) return;

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
          _step == 1 && _deviceIdController.text.trim().isNotEmpty;
      if (shouldAutoClaim) {
        await _claimSession();
      }
    } on PlatformException catch (e) {
      if (mounted) {
        setState(() {
          _errorText = e.message ?? e.code;
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

    _log('Claim button clicked', <String, Object?>{
      'has_qr': qrData.isNotEmpty,
      'qr_len': qrData.length,
      'has_device_id': deviceId.isNotEmpty,
      'device_id_len': deviceId.length,
    });

    if (qrData.isEmpty || deviceId.isEmpty) {
      final missing = <String>[
        if (qrData.isEmpty) 'qr_data',
        if (deviceId.isEmpty) 'device_id',
      ];
      setState(() {
        _errorText =
            'Missing required fields: ${missing.join(', ')}. QR data and Device ID are required.';
      });
      _log('Claim blocked: missing fields', <String, Object?>{
        'has_qr': qrData.isNotEmpty,
        'has_device_id': deviceId.isNotEmpty,
        'missing': missing,
      });
      return;
    }

    setState(() {
      _busy = true;
      _errorText = null;
    });

    try {
      _log('Claim session start', <String, Object?>{
        'device_id': deviceId,
        'qr_data': _redactText(qrData),
      });
      final res = await _postJson(
        uri: Uri.parse('$_amenPayApiBaseUrl/api/palm/enroll/sessions/claim'),
        headers: <String, String>{'X-Device-Id': deviceId},
        body: <String, dynamic>{'qr_data': qrData, 'device_id': deviceId},
      );
      _log(
        'Claim API response',
        _redactMap(Map<String, Object?>.from(res)),
      );

      final sessionId = (res['sessionId'] ?? res['session_id'] ?? res['id'])
          ?.toString();

      setState(() {
        _claimResponse = res;
        _sessionId = sessionId;
        _step = 2;
      });
      _setStepTwoStatus(_PalmStepTwoStatus.placePalm);
      _log(
        'Claim session success',
        _redactMap(<String, Object?>{'session_id': sessionId, 'response': res}),
      );
      _log('Claim result summary', <String, Object?>{
        'ok': true,
        'session_id': sessionId ?? '',
        'has_response': res.isNotEmpty,
      });
      _showSnackBar(
        AppLocalizations.of(context)!.sessionClaimedSuccessfully,
        isError: false,
      );
    } catch (e) {
      setState(() {
        _errorText = e.toString();
      });
      _log('Claim session failed', <String, Object?>{'error': e.toString()});
      _log('Claim result summary', <String, Object?>{
        'ok': false,
        'error': e.toString(),
      });
      _showSnackBar(_userFacingError(e), isError: true);
    } finally {
      setState(() {
        _busy = false;
      });
    }
  }

  Future<void> _startEnrollmentAndSubmit({bool allowRetry = true}) async {
    final sessionId = _sessionId?.trim();
    final deviceId = _deviceIdController.text.trim();

    if (sessionId == null || sessionId.isEmpty) {
      setState(() {
        _errorText = AppLocalizations.of(context)!.missingSessionIdClaimFirst;
      });
      return;
    }

    if (deviceId.isEmpty) {
      setState(() {
        _errorText = AppLocalizations.of(context)!.deviceIdRequired;
      });
      return;
    }

    setState(() {
      _busy = true;
      _errorText = null;
    });
    _setStepTwoStatus(_PalmStepTwoStatus.scanning);

    try {
      _log('Palm enrollment start', <String, Object?>{
        'session_id': sessionId,
        'device_id': deviceId,
      });
      final body = <String, dynamic>{'device_id': deviceId};
      _setStepTwoStatus(_PalmStepTwoStatus.waitingMatcher);
      final matcherUserId = await _extractMatcherUserId();
      if (matcherUserId == null) {
        throw const PalmMatcherException(
          code: 'MATCHER_USER_ID_MISSING',
          message:
              'Enrollment session is missing the user id required by the local matcher.',
        );
      }
      final voucher = _extractMatcherVoucher(sessionId);
      final matcherRes = await PalmMatcherService.instance.captureEnroll(
        userId: matcherUserId.toString(),
        voucher: voucher,
      );

      _log('Local matcher enrollment result', <String, Object?>{
        'palm_id': _redactText(matcherRes.palmId),
        'user_id': matcherRes.userId ?? matcherUserId.toString(),
        'matched_existing': matcherRes.matchedExisting,
        'voucher': matcherRes.voucher ?? voucher,
        'palm_type': matcherRes.palmType,
        'score': matcherRes.score,
        'similar_rgb': matcherRes.similarRgb,
        'similar_nir': matcherRes.similarNir,
      });

      body['result'] = 'success';
      body['palm_id'] = matcherRes.palmId;

      _log(
        'Submit result start',
        _redactMap(<String, Object?>{
          'session_id': sessionId,
          'device_id': deviceId,
          'body': body,
        }),
      );
      _setStepTwoStatus(_PalmStepTwoStatus.submitting);
      final res = await _postJson(
        uri: Uri.parse(
          '$_amenPayApiBaseUrl/api/palm/enroll/sessions/$sessionId/submit-result',
        ),
        headers: <String, String>{'X-Device-Id': deviceId},
        body: body,
      );
      _log(
        'Submit API response',
        _redactMap(Map<String, Object?>.from(res)),
      );

      setState(() {
        _submitResponse = res;
        _step = 3;
      });
      _qrSubscription?.cancel();
      _qrSubscription = null;
      _scannerStatusTimer?.cancel();
      _scannerStatusTimer = null;
      _hidFinalizeTimer?.cancel();
      _hidFinalizeTimer = null;
      if (mounted) {
        FocusScope.of(context).unfocus();
      }
      _log(
        'Submit result success',
        _redactMap(<String, Object?>{'response': res}),
      );
      _showSnackBar(
        AppLocalizations.of(context)!.enrollmentSubmittedSuccessfully,
        isError: false,
      );
    } on PalmMatcherException catch (e) {
      final friendlyMessage = _friendlyMatcherMessage(e);
      setState(() {
        _errorText = friendlyMessage;
      });
      _setStepTwoStatus(
        _PalmStepTwoStatus.matcherUnavailable,
        messageOverride: friendlyMessage,
      );
      _log('Enrollment/submit matcher error', <String, Object?>{
        'code': e.code,
        'message': e.message,
      });
      _showSnackBar(friendlyMessage, isError: true);
    } catch (e) {
      final friendlyMessage = _userFacingError(e);
      setState(() {
        _errorText = friendlyMessage;
      });
      _setStepTwoStatus(
        _PalmStepTwoStatus.failed,
        messageOverride: friendlyMessage,
      );
      _log('Enrollment/submit error', <String, Object?>{'error': e.toString()});
      _showSnackBar(friendlyMessage, isError: true);
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

    if (Platform.isAndroid && _step == 1) {
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
        title: Text(AppLocalizations.of(context)!.enrollPalmVeinTitle),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(24, 24, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (Platform.isAndroid && _step == 1)
              SizedBox(
                width: 1,
                height: 1,
                child: TextField(
                  focusNode: _hidQrFocusNode,
                  controller: _hidQrBufferController,
                  autofocus: false,
                  autocorrect: false,
                  enableSuggestions: false,
                  showCursor: false,
                  readOnly: true,
                  enableInteractiveSelection: false,
                  keyboardType: TextInputType.none,
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
                      scannerStatusLabel: _scannerStatusLabel,
                      scannerArmed: _scannerArmed,
                      scannerReceiving: _scannerReceiving,
                      scannerMode: _scannerMode,
                      scannerHidRecent: _scannerHidRecent,
                      scannerSerialRecent: _scannerSerialRecent,
                      scannerSerialBytesTotal: _scannerSerialBytesTotal,
                      lastDecodedSource: _lastDecodedSource,
                      lastDecodedPayloadRedacted: _lastDecodedPayloadRedacted,
                      lastDecodedAt: _lastDecodedAt,
                      onRequestScannerFocus: _ensureHidQrFocus,
                      onScanQr: _scanQrOnce,
                      onClaim: _claimSession,
                    )
                  : _step == 2
                  ? _StepTwo(
                      busy: _busy,
                      sessionId: _sessionId,
                      statusTitle: _stepTwoStatusTitle,
                      statusMessage: _stepTwoStatusMessage,
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
            _StepLabel(label: AppLocalizations.of(context)!.stepQrCode),
            _StepLabel(label: AppLocalizations.of(context)!.stepScanning),
            _StepLabel(label: AppLocalizations.of(context)!.stepComplete),
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
  final String scannerStatusLabel;
  final bool scannerArmed;
  final bool scannerReceiving;
  final String scannerMode;
  final bool scannerHidRecent;
  final bool scannerSerialRecent;
  final int scannerSerialBytesTotal;
  final String lastDecodedSource;
  final String lastDecodedPayloadRedacted;
  final DateTime? lastDecodedAt;
  final Future<void> Function() onClaim;
  final Future<void> Function() onScanQr;
  final VoidCallback onRequestScannerFocus;

  const _StepOne({
    required this.busy,
    required this.qrDataController,
    required this.deviceIdController,
    required this.scannerStatusLabel,
    required this.scannerArmed,
    required this.scannerReceiving,
    required this.scannerMode,
    required this.scannerHidRecent,
    required this.scannerSerialRecent,
    required this.scannerSerialBytesTotal,
    required this.lastDecodedSource,
    required this.lastDecodedPayloadRedacted,
    required this.lastDecodedAt,
    required this.onClaim,
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
                          color: scannerReceiving
                              ? const Color(0xFF16A34A)
                              : const Color(0xFF238EC2),
                          width: 2,
                        ),
                        gradient: const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                        ),
                      ),
                      child: Stack(
                        children: [
                          const Positioned(
                            top: 16,
                            left: 16,
                            child: _ScanCorner(top: true, left: true),
                          ),
                          const Positioned(
                            top: 16,
                            right: 16,
                            child: _ScanCorner(top: true, left: false),
                          ),
                          const Positioned(
                            bottom: 16,
                            left: 16,
                            child: _ScanCorner(top: false, left: true),
                          ),
                          const Positioned(
                            bottom: 16,
                            right: 16,
                            child: _ScanCorner(top: false, left: false),
                          ),
                          Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.qr_code_scanner,
                                  size: 90,
                                  color: scannerReceiving
                                      ? const Color(0xFF86EFAC)
                                      : const Color(0xFF93C5FD),
                                ),
                                const SizedBox(height: 10),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: scannerReceiving
                                        ? const Color(0xFF14532D)
                                        : scannerArmed
                                        ? const Color(0xFF1E3A8A)
                                        : const Color(0xFF374151),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    scannerReceiving
                                        ? AppLocalizations.of(context)!.scannerActive
                                        : scannerArmed
                                        ? AppLocalizations.of(context)!.scannerReady
                                        : AppLocalizations.of(context)!.scannerIdle,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      AppLocalizations.of(context)!.palmEnrollQrBody,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        height: 23 / 14,
                        letterSpacing: -0.5,
                        color: const Color(0xFF333333),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '$scannerStatusLabel (mode: ${scannerMode.toUpperCase()})',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontSize: 12,
                        color: scannerReceiving
                            ? const Color(0xFF15803D)
                            : const Color(0xFF475569),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: busy ? null : onScanQr,
                        icon: const Icon(Icons.qr_code_scanner),
                        label: Text(AppLocalizations.of(context)!.scanEnrollmentQrButton),
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
                              ? AppLocalizations.of(context)!.scanEnrollmentQrHint
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
                            ? AppLocalizations.of(context)!.deviceIdNotLoaded
                            : '${AppLocalizations.of(context)!.deviceIdPrefix}: ${deviceIdController.text.trim()}',
                        style: Theme.of(context).textTheme.bodySmall,
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
            onPressed: busy ? null : onClaim,
            child: busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(AppLocalizations.of(context)!.claimEnrollmentSession),
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
                AppLocalizations.of(context)!.biometricDataSecureBody,
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

class _ScanCorner extends StatelessWidget {
  final bool top;
  final bool left;

  const _ScanCorner({required this.top, required this.left});

  @override
  Widget build(BuildContext context) {
    const color = Color(0xFF60A5FA);
    return SizedBox(
      width: 28,
      height: 28,
      child: CustomPaint(
        painter: _ScanCornerPainter(top: top, left: left, color: color),
      ),
    );
  }
}

class _ScanCornerPainter extends CustomPainter {
  final bool top;
  final bool left;
  final Color color;

  const _ScanCornerPainter({
    required this.top,
    required this.left,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final sx = left ? 0.0 : size.width;
    final sy = top ? 0.0 : size.height;
    final hx = left ? size.width * 0.7 : size.width * 0.3;
    final vy = top ? size.height * 0.7 : size.height * 0.3;
    canvas.drawLine(Offset(sx, sy), Offset(hx, sy), paint);
    canvas.drawLine(Offset(sx, sy), Offset(sx, vy), paint);
  }

  @override
  bool shouldRepaint(covariant _ScanCornerPainter oldDelegate) {
    return oldDelegate.top != top ||
        oldDelegate.left != left ||
        oldDelegate.color != color;
  }
}

class _StepTwo extends StatelessWidget {
  final bool busy;
  final String? sessionId;
  final String statusTitle;
  final String statusMessage;
  final Future<void> Function() onStartEnrollment;

  const _StepTwo({
    required this.busy,
    required this.sessionId,
    required this.statusTitle,
    required this.statusMessage,
    required this.onStartEnrollment,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.palmStep2Of3,
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
                      statusTitle,
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
                      statusMessage,
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
                          '${l10n.palmSessionLabel}: $sessionId',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    const SizedBox(height: 24),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        vertical: 18,
                        horizontal: 16,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (busy) ...[
                            const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            const SizedBox(width: 12),
                          ],
                          Expanded(
                            child: Text(
                              busy
                                  ? l10n.palmScanningInProgressBody
                                  : l10n.palmPressStartBody,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                letterSpacing: -0.5,
                                color: Color(0xFF238EC2),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: busy ? null : onStartEnrollment,
                        icon: const Icon(Icons.pan_tool_alt_outlined),
                        label: Text(
                          busy
                              ? l10n.scanningProgressShort
                              : l10n.startPalmEnrollment,
                        ),
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
            child: Text(
              busy ? l10n.scanningInProgressShort : l10n.awaitingEnrollment,
            ),
          ),
        ),
      ],
    );
  }
}

enum _PalmStepTwoStatus {
  placePalm,
  scanning,
  waitingMatcher,
  submitting,
  matcherUnavailable,
  failed,
}

class _PalmHardware {
  static const MethodChannel _posDeviceMethods = MethodChannel(
    'posDevice/methods',
  );
  static const MethodChannel _qrScannerMethods = MethodChannel(
    'qrScanner/methods',
  );
  static const EventChannel _qrScannerEvents = EventChannel('qrScanner/events');

  static Future<String?> getDeviceId() async {
    final res = await _posDeviceMethods.invokeMethod<dynamic>('getDeviceId');
    return res?.toString();
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
    final l10n = AppLocalizations.of(context)!;
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
                      l10n.enrollmentComplete,
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
                      l10n.palmEnrollmentCompletedBody,
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
