import '../../models/discovery/twitch_live_stream.dart';

/// Seed silently; announce offline -> live, not a title/game/stream-id change.
class TwitchLiveNotificationPolicy {
  static const repeatWindow = Duration(minutes: 5);
  final DateTime Function() now;
  TwitchLiveNotificationPolicy({DateTime Function()? clock})
    : now = clock ?? DateTime.now;
  Set<String>? _live;
  final Map<String, DateTime> _announced = {};

  List<TwitchLiveStream> observe(List<TwitchLiveStream> streams) {
    final current = streams.map(_key).where((key) => key.isNotEmpty).toSet();
    final previous = _live;
    _live = current;
    if (previous == null) return [];
    final at = now();
    _announced.removeWhere((key, time) => at.difference(time) >= repeatWindow);
    final fresh = <TwitchLiveStream>[];
    for (final stream in streams) {
      final key = _key(stream);
      if (key.isEmpty ||
          previous.contains(key) ||
          _announced.containsKey(key)) {
        continue;
      }
      _announced[key] = at;
      fresh.add(stream);
    }
    return fresh;
  }

  String _key(TwitchLiveStream stream) => stream.channelLogin.isNotEmpty
      ? stream.channelLogin
      : stream.userId.trim();

  void reset() {
    _live = null;
    _announced.clear();
  }
}
