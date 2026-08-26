import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Key used to persist the selected language locally.
const String kAppLocalePrefKey = 'app_locale';

final sharedPreferencesProvider =
    Provider<SharedPreferences>((ref) => throw UnimplementedError());

/// Initial locale code, provided synchronously from main() so the very first
/// frame is already in the saved language (default: Arabic).
final initialLocaleCodeProvider =
    Provider<String>((ref) => throw UnimplementedError());

/// Controls the app locale. Changing it rebuilds [MaterialApp] immediately
/// (no restart) and persists the choice for future launches.
class LocaleController extends StateNotifier<Locale> {
  LocaleController(this._prefs, String code) : super(Locale(code)) {
    _applyIntlLocale(code);
  }

  final SharedPreferences _prefs;

  static const supportedCodes = ['ar', 'en'];

  void setLocale(Locale locale) {
    if (!supportedCodes.contains(locale.languageCode)) return;
    state = locale;
    _applyIntlLocale(locale.languageCode);
    _prefs.setString(kAppLocalePrefKey, locale.languageCode);
  }

  void _applyIntlLocale(String code) {
    Intl.defaultLocale = code;
    if (code == 'ar') {
      // Ensure Arabic date/month symbols are available for DateFormat.
      initializeDateFormatting('ar', null);
    }
  }
}

final localeControllerProvider =
    StateNotifierProvider<LocaleController, Locale>((ref) {
  return LocaleController(
    ref.watch(sharedPreferencesProvider),
    ref.watch(initialLocaleCodeProvider),
  );
});
