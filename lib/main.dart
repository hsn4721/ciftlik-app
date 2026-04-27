import 'dart:async';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'core/design_system/ds.dart';
import 'core/services/security_service.dart';
import 'features/splash/splash_screen.dart';
import 'features/auth/lock_screen.dart';
import 'shared/widgets/dismiss_keyboard.dart';

void main() {
  // runZonedGuarded — uncaught async hatalarını yakalar.
  runZonedGuarded<Future<void>>(() async {
    final binding = WidgetsFlutterBinding.ensureInitialized();
    FlutterNativeSplash.preserve(widgetsBinding: binding);
    await initializeDateFormatting('tr_TR', null);

    // Framework-level hatalar (build/layout/paint) → Crashlytics
    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      try {
        FirebaseCrashlytics.instance.recordFlutterFatalError(details);
      } catch (_) {/* Firebase init edilmeden önceki erken hatalar */}
    };
    // Platform isolate hataları (PlatformDispatcher) → Crashlytics
    PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
      try {
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      } catch (_) {}
      return true;
    };

    // IAP/Firebase init splash sonrası yapılır.
    runApp(const CiftlikProApp());
  }, (Object error, StackTrace stack) {
    if (kDebugMode) debugPrint('[main.zone] uncaught: $error\n$stack');
    try {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    } catch (_) {}
  });
}

class CiftlikProApp extends StatefulWidget {
  const CiftlikProApp({super.key});

  @override
  State<CiftlikProApp> createState() => _CiftlikProAppState();
}

class _CiftlikProAppState extends State<CiftlikProApp> with WidgetsBindingObserver {
  final _navKey = GlobalKey<NavigatorState>();
  DateTime? _pausedAt;
  bool _lockOpen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      _pausedAt = DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      _maybeShowLock();
    }
  }

  Future<void> _maybeShowLock() async {
    if (_lockOpen) return;
    final ctx = _navKey.currentContext;
    if (ctx == null) return;

    // Uygulama hiç arka plana düşmemişse lock gösterme
    if (_pausedAt == null) return;

    final shouldLock = await SecurityService.instance.shouldRequireUnlock();
    if (!shouldLock) return;

    _lockOpen = true;
    await Navigator.of(ctx, rootNavigator: true).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const LockScreen(),
      ),
    );
    _lockOpen = false;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navKey,
      title: 'ÇiftlikPRO',
      debugShowCheckedModeBanner: false,
      // Sadece light tema — dark mode kullanılmıyor
      theme: DsTheme.light(),
      themeMode: ThemeMode.light,
      locale: const Locale('tr', 'TR'),
      supportedLocales: const [Locale('tr', 'TR'), Locale('en', 'US')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      // Global keyboard dismiss: form dışına tap edilince klavye kapanır.
      builder: (context, child) => DismissKeyboard(child: child ?? const SizedBox()),
      home: const SplashScreen(),
    );
  }
}
