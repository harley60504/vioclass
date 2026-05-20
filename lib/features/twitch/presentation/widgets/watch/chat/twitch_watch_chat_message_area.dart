// PATCH VERSION: twitch_watch_chat_message_area_stage243_official_emote_fallback
//
// Runtime message list area for Watch chat.
//
// Stage 243:
// - Pass official emote cache into the chat message renderer. This lets official
//   Twitch emotes such as corgiHHH / OverHip render as images even when a
//   message path lacks a complete IRC emotes tag and originally arrives as text.

import 'package:flutter/material.dart';

import '../../../../models/chat/twitch_chat_runtime_message.dart';
import '../../../../services/chat/twitch_chat_runtime.dart';
import '../../../../services/chat/twitch_official_emote_cache_service.dart';
import '../../../../services/chat/twitch_third_party_emote_cache_service.dart';
import '../../chat/twitch_chat_empty_view.dart';
import '../../chat/twitch_chat_message_list.dart';

class TwitchWatchChatMessageArea extends StatelessWidget {
  final TwitchChatRuntime? runtime;
  final TwitchThirdPartyEmoteCacheService thirdPartyEmoteCache;
  final TwitchOfficialEmoteCacheService officialEmoteCache;
  final Listenable appearanceListenable;
  final double fontScale;
  final bool compact;
  final ValueChanged<TwitchChatRuntimeMessage> onOpenMessageContext;

  const TwitchWatchChatMessageArea({
    super.key,
    required this.runtime,
    required this.thirdPartyEmoteCache,
    required this.officialEmoteCache,
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
        officialEmoteCache,
      ]),
      builder: (context, _) {
        return TwitchChatMessageList(
          runtime: currentRuntime,
          thirdPartyEmoteCache: thirdPartyEmoteCache,
          officialEmoteCache: officialEmoteCache,
          fontScale: fontScale,
          compact: compact,
          onOpenMessageContext: onOpenMessageContext,
        );
      },
    );
  }
}
