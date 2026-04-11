import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:amenpay_cashir_app/l10n/app_localizations.dart';
import 'package:amenpay_cashir_app/services/auth_service.dart';

class SupportLogsScreen extends StatefulWidget {
  const SupportLogsScreen({super.key});

  @override
  State<SupportLogsScreen> createState() => _SupportLogsScreenState();
}

class _SupportLogsScreenState extends State<SupportLogsScreen> {
  static const MethodChannel _posDeviceMethods = MethodChannel(
    'posDevice/methods',
  );

  late final Future<Map<String, dynamic>> _snapshotFuture = _loadSnapshot();

  Future<Map<String, dynamic>> _loadSnapshot() async {
    final token = await AuthService.getToken();
    final userId = await AuthService.getUserId();
    final deviceId = await AuthService.getDeviceId();
    Map<String, dynamic> deviceDiag = const <String, dynamic>{};
    try {
      final raw = await _posDeviceMethods.invokeMethod<dynamic>(
        'getDisplayDiagnostics',
      );
      if (raw is Map) {
        deviceDiag = Map<String, dynamic>.from(raw);
      }
    } catch (_) {}

    return <String, dynamic>{
      'logged_in': token != null && token.isNotEmpty,
      'user_id': userId,
      'device_id': deviceId ?? '',
      'display_diagnostics': deviceDiag,
      'captured_at': DateTime.now().toIso8601String(),
    };
  }

  Future<void> _copySnapshot(Map<String, dynamic> snapshot) async {
    await Clipboard.setData(
      ClipboardData(text: const JsonEncoder.withIndent('  ').convert(snapshot)),
    );
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.supportSnapshotCopied)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.supportLogs)),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _snapshotFuture,
        builder: (context, snapshot) {
          final data = snapshot.data ?? const <String, dynamic>{};
          final display = data['display_diagnostics'] is Map
              ? Map<String, dynamic>.from(data['display_diagnostics'] as Map)
              : const <String, dynamic>{};
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF102A43),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.supportSnapshotTitle,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.supportSnapshotBody,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: snapshot.hasData
                            ? () => _copySnapshot(data)
                            : null,
                        icon: const Icon(Icons.copy_all),
                        label: Text(l10n.supportCopySnapshot),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _SupportSection(
                title: l10n.supportSectionSessionState,
                children: [
                  _SupportRow(
                    label: l10n.supportLoggedIn,
                    value: (data['logged_in'] == true)
                        ? l10n.supportYes
                        : l10n.supportNo,
                  ),
                  _SupportRow(
                    label: l10n.supportUserId,
                    value: (data['user_id'] ?? l10n.settingsUnavailable)
                        .toString(),
                  ),
                  _SupportRow(
                    label: l10n.supportCapturedAt,
                    value: (data['captured_at'] ?? '-').toString(),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _SupportSection(
                title: l10n.supportSectionDeviceState,
                children: [
                  _SupportRow(
                    label: l10n.supportDeviceId,
                    value: (data['device_id'] ?? l10n.settingsUnavailable)
                        .toString(),
                  ),
                  _SupportRow(
                    label: l10n.supportDisplayCount,
                    value:
                        (display['display_count'] ??
                                display['count'] ??
                                l10n.unknown)
                            .toString(),
                  ),
                  _SupportRow(
                    label: l10n.supportPrimaryDisplay,
                    value:
                        (display['primary_display'] ??
                                display['default_display'] ??
                                l10n.unknown)
                            .toString(),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _SupportSection(
                title: l10n.supportSectionRecommendedChecks,
                children: [
                  _SupportBullet(text: l10n.supportCheckRegistration),
                  _SupportBullet(text: l10n.supportCheckHardware),
                  _SupportBullet(text: l10n.supportCheckSnapshot),
                  _SupportBullet(text: l10n.supportCheckScanner),
                ],
              ),
              const SizedBox(height: 12),
              _SupportSection(
                title: l10n.supportSectionRawDisplayDiagnostics,
                children: [
                  SelectableText(
                    const JsonEncoder.withIndent('  ').convert(display),
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SupportSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _SupportSection({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _SupportRow extends StatelessWidget {
  final String label;
  final String value;

  const _SupportRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(color: Color(0xFF6B7280)),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _SupportBullet extends StatelessWidget {
  final String text;

  const _SupportBullet({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Icon(Icons.circle, size: 8, color: Color(0xFF1F8EC9)),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
