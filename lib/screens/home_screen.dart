import 'dart:convert';

import 'package:amenpay_cashir_app/features/home/screens/enroll_nfc_card_screen.dart';
import 'package:amenpay_cashir_app/features/home/screens/enroll_palm_vein_screen.dart';
import 'package:amenpay_cashir_app/screens/new_payment_screen.dart';
import 'package:amenpay_cashir_app/screens/settings_screen.dart';
import 'package:amenpay_cashir_app/screens/transaction_details_screen.dart';
import 'package:amenpay_cashir_app/screens/welcome_screen.dart';
import 'package:amenpay_cashir_app/screens/transactions_screen.dart';
import 'package:amenpay_cashir_app/services/auth_service.dart';
import 'package:amenpay_cashir_app/widgets/language_switch.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:amenpay_cashir_app/l10n/app_localizations.dart';

const String _amenPayApiBaseUrl = String.fromEnvironment(
  'AMENPAY_API_BASE_URL',
  defaultValue: 'https://amenpay.org',
);

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Future<_BalanceSummary> _loadBalanceSummary() async {
    final transactions = await _loadCustomerTransactions();
    double balance = 0;
    for (final txn in transactions) {
      final amountRaw = txn['amount'];
      final amount = amountRaw is num
          ? amountRaw.toDouble()
          : double.tryParse(amountRaw?.toString() ?? '') ?? 0;
      final status = (txn['status'] ?? '').toString().toLowerCase();
      if (status == 'failed') continue;
      balance += amount;
    }
    return _BalanceSummary(
      balance: balance,
      transactionCount: transactions.length,
    );
  }

  Future<_HeaderInfo> _loadHeader() async {
    final deviceId = await AuthService.getDeviceId();
    final userId = await AuthService.getUserId();
    return _HeaderInfo(
      deviceId: deviceId ?? '',
      userLabel: userId == null ? '' : '#$userId',
    );
  }

  Future<List<Map<String, dynamic>>> _loadCustomerTransactions() async {
    final token = await AuthService.getToken();
    final userId = await AuthService.getUserId();
    if (token == null || token.isEmpty || userId == null) {
      return const <Map<String, dynamic>>[];
    }

    final url = Uri.parse(
      '$_amenPayApiBaseUrl/api/reciept/transactions/cashier',
    );
    debugPrint('[Home] transactions request user_id=$userId');
    final res = await http.get(
      url,
      headers: <String, String>{
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      },
    );
    debugPrint(
      '[Home] transactions response status=${res.statusCode} body=${res.body}',
    );

    if (res.statusCode < 200 || res.statusCode >= 300) {
      return const <Map<String, dynamic>>[];
    }

    dynamic decoded;
    try {
      decoded = jsonDecode(res.body);
    } catch (_) {
      return const <Map<String, dynamic>>[];
    }
    return _extractTransactions(decoded);
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
      final keys = <String>['transactions', 'transaction', 'data', 'items'];
      for (final key in keys) {
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

  String _formatAmount(BuildContext context, Map<String, dynamic> txn) {
    final isArabic =
        Localizations.localeOf(context).languageCode.toLowerCase() == 'ar';
    final currencyCode = (txn['currency'] ?? 'SAR').toString().toUpperCase();
    final currencyLabel = currencyCode == 'SAR'
        ? (isArabic ? 'ر.س' : 'SAR')
        : currencyCode;
    final amountRaw = txn['amount'];
    final amount = amountRaw is num
        ? amountRaw.toDouble()
        : double.tryParse(amountRaw?.toString() ?? '') ?? 0;
    return '$currencyLabel ${amount.toStringAsFixed(2)}';
  }

  String _transactionTitle(Map<String, dynamic> txn) {
    final holder = (txn['card_holder_name'] ?? '').toString().trim();
    if (holder.isNotEmpty) return holder;
    final userName = (txn['user_name'] ?? '').toString().trim();
    if (userName.isNotEmpty && userName.toLowerCase() != 'unknown') {
      return userName;
    }
    final id = (txn['id'] ?? '').toString().trim();
    return id.isEmpty ? 'Transaction' : 'Transaction #$id';
  }

  String _transactionSubtitle(Map<String, dynamic> txn) {
    final status = (txn['status'] ?? 'unknown').toString().trim();
    final cardNumber = (txn['card_number'] ?? '').toString().trim();
    final moyasarId = (txn['moyasar_id'] ?? '').toString().trim();
    if (cardNumber.isNotEmpty) {
      return '${status.toUpperCase()} • $cardNumber';
    }
    if (moyasarId.isNotEmpty) {
      return '${status.toUpperCase()} • $moyasarId';
    }
    return status.toUpperCase();
  }

  IconData _transactionIcon(Map<String, dynamic> txn) {
    final status = (txn['status'] ?? '').toString().toLowerCase();
    if (status == 'failed') return Icons.error_outline;
    return Icons.receipt_long_outlined;
  }

  Color _transactionIconBg(Map<String, dynamic> txn) {
    final status = (txn['status'] ?? '').toString().toLowerCase();
    if (status == 'failed') return const Color(0xFFFEE2E2);
    if (status == 'pending') return const Color(0xFFEAF4FB);
    return const Color(0xFFE8F9EF);
  }

  Color _transactionIconFg(Map<String, dynamic> txn) {
    final status = (txn['status'] ?? '').toString().toLowerCase();
    if (status == 'failed') return const Color(0xFFDC2626);
    if (status == 'pending') return const Color(0xFF2563EB);
    return const Color(0xFF16A34A);
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
      counterpartyName: _transactionTitle(txn),
      referenceId: 'TXN-${txn['id'] ?? '-'}',
      at: createdAt,
      amount: amount,
      direction: TxnDirection.incoming,
      status: status == 'failed'
          ? TxnStatus.failed
          : (status == 'pending')
          ? TxnStatus.pending
          : TxnStatus.completed,
      merchant: (txn['moyasar_id'] ?? txn['card_number'] ?? 'Card payment')
          .toString(),
      paymentMethod: ((txn['status'] ?? 'initiated').toString()).toUpperCase(),
    );
  }

  void _push(Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  Future<void> _logout() async {
    await AuthService.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const WelcomeScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    final size = MediaQuery.sizeOf(context);
    final isLandscape = size.width > size.height;
    final isWide = size.width >= 700;
    final headerHeight = (isWide || isLandscape) ? 220.0 : 260.0;
    final topGradient = const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF2B7BA6), Color(0xFF1F8EC9)],
    );

    return Scaffold(
      drawer: Drawer(
        child: SafeArea(
          child: Column(
            children: [
              FutureBuilder<_HeaderInfo>(
                future: _loadHeader(),
                builder: (context, snapshot) {
                  final info = snapshot.data ?? const _HeaderInfo();
                  return Container(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF2B7BA6), Color(0xFF1F8EC9)],
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            Icons.storefront,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.appTitleShort,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                [
                                  if (info.userLabel.isNotEmpty)
                                    '${l10n.cashier} ${info.userLabel}',
                                  if (info.deviceId.isNotEmpty)
                                    '${l10n.deviceIdLabel}: ${info.deviceId}',
                                ].join(' • '),
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.85),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const LanguageSwitch(compact: true),
                      ],
                    ),
                  );
                },
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  children: [
                    _DrawerItem(
                      icon: Icons.home_outlined,
                      label: l10n.homeTitle,
                      onTap: () => Navigator.of(context).pop(),
                    ),
                    _DrawerItem(
                      icon: Icons.payments_outlined,
                      label: l10n.newPayment,
                      onTap: () {
                        Navigator.of(context).pop();
                        _push(const NewPaymentScreen());
                      },
                    ),
                    _DrawerItem(
                      icon: Icons.front_hand_outlined,
                      label: l10n.palmEnroll,
                      onTap: () {
                        Navigator.of(context).pop();
                        _push(const EnrollPalmVeinScreen());
                      },
                    ),
                    _DrawerItem(
                      icon: Icons.nfc_outlined,
                      label: l10n.enrollNfcCard,
                      onTap: () {
                        Navigator.of(context).pop();
                        _push(const EnrollNfcCardScreen());
                      },
                    ),
                    _DrawerItem(
                      icon: Icons.receipt_long_outlined,
                      label: l10n.transactions,
                      onTap: () {
                        Navigator.of(context).pop();
                        _push(const TransactionsScreen());
                      },
                    ),
                    _DrawerItem(
                      icon: Icons.settings_outlined,
                      label: l10n.settings,
                      onTap: () {
                        Navigator.of(context).pop();
                        _push(const SettingsScreen());
                      },
                    ),
                    _DrawerItem(
                      icon: Icons.exit_to_app,
                      label: l10n.logout,
                      danger: true,
                      onTap: () {
                        Navigator.of(context).pop();
                        _logout();
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      appBar: AppBar(
        title: Text(l10n.appTitleShort),
        actions: const [
          Padding(
            padding: EdgeInsetsDirectional.only(end: 10),
            child: Center(child: LanguageSwitch(compact: true)),
          ),
        ],
      ),
      body: ListView(
        children: [
          SizedBox(
            height: headerHeight,
            child: Stack(
              children: [
                Container(
                  height: headerHeight - 40,
                  decoration: BoxDecoration(gradient: topGradient),
                ),
                PositionedDirectional(
                  start: 16,
                  top: 16,
                  end: 16,
                  child: FutureBuilder<_HeaderInfo>(
                    future: _loadHeader(),
                    builder: (context, snapshot) {
                      final info = snapshot.data ?? const _HeaderInfo();
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l10n.welcomeBack,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.9),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  info.userLabel.isEmpty
                                      ? l10n.cashier
                                      : '${l10n.cashier} ${info.userLabel}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 22,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                PositionedDirectional(
                  start: 16,
                  end: 16,
                  bottom: 50,
                  child: Align(
                    alignment: isWide
                        ? AlignmentDirectional.center
                        : AlignmentDirectional.centerStart,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minWidth: isWide ? 450 : 0,
                        maxWidth: isWide ? 560 : double.infinity,
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.18),
                          ),
                        ),
                        child: FutureBuilder<_BalanceSummary>(
                          future: _loadBalanceSummary(),
                          builder: (context, snapshot) {
                            final summary =
                                snapshot.data ?? const _BalanceSummary();
                            final isArabic =
                                Localizations.localeOf(
                                  context,
                                ).languageCode.toLowerCase() ==
                                'ar';
                            final currencyLabel = isArabic ? 'ر.س' : 'SAR';
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l10n.totalBalance,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.9),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '$currencyLabel ${summary.balance.toStringAsFixed(2)}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 30,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  l10n.liveBalanceFromTransactions(
                                    summary.transactionCount,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.85),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _CardSection(
              title: l10n.quickActions,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final w = constraints.maxWidth;
                  final cols = w >= 900
                      ? 4
                      : w >= 700
                      ? 4
                      : 2;

                  // Keep tiles usable on wide/landscape POS screens (avoid huge tiles).
                  final tileExtent = cols == 4 ? 110.0 : 120.0;

                  final tiles = <Widget>[
                    _QuickActionTile(
                      icon: Icons.near_me_outlined,
                      label: l10n.newPayment,
                      primary: true,
                      onTap: () => _push(const NewPaymentScreen()),
                    ),
                    _QuickActionTile(
                      icon: Icons.front_hand_outlined,
                      label: l10n.palmEnroll,
                      onTap: () => _push(const EnrollPalmVeinScreen()),
                    ),
                    _QuickActionTile(
                      icon: Icons.nfc_outlined,
                      label: l10n.enrollNfcCard,
                      onTap: () => _push(const EnrollNfcCardScreen()),
                    ),
                    _QuickActionTile(
                      icon: Icons.receipt_long_outlined,
                      label: l10n.transactions,
                      onTap: () => _push(const TransactionsScreen()),
                    ),
                    _QuickActionTile(
                      icon: Icons.settings_outlined,
                      label: l10n.settings,
                      onTap: () => _push(const SettingsScreen()),
                    ),
                  ];

                  return GridView.builder(
                    itemCount: tiles.length,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: cols,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      mainAxisExtent: tileExtent,
                    ),
                    itemBuilder: (context, index) => tiles[index],
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.recentTransactions,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => _push(const TransactionsScreen()),
                  child: Text(l10n.viewAll),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _loadCustomerTransactions(),
              builder: (context, snapshot) {
                final transactions =
                    snapshot.data ?? const <Map<String, dynamic>>[];
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: CircularProgressIndicator(),
                    ),
                  );
                }
                if (transactions.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 12,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Text(
                      l10n.homeNoTransactions,
                      style: const TextStyle(color: Color(0xFF6B7280)),
                    ),
                  );
                }
                final visible = transactions.take(4).toList(growable: false);
                return Column(
                  children: [
                    for (int i = 0; i < visible.length; i++) ...[
                      _TxnRow(
                        icon: _transactionIcon(visible[i]),
                        iconBg: _transactionIconBg(visible[i]),
                        iconFg: _transactionIconFg(visible[i]),
                        title: _transactionTitle(visible[i]),
                        subtitle: _transactionSubtitle(visible[i]),
                        trailing: _formatAmount(context, visible[i]),
                        trailingColor: _transactionIconFg(visible[i]),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => TransactionDetailsScreen(
                                txn: _txnItemFromApi(visible[i]),
                              ),
                            ),
                          );
                        },
                      ),
                      if (i != visible.length - 1) const SizedBox(height: 10),
                    ],
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 22),
        ],
      ),
    );
  }
}

