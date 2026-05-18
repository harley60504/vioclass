// PATCH VERSION: twitch_watch_chat_message_area_stage219ad_batched_runtime_bridge
//
// Runtime message list area for Watch chat.
//
// Stage 219AD:
// - Adds a 200ms batched bridge between TwitchChatRuntime.notifyListeners() and
//   the widget tree. This keeps the runtime implementation untouched while
//   reducing hot-chat rebuild pressure in the Watch chat area.
// - Appearance changes still rebuild immediately.

import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../models/chat/twitch_chat_runtime_message.dart';
import '../../../../services/chat/twitch_chat_runtime.dart';
import '../../../../services/chat/twitch_third_party_emote_cache_service.dart';
import '../../chat/twitch_chat_empty_view.dart';
import '../../chat/twitch_chat_message_list.dart';

class TwitchWatchChatMessageArea extends StatefulWidget {
  final TwitchChatRuntime? runtime;
  final TwitchThirdPartyEmoteCacheService thirdPartyEmoteCache;
  final Listenable appearanceListenable;
  final double fontScale;
  final bool compact;
  final ValueChanged<TwitchChatRuntimeMessage> onOpenMessageContext;

  const TwitchWatchChatMessageArea({
    super.key,
    required this.runtime,
    required this.thirdPartyEmoteCache,
    required this.appearanceListenable,
    required this.fontScale,
    required this.compact,
    required this.onOpenMessageContext,
  });

  @override
  State<TwitchWatchChatMessageArea> createState() =>
      _TwitchWatchChatMessageAreaState();
}

class _TwitchWatchChatMessageAreaState extends State<TwitchWatchChatMessageArea> {
  static const Duration _runtimeRebuildInterval = Duration(milliseconds: 200);

  final ValueNotifier<int> _batchedRuntimeTick = ValueNotifier<int>(0);

  Timer? _runtimeBatchTimer;
  TwitchChatRuntime? _listeningRuntime;

  @override
  void initState() {
    super.initState();
    _attachRuntime(widget.runtime);
  }

  @override
  void didUpdateWidget(covariant TwitchWatchChatMessageArea oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.runtime != widget.runtime) {
      _attachRuntime(widget.runtime);
      _batchedRuntimeTick.value += 1;
    }
  }

  @override
  void dispose() {
    _runtimeBatchTimer?.cancel();
    _detachRuntime();
    _batchedRuntimeTick.dispose();
    super.dispose();
  }

  void _attachRuntime(TwitchChatRuntime? runtime) {
    _detachRuntime();
    _listeningRuntime = runtime;
    runtime?.addListener(_handleRuntimeChanged);
  }

  void _detachRuntime() {
    final runtime = _listeningRuntime;
    if (runtime != null) runtime.removeListener(_handleRuntimeChanged);
    _listeningRuntime = null;
    _runtimeBatchTimer?.cancel();
    _runtimeBatchTimer = null;
  }

  void _handleRuntimeChanged() {
    if (_runtimeBatchTimer?.isActive ?? false) return;
    _runtimeBatchTimer = Timer(_runtimeRebuildInterval, () {
      if (!mounted) return;
      _batchedRuntimeTick.value += 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentRuntime = widget.runtime;
    if (currentRuntime == null) return const TwitchChatEmptyView();

    return AnimatedBuilder(
      animation: Listenable.merge([
        _batchedRuntimeTick,
        widget.appearanceListenable,
      ]),
      builder: (context, _) {
        return TwitchChatMessageList(
          runtime: currentRuntime,
          thirdPartyEmoteCache: widget.thirdPartyEmoteCache,
          fontScale: widget.fontScale,
          compact: widget.compact,
          onOpenMessageContext: widget.onOpenMessageContext,
        );
      },
    );
  }
}
