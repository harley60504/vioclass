/// Fixed, local message shortcuts. They open confirmation, never submit writes.
enum TwitchChatModerationShortcut { delete, timeout, warn, ban, unban }

extension TwitchChatModerationShortcutLabel on TwitchChatModerationShortcut {
  String get actionLabel => switch (this) {
    TwitchChatModerationShortcut.delete => '刪除訊息',
    TwitchChatModerationShortcut.timeout => '自訂禁言時間',
    TwitchChatModerationShortcut.warn => '警告',
    TwitchChatModerationShortcut.ban => '封鎖',
    TwitchChatModerationShortcut.unban => '解除封鎖／禁言',
  };
}
