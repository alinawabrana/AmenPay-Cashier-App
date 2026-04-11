import 'package:flutter/material.dart';

import 'package:amenpay_cashir_app/services/locale_controller.dart';

class LanguageSwitch extends StatelessWidget {
  final bool compact;

  const LanguageSwitch({super.key, this.compact = false});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: LocaleController.instance,
      builder: (context, _) {
        final isAr = LocaleController.instance.locale.languageCode == 'ar';

        return InkWell(
          onTap: () async {
            await LocaleController.instance.toggle();
          },
          borderRadius: BorderRadius.circular(999),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 10 : 12,
              vertical: compact ? 6 : 8,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _PillLabel(
                  label: 'EN',
                  active: !isAr,
                  compact: compact,
                ),
                const SizedBox(width: 6),
                _PillLabel(
                  label: 'AR',
                  active: isAr,
                  compact: compact,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PillLabel extends StatelessWidget {
  final String label;
  final bool active;
  final bool compact;

  const _PillLabel({
    required this.label,
    required this.active,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: active ? const Color(0xFF238EC2) : Colors.transparent,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: compact ? 12 : 13,
          color: active ? Colors.white : const Color(0xFF6B7280),
        ),
      ),
    );
  }
}
