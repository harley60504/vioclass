// PATCH VERSION: twitch_reply_thread_builder_stage164
//
// Reply-thread construction logic for Twitch chat message context sheet.
// This file intentionally contains no Flutter UI code.

import '../../../models/chat/twitch_chat_runtime_message.dart';

enum TwitchReplyThreadEntryKind {
  ancestor,
  selected,
  directReply,
}

class TwitchReplyThreadEntry {
  final TwitchChatRuntimeMessage message;
  final TwitchReplyThreadEntryKind kind;
  final int depth;

  const TwitchReplyThreadEntry({
    required this.message,
    required this.kind,
    required this.depth,
  });
}

class TwitchReplyThreadBuilder {
  const TwitchReplyThreadBuilder._();

  static const int _maxParentDepth = 6;
  static const int _maxDirectReplies = 8;
  static const int _maxTotalRows = 12;

  static List<TwitchReplyThreadEntry> build({
    required TwitchChatRuntimeMessage selectedMessage,
    required List<TwitchChatRuntimeMessage> messages,
  }) {
    final sourceMessages = _mergeSelectedMessage(
      selectedMessage: selectedMessage,
      messages: messages,
    );

    final messagesById = <String, TwitchChatRuntimeMessage>{};
    for (final message in sourceMessages) {
      final id = _messageId(message);
      if (id.isNotEmpty) messagesById[id] = message;
    }

    final parentChain = <TwitchChatRuntimeMessage>[];
    final seenParentKeys = <String>{_messageIdentityKey(selectedMessage)};
    var cursor = selectedMessage;

    for (var depth = 0; depth < _maxParentDepth; depth++) {
      final parent = _findParentMessage(
        message: cursor,
        messages: sourceMessages,
        messagesById: messagesById,
      );

      if (parent == null) break;

      final key = _messageIdentityKey(parent);
      if (!seenParentKeys.add(key)) break;

      parentChain.insert(0, parent);
      cursor = parent;
    }

    final selectedKey = _messageIdentityKey(selectedMessage);
    final parentKeys = parentChain.map(_messageIdentityKey).toSet();

    final directReplies = sourceMessages.where((candidate) {
      final candidateKey = _messageIdentityKey(candidate);
      if (candidateKey == selectedKey || parentKeys.contains(candidateKey)) {
        return false;
      }
      return _isDirectReplyTo(candidate: candidate, target: selectedMessage);
    }).toList(growable: false)
      ..sort((a, b) => a.receivedAt.compareTo(b.receivedAt));

    final entries = <TwitchReplyThreadEntry>[
      for (var i = 0; i < parentChain.length; i++)
        TwitchReplyThreadEntry(
          message: parentChain[i],
          kind: TwitchReplyThreadEntryKind.ancestor,
          depth: i,
        ),
      TwitchReplyThreadEntry(
        message: selectedMessage,
        kind: TwitchReplyThreadEntryKind.selected,
        depth: parentChain.length,
      ),
      for (final reply in directReplies.take(_maxDirectReplies))
        TwitchReplyThreadEntry(
          message: reply,
          kind: TwitchReplyThreadEntryKind.directReply,
          depth: parentChain.length + 1,
        ),
    ];

    if (entries.length <= _maxTotalRows) {
      return List<TwitchReplyThreadEntry>.unmodifiable(entries);
    }

    return List<TwitchReplyThreadEntry>.unmodifiable(entries.take(_maxTotalRows));
  }

  static List<TwitchChatRuntimeMessage> _mergeSelectedMessage({
    required TwitchChatRuntimeMessage selectedMessage,
    required List<TwitchChatRuntimeMessage> messages,
  }) {
    final output = <TwitchChatRuntimeMessage>[];
    final seenKeys = <String>{};

    void add(TwitchChatRuntimeMessage message) {
      final key = _messageIdentityKey(message);
      if (!seenKeys.add(key)) return;
      output.add(message);
    }

    for (final message in messages) {
      add(message);
    }
    add(selectedMessage);

    output.sort((a, b) => a.receivedAt.compareTo(b.receivedAt));
    return output;
  }

