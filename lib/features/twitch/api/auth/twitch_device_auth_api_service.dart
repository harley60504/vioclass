import 'package:dio/dio.dart';

import '../../models/auth/twitch_auth_token.dart';
import '../core/twitch_api_client.dart';
import '../core/twitch_api_exception.dart';

class TwitchDeviceAuthorization {
  final String deviceCode;
  final String userCode;
  final String verificationUri;
  final int expiresIn;
  final int interval;

  const TwitchDeviceAuthorization({
    required this.deviceCode,
    required this.userCode,
    required this.verificationUri,
    required this.expiresIn,
    required this.interval,
  });

  factory TwitchDeviceAuthorization.fromJson(Map<String, dynamic> json) {
    return TwitchDeviceAuthorization(
      deviceCode: json['device_code']?.toString() ?? '',
      userCode: json['user_code']?.toString() ?? '',
      verificationUri: json['verification_uri']?.toString() ?? '',
      expiresIn: int.tryParse(json['expires_in']?.toString() ?? '') ?? 1800,
      interval: int.tryParse(json['interval']?.toString() ?? '') ?? 5,
    );
  }
}

enum TwitchDeviceTokenPollStatus {
  success,
  pending,
  slowDown,
  expired,
  denied,
  error,
}

class TwitchDeviceTokenPollResult {
  final TwitchDeviceTokenPollStatus status;
  final TwitchAuthToken? token;
  final String? message;
  final int? nextIntervalSeconds;

  const TwitchDeviceTokenPollResult({
    required this.status,
    this.token,
    this.message,
    this.nextIntervalSeconds,
  });

  bool get isDone {
    return status == TwitchDeviceTokenPollStatus.success ||
        status == TwitchDeviceTokenPollStatus.expired ||
        status == TwitchDeviceTokenPollStatus.denied ||
        status == TwitchDeviceTokenPollStatus.error;
  }
}

/// Twitch OAuth Device Code Flow API。
///
/// 這層只打 OAuth endpoint，不保存 token，也不處理 UI。
class TwitchDeviceAuthApiService {
  final TwitchApiClient client;

  const TwitchDeviceAuthApiService({required this.client});

  Future<TwitchDeviceAuthorization> startDeviceAuthorization({
    required String clientId,
    required List<String> scopes,
  }) async {
    final response = await client.dio.post<dynamic>(
      'https://id.twitch.tv/oauth2/device',
      data: <String, dynamic>{
        'client_id': clientId.trim(),
        'scopes': scopes.join(' '),
      },
      options: Options(
        contentType: Headers.formUrlEncodedContentType,
        responseType: ResponseType.json,
        validateStatus: (status) => status != null && status < 500,
      ),
    );

    final statusCode = response.statusCode ?? 0;
    final data = response.data;

    if (statusCode < 200 || statusCode >= 300) {
      throw TwitchApiException(
        _readOAuthError(data) ?? 'Device authorization failed.',
        statusCode: statusCode,
        uri: response.realUri,
        details: data,
      );
    }

    if (data is! Map<String, dynamic>) {
      throw TwitchApiException(
        'Unexpected device authorization response type: ${data.runtimeType}.',
        statusCode: statusCode,
        uri: response.realUri,
        details: data,
      );
    }

    final authorization = TwitchDeviceAuthorization.fromJson(data);

    if (authorization.deviceCode.isEmpty ||
        authorization.userCode.isEmpty ||
        authorization.verificationUri.isEmpty) {
      throw TwitchApiException(
        'Incomplete device authorization response.',
        statusCode: statusCode,
        uri: response.realUri,
        details: data,
      );
    }

    return authorization;
  }

