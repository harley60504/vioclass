import 'package:dio/dio.dart';

import '../auth/twitch_auth_api_service.dart';
import '../core/twitch_api_client.dart';
import '../core/twitch_api_constants.dart';

/// Official chat-color update; does not alter login storage or IRC commands.
class TwitchChatIdentityApiService {
  final TwitchApiClient client;
  final List<Future<String?> Function()> tokenProviders;

  const TwitchChatIdentityApiService({
    required this.client,
    required this.tokenProviders,
  });

  Future<void> updateColor({
    required String userId,
    required String color,
  }) async {
    for (final provider in tokenProviders) {
      final token = await provider();
      if (token == null || token.trim().isEmpty) continue;
      TwitchTokenValidation validation;
      try {
        validation = await TwitchAuthApiService(
          client: client,
        ).validateToken(token);
      } catch (_) {
        continue;
      }
      if (validation.userId != userId ||
          !validation.scopes.contains('user:manage:chat_color')) {
        continue;
      }
      final response = await client.dio.put<dynamic>(
        '${TwitchApiConstants.helixBaseUrl}/chat/color',
        queryParameters: {'user_id': userId, 'color': color},
        options: Options(
          headers: {
            'Client-ID': validation.clientId,
            'Authorization': 'Bearer ${token.trim()}',
          },
        ),
      );
      if (response.statusCode == 204) return;
      if (response.statusCode == 400 && color.startsWith('#')) {
        throw const TwitchChatColorException(
          '自訂色碼需要 Twitch Prime 或 Turbo，請改用預設色票。',
        );
      }
      throw const TwitchChatColorException('ID 顏色更新失敗，請稍後再試。');
    }
    throw const TwitchChatColorException(
      '目前登入缺少修改 ID 顏色的授權，請使用具備 user:manage:chat_color 權限的帳號登入。',
    );
  }
}

class TwitchChatColorException implements Exception {
  final String message;
  const TwitchChatColorException(this.message);
}