  static TwitchChatRuntimeMessage? _findParentMessage({
    required TwitchChatRuntimeMessage message,
    required List<TwitchChatRuntimeMessage> messages,
    required Map<String, TwitchChatRuntimeMessage> messagesById,
  }) {
    final parentId = _replyParentMessageId(message);
    if (parentId.isNotEmpty) {
      final byId = messagesById[parentId];
      if (byId != null) return byId;
    }

    final parentLogin = _normalizeLogin(_replyParentLogin(message));
    final parentBody = _normalizeBody(_replyParentBody(message));

    if (parentLogin.isEmpty && parentBody.isEmpty) return null;

    for (final candidate in messages.reversed) {
      if (_messageIdentityKey(candidate) == _messageIdentityKey(message)) {
        continue;
      }
      if (candidate.receivedAt.isAfter(message.receivedAt)) continue;

      final candidateLogin = _normalizeLogin(candidate.userLogin);
      final candidateDisplayName = _normalizeLogin(candidate.displayName);
      final candidateBody = _normalizeBody(_messagePlainText(candidate));

      final loginMatches = parentLogin.isEmpty ||
          parentLogin == candidateLogin ||
          parentLogin == candidateDisplayName;
      final bodyMatches = parentBody.isEmpty || parentBody == candidateBody;

      if (loginMatches && bodyMatches) {
        return candidate;
      }
    }

    return null;
  }

  static bool _isDirectReplyTo({
    required TwitchChatRuntimeMessage candidate,
    required TwitchChatRuntimeMessage target,
  }) {
    final candidateParentId = _replyParentMessageId(candidate);
    final targetId = _messageId(target);

    if (candidateParentId.isNotEmpty && targetId.isNotEmpty) {
      return candidateParentId == targetId;
    }

    final parentLogin = _normalizeLogin(_replyParentLogin(candidate));
    final parentBody = _normalizeBody(_replyParentBody(candidate));

    if (parentLogin.isEmpty && parentBody.isEmpty) return false;

    final targetLogin = _normalizeLogin(target.userLogin);
    final targetDisplayName = _normalizeLogin(target.displayName);
    final targetBody = _normalizeBody(_messagePlainText(target));

    final loginMatches = parentLogin.isEmpty ||
        parentLogin == targetLogin ||
        parentLogin == targetDisplayName;
    final bodyMatches = parentBody.isEmpty || parentBody == targetBody;
    final timeLooksValid = !candidate.receivedAt.isBefore(target.receivedAt);

    return loginMatches && bodyMatches && timeLooksValid;
  }

  static String _messageId(TwitchChatRuntimeMessage message) {
    return message.id.trim();
  }

  static String _messageIdentityKey(TwitchChatRuntimeMessage message) {
    final id = _messageId(message);
    if (id.isNotEmpty) return 'id:$id';
    return 'fallback:${message.userLogin}:${message.receivedAt.microsecondsSinceEpoch}:${message.message.hashCode}';
  }

  static String _replyParentMessageId(TwitchChatRuntimeMessage message) {
    final dynamic reply = message.metadata.replyInfo;
    if (reply == null) return '';

    return _firstNonEmpty([
      () => reply.parentMessageId,
      () => reply.parentMsgId,
      () => reply.parentId,
      () => reply.messageId,
      () => reply.id,
    ]);
  }

  static String _replyParentLogin(TwitchChatRuntimeMessage message) {
    final dynamic reply = message.metadata.replyInfo;
    if (reply == null) return '';

    return _firstNonEmpty([
      () => reply.parentUserLogin,
      () => reply.parentLogin,
      () => reply.parentUserName,
      () => reply.parentDisplayName,
      () => reply.displayName,
    ]);
  }

  static String _replyParentBody(TwitchChatRuntimeMessage message) {
    final dynamic reply = message.metadata.replyInfo;
    if (reply == null) return '';

    return _firstNonEmpty([
      () => reply.parentMsgBody,
      () => reply.parentMessageBody,
      () => reply.parentBody,
      () => reply.messageBody,
    ]);
  }

  static String _firstNonEmpty(List<Object? Function()> readers) {
    for (final reader in readers) {
      final value = _readDynamicString(reader);
      if (value.isNotEmpty) return value;
    }
    return '';
  }

  static String _readDynamicString(Object? Function() reader) {
    try {
      final value = reader();
      return value?.toString().trim() ?? '';
    } catch (_) {
      return '';
    }
  }

  static String _messagePlainText(TwitchChatRuntimeMessage message) {
    final text = message.message.trim();
    if (text.isNotEmpty) return text;
    return (message.metadata.systemMessage ?? '').trim();
  }

  static String _normalizeLogin(String value) {
    final text = value.trim().toLowerCase();
    if (text.startsWith('@')) return text.substring(1);
    return text;
  }

  static String _normalizeBody(String value) {
    return value.trim().replaceAll(RegExp(r'\s+'), ' ');
  }
}
