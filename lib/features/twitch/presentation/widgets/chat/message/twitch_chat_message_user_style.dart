//
// User display helpers for runtime chat messages.

import 'package:flutter/material.dart';

import '../../../../models/chat/twitch_chat_runtime_message.dart';
import '../../../theme/twitch_ui_tokens.dart';

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
  return readableTwitchChatUserColor(
    parseTwitchChatUserColor(color) ?? fallbackTwitchChatUserColor(login),
  );
}

final _readableNameColors = <Color, Color>{};

/// Adjust only the rendered name; keep the source Twitch color unchanged.
Color readableTwitchChatUserColor(Color color) {
  final cached = _readableNameColors[color];
  if (cached != null) return cached;
  final backgroundLuminance = TwitchUiColors.surfaceRaised.computeLuminance();
  var adjusted = color;
  var hsl = HSLColor.fromColor(color);
  for (var step = 0; step < 20; step++) {
    final contrast =
        (adjusted.computeLuminance() + .05) / (backgroundLuminance + .05);
    if (contrast >= 4.5) break;
    hsl = hsl.withLightness(hsl.lightness + (1 - hsl.lightness) * .1);
    adjusted = hsl.toColor();
  }
  if (_readableNameColors.length >= 2000) {
    _readableNameColors.remove(_readableNameColors.keys.first);
  }
  _readableNameColors[color] = adjusted;
  return adjusted;
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
  if (clean.isEmpty) return TwitchUiColors.primarySoft;

  var hash = 0;
  for (final codeUnit in clean.codeUnits) {
    hash = (hash * 31 + codeUnit) & 0x7fffffff;
  }

  return palette[hash % palette.length];
}
