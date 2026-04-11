import 'package:flutter/material.dart';

import 'dart:async';
import 'dart:convert';

import 'package:amenpay_cashir_app/l10n/app_localizations.dart';
import 'package:amenpay_cashir_app/screens/hardware_test_screens.dart';
import 'package:flutter/services.dart';

class DeviceStatusScreen extends StatelessWidget {
  const DeviceStatusScreen({super.key});

  static const MethodChannel _posDeviceMethods = MethodChannel(
    'posDevice/methods',
  );

  void _push(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  Future<void> _showDisplayTest(BuildContext context, {int? displayId}) async {
    try {
      final ok = await _posDeviceMethods.invokeMethod<dynamic>(
        'showTestPresentation',
        displayId == null ? null : <String, dynamic>{'display_id': displayId},
      );
      debugPrint(
        '[DeviceStatus] showTestPresentation display_id=${displayId ?? -1} ok=$ok',
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ok == true
                ? AppLocalizations.of(context)!.deviceDisplayTestShown
                : AppLocalizations.of(context)!.deviceDisplayTestFailed,
          ),
        ),
      );
    } on PlatformException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)!.deviceDisplayTestError(e.code),
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)!.deviceDisplayTestError(e.toString()),
          ),
        ),
      );
    }
  }

  Future<void> _dismissDisplayTest(BuildContext context) async {
    try {
      await _posDeviceMethods.invokeMethod<dynamic>('dismissTestPresentation');
      debugPrint('[DeviceStatus] dismissTestPresentation ok=true');
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)!.deviceDisplayTestDismissed,
          ),
        ),
      );
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.deviceStatus)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(l10n.todoDeviceStatus, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          _DeviceActionTile(
            icon: Icons.qr_code_scanner,
            title: l10n.testQrScanner,
            subtitle: l10n.deviceStatusQrBody,
            onTap: () => _push(context, const QrScannerTestScreen()),
          ),
          _DeviceActionTile(
            icon: Icons.front_hand_outlined,
            title: l10n.testPalmVeinScanner,
            subtitle: l10n.deviceStatusPalmBody,
            onTap: () => _push(context, const PalmVeinTestScreen()),
          ),
          _DeviceActionTile(
            icon: Icons.nfc,
            title: l10n.testNfcCardScanner,
            subtitle: l10n.deviceStatusNfcBody,
            onTap: () => _push(context, const NfcCardTestScreen()),
          ),
          _DeviceActionTile(
            icon: Icons.monitor,
            title: l10n.deviceDisplayDiagnostics,
            subtitle: l10n.deviceStatusDisplayBody,
            onTap: () => _push(context, const DisplayDiagnosticsScreen()),
          ),
          _DeviceActionTile(
            icon: Icons.screen_share,
            title: l10n.deviceStatusShowSecondary,
            subtitle: l10n.deviceStatusShowSecondaryBody,
            onTap: () => _showDisplayTest(context, displayId: 1),
          ),
          _DeviceActionTile(
            icon: Icons.close_fullscreen,
            title: l10n.deviceStatusDismissTest,
            subtitle: l10n.deviceStatusDismissTestBody,
            onTap: () => _dismissDisplayTest(context),
          ),
        ],
      ),
    );
  }
}

class _DeviceActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _DeviceActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: const Color(0xFFEAF4FB),
          child: Icon(icon, color: const Color(0xFF1F8EC9)),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

class DisplayDiagnosticsScreen extends StatefulWidget {
  const DisplayDiagnosticsScreen({super.key});

  @override
  State<DisplayDiagnosticsScreen> createState() =>
      _DisplayDiagnosticsScreenState();
}

class _DisplayDiagnosticsScreenState extends State<DisplayDiagnosticsScreen> {
  static const MethodChannel _posDeviceMethods = MethodChannel(
    'posDevice/methods',
  );
  Timer? _pollTimer;
  final List<String> _logs = <String>[];
  String _lastSignature = '';
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _startPolling();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _pollDisplays();
    });
    _pollDisplays();
  }

  Future<void> _pollDisplays() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final res = await _posDeviceMethods.invokeMethod<dynamic>(
        'getDisplayDiagnostics',
      );
      final sig = jsonEncode(res ?? {});
      if (sig != _lastSignature) {
        _lastSignature = sig;
        _appendLog('Display change detected', res);
      }
    } catch (e) {
      _appendLog('Display poll error', <String, Object?>{
        'error': e.toString(),
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _appendLog(String title, Object? data) {
    final now = DateTime.now().toIso8601String();
    final pretty = const JsonEncoder.withIndent(
      '  ',
    ).convert(data is Map ? data : <String, dynamic>{'data': data});
    final line = '[$now] $title\n$pretty';
    debugPrint('[DeviceStatus] $line');
    setState(() {
      _logs.add(line);
      if (_logs.length > 200) {
        _logs.removeRange(0, _logs.length - 200);
      }
    });
  }

  Future<void> _showTestOnSecondary() async {
    try {
      final ok = await _posDeviceMethods.invokeMethod<dynamic>(
        'showTestPresentation',
        <String, dynamic>{'display_id': 1},
      );
      _appendLog('Show test presentation', <String, Object?>{'ok': ok});
    } catch (e) {
      _appendLog('Show test presentation error', <String, Object?>{
        'error': e.toString(),
      });
    }
  }

  Future<void> _showDisplayTest(int displayId) async {
    try {
      final ok = await _posDeviceMethods.invokeMethod<dynamic>(
        'showTestPresentation',
        <String, dynamic>{'display_id': displayId},
      );
      _appendLog('Show test presentation', <String, Object?>{
        'display_id': displayId,
        'ok': ok,
      });
    } catch (e) {
      _appendLog('Show test presentation error', <String, Object?>{
        'display_id': displayId,
        'error': e.toString(),
      });
    }
  }

  Future<void> _dismissTest() async {
    try {
      await _posDeviceMethods.invokeMethod<dynamic>('dismissTestPresentation');
      _appendLog('Dismiss test presentation', <String, Object?>{'ok': true});
    } catch (e) {
      _appendLog('Dismiss test presentation error', <String, Object?>{
        'error': e.toString(),
      });
    }
  }

  Future<void> _rebootDevice() async {
    try {
      final ok = await _posDeviceMethods.invokeMethod<dynamic>('rebootDevice');
      _appendLog('Reboot requested', <String, Object?>{'ok': ok});
    } catch (e) {
      _appendLog('Reboot error', <String, Object?>{'error': e.toString()});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Display Diagnostics'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _pollDisplays,
            tooltip: 'Refresh now',
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton.icon(
                  onPressed: () => _showDisplayTest(0),
                  icon: const Icon(Icons.tv),
                  label: const Text('Show Test (Primary)'),
                ),
                ElevatedButton.icon(
                  onPressed: _showTestOnSecondary,
                  icon: const Icon(Icons.screen_share),
                  label: const Text('Show Test (Secondary)'),
                ),
                OutlinedButton.icon(
                  onPressed: _dismissTest,
                  icon: const Icon(Icons.close),
                  label: const Text('Dismiss Test'),
                ),
                OutlinedButton.icon(
                  onPressed: _rebootDevice,
                  icon: const Icon(Icons.restart_alt),
                  label: const Text('Reboot Device'),
                ),
              ],
            ),
          ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
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
    );
  }
}
