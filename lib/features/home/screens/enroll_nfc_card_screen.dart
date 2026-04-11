import 'dart:async';
import 'dart:convert';

import 'package:amenpay_cashir_app/services/auth_service.dart';
import 'package:amenpay_cashir_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:io';

const String _amenPayApiBaseUrl = String.fromEnvironment(
  'AMENPAY_API_BASE_URL',
  defaultValue: 'https://amenpay.org',
);

class EnrollNfcCardScreen extends StatefulWidget {
  const EnrollNfcCardScreen({super.key});

  @override
  State<EnrollNfcCardScreen> createState() => _EnrollNfcCardScreenState();
}

class _EnrollNfcCardScreenState extends State<EnrollNfcCardScreen> {
  int _step = 1;
  bool _busy = false;
  String? _errorText;
  String _deviceId = 'Loading...';
  String _qrStatus = 'Ready to scan enrollment QR';
  String _scannerStatus = 'Reader idle';
  String _qrData = '';
  String _uidHex = '';
  String _uidDec = '';
  String _scanSource = '';
  String _lastAction = '';
  DateTime? _scannedAt;
  String? _sessionId;
  int? _paymentMethodId;
  String? _resultMessage;
  String _nfcStatus = 'inactive';
  bool _requiresScan = true;
  StreamSubscription<Map<String, dynamic>>? _sub;
  StreamSubscription<Map<String, dynamic>>? _qrSubscription;
  bool _hardwareInitialized = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_hardwareInitialized) return;
    _hardwareInitialized = true;
    _initHardware();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _qrSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initHardware() async {
    await _loadDeviceId();

    try {
      if (Platform.isAndroid) {
        final currentPath = await _NfcEnrollHardware.getQrDevicePath();
        final candidates = await _NfcEnrollHardware.listQrDeviceCandidates();

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
          if (nextPath.isNotEmpty && nextPath != currentPath) {
            await _NfcEnrollHardware.setQrDevicePath(nextPath);
          }
        }
      }
    } catch (_) {}

    try {
      _qrSubscription = _NfcEnrollHardware.qrEvents().listen(
        (event) {
          if (!mounted || _step != 1 || !_busy) return;
          final payload = event['payload']?.toString().trim() ?? '';
          if (payload.isEmpty) return;
          _claimQrPayload(payload);
        },
        onError: (Object error, StackTrace _) {
          if (!mounted || !_busy) return;
          setState(() {
            _busy = false;
            _qrStatus = AppLocalizations.of(context)!.scanFailed;
            _errorText = error.toString();
          });
        },
      );
    } catch (_) {}
  }

  Future<void> _loadDeviceId() async {
    final id = await _NfcEnrollHardware.getDeviceId();
    if (!mounted) return;
    setState(() {
      _deviceId = (id == null || id.trim().isEmpty) ? 'POS-001' : id.trim();
    });
  }

  Map<String, dynamic> _decodeMap(String body) {
    try {
      final raw = jsonDecode(body);
      if (raw is Map<String, dynamic>) return raw;
      if (raw is Map) return Map<String, dynamic>.from(raw);
    } catch (_) {}
    return <String, dynamic>{};
  }

  Future<void> _scanQrAndClaim() async {
    final l10n = AppLocalizations.of(context)!;
    if (_deviceId.trim().isEmpty || _deviceId == 'Loading...') {
      setState(() {
        _errorText = l10n.deviceIdNotLoaded;
      });
      return;
    }

    setState(() {
      _busy = true;
      _errorText = null;
      _resultMessage = null;
      _qrStatus = l10n.scanEnrollmentQrTitle;
    });

    try {
      final qr = await _NfcEnrollHardware.scanQrOnce(timeoutMs: 15000);
      final qrData = qr?.trim() ?? '';
      if (qrData.isNotEmpty) {
        await _claimQrPayload(qrData);
      }
    } on PlatformException catch (_) {
      // Keep the QR event stream armed. Some scanner paths deliver payload through HID/broadcast only.
    } catch (_) {
      // Keep waiting for the QR event stream.
    }
  }

  Future<void> _claimQrPayload(String qrData) async {
    final l10n = AppLocalizations.of(context)!;
    if (!_busy || _step != 1) return;

    final token = await AuthService.getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Missing auth token. Please log in again.');
    }

    final url = Uri.parse('$_amenPayApiBaseUrl/api/nfc/enroll/sessions/claim');
    final res = await http.post(
      url,
      headers: <String, String>{
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(<String, dynamic>{
        'qr_data': qrData,
        'device_id': _deviceId,
      }),
    );

    final decoded = _decodeMap(res.body);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception(
        (decoded['message'] ??
                decoded['error'] ??
                'Failed to claim NFC session.')
            .toString(),
      );
    }

    final sessionId = (decoded['session_id'] ?? '').toString().trim();
    final paymentMethodId = decoded['payment_method_id'];
    final nfcStatus = (decoded['nfc_status'] ?? 'inactive').toString();
    final requiresScan = decoded['requires_scan'] != false;
    final message =
        (decoded['message'] ?? 'NFC enrollment session claimed successfully.')
            .toString();

    final parsedPaymentMethodId = paymentMethodId is int
        ? paymentMethodId
        : int.tryParse(paymentMethodId?.toString() ?? '');

    if (sessionId.isEmpty || parsedPaymentMethodId == null) {
      throw Exception(
        'Claim response is missing session or payment method information.',
      );
    }

    if (!mounted) return;
    setState(() {
      _busy = false;
      _qrData = qrData;
      _sessionId = sessionId;
      _paymentMethodId = parsedPaymentMethodId;
      _nfcStatus = nfcStatus;
      _requiresScan = requiresScan;
      _resultMessage = message;
      _qrStatus = l10n.sessionClaimedSuccessfully;
    });

    if (requiresScan) {
      setState(() {
        _step = 2;
        _scannerStatus = l10n.waitingForNfcCard;
        _uidHex = '';
        _uidDec = '';
        _scanSource = '';
        _lastAction = '';
        _scannedAt = null;
      });
      _startListening();
    } else {
      setState(() {
        _step = 3;
      });
    }
  }

  void _startListening() {
    _sub?.cancel();
    setState(() {
      _busy = true;
      _scannerStatus = AppLocalizations.of(context)!.waitingForNfcCard;
      _errorText = null;
    });
    _sub = _NfcEnrollHardware.nfcEvents().listen(
      (event) {
        final type = event['type']?.toString() ?? '';
        if (type == 'state') {
          if (!mounted) return;
          final diag = event['diagnostics'];
          final initialized = diag is Map
              ? diag['vendor_hwinf_initialized'] == true
              : false;
          final reading = diag is Map
              ? diag['vendor_hwinf_reading'] == true
              : false;
          setState(() {
            _scannerStatus = initialized
                ? (reading
                      ? AppLocalizations.of(context)!.tapNfcCardOnReader
                      : AppLocalizations.of(context)!.scannerReady)
                : AppLocalizations.of(context)!.waiting;
          });
          return;
        }
        if (type != 'tag' || !_busy) return;
        final hex = event['tag_id_hex']?.toString().trim() ?? '';
        final dec = event['tag_id_dec']?.toString().trim() ?? '';
        if (hex.isEmpty && dec.isEmpty) return;
        _sub?.cancel();
        _sub = null;
        _submitScanResult(
          hex: hex,
          dec: dec,
          source: event['source']?.toString() ?? '',
          action: event['action']?.toString() ?? '',
        );
      },
      onError: (Object error, StackTrace _) {
        if (!mounted) return;
        setState(() {
          _busy = false;
          _errorText = error.toString();
          _scannerStatus = AppLocalizations.of(context)!.scanFailed;
        });
      },
    );
  }

  Future<void> _submitScanResult({
    required String hex,
    required String dec,
    required String source,
    required String action,
  }) async {
    final paymentMethodId = _paymentMethodId;
    final sessionId = _sessionId;
    if (paymentMethodId == null || sessionId == null || sessionId.isEmpty) {
      setState(() {
        _busy = false;
        _errorText = AppLocalizations.of(context)!.missingNfcEnrollmentSession;
      });
      return;
    }

    try {
      final token = await AuthService.getToken();
      if (token == null || token.isEmpty) {
        throw Exception('Missing auth token. Please log in again.');
      }

      final url = Uri.parse(
        '$_amenPayApiBaseUrl/api/payment-methods/$paymentMethodId/nfc/submit-result',
      );
      final res = await http.post(
        url,
        headers: <String, String>{
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(<String, dynamic>{
          'session_id': sessionId,
          'result': 'success',
          'device_id': _deviceId,
          'uid_hex': hex,
          'uid_dec': dec,
        }),
      );

      final decoded = _decodeMap(res.body);
      if (res.statusCode < 200 || res.statusCode >= 300) {
        throw Exception(
          (decoded['message'] ??
                  decoded['error'] ??
                  'Failed to submit NFC scan result.')
              .toString(),
        );
      }

      if (!mounted) return;
      setState(() {
        _busy = false;
        _uidHex = hex;
        _uidDec = dec;
        _scanSource = source;
        _lastAction = action;
        _scannedAt = DateTime.now();
        _scannerStatus = AppLocalizations.of(context)!.scanSuccessful;
        _resultMessage = (decoded['message'] ?? 'NFC enrolled successfully.')
            .toString();
        _nfcStatus = (decoded['nfc_status'] ?? 'active').toString();
        _step = 3;
      });
    } catch (e) {
      if (!mounted) return;
      final message = e.toString().replaceFirst('Exception: ', '');
      final isConflict =
          message.toLowerCase().contains('already enrolled') ||
          message.toLowerCase().contains('already linked');
      if (isConflict) {
        setState(() {
          _step = 1;
          _busy = false;
          _errorText = message;
          _scannerStatus = AppLocalizations.of(context)!.scannerIdle;
          _uidHex = '';
          _uidDec = '';
          _scanSource = '';
          _lastAction = '';
          _scannedAt = null;
          _sessionId = null;
          _paymentMethodId = null;
          _resultMessage = null;
          _nfcStatus = 'inactive';
          _requiresScan = true;
          _qrStatus = AppLocalizations.of(context)!.scanEnrollmentQrTitle;
        });
        return;
      }
      setState(() {
        _busy = false;
        _errorText = message;
        _scannerStatus = AppLocalizations.of(context)!.scanFailed;
      });
    }
  }

  void _restartFlow() {
    _sub?.cancel();
    setState(() {
      _step = 1;
      _busy = false;
      _errorText = null;
      _qrStatus = AppLocalizations.of(context)!.scanEnrollmentQrTitle;
      _scannerStatus = AppLocalizations.of(context)!.scannerIdle;
      _qrData = '';
      _uidHex = '';
      _uidDec = '';
      _scanSource = '';
      _lastAction = '';
      _scannedAt = null;
      _sessionId = null;
      _paymentMethodId = null;
      _resultMessage = null;
      _nfcStatus = 'inactive';
      _requiresScan = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back, color: Color(0xFF333333)),
        ),
        title: Text(l10n.enrollNfcCard),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(24, 24, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _NfcStepIndicator(step: _step),
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
              child: switch (_step) {
                1 => _NfcStepOne(
                  deviceId: _deviceId,
                  busy: _busy,
                  qrStatus: _qrStatus,
                  onContinue: _scanQrAndClaim,
                ),
                2 => _NfcStepTwo(
                  busy: _busy,
                  scannerStatus: _scannerStatus,
                  sessionId: _sessionId,
                  paymentMethodId: _paymentMethodId,
                  onStartScan: _startListening,
                ),
                _ => _NfcStepThree(
                  paymentMethodId: _paymentMethodId,
                  uidHex: _uidHex,
                  uidDec: _uidDec,
                  scanSource: _scanSource,
                  lastAction: _lastAction,
                  scannedAt: _scannedAt,
                  resultMessage: _resultMessage,
                  nfcStatus: _nfcStatus,
                  requiresScan: _requiresScan,
                  qrData: _qrData,
                  onRescan: _restartFlow,
                  onDone: () => Navigator.of(context).pop(),
                ),
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _NfcStepIndicator extends StatelessWidget {
  final int step;

  const _NfcStepIndicator({required this.step});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      children: [
        Row(
          children: [
            _NfcStepCircle(number: 1, active: step >= 1, current: step == 1),
            Expanded(
              child: Container(
                height: 4,
                color: step >= 2
                    ? const Color(0xFF238EC2)
                    : const Color(0xFFE5E7EB),
              ),
            ),
            _NfcStepCircle(number: 2, active: step >= 2, current: step == 2),
            Expanded(
              child: Container(
                height: 4,
                color: step >= 3
                    ? const Color(0xFF238EC2)
                    : const Color(0xFFE5E7EB),
              ),
            ),
            _NfcStepCircle(number: 3, active: step >= 3, current: step == 3),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _NfcStepLabel(label: l10n.stepClaim),
            _NfcStepLabel(label: l10n.stepNfcScan),
            _NfcStepLabel(label: l10n.stepComplete),
          ],
        ),
      ],
    );
  }
}

class _NfcStepLabel extends StatelessWidget {
  final String label;

  const _NfcStepLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: const Color(0xFF4B5563),
      ),
    );
  }
}

