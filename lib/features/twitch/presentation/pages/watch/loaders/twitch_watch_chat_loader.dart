// PATCH VERSION: twitch_watch_chat_loader_stage141
//
// Chat-only WatchPage startup loader.
// Owns startup snapshot, OAuth validation, channel id resolution and IRC
// runtime creation. WatchPage only consumes the returned result.

import '../../../../api/auth/twitch_auth_api_service.dart';
import '../../../../api/chat/twitch_chat_startup_api_service.dart';
import '../../../../api/chat/twitch_irc_api_service.dart';
import '../../../../api/chat/twitch_recent_messages_api_service.dart';
import '../../../../services/auth/twitch_auth_service.dart';
import '../../../../services/auth/twitch_drops_auth_service.dart';
import '../../../../services/chat/twitch_badge_cache_service.dart';
import '../../../../services/chat/twitch_chat_runtime.dart';

class TwitchWatchChatLoader {
  final TwitchAuthService authService;
  final TwitchDropsAuthService dropsAuthService;
  final TwitchAuthApiService authApi;
  final TwitchChatStartupApiService chatStartupApi;
  final TwitchRecentMessagesApiService recentMessagesApi;

  const TwitchWatchChatLoader({
    required this.authService,
    required this.dropsAuthService,
    required this.authApi,
    required this.chatStartupApi,
    required this.recentMessagesApi,
  });

  Future<TwitchWatchChatLoadResult> connect({
    required String channelLogin,
    TwitchChatRuntime? previousRuntime,
  }) async {
    await previousRuntime?.disposeRuntime();

    final token = await authService.getValidAccessToken();
    if (token == null || token.isEmpty) {
      throw StateError('沒有可用 OAuth，不能連線可發言聊天室。');
    }

    await dropsAuthService.loadStoredSession();
    final validation = await authApi.validateToken(token);
    final startup = await chatStartupApi.fetchParsedStartupSnapshot(
      channelLogin: channelLogin,
    );

    final runtime = TwitchChatRuntime(
      ircApi: TwitchIrcApiService(),
      writeIrcApi: TwitchIrcApiService(),
      badgeCache: TwitchBadgeCacheService(),
      recentMessagesApi: recentMessagesApi,
    );

    await runtime.connect(
      channelLogin: channelLogin,
      accessToken: token,
      ircNick: validation.login,
      viewerLogin: validation.login,
      viewerDisplayName: validation.login,
      viewerUserId: validation.userId,
      badgeCatalog: startup.badgeCatalog,
      preloadRecentMessages: true,
      recentMessageLimit: 100,
    );

    return TwitchWatchChatLoadResult(
      runtime: runtime,
      viewerLogin: validation.login,
      viewerId: validation.userId,
      viewerScopes: validation.scopes,
      channelId: startup.channelId,
    );
  }
}

class TwitchWatchChatLoadResult {
  final TwitchChatRuntime runtime;
  final String viewerLogin;
  final String viewerId;
  final List<String> viewerScopes;
  final String channelId;

  const TwitchWatchChatLoadResult({
    required this.runtime,
    required this.viewerLogin,
    required this.viewerId,
    required this.viewerScopes,
    required this.channelId,
  });
}
