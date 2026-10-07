import '../auth/twitch_auth_api_service.dart';
import '../core/twitch_api_client.dart';
import '../core/twitch_api_constants.dart';
import '../../models/channel/twitch_user.dart';

/// Read-only identity lookup. Uses the validated client ID, never a different
/// linked account to bypass the selected viewer's authorization.
class TwitchChatUserProfileApiService {
  final TwitchApiClient client;
  final List<Future<String?> Function()> tokenProviders;
  final String? ownerId;
  final bool Function() isCurrent;

  const TwitchChatUserProfileApiService({
    required this.client,
    required this.tokenProviders,
    required this.ownerId,
    required this.isCurrent,
  });

  Future<TwitchUser?> getUser({required String login, String? userId}) async {
    final id = userId?.trim() ?? '';
    final clean = login.trim().toLowerCase();
    final byId = RegExp(r'^\d+$').hasMatch(id);
    if (!RegExp(r'^\d+$').hasMatch(id) &&
        !RegExp(r'^[a-z0-9_]{1,25}$').hasMatch(clean)) {
      throw const TwitchChatUserProfileException('無法辨識這個 Twitch 使用者。');
    }
    for (final provider in tokenProviders) {
      String? token;
      TwitchTokenValidation validation;
      try {
        token = (await provider())?.trim();
        if (token == null || token.isEmpty) continue;
        validation = await TwitchAuthApiService(
          client: client,
        ).validateToken(token);
      } catch (_) {
        continue;
      }
      if (validation.clientId.isEmpty ||
          (ownerId != null && validation.userId != ownerId)) {
        continue;
      }
      if (!isCurrent()) {
        throw const TwitchChatUserProfileException('觀看頻道或登入帳號已變更。');
      }
      final result = await client.getJson<Map<String, dynamic>>(
        '${TwitchApiConstants.helixBaseUrl}/users',
        queryParameters: RegExp(r'^\d+$').hasMatch(id)
            ? {'id': id}
            : {'login': clean},
        headers: {
          'Client-ID': validation.clientId,
          'Authorization': 'Bearer $token',
        },
      );
      if (!isCurrent()) {
        throw const TwitchChatUserProfileException('觀看頻道或登入帳號已變更。');
      }
      final rows = result['data'];
      if (rows is! List || rows.isEmpty || rows.first is! Map) return null;
      final user = TwitchUser.fromHelixJson(
        Map<String, dynamic>.from(rows.first as Map),
      );
      if ((id.isNotEmpty && RegExp(r'^\d+$').hasMatch(id) && user.id != id) ||
          (!byId && user.login.toLowerCase() != clean)) {
        throw const TwitchChatUserProfileException('使用者資料與選取對象不符。');
      }
      return user;
    }
    throw const TwitchChatUserProfileException('請先登入 Twitch 載入官方使用者資料。');
  }
}

class TwitchChatUserProfileException implements Exception {
  final String message;
  const TwitchChatUserProfileException(this.message);
}
