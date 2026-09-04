import 'package:flutter/material.dart';

import '../../../api/core/twitch_api_exception.dart';
import '../../../api/engagement/twitch_channel_points_api_service.dart';
import '../../../models/engagement/twitch_prediction.dart';
import '../../../models/special_actions/twitch_pending_special_message.dart';
import '../../../services/engagement/twitch_channel_points_runtime_service.dart';
import '../../sheets/twitch_channel_points_sheet.dart';
import '../../sheets/channel_points/twitch_channel_points_sheet_models.dart';
import '../../sheets/twitch_emote_picker_sheet.dart';
import '../../sheets/twitch_prediction_bet_sheet.dart';
import '../../widgets/channel_points/twitch_channel_points_sheet_utils.dart';
import '../twitch_watch_feature_ports.dart';

class TwitchWatchSheetPortLauncher {
  final TwitchWatchEmotePort emotes;
  final TwitchWatchEngagementPort engagement;
  final void Function(String message) showMessage;
  final void Function(String text) insertMessageText;
  final void Function(TwitchPendingSpecialMessage pending)?
  setPendingSpecialMessage;
  final Future<void> Function({bool showSnackOnError}) refreshEngagement;
  final Future<void> Function({bool forceRefresh}) refreshEmotes;
  final String Function() channelLogin;
  final String? Function() channelId;
  final TwitchChannelPointsRuntimeSnapshot? Function() channelPointsSnapshot;
  final TwitchPredictionSnapshot? Function() predictionSnapshot;
  final bool Function() loadingEmotes;
  final bool Function() emoteBootstrapping;
  final bool Function() loadingEngagement;
  final bool Function() engagementBootstrapping;
  final bool enableChannelPointEmoteMenu;

  const TwitchWatchSheetPortLauncher({
    required this.emotes,
    required this.engagement,
    required this.showMessage,
    required this.insertMessageText,
    this.setPendingSpecialMessage,
    required this.refreshEngagement,
    required this.refreshEmotes,
    required this.channelLogin,
    required this.channelId,
    required this.channelPointsSnapshot,
    required this.predictionSnapshot,
    required this.loadingEmotes,
    required this.emoteBootstrapping,
    required this.loadingEngagement,
    required this.engagementBootstrapping,
    this.enableChannelPointEmoteMenu = true,
  });

  Future<void> openEmotePicker(BuildContext context) async {
    await showTwitchEmotePickerSheet(
      context: context,
      cache: emotes.thirdParty,
      officialCache: emotes.official,
      loading:
          emotes.thirdParty.loading ||
          emotes.official.loading ||
          loadingEmotes() ||
          emoteBootstrapping(),
      onRefresh: () => refreshEmotes(forceRefresh: true),
      onEmoteSelected: (emoteText) {
        final clean = emoteText.trim();
        if (clean.isEmpty) return;
        insertMessageText('$clean ');
      },
    );
  }

  Future<void> openChannelPointsSheet(BuildContext context) async {
    await showTwitchChannelPointsSheet(
      context: context,
      snapshot: channelPointsSnapshot(),
      loading: loadingEngagement() || engagementBootstrapping(),
      onRefresh: () => refreshEngagement(showSnackOnError: true),
      onClaim: claimCommunityPoints,
      onPrepareTextReward: prepareChannelPointTextReward,
      onRedeemReward: redeemChannelPointReward,
      onLoadChannelPointEmotes: enableChannelPointEmoteMenu
          ? (_) => loadChannelPointModifiableEmotes()
          : null,
    );
  }

  Future<List<TwitchChannelPointEmoteOption>>
  loadChannelPointModifiableEmotes() async {
    try {
      return await engagement.loadChannelPointEmotes(
        channelLogin: channelLogin(),
        channelId: channelPointsSnapshot()?.channelId ?? channelId(),
      );
    } catch (error) {
      showMessage('忠誠點數貼圖暫時載入失敗，稍後再試。');
      return const <TwitchChannelPointEmoteOption>[];
    }
  }

