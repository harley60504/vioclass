//
// User display helpers for runtime chat messages.

import 'package:flutter/material.dart';

import '../../../../models/chat/twitch_chat_runtime_message.dart';

String formatTwitchChatDisplayName(TwitchChatRuntimeMessage message) {
  final displayName = message.displayName.trim();
  final login = message.userLogin.trim();

  if (displayName.isEmpty) return login;
  if (login.isEmpty) return displayName;
  if (displayName.toLowerCase() == login.toLowerCase()) return displayName;

  return '$displayName ($login)';
}

Color parseTwitchChatUserColorOrFallback({
  required String color,
  required String login,
}) {
  return parseTwitchChatUserColor(color) ?? fallbackTwitchChatUserColor(login);
}

Color? parseTwitchChatUserColor(String value) {
  final text = value.trim();
  if (!text.startsWith('#') || text.length != 7) return null;

  final parsed = int.tryParse(text.substring(1), radix: 16);
  if (parsed == null) return null;

  return Color(0xFF000000 | parsed);
}

Color fallbackTwitchChatUserColor(String login) {
  const palette = <Color>[
    Color(0xFFFF0000),
    Color(0xFF0000FF),
    Color(0xFF008000),
    Color(0xFFB22222),
    Color(0xFFFF7F50),
    Color(0xFF9ACD32),
    Color(0xFFFF4500),
    Color(0xFF2E8B57),
    Color(0xFFDAA520),
    Color(0xFFD2691E),
    Color(0xFF5F9EA0),
    Color(0xFF1E90FF),
    Color(0xFFFF69B4),
    Color(0xFF8A2BE2),
    Color(0xFF00FF7F),
  ];

  final clean = login.trim().toLowerCase();
  if (clean.isEmpty) return const Color(0xFFBF94FF);

  var hash = 0;
  for (final codeUnit in clean.codeUnits) {
    hash = (hash * 31 + codeUnit) & 0x7fffffff;
  }

  return palette[hash % palette.length];
}
