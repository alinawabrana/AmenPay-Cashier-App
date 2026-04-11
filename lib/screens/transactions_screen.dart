import 'dart:convert';

import 'package:amenpay_cashir_app/l10n/app_localizations.dart';
import 'package:amenpay_cashir_app/screens/transaction_details_screen.dart';
import 'package:amenpay_cashir_app/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

const String _amenPayApiBaseUrl = String.fromEnvironment(
  'AMENPAY_API_BASE_URL',
  defaultValue: 'https://amenpay.org',
);

enum TxnStatus { completed, pending, failed }

enum TxnDirection { incoming, outgoing }

enum TxnKind {
  paymentReceived,
  subscriptionPayment,
  onlinePurchase,
  freelancePayment,
  restaurantPayment,
  transferToSavings,
  refundReceived,
  palmPayment,
}

class TxnItem {
  final TxnKind kind;
  final String counterpartyLabel; // raw: "From" / "To" (localized at render)
  final String counterpartyName;
  final String referenceId;
  final DateTime at;
  final double amount;
  final TxnDirection direction;
  final TxnStatus status;
  final String merchant;
  final String paymentMethod; // e.g. "Palm", "NFC", "QR"

  const TxnItem({
    required this.kind,
    required this.counterpartyLabel,
    required this.counterpartyName,
    required this.referenceId,
    required this.at,
    required this.amount,
    required this.direction,
    required this.status,
    required this.merchant,
    required this.paymentMethod,
  });
}

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  final TextEditingController _searchController = TextEditingController();
  int _rangeIdx = 0; // 0=all 1=today 2=week 3=month
  late final Future<List<TxnItem>> _transactionsFuture = _loadTransactions();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  DateTime _startForRange(DateTime now) {
    if (_rangeIdx == 1) {
      return DateTime(now.year, now.month, now.day);
    }
    if (_rangeIdx == 2) {
      // week starting Monday
      final delta = (now.weekday + 6) % 7;
      final start = now.subtract(Duration(days: delta));
      return DateTime(start.year, start.month, start.day);
    }
    if (_rangeIdx == 3) {
      return DateTime(now.year, now.month, 1);
    }
    // all
    return DateTime(now.year, now.month, 1);
  }

  Future<List<TxnItem>> _loadTransactions() async {
    final token = await AuthService.getToken();
    if (token == null || token.isEmpty) {
      return const <TxnItem>[];
    }
    final url = Uri.parse(
      '$_amenPayApiBaseUrl/api/reciept/transactions/cashier',
    );
    debugPrint('[Transactions] list request');
    final res = await http.get(
      url,
      headers: <String, String>{
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      },
    );
    debugPrint(
      '[Transactions] list response status=${res.statusCode} body=${res.body}',
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      return const <TxnItem>[];
    }
    dynamic decoded;
    try {
      decoded = jsonDecode(res.body);
    } catch (_) {
      return const <TxnItem>[];
    }
    final rows = _extractTransactions(decoded);
    return rows.map(_txnItemFromApi).toList(growable: false);
  }

  List<Map<String, dynamic>> _extractTransactions(dynamic data) {
    if (data is List) {
      return data
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList(growable: false);
    }
    if (data is Map) {
      final map = Map<String, dynamic>.from(data);
      for (final key in <String>[
        'transactions',
        'data',
        'items',
        'transaction',
      ]) {
        final value = map[key];
        final extracted = _extractTransactions(value);
        if (extracted.isNotEmpty) return extracted;
      }
      if (map.isNotEmpty && map.containsKey('id')) {
        return <Map<String, dynamic>>[map];
      }
    }
    return const <Map<String, dynamic>>[];
  }

  TxnItem _txnItemFromApi(Map<String, dynamic> txn) {
    final status = (txn['status'] ?? '').toString().toLowerCase();
    final amountRaw = txn['amount'];
    final amount = amountRaw is num
        ? amountRaw.toDouble()
        : double.tryParse(amountRaw?.toString() ?? '') ?? 0;
    final createdAt =
        DateTime.tryParse((txn['created_at'] ?? '').toString()) ??
        DateTime.now();
    return TxnItem(
      kind: TxnKind.palmPayment,
      counterpartyLabel: 'From',
      counterpartyName:
          (txn['card_holder_name'] ?? txn['user_name'] ?? 'Customer')
              .toString(),
      referenceId: 'TXN-${txn['id'] ?? '-'}',
      at: createdAt,
      amount: amount,
      direction: TxnDirection.incoming,
      status: status == 'failed'
          ? TxnStatus.failed
          : status == 'pending'
          ? TxnStatus.pending
          : TxnStatus.completed,
      merchant: (txn['moyasar_id'] ?? txn['card_number'] ?? 'Card payment')
          .toString(),
      paymentMethod: status.toUpperCase(),
    );
  }

  List<TxnItem> _filtered(List<TxnItem> allTxns) {
    final now = DateTime.now();
    final start = _rangeIdx == 0 ? null : _startForRange(now);
    final q = _searchController.text.trim().toLowerCase();
    return allTxns.where((t) {
      if (start != null && t.at.isBefore(start)) return false;
      if (q.isEmpty) return true;
      return t.referenceId.toLowerCase().contains(q) ||
          t.counterpartyName.toLowerCase().contains(q) ||
          t.kind.name.toLowerCase().contains(q);
    }).toList()..sort((a, b) => b.at.compareTo(a.at));
  }

  double _sumIncome(List<TxnItem> txns) {
    double sum = 0;
    for (final t in txns) {
      if (t.direction == TxnDirection.incoming) sum += t.amount;
    }
    return sum;
  }

  void _openDetails(TxnItem txn) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => TransactionDetailsScreen(txn: txn)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.transactions),
      ),
      body: FutureBuilder<List<TxnItem>>(
        future: _transactionsFuture,
        builder: (context, snapshot) {
          final allTxns = snapshot.data ?? const <TxnItem>[];
          final txns = _filtered(allTxns);
          final income = _sumIncome(txns);
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            children: [
              _StatCard(
                title: l10n.totalIncome,
                amount: income,
                trend: l10n.trendUpWeek,
                trendColor: const Color(0xFF16A34A),
                icon: Icons.south,
                iconBg: const Color(0xFFD1FAE5),
                iconFg: const Color(0xFF16A34A),
              ),
              const SizedBox(height: 14),
              _SearchBox(
                controller: _searchController,
                hint: l10n.searchByReference,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 14),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _RangeChip(
                      label: l10n.allFilter,
                      selected: _rangeIdx == 0,
                      onTap: () => setState(() => _rangeIdx = 0),
                    ),
                    const SizedBox(width: 10),
                    _RangeChip(
                      label: l10n.today,
                      selected: _rangeIdx == 1,
                      onTap: () => setState(() => _rangeIdx = 1),
                    ),
                    const SizedBox(width: 10),
                    _RangeChip(
                      label: l10n.thisWeek,
                      selected: _rangeIdx == 2,
                      onTap: () => setState(() => _rangeIdx = 2),
                    ),
                    const SizedBox(width: 10),
                    _RangeChip(
                      label: l10n.thisMonth,
                      selected: _rangeIdx == 3,
                      onTap: () => setState(() => _rangeIdx = 3),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.recentTransactions,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _rangeIdx = 0);
                    },
                    child: Text(l10n.viewAll),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (snapshot.connectionState == ConnectionState.waiting)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (txns.isEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: Text(
                    l10n.noTransactionsFound,
                    style: const TextStyle(color: Color(0xFF6B7280)),
                  ),
                )
              else
                for (final t in txns) ...[
                  _TxnTile(txn: t, onTap: () => _openDetails(t)),
                  const SizedBox(height: 12),
                ],
            ],
          );
        },
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final double amount;
  final String trend;
  final Color trendColor;
  final IconData icon;
  final Color iconBg;
  final Color iconFg;

  const _StatCard({
    required this.title,
    required this.amount,
    required this.trend,
    required this.trendColor,
    required this.icon,
    required this.iconBg,
    required this.iconFg,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF6B7280),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: iconBg,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconFg, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '\$${amount.toStringAsFixed(0)}',
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 22),
          ),
          const SizedBox(height: 4),
          Text(
            trend,
            style: TextStyle(
              color: trendColor,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchBox extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;

  const _SearchBox({
    required this.controller,
    required this.hint,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          const Icon(Icons.search, color: Color(0xFF9CA3AF)),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              decoration: InputDecoration(
                hintText: hint,
                border: InputBorder.none,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RangeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _RangeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bg = selected ? const Color(0xFF1F8EC9) : Colors.white;
    final fg = selected ? Colors.white : const Color(0xFF374151);
    final border = selected ? const Color(0xFF1F8EC9) : const Color(0xFFE5E7EB);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: border),
        ),
        child: Text(
          label,
          style: TextStyle(color: fg, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}

class _TxnTile extends StatelessWidget {
  final TxnItem txn;
  final VoidCallback onTap;

  const _TxnTile({required this.txn, required this.onTap});

  String _titleLabel(AppLocalizations l10n) {
    return switch (txn.kind) {
      TxnKind.paymentReceived => l10n.txnPaymentReceived,
      TxnKind.subscriptionPayment => l10n.txnSubscriptionPayment,
      TxnKind.onlinePurchase => l10n.txnOnlinePurchase,
      TxnKind.freelancePayment => l10n.txnFreelancePayment,
      TxnKind.restaurantPayment => l10n.txnRestaurantPayment,
      TxnKind.transferToSavings => l10n.txnTransferToSavings,
      TxnKind.refundReceived => l10n.txnRefundReceived,
      TxnKind.palmPayment => l10n.txnPalmPayment,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isArabic =
        Localizations.localeOf(context).languageCode.toLowerCase() == 'ar';
    final currencyLabel = isArabic ? 'ر.س' : 'SAR';
    final isIn = txn.direction == TxnDirection.incoming;
    final amountColor = txn.status == TxnStatus.failed
        ? const Color(0xFFDC2626)
        : txn.status == TxnStatus.pending
        ? const Color(0xFF2563EB)
        : const Color(0xFF16A34A);

    final (icon, iconBg, iconFg) = switch (txn.kind) {
      TxnKind.paymentReceived => (
        Icons.south,
        const Color(0xFFD1FAE5),
        const Color(0xFF16A34A),
      ),
      TxnKind.refundReceived => (
        Icons.attach_money,
        const Color(0xFFD1FAE5),
        const Color(0xFF16A34A),
      ),
      TxnKind.transferToSavings => (
        Icons.schedule,
        const Color(0xFFFEF3C7),
        const Color(0xFFB45309),
      ),
      TxnKind.onlinePurchase => (
        Icons.shopping_cart,
        const Color(0xFFFEE2E2),
        const Color(0xFFDC2626),
      ),
      TxnKind.restaurantPayment => (
        Icons.restaurant,
        const Color(0xFFFEE2E2),
        const Color(0xFFDC2626),
      ),
      _ => (
        isIn ? Icons.south : Icons.north,
        isIn ? const Color(0xFFD1FAE5) : const Color(0xFFFEE2E2),
        isIn ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
      ),
    };

    String statusLabel() {
      return switch (txn.status) {
        TxnStatus.completed => l10n.completed,
        TxnStatus.pending => l10n.pending,
        TxnStatus.failed => l10n.failed,
      };
    }

    Color statusColor() {
      return switch (txn.status) {
        TxnStatus.completed => const Color(0xFF16A34A),
        TxnStatus.pending => const Color(0xFFB45309),
        TxnStatus.failed => const Color(0xFFDC2626),
      };
    }

    final timeLabel = _formatRelative(context, txn.at);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: iconBg,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconFg),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _titleLabel(l10n),
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${_translateFromTo(l10n, txn.counterpartyLabel)}: ${txn.counterpartyName}',
                      style: const TextStyle(
                        color: Color(0xFF6B7280),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${l10n.refLabel}: ${txn.referenceId}',
                      style: const TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      timeLabel,
                      style: const TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$currencyLabel ${txn.amount.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: amountColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    statusLabel(),
                    style: TextStyle(
                      color: statusColor(),
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _translateFromTo(AppLocalizations l10n, String raw) {
    final v = raw.trim().toLowerCase();
    if (v == 'from') return l10n.fromLabel;
    if (v == 'to') return l10n.toLabel;
    return raw;
  }

  String _formatRelative(BuildContext context, DateTime at) {
    final l10n = AppLocalizations.of(context)!;
    final now = DateTime.now();
    final delta = now.difference(at);
    if (delta.inMinutes < 60) return l10n.minutesAgo(delta.inMinutes);
    if (delta.inHours < 24) return l10n.hoursAgo(delta.inHours);
    if (delta.inDays == 1) return l10n.yesterday;
    return l10n.daysAgo(delta.inDays);
  }
}
