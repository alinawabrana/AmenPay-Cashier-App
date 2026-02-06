import 'package:amenpay_cashir_app/utils/themes/text_theme.dart';
import 'package:flutter/material.dart';

class AOutlinedButtonTheme {
  static OutlinedButtonThemeData outlinedButtonTheme = OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: Color(0xFF238EC2),
      backgroundColor: Colors.white,
      textStyle: ATextTheme.textTheme.titleLarge,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
        side: BorderSide(color: Color(0xFF238EC2), width: 2),
      ),
    ),
  );
}
