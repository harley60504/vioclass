// PATCH VERSION: twitch_emote_animation_policy_service_stage233e_stream_setting

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
        return '可見時動圖';
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
        return '一般模式，聊天室停住時動圖會播放。';
      case TwitchEmoteAnimationPolicy.staticWhileScroll:
        return '滑動聊天室時暫時使用靜態圖，停止後恢復動圖。';
      case TwitchEmoteAnimationPolicy.alwaysAnimated:
        return '不因滑動降級，效能較好的桌機可用。';
      case TwitchEmoteAnimationPolicy.staticOnly:
        return '所有貼圖都使用靜態圖，適合低效能或省電。';
    }
  }
}

class TwitchEmoteAnimationPolicyService {
  const TwitchEmoteAnimationPolicyService._();

  static const String preferenceKey = 'twitch_chat_emote_animation_policy_v1';

  static const TwitchEmoteAnimationPolicy defaultPolicy =
      TwitchEmoteAnimationPolicy.staticWhileScroll;

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
