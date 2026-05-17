import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import '../../api/engagement/twitch_channel_points_api_service.dart';
import '../../services/engagement/twitch_channel_points_runtime_service.dart';

import '../widgets/channel_points/twitch_channel_points_emote_overlay.dart';
import '../widgets/channel_points/twitch_channel_points_sheet_utils.dart';
import '../widgets/responsive/twitch_responsive_sheet.dart';
import '../dialogs/twitch_channel_points_text_input_dialog.dart';
import 'channel_points/twitch_channel_points_sheet_body.dart';
import 'channel_points/twitch_channel_points_sheet_models.dart';

Future<void> showTwitchChannelPointsSheet({
  required BuildContext context,
  required TwitchChannelPointsRuntimeSnapshot? snapshot,
  required bool loading,
  required Future<void> Function() onRefresh,
  required Future<void> Function(String claimId) onClaim,
  Future<void> Function(Map<String, dynamic> reward)? onRewardTap,
  Future<void> Function(Map<String, dynamic> reward, String textInput)? onRedeemReward,
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

  /// Main redeem callback.
  ///
  /// The second argument is the action payload:
  /// - custom reward with text input: message text
  /// - Highlight / Sub-only: chat message text
  /// - Choose / Gigantify: emote id
  /// - Modify: JSON string with {emoteId, modifierId}; emoteId is the final
  ///   modified emote id, StreamNook-style.
  final Future<void> Function(Map<String, dynamic> reward, String textInput)?
      onRedeemReward;

  /// StreamNook-style source for Choose / Modify emote menus.
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
    this.onRedeemReward,
    this.onLoadChannelPointEmotes,
  });

  @override
  State<TwitchChannelPointsSheet> createState() => _TwitchChannelPointsSheetState();
}

class _TwitchChannelPointsSheetState extends State<TwitchChannelPointsSheet> {
  ChannelPointEmoteOverlayMode? _emoteOverlayMode;
  Map<String, dynamic>? _emoteOverlayReward;
  List<TwitchChannelPointEmoteOption> _emoteOverlayEmotes = const <TwitchChannelPointEmoteOption>[];
  TwitchChannelPointEmoteOption? _selectedBaseEmote;
  bool _emoteOverlayLoading = false;
  String? _emoteOverlayError;
  String _emoteSearchQuery = '';

  bool get _isEmoteOverlayVisible => _emoteOverlayMode != null;

