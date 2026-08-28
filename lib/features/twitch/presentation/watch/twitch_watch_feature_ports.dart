//
// Feature-facing ports for Watch composition.
//
// A port is intentionally thinner than a controller. It exposes the operations
// a UI feature needs so components can depend on their own interface instead of
// depending on TwitchWatchPage callbacks.

import 'dart:convert';

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
  List<TwitchM3u8Variant> get qualityVariants =>
      services.playerRuntime.variants;
  TwitchM3u8Variant? get currentVariant =>
      services.playerRuntime.currentVariant;
  bool get busy => services.playerRuntime.busy;
  Object? get error => services.playerRuntime.error;

  Future<Uri?> loadLivePlaylist({required String channelLogin}) {
    return services.playerRuntime.loadLivePlaylist(channelLogin: channelLogin);
  }

  Future<void> openLive({
    required String channelLogin,
    bool play = true,
    bool forceOpen = true,
  }) async {
    final uri = await loadLivePlaylist(channelLogin: channelLogin);
    if (uri == null) {
      final runtimeError = services.playerRuntime.error;
      throw StateError(runtimeError?.toString() ?? '播放清單載入失敗，沒有 playlist uri。');
    }

    await services.playerSession.openOrResume(
      uri: uri.toString(),
      play: play,
      forceOpen: forceOpen,
    );
  }

  Future<Uri?> startProxyForVariant(TwitchM3u8Variant variant) {
    return services.playerRuntime.startProxyForVariant(variant);
  }

  Future<void> switchQuality(
    TwitchM3u8Variant variant, {
    bool play = true,
  }) async {
    final wasPlaying = playerOrNull?.state.playing ?? play;
    final uri = await startProxyForVariant(variant);
    if (uri == null) {
      throw StateError('切換畫質失敗：runtime 沒有回傳 playlist uri。');
    }

    // Seamless mode: TwitchStableHlsProxyRouter keeps the same /stream.ts HTTP
    // response open and re-attaches it to the new inner upstream. Do not call
    // Player.open here, otherwise media_kit will blink/rebuffer like a full
    // reconnect.
    if (wasPlaying || play) {
      await player.play();
    }
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
    bool precacheThirdPartyStaticImages = false,
  }) async {
    await Future.wait<void>([
      services.thirdPartyEmotes.loadForChannel(
        channelId: channelId,
        channelLogin: channelLogin,
        precacheStaticImages: precacheThirdPartyStaticImages,
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
      precacheThirdPartyStaticImages: true,
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
          nextChannelPointsSnapshot = await services.channelPointsRuntimeService
              .load(channelLogin: channelLogin);
        } catch (error) {
          errors.add(error);
        }
      })(),
      (() async {
        try {
          nextPrediction = await services.publicPredictionApi
              .fetchPredictionContext(channelLogin: channelLogin);
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
          nextPinnedMessages = await services.pinnedChatApi
              .getPinnedChatMessages(channelId: channelId);
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
    return services.channelPointsRuntimeService.getModifiableEmotes(
      channelLogin: channelLogin,
      channelId: channelId,
    );
  }

  Future<TwitchChannelPointsClaimResult> claimCommunityPoints({
    required String channelId,
    required String claimId,
  }) {
    return services.channelPointsRuntimeService.claimBonus(
      channelId: channelId,
      claimId: claimId,
    );
  }

  Future<TwitchWatchRewardRedeemResult> redeemReward({
    required String channelId,
    required Map<String, dynamic> reward,
    required String textInput,
  }) async {
    final title = reward['title']?.toString() ?? 'Reward';
    final modifiedSelection = _tryReadModifiedEmoteSelection(textInput);
    if (modifiedSelection != null) {
      await services.channelPointsRuntimeService.unlockModifiedSubscriberEmote(
        channelId: channelId,
        reward: reward,
        modifiedEmoteId: modifiedSelection.emoteId,
        modifierId: modifiedSelection.modifierId,
      );
      return TwitchWatchRewardRedeemResult(title: title);
    }

    await services.channelPointsRuntimeService.redeemReward(
      channelId: channelId,
      reward: reward,
      textInput: textInput,
    );
    return TwitchWatchRewardRedeemResult(title: title);
  }

  _TwitchWatchModifiedEmoteSelection? _tryReadModifiedEmoteSelection(
    String raw,
  ) {
    final text = raw.trim();
    if (text.isEmpty || !text.startsWith('{')) return null;
    try {
      final decoded = jsonDecode(text);
      if (decoded is! Map) return null;
      final emoteId = decoded['emoteId']?.toString().trim() ?? '';
      final modifierId = decoded['modifierId']?.toString().trim() ?? '';
      if (emoteId.isEmpty) return null;
      return _TwitchWatchModifiedEmoteSelection(
        emoteId: emoteId,
        modifierId: modifierId,
      );
    } catch (_) {
      return null;
    }
  }

  Future<TwitchWatchRewardRedeemResult> sendHighlightedMessage({
    required String channelId,
    required Map<String, dynamic> reward,
    required String message,
  }) async {
    final title = reward['title']?.toString() ?? 'Highlighted Message';
    await services.channelPointsRuntimeService.sendHighlightedMessage(
      channelId: channelId,
      reward: reward,
      message: message,
    );
    return TwitchWatchRewardRedeemResult(title: title);
  }

  Future<TwitchWatchRewardRedeemResult> unlockRandomSubscriberEmote({
    required String channelId,
    required Map<String, dynamic> reward,
  }) async {
    final title = reward['title']?.toString() ?? 'Random Emote Unlock';
    await services.channelPointsRuntimeService.unlockRandomSubscriberEmote(
      channelId: channelId,
      reward: reward,
    );
    return TwitchWatchRewardRedeemResult(title: title);
  }

  Future<TwitchWatchRewardRedeemResult> unlockChosenSubscriberEmote({
    required String channelId,
    required Map<String, dynamic> reward,
    required String emoteId,
  }) async {
    final title = reward['title']?.toString() ?? 'Chosen Emote Unlock';
    await services.channelPointsRuntimeService.unlockChosenSubscriberEmote(
      channelId: channelId,
      reward: reward,
      emoteId: emoteId,
    );
    return TwitchWatchRewardRedeemResult(title: title);
  }

  Future<TwitchWatchRewardRedeemResult> unlockModifiedSubscriberEmote({
    required String channelId,
    required Map<String, dynamic> reward,
    required String modifiedEmoteId,
    String? modifierId,
  }) async {
    final title = reward['title']?.toString() ?? 'Modified Emote Unlock';
    await services.channelPointsRuntimeService.unlockModifiedSubscriberEmote(
      channelId: channelId,
      reward: reward,
      modifiedEmoteId: modifiedEmoteId,
      modifierId: modifierId,
    );
    return TwitchWatchRewardRedeemResult(title: title);
  }

  Future<TwitchPredictionSnapshot?> refreshPrediction({
    required String channelLogin,
  }) {
    return services.publicPredictionApi.fetchPredictionContext(
      channelLogin: channelLogin,
    );
  }

  Future<TwitchWatchPredictionBetResult> placePredictionBet({
    required TwitchPredictionSnapshot prediction,
    required TwitchPredictionOutcome outcome,
    required int points,
  }) async {
    await services.dropsPredictionApi.makePrediction(
      prediction: prediction,
      outcome: outcome,
      points: points,
    );
    return TwitchWatchPredictionBetResult(
      outcomeTitle: outcome.title,
      points: points,
    );
  }
}

class _TwitchWatchModifiedEmoteSelection {
  final String emoteId;
  final String modifierId;

  const _TwitchWatchModifiedEmoteSelection({
    required this.emoteId,
    required this.modifierId,
  });
}

class TwitchWatchRelationshipPort {
  final TwitchWatchRelationshipServices services;

  const TwitchWatchRelationshipPort({required this.services});

  Future<TwitchPrivateGqlRelationshipSnapshot> fetchRelationship({
    required String channelLogin,
    String? targetUserId,
    String? viewerUserId,
  }) {
    return services.relationshipApi.fetchRelationship(
      channelLogin: channelLogin,
      targetUserId: targetUserId,
      viewerUserId: viewerUserId,
    );
  }

  Future<TwitchPrivateGqlRelationshipSnapshot> followChannel({
    required String channelLogin,
    String? targetUserId,
    String? viewerUserId,
  }) {
    return services.relationshipApi.followChannel(
      channelLogin: channelLogin,
      targetUserId: targetUserId,
      viewerUserId: viewerUserId,
    );
  }

  Future<TwitchPrivateGqlRelationshipSnapshot> unfollowChannel({
    required String channelLogin,
    String? targetUserId,
    String? viewerUserId,
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

  Uri buildChannelUri(String channelLogin) {
    return services.subscribeApi.buildChannelUri(channelLogin);
  }
}

class TwitchWatchFeaturePorts {
  final TwitchWatchPlayerPort player;
  final TwitchWatchChatPort chat;
  final TwitchWatchEmotePort emotes;
  final TwitchWatchEngagementPort engagement;
  final TwitchWatchRelationshipPort relationship;

  const TwitchWatchFeaturePorts({
    required this.player,
    required this.chat,
    required this.emotes,
    required this.engagement,
    required this.relationship,
  });

  factory TwitchWatchFeaturePorts.fromServices(TwitchWatchServices services) {
    return TwitchWatchFeaturePorts(
      player: TwitchWatchPlayerPort(services: services.player),
      chat: TwitchWatchChatPort(services: services.chat),
      emotes: TwitchWatchEmotePort(services: services.emotes),
      engagement: TwitchWatchEngagementPort(services: services.engagement),
      relationship: TwitchWatchRelationshipPort(
        services: services.relationship,
      ),
    );
  }
}
