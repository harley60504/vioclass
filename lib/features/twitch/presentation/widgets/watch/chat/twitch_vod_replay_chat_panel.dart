import 'package:flutter/material.dart';
import '../../../../models/chat/twitch_chat_runtime_message.dart';

import '../../../../services/chat/twitch_vod_chat_replay_runtime.dart';
import '../../../../services/chat/twitch_official_emote_cache_service.dart';
import '../../../../services/chat/twitch_third_party_emote_cache_service.dart';
import '../../../localization/vioclass_localizations.dart';
import '../../../settings/twitch_chat_appearance_controller.dart';
import '../../../sheets/twitch_chat_message_context_sheet.dart';
import 'twitch_watch_chat_header_bar.dart';
import 'twitch_watch_chat_layout_metrics.dart';
import '../../chat/twitch_chat_text_style.dart';
import '../../chat/twitch_chat_message_list.dart';

class TwitchVodReplayChatPanel extends StatefulWidget {
  final Future<void> Function(TwitchChatRuntimeMessage)? onOpenUser;
  final TwitchVodChatReplayRuntime runtime;
  final Widget liveChat;
  final Widget Function(VoidCallback onToggleMode)? liveChatBuilder;
  final TwitchThirdPartyEmoteCacheService? thirdPartyEmoteCache;
  final TwitchOfficialEmoteCacheService? officialEmoteCache;
  final TwitchVodReplayChatMode preferredMode;

  const TwitchVodReplayChatPanel({
    super.key,
    this.onOpenUser,
    required this.runtime,
    required this.liveChat,
    this.liveChatBuilder,
    this.thirdPartyEmoteCache,
    this.officialEmoteCache,
    this.preferredMode = TwitchVodReplayChatMode.replay,
  });

  @override
  State<TwitchVodReplayChatPanel> createState() =>
      _TwitchVodReplayChatPanelState();
}

class _TwitchVodReplayChatPanelState extends State<TwitchVodReplayChatPanel> {
  TwitchVodReplayChatMode _mode = TwitchVodReplayChatMode.replay;
  final TwitchChatAppearanceController _appearanceController =
      twitchChatAppearanceController;

  @override
  void initState() {
    super.initState();
    _mode = widget.preferredMode;
    _appearanceController.load();
  }

