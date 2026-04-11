import 'package:amenpay_cashir_app/l10n/app_localizations.dart';
import 'package:amenpay_cashir_app/screens/receipt_preview_screen.dart';
import 'package:amenpay_cashir_app/screens/transactions_screen.dart';
import 'package:flutter/material.dart';

class TransactionDetailsScreen extends StatelessWidget {
  final TxnItem txn;

  const TransactionDetailsScreen({super.key, required this.txn});

  ReceiptPreviewData _receiptData(AppLocalizations l10n, String currencyLabel) {
    final status = switch (txn.status) {
      TxnStatus.completed => 'COMPLETED',
      TxnStatus.pending => 'PENDING',
      TxnStatus.failed => 'FAILED',
    };
    return ReceiptPreviewData(
      headerTitle: l10n.receiptTransactionTitle,
      amountText: '$currencyLabel ${txn.amount.toStringAsFixed(2)}',
      referenceId: txn.referenceId,
      timeText: _formatDateTime(txn.at),
      methodLabel: txn.paymentMethod,
      status: status,
      merchantLabel: txn.counterpartyName,
      cardLabel: txn.merchant,
      customerLabel: txn.counterpartyName,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isArabic =
        Localizations.localeOf(context).languageCode.toLowerCase() == 'ar';
    final currencyLabel = isArabic ? 'ر.س' : 'SAR';
    final failed = txn.status == TxnStatus.failed;
    final pending = txn.status == TxnStatus.pending;

    final statusTitle = failed
        ? l10n.transactionFailedTitle
        : pending
        ? l10n.transactionPendingTitle
        : l10n.transactionCompletedTitle;

    final statusBody = failed
        ? l10n.transactionFailedBody
        : pending
        ? l10n.transactionPendingBody
        : l10n.transactionCompletedBody;

    final statusBg = failed
        ? const Color(0xFFFEE2E2)
        : pending
        ? const Color(0xFFFEF3C7)
        : const Color(0xFFD1FAE5);
    final statusBorder = failed
        ? const Color(0xFFFCA5A5)
        : pending
        ? const Color(0xFFFCD34D)
        : const Color(0xFF86EFAC);
    final statusFg = failed
        ? const Color(0xFFB91C1C)
        : pending
        ? const Color(0xFFB45309)
        : const Color(0xFF065F46);
    final statusIcon = failed
        ? Icons.close
        : pending
        ? Icons.timelapse
        : Icons.check;

    final subtotal = txn.amount;
    const serviceFee = 0.0;
    const tax = 0.0;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.transactionDetailsTitle),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: statusBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: statusBorder),
            ),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(statusIcon, color: statusFg),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        statusTitle,
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          color: statusFg,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(statusBody, style: TextStyle(color: statusFg)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Center(
            child: Column(
              children: [
                Text(
                  l10n.amount,
                  style: const TextStyle(color: Color(0xFF6B7280)),
                ),
                const SizedBox(height: 8),
                Text(
                  '$currencyLabel ${txn.amount.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 32,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  currencyLabel,
                  style: const TextStyle(color: Color(0xFF6B7280)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _Card(
            title: l10n.transactionInformationTitle,
            child: Column(
              children: [
                _RowKV(label: l10n.transactionIdLabel, value: txn.referenceId),
                _RowKV(
                  label: l10n.dateTimeLabel,
                  value: _formatDateTime(txn.at),
                ),
                _RowKV(label: l10n.merchantLabel, value: txn.counterpartyName),
                _RowKV(
                  label: l10n.paymentMethodLabel,
                  value: txn.paymentMethod,
                ),
                _RowKV(label: l10n.cardReferenceLabel, value: txn.merchant),
                _RowKV(label: l10n.referenceLabel, value: txn.referenceId),
              ],
            ),
          ),
          const SizedBox(height: 14),
          if (failed)
            _Card(
              title: l10n.failureReasonTitle,
              danger: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.failureReasonBody,
                    style: const TextStyle(color: Color(0xFFB91C1C)),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEE2E2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFCA5A5)),
                    ),
                    child: Text(
                      '${l10n.errorCodeLabel}: ${txn.referenceId}',
                      style: const TextStyle(
                        color: Color(0xFFB91C1C),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (failed) const SizedBox(height: 14),
          _Card(
            title: l10n.amountBreakdownTitle,
            child: Column(
              children: [
                _RowKV(
                  label: l10n.subtotalLabel,
                  value: '$currencyLabel ${subtotal.toStringAsFixed(2)}',
                ),
                _RowKV(
                  label: l10n.serviceFeeLabel,
                  value: '$currencyLabel ${serviceFee.toStringAsFixed(2)}',
                ),
                _RowKV(
                  label: l10n.taxLabel,
                  value: '$currencyLabel ${tax.toStringAsFixed(2)}',
                ),
                const Divider(height: 22),
                _RowKV(
                  label: l10n.totalLabel,
                  value: '$currencyLabel ${txn.amount.toStringAsFixed(2)}',
                  strong: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          if (failed)
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.credit_card),
                label: Text(l10n.tryAgain),
              ),
            )
          else
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ReceiptPreviewScreen(
                        receipt: _receiptData(l10n, currencyLabel),
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.receipt_long),
                label: Text(l10n.reprintReceipt),
              ),
            ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFEAF4FB),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFC7DFF0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.help_outline, color: Color(0xFF1F8EC9)),
                    const SizedBox(width: 8),
                    Text(
                      l10n.needHelpTitle,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  l10n.needHelpBody,
                  style: const TextStyle(color: Color(0xFF6B7280)),
                ),
                const SizedBox(height: 10),
                TextButton(onPressed: () {}, child: Text(l10n.contactSupport)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    final mm = dt.month.toString().padLeft(2, '0');
    final dd = dt.day.toString().padLeft(2, '0');
    final hh = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    final min = dt.minute.toString().padLeft(2, '0');
    return '${dt.year}-$mm-$dd  $hh:$min $ampm';
  }
}

class _Card extends StatelessWidget {
  final String title;
  final Widget child;
  final bool danger;

  const _Card({required this.title, required this.child, this.danger = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: danger ? const Color(0xFFFCA5A5) : const Color(0xFFE5E7EB),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _RowKV extends StatelessWidget {
  final String label;
  final String value;
  final bool strong;

  const _RowKV({required this.label, required this.value, this.strong = false});

  @override
  Widget build(BuildContext context) {
    final valueStyle = TextStyle(
      fontWeight: strong ? FontWeight.w900 : FontWeight.w800,
      color: const Color(0xFF111827),
    );
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
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: valueStyle,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
