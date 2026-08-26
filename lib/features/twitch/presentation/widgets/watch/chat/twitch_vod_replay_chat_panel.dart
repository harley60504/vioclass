import 'package:flutter/material.dart';

import '../../../../services/chat/twitch_vod_chat_replay_runtime.dart';
import '../../../settings/twitch_chat_appearance_controller.dart';
import '../../../theme/twitch_ui_tokens.dart';
import '../../chat/twitch_runtime_message_tile.dart';

class TwitchVodReplayChatPanel extends StatefulWidget {
  final TwitchVodChatReplayRuntime runtime;
  final Widget liveChat;
  final TwitchVodReplayChatMode preferredMode;

  const TwitchVodReplayChatPanel({
    super.key,
    required this.runtime,
    required this.liveChat,
    this.preferredMode = TwitchVodReplayChatMode.replay,
  });

  @override
  State<TwitchVodReplayChatPanel> createState() =>
      _TwitchVodReplayChatPanelState();
}

class _TwitchVodReplayChatPanelState extends State<TwitchVodReplayChatPanel> {
  TwitchVodReplayChatMode _mode = TwitchVodReplayChatMode.replay;
  final TwitchChatAppearanceController _appearanceController =
      TwitchChatAppearanceController();

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
  void dispose() {
    _appearanceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _appearanceController,
      builder: (context, _) {
        final fontScale = _appearanceController.fontScale;

        return Column(
          children: [
            _VodReplayChatHeader(
              mode: _mode,
              runtime: widget.runtime,
              onToggleMode: () {
                final next = _mode == TwitchVodReplayChatMode.replay
                    ? TwitchVodReplayChatMode.live
                    : TwitchVodReplayChatMode.replay;
                setState(() => _mode = next);
                if (next == TwitchVodReplayChatMode.replay) {
                  widget.runtime.nudge();
                }
              },
            ),
            const Divider(height: 1, color: Color(0x223A3A44)),
            Expanded(
              child: _mode == TwitchVodReplayChatMode.replay
                  ? _VodReplayMessageList(
                      runtime: widget.runtime,
                      fontScale: fontScale,
                    )
                  : widget.liveChat,
            ),
          ],
        );
      },
    );
  }
}

enum TwitchVodReplayChatMode { replay, live }

class _VodReplayChatHeader extends StatelessWidget {
  final TwitchVodReplayChatMode mode;
  final TwitchVodChatReplayRuntime runtime;
  final VoidCallback onToggleMode;

  const _VodReplayChatHeader({
    required this.mode,
    required this.runtime,
    required this.onToggleMode,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      color: const Color(0xFF18181B),
      child: Row(
        children: [
          _ChatModeBadge(
            mode: mode,
            hasError: runtime.error != null,
            onTap: onToggleMode,
          ),
          const Spacer(),
        ],
      ),
    );
  }
}

class _ChatModeBadge extends StatelessWidget {
  final TwitchVodReplayChatMode mode;
  final bool hasError;
  final VoidCallback onTap;

  const _ChatModeBadge({
    required this.mode,
    required this.hasError,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final live = mode == TwitchVodReplayChatMode.live;
    final color = hasError
        ? Colors.redAccent
        : live
        ? TwitchUiColors.green
        : const Color(0xFFC084FC);
    final label = live ? 'LIVE' : 'VOD';

    return Tooltip(
      message: live ? '切換到 VOD 聊天回放' : '切換到 Live 聊天室',
      child: InkWell(
        borderRadius: BorderRadius.circular(TwitchUiRadius.pill),
        onTap: onTap,
        child: Container(
          height: 28,
          padding: const EdgeInsets.symmetric(horizontal: 9),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(TwitchUiRadius.pill),
            border: Border.all(color: color.withValues(alpha: 0.34)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.38),
                      blurRadius: 6,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 10.5,
                  fontWeight: TwitchUiFontWeight.heavy,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VodReplayMessageList extends StatefulWidget {
  final TwitchVodChatReplayRuntime runtime;
  final double fontScale;

  const _VodReplayMessageList({required this.runtime, required this.fontScale});

  @override
  State<_VodReplayMessageList> createState() => _VodReplayMessageListState();
}

class _VodReplayMessageListState extends State<_VodReplayMessageList> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.runtime,
      builder: (context, _) {
        final messages = widget.runtime.messages;
        final error = widget.runtime.error;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!_scrollController.hasClients) return;
          _scrollController.jumpTo(0);
        });

        if (messages.isEmpty) {
          final emptyFontSize = (13 * widget.fontScale)
              .clamp(10.5, 19.0)
              .toDouble();

          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                error == null
                    ? widget.runtime.fetching
                          ? '正在讀取 VOD 聊天...'
                          : '等待影片時間軸上的聊天...'
                    : 'VOD 聊天讀取失敗：$error',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white54,
                  fontWeight: FontWeight.w800,
                  height: 1.35,
                ).copyWith(fontSize: emptyFontSize),
              ),
            ),
          );
        }

        return ListView.builder(
          controller: _scrollController,
          reverse: true,
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: messages.length,
          itemBuilder: (context, index) {
            final chronologicalIndex = messages.length - 1 - index;
            final message = messages[chronologicalIndex];
            return TwitchRuntimeMessageTile(
              key: ValueKey<String>(message.id),
              message: message,
              showTimestamp: true,
              fontScale: widget.fontScale,
              compact: true,
            );
          },
        );
      },
    );
  }
}
