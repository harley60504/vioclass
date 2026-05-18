// Stage 220F: Isolated entrypoint for player_core testing.
//
// Run with:
// flutter run -d windows -t lib/player_core_test_main.dart
// flutter run -d android -t lib/player_core_test_main.dart
//
// This avoids importing app.dart / WatchPage while the player_core branch is
// testing the PiliPlus media_kit fork API.

import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';

import 'features/twitch/presentation/pages/twitch_player_core_test_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  runApp(const TwitchPlayerCoreTestApp());
}

class TwitchPlayerCoreTestApp extends StatelessWidget {
  const TwitchPlayerCoreTestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Twitch Player Core Test',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        colorSchemeSeed: const Color(0xFF9146FF),
        scaffoldBackgroundColor: const Color(0xFF0E0E10),
        useMaterial3: true,
      ),
      home: const TwitchPlayerCoreTestPage(),
    );
  }
}
