// PATCH VERSION: twitch_emote_animation_policy_service_stage233h_frosty_like_default

import 'package:shared_preferences/shared_preferences.dart';

enum TwitchEmoteAnimationPolicy {
  visibleAnimated,
  staticWhileScroll,
  alwaysAnimated,
  staticOnly,
}

extension TwitchEmoteAnimationPolicyUi on TwitchEmoteAnimationPolicy {
  String get label {
    switch (this) {
      case TwitchEmoteAnimationPolicy.visibleAnimated:
        return 'Frosty 模式';
      case TwitchEmoteAnimationPolicy.staticWhileScroll:
        return '滑動時靜態';
      case TwitchEmoteAnimationPolicy.alwaysAnimated:
        return '一律動圖';
      case TwitchEmoteAnimationPolicy.staticOnly:
        return '一律靜態';
    }
  }

  String get description {
    switch (this) {
      case TwitchEmoteAnimationPolicy.visibleAnimated:
        return '接近 Frosty：使用動圖與 cache，不在滑動時頻繁切換 URL。';
      case TwitchEmoteAnimationPolicy.staticWhileScroll:
        return '滑動聊天室時暫時使用靜態圖，停止後恢復動圖。';
      case TwitchEmoteAnimationPolicy.alwaysAnimated:
        return '所有已建立的訊息列都維持動圖，效能較好的桌機可用。';
      case TwitchEmoteAnimationPolicy.staticOnly:
        return '所有貼圖都使用靜態圖，適合低效能或省電。';
    }
  }
}

class TwitchEmoteAnimationPolicyService {
  const TwitchEmoteAnimationPolicyService._();

  static const String preferenceKey = 'twitch_chat_emote_animation_policy_v1';

  /// Default to the stable Frosty-like path:
  /// keep animated URLs stable, rely on shared cache + ListView lifecycle, and
  /// avoid static/animated URL churn unless the user explicitly enables it.
  static const TwitchEmoteAnimationPolicy defaultPolicy =
      TwitchEmoteAnimationPolicy.visibleAnimated;

  static Future<TwitchEmoteAnimationPolicy> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(preferenceKey);
    if (raw == null || raw.trim().isEmpty) return defaultPolicy;

    return TwitchEmoteAnimationPolicy.values.firstWhere(
      (policy) => policy.name == raw,
      orElse: () => defaultPolicy,
    );
  }

  static Future<void> save(TwitchEmoteAnimationPolicy policy) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(preferenceKey, policy.name);
  }

  static TwitchEmoteAnimationPolicy next(TwitchEmoteAnimationPolicy current) {
    switch (current) {
      case TwitchEmoteAnimationPolicy.visibleAnimated:
        return TwitchEmoteAnimationPolicy.staticWhileScroll;
      case TwitchEmoteAnimationPolicy.staticWhileScroll:
        return TwitchEmoteAnimationPolicy.alwaysAnimated;
      case TwitchEmoteAnimationPolicy.alwaysAnimated:
        return TwitchEmoteAnimationPolicy.staticOnly;
      case TwitchEmoteAnimationPolicy.staticOnly:
        return TwitchEmoteAnimationPolicy.visibleAnimated;
    }
  }
}
