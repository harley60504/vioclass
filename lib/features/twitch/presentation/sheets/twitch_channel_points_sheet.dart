import 'package:flutter/material.dart';

import '../../api/engagement/twitch_channel_points_api_service.dart';
import '../../services/engagement/twitch_channel_points_runtime_service.dart';

import '../widgets/channel_points/twitch_channel_points_emote_overlay.dart';
import '../widgets/channel_points/twitch_channel_points_sheet_utils.dart';
import '../widgets/responsive/twitch_responsive_sheet.dart';
import 'channel_points/twitch_channel_points_emote_overlay_state.dart';
import 'channel_points/twitch_channel_points_redeem_payload_builder.dart';
import 'channel_points/twitch_channel_points_sheet_body.dart';
import 'channel_points/twitch_channel_points_sheet_models.dart';

Future<void> showTwitchChannelPointsSheet({
  required BuildContext context,
  required TwitchChannelPointsRuntimeSnapshot? snapshot,
  required bool loading,
  required Future<void> Function() onRefresh,
  required Future<void> Function(String claimId) onClaim,
  Future<void> Function(Map<String, dynamic> reward)? onRewardTap,
  Future<void> Function(Map<String, dynamic> reward)? onPrepareTextReward,
  Future<void> Function(Map<String, dynamic> reward, String textInput)?
  onRedeemReward,
  TwitchChannelPointEmoteLoader? onLoadChannelPointEmotes,
}) {
  return showTwitchResponsiveSheet<void>(
    context: context,
    size: TwitchUnifiedSheetSize.large,
    builder: (_) => TwitchChannelPointsSheet(
      snapshot: snapshot,
      loading: loading,
      onRefresh: onRefresh,
      onClaim: onClaim,
      onRewardTap: onRewardTap,
      onPrepareTextReward: onPrepareTextReward,
      onRedeemReward: onRedeemReward,
      onLoadChannelPointEmotes: onLoadChannelPointEmotes,
    ),
  );
}

class TwitchChannelPointsSheet extends StatefulWidget {
  final TwitchChannelPointsRuntimeSnapshot? snapshot;
  final bool loading;
  final Future<void> Function() onRefresh;
  final Future<void> Function(String claimId) onClaim;

  /// Legacy callback. Kept so older WatchPage wiring still compiles.
  /// Prefer [onRedeemReward] for actual redeem actions.
  final Future<void> Function(Map<String, dynamic> reward)? onRewardTap;

  /// Optional composer integration for rewards that are really chat messages,
  /// such as Highlight My Message and sub-only bypass message.
  ///
  /// Keeping the final text input in the normal chat composer makes the flow
  /// match Twitch: choose the special action first, type in the
  /// regular chat box, then press Send once.
  final Future<void> Function(Map<String, dynamic> reward)? onPrepareTextReward;

  /// Main redeem callback.
  ///
  /// The second argument is the action payload:
  /// - custom reward with text input: message text
  /// - Highlight / Sub-only: chat message text
  /// - Choose / Gigantify: emote id
  /// - Modify: JSON string with {emoteId, modifierId}; emoteId is the final
  ///   modified emote id, Twitch-style.
  final Future<void> Function(Map<String, dynamic> reward, String textInput)?
  onRedeemReward;

  /// Twitch-style source for Choose / Modify emote menus.
  /// This must return Channel Points-selectable emotes, not the general chat
  /// emote list and not all locked channel emotes.
  final TwitchChannelPointEmoteLoader? onLoadChannelPointEmotes;

  const TwitchChannelPointsSheet({
    super.key,
    required this.snapshot,
    required this.loading,
    required this.onRefresh,
    required this.onClaim,
    this.onRewardTap,
    this.onPrepareTextReward,
    this.onRedeemReward,
    this.onLoadChannelPointEmotes,
  });

  @override
  State<TwitchChannelPointsSheet> createState() =>
      _TwitchChannelPointsSheetState();
}

class _TwitchChannelPointsSheetState extends State<TwitchChannelPointsSheet> {
  TwitchChannelPointsEmoteOverlayState _emoteOverlay =
      const TwitchChannelPointsEmoteOverlayState.hidden();
  TwitchChannelPointEmoteCompleter? _emoteCompleter;

