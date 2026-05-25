// PATCH VERSION: twitch_chat_message_special_style_stage154
//
// Visual style mapping for Twitch special chat messages.

import 'package:flutter/material.dart';

import '../../../../models/chat/twitch_chat_message_metadata.dart';

class TwitchChatSpecialMessageStyle {
  final Color accentColor;
  final Color backgroundColor;
  final Color borderColor;
  final IconData icon;

  const TwitchChatSpecialMessageStyle({
    required this.accentColor,
    required this.backgroundColor,
    required this.borderColor,
    required this.icon,
  });

  static TwitchChatSpecialMessageStyle? fromMetadata(
    TwitchChatMessageMetadata metadata,
  ) {
    switch (metadata.specialKind) {
      case TwitchChatSpecialMessageKind.channelPointReward:
        return _style(
          accent: const Color(0xFFB778FF),
          icon: Icons.diamond_rounded,
        );
      case TwitchChatSpecialMessageKind.bits:
      case TwitchChatSpecialMessageKind.bitsBadgeTier:
        return _style(
          accent: const Color(0xFFFFC857),
          icon: Icons.auto_awesome_rounded,
        );
      case TwitchChatSpecialMessageKind.sub:
      case TwitchChatSpecialMessageKind.resub:
        return _style(
          accent: const Color(0xFFFF75B7),
          icon: Icons.star_rounded,
        );
      case TwitchChatSpecialMessageKind.subGift:
      case TwitchChatSpecialMessageKind.subMysteryGift:
      case TwitchChatSpecialMessageKind.giftPaidUpgrade:
        return _style(
          accent: const Color(0xFFFF9D5C),
          icon: Icons.card_giftcard_rounded,
        );
      case TwitchChatSpecialMessageKind.raid:
        return _style(
          accent: const Color(0xFFFF5C5C),
          icon: Icons.groups_rounded,
        );
      case TwitchChatSpecialMessageKind.announcement:
        return _style(
          accent: const Color(0xFF5CC8FF),
          icon: Icons.campaign_rounded,
        );
      case TwitchChatSpecialMessageKind.notice:
      case TwitchChatSpecialMessageKind.clearChat:
      case TwitchChatSpecialMessageKind.clearMsg:
      case TwitchChatSpecialMessageKind.system:
        return _style(
          accent: const Color(0xFFFFC857),
          icon: Icons.info_outline_rounded,
        );
      case TwitchChatSpecialMessageKind.ritual:
        return _style(
          accent: const Color(0xFF7EE787),
          icon: Icons.auto_awesome_rounded,
        );
      case TwitchChatSpecialMessageKind.normal:
      case TwitchChatSpecialMessageKind.action:
        return null;
    }
  }

  static TwitchChatSpecialMessageStyle _style({
    required Color accent,
    required IconData icon,
  }) {
    return TwitchChatSpecialMessageStyle(
      accentColor: accent,
      backgroundColor: Color.alphaBlend(
        accent.withValues(alpha: 0.14),
        const Color(0xFF191922),
      ),
      borderColor: accent.withValues(alpha: 0.46),
      icon: icon,
    );
  }
}
