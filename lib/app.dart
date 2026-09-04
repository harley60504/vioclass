import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'features/twitch/presentation/localization/vioclass_localizations.dart';
import 'features/twitch/presentation/navigation/twitch_route_observer.dart';
import 'features/twitch/presentation/pages/twitch_stream_page.dart';
import 'features/twitch/presentation/settings/twitch_app_font_controller.dart';
import 'features/twitch/presentation/settings/twitch_app_language_controller.dart';
import 'features/twitch/presentation/widgets/notifications/twitch_app_notification_overlay.dart';

class VioClassApp extends StatefulWidget {
  const VioClassApp({super.key});

  @override
  State<VioClassApp> createState() => _VioClassAppState();
}

class _VioClassAppState extends State<VioClassApp> {
  @override
  void initState() {
    super.initState();
    twitchAppFontController.addListener(_handleFontChanged);
    twitchAppLanguageController.addListener(_handleLanguageChanged);
    twitchAppFontController.load();
    twitchAppLanguageController.load();
  }

  @override
  void dispose() {
    twitchAppFontController.removeListener(_handleFontChanged);
    twitchAppLanguageController.removeListener(_handleLanguageChanged);
    super.dispose();
  }

  void _handleFontChanged() {
    if (mounted) setState(() {});
  }

  void _handleLanguageChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final appFontFamily = twitchAppFontController.fontFamily;
    final baseTheme = ThemeData(
      brightness: Brightness.dark,
      colorSchemeSeed: const Color(0xFF9146FF),
      scaffoldBackgroundColor: const Color(0xFF0E0E10),
      fontFamily: appFontFamily,
      fontFamilyFallback: TwitchAppFontController.fontFallback,
      useMaterial3: true,
    );

    return MaterialApp(
      title: 'VioClass',
      debugShowCheckedModeBanner: false,
      locale: twitchAppLanguageController.locale,
      supportedLocales: const [Locale('zh', 'TW'), Locale('en')],
      localizationsDelegates: const [
        VioClassLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      localeListResolutionCallback: (locales, supportedLocales) {
        final preferred = locales?.first;
        if (preferred?.languageCode == 'en') return const Locale('en');
        if (preferred?.languageCode == 'zh') return const Locale('zh', 'TW');
        return const Locale('zh', 'TW');
      },
      navigatorObservers: <NavigatorObserver>[twitchRouteObserver],
      theme: baseTheme.copyWith(
        textTheme: baseTheme.textTheme.apply(
          fontFamily: appFontFamily,
          fontFamilyFallback: TwitchAppFontController.fontFallback,
        ),
        primaryTextTheme: baseTheme.primaryTextTheme.apply(
          fontFamily: appFontFamily,
          fontFamilyFallback: TwitchAppFontController.fontFallback,
        ),
      ),
      builder: (context, child) {
        return TwitchAppNotificationOverlay(
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: const _StartupSafeHome(),
    );
  }
}

class _StartupSafeHome extends StatefulWidget {
  const _StartupSafeHome();

  @override
  State<_StartupSafeHome> createState() => _StartupSafeHomeState();
}

class _StartupSafeHomeState extends State<_StartupSafeHome> {
  bool showTwitchHome = false;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future<void>.delayed(const Duration(milliseconds: 300));
      if (!mounted) return;
      setState(() {
        showTwitchHome = true;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    if (showTwitchHome) {
      return const TwitchStreamPage();
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0E0E10),
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxHeight < 150) {
            return const Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: Color(0xFF9146FF),
                  strokeWidth: 2.6,
                ),
              ),
            );
          }

          return const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.live_tv_rounded, color: Color(0xFF9146FF), size: 64),
                SizedBox(height: 14),
                CircularProgressIndicator(color: Color(0xFF9146FF)),
              ],
            ),
          );
        },
      ),
    );
  }
}
