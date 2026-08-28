// Builds the redeem payload for Channel Points rewards. The parent sheet owns
// the overlay state and passes an opener callback into this helper.

import 'dart:convert';

import 'package:flutter/material.dart';

import '../../dialogs/twitch_channel_points_text_input_dialog.dart';
import '../../widgets/channel_points/twitch_channel_points_emote_overlay.dart';
import '../../widgets/channel_points/twitch_channel_points_sheet_utils.dart';
import 'twitch_channel_points_sheet_models.dart';

typedef TwitchChannelPointEmoteOverlayOpener =
    Future<Object?> Function({
      required BuildContext context,
      required Map<String, dynamic> reward,
      required ChannelPointEmoteOverlayMode mode,
    });

Future<String?> buildTwitchChannelPointRedeemPayload({
  required BuildContext context,
  required Map<String, dynamic> reward,
  required TwitchChannelPointEmoteOverlayOpener openEmoteOverlay,
}) async {
  if (requiresChannelPointModifiedEmoteSelection(reward)) {
    final selection = await openEmoteOverlay(
      context: context,
      reward: reward,
      mode: ChannelPointEmoteOverlayMode.modify,
    );

    if (selection is! TwitchChannelPointsModifiedEmoteSelection) return null;
    return jsonEncode(selection.toJson());
  }

  if (requiresChannelPointOfficialEmoteSelection(reward)) {
    final emoteId = await openEmoteOverlay(
      context: context,
      reward: reward,
      mode: ChannelPointEmoteOverlayMode.choose,
    );

    final text = emoteId?.toString().trim();
    if (text == null || text.isEmpty) return null;
    return text;
  }

  if (requiresChannelPointMessageInput(reward)) {
    final text = await askChannelPointTextInput(
      context: context,
      title: channelPointRewardTitle(reward),
      label: '聊天室訊息',
      hintText: '輸入要送出的訊息',
      confirmLabel: '送出兌換',
      minLines: 2,
      maxLines: 4,
    );

    final trimmed = text?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  }

  if (readChannelPointBool(reward['isUserInputRequired'])) {
    final prompt = reward['prompt']?.toString().trim();
    final text = await askChannelPointTextInput(
      context: context,
      title: channelPointRewardTitle(reward),
      label: prompt == null || prompt.isEmpty ? '兌換內容' : prompt,
      hintText: '輸入兌換內容',
      confirmLabel: '送出兌換',
      minLines: 2,
      maxLines: 4,
    );

    final trimmed = text?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  }

  return '';
}
