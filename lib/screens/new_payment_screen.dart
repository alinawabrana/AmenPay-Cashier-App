import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import 'package:amenpay_cashir_app/l10n/app_localizations.dart';
import 'package:amenpay_cashir_app/screens/receipt_preview_screen.dart';
import 'package:amenpay_cashir_app/screens/home_screen.dart';
import 'package:amenpay_cashir_app/services/auth_service.dart';
import 'package:amenpay_cashir_app/services/palm_matcher_service.dart';

enum PaymentMethod { qr, palm, nfc }

const String _amenPayApiBaseUrl = String.fromEnvironment(
  'AMENPAY_API_BASE_URL',
  defaultValue: 'https://amenpay.org',
);

class NewPaymentScreen extends StatefulWidget {
  const NewPaymentScreen({super.key});

  @override
  State<NewPaymentScreen> createState() => _NewPaymentScreenState();
}

class _NewPaymentScreenState extends State<NewPaymentScreen> {
  int _step = 1; // 1..3
  PaymentMethod? _method;

  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _referenceController = TextEditingController();

  double? _amountValue() {
    final raw = _amountController.text.trim().replaceAll(',', '');
    if (raw.isEmpty) return null;
    return double.tryParse(raw);
  }

  bool get _canContinue {
    if (_step == 1) return _method != null;
    if (_step == 2) {
      final v = _amountValue();
      return v != null && v > 0;
    }
    return false;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _referenceController.dispose();
    super.dispose();
  }

  void _goBack() {
    if (_step > 1) {
      setState(() => _step -= 1);
      return;
    }
    Navigator.of(context).pop();
  }

