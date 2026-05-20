// PATCH VERSION: twitch_reply_thread_builder_stage266_full_conversation
//
// Reply-thread construction logic for Twitch chat message context sheet.
// This file intentionally contains no Flutter UI code.
//
// Twitch-like behavior:
// - Find the top/root message of the selected reply chain.
// - Show every visible message that belongs to that root conversation.
// - Example: A replies B, B replies C, D replies C. Opening A shows C/B/A/D.
// - @tag mentions are not treated as reply edges.

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

  static const int _maxParentDepth = 8;
  static const int _maxConversationDepth = 10;
  static const int _maxTotalRows = 32;

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

    final parentCache = <String, TwitchChatRuntimeMessage?>{};

    TwitchChatRuntimeMessage? parentOf(TwitchChatRuntimeMessage message) {
      final key = _messageIdentityKey(message);
      if (parentCache.containsKey(key)) return parentCache[key];

      final parent = _findParentMessage(
        message: message,
        messages: sourceMessages,
        messagesById: messagesById,
      );
      parentCache[key] = parent;
      return parent;
    }

    final parentChain = _buildParentChain(
      selectedMessage: selectedMessage,
      parentOf: parentOf,
    );

    final rootMessage = parentChain.isEmpty ? selectedMessage : parentChain.first;
    final rootKey = _messageIdentityKey(rootMessage);
    final selectedKey = _messageIdentityKey(selectedMessage);
    final ancestorKeys = parentChain.map(_messageIdentityKey).toSet();

    final entries = <TwitchReplyThreadEntry>[];
    final seenEntryKeys = <String>{};

    for (final message in sourceMessages) {
      final key = _messageIdentityKey(message);
      if (!seenEntryKeys.add(key)) continue;

      final belongsToRoot = _conversationRootKey(
            message: message,
            parentOf: parentOf,
          ) ==
          rootKey;
      if (!belongsToRoot) continue;

      final depth = _conversationDepthFromRoot(
        message: message,
        rootKey: rootKey,
        parentOf: parentOf,
      );

      final kind = key == selectedKey
          ? TwitchReplyThreadEntryKind.selected
          : ancestorKeys.contains(key)
              ? TwitchReplyThreadEntryKind.ancestor
              : TwitchReplyThreadEntryKind.directReply;

      entries.add(
        TwitchReplyThreadEntry(
          message: message,
          kind: kind,
          depth: depth,
        ),
      );
    }

    if (entries.isEmpty) {
      entries.add(
        TwitchReplyThreadEntry(
          message: selectedMessage,
          kind: TwitchReplyThreadEntryKind.selected,
          depth: parentChain.length,
        ),
      );
    }

    entries.sort((a, b) {
      final timeCompare = a.message.receivedAt.compareTo(b.message.receivedAt);
      if (timeCompare != 0) return timeCompare;
      final depthCompare = a.depth.compareTo(b.depth);
      if (depthCompare != 0) return depthCompare;
      return _messageIdentityKey(a.message).compareTo(_messageIdentityKey(b.message));
    });

    if (entries.length <= _maxTotalRows) {
      return List<TwitchReplyThreadEntry>.unmodifiable(entries);
    }

    return List<TwitchReplyThreadEntry>.unmodifiable(
      _trimEntriesAroundSelected(
        entries: entries,
        selectedKey: selectedKey,
      ),
    );
  }

  static List<TwitchReplyThreadEntry> _trimEntriesAroundSelected({
    required List<TwitchReplyThreadEntry> entries,
    required String selectedKey,
  }) {
    final required = <TwitchReplyThreadEntry>[];
    final optional = <TwitchReplyThreadEntry>[];

    for (final entry in entries) {
      final key = _messageIdentityKey(entry.message);
      if (entry.kind == TwitchReplyThreadEntryKind.ancestor || key == selectedKey) {
        required.add(entry);
      } else {
        optional.add(entry);
      }
    }

    final output = <TwitchReplyThreadEntry>[];
    final seen = <String>{};

    void add(TwitchReplyThreadEntry entry) {
      final key = _messageIdentityKey(entry.message);
      if (!seen.add(key)) return;
      output.add(entry);
    }

    for (final entry in required) {
      add(entry);
    }

    for (final entry in optional) {
      if (output.length >= _maxTotalRows) break;
      add(entry);
    }

    output.sort((a, b) {
      final timeCompare = a.message.receivedAt.compareTo(b.message.receivedAt);
      if (timeCompare != 0) return timeCompare;
      final depthCompare = a.depth.compareTo(b.depth);
      if (depthCompare != 0) return depthCompare;
      return _messageIdentityKey(a.message).compareTo(_messageIdentityKey(b.message));
    });

    return output.take(_maxTotalRows).toList(growable: false);
  }

  static List<TwitchChatRuntimeMessage> _buildParentChain({
    required TwitchChatRuntimeMessage selectedMessage,
    required TwitchChatRuntimeMessage? Function(TwitchChatRuntimeMessage message)
        parentOf,
  }) {
    final chain = <TwitchChatRuntimeMessage>[];
    final seen = <String>{_messageIdentityKey(selectedMessage)};
    var cursor = selectedMessage;

    for (var depth = 0; depth < _maxParentDepth; depth++) {
      final parent = parentOf(cursor);
      if (parent == null) break;

      final key = _messageIdentityKey(parent);
      if (!seen.add(key)) break;

      chain.insert(0, parent);
      cursor = parent;
    }

    return chain;
  }

  static String _conversationRootKey({
    required TwitchChatRuntimeMessage message,
    required TwitchChatRuntimeMessage? Function(TwitchChatRuntimeMessage message)
        parentOf,
  }) {
    var cursor = message;
    final seen = <String>{_messageIdentityKey(cursor)};

    for (var depth = 0; depth < _maxConversationDepth; depth++) {
      final parent = parentOf(cursor);
      if (parent == null) break;

      final key = _messageIdentityKey(parent);
      if (!seen.add(key)) break;

      cursor = parent;
    }

    return _messageIdentityKey(cursor);
  }

  static int _conversationDepthFromRoot({
    required TwitchChatRuntimeMessage message,
    required String rootKey,
    required TwitchChatRuntimeMessage? Function(TwitchChatRuntimeMessage message)
        parentOf,
  }) {
    final messageKey = _messageIdentityKey(message);
    if (messageKey == rootKey) return 0;

    var cursor = message;
    final seen = <String>{messageKey};
    var depth = 0;

    for (var index = 0; index < _maxConversationDepth; index++) {
      final parent = parentOf(cursor);
      if (parent == null) break;

      depth += 1;
      final parentKey = _messageIdentityKey(parent);
      if (parentKey == rootKey) return depth;
      if (!seen.add(parentKey)) break;

      cursor = parent;
    }

    return depth;
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