class _HeaderInfo {
  final String deviceId;
  final String userLabel;

  const _HeaderInfo({this.deviceId = '', this.userLabel = ''});
}

class _BalanceSummary {
  final double balance;
  final int transactionCount;

  const _BalanceSummary({this.balance = 0, this.transactionCount = 0});
}

class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;

  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = danger ? const Color(0xFFB91C1C) : null;
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(label, style: TextStyle(color: color)),
      onTap: onTap,
    );
  }
}

class _CardSection extends StatelessWidget {
  final String title;
  final Widget child;

  const _CardSection({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool primary;

  const _QuickActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.primary = false,
  });

  @override
  Widget build(BuildContext context) {
    final bg = primary ? const Color(0xFF1F8EC9) : const Color(0xFFEAF4FB);
    final fg = primary ? Colors.white : const Color(0xFF1F8EC9);

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: fg),
              const SizedBox(height: 10),
              Text(
                label,
                style: TextStyle(color: fg, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TxnRow extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final Color iconFg;
  final String title;
  final String subtitle;
  final String trailing;
  final Color trailingColor;
  final VoidCallback? onTap;

  const _TxnRow({
    required this.icon,
    required this.iconBg,
    required this.iconFg,
    required this.title,
    required this.subtitle,
    required this.trailing,
    required this.trailingColor,
    this.onTap,
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
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 12,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
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
                      title,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 3),
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
              Text(
                trailing,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: trailingColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
