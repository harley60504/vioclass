class TwitchRewardLocalizer {
  const TwitchRewardLocalizer._();

  static const Map<String, String> _titles = <String, String>{
    'Choose an Emote to Unlock': '選擇解鎖貼圖',
    'Modify a Single Emote': '修改單一貼圖',
    'Unlock a Random Sub Emote': '解鎖隨機訂閱貼圖',
    'Highlight My Message': '醒目顯示訊息',
    'Send a Message in Sub-Only Mode': '在訂閱者模式中發送訊息',
    'Gigantify an Emote': '放大貼圖',
    'Celebrate and Pin': '慶祝並置頂',
    'First-Time Chatter Highlight': '醒目顯示首次發言',
  };

  static String title(String rawTitle, {bool translateBuiltIns = true}) {
    final clean = rawTitle.trim();
    if (clean.isEmpty) return clean;
    if (!translateBuiltIns) return clean;
    return _titles[clean] ?? clean;
  }

  static String typeLabel(String rawLabel) {
    switch (rawLabel.trim().toLowerCase()) {
      case 'builtin':
      case 'built-in':
        return '內建';
      case 'custom':
        return '自訂';
      default:
        return rawLabel;
    }
  }
}
