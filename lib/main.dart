import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'core/datasource/local_data/preferences_manager.dart';
import 'core/services/notification_service.dart';
import 'core/providers/locale_provider.dart';
import 'core/services/session_manager.dart';
import 'core/theme/theme_data.dart';
import 'firebase_options.dart';
import 'auth/login_screen.dart';
import 'package:projects/l10n/app_localizations.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await PreferencesManager().init();
  await NotificationService.instance.initialize();
  runApp(
    ChangeNotifierProvider(
      create: (_) => LocaleProvider(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  final Duration _timeout = const Duration(minutes: 5);

  Timer? _inactivityTimer;
  DateTime _lastInteraction = DateTime.now();
  bool _isHandlingTimeout = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _resetInactivityTimer();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _inactivityTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        final elapsed = DateTime.now().difference(_lastInteraction);
        if (elapsed >= _timeout) {
          _handleTimeout();
        } else {
          _resetInactivityTimer(_timeout - elapsed);
        }
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        _inactivityTimer?.cancel();
        break;
    }
  }

  void _resetInactivityTimer([Duration? customDuration]) {
    _lastInteraction = DateTime.now();
    _inactivityTimer?.cancel();
    _inactivityTimer = Timer(customDuration ?? _timeout, _handleTimeout);
  }

  Future<void> _handleTimeout() async {
    if (_isHandlingTimeout) return;
    _isHandlingTimeout = true;

    final context = _navigatorKey.currentContext;
    if (context != null && mounted) {
      final l = AppLocalizations.of(context);
      await SessionManager.instance.logout(
        context,
        reason: l?.sessionEndedInactivity ?? 'Session ended due to inactivity.',
      );
    }

    _isHandlingTimeout = false;
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    _resetInactivityTimer();
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final localeProvider = context.watch<LocaleProvider>();

    return ScreenUtilInit(
      designSize: const Size(375, 812),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) {
        return Focus(
          autofocus: true,
          onKeyEvent: _onKey,
          child: Listener(
            behavior: HitTestBehavior.translucent,
            onPointerDown: (_) => _resetInactivityTimer(),
            onPointerMove: (_) => _resetInactivityTimer(),
            onPointerHover: (_) => _resetInactivityTimer(),
            onPointerSignal: (_) => _resetInactivityTimer(),
            child: MaterialApp(
              navigatorKey: _navigatorKey,
              navigatorObservers: [
                _InactivityNavigatorObserver(
                  onInteraction: _resetInactivityTimer,
                ),
              ],
              title: 'GovChat',
              debugShowCheckedModeBanner: false,
              theme: darkTheme,

              // ── Localization ──
              locale: localeProvider.locale,
              supportedLocales: AppLocalizations.supportedLocales,
              localizationsDelegates: const [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],

              builder: (context, child) {
                _resetInactivityTimer();
                return Directionality(
                  textDirection: localeProvider.isArabic
                      ? TextDirection.rtl
                      : TextDirection.ltr,
                  child: child ?? const SizedBox.shrink(),
                );
              },
              home: const LoginScreen(),
            ),
          ),
        );
      },
    );
  }
}

class _InactivityNavigatorObserver extends NavigatorObserver {
  _InactivityNavigatorObserver({required this.onInteraction});

  final VoidCallback onInteraction;

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    onInteraction();
    super.didPop(route, previousRoute);
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    onInteraction();
    super.didPush(route, previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    onInteraction();
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
  }
}
