import 'package:flutter/material.dart';

class ATextFormFieldTheme {
  static InputDecorationTheme textFormFieldTheme = InputDecorationTheme(
    hintStyle: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w400,
      color: Color(0xFFADAEBC),
    ),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: Color(0xFFD1D5DB), width: 1),
    ),
    prefixIconColor: Color(0xFF9CA3AF),
    suffixIconColor: Color(0xFF9CA3AF),
  );
}