  Future<TwitchDeviceTokenPollResult> pollDeviceToken({
    required String clientId,
    required String deviceCode,
    required List<String> scopes,
    int currentIntervalSeconds = 5,
  }) async {
    final response = await client.dio.post<dynamic>(
      'https://id.twitch.tv/oauth2/token',
      data: <String, dynamic>{
        'client_id': clientId.trim(),
        'device_code': deviceCode.trim(),
        'grant_type': 'urn:ietf:params:oauth:grant-type:device_code',
        'scopes': scopes.join(' '),
      },
      options: Options(
        contentType: Headers.formUrlEncodedContentType,
        responseType: ResponseType.json,
        validateStatus: (status) => status != null && status < 500,
      ),
    );

    final statusCode = response.statusCode ?? 0;
    final data = response.data;

    if (statusCode >= 200 && statusCode < 300) {
      if (data is! Map<String, dynamic>) {
        return TwitchDeviceTokenPollResult(
          status: TwitchDeviceTokenPollStatus.error,
          message: 'Unexpected token response type: ${data.runtimeType}.',
        );
      }

      final token = TwitchAuthToken.fromOAuthJson(data);
      if (token.accessToken.isEmpty) {
        return const TwitchDeviceTokenPollResult(
          status: TwitchDeviceTokenPollStatus.error,
          message: 'Token response did not contain access_token.',
        );
      }

      return TwitchDeviceTokenPollResult(
        status: TwitchDeviceTokenPollStatus.success,
        token: token,
      );
    }

    final error = _readOAuthError(data) ?? 'unknown_error';

    if (error.contains('authorization_pending')) {
      return const TwitchDeviceTokenPollResult(
        status: TwitchDeviceTokenPollStatus.pending,
        message: '等待使用者完成 Twitch 授權...',
      );
    }

    if (error.contains('slow_down')) {
      return TwitchDeviceTokenPollResult(
        status: TwitchDeviceTokenPollStatus.slowDown,
        message: '輪詢太快，已延長等待時間。',
        nextIntervalSeconds: currentIntervalSeconds + 5,
      );
    }

    if (error.contains('expired_token') || error.contains('expired')) {
      return TwitchDeviceTokenPollResult(
        status: TwitchDeviceTokenPollStatus.expired,
        message: error,
      );
    }

    if (error.contains('access_denied') || error.contains('denied')) {
      return TwitchDeviceTokenPollResult(
        status: TwitchDeviceTokenPollStatus.denied,
        message: error,
      );
    }

    return TwitchDeviceTokenPollResult(
      status: TwitchDeviceTokenPollStatus.error,
      message: error,
    );
  }

  /// 用 refresh_token 換新的 access_token。
  ///
  /// Device Code Flow 的 public client 不需要 client_secret，但 refresh token 會輪替，
  /// 所以呼叫端必須把回傳的新 refresh token 存起來。
  Future<TwitchAuthToken> refreshAccessToken({
    required String clientId,
    required String refreshToken,
  }) async {
    final response = await client.dio.post<dynamic>(
      'https://id.twitch.tv/oauth2/token',
      data: <String, dynamic>{
        'client_id': clientId.trim(),
        'grant_type': 'refresh_token',
        'refresh_token': refreshToken.trim(),
      },
      options: Options(
        contentType: Headers.formUrlEncodedContentType,
        responseType: ResponseType.json,
        validateStatus: (status) => status != null && status < 500,
      ),
    );

    final statusCode = response.statusCode ?? 0;
    final data = response.data;

    if (statusCode < 200 || statusCode >= 300) {
      throw TwitchApiException(
        _readOAuthError(data) ?? 'Refresh access token failed.',
        statusCode: statusCode,
        uri: response.realUri,
        details: data,
      );
    }

    if (data is! Map<String, dynamic>) {
      throw TwitchApiException(
        'Unexpected refresh token response type: ${data.runtimeType}.',
        statusCode: statusCode,
        uri: response.realUri,
        details: data,
      );
    }

    final token = TwitchAuthToken.fromOAuthJson(data);
    if (token.accessToken.isEmpty) {
      throw TwitchApiException(
        'Refresh response did not contain access_token.',
        statusCode: statusCode,
        uri: response.realUri,
        details: data,
      );
    }

    return token;
  }

  String? _readOAuthError(Object? data) {
    if (data is Map) {
      final error = data['error']?.toString();
      final message = data['message']?.toString();
      if (error != null && error.isNotEmpty) {
        return message == null || message.isEmpty ? error : '$error: $message';
      }
      if (message != null && message.isNotEmpty) return message;
    }

    if (data is String && data.trim().isNotEmpty) {
      return data.trim();
    }

    return null;
  }
}
