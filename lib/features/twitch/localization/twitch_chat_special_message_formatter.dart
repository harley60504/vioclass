// PATCH VERSION: twitch_chat_special_message_formatter_stage250c_resub_months
//
// Localizes Twitch IRC USERNOTICE / special message system text from msg-id and
// msg-param-* tags. This keeps detailed special-message text out of model and UI layers.

import '../models/chat/twitch_chat_message.dart';

String? formatLocalizedTwitchSpecialSystemMessage({
  required TwitchChatMessage message,
  required String? msgId,
  required int? bitsAmount,
  required String? customRewardId,
  required String? fallbackSystemMessage,
}) {
  final normalizedMsgId = _clean(msgId).toLowerCase();
  final tags = message.tags;
  final actor = _displayName(message.displayName, message.userLogin);

  if (customRewardId != null && customRewardId.trim().isNotEmpty) {
    return '$actor 兌換了忠誠點數獎勵';
  }

  if (bitsAmount != null && bitsAmount > 0) {
    return '$actor 歡呼了 $bitsAmount Bits';
  }

  switch (normalizedMsgId) {
    case 'sub':
      return _formatSub(actor: actor, tags: tags, resub: false);
    case 'resub':
      return _formatSub(actor: actor, tags: tags, resub: true);
    case 'subgift':
    case 'anonsubgift':
      return _formatSubGift(
        actor: actor,
        tags: tags,
        anonymous: normalizedMsgId.startsWith('anon'),
      );
    case 'submysterygift':
    case 'anonsubmysterygift':
      return _formatSubMysteryGift(
        actor: actor,
        tags: tags,
        anonymous: normalizedMsgId.startsWith('anon'),
      );
    case 'giftpaidupgrade':
      return _formatGiftPaidUpgrade(actor: actor, tags: tags, anonymous: false);
    case 'anongiftpaidupgrade':
      return _formatGiftPaidUpgrade(actor: actor, tags: tags, anonymous: true);
    case 'raid':
      return _formatRaid(actor: actor, tags: tags);
    case 'ritual':
      return _formatRitual(actor: actor, tags: tags);
    case 'bitsbadgetier':
      return _formatBitsBadgeTier(actor: actor, tags: tags);
    case 'announcement':
      return null;
  }

  final localizedFallback = _formatKnownFallbackSystemMessage(
    fallbackSystemMessage,
    fallbackActor: actor,
  );
  if (localizedFallback != null && localizedFallback.isNotEmpty) {
    return localizedFallback;
  }

  return _decodeTwitchTagText(fallbackSystemMessage);
}

String _formatSub({
  required String actor,
  required Map<String, String> tags,
  required bool resub,
}) {
  final cumulativeMonths = _readInt(tags, 'msg-param-cumulative-months');
  final streakMonths = _readInt(tags, 'msg-param-streak-months');
  final shouldShareStreak = _readBool(tags, 'msg-param-should-share-streak');
  final plan = _formatSubPlan(_read(tags, 'msg-param-sub-plan'));
  final planName = _read(tags, 'msg-param-sub-plan-name');
  final tierText = planName.isNotEmpty ? '$planName（$plan）' : plan;

  final parts = <String>[];
  if (resub) {
    if (cumulativeMonths != null && cumulativeMonths > 0) {
      parts.add('$actor 已訂閱 $cumulativeMonths 個月');
    } else {
      parts.add('$actor 重新訂閱了頻道');
    }
  } else {
    parts.add('$actor 訂閱了頻道');
  }

  if (tierText.isNotEmpty) parts.add('方案：$tierText');

  if (shouldShareStreak && streakMonths != null && streakMonths > 0) {
    parts.add('目前連續訂閱 $streakMonths 個月');
  }

  // Do not display msg-param-multimonth-duration / msg-param-multimonth-tenure.
  // They are useful raw Twitch metadata for some multi-month pledge cases, but
  // showing them beside cumulative/streak months is confusing and can look
  // contradictory in shared-chat/resub cards. Twitch's official chat card also
  // keeps the visible summary focused on cumulative months, streak, and tier.
  return _joinSentence(parts);
}

