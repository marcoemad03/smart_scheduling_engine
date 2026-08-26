import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reception_workforce_scheduler/app/app.dart';
import 'package:reception_workforce_scheduler/core/locale/locale_providers.dart';
import 'package:reception_workforce_scheduler/firebase_options.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final savedLocaleCode =
      prefs.getString(kAppLocalePrefKey) ?? 'ar'; // Arabic by default.
  runApp(_BootstrapApp(
    prefs: prefs,
    initialLocaleCode: savedLocaleCode,
  ));
}

class _BootstrapApp extends StatelessWidget {
  const _BootstrapApp({
    required this.prefs,
    required this.initialLocaleCode,
  });

  final SharedPreferences prefs;
  final String initialLocaleCode;

  @override
  Widget build(BuildContext context) {
    final initialLocale = Locale(initialLocaleCode);
    return FutureBuilder<FirebaseApp>(
      future: _initFirebase(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          debugPrint('Firebase init failed: ${snapshot.error}');
          return _BootstrapMaterialApp(
            locale: initialLocale,
            home: Scaffold(
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline,
                          size: 48, color: Colors.red),
                      const SizedBox(height: 16),
                      Text(AppLocalizations.of(context)?.firebaseInitFailed ??
                          'Failed to initialize Firebase'),
                      const SizedBox(height: 8),
                      Text('${snapshot.error}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
              ),
            ),
          );
        }
        if (snapshot.connectionState != ConnectionState.done) {
          return _BootstrapMaterialApp(
            locale: initialLocale,
            home: Scaffold(
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text(AppLocalizations.of(context)?.startingApp ??
                        'Starting Reception Scheduler…'),
                  ],
                ),
              ),
            ),
          );
        }
        return ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            initialLocaleCodeProvider.overrideWithValue(initialLocaleCode),
          ],
          child: const ReceptionSchedulerApp(),
        );
      },
    );
  }

  Future<FirebaseApp> _initFirebase() async {
    try {
      return await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } on FirebaseException catch (e) {
      if (e.code == 'duplicate-app' && Firebase.apps.isNotEmpty) {
        // Duplicate initialization (hot restart) - reuse the default app.
        return Firebase.app();
      }
      rethrow;
    }
  }
}

/// MaterialApp used before the main ProviderScope exists, so the bootstrap
/// screens are localized and direction-aware too.
class _BootstrapMaterialApp extends StatelessWidget {
  const _BootstrapMaterialApp({required this.locale, required this.home});

  final Locale locale;
  final Widget home;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: home,
    );
  }
}
