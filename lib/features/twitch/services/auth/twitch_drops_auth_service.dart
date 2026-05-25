// PATCH VERSION: twitch_drops_auth_service_token_split_v15
import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../api/auth/twitch_auth_api_service.dart';
import '../../api/auth/twitch_device_auth_api_service.dart';
import '../../api/auth/twitch_drops_device_auth_api_service.dart';
import '../../api/core/twitch_api_client.dart';
import '../../api/core/twitch_api_constants.dart';
import '../../models/auth/twitch_auth_token.dart';

class TwitchDropsAuthService extends ChangeNotifier {
  static const String tokenStorageKey = 'new_twitch_app_twitch_drops_token';
  static const String clientIdStorageKey =
      'new_twitch_app_twitch_drops_client_id';
  static const String validatedAtStorageKey =
      'new_twitch_app_twitch_drops_validated_at';

  final TwitchApiClient apiClient;
  late final TwitchDropsDeviceAuthApiService dropsDeviceAuthApi;
  late final TwitchAuthApiService authApi;

  TwitchAuthToken? _token;
  DateTime? _lastValidatedAt;
  String _dropsClientId = TwitchApiConstants.twitchDefaultDropsClientId;

  TwitchDropsAuthService({required this.apiClient}) {
    dropsDeviceAuthApi = TwitchDropsDeviceAuthApiService(
      deviceAuthApi: TwitchDeviceAuthApiService(client: apiClient),
      clientIdProvider: () => _dropsClientId,
    );
    authApi = TwitchAuthApiService(client: apiClient);
  }

  TwitchAuthToken? get token => _token;
  DateTime? get lastValidatedAt => _lastValidatedAt;
  bool get hasStoredToken => _token != null;
  String get dropsClientId => _dropsClientId.trim();
  bool get hasDropsClientId => dropsClientId.isNotEmpty;

  /// Twitch-style: do not proactively expire this token by expires_at.
  ///
  /// Drops/channel-points auth uses the token until Twitch rejects it. This
  /// avoids fighting the Android/mobile public-client behavior.
  String? get accessToken {
    final current = _token;
    if (current == null || current.accessToken.trim().isEmpty) return null;
    return current.accessToken;
  }

  Future<void> loadStoredSession() async {
    final prefs = await SharedPreferences.getInstance();

    final storedClientId = prefs.getString(clientIdStorageKey);
    final safeStoredClientId = storedClientId?.trim();
    if (safeStoredClientId != null &&
        safeStoredClientId.isNotEmpty &&
        !_looksLikeWebClientId(safeStoredClientId)) {
      _dropsClientId = safeStoredClientId;
    } else {
      _dropsClientId = _defaultDropsClientId();
      if (safeStoredClientId != null &&
          safeStoredClientId.isNotEmpty &&
          _looksLikeWebClientId(safeStoredClientId)) {
        // A previous patch accidentally stored Twitch Web Client-ID in the
        // Drops auth slot. Move that token into the dedicated Web GQL slot when
        // possible, then clear the Drops slot so Android device flow can own it.
        final rawToken = prefs.getString(tokenStorageKey);
        if (rawToken != null && rawToken.trim().isNotEmpty) {
          final existingWebToken = prefs.getString(
            'new_twitch_app_twitch_web_gql_token',
          );
          if (existingWebToken == null || existingWebToken.trim().isEmpty) {
            await prefs.setString(
              'new_twitch_app_twitch_web_gql_token',
              rawToken,
            );
            await prefs.setString(
              'new_twitch_app_twitch_web_gql_client_id',
              TwitchApiConstants.twitchWebClientId,
            );
            final legacyValidatedAt = prefs.getString(validatedAtStorageKey);
            if (legacyValidatedAt != null &&
                legacyValidatedAt.trim().isNotEmpty) {
              await prefs.setString(
                'new_twitch_app_twitch_web_gql_validated_at',
                legacyValidatedAt,
              );
            }
          }
        }
        await prefs.remove(clientIdStorageKey);
        await prefs.remove(tokenStorageKey);
        await prefs.remove(validatedAtStorageKey);
      }
    }

    final rawToken = prefs.getString(tokenStorageKey);
    final validatedAt = prefs.getString(validatedAtStorageKey);

    if (validatedAt != null && validatedAt.trim().isNotEmpty) {
      _lastValidatedAt = DateTime.tryParse(validatedAt);
    }

    if (rawToken != null && rawToken.trim().isNotEmpty) {
      try {
        final json = jsonDecode(rawToken);
        if (json is Map<String, dynamic>) {
          final parsed = TwitchAuthToken.fromJson(json);
          if (parsed.accessToken.trim().isNotEmpty) {
            _token = parsed;
          }
        }
      } catch (_) {
        await prefs.remove(tokenStorageKey);
        _token = null;
      }
    }

    notifyListeners();
  }