String _formatSubGift({
  required String actor,
  required Map<String, String> tags,
  required bool anonymous,
}) {
  final giver = anonymous ? '匿名觀眾' : actor;
  final recipient = _firstNonEmpty(<String>[
    _read(tags, 'msg-param-recipient-display-name'),
    _read(tags, 'msg-param-recipient-user-name'),
    _read(tags, 'msg-param-recipient-login'),
  ]);
  final months = _readInt(tags, 'msg-param-gift-months');
  final senderCount = _readInt(tags, 'msg-param-sender-count');
  final plan = _formatSubPlan(_read(tags, 'msg-param-sub-plan'));

  final parts = <String>[];
  if (recipient.isNotEmpty) {
    parts.add('$giver 贈送訂閱給 $recipient');
  } else {
    parts.add('$giver 贈送了一份訂閱');
  }
  if (plan.isNotEmpty) parts.add('方案：$plan');
  if (months != null && months > 1) parts.add('贈送 $months 個月');
  if (!anonymous && senderCount != null && senderCount > 0) {
    parts.add('$giver 在本頻道累計贈送 $senderCount 份訂閱');
  }
  return _joinSentence(parts);
}

String _formatSubMysteryGift({
  required String actor,
  required Map<String, String> tags,
  required bool anonymous,
}) {
  final giver = anonymous ? '匿名觀眾' : actor;
  final count = _readInt(tags, 'msg-param-mass-gift-count') ??
      _readInt(tags, 'msg-param-gift-count');
  final senderCount = _readInt(tags, 'msg-param-sender-count');
  final plan = _formatSubPlan(_read(tags, 'msg-param-sub-plan'));

  final parts = <String>[];
  if (count != null && count > 0) {
    parts.add('$giver 一次贈送了 $count 份訂閱');
  } else {
    parts.add('$giver 贈送了大量訂閱');
  }
  if (plan.isNotEmpty) parts.add('方案：$plan');
  if (!anonymous && senderCount != null && senderCount > 0) {
    parts.add('$giver 在本頻道累計贈送 $senderCount 份訂閱');
  }
  return _joinSentence(parts);
}

String _formatGiftPaidUpgrade({
  required String actor,
  required Map<String, String> tags,
  required bool anonymous,
}) {
  final sender = anonymous
      ? '匿名觀眾'
      : _firstNonEmpty(<String>[
          _read(tags, 'msg-param-sender-name'),
          _read(tags, 'msg-param-sender-login'),
        ]);
  if (sender.isEmpty) return '$actor 將贈送訂閱升級為付費訂閱';
  return '$actor 將 $sender 贈送的訂閱升級為付費訂閱';
}

String _formatRaid({
  required String actor,
  required Map<String, String> tags,
}) {
  final raider = _firstNonEmpty(<String>[
    _read(tags, 'msg-param-displayName'),
    _read(tags, 'msg-param-login'),
    actor,
  ]);
  final viewerCount = _readInt(tags, 'msg-param-viewerCount') ??
      _readInt(tags, 'msg-param-viewer-count');
  if (viewerCount != null && viewerCount > 0) {
    return '$raider 帶著 $viewerCount 位觀眾襲來';
  }
  return '$raider 正在揪團襲來';
}

String _formatRitual({
  required String actor,
  required Map<String, String> tags,
}) {
  final ritualName = _read(tags, 'msg-param-ritual-name').toLowerCase();
  switch (ritualName) {
    case 'new_chatter':
      return '$actor 第一次在聊天室發言';
    default:
      return '$actor 觸發了特殊互動';
  }
}