  @override
  Widget build(BuildContext context) {
    final current = widget.snapshot;
    final balance = current?.balance;
    final rewards = sortChannelPointRewards(
      current?.rewards ?? const <Map<String, dynamic>>[],
      balance: balance,
    );

    final availableCount = rewards
        .where(
          (reward) => isChannelPointRewardAvailable(reward, balance: balance),
        )
        .length;

    return SafeArea(
      child: Stack(
        children: [
          TwitchUnifiedSheetScaffold(
            title: current?.pointsName ?? '忠誠點數',
            subtitle: balance == null
                ? '讀取點數與可兌換項目 · $availableCount/${rewards.length} 可用'
                : '${formatChannelPointFullNumber(balance)} 點 · $availableCount/${rewards.length} 可用',
            icon: Icons.stars_rounded,
            iconImageUrl: current?.pointsIconUrl,
            loading: widget.loading,
            onRefresh: widget.onRefresh,
            child: TwitchChannelPointsSheetBody(
              snapshot: current,
              loading: widget.loading,
              onRefresh: widget.onRefresh,
              onClaim: widget.onClaim,
              onRewardTap: (reward) => _handleRewardTap(context, reward),
            ),
          ),
          if (_emoteOverlay.isVisible)
            Positioned.fill(
              child: ChannelPointEmoteMenuOverlay(
                mode: _emoteOverlay.mode!,
                rewardTitle: channelPointRewardTitle(
                  _emoteOverlay.reward ?? const <String, dynamic>{},
                ),
                emotes: _emoteOverlay.visibleEmotes(),
                selectedBaseEmote: _emoteOverlay.selectedBaseEmote,
                selectedModifier: _emoteOverlay.selectedModifier,
                loading: _emoteOverlay.loading,
                error: _emoteOverlay.error,
                query: _emoteOverlay.query,
                onQueryChanged: (value) {
                  setState(() {
                    _emoteOverlay = _emoteOverlay.withQuery(value);
                  });
                },
                onBack: _emoteOverlay.selectedBaseEmote == null
                    ? null
                    : () {
                        setState(() {
                          _emoteOverlay = _emoteOverlay.clearBaseEmote();
                        });
                      },
                onClose: _closeEmoteOverlay,
                onReload: _reloadEmoteOverlay,
                onChooseEmote: _completeChooseEmote,
                onChooseModifier: _previewModifyEmote,
                onConfirmModifier: _completeModifyEmote,
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _handleRewardTap(
    BuildContext context,
    Map<String, dynamic> reward,
  ) async {
    final prepareTextReward = widget.onPrepareTextReward;
    if (prepareTextReward != null && requiresChannelPointMessageInput(reward)) {
      await prepareTextReward(reward);
      if (context.mounted) Navigator.of(context).maybePop();
      return;
    }

    if (widget.onRedeemReward == null) {
      final legacyTap = widget.onRewardTap;
      if (legacyTap != null) {
        await legacyTap(reward);
        return;
      }

      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('目前無法兌換這個獎勵，請稍後再試。')));
      }
      return;
    }

    final payload = await buildTwitchChannelPointRedeemPayload(
      context: context,
      reward: reward,
      openEmoteOverlay: _openEmoteOverlay,
    );
    if (payload == null) return;

    await widget.onRedeemReward!(reward, payload);
  }

  Future<Object?> _openEmoteOverlay({
    required BuildContext context,
    required Map<String, dynamic> reward,
    required ChannelPointEmoteOverlayMode mode,
  }) async {
    final loader = widget.onLoadChannelPointEmotes;
    if (loader == null) {
      showChannelPointsSnack(context, 'Channel Points emote menu 目前先暫時關閉。');
      return null;
    }

    final completer = _emoteCompleter = TwitchChannelPointEmoteCompleter();

    setState(() {
      _emoteOverlay = _emoteOverlay.opened(mode: mode, reward: reward);
    });

    try {
      final loaded = await loader(reward);
      if (!mounted || completer.isCompleted) return completer.future;
      setState(() {
        _emoteOverlay = _emoteOverlay.loaded(loaded);
      });
    } catch (error) {
      if (!mounted || completer.isCompleted) return completer.future;
      setState(() {
        _emoteOverlay = _emoteOverlay.failed(error);
      });
    }

    return completer.future;
  }

  Future<void> _reloadEmoteOverlay() async {
    final reward = _emoteOverlay.reward;
    final loader = widget.onLoadChannelPointEmotes;
    if (reward == null || loader == null) return;

    setState(() {
      _emoteOverlay = _emoteOverlay.reloading();
    });

    try {
      final loaded = await loader(reward);
      if (!mounted) return;
      setState(() {
        _emoteOverlay = _emoteOverlay.loaded(loaded);
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _emoteOverlay = _emoteOverlay.failed(error);
      });
    }
  }

  void _closeEmoteOverlay() {
    final completer = _emoteCompleter;
    if (completer != null && !completer.isCompleted) {
      completer.complete(null);
    }

    setState(() {
      _emoteCompleter = null;
      _emoteOverlay = const TwitchChannelPointsEmoteOverlayState.hidden();
    });
  }

  void _completeChooseEmote(TwitchChannelPointEmoteOption emote) {
    final mode = _emoteOverlay.mode;

    if (mode == ChannelPointEmoteOverlayMode.modify) {
      setState(() {
        _emoteOverlay = _emoteOverlay.selectBaseEmote(emote);
      });
      return;
    }

    final completer = _emoteCompleter;
    if (completer != null && !completer.isCompleted) {
      completer.complete(emote.id.trim());
    }

    setState(() {
      _emoteCompleter = null;
      _emoteOverlay = const TwitchChannelPointsEmoteOverlayState.hidden();
    });
  }

  void _previewModifyEmote(TwitchChannelPointEmoteModification modifier) {
    setState(() {
      _emoteOverlay = _emoteOverlay.selectModifier(modifier);
    });
  }

  void _completeModifyEmote(TwitchChannelPointEmoteModification modifier) {
    final completer = _emoteCompleter;
    if (completer != null && !completer.isCompleted) {
      completer.complete(
        TwitchChannelPointsModifiedEmoteSelection(
          emoteId: modifier.id.trim(),
          modifierId: modifier.modifierId.trim(),
        ),
      );
    }

    setState(() {
      _emoteCompleter = null;
      _emoteOverlay = const TwitchChannelPointsEmoteOverlayState.hidden();
    });
  }
}