  @override
  void didUpdateWidget(covariant TwitchVodReplayChatPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.preferredMode != oldWidget.preferredMode &&
        widget.preferredMode != _mode) {
      _mode = widget.preferredMode;
      if (_mode == TwitchVodReplayChatMode.replay) {
        widget.runtime.nudge();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = TwitchWatchChatLayoutMetrics.resolve(
          constraints: constraints,
          media: MediaQuery.of(context),
        ).verticalCompact;
        return AnimatedBuilder(
          animation: _appearanceController,
          builder: (context, _) {
            final fontScale = _appearanceController.fontScale;
            if (_mode == TwitchVodReplayChatMode.live) {
              return widget.liveChatBuilder?.call(_toggleMode) ??
                  Column(
                    children: [
                      _VodReplayChatHeader(
                        mode: _mode,
                        runtime: widget.runtime,
                        onToggleMode: _toggleMode,
                        compact: compact,
                      ),
                      Expanded(child: widget.liveChat),
                    ],
                  );
            }

            return Column(
              children: [
                _VodReplayChatHeader(
                  mode: _mode,
                  runtime: widget.runtime,
                  onToggleMode: _toggleMode,
                  compact: compact,
                ),
                Expanded(
                  child: _mode == TwitchVodReplayChatMode.replay
                      ? _VodReplayMessageList(
                          onOpenUser: widget.onOpenUser,
                          runtime: widget.runtime,
                          thirdPartyEmoteCache: widget.thirdPartyEmoteCache,
                          officialEmoteCache: widget.officialEmoteCache,
                          fontScale: fontScale,
                          showTimestamp:
                              _appearanceController.messageTimestampsEnabled,
                        )
                      : widget.liveChat,
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _toggleMode() {
    setState(
      () => _mode = _mode == TwitchVodReplayChatMode.replay
          ? TwitchVodReplayChatMode.live
          : TwitchVodReplayChatMode.replay,
    );
    if (_mode == TwitchVodReplayChatMode.replay) {
      widget.runtime.nudge();
    }
  }
}

enum TwitchVodReplayChatMode { replay, live }

class _VodReplayChatHeader extends StatelessWidget {
  final TwitchVodReplayChatMode mode;
  final TwitchVodChatReplayRuntime runtime;
  final VoidCallback onToggleMode;
  final bool compact;

  const _VodReplayChatHeader({
    required this.mode,
    required this.runtime,
    required this.onToggleMode,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: runtime,
      builder: (context, _) => TwitchWatchChatHeaderBar(
        connected: mode == TwitchVodReplayChatMode.live,
        compact: compact,
        replayMode: mode == TwitchVodReplayChatMode.replay,
        replayHasError:
            mode == TwitchVodReplayChatMode.replay && runtime.error != null,
        showToggles: false,
        showPinned: false,
        showPrediction: false,
        predictionVisible: false,
        hasPinned: false,
        hasPrediction: false,
        onTogglePinned: () {},
        onTogglePrediction: () {},
        onToggleMode: onToggleMode,
      ),
    );
  }
}

class _VodReplayMessageList extends StatefulWidget {
  final Future<void> Function(TwitchChatRuntimeMessage)? onOpenUser;
  final TwitchVodChatReplayRuntime runtime;
  final TwitchThirdPartyEmoteCacheService? thirdPartyEmoteCache;
  final TwitchOfficialEmoteCacheService? officialEmoteCache;
  final double fontScale;
  final bool showTimestamp;

  const _VodReplayMessageList({
    this.onOpenUser,
    required this.runtime,
    required this.thirdPartyEmoteCache,
    required this.officialEmoteCache,
    required this.fontScale,
    required this.showTimestamp,
  });

  @override
  State<_VodReplayMessageList> createState() => _VodReplayMessageListState();
}

class _VodReplayMessageListState extends State<_VodReplayMessageList> {
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.runtime,
      builder: (context, _) {
        final messages = widget.runtime.messages;
        final error = widget.runtime.error;

        return TwitchChatTextScope(
          child: TwitchChatMessageFeed(
            messages: messages,
            onOpenUser: widget.onOpenUser,
            thirdPartyEmoteCache: widget.thirdPartyEmoteCache,
            officialEmoteCache: widget.officialEmoteCache,
            showTimestamp: widget.showTimestamp,
            fontScale: widget.fontScale,
            compact: true,
            onOpenMessageContext: (message) =>
                showTwitchChatMessageContextSheet(
                  context: context,
                  selectedMessage: message,
                  onOpenUser: widget.onOpenUser,
                  messages: messages,
                  thirdPartyEmotes: widget.thirdPartyEmoteCache,
                  officialEmotes: widget.officialEmoteCache,
                  fontScale: widget.fontScale,
                ),
            emptyBuilder: (_) => _VodReplayEmptyState(
              error: error,
              fetching: widget.runtime.fetching,
              fontScale: widget.fontScale,
            ),
          ),
        );
      },
    );
  }
}

class _VodReplayEmptyState extends StatelessWidget {
  final Object? error;
  final bool fetching;
  final double fontScale;

  const _VodReplayEmptyState({
    required this.error,
    required this.fetching,
    required this.fontScale,
  });

  @override
  Widget build(BuildContext context) {
    final emptyFontSize = (13 * fontScale).clamp(10.5, 19.0).toDouble();

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          context.vio.t(
            error == null
                ? fetching
                      ? '正在讀取 VOD 聊天...'
                      : '等待影片時間軸上的聊天...'
                : 'VOD 聊天暫時讀取失敗，稍後再試。',
          ),
          textAlign: TextAlign.center,
          style: twitchChatTextStyle(
            TextStyle(
              color: Colors.white54,
              fontSize: emptyFontSize,
              fontWeight: FontWeight.w800,
              height: 1.35,
            ),
          ),
        ),
      ),
    );
  }
}
