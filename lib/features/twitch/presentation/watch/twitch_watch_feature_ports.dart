// PATCH VERSION: twitch_watch_feature_ports_stage220i_nullable_player_handles
//
// Feature-facing ports for Watch composition.
//
// A port is intentionally thinner than a controller. It exposes the operations
// a UI feature needs so components can depend on their own interface instead of
// depending on TwitchWatchPage callbacks.

import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../api/channel/twitch_private_gql_relationship_api_service_v1.dart';
import '../../api/chat/twitch_recent_messages_api_service.dart';
import '../../api/engagement/twitch_channel_points_api_service.dart';
import '../../models/chat/twitch_chat_startup.dart';
import '../../models/engagement/twitch_prediction.dart';
import '../../models/playback/twitch_m3u8_variant.dart';
import '../../services/chat/twitch_official_emote_cache_service.dart';
import '../../services/chat/twitch_third_party_emote_cache_service.dart';
import '../../services/engagement/twitch_channel_points_runtime_service.dart';
import '../../services/playback/twitch_playlist_player_runtime.dart';
import '../../services/watch/twitch_watch_feature_services.dart';
import '../../services/watch/twitch_watch_services.dart';

class TwitchWatchPlayerPort {
  final TwitchWatchPlayerServices services;

  const TwitchWatchPlayerPort({required this.services});

  TwitchPlaylistPlayerRuntime get runtime => services.playerRuntime;
  Player? get playerOrNull => services.playerSession.playerOrNull;
  VideoController? get videoControllerOrNull =>
      services.playerSession.videoControllerOrNull;
  Player get player => services.playerSession.player;
  VideoController get videoController => services.playerSession.videoController;
  List<TwitchM3u8Variant> get qualityVariants => services.playerRuntime.variants;
  TwitchM3u8Variant? get currentVariant => services.playerRuntime.currentVariant;
  bool get busy => services.playerRuntime.busy;
  Object? get error => services.playerRuntime.error;

  Future<Uri?> loadLivePlaylist({required String channelLogin}) {
    return services.playerRuntime.loadLivePlaylist(channelLogin: channelLogin);
  }

  Future<void> openLive({
    required String channelLogin,
    bool play = true,
  }) async {
    final uri = await loadLivePlaylist(channelLogin: channelLogin);
    if (uri == null) {
      throw StateError('播放清單載入失敗，沒有 playlist uri。');
    }

    await services.playerSession.openOrResume(
      uri: uri.toString(),
      play: play,
    );
  }

  Future<Uri?> startProxyForVariant(TwitchM3u8Variant variant) {
    return services.playerRuntime.startProxyForVariant(variant);
  }

  Future<void> switchQuality(
    TwitchM3u8Variant variant, {
    bool play = true,
  }) async {
    final uri = await startProxyForVariant(variant);
    if (uri == null) {
      throw StateError('切換畫質失敗：runtime 沒有回傳 playlist uri。');
    }

    await services.playerSession.openOrResume(
      uri: uri.toString(),
      play: play,
    );
  }

  Future<void> pause() {
    return services.playerSession.pauseCurrent();
  }

  Future<void> stop() {
    return services.playerSession.stopCurrent();
  }

  void releaseSession() {
    services.playerSession.release();
  }

  Future<void> disposeRuntime() {
    services.playerRuntime.dispose();
    return Future<void>.value();
  }
}

class TwitchWatchChatPort {
  final TwitchWatchChatServices services;

  const TwitchWatchChatPort({required this.services});

  Future<TwitchChatStartupSnapshot> fetchStartupSnapshot({
    required String channelLogin,
  }) {
    return services.chatStartupApi.fetchParsedStartupSnapshot(
      channelLogin: channelLogin,
    );
  }

  Future<TwitchRecentMessagesResult> fetchRecentMessages({
    required String channelLogin,
    int limit = 100,
    bool includeClearchat = false,
  }) {
    return services.recentMessagesApi.getRecentMessages(
      channelLogin: channelLogin,
      limit: limit,
      includeClearchat: includeClearchat,
    );
  }
}

class TwitchWatchEmotePort {
  final TwitchWatchEmoteServices services;

  const TwitchWatchEmotePort({required this.services});

  TwitchThirdPartyEmoteCacheService get thirdParty => services.thirdPartyEmotes;
  TwitchOfficialEmoteCacheService get official => services.officialEmotes;

  Future<void> loadForChannel({
    required String channelId,
    required String channelLogin,
    required String viewerId,
    bool forceRefresh = false,
  }) async {
    await Future.wait<void>([
      services.thirdPartyEmotes.loadForChannel(
        channelId: channelId,
        channelLogin: channelLogin,
      ),
      services.officialEmotes.loadForChannel(
        channelId: channelId,
        viewerId: viewerId,
        forceRefresh: forceRefresh,
      ),
    ]);
  }