  void _continue() {
    if (_step == 1) {
      if (_method == null) return;
      setState(() => _step = 2);
      return;
    }
    if (_step == 2) {
      if (!_canContinue) return;
      setState(() => _step = 3);
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(_step == 1 ? l10n.paymentMethod : l10n.newPayment),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _goBack,
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 12),
            _StepHeader(
              step: _step,
              labels: [l10n.stepMethod, l10n.stepAmount, l10n.stepPay],
            ),
            const SizedBox(height: 14),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: switch (_step) {
                  1 => _PaymentMethodStep(
                    key: const ValueKey('step1'),
                    selected: _method,
                    onSelect: (m) => setState(() => _method = m),
                  ),
                  2 => _AmountStep(
                    key: const ValueKey('step2'),
                    amountController: _amountController,
                    referenceController: _referenceController,
                    onPreset: (value) {
                      _amountController.text = value.toStringAsFixed(0);
                      setState(() {});
                    },
                    onChanged: () => setState(() {}),
                  ),
                  _ => _PayStep(
                    key: const ValueKey('step3'),
                    method: _method ?? PaymentMethod.qr,
                    amount: _amountValue() ?? 0,
                    reference: _referenceController.text.trim(),
                    onCancel: () => setState(() => _step = 2),
                  ),
                },
              ),
            ),
            if (_step != 3)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _canContinue ? _continue : null,
                    child: Text(l10n.continueLabel),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _StepHeader extends StatelessWidget {
  final int step;
  final List<String> labels;

  const _StepHeader({required this.step, required this.labels});

  @override
  Widget build(BuildContext context) {
    Color dotFill(bool done, bool active) {
      if (done) return const Color(0xFF1F8EC9);
      if (active) return const Color(0xFF1F8EC9);
      return const Color(0xFFE5E7EB);
    }

    Color dotText(bool done, bool active) {
      if (done || active) return Colors.white;
      return const Color(0xFF6B7280);
    }

    Color lineColor(bool done) =>
        done ? const Color(0xFF1F8EC9) : const Color(0xFFE5E7EB);

    Widget dot(int idx) {
      final done = step > idx;
      final active = step == idx;
      return Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: dotFill(done, active),
          shape: BoxShape.circle,
        ),
        child: Center(
          child: done
              ? const Icon(Icons.check, size: 16, color: Colors.white)
              : Text(
                  '$idx',
                  style: TextStyle(
                    color: dotText(done, active),
                    fontWeight: FontWeight.w800,
                  ),
                ),
        ),
      );
    }

    Widget line(bool done) {
      return Expanded(
        child: Container(
          height: 3,
          margin: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: lineColor(done),
            borderRadius: BorderRadius.circular(99),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          Row(
            children: [dot(1), line(step > 1), dot(2), line(step > 2), dot(3)],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                labels[0],
                style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
              ),
              Text(
                labels[1],
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: step == 2 ? FontWeight.w800 : FontWeight.w600,
                  color: step == 2
                      ? const Color(0xFF1F8EC9)
                      : const Color(0xFF6B7280),
                ),
              ),
              Text(
                labels[2],
                style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PaymentMethodStep extends StatelessWidget {
  final PaymentMethod? selected;
  final ValueChanged<PaymentMethod> onSelect;

  const _PaymentMethodStep({
    super.key,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      children: [
        const SizedBox(height: 10),
        Text(
          l10n.selectPaymentMethodTitle,
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 6),
        Text(
          l10n.selectPaymentMethodSubtitle,
          style: const TextStyle(color: Color(0xFF6B7280)),
        ),
        const SizedBox(height: 14),
        _MethodCard(
          icon: Icons.qr_code_2,
          title: l10n.qrCode,
          subtitle: l10n.qrCodeSubtitle,
          hint: l10n.quickAndSecure,
          selected: selected == PaymentMethod.qr,
          onTap: () => onSelect(PaymentMethod.qr),
        ),
        const SizedBox(height: 12),
        _MethodCard(
          icon: Icons.front_hand_outlined,
          title: l10n.palmScan,
          subtitle: l10n.palmScanSubtitle,
          hint: l10n.highlySecure,
          selected: selected == PaymentMethod.palm,
          onTap: () => onSelect(PaymentMethod.palm),
        ),
        const SizedBox(height: 12),
        _MethodCard(
          icon: Icons.wifi_tethering,
          title: l10n.nfcTap,
          subtitle: l10n.nfcTapSubtitle,
          hint: l10n.lightningFast,
          selected: selected == PaymentMethod.nfc,
          onTap: () => onSelect(PaymentMethod.nfc),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFEAF4FB),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFC7DFF0)),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline, color: Color(0xFF1F8EC9)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.hardwareSupport,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l10n.hardwareSupportBody,
                      style: const TextStyle(color: Color(0xFF6B7280)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MethodCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String hint;
  final bool selected;
  final VoidCallback onTap;

  const _MethodCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.hint,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected
                  ? const Color(0xFF1F8EC9)
                  : const Color(0xFFE5E7EB),
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEAF4FB),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: const Color(0xFF1F8EC9)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: const TextStyle(
                            color: Color(0xFF6B7280),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    selected
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off,
                    color: selected
                        ? const Color(0xFF1F8EC9)
                        : const Color(0xFF9CA3AF),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(
                    Icons.check_circle,
                    color: Color(0xFF16A34A),
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(hint, style: const TextStyle(color: Color(0xFF6B7280))),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AmountStep extends StatelessWidget {
  final TextEditingController amountController;
  final TextEditingController referenceController;
  final VoidCallback onChanged;
  final void Function(double value) onPreset;

  const _AmountStep({
    super.key,
    required this.amountController,
    required this.referenceController,
    required this.onChanged,
    required this.onPreset,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isArabic =
        Localizations.localeOf(context).languageCode.toLowerCase() == 'ar';
    final currencyLabel = isArabic ? 'ر.س' : 'SAR';

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      children: [
        const SizedBox(height: 10),
        Text(
          l10n.enterAmountTitle,
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 6),
        Text(
          l10n.enterAmountSubtitle,
          style: const TextStyle(color: Color(0xFF6B7280)),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Row(
            children: [
              Text(
                currencyLabel,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                  color: Color(0xFF6B7280),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: amountController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  style: const TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                  ),
                  decoration: InputDecoration(
                    hintText: '0.00',
                    border: InputBorder.none,
                    isCollapsed: true,
                    hintStyle: TextStyle(
                      color: Colors.black.withValues(alpha: 0.2),
                    ),
                  ),
                  onChanged: (_) => onChanged(),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => onPreset(50),
                child: Text('$currencyLabel 50'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton(
                onPressed: () => onPreset(100),
                child: Text('$currencyLabel 100'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton(
                onPressed: () => onPreset(250),
                child: Text('$currencyLabel 250'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Text(
          l10n.referenceOptional,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: referenceController,
          decoration: InputDecoration(
            hintText: l10n.referenceHint,
            prefixIcon: const Icon(Icons.receipt_long_outlined),
          ),
          onChanged: (_) => onChanged(),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFEAF4FB),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFC7DFF0)),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline, color: Color(0xFF1F8EC9)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.transactionFeeTitle,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l10n.transactionFeeBody,
                      style: const TextStyle(color: Color(0xFF6B7280)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PayStep extends StatelessWidget {
  final PaymentMethod method;
  final double amount;
  final String reference;
  final VoidCallback onCancel;

  const _PayStep({
    super.key,
    required this.method,
    required this.amount,
    required this.reference,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    switch (method) {
      case PaymentMethod.palm:
        return _PalmPay(
          amount: amount,
          reference: reference,
          onCancel: onCancel,
        );
      case PaymentMethod.nfc:
        return _NfcPay(
          amount: amount,
          reference: reference,
          onCancel: onCancel,
        );
      case PaymentMethod.qr:
        return _QrPay(amount: amount, reference: reference, onCancel: onCancel);
    }
  }
}

class _PalmPay extends StatefulWidget {
  final double amount;
  final String reference;
  final VoidCallback onCancel;

  const _PalmPay({
    required this.amount,
    required this.reference,
    required this.onCancel,
  });

  @override
  State<_PalmPay> createState() => _PalmPayState();
}

class _PalmPayState extends State<_PalmPay> {
  bool _busy = false;
  String? _error;
  String? _palmId;
  int? _recognizedUserId;
  bool _started = false;
  bool _loadingMethods = false;
  String? _methodsError;
  List<Map<String, dynamic>> _paymentMethods = const [];
  int _selectedMethodIndex = 0;

  bool get _hasMethods => _paymentMethods.isNotEmpty;

  String _methodLabel(Map<String, dynamic> method) {
    final brand =
        (method['brand'] ??
                method['card_brand'] ??
                method['scheme'] ??
                method['type'])
            ?.toString()
            .trim();
    final last4 =
        (method['last4'] ??
                method['card_last4'] ??
                method['card_last_four'] ??
                method['last_four'] ??
                method['masked_pan'] ??
                method['pan_last4'])
            ?.toString()
            .trim();
    final safeLast4 = (last4 == null || last4.isEmpty)
        ? ''
        : (last4.length > 4 ? last4.substring(last4.length - 4) : last4);
    final name = (method['name'] ?? method['title'] ?? method['label'])
        ?.toString()
        .trim();
    if (brand != null &&
        brand.isNotEmpty &&
        last4 != null &&
        last4.isNotEmpty) {
      return '${brand.toUpperCase()} •••• $safeLast4';
    }
    if (last4 != null && last4.isNotEmpty) {
      return 'CARD •••• $safeLast4';
    }
    if (name != null && name.isNotEmpty) return name;
    final id = (method['payment_method_id'] ?? method['id'])?.toString().trim();
    return id != null && id.isNotEmpty ? 'Card $id' : 'Card';
  }

  String _methodBrand(Map<String, dynamic> method) {
    final brand =
        (method['brand'] ??
                method['card_brand'] ??
                method['scheme'] ??
                method['card_type'] ??
                method['type'])
            ?.toString()
            .trim();
    return brand?.isNotEmpty == true ? brand! : 'Card';
  }

  String _methodHolder(Map<String, dynamic> method) {
    final holder =
        (method['card_holder_name'] ??
                method['holder_name'] ??
                method['name'] ??
                method['title'])
            ?.toString()
            .trim();
    return holder?.isNotEmpty == true ? holder! : 'Card Holder';
  }

  String _methodMaskedNumber(Map<String, dynamic> method) {
    final masked =
        (method['card_number'] ??
                method['masked_pan'] ??
                method['masked_card'] ??
                method['last4'])
            ?.toString()
            .trim();
    return masked?.isNotEmpty == true ? masked! : '**** **** **** ****';
  }

  String _methodExpiry(Map<String, dynamic> method) {
    final expiry =
        (method['expiry_date'] ?? method['expiry'] ?? method['expires_at'])
            ?.toString()
            .trim();
    return expiry?.isNotEmpty == true ? expiry! : '--/--';
  }

  List<Map<String, dynamic>> _extractMethods(dynamic data) {
    if (data is List) {
      return data
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList(growable: false);
    }
    if (data is Map) {
      final map = Map<String, dynamic>.from(data);
      final keys = <String>[
        'payment_methods',
        'paymentMethods',
        'methods',
        'cards',
        'data',
      ];
      for (final key in keys) {
        final value = map[key];
        final list = _extractMethods(value);
        if (list.isNotEmpty) return list;
      }
    }
    return const <Map<String, dynamic>>[];
  }

  Future<void> _fetchPaymentMethods(String palmId) async {
    setState(() {
      _loadingMethods = true;
      _methodsError = null;
      _paymentMethods = const [];
      _selectedMethodIndex = 0;
    });

    try {
      debugPrint('[NewPayment] payment-methods lookup palm_id=$palmId');
      final token = await AuthService.getToken();
      final deviceId = await AuthService.getDeviceId();
      if (token == null || token.isEmpty) {
        setState(() {
          _methodsError = 'Missing auth token. Please log in again.';
        });
        return;
      }

      final res = await http.post(
        Uri.parse('$_amenPayApiBaseUrl/api/palm/payment-methods-by-template'),
        headers: <String, String>{
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(<String, dynamic>{
          'palm_id': palmId,
          'palm_device_id': deviceId ?? '',
        }),
      );
      debugPrint(
        '[NewPayment] payment-methods lookup status=${res.statusCode} body=${res.body}',
      );

      Map<String, dynamic> body = <String, dynamic>{};
      try {
        final decoded = jsonDecode(res.body);
        if (decoded is Map<String, dynamic>) {
          body = decoded;
        } else if (decoded is Map) {
          body = Map<String, dynamic>.from(decoded);
        } else {
          body = <String, dynamic>{'data': decoded};
        }
      } catch (_) {
        body = <String, dynamic>{'raw': res.body};
      }

      if (res.statusCode < 200 || res.statusCode >= 300) {
        final message = (body['message'] ?? body['error'] ?? body['detail'])
            ?.toString()
            .trim();
        setState(() {
          _methodsError = message?.isNotEmpty == true
              ? message
              : 'Failed to load payment methods.';
        });
        return;
      }

      final methods = _extractMethods(body);
      if (methods.isEmpty) {
        setState(() {
          _methodsError =
              'No payment method found for this palm. Please enroll yourself.';
        });
        return;
      }

      setState(() {
        _paymentMethods = methods;
        _selectedMethodIndex = 0;
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingMethods = false;
        });
      }
    }
  }

  Future<String?> _recognizePalmLocally() async {
    setState(() {
      _loadingMethods = true;
      _methodsError = null;
      _paymentMethods = const [];
      _selectedMethodIndex = 0;
    });
    try {
      debugPrint('[NewPayment] palm matcher recognize request start');
      final res = await PalmMatcherService.instance.captureRecognize();
      debugPrint(
        '[NewPayment] palm matcher recognize response success=${res.success} matched=${res.matched} palm_id=${res.palmId ?? ''} user_id=${res.userId ?? ''} message=${res.message ?? ''}',
      );
      if (!res.success) {
        throw PalmMatcherException(
          code: 'MATCHER_RECOGNIZE_FAILED',
          message: res.message ?? 'Local palm recognition failed.',
        );
      }
      if (!res.matched) {
        if (!mounted) return null;
        final message = res.message?.trim().isNotEmpty == true
            ? res.message!.trim()
            : 'No matching palm found.';
        setState(() {
          _loadingMethods = false;
          _error = message;
          _methodsError = message;
        });
        debugPrint('[NewPayment] palm matcher no match message=$message');
        return null;
      }
      final palmId = res.palmId?.trim() ?? '';
      final recognizedUserId = int.tryParse((res.userId ?? '').trim());
      if (palmId.isEmpty) {
        if (!mounted) return null;
        setState(() {
          _loadingMethods = false;
          _error = 'Local palm recognition succeeded but palm_id was missing.';
          _methodsError =
              'Local palm recognition succeeded but palm_id was missing.';
        });
        debugPrint('[NewPayment] palm matcher returned empty palm_id');
        return null;
      }
      if (mounted) {
        setState(() {
          _recognizedUserId = recognizedUserId;
        });
      }
      return palmId;
    } on PalmMatcherException catch (e) {
      if (!mounted) return null;
      final message = _friendlyMatcherMessage(e);
      debugPrint(
        '[NewPayment] palm matcher error code=${e.code} status=${e.statusCode?.toString() ?? ''} message=${e.message}',
      );
      setState(() {
        _loadingMethods = false;
        _error = message;
        _methodsError = message;
      });
      return null;
    }
  }

  String _userFacingError(Object error) {
    final raw = error.toString().trim();
    if (raw.isEmpty) return 'Unknown error';
    final firstLine = raw.split('\n').first.trim();
    if (firstLine.length <= 180) return firstLine;
    return '${firstLine.substring(0, 180)}...';
  }

  String _friendlyMatcherMessage(PalmMatcherException error) {
    switch (error.code) {
      case 'MATCHER_KEY_MISSING':
        return 'Local matcher key is missing in this cashier app build.';
      case 'MATCHER_UNAVAILABLE':
        return 'Local palm matcher is unavailable. Ensure the matcher app is running on this POS device.';
      case 'MATCHER_NOT_READY':
        return error.message.trim().isNotEmpty
            ? error.message.trim()
            : 'Palm matcher startup sync is still in progress.';
      default:
        return error.message.trim().isNotEmpty
            ? error.message.trim()
            : 'Local palm matcher request failed.';
    }
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _start({bool allowRetry = true}) async {
    debugPrint(
      '[NewPayment] palm scan button pressed allowRetry=$allowRetry amount=${widget.amount} reference=${widget.reference}',
    );
    setState(() {
      _busy = true;
      _error = null;
      _palmId = null;
      _recognizedUserId = null;
      _started = true;
      _methodsError = null;
      _paymentMethods = const [];
    });
    try {
      setState(() {
        _error = null;
      });
      final palmId = await _recognizePalmLocally();
      if (palmId == null || palmId.isEmpty) {
        debugPrint('[NewPayment] palm scan ended without palm_id');
        if (!mounted) return;
        setState(() {
          _started = false;
        });
        return;
      }
      setState(() => _palmId = palmId);
      debugPrint('[NewPayment] palm recognize palm_id=$palmId');
      await _fetchPaymentMethods(palmId);
    } catch (e) {
      debugPrint('[NewPayment] palm scan fatal error=$e');
      setState(() {
        _error = e is PalmMatcherException
            ? _friendlyMatcherMessage(e)
            : _userFacingError(e);
        _started = false;
      });
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _started = false;
        });
      }
    }
  }

  void _proceed() {
    final l10n = AppLocalizations.of(context)!;
    final methodLabel = _hasMethods
        ? _methodLabel(_paymentMethods[_selectedMethodIndex])
        : l10n.palmScan;
    final selected = _hasMethods ? _paymentMethods[_selectedMethodIndex] : null;
    final paymentMethodId = _hasMethods
        ? int.tryParse(
            (selected?['payment_method_id'] ?? selected?['id'])?.toString() ??
                '',
          )
        : null;
    final customerId = _hasMethods
        ? int.tryParse(
            (selected?['customer_id'] ??
                        selected?['user_id'] ??
                        selected?['user']?['id'])
                    ?.toString() ??
                '',
          )
        : null;
    final effectiveCustomerId = customerId ?? _recognizedUserId;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PaymentProcessingScreen(
          amount: widget.amount,
          reference: widget.reference,
          methodLabel: methodLabel,
          paymentMethodId: paymentMethodId,
          customerId: effectiveCustomerId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
      children: [
        Text(
          l10n.placeYourPalm,
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),
        Text(
          l10n.placeYourPalmBody,
          style: const TextStyle(color: Color(0xFF6B7280)),
        ),
        const SizedBox(height: 18),
        Center(
          child: Container(
            width: 240,
            height: 240,
            decoration: BoxDecoration(
              color: const Color(0xFFEAF4FB),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF8AC3E3), width: 3),
            ),
            child: Center(
              child: _palmId != null
                  ? const Icon(Icons.check, size: 54, color: Color(0xFF16A34A))
                  : const Icon(
                      Icons.front_hand_outlined,
                      size: 54,
                      color: Color(0xFF1F8EC9),
                    ),
            ),
          ),
        ),
        const SizedBox(height: 18),
        Text(l10n.scanningProgress),
        const SizedBox(height: 8),
        if (_palmId != null)
          const LinearProgressIndicator(value: 1.0, minHeight: 8)
        else if (!_started)
          const LinearProgressIndicator(value: 0, minHeight: 8)
        else
          LinearProgressIndicator(value: null, minHeight: 8),
        const SizedBox(height: 14),
        if (_error != null)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFEE2E2),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFFCA5A5)),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline, color: Color(0xFFB91C1C)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${l10n.scanFailed}: ${_error!}',
                    style: const TextStyle(color: Color(0xFF7F1D1D)),
                  ),
                ),
              ],
            ),
          )
        else if (_palmId != null)
          _StatusPill(
            icon: Icons.check_circle,
            bg: const Color(0xFFEAF9F0),
            fg: const Color(0xFF16A34A),
            title: l10n.scanSuccessful,
            subtitle: l10n.readyToProceed,
          )
        else
          _StatusPill(
            icon: Icons.timelapse,
            bg: const Color(0xFFFEF9C3),
            fg: const Color(0xFFB45309),
            title: l10n.scanningInProgress,
            subtitle: l10n.scanningInProgressBody,
          ),
        if (_palmId != null) ...[
          const SizedBox(height: 14),
          if (_loadingMethods)
            _StatusPill(
              icon: Icons.sync,
              bg: const Color(0xFFEAF4FB),
              fg: const Color(0xFF1F8EC9),
              title: l10n.loadingPaymentMethodsTitle,
              subtitle: l10n.loadingPaymentMethodsBody,
            )
          else if (_methodsError != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFFECACA)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: Color(0xFFB91C1C)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _methodsError!,
                      style: const TextStyle(color: Color(0xFF7F1D1D)),
                    ),
                  ),
                ],
              ),
            )
          else if (_hasMethods) ...[
            const SizedBox(height: 6),
            Text(
              l10n.selectPaymentMethodTitle,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            ...List.generate(_paymentMethods.length, (index) {
              final method = _paymentMethods[index];
              final selected = _selectedMethodIndex == index;
              final brand = _methodBrand(method);
              final holder = _methodHolder(method);
              final maskedNumber = _methodMaskedNumber(method);
              final expiry = _methodExpiry(method);
              final trailingId =
                  (method['payment_method_id'] ?? method['id'])?.toString() ??
                  '';
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: selected
                        ? const [Color(0xFF10324A), Color(0xFF1F8EC9)]
                        : const [Color(0xFF1F2937), Color(0xFF111827)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: selected
                        ? const Color(0xFF7DD3FC)
                        : const Color(0xFF374151),
                  ),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => setState(() => _selectedMethodIndex = index),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.14),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                brand.toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ),
                            const Spacer(),
                            Icon(
                              selected
                                  ? Icons.radio_button_checked
                                  : Icons.radio_button_off,
                              color: selected
                                  ? const Color(0xFFBAE6FD)
                                  : Colors.white70,
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        Text(
                          maskedNumber,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    l10n.cardHolderLabel,
                                    style: TextStyle(
                                      color: Colors.white60,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.9,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    holder,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  l10n.expiryLabel,
                                  style: TextStyle(
                                    color: Colors.white60,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.9,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  expiry,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        if (trailingId.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Text(
                            '${l10n.paymentMethodIdPrefix}: $trailingId',
                            style: const TextStyle(
                              color: Colors.white60,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            }),
          ],
        ],
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(child: Text(l10n.transactionAmount)),
            Text(
              '${Localizations.localeOf(context).languageCode.toLowerCase() == 'ar' ? 'ر.س' : 'SAR'} ${widget.amount.toStringAsFixed(2)}',
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (_palmId != null && _hasMethods)
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _busy || _loadingMethods ? null : _proceed,
              child: Text(l10n.proceedToPayment),
            ),
          )
        else if (_palmId != null && !_loadingMethods)
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _busy ? null : _start,
              child: Text(l10n.retry),
            ),
          )
        else if (!_started)
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _busy ? null : _start,
              child: Text(l10n.startScan),
            ),
          )
        else
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _busy ? null : _start,
              child: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(l10n.retry),
            ),
          ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: OutlinedButton(
            onPressed: widget.onCancel,
            child: Text(l10n.cancelPayment),
          ),
        ),
      ],
    );
  }
}

class _NfcPay extends StatefulWidget {
  final double amount;
  final String reference;
  final VoidCallback onCancel;

  const _NfcPay({
    required this.amount,
    required this.reference,
    required this.onCancel,
  });

  @override
  State<_NfcPay> createState() => _NfcPayState();
}

class _NfcPayState extends State<_NfcPay> {
  StreamSubscription<Map<String, dynamic>>? _sub;
  String _uidHex = '';
  String _uidDec = '';
  bool _listening = false;
  bool _identifying = false;
  String? _error;
  Map<String, dynamic>? _identifiedDetails;

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _startListening() {
    if (_listening) return;
    setState(() {
      _listening = true;
      _identifying = false;
      _error = null;
      _identifiedDetails = null;
      _uidHex = '';
      _uidDec = '';
    });
    _sub = _PaymentHardwareBridge.nfcEvents().listen((event) {
      final type = event['type']?.toString() ?? '';
      if (type == 'tag') {
        final hex = event['tag_id_hex']?.toString().trim() ?? '';
        final dec = event['tag_id_dec']?.toString().trim() ?? '';
        if (!mounted) return;
        setState(() {
          _uidHex = hex;
          _uidDec = dec;
          _listening = false;
        });
        _sub?.cancel();
        _sub = null;
        unawaited(_identifyNfc());
      }
    });
  }

  Future<void> _identifyNfc() async {
    if (_uidHex.trim().isEmpty) return;
    setState(() {
      _identifying = true;
      _error = null;
      _identifiedDetails = null;
    });
    try {
      final token = await AuthService.getToken();
      final deviceId = await AuthService.getDeviceId();
      if (token == null || token.isEmpty) {
        throw Exception('Missing auth token. Please log in again.');
      }
      final res = await http.post(
        Uri.parse('$_amenPayApiBaseUrl/api/nfc/identify'),
        headers: <String, String>{
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(<String, dynamic>{
          'nfc_card_uid': _uidHex,
          'uid_hex': _uidHex,
          'uid_dec': _uidDec,
          'device_id': deviceId ?? '',
        }),
      );
      debugPrint(
        '[NewPayment] nfc identify status=${res.statusCode} body=${res.body}',
      );
      Map<String, dynamic> body = <String, dynamic>{};
      try {
        final decoded = jsonDecode(res.body);
        if (decoded is Map<String, dynamic>) {
          body = decoded;
        } else if (decoded is Map) {
          body = Map<String, dynamic>.from(decoded);
        }
      } catch (_) {}
      if (res.statusCode < 200 || res.statusCode >= 300) {
        throw Exception(
          (body['message'] ?? body['error'] ?? 'Failed to identify NFC card.')
              .toString(),
        );
      }
      if (!mounted) return;
      setState(() {
        _identifiedDetails = body;
        _identifying = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _identifying = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  void _reset() {
    setState(() {
      _uidHex = '';
      _uidDec = '';
      _identifying = false;
      _error = null;
      _identifiedDetails = null;
    });
  }

  void _proceed() {
    final l10n = AppLocalizations.of(context)!;
    final details = _identifiedDetails;
    final paymentMethodId = int.tryParse(
      (details?['payment_method_id'])?.toString() ?? '',
    );
    final customerId = int.tryParse(
      (details?['user']?['id'])?.toString() ?? '',
    );
    final methodLabel = (details?['card']?['card_type'] ?? l10n.nfcTap)
        .toString();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PaymentProcessingScreen(
          amount: widget.amount,
          reference: widget.reference,
          methodLabel: methodLabel,
          paymentMethodId: paymentMethodId,
          customerId: customerId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final hasUid = _uidHex.trim().isNotEmpty;
    final card = _identifiedDetails?['card'] is Map
        ? Map<String, dynamic>.from(_identifiedDetails!['card'] as Map)
        : null;
    final user = _identifiedDetails?['user'] is Map
        ? Map<String, dynamic>.from(_identifiedDetails!['user'] as Map)
        : null;
    final canProceed =
        !_identifying &&
        int.tryParse(
              (_identifiedDetails?['payment_method_id'])?.toString() ?? '',
            ) !=
            null &&
        int.tryParse((user?['id'])?.toString() ?? '') != null;
    final statusText = _identifying
        ? l10n.identifyingCard
        : canProceed
        ? l10n.cardIdentified
        : _listening
        ? l10n.waitingForNfcCard
        : l10n.readyToScan;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
      children: [
        Text(
          l10n.tapYourCard,
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),
        Text(
          l10n.tapYourCardBody,
          style: const TextStyle(color: Color(0xFF6B7280)),
        ),
        const SizedBox(height: 18),
        Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            width: 240,
            height: 240,
            decoration: BoxDecoration(
              color: const Color(0xFFEAF4FB),
              shape: BoxShape.circle,
              border: Border.all(
                color: canProceed
                    ? const Color(0xFF16A34A)
                    : const Color(0xFF8AC3E3),
                width: 3,
              ),
              boxShadow: [
                BoxShadow(
                  color: (_listening || _identifying)
                      ? const Color(0xFF8AC3E3).withValues(alpha: 0.28)
                      : Colors.transparent,
                  blurRadius: 24,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: Center(
              child: _identifying || _listening
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(
                          width: 42,
                          height: 42,
                          child: CircularProgressIndicator(strokeWidth: 3),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          statusText,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1F8EC9),
                          ),
                        ),
                      ],
                    )
                  : Icon(
                      hasUid ? Icons.check : Icons.wifi,
                      size: 54,
                      color: hasUid
                          ? const Color(0xFF16A34A)
                          : const Color(0xFF1F8EC9),
                    ),
            ),
          ),
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF102A43), Color(0xFF1F4E79)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [
              BoxShadow(
                color: Color(0x1A000000),
                blurRadius: 20,
                offset: Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      (card?['card_type'] ?? l10n.nfcTap).toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      statusText,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              Text(
                (card?['card_number'] ?? '**** **** **** ----').toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: _NfcDetailBlock(
                      label: l10n.cardHolderLabel,
                      value: (card?['card_holder_name'] ?? l10n.unknownPlaceholder)
                          .toString(),
                      light: true,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _NfcDetailBlock(
                      label: l10n.customerLabel,
                      value: (user?['fullname'] ?? l10n.unknownPlaceholder).toString(),
                      light: true,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Column(
            children: [
              _DetailRow(label: l10n.uid, value: hasUid ? _uidHex : '----'),
              _DetailRow(
                label: l10n.uidDecShort,
                value: _uidDec.trim().isNotEmpty ? _uidDec : '----',
              ),
              _DetailRow(
                label: l10n.paymentMethodShort,
                value: (_identifiedDetails?['payment_method_id'] ?? '----')
                    .toString(),
              ),
              _DetailRow(
                label: l10n.customerIdLabel.trim(),
                value: (user?['id'] ?? '----').toString(),
              ),
              _DetailRow(
                label: l10n.nfcStatusLabel,
                value: (_identifiedDetails?['nfc']?['status'] ?? '----')
                    .toString(),
              ),
            ],
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(_error!, style: const TextStyle(color: Color(0xFFB91C1C))),
        ],
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: (_listening || _identifying)
                ? null
                : () {
                    _reset();
                    _startListening();
                  },
            child: (_listening || _identifying)
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        _identifying ? l10n.identifyingCardProgress : l10n.scanningProgressShort,
                      ),
                    ],
                  )
                : Text(hasUid ? l10n.startNewScan : l10n.startScan),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: canProceed ? _proceed : null,
            child: Text(l10n.proceedToPayment),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: OutlinedButton(
            onPressed: widget.onCancel,
            child: Text(l10n.cancelPayment),
          ),
        ),
      ],
    );
  }
}

class _NfcDetailBlock extends StatelessWidget {
  final String label;
  final String value;
  final bool light;

  const _NfcDetailBlock({
    required this.label,
    required this.value,
    this.light = false,
  });

  @override
  Widget build(BuildContext context) {
    final labelColor = light ? Colors.white70 : const Color(0xFF6B7280);
    final valueColor = light ? Colors.white : const Color(0xFF111827);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: labelColor, fontSize: 12)),
        const SizedBox(height: 4),
        Text(
          value,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: valueColor, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

class _QrPay extends StatefulWidget {
  final double amount;
  final String reference;
  final VoidCallback onCancel;

  const _QrPay({
    required this.amount,
    required this.reference,
    required this.onCancel,
  });

  @override
  State<_QrPay> createState() => _QrPayState();
}

class _QrPayState extends State<_QrPay> {
  bool _busy = false;
  String? _error;
  String _payload = '';
  String _source = '';
  bool _identified = false;
  bool _loadingDetails = false;
  Map<String, dynamic>? _qrDetails;

  StreamSubscription<Map<String, dynamic>>? _sub;
  Timer? _timeout;

  @override
  void initState() {
    super.initState();
    _startStream();
  }

  @override
  void dispose() {
    _timeout?.cancel();
    _sub?.cancel();
    super.dispose();
  }

  void _armTimeout() {
    _timeout?.cancel();
    _timeout = Timer(const Duration(seconds: 15), () {
      if (!mounted) return;
      if (_identified) return;
      final l10n = AppLocalizations.of(context)!;
      setState(() {
        _busy = false;
        _error = l10n.qrScanTimedOut;
      });
    });
  }

  void _startStream() {
    _timeout?.cancel();
    _sub?.cancel();

    setState(() {
      _busy = true;
      _error = null;
      _payload = '';
      _source = '';
      _identified = false;
      _loadingDetails = false;
      _qrDetails = null;
    });

    _armTimeout();
    _sub = _PaymentHardwareBridge.qrEvents().listen(
      (event) {
        final type = event['type']?.toString() ?? '';
        final payload = event['payload']?.toString() ?? '';
        final source = event['source']?.toString() ?? '';

        final isError = type == 'error';
        final isSuccess = type == 'success' || payload.trim().isNotEmpty;

        if (isSuccess) {
          if (!mounted) return;
          if (payload.trim().isEmpty) return;
          _timeout?.cancel();
          debugPrint('[NewPayment] qr payload len=${payload.trim().length}');
          setState(() {
            _busy = false;
            _error = null;
            _payload = payload.trim();
            _source = source.trim();
            _identified = true;
            _loadingDetails = true;
          });
          _sub?.cancel();
          _sub = null;
          _fetchQrDetails(_payload);
          return;
        }

        if (isError) {
          final msg = event['message']?.toString() ?? '';
          if (!mounted) return;
          setState(() {
            _busy = false;
            _error = msg.isEmpty ? 'QR event error' : msg;
          });
        }
      },
      onError: (Object error, StackTrace _) {
        if (!mounted) return;
        setState(() {
          _busy = false;
          _error = error.toString();
        });
      },
    );
  }

  void _restartScan() {
    if (_sub == null) {
      _startStream();
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _payload = '';
      _source = '';
      _identified = false;
      _loadingDetails = false;
      _qrDetails = null;
    });
    _armTimeout();
  }

  Future<void> _fetchQrDetails(String qrData) async {
    try {
      final payload = qrData.trim();
      debugPrint('[NewPayment] qr lookup payload=$payload');
      debugPrint('[NewPayment] qr lookup payload_len=${payload.length}');
      if (payload.startsWith('data:image/')) {
        if (!mounted) return;
        setState(() {
          _loadingDetails = false;
          _error = 'Scanner returned QR image data instead of decoded QR text.';
        });
        return;
      }
      final token = await AuthService.getToken();
      if (token == null || token.isEmpty) {
        if (!mounted) return;
        setState(() {
          _loadingDetails = false;
          _error = 'Missing auth token. Please log in again.';
        });
        return;
      }
      final url = Uri.parse('$_amenPayApiBaseUrl/api/payment-methods/qr');
      debugPrint('[NewPayment] qr lookup request qr_payload=$payload');
      final requestBody = jsonEncode(<String, String>{'qr_payload': payload});
      final res = await http.post(
        url,
        headers: <String, String>{
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
        body: requestBody,
      );
      debugPrint(
        '[NewPayment] qr lookup status=${res.statusCode} body=${res.body}',
      );
      Map<String, dynamic> body = <String, dynamic>{};
      try {
        final decoded = jsonDecode(res.body);
        if (decoded is Map<String, dynamic>) {
          body = decoded;
        } else if (decoded is Map) {
          body = Map<String, dynamic>.from(decoded);
        } else {
          body = <String, dynamic>{'data': decoded};
        }
      } catch (_) {
        body = <String, dynamic>{'raw': res.body};
      }
      if (res.statusCode < 200 || res.statusCode >= 300) {
        final message = (body['message'] ?? body['error'] ?? body['detail'])
            ?.toString()
            .trim();
        if (!mounted) return;
        setState(() {
          _loadingDetails = false;
          _error = message?.isNotEmpty == true
              ? message
              : 'Failed to load payment method.';
        });
        return;
      }
      if (!mounted) return;
      setState(() {
        _loadingDetails = false;
        _qrDetails = body;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingDetails = false;
        _error = e.toString();
      });
    }
  }

  void _proceed() {
    final l10n = AppLocalizations.of(context)!;
    final details = _qrDetails;
    final methodLabel = details == null
        ? l10n.qrCode
        : (details['payment_method']?['label'] ??
                  details['payment_method']?['name'] ??
                  details['card']?['brand'] ??
                  l10n.qrCode)
              .toString();
    final paymentMethodId = int.tryParse(
      (details?['payment_method']?['id'] ??
                  details?['payment_method']?['payment_method_id'])
              ?.toString() ??
          '',
    );
    final customerId = int.tryParse(
      (details?['user']?['id'] ?? details?['customer']?['id'])?.toString() ??
          '',
    );
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PaymentProcessingScreen(
          amount: widget.amount,
          reference: widget.reference,
          methodLabel: methodLabel,
          paymentMethodId: paymentMethodId,
          customerId: customerId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
      children: [
        Text(
          _identified ? l10n.qrPaymentResultTitle : l10n.qrPaymentTitle,
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),
        if (!_identified) ...[
          Text(
            l10n.qrPaymentBody,
            style: const TextStyle(color: Color(0xFF6B7280)),
          ),
          const SizedBox(height: 18),
          Container(
            height: 220,
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: Center(
                    child: Container(
                      width: 210,
                      height: 210,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: const Color(0xFF1F8EC9),
                          width: 3,
                        ),
                      ),
                    ),
                  ),
                ),
                const PositionedDirectional(
                  top: 12,
                  start: 12,
                  child: Icon(Icons.flash_on, color: Colors.white),
                ),
                const PositionedDirectional(
                  top: 12,
                  end: 12,
                  child: Icon(Icons.cameraswitch, color: Colors.white),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _StatusPill(
            icon: Icons.qr_code_2,
            bg: Colors.white,
            fg: const Color(0xFF1F8EC9),
            title: l10n.scanningActive,
            subtitle: _busy ? l10n.waitingForQr : l10n.tapToRetry,
          ),
          const SizedBox(height: 12),
          if (_error != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFFCA5A5)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: Color(0xFFB91C1C)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${l10n.scanFailed}: ${_error!}',
                      style: const TextStyle(color: Color(0xFF7F1D1D)),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _busy ? null : _restartScan,
              child: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(l10n.retry),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: OutlinedButton(
              onPressed: widget.onCancel,
              child: Text(l10n.cancelPayment),
            ),
          ),
        ] else ...[
          _CustomerIdentifiedCard(details: _qrDetails),
          const SizedBox(height: 10),
          if (_loadingDetails)
            _StatusPill(
              icon: Icons.sync,
              bg: const Color(0xFFEAF4FB),
              fg: const Color(0xFF1F8EC9),
              title: l10n.fetchingPaymentMethodTitle,
              subtitle: l10n.pleaseWaitShort,
            )
          else if (_qrDetails != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.paymentMethodDetailsTitle,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 10),
                  _DetailRow(
                    label: l10n.cardHolderLabel,
                    value: (_qrDetails?['card']?['card_holder_name'] ?? '-')
                        .toString(),
                  ),
                  _DetailRow(
                    label: l10n.cardNumberLabel,
                    value: (_qrDetails?['card']?['card_number'] ?? '-')
                        .toString(),
                  ),
                  _DetailRow(
                    label: l10n.cardType,
                    value: (_qrDetails?['card']?['card_type'] ?? '-')
                        .toString(),
                  ),
                  _DetailRow(
                    label: l10n.expiryLabel,
                    value: (_qrDetails?['card']?['expiry_date'] ?? '-')
                        .toString(),
                  ),
                  _DetailRow(
                    label: l10n.paymentMethodIdLabel,
                    value: (_qrDetails?['payment_method']?['id'] ?? '-')
                        .toString(),
                  ),
                ],
              ),
            )
          else if (_error != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFFCA5A5)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: Color(0xFFB91C1C)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${l10n.scanFailed}: ${_error!}',
                      style: const TextStyle(color: Color(0xFF7F1D1D)),
                    ),
                  ),
                ],
              ),
            ),
          if (_payload.trim().isNotEmpty)
            Text(
              '${l10n.qrPayloadShort}: ${_redact(_payload)}',
              style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12),
            ),
          if (_source.trim().isNotEmpty)
            Text(
              '${l10n.sourceLabel}: $_source',
              style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12),
            ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _loadingDetails ? null : _proceed,
              child: Text(l10n.proceedToPayment),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: OutlinedButton(
              onPressed: _busy ? null : _restartScan,
              child: Text(l10n.scanAnotherQr),
            ),
          ),
        ],
      ],
    );
  }

  String _redact(String value) {
    final v = value.trim();
    if (v.isEmpty) return '';
    if (v.length <= 10) return '*' * v.length;
    return '${v.substring(0, 6)}...${v.substring(v.length - 4)}';
  }
}