  Future<void> setDropsClientId(
    String clientId, {
    bool clearTokenOnChange = true,
  }) async {
    final requested = clientId.trim();
    final next = requested.isEmpty
        ? ''
        : _looksLikeWebClientId(requested)
        ? _defaultDropsClientId()
        : requested;
    final changed = next != _dropsClientId.trim();

    _dropsClientId = next;

    final prefs = await SharedPreferences.getInstance();
    if (next.isEmpty) {
      await prefs.remove(clientIdStorageKey);
    } else {
      await prefs.setString(clientIdStorageKey, next);
    }

    if (changed && clearTokenOnChange) {
      _token = null;
      _lastValidatedAt = null;
      await prefs.remove(tokenStorageKey);
      await prefs.remove(validatedAtStorageKey);
    }

    notifyListeners();
  }

  Future<void> saveSession(TwitchAuthToken token) async {
    _token = token;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(tokenStorageKey, jsonEncode(token.toJson()));
    if (_dropsClientId.trim().isNotEmpty) {
      await prefs.setString(clientIdStorageKey, _dropsClientId.trim());
    }

    notifyListeners();
  }

  Future<TwitchDeviceAuthorization> startDeviceFlow() {
    return dropsDeviceAuthApi.startDeviceFlow();
  }

  Future<TwitchDeviceTokenPollResult> pollForToken({
    required String deviceCode,
    int currentIntervalSeconds = 5,
  }) async {
    final result = await dropsDeviceAuthApi.pollForToken(
      deviceCode: deviceCode,
      currentIntervalSeconds: currentIntervalSeconds,
    );

    final token = result.token;
    if (result.status == TwitchDeviceTokenPollStatus.success && token != null) {
      await saveSession(token);
    }

    return result;
  }

  Future<String?> getToken() async {
    if (_token == null) {
      await loadStoredSession();
    }

    return accessToken;
  }

  Future<bool> validateToken() async {
    final token = await getToken();
    if (token == null || token.trim().isEmpty) return false;

    try {
      final validation = await authApi.validateToken(token);
      final expectedClientId = dropsClientId;
      if (validation.clientId.trim().isNotEmpty &&
          expectedClientId.isNotEmpty &&
          validation.clientId.trim() != expectedClientId) {
        await logout(clearClientId: false);
        return false;
      }

      _lastValidatedAt = DateTime.now();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        validatedAtStorageKey,
        _lastValidatedAt!.toIso8601String(),
      );

      notifyListeners();
      return true;
    } catch (_) {
      await logout(clearClientId: false);
      return false;
    }
  }

  Future<void> logout({bool clearClientId = false}) async {
    _token = null;
    _lastValidatedAt = null;

    if (clearClientId) {
      _dropsClientId = '';
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(tokenStorageKey);
    await prefs.remove(validatedAtStorageKey);
    if (clearClientId) {
      await prefs.remove(clientIdStorageKey);
    }

    notifyListeners();
  }

  static bool _looksLikeWebClientId(String value) {
    return value.trim() == TwitchApiConstants.twitchWebClientId.trim();
  }

  static String _defaultDropsClientId() {
    final configured = TwitchApiConstants.twitchDefaultDropsClientId.trim();
    if (configured.isNotEmpty && !_looksLikeWebClientId(configured)) {
      return configured;
    }
    return TwitchApiConstants.twitchAndroidClientId.trim();
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'hasStoredToken': hasStoredToken,
      'hasAccessToken': accessToken != null && accessToken!.trim().isNotEmpty,
      'lastValidatedAt': lastValidatedAt?.toIso8601String(),
      'dropsClientIdConfigured': hasDropsClientId,
      'dropsClientId': hasDropsClientId ? dropsClientId : '<empty>',
      'dropsClientIdLooksLikeWebClientId':
          hasDropsClientId && _looksLikeWebClientId(dropsClientId),
      'expectedAndroidDropsClientId': _defaultDropsClientId(),
      'defaultDartDefineClientIdConfigured':
          TwitchApiConstants.hasDefaultDropsClientId,
    };
  }
}
