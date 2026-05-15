import '../../models/chat/twitch_chat_message_metadata.dart';
import '../../models/chat/twitch_chat_runtime_message.dart';

class TwitchChatEventLocalizer {
  const TwitchChatEventLocalizer._();

  static String specialLabel(TwitchChatMessageMetadata metadata) {
    switch (metadata.specialKind) {
      case TwitchChatSpecialMessageKind.normal:
        return '';
      case TwitchChatSpecialMessageKind.action:
        return '動作訊息';
      case TwitchChatSpecialMessageKind.channelPointReward:
        return '忠誠點數';
      case TwitchChatSpecialMessageKind.bits:
        return metadata.hasBits ? '${metadata.bitsAmount!} Bits' : 'Bits';
      case TwitchChatSpecialMessageKind.sub:
        return '訂閱';
      case TwitchChatSpecialMessageKind.resub:
        return '續訂';
      case TwitchChatSpecialMessageKind.subGift:
        return '贈送訂閱';
      case TwitchChatSpecialMessageKind.subMysteryGift:
        return '批量贈訂';
      case TwitchChatSpecialMessageKind.giftPaidUpgrade:
        return '贈訂升級';
      case TwitchChatSpecialMessageKind.raid:
        return '揪團';
      case TwitchChatSpecialMessageKind.ritual:
        return '儀式';
      case TwitchChatSpecialMessageKind.bitsBadgeTier:
        return 'Bits 徽章';
      case TwitchChatSpecialMessageKind.announcement:
        return '公告';
      case TwitchChatSpecialMessageKind.notice:
        return '系統通知';
      case TwitchChatSpecialMessageKind.clearChat:
        return '清除聊天';
      case TwitchChatSpecialMessageKind.clearMsg:
        return '刪除訊息';
      case TwitchChatSpecialMessageKind.system:
        return '系統';
    }
  }

  static String? systemMessage(TwitchChatRuntimeMessage message) {
    final metadata = message.metadata;
    final msgId = metadata.msgId?.trim().toLowerCase() ?? '';
    final tags = message.source.tags;
    final original = metadata.systemMessage?.trim();

    switch (metadata.specialKind) {
      case TwitchChatSpecialMessageKind.sub:
        return _subMessage(message, tags, resub: false) ?? original;
      case TwitchChatSpecialMessageKind.resub:
        return _subMessage(message, tags, resub: true) ?? original;
      case TwitchChatSpecialMessageKind.subGift:
        return _subGiftMessage(message, tags, anonymous: msgId.contains('anon')) ??
            original;
      case TwitchChatSpecialMessageKind.subMysteryGift:
        return _subMysteryGiftMessage(message, tags, anonymous: msgId.contains('anon')) ??
            original;
      case TwitchChatSpecialMessageKind.giftPaidUpgrade:
        return _giftPaidUpgradeMessage(message, tags, anonymous: msgId.contains('anon')) ??
            original;
      case TwitchChatSpecialMessageKind.raid:
        return _raidMessage(message, tags) ?? original;
      case TwitchChatSpecialMessageKind.ritual:
        return _ritualMessage(message, tags) ?? original;
      case TwitchChatSpecialMessageKind.bitsBadgeTier:
        return _bitsBadgeTierMessage(message, tags) ?? original;
      case TwitchChatSpecialMessageKind.announcement:
        return original ?? '實況主發布了一則公告。';
      case TwitchChatSpecialMessageKind.notice:
        return noticeMessage(message) ?? original;
      case TwitchChatSpecialMessageKind.clearChat:
        return _clearChatMessage(message, tags) ?? original;
      case TwitchChatSpecialMessageKind.clearMsg:
        return _clearMsgMessage(message, tags) ?? original;
      case TwitchChatSpecialMessageKind.channelPointReward:
        return _channelPointMessage(message, tags) ?? original;
      case TwitchChatSpecialMessageKind.bits:
        return _bitsMessage(message, tags) ?? original;
      case TwitchChatSpecialMessageKind.system:
        return original;
      case TwitchChatSpecialMessageKind.normal:
      case TwitchChatSpecialMessageKind.action:
        return original;
    }
  }