class _CustomerIdentifiedCard extends StatelessWidget {
  final Map<String, dynamic>? details;

  const _CustomerIdentifiedCard({this.details});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final user = details?['user'] as Map<String, dynamic>?;
    final fullName = (user?['fullname'] ?? l10n.customerLabel).toString();
    final initials = _initialsFor(fullName);
    final userId = (user?['id'] ?? '').toString();
    final email = (user?['email'] ?? '').toString();
    final phone = (user?['phone'] ?? '').toString();

    return Column(
      children: [
        const SizedBox(height: 8),
        Container(
          width: 92,
          height: 92,
          decoration: const BoxDecoration(
            color: Color(0xFF22C55E),
            shape: BoxShape.circle,
          ),
          child: const Center(
            child: Icon(Icons.check, size: 44, color: Colors.white),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          l10n.customerIdentified,
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6),
        Text(
          l10n.qrScannedSuccessfully,
          style: const TextStyle(color: Color(0xFF6B7280)),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: const Color(0xFFEAF4FB),
                child: Text(
                  initials,
                  style: TextStyle(
                    color: const Color(0xFF1F8EC9),
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            fullName,
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                        ),
                        const Icon(
                          Icons.verified,
                          color: Color(0xFF16A34A),
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          l10n.verified,
                          style: const TextStyle(
                            color: Color(0xFF16A34A),
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      userId.isEmpty
                          ? l10n.customerIdLabel
                          : '${l10n.customerIdLabel} #$userId',
                      style: const TextStyle(
                        color: Color(0xFF6B7280),
                        fontSize: 12,
                      ),
                    ),
                    if (email.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        email,
                        style: const TextStyle(
                          color: Color(0xFF6B7280),
                          fontSize: 12,
                        ),
                      ),
                    ],
                    if (phone.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        phone,
                        style: const TextStyle(
                          color: Color(0xFF6B7280),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _initialsFor(String value) {
    final parts = value
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .toList();
    if (parts.isEmpty) return 'CU';
    return parts.map((part) => part[0].toUpperCase()).join();
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class PaymentProcessingScreen extends StatefulWidget {
  final double amount;
  final String reference;
  final String methodLabel;
  final int? paymentMethodId;
  final int? customerId;
  final String paymentApiPath;

  const PaymentProcessingScreen({
    super.key,
    required this.amount,
    required this.reference,
    required this.methodLabel,
    this.paymentMethodId,
    this.customerId,
    this.paymentApiPath = '/api/palm/pay',
  });

  @override
  State<PaymentProcessingScreen> createState() =>
      _PaymentProcessingScreenState();
}

class _PaymentProcessingScreenState extends State<PaymentProcessingScreen> {
  int _stage = 0; // 0..2
  bool _submitting = false;
  String? _error;
  String? _info;
  String? _paymentStatus;
  String? _redirectUrl;
  Map<String, dynamic>? _paymentResponse;

  @override
  void initState() {
    super.initState();
    _tick();
  }

  Future<void> _tick() async {
    setState(() {
      _stage = 0;
      _error = null;
      _info = null;
      _paymentStatus = null;
      _redirectUrl = null;
      _paymentResponse = null;
      _submitting = widget.paymentMethodId != null;
    });
    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    setState(() => _stage = 1);
    if (widget.paymentMethodId != null) {
      final outcome = await _submitPayment();
      if (!mounted || outcome != _PaymentSubmitOutcome.success) return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 850));
    if (!mounted) return;
    setState(() => _stage = 2);
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => PaymentSuccessScreen(
          amount: widget.amount,
          reference: widget.reference,
          methodLabel: widget.methodLabel,
          customerId: widget.customerId,
        ),
      ),
    );
  }

  Future<_PaymentSubmitOutcome> _submitPayment() async {
    try {
      if (widget.customerId == null) {
        setState(() {
          _error = AppLocalizations.of(context)!.missingCustomerIdPayment;
          _submitting = false;
        });
        return _PaymentSubmitOutcome.failure;
      }
      final token = await AuthService.getToken();
      if (token == null || token.isEmpty) {
        setState(() {
          _error = 'Missing auth token. Please log in again.';
          _submitting = false;
        });
        return _PaymentSubmitOutcome.failure;
      }
      final deviceId = await AuthService.getDeviceId();
      final url = Uri.parse('$_amenPayApiBaseUrl${widget.paymentApiPath}');
      final body = <String, dynamic>{
        'payment_method_id': widget.paymentMethodId,
        'amount': widget.amount,
        'currency': 'SAR',
        'customer_id': widget.customerId,
        'device_id': deviceId ?? '',
      };
      debugPrint('[NewPayment] pay request body=${jsonEncode(body)}');
      final res = await http.post(
        url,
        headers: <String, String>{
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(body),
      );
      debugPrint(
        '[NewPayment] pay response status=${res.statusCode} body=${res.body}',
      );
      Map<String, dynamic> decoded = <String, dynamic>{};
      try {
        final raw = jsonDecode(res.body);
        if (raw is Map<String, dynamic>) {
          decoded = raw;
        } else if (raw is Map) {
          decoded = Map<String, dynamic>.from(raw);
        }
      } catch (_) {}
      if (res.statusCode < 200 || res.statusCode >= 300) {
        setState(() {
          _error = (decoded['message'] ?? decoded['error'] ?? 'Payment failed.')
              .toString();
          _submitting = false;
        });
        return _PaymentSubmitOutcome.failure;
      }
      final status = (decoded['status'] ?? '').toString().trim().toLowerCase();
      final redirectUrl = (decoded['redirect_url'] ?? decoded['url'] ?? '')
          .toString()
          .trim();
      setState(() {
        _paymentResponse = decoded;
        _paymentStatus = status;
        _redirectUrl = redirectUrl.isEmpty ? null : redirectUrl;
        _submitting = false;
      });
      if (status == 'paid' ||
          status == 'succeeded' ||
          status == 'success' ||
          status == 'initiated') {
        return _PaymentSubmitOutcome.success;
      }
      setState(() {
        _info = (decoded['message'] ??
                AppLocalizations.of(context)!.paymentPendingFurtherAction)
            .toString();
      });
      return _PaymentSubmitOutcome.pending;
    } catch (e) {
      if (!mounted) return _PaymentSubmitOutcome.failure;
      setState(() {
        _error = e.toString();
        _submitting = false;
      });
      return _PaymentSubmitOutcome.failure;
    }
  }

  Future<void> _recheckPayment() async {
    try {
      if (widget.customerId == null) {
        setState(() {
          _error = AppLocalizations.of(context)!.missingCustomerIdLookup;
        });
        return;
      }
      setState(() {
        _submitting = true;
        _error = null;
      });
      final token = await AuthService.getToken();
      if (token == null || token.isEmpty) {
        setState(() {
          _error = 'Missing auth token. Please log in again.';
          _submitting = false;
        });
        return;
      }
      final url = Uri.parse('$_amenPayApiBaseUrl/api/transactions/latest')
          .replace(
            queryParameters: <String, String>{
              'customer_id': widget.customerId.toString(),
            },
          );
      debugPrint(
        '[NewPayment] latest transaction request customer_id=${widget.customerId}',
      );
      final res = await http.get(
        url,
        headers: <String, String>{
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );
      debugPrint(
        '[NewPayment] latest transaction response status=${res.statusCode} body=${res.body}',
      );
      Map<String, dynamic> decoded = <String, dynamic>{};
      try {
        final raw = jsonDecode(res.body);
        if (raw is Map<String, dynamic>) {
          decoded = raw;
        } else if (raw is Map) {
          decoded = Map<String, dynamic>.from(raw);
        }
      } catch (_) {}
      if (res.statusCode < 200 || res.statusCode >= 300) {
        setState(() {
          _error =
              (decoded['message'] ??
                      decoded['error'] ??
                      AppLocalizations.of(context)!.failedFetchLatestTransaction)
                  .toString();
          _submitting = false;
        });
        return;
      }
      final transaction = (decoded['transaction'] is Map)
          ? Map<String, dynamic>.from(decoded['transaction'])
          : null;
      final status = (transaction?['status'] ?? '')
          .toString()
          .trim()
          .toLowerCase();
      setState(() {
        _paymentResponse = decoded;
        _paymentStatus = status;
        _info = transaction == null
            ? AppLocalizations.of(context)!.latestTransactionFetched
            : AppLocalizations.of(context)!.latestTransactionStatus(status);
        _submitting = false;
      });
      if (status == 'paid' ||
          status == 'succeeded' ||
          status == 'success' ||
          status == 'initiated') {
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => PaymentSuccessScreen(
              amount: widget.amount,
              reference: widget.reference,
              methodLabel: widget.methodLabel,
              customerId: widget.customerId,
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _submitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.processingTitle),
        automaticallyImplyLeading: false,
      ),
      body: Container(
        color: const Color(0xFFEFF7FB),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF4FB),
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 26,
                      offset: const Offset(0, 16),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.75),
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFFBFE3F7)),
                      ),
                      child: const Center(
                        child: Icon(Icons.settings, color: Color(0xFF1F8EC9)),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      l10n.processingTitle,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 6),
                    if (_error == null)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(l10n.pleaseWait),
                          const SizedBox(width: 8),
                          const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ],
                      )
                    else
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Color(0xFFB91C1C)),
                      ),
                    if (_info != null && _error == null) ...[
                      const SizedBox(height: 8),
                      Text(
                        _info!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Color(0xFF0F766E)),
                      ),
                    ],
                    const SizedBox(height: 14),
                    _ProcessRow(
                      done: _stage >= 0,
                      active: _stage == 0,
                      title: l10n.requestReceived,
                    ),
                    const SizedBox(height: 10),
                    _ProcessRow(
                      done: _error == null && _stage >= 1,
                      active: _stage == 1,
                      title: widget.paymentMethodId != null
                          ? l10n.processingSubmittingPayment
                          : l10n.analyzingData,
                    ),
                    const SizedBox(height: 10),
                    _ProcessRow(
                      done: _error == null && _stage >= 2,
                      active: _stage == 2,
                      title: l10n.preparingResults,
                    ),
                    if (_paymentStatus != null) ...[
                      const SizedBox(height: 12),
                      _DetailRow(
                        label: l10n.paymentStatusLabel,
                        value: _paymentStatus!,
                      ),
                    ],
                    if (_paymentResponse != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        (_paymentResponse!['message'] ??
                                l10n.paymentSubmittedSuccessfully)
                            .toString(),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFF0F766E),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                    if (_redirectUrl != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE5E7EB)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.authenticationUrl,
                              style: const TextStyle(fontWeight: FontWeight.w900),
                            ),
                            const SizedBox(height: 6),
                            SelectableText(
                              _redirectUrl!,
                              style: const TextStyle(
                                color: Color(0xFF6B7280),
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Align(
                              alignment: Alignment.centerRight,
                              child: OutlinedButton.icon(
                                onPressed: () async {
                                  await Clipboard.setData(
                                    ClipboardData(text: _redirectUrl!),
                                  );
                                  if (!mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(l10n.authenticationUrlCopied),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.copy),
                                label: Text(l10n.copyUrl),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Text(
                      _error == null
                          ? (_redirectUrl == null
                                ? l10n.processingNote
                                : l10n.completeAuthenticationBody)
                          : l10n.fixPaymentIssueBody,
                      style: const TextStyle(
                        color: Color(0xFF6B7280),
                        fontSize: 12,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    if (_error != null)
                      OutlinedButton.icon(
                        onPressed: _submitting
                            ? null
                            : () {
                                Navigator.of(context).pushAndRemoveUntil(
                                  MaterialPageRoute(
                                    builder: (_) => const NewPaymentScreen(),
                                  ),
                                  (route) => route.isFirst,
                                );
                              },
                        icon: const Icon(Icons.refresh),
                        label: Text(l10n.retry),
                      )
                    else if (_redirectUrl != null)
                      OutlinedButton.icon(
                        onPressed: _submitting ? null : _recheckPayment,
                        icon: const Icon(Icons.refresh),
                        label: Text(l10n.recheckPayment),
                      )
                    else
                      OutlinedButton.icon(
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                        icon: const Icon(Icons.close),
                        label: Text(l10n.cancelRequest),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

enum _PaymentSubmitOutcome { success, pending, failure }

class _ProcessRow extends StatelessWidget {
  final bool done;
  final bool active;
  final String title;

  const _ProcessRow({
    required this.done,
    required this.active,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    final bg = active
        ? const Color(0xFFEAF9F0)
        : Colors.white.withValues(alpha: 0.65);
    final icon = done
        ? const Icon(Icons.check_circle, color: Color(0xFF1F8EC9))
        : const Icon(Icons.radio_button_unchecked, color: Color(0xFF9CA3AF));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          icon,
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class PaymentSuccessScreen extends StatefulWidget {
  final double amount;
  final String reference;
  final String methodLabel;
  final int? customerId;

  const PaymentSuccessScreen({
    super.key,
    required this.amount,
    required this.reference,
    required this.methodLabel,
    this.customerId,
  });

  @override
  State<PaymentSuccessScreen> createState() => _PaymentSuccessScreenState();
}

class _PaymentSuccessScreenState extends State<PaymentSuccessScreen> {
  Map<String, dynamic>? _transaction;
  String? _latestError;

  @override
  void initState() {
    super.initState();
    _loadLatestTransaction();
  }

  Future<void> _loadLatestTransaction() async {
    try {
      if (widget.customerId == null) {
        setState(() {
          _latestError = AppLocalizations.of(context)!.missingCustomerIdLookup;
        });
        return;
      }
      final token = await AuthService.getToken();
      if (token == null || token.isEmpty) {
        setState(() {
          _latestError = 'Missing auth token. Please log in again.';
        });
        return;
      }
      final url = Uri.parse('$_amenPayApiBaseUrl/api/transactions/latest')
          .replace(
            queryParameters: <String, String>{
              'customer_id': widget.customerId.toString(),
            },
          );
      debugPrint(
        '[NewPayment] payment result latest transaction request customer_id=${widget.customerId}',
      );
      final res = await http.get(
        url,
        headers: <String, String>{
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );
      debugPrint(
        '[NewPayment] payment result latest transaction response status=${res.statusCode} body=${res.body}',
      );
      Map<String, dynamic> decoded = <String, dynamic>{};
      try {
        final raw = jsonDecode(res.body);
        if (raw is Map<String, dynamic>) {
          decoded = raw;
        } else if (raw is Map) {
          decoded = Map<String, dynamic>.from(raw);
        }
      } catch (_) {}
      if (res.statusCode < 200 || res.statusCode >= 300) {
        setState(() {
          _latestError =
              (decoded['message'] ??
                      decoded['error'] ??
                      AppLocalizations.of(context)!.failedFetchLatestTransaction)
                  .toString();
        });
        return;
      }
      setState(() {
        _transaction = (decoded['transaction'] is Map)
            ? Map<String, dynamic>.from(decoded['transaction'])
            : null;
        _latestError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _latestError = e.toString();
      });
    }
  }

  String _formatTime(dynamic value) {
    final text = value?.toString().trim() ?? '';
    if (text.isEmpty) {
      final now = DateTime.now();
      return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} '
          '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    }
    return text;
  }

  ReceiptPreviewData _receiptData(String currencyLabel) {
    final transaction = _transaction;
    return ReceiptPreviewData(
      headerTitle: AppLocalizations.of(context)!.paymentReceiptTitle,
      amountText:
          '$currencyLabel ${transaction?['amount']?.toString() ?? widget.amount.toStringAsFixed(2)}',
      referenceId: (transaction?['id'] ?? widget.reference).toString(),
      timeText: _formatTime(transaction?['created_at']),
      methodLabel: widget.methodLabel,
      status: (transaction?['status'] ?? 'SUCCESS').toString().toUpperCase(),
      merchantLabel:
          (transaction?['card_holder_name'] ??
                  AppLocalizations.of(context)!.defaultCustomerName)
          .toString(),
      cardLabel:
          (transaction?['card_number'] ??
                  AppLocalizations.of(context)!.defaultCardPayment)
              .toString(),
      customerLabel:
          (transaction?['card_holder_name'] ??
                  AppLocalizations.of(context)!.defaultCustomerName)
          .toString(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isArabic =
        Localizations.localeOf(context).languageCode.toLowerCase() == 'ar';
    final currencyLabel = isArabic ? 'ر.س' : 'SAR';
    final transaction = _transaction;
    final txnId = (transaction?['id'] ?? widget.reference).toString();
    final amountText =
        transaction?['amount']?.toString() ?? widget.amount.toStringAsFixed(2);
    final timeText = _formatTime(transaction?['created_at']);
    final methodText = widget.methodLabel;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.paymentResultTitle),
        automaticallyImplyLeading: false,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 20),
        children: [
          Center(
            child: Container(
              width: 96,
              height: 96,
              decoration: const BoxDecoration(
                color: Color(0xFFD1FAE5),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Icon(Icons.check, size: 44, color: Color(0xFF16A34A)),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            l10n.paymentSuccessfulTitle,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            l10n.paymentSuccessfulBody,
            style: const TextStyle(color: Color(0xFF6B7280)),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Column(
              children: [
                _KvpRow(
                  label: l10n.amountPaid,
                  value: '$currencyLabel $amountText',
                ),
                _KvpRow(label: l10n.referenceId, value: txnId),
                _KvpRow(label: l10n.transactionTime, value: timeText),
                _KvpRow(label: l10n.paymentMethodLabel, value: methodText),
                if (transaction?['status'] != null)
                  _KvpRow(
                    label: l10n.statusLabel,
                    value: transaction!['status'].toString(),
                  ),
                if (transaction?['moyasar_id'] != null)
                  _KvpRow(
                    label: l10n.moyasarIdLabel,
                    value: transaction!['moyasar_id'].toString(),
                  ),
                if (transaction?['card_number'] != null)
                  _KvpRow(
                    label: l10n.cardNumberLabel,
                    value: transaction!['card_number'].toString(),
                  ),
                if (transaction?['card_holder_name'] != null)
                  _KvpRow(
                    label: l10n.cardHolderLabel,
                    value: transaction!['card_holder_name'].toString(),
                  ),
              ],
            ),
          ),
          if (_latestError != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFFCA5A5)),
              ),
              child: Text(
                _latestError!,
                style: const TextStyle(color: Color(0xFF7F1D1D)),
              ),
            ),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ReceiptPreviewScreen(
                      receipt: _receiptData(currencyLabel),
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.print_outlined),
              label: Text(l10n.printReceipt),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: OutlinedButton(
              onPressed: () {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const HomeScreen()),
                  (route) => false,
                );
              },
              child: Text(l10n.backToHome),
            ),
          ),
        ],
      ),
    );
  }
}

class _KvpRow extends StatelessWidget {
  final String label;
  final String value;

  const _KvpRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: Color(0xFF6B7280)),
            ),
          ),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final IconData icon;
  final Color bg;
  final Color fg;
  final String title;
  final String subtitle;

  const _StatusPill({
    required this.icon,
    required this.bg,
    required this.fg,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, color: fg),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Color(0xFF6B7280),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentHardwareBridge {
  static const EventChannel _qrScannerEvents = EventChannel('qrScanner/events');
  static const EventChannel _nfcScannerEvents = EventChannel(
    'nfcScanner/events',
  );

  static Stream<Map<String, dynamic>> qrEvents() {
    return _qrScannerEvents.receiveBroadcastStream().map((event) {
      if (event is Map) return Map<String, dynamic>.from(event);
      return <String, dynamic>{};
    });
  }

  static Stream<Map<String, dynamic>> nfcEvents() {
    return _nfcScannerEvents.receiveBroadcastStream().map((event) {
      if (event is Map) return Map<String, dynamic>.from(event);
      return <String, dynamic>{};
    });
  }
}
