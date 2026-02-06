import 'package:flutter/material.dart';

import 'package:amenpay_cashir_app/screens/loading_screen.dart';
import 'package:amenpay_cashir_app/utils/themes/elevated_button_theme.dart';
import 'package:amenpay_cashir_app/utils/themes/icon_theme.dart';
import 'package:amenpay_cashir_app/utils/themes/input_decoration_theme.dart';
import 'package:amenpay_cashir_app/utils/themes/outlined_button_theme.dart';
import 'package:amenpay_cashir_app/utils/themes/text_theme.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AmenPay Cashier',
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF9FAFB),
        textTheme: ATextTheme.textTheme,
        iconTheme: AIconTheme.iconTheme,
        inputDecorationTheme: ATextFormFieldTheme.textFormFieldTheme,
        elevatedButtonTheme: AElevatedButtonTheme.elevatedButtonTheme,
        outlinedButtonTheme: AOutlinedButtonTheme.outlinedButtonTheme,
      ),
      home: const LoadingScreen(),
    );
  }
}
