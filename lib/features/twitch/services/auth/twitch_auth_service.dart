import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../api/core/twitch_api_client.dart';
import '../../api/auth/twitch_auth_api_service.dart';
import '../../api/auth/twitch_device_auth_api_service.dart';
import '../../models/auth/twitch_auth_token.dart';

class TwitchAuthService extends ChangeNotifier {
  static const String tokenStorageKey = 'new_twitch_app_twitch_auth_token';
  static const String clientIdStorageKey = 'new_twitch_app_twitch_client_id';

  final TwitchApiClient apiClient;
  late final TwitchDeviceAuthApiService deviceAuthApi;
  late final TwitchAuthApiService authApi;

  TwitchAuthToken? _token;
  String? _clientId;
  Future<TwitchAuthToken?>? _refreshInFlight;

  TwitchAuthService({required this.apiClient}) {
    deviceAuthApi = TwitchDeviceAuthApiService(client: apiClient);
    authApi = TwitchAuthApiService(client: apiClient);
  }

  TwitchAuthToken? get token => _token;
  String? get clientId => _clientId;

  bool get hasStoredToken => _token != null;
  bool get isLoggedIn => _token != null && !_token!.isExpired;

  String? get accessToken {
    final current = _token;
    if (current == null || current.isExpired) return null;
    return current.accessToken;
  }

  /// 讀取本機已保存 OAuth。
  ///
  /// 如果 access token 快過期或已過期，會嘗試用 refresh token 自動刷新。
  Future<void> loadStoredSession({bool refreshIfNeeded = true}) async {
    final prefs = await SharedPreferences.getInstance();

    final rawToken = prefs.getString(tokenStorageKey);
    _clientId = prefs.getString(clientIdStorageKey);

    if (rawToken != null && rawToken.trim().isNotEmpty) {
      try {
        final json = jsonDecode(rawToken);
        if (json is Map<String, dynamic>) {
          final parsed = TwitchAuthToken.fromJson(json);
          if (parsed.accessToken.isNotEmpty) {
            _token = parsed;
          }
        }
      } catch (_) {
        await prefs.remove(tokenStorageKey);
        _token = null;
      }
    }

    if (refreshIfNeeded) {
      final current = _token;
      final currentClientId = _clientId;

      if (current != null &&
          currentClientId != null &&
          currentClientId.trim().isNotEmpty &&
          current.refreshToken.trim().isNotEmpty &&
          (current.isExpired || current.expiresSoon)) {
        await refreshStoredToken();
      }
    }

    notifyListeners();
  }

  Future<void> saveSession({
    required String clientId,
    required TwitchAuthToken token,
  }) async {
    _clientId = clientId.trim();
    _token = token;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(clientIdStorageKey, _clientId!);
    await prefs.setString(tokenStorageKey, jsonEncode(token.toJson()));

    notifyListeners();
  }

  /// 回傳可用 access token。
  ///
  /// - token 還有效：直接回傳
  /// - token 快過期 / 已過期：嘗試 refresh
  /// - refresh 失敗且舊 token 已過期：回傳 null
  Future<String?> getValidAccessToken({bool forceRefresh = false}) async {
    if (_token == null) {
      await loadStoredSession(refreshIfNeeded: false);
    }

    final current = _token;
    final currentClientId = _clientId;

    if (current == null || current.accessToken.isEmpty) return null;

    final shouldRefresh =
        forceRefresh || current.isExpired || current.expiresSoon;

    if (!shouldRefresh) {
      return current.accessToken;
    }

    if (currentClientId == null ||
        currentClientId.trim().isEmpty ||
        current.refreshToken.trim().isEmpty) {
      return current.isExpired ? null : current.accessToken;
    }

    final refreshed = await refreshStoredToken();

    if (refreshed != null) {
      return refreshed.accessToken;
    }

    return current.isExpired ? null : current.accessToken;
  }

  /// 用 refresh token 更新本機 token。
  ///
  /// refresh token 可能輪替，所以成功後必須保存整包新 token。
  Future<TwitchAuthToken?> refreshStoredToken() async {
    final current = _token;
    final currentClientId = _clientId;

    if (current == null ||
        currentClientId == null ||
        currentClientId.trim().isEmpty ||
        current.refreshToken.trim().isEmpty) {
      return null;
    }

    final inFlight = _refreshInFlight;
    if (inFlight != null) {
      return inFlight;
    }

    final future = _refreshStoredTokenInternal(
      clientId: currentClientId,
      refreshToken: current.refreshToken,
    );

    _refreshInFlight = future;

    try {
      return await future;
    } finally {
      _refreshInFlight = null;
    }
  }

  Future<TwitchAuthToken?> _refreshStoredTokenInternal({
    required String clientId,
    required String refreshToken,
  }) async {
    try {
      final refreshed = await deviceAuthApi.refreshAccessToken(
        clientId: clientId,
        refreshToken: refreshToken,
      );

      await saveSession(clientId: clientId, token: refreshed);

      return refreshed;
    } catch (_) {
      return null;
    }
  }

  Future<void> logout() async {
    final currentToken = _token;
    final currentClientId = _clientId;

    _token = null;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(tokenStorageKey);

    if (currentToken != null &&
        currentToken.accessToken.isNotEmpty &&
        currentClientId != null &&
        currentClientId.isNotEmpty) {
      try {
        final revokeApi = TwitchAuthApiService(
          client: apiClient,
          clientId: currentClientId,
        );
        await revokeApi.revokeToken(currentToken.accessToken);
      } catch (_) {
        // 測試用 logout 不因 revoke 失敗而中斷。
      }
    }
  }

  Future<bool> validateCurrentToken() async {
    final token = await getValidAccessToken();

    if (token == null || token.isEmpty) {
      return false;
    }

    try {
      await authApi.validateToken(token);
      return true;
    } catch (_) {
      return false;
    }
  }
}
