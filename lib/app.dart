import 'package:flutter/material.dart';

import 'features/twitch/presentation/navigation/twitch_route_observer.dart';
import 'features/twitch/presentation/pages/twitch_stream_page.dart';
import 'features/twitch/presentation/widgets/notifications/twitch_app_notification_overlay.dart';

class VioClassApp extends StatelessWidget {
  const VioClassApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VioClass',
      debugShowCheckedModeBanner: false,
      navigatorObservers: <NavigatorObserver>[twitchRouteObserver],
      theme: ThemeData(
        brightness: Brightness.dark,
        colorSchemeSeed: const Color(0xFF9146FF),
        scaffoldBackgroundColor: const Color(0xFF0E0E10),
        useMaterial3: true,
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

    // 先讓 Windows 主視窗成功畫出第一幀，再載入真正首頁。
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
                SizedBox(height: 18),
                Text(
                  'Starting VioClass...',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
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
