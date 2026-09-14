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
  final bool showTimestamp;
  final bool compact;
  final ValueChanged<TwitchChatRuntimeMessage> onOpenMessageContext;

  const TwitchWatchChatMessageArea({
    super.key,
    required this.runtime,
    required this.thirdPartyEmoteCache,
    required this.officialEmoteCache,
    required this.appearanceListenable,
    required this.fontScale,
    required this.showTimestamp,
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
        thirdPartyEmoteCache,
        officialEmoteCache,
        appearanceListenable,
      ]),
      builder: (context, _) {
        return TwitchChatMessageList(
          runtime: currentRuntime,
          thirdPartyEmoteCache: thirdPartyEmoteCache,
          officialEmoteCache: officialEmoteCache,
          showTimestamp: showTimestamp,
          fontScale: fontScale,
          compact: compact,
          onOpenMessageContext: onOpenMessageContext,
        );
      },
    );
  }
}