  static String? noticeMessage(TwitchChatRuntimeMessage message) {
    final msgId = message.metadata.msgId?.trim().toLowerCase() ?? '';
    final body = message.message.trim();
    final fallback = body.isNotEmpty ? body : message.metadata.systemMessage?.trim();

    switch (msgId) {
      case 'subs_on':
        return '已開啟訂閱者模式。';
      case 'subs_off':
        return '已關閉訂閱者模式。';
      case 'emote_only_on':
        return '已開啟純表情模式。';
      case 'emote_only_off':
        return '已關閉純表情模式。';
      case 'followers_on':
        return '已開啟追隨者模式。';
      case 'followers_off':
        return '已關閉追隨者模式。';
      case 'slow_on':
        return '已開啟慢速模式。';
      case 'slow_off':
        return '已關閉慢速模式。';
      case 'r9k_on':
        return '已開啟唯一訊息模式。';
      case 'r9k_off':
        return '已關閉唯一訊息模式。';
      case 'msg_duplicate':
        return '你的訊息與上一則太相似，未送出。';
      case 'msg_ratelimit':
      case 'msg_timedout':
        return '你發言太快了，請稍後再試。';
      case 'msg_banned':
        return '你已被此聊天室封鎖，無法發言。';
      case 'msg_channel_suspended':
        return '此頻道目前已被停權。';
      case 'no_permission':
        return '你沒有執行此操作的權限。';
      case 'host_on':
        return '已開始主持其他頻道。';
      case 'host_off':
        return '已停止主持。';
      default:
        return fallback == null || fallback.isEmpty ? null : _translateCommonNotice(fallback);
    }
  }

  static String _displayName(TwitchChatRuntimeMessage message) {
    final displayName = message.displayName.trim();
    if (displayName.isNotEmpty) return displayName;
    final login = message.userLogin.trim();
    return login.isNotEmpty ? login : '使用者';
  }

  static String _tag(Map<String, String> tags, String key) {
    return tags[key]?.trim() ?? '';
  }

  static int? _intTag(Map<String, String> tags, String key) {
    return int.tryParse(_tag(tags, key));
  }

  static String? _subMessage(
    TwitchChatRuntimeMessage message,
    Map<String, String> tags, {
    required bool resub,
  }) {
    final name = _displayName(message);
    final months = _intTag(tags, 'msg-param-cumulative-months') ??
        _intTag(tags, 'msg-param-months');
    final tier = _subscriptionTier(_tag(tags, 'msg-param-sub-plan'));
    if (resub) {
      if (months != null && months > 0) {
        return '$name 已續訂 $tier，累積 $months 個月。';
      }
      return '$name 已續訂 $tier。';
    }

    return '$name 訂閱了 $tier。';
  }

  static String? _subGiftMessage(
    TwitchChatRuntimeMessage message,
    Map<String, String> tags, {
    required bool anonymous,
  }) {
    final sender = anonymous ? '匿名使用者' : _displayName(message);
    final recipient = _tag(tags, 'msg-param-recipient-display-name').isNotEmpty
        ? _tag(tags, 'msg-param-recipient-display-name')
        : _tag(tags, 'msg-param-recipient-user-name');
    final tier = _subscriptionTier(_tag(tags, 'msg-param-sub-plan'));

    if (recipient.isEmpty) return '$sender 贈送了一份 $tier 訂閱。';
    return '$sender 贈送了一份 $tier 訂閱給 $recipient。';
  }

  static String? _subMysteryGiftMessage(
    TwitchChatRuntimeMessage message,
    Map<String, String> tags, {
    required bool anonymous,
  }) {
    final sender = anonymous ? '匿名使用者' : _displayName(message);
    final count = _intTag(tags, 'msg-param-mass-gift-count') ??
        _intTag(tags, 'msg-param-sender-count');
    final tier = _subscriptionTier(_tag(tags, 'msg-param-sub-plan'));

    if (count != null && count > 0) {
      return '$sender 贈送了 $count 份 $tier 訂閱給社群。';
    }
    return '$sender 贈送了 $tier 訂閱給社群。';
  }