class _NfcStepCircle extends StatelessWidget {
  final int number;
  final bool active;
  final bool current;

  const _NfcStepCircle({
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

class _NfcStepOne extends StatelessWidget {
  final String deviceId;
  final bool busy;
  final String qrStatus;
  final VoidCallback onContinue;

  const _NfcStepOne({
    required this.deviceId,
    required this.busy,
    required this.qrStatus,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.scanEnrollmentQrTitle,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.scanEnrollmentQrBody,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF4B5563),
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${l10n.deviceIdPrefix}: $deviceId',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: Center(
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
                              Icons.qr_code_scanner,
                              color: Colors.white,
                              size: 56,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          qrStatus,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF238EC2),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          height: 56,
          child: ElevatedButton.icon(
            onPressed: busy ? null : onContinue,
            icon: const Icon(Icons.qr_code_scanner),
            label: busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(l10n.scanEnrollmentQrButton),
          ),
        ),
      ],
    );
  }
}

class _NfcStepTwo extends StatelessWidget {
  final bool busy;
  final String scannerStatus;
  final String? sessionId;
  final int? paymentMethodId;
  final VoidCallback onStartScan;

  const _NfcStepTwo({
    required this.busy,
    required this.scannerStatus,
    required this.sessionId,
    required this.paymentMethodId,
    required this.onStartScan,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.step2Of3,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontSize: 14,
            fontWeight: FontWeight.w600,
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
                        child: Icon(Icons.nfc, color: Colors.white, size: 60),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      l10n.tapNfcCardOnReader,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF333333),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.nfcEnrollmentClaimCompleteBody,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontSize: 14,
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
                          '${l10n.sessionLabel}: $sessionId',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    if (paymentMethodId != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${l10n.paymentMethodIdLabel}: $paymentMethodId',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ],
                    const SizedBox(height: 18),
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
                              scannerStatus,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
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
                        onPressed: busy ? null : onStartScan,
                        icon: const Icon(Icons.nfc_outlined),
                        label: Text(
                          busy ? l10n.waitingForCard : l10n.startNfcScan,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _NfcStepThree extends StatelessWidget {
  final int? paymentMethodId;
  final String uidHex;
  final String uidDec;
  final String scanSource;
  final String lastAction;
  final DateTime? scannedAt;
  final String? resultMessage;
  final String nfcStatus;
  final bool requiresScan;
  final String qrData;
  final VoidCallback onRescan;
  final VoidCallback onDone;

  const _NfcStepThree({
    required this.paymentMethodId,
    required this.uidHex,
    required this.uidDec,
    required this.scanSource,
    required this.lastAction,
    required this.scannedAt,
    required this.resultMessage,
    required this.nfcStatus,
    required this.requiresScan,
    required this.qrData,
    required this.onRescan,
    required this.onDone,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scannedLabel = scannedAt == null
        ? '-'
        : scannedAt!.toLocal().toString();
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
                      l10n.nfcEnrollmentComplete,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF333333),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      resultMessage ?? l10n.nfcFlowCompletedSuccessfully,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontSize: 14,
                        color: const Color(0xFF4B5563),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    _InfoTile(
                      label: l10n.paymentMethodIdLabel,
                      value: paymentMethodId?.toString() ?? '-',
                    ),
                    const SizedBox(height: 10),
                    _InfoTile(label: l10n.nfcStatusLabel, value: nfcStatus),
                    const SizedBox(height: 10),
                    _InfoTile(
                      label: l10n.qrPayloadLabel,
                      value: qrData.isEmpty ? '-' : qrData,
                    ),
                    if (requiresScan) ...[
                      const SizedBox(height: 10),
                      _InfoTile(
                        label: l10n.uidHexLabel,
                        value: uidHex.isEmpty ? '-' : uidHex,
                      ),
                      const SizedBox(height: 10),
                      _InfoTile(
                        label: l10n.uidDecLabel,
                        value: uidDec.isEmpty ? '-' : uidDec,
                      ),
                      const SizedBox(height: 10),
                      _InfoTile(
                        label: l10n.sourceLabel,
                        value: scanSource.isEmpty ? '-' : scanSource,
                      ),
                      const SizedBox(height: 10),
                      _InfoTile(
                        label: l10n.actionLabel,
                        value: lastAction.isEmpty ? '-' : lastAction,
                      ),
                      const SizedBox(height: 10),
                      _InfoTile(label: l10n.scannedAtLabel, value: scannedLabel),
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
          child: ElevatedButton(onPressed: onDone, child: Text(l10n.done)),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 56,
          child: OutlinedButton(
            onPressed: onRescan,
            child: Text(l10n.startNewNfcEnrollment),
          ),
        ),
      ],
    );
  }
}

class _InfoTile extends StatelessWidget {
  final String label;
  final String value;

  const _InfoTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: const Color(0xFF6B7280)),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _NfcEnrollHardware {
  static const MethodChannel _posDeviceMethods = MethodChannel(
    'posDevice/methods',
  );
  static const MethodChannel _qrScannerMethods = MethodChannel(
    'qrScanner/methods',
  );
  static const EventChannel _qrScannerEvents = EventChannel('qrScanner/events');
  static const EventChannel _nfcScannerEvents = EventChannel(
    'nfcScanner/events',
  );

  static Future<String?> getDeviceId() async {
    final res = await _posDeviceMethods.invokeMethod<dynamic>('getDeviceId');
    return res?.toString();
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

  static Stream<Map<String, dynamic>> qrEvents() {
    return _qrScannerEvents.receiveBroadcastStream().map((event) {
      if (event is Map) {
        return Map<String, dynamic>.from(event);
      }
      return <String, dynamic>{'payload': event.toString(), 'source': 'raw'};
    });
  }

  static Future<String?> scanQrOnce({required int timeoutMs}) async {
    final res = await _qrScannerMethods.invokeMethod<dynamic>(
      'scanQrOnce',
      <String, dynamic>{'timeout_ms': timeoutMs},
    );
    return res?.toString();
  }

  static Stream<Map<String, dynamic>> nfcEvents() {
    return _nfcScannerEvents.receiveBroadcastStream().map((event) {
      if (event is Map) {
        return Map<String, dynamic>.from(event);
      }
      return <String, dynamic>{'type': 'unknown', 'raw': event.toString()};
    });
  }
}
