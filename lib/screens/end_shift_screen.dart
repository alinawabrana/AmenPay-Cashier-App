import 'package:flutter/material.dart';

import 'package:amenpay_cashir_app/l10n/app_localizations.dart';

class EndShiftScreen extends StatelessWidget {
  const EndShiftScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.endShift)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            l10n.todoEndShift,
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}

