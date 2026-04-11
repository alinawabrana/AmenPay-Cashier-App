import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class QrScannerTestScreen extends StatefulWidget {
  const QrScannerTestScreen({super.key});

  @override
  State<QrScannerTestScreen> createState() => _QrScannerTestScreenState();
}

class _QrScannerTestScreenState extends State<QrScannerTestScreen> {
  final List<String> _logs = <String>[];
  String _lastPayload = '';
  String _lastSource = '';
  bool _busy = false;
  StreamSubscription<Map<String, dynamic>>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = _HardwareBridge.qrEvents().listen((event) {
      final type = event['type']?.toString() ?? '';
      if (type == 'success') {
        final payload = event['payload']?.toString() ?? '';
        final source = event['source']?.toString() ?? 'unknown';
        if (!mounted) return;
        setState(() {
          _lastPayload = payload;
          _lastSource = source;
        });
        _log('QR payload received', <String, Object?>{
          'source': source,
          'qr_data': _redact(payload),
        });
      } else if (type == 'error') {
        _log('QR event error', <String, Object?>{
          'code': event['code']?.toString() ?? '',
          'message': event['message']?.toString() ?? '',
        });
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _log(String message, [Map<String, Object?>? data]) {
    final now = DateTime.now().toIso8601String();
    final suffix = data == null ? '' : ' ${jsonEncode(data)}';
    final line = '[$now] $message$suffix';
    if (!mounted) return;
    setState(() {
      _logs.add(line);
      if (_logs.length > 400) {
        _logs.removeRange(0, _logs.length - 400);
      }
    });
    debugPrint(line);
  }

  String _redact(String value) {
    final v = value.trim();
    if (v.isEmpty) return '';
    if (v.length <= 10) return '*' * v.length;
    return '${v.substring(0, 6)}...${v.substring(v.length - 4)}';
  }

  Future<void> _runChip() async {
    setState(() {
      _busy = true;
    });
    try {
      final report = <String, Object?>{
        'report_schema_version': 'qr-test-v1',
        'app_build_info': await _HardwareBridge.getAppBuildInfo(),
        'device_id': await _HardwareBridge.getDeviceId(),
        'qr_device_path': await _HardwareBridge.getQrDevicePath(),
        'qr_device_candidates': await _HardwareBridge.listQrDeviceCandidates(),
        'qr_native_diagnostics': await _HardwareBridge.getQrNativeDiagnostics(),
      };
      _log('QR tester chip report', report);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('QR report logged. Tap copy icon.')),
      );
    } catch (e) {
      _log('QR tester chip report failed', <String, Object?>{
        'error': e.toString(),
      });
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> _copyLogs() async {
    if (_logs.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: _logs.join('\n')));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('QR logs copied')));
  }

