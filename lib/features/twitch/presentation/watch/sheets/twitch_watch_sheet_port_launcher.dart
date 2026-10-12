import 'package:flutter/material.dart';

import '../../../api/engagement/twitch_channel_points_api_service.dart';
import '../../../models/engagement/twitch_prediction.dart';
import '../../../models/special_actions/twitch_pending_special_message.dart';
import '../../../services/engagement/twitch_channel_points_runtime_service.dart';
import '../../sheets/twitch_channel_points_sheet.dart';
import '../../sheets/channel_points/twitch_channel_points_sheet_models.dart';
import '../../sheets/twitch_emote_picker_sheet.dart';
import '../../sheets/twitch_prediction_bet_sheet.dart';
import '../../widgets/channel_points/twitch_channel_points_sheet_utils.dart';
import '../../widgets/chat/twitch_chat_input_emote_state.dart';
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
  final bool Function() canPlacePredictionBet;
  final Object? Function()? channelPointsIdentity;
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
    required this.canPlacePredictionBet,
    this.channelPointsIdentity,
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

        final official = emotes.official.lookupRenderableByName(clean);
        if (official != null) {
          insertMessageText(
            TwitchChatInputEmotePayload.encode(
              TwitchChatInputEmote(
                id: official.id,
                name: official.name,
                imageUrl: official.preferredImageUrl(),
                staticImageUrl: official.officialStaticImageUrl(),
                providerLabel: official.sourceLabel,
                isOfficial: true,
                isAnimated: official.supportsAnimation,
              ),
            ),
          );
          return;
        }

        final thirdParty = emotes.thirdParty.lookupLoose(clean);
        if (thirdParty != null) {
          insertMessageText(
            TwitchChatInputEmotePayload.encode(
              TwitchChatInputEmote(
                id: thirdParty.id,
                name: thirdParty.name,
                imageUrl: thirdParty.imageUrl,
                staticImageUrl: thirdParty.effectiveStaticImageUrl,
                providerLabel: thirdParty.providerLabel,
                isAnimated: thirdParty.isAnimated,
              ),
            ),
          );
          return;
        }

        insertMessageText('$clean ');
      },
    );
  }

  Future<void> openChannelPointsSheet(BuildContext context) async {
    final destinationLogin = channelLogin();
    final destinationId = channelId();
    final openingSnapshot = channelPointsSnapshot();
    final openingIdentity = channelPointsIdentity?.call();
    void requireCurrentDestination() {
      if (!context.mounted ||
          (channelPointsIdentity != null &&
              (openingIdentity == null ||
                  !identical(openingIdentity, channelPointsIdentity!()))) ||
          destinationLogin != channelLogin() ||
          destinationId != channelId() ||
          openingSnapshot?.channelId != channelPointsSnapshot()?.channelId) {
        throw StateError('Channel points destination changed');
      }
    }
    bool isCurrentDestination() {
      try {
        requireCurrentDestination();
        return true;
      } catch (_) {
        return false;
      }
    }
    await showTwitchChannelPointsSheet(
      context: context,
      snapshot: openingSnapshot,
      loading: loadingEngagement() || engagementBootstrapping(),
      onRefresh: () => refreshEngagement(showSnackOnError: false),
      onClaim: (claimId) async {
        try {
          requireCurrentDestination();
        } catch (_) {
          showMessage('領取點數失敗，請稍後再試。');
          return;
        }
        await claimCommunityPoints(claimId, isCurrent: isCurrentDestination);
      },
      onPrepareTextReward: (reward) async {
        requireCurrentDestination();
        await prepareChannelPointTextReward(reward);
      },
      onRedeemReward: (reward, textInput) async {
        requireCurrentDestination();
        return redeemChannelPointReward(reward, textInput);
      },
      onLoadChannelPointEmotes: enableChannelPointEmoteMenu
          ? (_) => loadChannelPointModifiableEmotes()
          : null,
    );
  }

  Future<List<TwitchChannelPointEmoteOption>>
  loadChannelPointModifiableEmotes() async {
    return engagement.loadChannelPointEmotes(
      channelLogin: channelLogin(),
      channelId: channelPointsSnapshot()?.channelId ?? channelId(),
    );
  }

  Future<void> prepareChannelPointTextReward(
    Map<String, dynamic> reward,
  ) async {
    final setPending = setPendingSpecialMessage;
    if (setPending == null) return;

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
  }

  Future<void> claimCommunityPoints(
    String claimId, {
    bool Function()? isCurrent,
  }) async {
    final resolvedChannelId = channelPointsSnapshot()?.channelId ?? channelId();
    if (resolvedChannelId == null || resolvedChannelId.isEmpty) return;

    try {
      final result = await engagement.claimCommunityPoints(
        channelId: resolvedChannelId,
        claimId: claimId,
      );
      if (isCurrent?.call() == false) return;
      if (!result.ok) throw StateError('Channel points claim rejected');
      await refreshEngagement(showSnackOnError: false);
    } catch (error) {
      if (isCurrent?.call() == false) return;
      showMessage('領取點數失敗，請稍後再試。');
      debugPrint('[ChannelPointsClaim] failed type=${error.runtimeType}');
    }
  }

  Future<TwitchChannelPointRedeemUiResult?> redeemChannelPointReward(
    Map<String, dynamic> reward,
    String textInput,
  ) async {
    final resolvedChannelId = channelPointsSnapshot()?.channelId ?? channelId();
    if (resolvedChannelId == null || resolvedChannelId.isEmpty) return null;

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
      return result.displayResult ??
          TwitchChannelPointRedeemUiResult(title: result.title);
    } catch (error) {
      showMessage('兌換失敗，請稍後再試。');
      debugPrint('[ChannelPointsRedeem] failed type=${error.runtimeType}');
      return null;
    }
  }

  bool _isRandomEmoteUnlockReward(Map<String, dynamic> reward) {
    final type = channelPointRewardTypeKey(reward);
    if (type == 'RANDOM_SUB_EMOTE_UNLOCK') return true;
    return channelPointRewardTitle(reward).trim().toLowerCase() ==
        'unlock a random sub emote';
  }

  Future<void> openPredictionBetSheet(BuildContext context) async {
    final prediction = predictionSnapshot();
    if (prediction == null || !prediction.hasPrediction) {
      showMessage('目前沒有賭盤。');
      return;
    }
    final destinationLogin = channelLogin();
    final destinationId = channelId();
    bool isCurrentDestination() =>
        context.mounted &&
        destinationLogin == channelLogin() &&
        destinationId == channelId() &&
        predictionSnapshot()?.id == prediction.id;

    await showTwitchPredictionBetSheet(
      context: context,
      prediction: prediction,
      onBet: (outcome, points) async {
        if (!isCurrentDestination()) {
          throw StateError('Prediction destination changed');
        }
        await placePredictionBet(outcome, points);
      },
      onRefreshPrediction: () async {
        if (!isCurrentDestination()) return null;
        return engagement.refreshPrediction(channelLogin: destinationLogin);
      },
    );
  }

  Future<void> placePredictionBet(
    TwitchPredictionOutcome outcome,
    int points,
  ) async {
    if (!canPlacePredictionBet()) {
      showMessage('請先完成登入再下注。');
      throw StateError('Prediction viewer is not ready');
    }
    final prediction = predictionSnapshot();
    if (prediction == null || !prediction.hasPrediction) {
      showMessage('目前沒有可下注的賭盤。');
      throw StateError('No active prediction');
    }
    final balanceSnapshot = channelPointsSnapshot();
    final context = balanceSnapshot?.context;
    final login = channelLogin().trim().toLowerCase();
    if (balanceSnapshot == null ||
        !balanceSnapshot.contextOk ||
        context == null ||
        context.channelLogin.trim().toLowerCase() != login ||
        context.channelId != channelId()) {
      showMessage('目前無法確認點數餘額，請重新整理後再試。');
      throw StateError('Prediction balance is unavailable');
    }
    if (points <= 0 || points > context.balance) {
      showMessage(points <= 0 ? '請輸入有效點數' : '點數餘額不足，未送出下注。');
      throw StateError('Prediction points exceed available balance');
    }

    try {
      final result = await engagement.placePredictionBet(
        prediction: prediction,
        outcome: outcome,
        points: points,
      );
      showMessage('已送出下注：${result.outcomeTitle} · ${result.points} 點');
    } catch (error) {
      showMessage('下注失敗，稍後再試。');
      rethrow;
    }
    try {
      await refreshEngagement(showSnackOnError: false);
    } catch (_) {
      // A refresh failure must not turn an acknowledged bet into a failed bet.
    }
  }
}
