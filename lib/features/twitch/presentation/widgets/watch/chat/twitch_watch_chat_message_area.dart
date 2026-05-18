// PATCH VERSION: twitch_watch_chat_message_area_stage219ae_runtime_batched_direct_listener
//
// Runtime message list area for Watch chat.
//
// Stage 219AE:
// - Runtime-level notify batching now lives inside TwitchChatRuntime.
// - This widget returns to a direct AnimatedBuilder listener so there is only
//   one batching layer and no extra 200ms UI bridge delay.

import 'package:flutter/material.dart';

import '../../../../models/chat/twitch_chat_runtime_message.dart';
import '../../../../services/chat/twitch_chat_runtime.dart';
import '../../../../services/chat/twitch_third_party_emote_cache_service.dart';
import '../../chat/twitch_chat_empty_view.dart';
import '../../chat/twitch_chat_message_list.dart';

class TwitchWatchChatMessageArea extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final currentRuntime = runtime;
    if (currentRuntime == null) return const TwitchChatEmptyView();

    return AnimatedBuilder(
      animation: Listenable.merge([
        currentRuntime,
        appearanceListenable,
      ]),
      builder: (context, _) {
        return TwitchChatMessageList(
          runtime: currentRuntime,
          thirdPartyEmoteCache: thirdPartyEmoteCache,
          fontScale: fontScale,
          compact: compact,
          onOpenMessageContext: onOpenMessageContext,
        );
      },
    );
  }
}