  Future<void> _scanOnce() async {
    setState(() {
      _busy = true;
    });
    try {
      _log('scanQrOnce started');
      final payload = await _HardwareBridge.scanQrOnce(timeoutMs: 15000);
      _log('scanQrOnce received', <String, Object?>{
        'qr_data': _redact(payload ?? ''),
      });
    } catch (e) {
      _log('scanQrOnce failed', <String, Object?>{'error': e.toString()});
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> _runSerialProbe() async {
    setState(() {
      _busy = true;
    });
    try {
      final res = await _HardwareBridge.runFactoryParityScannerProbe(
        path: '/dev/ttyHSL3',
        baud: 9600,
        waitMs: 4000,
      );
      _log('Factory parity scanner probe result', res);
    } catch (e) {
      _log('Factory parity probe failed', <String, Object?>{
        'error': e.toString(),
      });
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Test QR Scanner'),
        actions: [
          IconButton(
            onPressed: _busy ? null : _runChip,
            icon: const Icon(Icons.memory),
            tooltip: 'Log QR hardware report',
          ),
          IconButton(
            onPressed: _logs.isEmpty ? null : _copyLogs,
            icon: const Icon(Icons.copy_all),
            tooltip: 'Copy QR logs',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  _lastPayload.isEmpty
                      ? 'No QR payload yet'
                      : 'Last payload: ${_redact(_lastPayload)} (source: $_lastSource)',
                ),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton.icon(
                  onPressed: _busy ? null : _scanOnce,
                  icon: const Icon(Icons.qr_code_scanner),
                  label: const Text('Scan QR Once'),
                ),
                OutlinedButton.icon(
                  onPressed: _busy ? null : _runSerialProbe,
                  icon: const Icon(Icons.usb),
                  label: const Text('Run Serial Probe'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: ListView.builder(
                  itemCount: _logs.length,
                  itemBuilder: (context, index) => SelectableText(
                    _logs[index],
                    style: const TextStyle(fontFamily: 'Menlo', fontSize: 12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PalmVeinTestScreen extends StatefulWidget {
  const PalmVeinTestScreen({super.key});

  @override
  State<PalmVeinTestScreen> createState() => _PalmVeinTestScreenState();
}

class _PalmVeinTestScreenState extends State<PalmVeinTestScreen> {
  final List<String> _logs = <String>[];
  final JsonEncoder _prettyJson = const JsonEncoder.withIndent('  ');
  bool _busy = false;
  String _compatibilityVerdict = 'Compatibility verdict: not checked yet';

  void _log(String message, [Map<String, Object?>? data]) {
    final now = DateTime.now().toIso8601String();
    final suffix = data == null ? '' : ' ${jsonEncode(data)}';
    final line = '[$now] $message$suffix';
    if (!mounted) return;
    setState(() {
      _logs.add(line);
      if (_logs.length > 400) {
        _logs.removeRange(0, _logs.length - 400);
      }
    });
    debugPrint(line);
  }

  Future<void> _runChip() async {
    setState(() {
      _busy = true;
    });
    try {
      final palmDiag = await _HardwareBridge.getPalmNativeDiagnostics();
      final hw = await _HardwareBridge.getHardwareConfigReport();
      final verdict = _derivePalmVerdict(palmDiag, hw);
      setState(() {
        _compatibilityVerdict = verdict;
      });
      final report = <String, Object?>{
        'report_schema_version': 'palm-test-v1',
        'app_build_info': await _HardwareBridge.getAppBuildInfo(),
        'device_id': await _HardwareBridge.getDeviceId(),
        'compatibility_verdict': verdict,
        'palm_native_diagnostics': palmDiag,
        'hardware_config': hw,
      };
      _log('Palm tester chip report', report);
    } catch (e) {
      _log('Palm tester chip report failed', <String, Object?>{
        'error': e.toString(),
      });
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  String _derivePalmVerdict(
    Map<String, dynamic> palmDiag,
    Map<String, dynamic> hw,
  ) {
    final baseline = palmDiag['baseline_class_available'] == true;
    final shun = palmDiag['shunpalm_class_available'] == true;
    final worker = palmDiag['shunpalm_worker_class_available'] == true;
    final palmSdkOk = baseline && shun && worker;
    final usbCandidates =
        (hw['palm_usb_candidates'] as List?) ?? const <dynamic>[];
    if (palmSdkOk && usbCandidates.isNotEmpty) {
      return 'Compatibility verdict: Leshun SDK path available + palm USB device detected.';
    }
    if (palmSdkOk) {
      return 'Compatibility verdict: Leshun SDK path available; no explicit palm USB candidate found.';
    }
    if (usbCandidates.isNotEmpty) {
      return 'Compatibility verdict: USB vendor path only (Leshun palm SDK classes missing on this build).';
    }
    return 'Compatibility verdict: No confirmed palm path (SDK missing and no palm USB candidate).';
  }

  Future<void> _copyLogs() async {
    if (_logs.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: _logs.join('\n')));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Palm logs copied')));
  }

  Future<void> _setMaxBrightness() async {
    try {
      final ok = await _HardwareBridge.setScreenBrightness(255);
      if (!mounted) return;
      debugPrint('[DeviceStatus] setScreenBrightness ok=$ok');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ok ? 'Screen brightness set to 255' : 'Failed to set brightness'),
        ),
      );
    } on PlatformException catch (e) {
      debugPrint(
        '[DeviceStatus] setScreenBrightness error code=${e.code} message=${e.message} details=${e.details}',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Brightness error: ${e.code}: ${e.message ?? ''}')),
      );
    } catch (e) {
      debugPrint('[DeviceStatus] setScreenBrightness error=$e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Brightness error: $e')),
      );
    }
  }

  Future<void> _getBrightness() async {
    try {
      final level = await _HardwareBridge.getScreenBrightness();
      if (!mounted) return;
      debugPrint('[DeviceStatus] getScreenBrightness level=$level');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Current brightness: ${level ?? 'unknown'}')),
      );
    } on PlatformException catch (e) {
      debugPrint(
        '[DeviceStatus] getScreenBrightness error code=${e.code} message=${e.message} details=${e.details}',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Brightness error: ${e.code}: ${e.message ?? ''}')),
      );
    } catch (e) {
      debugPrint('[DeviceStatus] getScreenBrightness error=$e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Brightness error: $e')),
      );
    }
  }

  Future<void> _copyCrashDiagnostics() async {
    setState(() {
      _busy = true;
    });
    try {
      final report = await _HardwareBridge.getPalmCrashDiagnostics();
      _log('Palm crash diagnostics', report);
      final text = _prettyJson.convert(report);
      await Clipboard.setData(ClipboardData(text: text));
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Crash diagnostics copied')));
    } catch (e) {
      _log('Palm crash diagnostics failed', <String, Object?>{
        'error': e.toString(),
      });
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> _startPalmTest() async {
    setState(() {
      _busy = true;
    });
    try {
      await _HardwareBridge.markPalmCheckpoint(
        stage: 'dart_startPalmTest_pressed',
      );
      _log('Palm enrollment test started');
      await _HardwareBridge.markPalmCheckpoint(
        stage: 'dart_before_startEnrollment_invoke',
      );
      final result = await _HardwareBridge.startPalmEnrollment();
      await _HardwareBridge.markPalmCheckpoint(
        stage: 'dart_after_startEnrollment_invoke',
      );
      _log('Palm enrollment test result', result);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Palm test finished. Check logs.')),
      );
    } catch (e) {
      _log('Palm enrollment test failed', <String, Object?>{
        'error': e.toString(),
      });
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> _runPalmUsbTransportProbe() async {
    setState(() {
      _busy = true;
    });
    try {
      final res = await _HardwareBridge.runUsbTransportProbe(
        vendorId: 807,
        productId: 4105,
        readTimeoutMs: 1200,
        readAttempts: 3,
      );
      _log('Palm USB transport probe result', res);
    } catch (e) {
      _log('Palm USB transport probe failed', <String, Object?>{
        'error': e.toString(),
      });
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> _runPalmUsbSniffProbe() async {
    setState(() {
      _busy = true;
    });
    try {
      final res = await _HardwareBridge.runUsbSniffProbe(
        vendorId: 807,
        productId: 4105,
        durationMs: 15000,
        readTimeoutMs: 300,
        triggerSweep: true,
      );
      _log('Palm USB sniff probe result', res);
    } catch (e) {
      _log('Palm USB sniff probe failed', <String, Object?>{
        'error': e.toString(),
      });
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Test Palm Vein Scanner'),
        actions: [
          IconButton(
            onPressed: _busy ? null : _runChip,
            icon: const Icon(Icons.memory),
            tooltip: 'Log palm hardware report',
          ),
          IconButton(
            onPressed: _logs.isEmpty ? null : _copyLogs,
            icon: const Icon(Icons.copy_all),
            tooltip: 'Copy palm logs',
          ),
          IconButton(
            onPressed: _busy ? null : _copyCrashDiagnostics,
            icon: const Icon(Icons.bug_report),
            tooltip: 'Copy crash diagnostics',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Text(_compatibilityVerdict),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _busy ? null : _startPalmTest,
              icon: const Icon(Icons.front_hand),
              label: const Text('Start Palm Enrollment Test'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _busy ? null : _runPalmUsbTransportProbe,
              icon: const Icon(Icons.usb),
              label: const Text('Run Palm USB Transport Probe'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _busy ? null : _runPalmUsbSniffProbe,
              icon: const Icon(Icons.sensors),
              label: const Text('Run Palm USB Sniff Probe (15s)'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _busy ? null : _copyCrashDiagnostics,
              icon: const Icon(Icons.bug_report),
              label: const Text('Copy Crash Diagnostics'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _busy ? null : _setMaxBrightness,
              icon: const Icon(Icons.wb_sunny),
              label: const Text('Set Screen Brightness 255'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _busy ? null : _getBrightness,
              icon: const Icon(Icons.brightness_6),
              label: const Text('Get Screen Brightness'),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: ListView.builder(
                  itemCount: _logs.length,
                  itemBuilder: (context, index) => SelectableText(
                    _logs[index],
                    style: const TextStyle(fontFamily: 'Menlo', fontSize: 12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class NfcCardTestScreen extends StatefulWidget {
  const NfcCardTestScreen({super.key});

  @override
  State<NfcCardTestScreen> createState() => _NfcCardTestScreenState();
}

class _NfcCardTestScreenState extends State<NfcCardTestScreen> {
  final List<String> _logs = <String>[];
  bool _busy = false;
  String _lastTagId = '';
  StreamSubscription<Map<String, dynamic>>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = _HardwareBridge.nfcEvents().listen((event) {
      final type = event['type']?.toString() ?? '';
      if (type == 'tag') {
        final tagId = event['tag_id_hex']?.toString() ?? '';
        if (mounted) {
          setState(() {
            _lastTagId = tagId;
          });
        }
        _log('NFC tag detected', Map<String, Object?>.from(event));
      } else if (type == 'state') {
        _log('NFC state event', Map<String, Object?>.from(event));
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _log(String message, [Map<String, Object?>? data]) {
    final now = DateTime.now().toIso8601String();
    final suffix = data == null ? '' : ' ${jsonEncode(data)}';
    final line = '[$now] $message$suffix';
    if (!mounted) return;
    setState(() {
      _logs.add(line);
      if (_logs.length > 400) {
        _logs.removeRange(0, _logs.length - 400);
      }
    });
    debugPrint(line);
  }

  Future<void> _runChip() async {
    setState(() {
      _busy = true;
    });
    try {
      final diag = await _HardwareBridge.getNfcDiagnostics();
      _log('NFC tester chip report', <String, Object?>{
        'report_schema_version': 'nfc-test-v1',
        'app_build_info': await _HardwareBridge.getAppBuildInfo(),
        'nfc_diagnostics': diag,
      });
    } catch (e) {
      _log('NFC tester chip report failed', <String, Object?>{
        'error': e.toString(),
      });
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> _copyLogs() async {
    if (_logs.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: _logs.join('\n')));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('NFC logs copied')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Test NFC Card Scanner'),
        actions: [
          IconButton(
            onPressed: _busy ? null : _runChip,
            icon: const Icon(Icons.memory),
            tooltip: 'Log NFC diagnostics',
          ),
          IconButton(
            onPressed: _logs.isEmpty ? null : _copyLogs,
            icon: const Icon(Icons.copy_all),
            tooltip: 'Copy NFC logs',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  _lastTagId.isEmpty
                      ? 'Tap NFC card on reader area to test.'
                      : 'Last NFC tag: $_lastTagId',
                ),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _busy ? null : _runChip,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh NFC Diagnostics'),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: ListView.builder(
                  itemCount: _logs.length,
                  itemBuilder: (context, index) => SelectableText(
                    _logs[index],
                    style: const TextStyle(fontFamily: 'Menlo', fontSize: 12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HardwareBridge {
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
  static const MethodChannel _nfcScannerMethods = MethodChannel(
    'nfcScanner/methods',
  );
  static const EventChannel _nfcScannerEvents = EventChannel(
    'nfcScanner/events',
  );

  static Future<String?> getDeviceId() async {
    final res = await _posDeviceMethods.invokeMethod<dynamic>('getDeviceId');
    return res?.toString();
  }

  static Future<Map<String, dynamic>> getAppBuildInfo() async {
    final res = await _posDeviceMethods.invokeMethod<dynamic>(
      'getAppBuildInfo',
    );
    if (res is Map) return Map<String, dynamic>.from(res);
    return const <String, dynamic>{};
  }

  static Future<Map<String, dynamic>> getHardwareConfigReport() async {
    final res = await _posDeviceMethods.invokeMethod<dynamic>(
      'getHardwareConfigReport',
    );
    if (res is Map) return Map<String, dynamic>.from(res);
    return const <String, dynamic>{};
  }

  static Future<int?> getScreenBrightness() async {
    final res = await _posDeviceMethods.invokeMethod<dynamic>(
      'getScreenBrightness',
    );
    if (res is int) return res;
    return int.tryParse(res?.toString() ?? '');
  }

  static Future<bool> setScreenBrightness(int level) async {
    final res = await _posDeviceMethods.invokeMethod<dynamic>(
      'setScreenBrightness',
      <String, dynamic>{'level': level},
    );
    if (res is bool) return res;
    return res == true;
  }

  static Stream<Map<String, dynamic>> qrEvents() {
    return _qrScannerEvents.receiveBroadcastStream().map((event) {
      if (event is Map) return Map<String, dynamic>.from(event);
      return <String, dynamic>{};
    });
  }

  static Future<String?> getQrDevicePath() async {
    final res = await _qrScannerMethods.invokeMethod<dynamic>(
      'getQrDevicePath',
    );
    return res?.toString();
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

  static Future<Map<String, dynamic>> getQrNativeDiagnostics() async {
    final res = await _qrScannerMethods.invokeMethod<dynamic>(
      'getQrNativeDiagnostics',
    );
    if (res is Map) return Map<String, dynamic>.from(res);
    return const <String, dynamic>{};
  }

  static Future<String?> scanQrOnce({required int timeoutMs}) async {
    final res = await _qrScannerMethods.invokeMethod<dynamic>(
      'scanQrOnce',
      <String, dynamic>{'timeout_ms': timeoutMs},
    );
    return res?.toString();
  }

  static Future<Map<String, dynamic>> runFactoryParityScannerProbe({
    required String path,
    required int baud,
    required int waitMs,
  }) async {
    final res = await _qrScannerMethods.invokeMethod<dynamic>(
      'runFactoryParityScannerProbe',
      <String, dynamic>{'path': path, 'baud': baud, 'wait_ms': waitMs},
    );
    if (res is Map) return Map<String, dynamic>.from(res);
    return const <String, dynamic>{};
  }

  static Future<Map<String, dynamic>> getPalmNativeDiagnostics() async {
    final res = await _palmEnrollmentMethods.invokeMethod<dynamic>(
      'getPalmNativeDiagnostics',
    );
    if (res is Map) return Map<String, dynamic>.from(res);
    return const <String, dynamic>{};
  }

  static Future<Map<String, dynamic>> runUsbTransportProbe({
    required int vendorId,
    required int productId,
    required int readTimeoutMs,
    required int readAttempts,
  }) async {
    final res = await _qrScannerMethods
        .invokeMethod<dynamic>('runUsbTransportProbe', <String, dynamic>{
          'vendor_id': vendorId,
          'product_id': productId,
          'read_timeout_ms': readTimeoutMs,
          'read_attempts': readAttempts,
        });
    if (res is Map) return Map<String, dynamic>.from(res);
    return const <String, dynamic>{};
  }

  static Future<Map<String, dynamic>> runUsbSniffProbe({
    required int vendorId,
    required int productId,
    required int durationMs,
    required int readTimeoutMs,
    required bool triggerSweep,
  }) async {
    final res = await _qrScannerMethods
        .invokeMethod<dynamic>('runUsbSniffProbe', <String, dynamic>{
          'vendor_id': vendorId,
          'product_id': productId,
          'duration_ms': durationMs,
          'read_timeout_ms': readTimeoutMs,
          'trigger_sweep': triggerSweep,
        });
    if (res is Map) return Map<String, dynamic>.from(res);
    return const <String, dynamic>{};
  }

  static Future<Map<String, dynamic>> startPalmEnrollment() async {
    final res = await _palmEnrollmentMethods.invokeMethod<dynamic>(
      'startEnrollment',
    );
    if (res is Map) return Map<String, dynamic>.from(res);
    return const <String, dynamic>{'error': 'invalid_result'};
  }

  static Future<Map<String, dynamic>> getPalmCrashDiagnostics() async {
    final res = await _palmEnrollmentMethods.invokeMethod<dynamic>(
      'getCrashDiagnostics',
    );
    if (res is Map) return Map<String, dynamic>.from(res);
    return const <String, dynamic>{};
  }

  static Future<void> markPalmCheckpoint({
    required String stage,
    String detail = '',
  }) async {
    await _palmEnrollmentMethods.invokeMethod<dynamic>(
      'markCheckpoint',
      <String, dynamic>{'stage': stage, 'detail': detail},
    );
  }

  static Stream<Map<String, dynamic>> nfcEvents() {
    return _nfcScannerEvents.receiveBroadcastStream().map((event) {
      if (event is Map) return Map<String, dynamic>.from(event);
      return <String, dynamic>{};
    });
  }

  static Future<Map<String, dynamic>> getNfcDiagnostics() async {
    final res = await _nfcScannerMethods.invokeMethod<dynamic>(
      'getNfcDiagnostics',
    );
    if (res is Map) return Map<String, dynamic>.from(res);
    return const <String, dynamic>{};
  }
}