  Future<void> prepareChannelPointTextReward(
    Map<String, dynamic> reward,
  ) async {
    final setPending = setPendingSpecialMessage;
    if (setPending == null) {
      showMessage('尚未接上聊天室輸入欄。');
      return;
    }

    final cost = readChannelPointInt(reward['cost']);
    final title = channelPointRewardTitle(reward);
    final type = channelPointRewardTypeKey(reward);

    setPending(
      TwitchPendingSpecialMessage(
        kind: type == 'SEND_HIGHLIGHTED_MESSAGE'
            ? TwitchPendingSpecialMessageKind.highlightedMessage
            : TwitchPendingSpecialMessageKind.channelPointRewardMessage,
        channelLogin: channelLogin(),
        channelId: channelPointsSnapshot()?.channelId ?? channelId(),
        title: title,
        subtitle: '在下方輸入欄輸入內容，按送出後兌換。',
        costLabel: cost > 0 ? '$cost 點' : null,
        payload: <String, dynamic>{'reward': reward},
      ),
    );

    showMessage('已準備：$title');
  }

  Future<void> claimCommunityPoints(String claimId) async {
    final resolvedChannelId = channelPointsSnapshot()?.channelId ?? channelId();
    if (resolvedChannelId == null || resolvedChannelId.isEmpty) {
      showMessage('找不到頻道資訊，暫時不能領取忠誠點數。');
      return;
    }

    try {
      final result = await engagement.claimCommunityPoints(
        channelId: resolvedChannelId,
        claimId: claimId,
      );
      showMessage('已送出領取忠誠點數：+${result.pointsEarned}');
      await refreshEngagement(showSnackOnError: false);
    } catch (error) {
      showMessage('忠誠點數領取失敗，稍後再試。');
    }
  }

  Future<TwitchChannelPointRedeemUiResult?> redeemChannelPointReward(
    Map<String, dynamic> reward,
    String textInput,
  ) async {
    final resolvedChannelId = channelPointsSnapshot()?.channelId ?? channelId();
    if (resolvedChannelId == null || resolvedChannelId.isEmpty) {
      showMessage('找不到頻道資訊，暫時不能兌換忠誠點數獎勵。');
      return null;
    }

    try {
      final result = _isRandomEmoteUnlockReward(reward)
          ? await engagement.unlockRandomSubscriberEmote(
              channelId: resolvedChannelId,
              reward: reward,
            )
          : await engagement.redeemReward(
              channelId: resolvedChannelId,
              reward: reward,
              textInput: textInput,
            );
      await refreshEngagement(showSnackOnError: false);
      return result.displayResult;
    } catch (error) {
      debugPrint('[ChannelPointsRedeem] failed: $error');
      final reason = _channelPointRedeemFailureReason(error);
      showMessage(reason == null ? '忠誠點數兌換失敗，稍後再試。' : '忠誠點數兌換失敗：$reason');
      return null;
    }
  }

  bool _isRandomEmoteUnlockReward(Map<String, dynamic> reward) {
    final type = channelPointRewardTypeKey(reward);
    if (type == 'RANDOM_SUB_EMOTE_UNLOCK') return true;
    return channelPointRewardTitle(reward).trim().toLowerCase() ==
        'unlock a random sub emote';
  }

  String? _channelPointRedeemFailureReason(Object error) {
    if (error is TwitchApiException) {
      final message = error.message.trim();
      if (message.isEmpty) return null;
      return message
          .replaceFirst('UnlockRandomSubscriberEmote failed: ', '')
          .replaceFirst('RedeemCommunityPointsCustomReward failed: ', '');
    }

    final text = error.toString().trim();
    if (text.isEmpty) return null;
    if (text.length > 80) return '${text.substring(0, 80)}...';
    return text;
  }

  Future<void> openPredictionBetSheet(BuildContext context) async {
    final prediction = predictionSnapshot();
    if (prediction == null || !prediction.hasPrediction) {
      showMessage('目前沒有賭盤。');
      return;
    }

    await showTwitchPredictionBetSheet(
      context: context,
      prediction: prediction,
      onBet: placePredictionBet,
      onRefreshPrediction: () =>
          engagement.refreshPrediction(channelLogin: channelLogin()),
    );
  }

  Future<void> placePredictionBet(
    TwitchPredictionOutcome outcome,
    int points,
  ) async {
    final prediction = predictionSnapshot();
    if (prediction == null || !prediction.hasPrediction) {
      showMessage('目前沒有可下注的賭盤。');
      return;
    }

    try {
      final result = await engagement.placePredictionBet(
        prediction: prediction,
        outcome: outcome,
        points: points,
      );
      showMessage('已送出下注：${result.outcomeTitle} · ${result.points} 點');
      await refreshEngagement(showSnackOnError: false);
    } catch (error) {
      showMessage('下注失敗，稍後再試。');
    }
  }
}
