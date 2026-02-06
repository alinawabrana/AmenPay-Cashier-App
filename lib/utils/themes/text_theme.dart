import 'package:flutter/material.dart';

class ATextTheme {
  static const TextTheme textTheme = TextTheme(
    // ===== Display / Big titles =====
    displayLarge: TextStyle(
      fontSize: 36,
      fontWeight: FontWeight.w700,
      height: 40 / 36,
      letterSpacing: -0.5,
      color: Colors.white,
    ),

    headlineLarge: TextStyle(
      fontSize: 30,
      fontWeight: FontWeight.w700,
      height: 36 / 30,
      letterSpacing: -0.7,
      color: Color(0xFF333333),
    ),

    headlineMedium: TextStyle(
      fontSize: 24,
      fontWeight: FontWeight.w700,
      height: 32 / 24,
      letterSpacing: -0.5,
      color: Color(0xFF333333),
    ),

    headlineSmall: TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w600,
      height: 1.0,
      letterSpacing: -0.5,
      color: Color(0xFF333333),
    ),

    // ===== Titles =====
    titleLarge: TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.w600,
      height: 1.0,
      letterSpacing: -0.5,
      color: Color(0xFF333333),
    ),

    titleMedium: TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.w500,
      height: 28 / 18,
      letterSpacing: -0.5,
      color: Color(0xFF4B5563),
    ),

    titleSmall: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w600,
      height: 1.0,
      letterSpacing: -0.5,
      color: Color(0xFF333333),
    ),

    // ===== Body text =====
    bodyLarge: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w400,
      height: 24 / 16,
      letterSpacing: -0.5,
      color: Color(0xFF333333),
    ),

    bodyMedium: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w500,
      height: 1.0,
      letterSpacing: -0.5,
      color: Color(0xFF6B7280),
    ),

    bodySmall: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w400,
      height: 20 / 14,
      letterSpacing: -0.5,
      color: Color(0xFF6B7280),
    ),

    // ===== Labels / captions =====
    labelLarge: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w700,
      height: 20 / 14,
      letterSpacing: -0.5,
      color: Color(0xFF333333),
    ),

    labelMedium: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      height: 1.0,
      letterSpacing: -0.5,
      color: Colors.white,
    ),

    labelSmall: TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      height: 1.0,
      letterSpacing: -0.2,
      color: Color(0xFF6B7280),
    ),
  );
}
