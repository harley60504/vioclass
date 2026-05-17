// PATCH VERSION: twitch_watch_engagement_loader_stage141
//
// Engagement-only WatchPage background loader.
// Owns prediction / channel points / pinned-chat refresh as one independently
// optimizable lane.

import '../../../../api/engagement/twitch_pinned_chat_api_service.dart';
import '../../../../api/engagement/twitch_prediction_api_service.dart';
import '../../../../models/engagement/twitch_prediction.dart';
import '../../../../services/engagement/twitch_channel_points_runtime_service.dart';

class TwitchWatchEngagementLoader {
  final TwitchChannelPointsRuntimeService channelPointsRuntimeService;
  final TwitchPredictionApiService predictionApi;
  final TwitchPinnedChatApiService pinnedChatApi;

  const TwitchWatchEngagementLoader({
    required this.channelPointsRuntimeService,
    required this.predictionApi,
    required this.pinnedChatApi,
  });

  Future<TwitchWatchEngagementLoadResult> load({
    required String channelLogin,
    required String? channelId,
  }) async {
    final errors = <Object>[];
    TwitchChannelPointsRuntimeSnapshot? channelPointsSnapshot;
    TwitchPredictionSnapshot? prediction;
    List<dynamic>? pinnedMessages;

    await Future.wait<void>([
      (() async {
        try {
          channelPointsSnapshot = await channelPointsRuntimeService.load(
            channelLogin: channelLogin,
          );
        } catch (error) {
          errors.add(error);
        }
      })(),
      (() async {
        try {
          prediction = await predictionApi.fetchPredictionContext(
            channelLogin: channelLogin,
          );
        } catch (error) {
          errors.add(error);
        }
      })(),
      (() async {
        final safeChannelId = channelId?.trim() ?? '';
        if (safeChannelId.isEmpty) {
          pinnedMessages = const <dynamic>[];
          return;
        }

        try {
          pinnedMessages = await pinnedChatApi.getPinnedChatMessages(
            channelId: safeChannelId,
          );
        } catch (error) {
          errors.add(error);
        }
      })(),
    ]);

    return TwitchWatchEngagementLoadResult(
      channelPointsSnapshot: channelPointsSnapshot,
      prediction: prediction,
      pinnedMessages: pinnedMessages,
      error: errors.isEmpty ? null : errors.last,
    );
  }
}

class TwitchWatchEngagementLoadResult {
  final TwitchChannelPointsRuntimeSnapshot? channelPointsSnapshot;
  final TwitchPredictionSnapshot? prediction;
  final List<dynamic>? pinnedMessages;
  final Object? error;

  const TwitchWatchEngagementLoadResult({
    required this.channelPointsSnapshot,
    required this.prediction,
    required this.pinnedMessages,
    required this.error,
  });
}
