// PATCH VERSION: twitch_web_gql_auth_service_token_split_v15
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../api/auth/twitch_auth_api_service.dart';
import '../../api/core/twitch_api_client.dart';
import '../../api/core/twitch_api_constants.dart';
import '../../models/auth/twitch_auth_token.dart';

/// Stores the Twitch Web / kimne GQL token separately from both:
///
/// - main Twitch OAuth token: Helix / IRC / normal account actions
/// - Drops Android token: Twitch-style FollowButton_* APQ mutations
///
/// Earlier patches reused TwitchDropsAuthService for the Web interaction token.
/// That polluted `new_twitch_app_twitch_drops_token` with a kimne/Web token and
/// made Follow / Unfollow fail integrity checks. This service owns the Web token
/// with a dedicated key namespace.
class TwitchWebGqlAuthService extends ChangeNotifier {
  static const String tokenStorageKey = 'new_twitch_app_twitch_web_gql_token';
  static const String clientIdStorageKey =
      'new_twitch_app_twitch_web_gql_client_id';
  static const String validatedAtStorageKey =
      'new_twitch_app_twitch_web_gql_validated_at';

  /// Legacy keys that were accidentally used by old interaction-login patches.
  static const String legacyDropsTokenStorageKey =
      'new_twitch_app_twitch_drops_token';
  static const String legacyDropsClientIdStorageKey =
      'new_twitch_app_twitch_drops_client_id';
  static const String legacyDropsValidatedAtStorageKey =
      'new_twitch_app_twitch_drops_validated_at';

  final TwitchApiClient apiClient;
  late final TwitchAuthApiService authApi;

  TwitchAuthToken? _token;
  DateTime? _lastValidatedAt;
  String _clientId = TwitchApiConstants.twitchWebClientId;

  TwitchWebGqlAuthService({required this.apiClient}) {
    authApi = TwitchAuthApiService(
      client: apiClient,
      clientId: TwitchApiConstants.twitchWebClientId,
    );
  }

  TwitchAuthToken? get token => _token;
  DateTime? get lastValidatedAt => _lastValidatedAt;
  bool get hasStoredToken => _token != null;
  String get clientId => _clientId.trim();

  String? get accessToken {
    final current = _token;
    if (current == null || current.accessToken.trim().isEmpty) return null;
    return current.accessToken;
  }

  Future<void> loadStoredSession({
    bool migrateLegacyDropsWebToken = true,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    if (migrateLegacyDropsWebToken) {
      await _migrateLegacyDropsWebTokenIfNeeded(prefs);
    }

    final storedClientId = prefs.getString(clientIdStorageKey);
    if (storedClientId != null && storedClientId.trim().isNotEmpty) {
      _clientId = storedClientId.trim();
    } else {
      _clientId = TwitchApiConstants.twitchWebClientId;
    }

    final validatedAt = prefs.getString(validatedAtStorageKey);
    if (validatedAt != null && validatedAt.trim().isNotEmpty) {
      _lastValidatedAt = DateTime.tryParse(validatedAt);
    }

    final rawToken = prefs.getString(tokenStorageKey);
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

  Future<void> saveSession(TwitchAuthToken token) async {
    _clientId = TwitchApiConstants.twitchWebClientId;
    _token = token;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(clientIdStorageKey, _clientId);
    await prefs.setString(tokenStorageKey, jsonEncode(token.toJson()));

    notifyListeners();
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
      if (validation.clientId.trim().isNotEmpty &&
          validation.clientId.trim() != TwitchApiConstants.twitchWebClientId) {
        await logout();
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
      await logout();
      return false;
    }
  }

  Future<void> logout() async {
    _token = null;
    _lastValidatedAt = null;
    _clientId = TwitchApiConstants.twitchWebClientId;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(tokenStorageKey);
    await prefs.remove(validatedAtStorageKey);
    await prefs.setString(clientIdStorageKey, _clientId);

    notifyListeners();
  }

  Future<void> _migrateLegacyDropsWebTokenIfNeeded(
    SharedPreferences prefs,
  ) async {
    final legacyClientId = prefs
        .getString(legacyDropsClientIdStorageKey)
        ?.trim();
    if (legacyClientId != TwitchApiConstants.twitchWebClientId) return;

    final legacyRaw = prefs.getString(legacyDropsTokenStorageKey);
    if (legacyRaw != null && legacyRaw.trim().isNotEmpty) {
      final existingWebRaw = prefs.getString(tokenStorageKey);
      if (existingWebRaw == null || existingWebRaw.trim().isEmpty) {
        await prefs.setString(tokenStorageKey, legacyRaw);
        await prefs.setString(
          clientIdStorageKey,
          TwitchApiConstants.twitchWebClientId,
        );
        final legacyValidatedAt = prefs.getString(
          legacyDropsValidatedAtStorageKey,
        );
        if (legacyValidatedAt != null && legacyValidatedAt.trim().isNotEmpty) {
          await prefs.setString(validatedAtStorageKey, legacyValidatedAt);
        }
      }
    }

    // Clear the polluted Drops slot so Android/Drops device flow can own it.
    await prefs.remove(legacyDropsTokenStorageKey);
    await prefs.remove(legacyDropsValidatedAtStorageKey);
    await prefs.remove(legacyDropsClientIdStorageKey);
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'hasStoredToken': hasStoredToken,
      'hasAccessToken': accessToken != null && accessToken!.trim().isNotEmpty,
      'lastValidatedAt': lastValidatedAt?.toIso8601String(),
      'clientId': clientId,
      'storageKey': tokenStorageKey,
    };
  }
}