  static String? _giftPaidUpgradeMessage(
    TwitchChatRuntimeMessage message,
    Map<String, String> tags, {
    required bool anonymous,
  }) {
    final name = _displayName(message);
    final sender = anonymous
        ? '匿名贈訂者'
        : (_tag(tags, 'msg-param-sender-name').isNotEmpty
            ? _tag(tags, 'msg-param-sender-name')
            : '贈訂者');
    return '$name 延續了來自 $sender 的贈訂。';
  }

  static String? _raidMessage(
    TwitchChatRuntimeMessage message,
    Map<String, String> tags,
  ) {
    final name = _displayName(message);
    final viewers = _intTag(tags, 'msg-param-viewerCount') ??
        _intTag(tags, 'msg-param-viewer-count');
    if (viewers != null && viewers > 0) {
      return '$name 帶著 $viewers 位觀眾揪團進來了。';
    }
    return '$name 揪團進來了。';
  }

  static String? _ritualMessage(
    TwitchChatRuntimeMessage message,
    Map<String, String> tags,
  ) {
    final name = _displayName(message);
    final ritual = _tag(tags, 'msg-param-ritual-name');
    if (ritual == 'new_chatter') return '$name 第一次在聊天室發言。';
    return '$name 觸發了聊天室儀式。';
  }

  static String? _bitsBadgeTierMessage(
    TwitchChatRuntimeMessage message,
    Map<String, String> tags,
  ) {
    final name = _displayName(message);
    final threshold = _tag(tags, 'msg-param-threshold');
    if (threshold.isEmpty) return '$name 獲得了新的 Bits 徽章。';
    return '$name 獲得了 $threshold Bits 徽章。';
  }

  static String? _bitsMessage(
    TwitchChatRuntimeMessage message,
    Map<String, String> tags,
  ) {
    final bits = message.metadata.bitsAmount;
    if (bits == null || bits <= 0) return null;
    return '${_displayName(message)} 使用了 $bits Bits。';
  }

  static String? _channelPointMessage(
    TwitchChatRuntimeMessage message,
    Map<String, String> tags,
  ) {
    final rewardTitle = _tag(tags, 'custom-reward-title');
    if (rewardTitle.isEmpty) return '${_displayName(message)} 兌換了忠誠點數獎勵。';
    return '${_displayName(message)} 兌換了「$rewardTitle」。';
  }

  static String? _clearChatMessage(
    TwitchChatRuntimeMessage message,
    Map<String, String> tags,
  ) {
    final target = message.message.trim();
    if (target.isNotEmpty) return '$target 已被暫時禁言或封鎖。';
    return '聊天室已被清除。';
  }

  static String? _clearMsgMessage(
    TwitchChatRuntimeMessage message,
    Map<String, String> tags,
  ) {
    final login = _tag(tags, 'login');
    if (login.isNotEmpty) return '$login 的一則訊息已被刪除。';
    return '一則訊息已被刪除。';
  }

  static String _subscriptionTier(String plan) {
    switch (plan.trim()) {
      case 'Prime':
        return 'Prime';
      case '1000':
        return 'Tier 1';
      case '2000':
        return 'Tier 2';
      case '3000':
        return 'Tier 3';
      default:
        return '訂閱';
    }
  }

  static String _translateCommonNotice(String text) {
    final lower = text.toLowerCase();
    if (lower.contains('subscribers-only')) return '目前聊天室為訂閱者模式。';
    if (lower.contains('emote-only')) return '目前聊天室為純表情模式。';
    if (lower.contains('followers-only')) return '目前聊天室為追隨者模式。';
    if (lower.contains('slow mode')) return '目前聊天室為慢速模式。';
    if (lower.contains('banned')) return '你已被此聊天室封鎖，無法發言。';
    if (lower.contains('duplicate')) return '你的訊息與上一則太相似，未送出。';
    return text;
  }
}
