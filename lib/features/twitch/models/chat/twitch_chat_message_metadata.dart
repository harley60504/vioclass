import './twitch_chat_message.dart';
import './twitch_chat_reply_info.dart';

enum TwitchChatSpecialMessageKind {
  normal,
  action,
  channelPointReward,
  bits,
  sub,
  resub,
  subGift,
  subMysteryGift,
  giftPaidUpgrade,
  raid,
  ritual,
  bitsBadgeTier,
  announcement,
  notice,
  clearChat,
  clearMsg,
  system,
}

class TwitchChatMessageMetadata {
  final String command;
  final bool isAction;
  final bool isFirstMessage;
  final bool isReturningChatter;
  final bool isModerator;
  final bool isSubscriber;
  final bool isTurbo;
  final int? bitsAmount;
  final String? msgId;
  final String? systemMessage;
  final String? customRewardId;
  final TwitchChatReplyInfo? replyInfo;
  final String? sourceRoomId;
  final bool isFromSharedChat;
  final TwitchChatMessageSource source;
  final TwitchChatSpecialMessageKind specialKind;

  const TwitchChatMessageMetadata({
    required this.command,
    required this.isAction,
    required this.isFirstMessage,
    required this.isReturningChatter,
    required this.isModerator,
    required this.isSubscriber,
    required this.isTurbo,
    required this.bitsAmount,
    required this.msgId,
    required this.systemMessage,
    required this.customRewardId,
    required this.replyInfo,
    required this.sourceRoomId,
    required this.isFromSharedChat,
    required this.source,
    required this.specialKind,
  });

  factory TwitchChatMessageMetadata.fromMessage(TwitchChatMessage message) {
    final tags = message.tags;
    final reply = TwitchChatReplyInfo.fromTags(tags);
    final sourceRoomId = tags['source-room-id'] ??
        tags['shared-chat-room'] ??
        tags['source-broadcaster-id'];
    final bitsAmount = int.tryParse(tags['bits'] ?? '');
    final msgId = _emptyToNull(tags['msg-id']);
    final systemMessage = _emptyToNull(tags['system-msg']);
    final customRewardId = _emptyToNull(tags['custom-reward-id']);
    final isAction = _isActionMessage(message);

    return TwitchChatMessageMetadata(
      command: message.command,
      isAction: isAction,
      isFirstMessage: tags['first-msg'] == '1',
      isReturningChatter: tags['returning-chatter'] == '1',
      isModerator: tags['mod'] == '1',
      isSubscriber: tags['subscriber'] == '1',
      isTurbo: tags['turbo'] == '1',
      bitsAmount: bitsAmount,
      msgId: msgId,
      systemMessage: systemMessage,
      customRewardId: customRewardId,
      replyInfo: reply.hasValue ? reply : null,
      sourceRoomId: _emptyToNull(sourceRoomId),
      isFromSharedChat: sourceRoomId != null && sourceRoomId.isNotEmpty,
      source: message.source,
      specialKind: _resolveSpecialKind(
        message: message,
        isAction: isAction,
        bitsAmount: bitsAmount,
        msgId: msgId,
        customRewardId: customRewardId,
        systemMessage: systemMessage,
      ),
    );
  }

  bool get hasReply => replyInfo != null;
  bool get hasBits => bitsAmount != null && bitsAmount! > 0;
  bool get isRewardRedemption =>
      customRewardId != null && customRewardId!.isNotEmpty;
  bool get isSystemLike => systemMessage != null && systemMessage!.isNotEmpty;
  bool get isUserNotice => command == 'USERNOTICE';
  bool get isNotice => command == 'NOTICE';
  bool get isClearChat => command == 'CLEARCHAT';
  bool get isClearMsg => command == 'CLEARMSG';

  bool get isProminentSpecial {
    switch (specialKind) {
      case TwitchChatSpecialMessageKind.normal:
      case TwitchChatSpecialMessageKind.action:
        return false;
      case TwitchChatSpecialMessageKind.channelPointReward:
      case TwitchChatSpecialMessageKind.bits:
      case TwitchChatSpecialMessageKind.sub:
      case TwitchChatSpecialMessageKind.resub:
      case TwitchChatSpecialMessageKind.subGift:
      case TwitchChatSpecialMessageKind.subMysteryGift:
      case TwitchChatSpecialMessageKind.giftPaidUpgrade:
      case TwitchChatSpecialMessageKind.raid:
      case TwitchChatSpecialMessageKind.ritual:
      case TwitchChatSpecialMessageKind.bitsBadgeTier:
      case TwitchChatSpecialMessageKind.announcement:
      case TwitchChatSpecialMessageKind.notice:
      case TwitchChatSpecialMessageKind.clearChat:
      case TwitchChatSpecialMessageKind.clearMsg:
      case TwitchChatSpecialMessageKind.system:
        return true;
    }
  }

