import 'package:flutter/material.dart';


List<Map<String, dynamic>> sortChannelPointRewards(
  List<Map<String, dynamic>> rewards, {
  required int? balance,
}) {
  final output = rewards.toList(growable: false);

  output.sort((a, b) {
    final aAvailable = isChannelPointRewardAvailable(a, balance: balance);
    final bAvailable = isChannelPointRewardAvailable(b, balance: balance);

    if (aAvailable != bAvailable) return aAvailable ? -1 : 1;

    final aCost = readChannelPointInt(a['cost']);
    final bCost = readChannelPointInt(b['cost']);
    if (aCost != bCost) return aCost.compareTo(bCost);

    final aTitle = a['title']?.toString().toLowerCase() ?? '';
    final bTitle = b['title']?.toString().toLowerCase() ?? '';
    return aTitle.compareTo(bTitle);
  });

  return output;
}

bool isChannelPointRewardAvailable(
  Map<String, dynamic> reward, {
  required int? balance,
}) {
  if (!readChannelPointBool(reward['isEnabled'], fallback: true)) return false;
  if (readChannelPointBool(reward['isPaused'])) return false;
  if (!readChannelPointBool(reward['isInStock'], fallback: true)) return false;
  if (_isCoolingDown(reward)) return false;
  if (balance != null && balance < readChannelPointInt(reward['cost'])) return false;

  return true;
}

String? channelPointRewardStatusText(
  Map<String, dynamic> reward, {
  required int? balance,
}) {
  if (!readChannelPointBool(reward['isEnabled'], fallback: true)) return 'Disabled';
  if (readChannelPointBool(reward['isPaused'])) return 'Paused';
  if (!readChannelPointBool(reward['isInStock'], fallback: true)) return 'Out of stock';

  final cooldown = _cooldownText(reward);
  if (cooldown != null) return cooldown;

  if (balance != null && balance < readChannelPointInt(reward['cost'])) return '點數不足';
  if (readChannelPointBool(reward['isUserInputRequired'])) return '需要輸入';
  if (requiresChannelPointMessageInput(reward)) return '需要訊息';
  if (requiresChannelPointModifiedEmoteSelection(reward)) return '需要貼圖與效果';
  if (requiresChannelPointOfficialEmoteSelection(reward)) return '需要貼圖';

  return null;
}

bool requiresChannelPointMessageInput(Map<String, dynamic> reward) {
  final type = channelPointRewardTypeKey(reward);
  final mode = reward['automaticInputMode']?.toString().trim().toLowerCase();
  final title = channelPointRewardTitle(reward).toLowerCase();

  return mode == 'message' ||
      type == 'SEND_HIGHLIGHTED_MESSAGE' ||
      type == 'SINGLE_MESSAGE_BYPASS_SUB_MODE' ||
      title.contains('highlight my message') ||
      title.contains('sub-only');
}

bool requiresChannelPointOfficialEmoteSelection(Map<String, dynamic> reward) {
  final type = channelPointRewardTypeKey(reward);
  final mode = reward['automaticInputMode']?.toString().trim().toLowerCase();
  final title = channelPointRewardTitle(reward).toLowerCase();

  return mode == 'emote' ||
      mode == 'gigantify_emote' ||
      type == 'CHOSEN_SUB_EMOTE_UNLOCK' ||
      type == 'SEND_GIGANTIFIED_EMOTE' ||
      title.contains('choose an emote') ||
      title.contains('gigantify');
}

bool requiresChannelPointModifiedEmoteSelection(Map<String, dynamic> reward) {
  final type = channelPointRewardTypeKey(reward);
  final mode = reward['automaticInputMode']?.toString().trim().toLowerCase();
  final title = channelPointRewardTitle(reward).toLowerCase();

  return mode == 'modified_emote' ||
      type == 'CHOSEN_MODIFIED_SUB_EMOTE_UNLOCK' ||
      title.contains('modify a single emote') ||
      title.contains('modified sub emote');
}

String channelPointRewardTypeKey(Map<String, dynamic> reward) {
  final raw = reward['normalizedRewardType'] ??
      reward['rewardType'] ??
      reward['type'] ??
      reward['automaticRewardType'] ??
      reward['id'];

  return raw?.toString().trim().toUpperCase() ?? '';
}

String channelPointRewardTitle(Map<String, dynamic> reward) {
  return reward['title']?.toString().trim().isNotEmpty == true
      ? reward['title'].toString().trim()
      : 'Reward';
}

String channelPointRewardTypeLabel(Map<String, dynamic> reward) {
  final source = reward['source']?.toString().trim().toLowerCase() ?? '';
  final type = channelPointRewardTypeKey(reward);

  if (source == 'custom') return '自訂';
  if (source == 'automatic') return '內建';

  if (type == 'SEND_HIGHLIGHTED_MESSAGE' ||
      type == 'SINGLE_MESSAGE_BYPASS_SUB_MODE' ||
      type == 'RANDOM_SUB_EMOTE_UNLOCK' ||
      type == 'CHOSEN_SUB_EMOTE_UNLOCK' ||
      type == 'CHOSEN_MODIFIED_SUB_EMOTE_UNLOCK' ||
      type == 'SEND_GIGANTIFIED_EMOTE') {
    return '內建';
  }

  return source;
}

