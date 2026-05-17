// PATCH VERSION: twitch_watch_feature_ports_stage186c_real_ports
//
// Feature-facing ports for Watch composition.
//
// A port is intentionally thinner than a controller. It exposes the operations
// a UI feature needs so components can depend on their own interface instead of
// depending on TwitchWatchPage callbacks.

import '../../api/engagement/twitch_channel_points_api_service.dart';
import '../../models/engagement/twitch_prediction.dart';
import '../../models/playback/twitch_m3u8_variant.dart';
import '../../services/engagement/twitch_channel_points_runtime_service.dart';
import '../../services/watch/twitch_watch_feature_services.dart';
import '../../services/watch/twitch_watch_services.dart';

class TwitchWatchPlayerPort {
  final TwitchWatchPlayerServices services;

  const TwitchWatchPlayerPort({required this.services});

  Future<Uri?> loadLivePlaylist({required String channelLogin}) {
    return services.playerRuntime.loadLivePlaylist(channelLogin: channelLogin);
  }

  Future<Uri?> startProxyForVariant(TwitchM3u8Variant variant) {
    return services.playerRuntime.startProxyForVariant(variant);
  }

  Future<void> disposeRuntime() {
    services.playerRuntime.dispose();
    return Future<void>.value();
  }
}

class TwitchWatchChatPort {
  final TwitchWatchChatServices services;

  const TwitchWatchChatPort({required this.services});

  Future<dynamic> fetchStartupSnapshot({required String channelLogin}) {
    return services.chatStartupApi.fetchParsedStartupSnapshot(
      channelLogin: channelLogin,
    );
  }
}

class TwitchWatchEmotePort {
  final TwitchWatchEmoteServices services;

  const TwitchWatchEmotePort({required this.services});

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
    await services.channelPointsRuntimeService.redeemReward(
      channelId: channelId,
      reward: reward,
      textInput: textInput,
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

class TwitchWatchRelationshipPort {
  final TwitchWatchRelationshipServices services;

  const TwitchWatchRelationshipPort({required this.services});
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
      relationship: TwitchWatchRelationshipPort(services: services.relationship),
    );
  }
}
