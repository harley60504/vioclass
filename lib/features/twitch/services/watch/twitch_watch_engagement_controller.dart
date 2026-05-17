// PATCH VERSION: twitch_watch_engagement_controller_stage186_fix_emote_option_type
//
// Engagement-only controller for Watch composition. This owns Channel Points,
// Prediction, and pinned-message API orchestration so WatchPage can become a
// composition layer instead of the only API gateway.

import '../../api/engagement/twitch_channel_points_api_service.dart';
import '../../models/engagement/twitch_prediction.dart';
import '../../services/engagement/twitch_channel_points_runtime_service.dart';
import 'twitch_watch_services.dart';

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

class TwitchWatchEngagementController {
  final TwitchWatchServices services;

  const TwitchWatchEngagementController({required this.services});

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
