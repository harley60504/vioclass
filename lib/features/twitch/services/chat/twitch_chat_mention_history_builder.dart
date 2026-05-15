import '../../models/chat/twitch_chat_mention_history.dart';
import '../../models/chat/twitch_chat_runtime_message.dart';

class TwitchChatMentionHistoryBuilder {
  const TwitchChatMentionHistoryBuilder._();

  static final RegExp _mentionRegex = RegExp(
    r'(^|[\s，,。:：;；!！?？()\[\]{}<>「」『』])@([A-Za-z0-9_]{2,25})',
    unicode: true,
  );

  static List<TwitchChatMentionHistoryGroup> buildGroups(
    List<TwitchChatRuntimeMessage> messages, {
    int maxMessages = 260,
  }) {
    final recent = messages.length <= maxMessages
        ? messages
        : messages.sublist(messages.length - maxMessages);

    final items = <TwitchChatMentionHistoryItem>[];
    final displayNames = <String, String>{};
    final parent = <String, String>{};

    String normalize(String value) => value.trim().toLowerCase();

    String find(String value) {
      final clean = normalize(value);
      if (clean.isEmpty) return clean;
      parent.putIfAbsent(clean, () => clean);
      final current = parent[clean]!;
      if (current == clean) return clean;
      final root = find(current);
      parent[clean] = root;
      return root;
    }

    void union(String a, String b) {
      final rootA = find(a);
      final rootB = find(b);
      if (rootA.isEmpty || rootB.isEmpty || rootA == rootB) return;
      parent[rootB] = rootA;
    }

    void rememberDisplay(String login, String displayName) {
      final clean = normalize(login);
      if (clean.isEmpty) return;
      final label = displayName.trim().isNotEmpty ? displayName.trim() : login.trim();
      displayNames.putIfAbsent(clean, () => label);
      parent.putIfAbsent(clean, () => clean);
    }

    for (final message in recent) {
      final fromLogin = normalize(message.userLogin);
      if (fromLogin.isEmpty) continue;

      rememberDisplay(fromLogin, message.displayName);
      final body = message.message;

      final seenTargets = <String>{};

      for (final match in _mentionRegex.allMatches(body)) {
        final target = normalize(match.group(2) ?? '');
        if (target.isEmpty || target == fromLogin || !seenTargets.add(target)) {
          continue;
        }

        rememberDisplay(target, match.group(2) ?? target);
        union(fromLogin, target);
        items.add(
          TwitchChatMentionHistoryItem(
            message: message,
            fromLogin: fromLogin,
            fromDisplayName: displayNames[fromLogin] ?? fromLogin,
            targetLogin: target,
            targetDisplayName: displayNames[target] ?? target,
            fromReply: false,
          ),
        );
      }

      final reply = message.metadata.replyInfo;
      final replyTarget = normalize(reply?.parentUserLogin ?? '');
      if (replyTarget.isNotEmpty &&
          replyTarget != fromLogin &&
          !seenTargets.contains(replyTarget)) {
        rememberDisplay(
          replyTarget,
          reply?.parentDisplayName ?? replyTarget,
        );
        union(fromLogin, replyTarget);
        items.add(
          TwitchChatMentionHistoryItem(
            message: message,
            fromLogin: fromLogin,
            fromDisplayName: displayNames[fromLogin] ?? fromLogin,
            targetLogin: replyTarget,
            targetDisplayName: displayNames[replyTarget] ?? replyTarget,
            fromReply: true,
          ),
        );
      }
    }

    final grouped = <String, List<TwitchChatMentionHistoryItem>>{};
    for (final item in items) {
      final root = find(item.fromLogin);
      if (root.isEmpty) continue;
      grouped.putIfAbsent(root, () => <TwitchChatMentionHistoryItem>[]).add(item);
    }

    final groups = <TwitchChatMentionHistoryGroup>[];
    for (final entry in grouped.entries) {
      final groupItems = entry.value
        ..sort((a, b) => b.message.receivedAt.compareTo(a.message.receivedAt));

      final participants = <String>{};
      for (final item in groupItems) {
        participants.add(item.fromLogin);
        participants.add(item.targetLogin);
      }

      final labels = participants
          .map((login) => displayNames[login] ?? login)
          .toList(growable: false)
        ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

      groups.add(
        TwitchChatMentionHistoryGroup(
          participants: labels,
          items: List<TwitchChatMentionHistoryItem>.unmodifiable(groupItems),
        ),
      );
    }

    groups.sort((a, b) => b.latestAt.compareTo(a.latestAt));
    return List<TwitchChatMentionHistoryGroup>.unmodifiable(groups);
  }
}
