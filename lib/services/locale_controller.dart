import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocaleController extends ChangeNotifier {
  static const String _storageKey = 'app_locale';

  LocaleController._();

  static final LocaleController instance = LocaleController._();

  Locale _locale = const Locale('en');

  Locale get locale => _locale;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final code = (prefs.getString(_storageKey) ?? 'en').trim().toLowerCase();
    _locale = Locale(code == 'ar' ? 'ar' : 'en');
    notifyListeners();
  }

  Future<void> setLocale(Locale locale) async {
    final next = Locale(locale.languageCode == 'ar' ? 'ar' : 'en');
    if (next.languageCode == _locale.languageCode) return;
    _locale = next;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, _locale.languageCode);
    notifyListeners();
  }

  Future<void> toggle() async {
    await setLocale(Locale(_locale.languageCode == 'ar' ? 'en' : 'ar'));
  }
}

