// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:amenpay_cashir_app/main.dart';

class _TestAssetBundle extends CachingAssetBundle {
  static final Uint8List _transparentImagePng = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMB/VMpS7cAAAAASUVORK5CYII=',
  );

  @override
  Future<ByteData> load(String key) async {
    if (key.toLowerCase().endsWith('.png')) {
      return ByteData.view(_transparentImagePng.buffer);
    }
    return rootBundle.load(key);
  }
}

void main() {
  testWidgets('Login navigates to home and enroll flow', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      DefaultAssetBundle(bundle: _TestAssetBundle(), child: const MyApp()),
    );

    expect(find.byType(Scaffold), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 2600));
    await tester.pumpAndSettle();

    expect(find.text('Welcome Back'), findsOneWidget);

    await tester.ensureVisible(find.text('Sign In'));
    await tester.tap(find.text('Sign In'));
    await tester.pumpAndSettle();

    expect(find.text('Enroll PalmVein'), findsOneWidget);

    await tester.tap(find.text('Enroll PalmVein'));
    await tester.pumpAndSettle();

    expect(find.text('Claim Enrollment Session'), findsOneWidget);
  });
}