String resolveChannelPointRewardDisplayImageUrl(Map<String, dynamic> reward) {
  final directKeys = const <String>[
    'resolvedImageUrl',
    'imageUrl',
    'image_url',
    'customImageUrl',
    'defaultImageUrl',
    'default_image_url',
  ];

  for (final key in directKeys) {
    final value = reward[key]?.toString().trim();
    if (_looksLikeImageUrl(value)) return value!;
  }

  final nestedPaths = const <List<String>>[
    <String>['image', 'url4x'],
    <String>['image', 'url_4x'],
    <String>['image', 'url2x'],
    <String>['image', 'url_2x'],
    <String>['image', 'url'],
    <String>['defaultImage', 'url4x'],
    <String>['defaultImage', 'url_4x'],
    <String>['defaultImage', 'url2x'],
    <String>['defaultImage', 'url_2x'],
    <String>['defaultImage', 'url'],
    <String>['default_image', 'url4x'],
    <String>['default_image', 'url_4x'],
    <String>['default_image', 'url2x'],
    <String>['default_image', 'url_2x'],
    <String>['default_image', 'url'],
  ];

  for (final path in nestedPaths) {
    final value = _readNestedString(reward, path);
    if (_looksLikeImageUrl(value)) return value!;
  }

  return '';
}

String? _readNestedString(Map<String, dynamic> map, List<String> path) {
  Object? current = map;

  for (final key in path) {
    if (current is! Map) return null;
    current = current[key];
  }

  final text = current?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}

bool _looksLikeImageUrl(String? value) {
  final text = value?.trim();
  if (text == null || text.isEmpty) return false;
  final lower = text.toLowerCase();
  return lower.startsWith('http') &&
      (lower.contains('jtvnw') ||
          lower.contains('static-cdn') ||
          lower.contains('twimg') ||
          lower.contains('.png') ||
          lower.contains('.jpg') ||
          lower.contains('.jpeg') ||
          lower.contains('.webp') ||
          lower.contains('.gif'));
}

bool _isCoolingDown(Map<String, dynamic> reward) {
  final raw = reward['cooldownExpiresAt']?.toString().trim();
  if (raw == null || raw.isEmpty) return false;

  final parsed = DateTime.tryParse(raw);
  if (parsed == null) return false;

  return parsed.toUtc().isAfter(DateTime.now().toUtc());
}

String? _cooldownText(Map<String, dynamic> reward) {
  final raw = reward['cooldownExpiresAt']?.toString().trim();
  if (raw == null || raw.isEmpty) return null;

  final parsed = DateTime.tryParse(raw);
  if (parsed == null) return null;

  final remaining = parsed.toUtc().difference(DateTime.now().toUtc());
  if (remaining.isNegative) return null;

  final seconds = remaining.inSeconds;
  if (seconds >= 3600) return '${(seconds / 3600).ceil()}h cooldown';
  if (seconds >= 60) return '${(seconds / 60).ceil()}m cooldown';
  return '${seconds.clamp(1, 59)}s cooldown';
}

int readChannelPointInt(Object? value) {
  if (value is int) return value;
  if (value is double) return value.round();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

bool readChannelPointBool(Object? value, {bool fallback = false}) {
  if (value is bool) return value;
  if (value == null) return fallback;

  final text = value.toString().toLowerCase();
  if (text == 'true') return true;
  if (text == 'false') return false;

  return fallback;
}

Color parseChannelPointColor(String? raw) {
  final clean = raw?.trim();
  if (clean == null || clean.isEmpty) return const Color(0xFF9146FF);

  final hex = clean.startsWith('#') ? clean.substring(1) : clean;
  final parsed = int.tryParse(hex, radix: 16);
  if (parsed == null) return const Color(0xFF9146FF);

  if (hex.length == 6) return Color(0xFF000000 | parsed);
  if (hex.length == 8) return Color(parsed);

  return const Color(0xFF9146FF);
}

String formatChannelPointCost(int cost) {
  return formatChannelPointFullNumber(cost);
}

String formatChannelPointFullNumber(int value) {
  final negative = value < 0;
  final raw = value.abs().toString();
  final buffer = StringBuffer();

  for (var i = 0; i < raw.length; i++) {
    final remaining = raw.length - i;
    buffer.write(raw[i]);
    if (remaining > 1 && remaining % 3 == 1) {
      buffer.write(',');
    }
  }

  final formatted = buffer.toString();
  return negative ? '-$formatted' : formatted;
}

String formatChannelPointCompactNumber(int value) {
  final negative = value < 0;
  final absValue = value.abs();

  String formatUnit(double scaled, String suffix) {
    final decimals = scaled >= 10 ? 0 : 1;
    final truncated = decimals == 0
        ? scaled.floorToDouble()
        : (scaled * 10).floor() / 10.0;
    final text = truncated
        .toStringAsFixed(decimals)
        .replaceFirst(RegExp(r'\.0$'), '');
    return '${negative ? '-' : ''}$text$suffix';
  }

  if (absValue >= 1000000000) {
    return formatUnit(absValue / 1000000000.0, 'b');
  }

  if (absValue >= 10000) {
    return formatUnit(absValue / 10000.0, 'w');
  }

  if (absValue >= 1000) {
    return formatUnit(absValue / 1000.0, 'k');
  }

  return value.toString();
}

void showChannelPointsSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message)),
  );
}