  @override
  Widget build(BuildContext context) {
    final current = widget.snapshot;
    final balance = current?.balance;
    final rewards = sortChannelPointRewards(
      current?.rewards ?? const <Map<String, dynamic>>[],
      balance: balance,
    );

    final availableCount = rewards
        .where((reward) => isChannelPointRewardAvailable(reward, balance: balance))
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
          if (_isEmoteOverlayVisible)
            Positioned.fill(
              child: ChannelPointEmoteMenuOverlay(
                mode: _emoteOverlayMode!,
                rewardTitle: channelPointRewardTitle(_emoteOverlayReward ?? const <String, dynamic>{}),
                emotes: _visibleOverlayEmotes(),
                selectedBaseEmote: _selectedBaseEmote,
                loading: _emoteOverlayLoading,
                error: _emoteOverlayError,
                query: _emoteSearchQuery,
                onQueryChanged: (value) {
                  setState(() {
                    _emoteSearchQuery = value.trim().toLowerCase();
                  });
                },
                onBack: _selectedBaseEmote == null
                    ? null
                    : () {
                        setState(() {
                          _selectedBaseEmote = null;
                          _emoteSearchQuery = '';
                        });
                      },
                onClose: _closeEmoteOverlay,
                onReload: _reloadEmoteOverlay,
                onChooseEmote: _completeChooseEmote,
                onChooseModifier: _completeModifyEmote,
              ),
            ),
        ],
      ),
    );
  }

  List<TwitchChannelPointEmoteOption> _visibleOverlayEmotes() {
    return filterChannelPointOverlayEmotes(
      mode: _emoteOverlayMode,
      emotes: _emoteOverlayEmotes,
      selectedBaseEmote: _selectedBaseEmote,
      query: _emoteSearchQuery,
    );
  }

  Future<void> _handleRewardTap(
    BuildContext context,
    Map<String, dynamic> reward,
  ) async {
    if (widget.onRedeemReward == null) {
      final legacyTap = widget.onRewardTap;
      if (legacyTap != null) {
        await legacyTap(reward);
        return;
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('尚未接上 reward redeem callback。')),
        );
      }
      return;
    }

    final payload = await _buildRedeemPayload(context, reward);
    if (payload == null) return;

    await widget.onRedeemReward!(reward, payload);
  }

  Future<String?> _buildRedeemPayload(
    BuildContext context,
    Map<String, dynamic> reward,
  ) async {
    if (requiresChannelPointModifiedEmoteSelection(reward)) {
      final selection = await _openEmoteOverlay(
        context: context,
        reward: reward,
        mode: ChannelPointEmoteOverlayMode.modify,
      );

      if (selection is! TwitchChannelPointsModifiedEmoteSelection) return null;
      return jsonEncode(selection.toJson());
    }

    if (requiresChannelPointOfficialEmoteSelection(reward)) {
      final emoteId = await _openEmoteOverlay(
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

  Future<Object?> _openEmoteOverlay({
    required BuildContext context,
    required Map<String, dynamic> reward,
    required ChannelPointEmoteOverlayMode mode,
  }) async {
    final loader = widget.onLoadChannelPointEmotes;
    if (loader == null) {
      showChannelPointsSnack(
        context,
        'Channel Points emote menu 目前先暫時關閉。',
      );
      return null;
    }

    final completer = _emoteCompleter = TwitchChannelPointEmoteCompleter();

    setState(() {
      _emoteOverlayMode = mode;
      _emoteOverlayReward = reward;
      _selectedBaseEmote = null;
      _emoteSearchQuery = '';
      _emoteOverlayEmotes = const <TwitchChannelPointEmoteOption>[];
      _emoteOverlayError = null;
      _emoteOverlayLoading = true;
    });

    try {
      final loaded = await loader(reward);
      if (!mounted || completer.isCompleted) return completer.future;
      setState(() {
        _emoteOverlayEmotes = loaded;
        _emoteOverlayLoading = false;
      });
    } catch (error) {
      if (!mounted || completer.isCompleted) return completer.future;
      setState(() {
        _emoteOverlayLoading = false;
        _emoteOverlayError = error.toString();
      });
    }

    return completer.future;
  }

  TwitchChannelPointEmoteCompleter? _emoteCompleter;

  Future<void> _reloadEmoteOverlay() async {
    final reward = _emoteOverlayReward;
    final loader = widget.onLoadChannelPointEmotes;
    if (reward == null || loader == null) return;

    setState(() {
      _emoteOverlayLoading = true;
      _emoteOverlayError = null;
      _emoteOverlayEmotes = const <TwitchChannelPointEmoteOption>[];
      _selectedBaseEmote = null;
    });

    try {
      final loaded = await loader(reward);
      if (!mounted) return;
      setState(() {
        _emoteOverlayEmotes = loaded;
        _emoteOverlayLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _emoteOverlayLoading = false;
        _emoteOverlayError = error.toString();
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
      _emoteOverlayMode = null;
      _emoteOverlayReward = null;
      _emoteOverlayEmotes = const <TwitchChannelPointEmoteOption>[];
      _selectedBaseEmote = null;
      _emoteSearchQuery = '';
      _emoteOverlayLoading = false;
      _emoteOverlayError = null;
    });
  }

  void _completeChooseEmote(TwitchChannelPointEmoteOption emote) {
    final mode = _emoteOverlayMode;

    if (mode == ChannelPointEmoteOverlayMode.modify) {
      setState(() {
        _selectedBaseEmote = emote;
        _emoteSearchQuery = '';
      });
      return;
    }

    final completer = _emoteCompleter;
    if (completer != null && !completer.isCompleted) {
      completer.complete(emote.id.trim());
    }

    setState(() {
      _emoteCompleter = null;
      _emoteOverlayMode = null;
      _emoteOverlayReward = null;
      _emoteOverlayEmotes = const <TwitchChannelPointEmoteOption>[];
      _selectedBaseEmote = null;
      _emoteSearchQuery = '';
      _emoteOverlayLoading = false;
      _emoteOverlayError = null;
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
      _emoteOverlayMode = null;
      _emoteOverlayReward = null;
      _emoteOverlayEmotes = const <TwitchChannelPointEmoteOption>[];
      _selectedBaseEmote = null;
      _emoteSearchQuery = '';
      _emoteOverlayLoading = false;
      _emoteOverlayError = null;
    });
  }
}