  Future<void> refreshForChannel({
    required String channelId,
    required String channelLogin,
    required String viewerId,
  }) {
    return loadForChannel(
      channelId: channelId,
      channelLogin: channelLogin,
      viewerId: viewerId,
      forceRefresh: true,
    );
  }

  void clear() {
    services.thirdPartyEmotes.clear();
    services.officialEmotes.clear();
  }
}

class TwitchWatchEngagementSnapshot {
  final TwitchChannelPointsRuntimeSnapshot? channelPoints;
  final TwitchPredictionSnapshot? prediction;
  final List<dynamic> pinnedMessages;
  final Object? error;

  const TwitchWatchEngagementSnapshot({
    required this.channelPoints,
    required this.prediction,
    required this.pinnedMessages,
    required this.error,
  });

  String? get errorText => error?.toString();
}

class TwitchWatchRewardRedeemResult {
  final String title;

  const TwitchWatchRewardRedeemResult({required this.title});
}

class TwitchWatchPredictionBetResult {
  final String outcomeTitle;
  final int points;

  const TwitchWatchPredictionBetResult({
    required this.outcomeTitle,
    required this.points,
  });
}

class TwitchWatchEngagementPort {
  final TwitchWatchEngagementServices services;

  const TwitchWatchEngagementPort({required this.services});

  Future<TwitchWatchEngagementSnapshot> refresh({
    required String channelLogin,
    required String? channelId,
  }) async {
    final errors = <Object>[];
    TwitchChannelPointsRuntimeSnapshot? nextChannelPointsSnapshot;
    TwitchPredictionSnapshot? nextPrediction;
    List<dynamic>? nextPinnedMessages;

    await Future.wait<void>([
      (() async {
        try {
          nextChannelPointsSnapshot =
              await services.channelPointsRuntimeService.load(
            channelLogin: channelLogin,
          );
        } catch (error) {
          errors.add(error);
        }
      })(),
      (() async {
        try {
          nextPrediction = await services.publicPredictionApi.fetchPredictionContext(
            channelLogin: channelLogin,
          );
        } catch (error) {
          errors.add(error);
        }
      })(),
      (() async {
        if (channelId == null || channelId.isEmpty) {
          nextPinnedMessages = const <dynamic>[];
          return;
        }
        try {
          nextPinnedMessages = await services.pinnedChatApi.getPinnedChatMessages(
            channelId: channelId,
          );
        } catch (error) {
          errors.add(error);
        }
      })(),
    ]);

    return TwitchWatchEngagementSnapshot(
      channelPoints: nextChannelPointsSnapshot,
      prediction: nextPrediction,
      pinnedMessages: nextPinnedMessages ?? const <dynamic>[],
      error: errors.isEmpty ? null : errors.last,
    );
  }

  Future<List<TwitchChannelPointEmoteOption>> loadChannelPointEmotes({
    required String channelLogin,
    required String? channelId,
  }) {
    return services.channelPointsApi.getModifiableEmotes(
      channelLogin: channelLogin,
      channelId: channelId,
    );
  }

  Future<TwitchChannelPointRedeemResult> redeemReward({
    required String channelLogin,
    required String rewardId,
    String? prompt,
  }) {
    return services.channelPointsApi.redeemReward(
      channelLogin: channelLogin,
      rewardId: rewardId,
      prompt: prompt,
    );
  }

  Future<TwitchPredictionBetResult> placePredictionBet({
    required String eventId,
    required String outcomeId,
    required int points,
    required String outcomeTitle,
  }) async {
    await services.dropsPredictionApi.placePredictionBet(
      eventId: eventId,
      outcomeId: outcomeId,
      points: points,
    );
    return TwitchWatchPredictionBetResult(
      outcomeTitle: outcomeTitle,
      points: points,
    );
  }
}

class TwitchWatchRelationshipPort {
  final TwitchWatchRelationshipServices services;

  const TwitchWatchRelationshipPort({required this.services});

  Future<TwitchRelationshipSnapshot> fetchRelationship({
    required String channelLogin,
    required String? targetUserId,
    required String? viewerUserId,
  }) {
    return services.relationshipApi.fetchRelationship(
      channelLogin: channelLogin,
      targetUserId: targetUserId,
      viewerUserId: viewerUserId,
    );
  }

  Future<TwitchRelationshipSnapshot> followChannel({
    required String channelLogin,
    required String? targetUserId,
    required String? viewerUserId,
  }) {
    return services.relationshipApi.followChannel(
      channelLogin: channelLogin,
      targetUserId: targetUserId,
      viewerUserId: viewerUserId,
    );
  }

  Future<TwitchRelationshipSnapshot> unfollowChannel({
    required String channelLogin,
    required String? targetUserId,
    required String? viewerUserId,
  }) {
    return services.relationshipApi.unfollowChannel(
      channelLogin: channelLogin,
      targetUserId: targetUserId,
      viewerUserId: viewerUserId,
    );
  }

  Uri buildSubscribeUri(String channelLogin) {
    return services.subscribeApi.buildSubscribeUri(channelLogin);
  }
}
