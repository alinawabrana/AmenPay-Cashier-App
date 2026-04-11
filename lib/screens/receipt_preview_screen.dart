import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:amenpay_cashir_app/l10n/app_localizations.dart';

class ReceiptPreviewData {
  final String headerTitle;
  final String amountText;
  final String referenceId;
  final String timeText;
  final String methodLabel;
  final String status;
  final String merchantLabel;
  final String cardLabel;
  final String customerLabel;

  const ReceiptPreviewData({
    required this.headerTitle,
    required this.amountText,
    required this.referenceId,
    required this.timeText,
    required this.methodLabel,
    required this.status,
    required this.merchantLabel,
    required this.cardLabel,
    required this.customerLabel,
  });

  String toPrintableText() {
    return <String>[
      'AMENPAY POS RECEIPT',
      headerTitle,
      '------------------------------',
      'Amount: $amountText',
      'Reference: $referenceId',
      'Time: $timeText',
      'Method: $methodLabel',
      'Status: $status',
      'Merchant: $merchantLabel',
      'Card: $cardLabel',
      'Customer: $customerLabel',
      '------------------------------',
      'Thank you for using AmenPay',
    ].join('\n');
  }
}

class ReceiptPreviewScreen extends StatefulWidget {
  final ReceiptPreviewData receipt;

  const ReceiptPreviewScreen({super.key, required this.receipt});

  @override
  State<ReceiptPreviewScreen> createState() => _ReceiptPreviewScreenState();
}

class _ReceiptPreviewScreenState extends State<ReceiptPreviewScreen> {
  static const MethodChannel _printerMethods = MethodChannel(
    'receiptPrinter/methods',
  );

  bool _printing = false;

  Future<void> _printReceipt() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _printing = true);
    try {
      await _printerMethods
          .invokeMethod<dynamic>('printTextReceipt', <String, dynamic>{
            'job_name': 'AmenPay Receipt ${widget.receipt.referenceId}',
            'text': widget.receipt.toPrintableText(),
          });
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.receiptPrintJobSent)));
    } on PlatformException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? l10n.receiptPrintFailed)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.receiptPrintFailed)));
    } finally {
      if (mounted) setState(() => _printing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final receipt = widget.receipt;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.receiptPreviewTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE5E7EB)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.receiptBrandHeader,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  receipt.headerTitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF6B7280),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 16),
                _ReceiptRow(
                  label: l10n.receiptAmountLabel,
                  value: receipt.amountText,
                  strong: true,
                ),
                _ReceiptRow(
                  label: l10n.referenceLabel,
                  value: receipt.referenceId,
                ),
                _ReceiptRow(
                  label: l10n.receiptTimeLabel,
                  value: receipt.timeText,
                ),
                _ReceiptRow(
                  label: l10n.receiptMethodLabel,
                  value: receipt.methodLabel,
                ),
                _ReceiptRow(
                  label: l10n.receiptStatusLabel,
                  value: receipt.status,
                ),
                _ReceiptRow(
                  label: l10n.receiptMerchantLabel,
                  value: receipt.merchantLabel,
                ),
                _ReceiptRow(
                  label: l10n.receiptCardLabel,
                  value: receipt.cardLabel,
                ),
                _ReceiptRow(
                  label: l10n.receiptCustomerLabel,
                  value: receipt.customerLabel,
                ),
                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 12),
                Text(
                  l10n.receiptPreviewBody,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xFF6B7280)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _printing ? null : _printReceipt,
              icon: _printing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.print_outlined),
              label: Text(
                _printing ? l10n.receiptPrinting : l10n.receiptPrintButton,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReceiptRow extends StatelessWidget {
  final String label;
  final String value;
  final bool strong;

  const _ReceiptRow({
    required this.label,
    required this.value,
    this.strong = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 86,
            child: Text(
              label,
              style: const TextStyle(color: Color(0xFF6B7280)),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontWeight: strong ? FontWeight.w900 : FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