  String get specialLabel {
    switch (specialKind) {
      case TwitchChatSpecialMessageKind.normal:
        return '';
      case TwitchChatSpecialMessageKind.action:
        return '動作訊息';
      case TwitchChatSpecialMessageKind.channelPointReward:
        return '忠誠點數兌換';
      case TwitchChatSpecialMessageKind.bits:
        return hasBits ? '歡呼 ${bitsAmount!} Bits' : 'Bits 歡呼';
      case TwitchChatSpecialMessageKind.sub:
        return '訂閱';
      case TwitchChatSpecialMessageKind.resub:
        return '重新訂閱';
      case TwitchChatSpecialMessageKind.subGift:
        return '贈送訂閱';
      case TwitchChatSpecialMessageKind.subMysteryGift:
        return '大量贈訂';
      case TwitchChatSpecialMessageKind.giftPaidUpgrade:
        return '贈訂升級';
      case TwitchChatSpecialMessageKind.raid:
        return '揪團襲來';
      case TwitchChatSpecialMessageKind.ritual:
        return '特殊互動';
      case TwitchChatSpecialMessageKind.bitsBadgeTier:
        return 'Bits 徽章';
      case TwitchChatSpecialMessageKind.announcement:
        return '公告';
      case TwitchChatSpecialMessageKind.notice:
        return '系統提示';
      case TwitchChatSpecialMessageKind.clearChat:
        return '清除聊天室';
      case TwitchChatSpecialMessageKind.clearMsg:
        return '訊息已刪除';
      case TwitchChatSpecialMessageKind.system:
        return '系統訊息';
    }
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'command': command,
      'isAction': isAction,
      'isFirstMessage': isFirstMessage,
      'isReturningChatter': isReturningChatter,
      'isModerator': isModerator,
      'isSubscriber': isSubscriber,
      'isTurbo': isTurbo,
      'bitsAmount': bitsAmount,
      'msgId': msgId,
      'systemMessage': systemMessage,
      'customRewardId': customRewardId,
      'replyInfo': replyInfo?.toJson(),
      'sourceRoomId': sourceRoomId,
      'isFromSharedChat': isFromSharedChat,
      'source': source.name,
      'specialKind': specialKind.name,
      'specialLabel': specialLabel,
      'isProminentSpecial': isProminentSpecial,
      'hasReply': hasReply,
      'hasBits': hasBits,
      'isRewardRedemption': isRewardRedemption,
      'isSystemLike': isSystemLike,
    };
  }

  static TwitchChatSpecialMessageKind _resolveSpecialKind({
    required TwitchChatMessage message,
    required bool isAction,
    required int? bitsAmount,
    required String? msgId,
    required String? customRewardId,
    required String? systemMessage,
  }) {
    final command = message.command;
    final normalizedMsgId = msgId?.trim().toLowerCase() ?? '';

    if (command == 'CLEARMSG') return TwitchChatSpecialMessageKind.clearMsg;
    if (command == 'CLEARCHAT') return TwitchChatSpecialMessageKind.clearChat;

    if (command == 'NOTICE') return TwitchChatSpecialMessageKind.notice;

    if (command == 'USERNOTICE') {
      switch (normalizedMsgId) {
        case 'sub':
          return TwitchChatSpecialMessageKind.sub;
        case 'resub':
          return TwitchChatSpecialMessageKind.resub;
        case 'subgift':
          return TwitchChatSpecialMessageKind.subGift;
        case 'submysterygift':
          return TwitchChatSpecialMessageKind.subMysteryGift;
        case 'giftpaidupgrade':
        case 'anongiftpaidupgrade':
          return TwitchChatSpecialMessageKind.giftPaidUpgrade;
        case 'raid':
          return TwitchChatSpecialMessageKind.raid;
        case 'ritual':
          return TwitchChatSpecialMessageKind.ritual;
        case 'bitsbadgetier':
          return TwitchChatSpecialMessageKind.bitsBadgeTier;
        case 'announcement':
          return TwitchChatSpecialMessageKind.announcement;
      }

      if (normalizedMsgId.contains('subgift')) {
        return TwitchChatSpecialMessageKind.subGift;
      }
      if (normalizedMsgId.contains('sub')) {
        return TwitchChatSpecialMessageKind.sub;
      }
      if (normalizedMsgId.contains('raid')) {
        return TwitchChatSpecialMessageKind.raid;
      }
      if (systemMessage != null && systemMessage.trim().isNotEmpty) {
        return TwitchChatSpecialMessageKind.system;
      }
    }

    if (normalizedMsgId == 'announcement') {
      return TwitchChatSpecialMessageKind.announcement;
    }

    if (customRewardId != null && customRewardId.trim().isNotEmpty) {
      return TwitchChatSpecialMessageKind.channelPointReward;
    }

    if (bitsAmount != null && bitsAmount > 0) {
      return TwitchChatSpecialMessageKind.bits;
    }

    if (isAction) return TwitchChatSpecialMessageKind.action;

    if (systemMessage != null && systemMessage.trim().isNotEmpty) {
      return TwitchChatSpecialMessageKind.system;
    }

    return TwitchChatSpecialMessageKind.normal;
  }

  static bool _isActionMessage(TwitchChatMessage message) {
    if (message.tags['message-type'] == 'action') return true;
    return message.message.startsWith('\u0001ACTION') &&
        message.message.endsWith('\u0001');
  }

  static String? _emptyToNull(String? value) {
    if (value == null) return null;
    final clean = value.trim();
    return clean.isEmpty ? null : clean;
  }
}