String _formatBitsBadgeTier({
  required String actor,
  required Map<String, String> tags,
}) {
  final threshold = _readInt(tags, 'msg-param-threshold');
  if (threshold != null && threshold > 0) {
    return '$actor 獲得了 $threshold Bits 徽章';
  }
  return '$actor 獲得了新的 Bits 徽章';
}

String? _formatKnownFallbackSystemMessage(
  String? fallbackSystemMessage, {
  required String fallbackActor,
}) {
  final text = _decodeTwitchTagText(fallbackSystemMessage)?.trim();
  if (text == null || text.isEmpty) return null;

  final watchStreak = RegExp(
    r'^(.+?) watched ([0-9,]+) consecutive streams and sparked a watch streak!?$',
    caseSensitive: false,
  ).firstMatch(text);
  if (watchStreak != null) {
    final actor = _cleanFallbackActor(watchStreak.group(1), fallbackActor);
    final count = watchStreak.group(2)?.replaceAll(',', '') ?? '';
    if (count.isNotEmpty) {
      return '$actor 已連續觀看 $count 場直播，點燃了觀看連勝';
    }
    return '$actor 點燃了觀看連勝';
  }

  final watchStreakGeneric = RegExp(
    r'^(.+?) watched ([0-9,]+) consecutive streams.*watch streak!?$',
    caseSensitive: false,
  ).firstMatch(text);
  if (watchStreakGeneric != null) {
    final actor = _cleanFallbackActor(watchStreakGeneric.group(1), fallbackActor);
    final count = watchStreakGeneric.group(2)?.replaceAll(',', '') ?? '';
    if (count.isNotEmpty) {
      return '$actor 已連續觀看 $count 場直播，達成觀看連勝';
    }
  }

  return null;
}

String _cleanFallbackActor(String? value, String fallbackActor) {
  final clean = _decodeTwitchTagText(value)?.trim() ?? '';
  if (clean.isNotEmpty) return clean;
  return fallbackActor.trim().isEmpty ? '某位觀眾' : fallbackActor;
}

String _formatSubPlan(String value) {
  switch (value.trim()) {
    case 'Prime':
      return 'Prime';
    case '1000':
      return 'Tier 1';
    case '2000':
      return 'Tier 2';
    case '3000':
      return 'Tier 3';
    default:
      return _decodeTwitchTagText(value) ?? '';
  }
}

String _displayName(String displayName, String login) {
  final cleanDisplay = _decodeTwitchTagText(displayName)?.trim() ?? '';
  if (cleanDisplay.isNotEmpty) return cleanDisplay;
  final cleanLogin = _decodeTwitchTagText(login)?.trim() ?? '';
  return cleanLogin.isEmpty ? '某位觀眾' : cleanLogin;
}

String _read(Map<String, String> tags, String key) {
  return _decodeTwitchTagText(tags[key])?.trim() ?? '';
}

int? _readInt(Map<String, String> tags, String key) {
  final text = _read(tags, key).replaceAll(',', '').trim();
  if (text.isEmpty) return null;
  return int.tryParse(text);
}

bool _readBool(Map<String, String> tags, String key) {
  final text = _read(tags, key).toLowerCase();
  return text == '1' || text == 'true';
}

String _firstNonEmpty(List<String> values) {
  for (final value in values) {
    final clean = value.trim();
    if (clean.isNotEmpty) return clean;
  }
  return '';
}

String _joinSentence(List<String> parts) {
  return parts.where((part) => part.trim().isNotEmpty).join('，');
}

String _clean(String? value) {
  return _decodeTwitchTagText(value)?.trim() ?? '';
}

String? _decodeTwitchTagText(String? value) {
  if (value == null) return null;
  return value
      .replaceAll(r'\s', ' ')
      .replaceAll(r'\:', ';')
      .replaceAll(r'\r', '\r')
      .replaceAll(r'\n', '\n')
      .replaceAll(r'\\', r'\');
}
