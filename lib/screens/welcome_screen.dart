import 'package:flutter/material.dart';

import 'package:amenpay_cashir_app/screens/login_screen.dart';
import 'package:amenpay_cashir_app/screens/signup_screen.dart';
import 'package:amenpay_cashir_app/widgets/language_switch.dart';
import 'package:amenpay_cashir_app/l10n/app_localizations.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  TextStyle _arabicTitleStyle(TextStyle base) {
    return base.copyWith(
      fontSize: 34,
      fontWeight: FontWeight.w800,
      height: 44 / 34,
      letterSpacing: -0.2,
      fontFamilyFallback: const [
        'Cairo',
        'Tajawal',
        'Noto Kufi Arabic',
        'Noto Naskh Arabic',
        'sans-serif',
      ],
    );
  }

  TextStyle _arabicBodyStyle(TextStyle base) {
    return base.copyWith(
      fontSize: 16,
      height: 24 / 16,
      fontFamilyFallback: const [
        'Cairo',
        'Tajawal',
        'Noto Kufi Arabic',
        'Noto Naskh Arabic',
        'sans-serif',
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final textTheme = Theme.of(context).textTheme;

    final titleStyle =
        isAr ? _arabicTitleStyle(textTheme.headlineLarge!) : textTheme.headlineLarge!;
    final subtitleStyle =
        isAr ? _arabicBodyStyle(textTheme.titleMedium!) : textTheme.titleMedium!;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 14),
                    Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: const LanguageSwitch(compact: true),
                    ),
                    const SizedBox(height: 18),
                    Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        color: const Color(0xFF238EC2),
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.12),
                            blurRadius: 16,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Image.asset(
                          'assets/icons/AmenPay_Cashier_Icon.png',
                          width: 44,
                          height: 44,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      l10n.welcomeTitle,
                      style: titleStyle.copyWith(color: const Color(0xFF333333)),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFF238EC2),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      l10n.welcomeMessage,
                      style: subtitleStyle.copyWith(
                        color: const Color(0xFF333333),
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.welcomeTagline,
                      style: textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF6B7280),
                        fontSize: 13,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 26),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const LoginScreen()),
                          );
                        },
                        child: Text(l10n.signIn),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const SignupScreen()),
                          );
                        },
                        child: Text(l10n.createAccount),
                      ),
                    ),
                    const SizedBox(height: 28),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.shield_outlined,
                          size: 16,
                          color: Color(0xFF16A34A),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          l10n.secureLogin,
                          style: textTheme.bodySmall?.copyWith(
                            color: const Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 26),
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
