// ignore_for_file: avoid_relative_lib_imports
// Explicitly armed, local-only login reset. Never reset application preferences.
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../lib/features/twitch/services/auth/twitch_auth_service.dart';
import '../lib/features/twitch/services/auth/twitch_drops_auth_service.dart';
import '../lib/features/twitch/services/auth/twitch_web_gql_auth_service.dart';
import '../lib/features/twitch/services/chat/twitch_whisper_login_integrity_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!Platform.isWindows ||
      !const bool.fromEnvironment('TWITCH_RESET_LOGIN')) {
    throw StateError('Login reset must be explicitly armed on Windows.');
  }
  final prefs = await SharedPreferences.getInstance();
  const keys = [
    TwitchAuthService.tokenStorageKey,
    TwitchAuthService.clientIdStorageKey,
    TwitchWebGqlAuthService.tokenStorageKey,
    TwitchWebGqlAuthService.clientIdStorageKey,
    TwitchWebGqlAuthService.validatedAtStorageKey,
    TwitchDropsAuthService.tokenStorageKey,
    TwitchDropsAuthService.clientIdStorageKey,
    TwitchDropsAuthService.validatedAtStorageKey,
    'new_twitch_app_twitch_interaction_gql_verified_at',
  ];
  for (final key in keys) {
    await prefs.remove(key);
  }
  const storage = FlutterSecureStorage();
  await storage.delete(key: TwitchWhisperLoginIntegrityService.storageKey);
  await prefs.reload();
  if (keys.any(prefs.containsKey) ||
      await storage.containsKey(
        key: TwitchWhisperLoginIntegrityService.storageKey,
      )) {
    throw StateError('Login reset verification failed.');
  }
  debugPrint(
    '[TwitchLoginReset] verified: token slots and integrity cache absent; unrelated data preserved',
  );
  await SystemNavigator.pop();
}
