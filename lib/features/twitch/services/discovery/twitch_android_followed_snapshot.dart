import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../../api/core/twitch_api_exception.dart';
import '../../models/discovery/twitch_live_stream.dart';

/// Uses the same public snapshot as Android live notifications. Token-free bridge.
class TwitchAndroidFollowedSnapshot {
  static const channel = MethodChannel('vio_class/background_receiving');
  final _windows = <String, List<TwitchLiveStream>>{};
  int _generation = 0;

  void clear() {
    _generation++;
    _windows.clear();
  }

  Future<TwitchStreamPageResult?> page({
    required String owner,
    String? after,
    required int first,
  }) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return null;
    }
    final generation = _generation;
    const prefix = 'native-followed:';
    String version;
    var offset = 0;
    List<TwitchLiveStream>? streams;
    if (after?.startsWith(prefix) == true) {
      final parts = after!.substring(prefix.length).split(':');
      if (parts.length != 2 || (offset = int.tryParse(parts.last) ?? -1) < 0) {
        throw const TwitchApiException('追隨直播分頁無效，請重新整理。');
      }
      version = parts.first;
      streams = _windows['$owner:$version'];
      if (streams == null) {
        throw const TwitchApiException('追隨直播清單已更新，請重新整理。');
      }
    } else {
      if (after != null && after.isNotEmpty) {
        return null; // Existing Helix page.
      }
      String? raw;
      try {
        raw = await channel.invokeMethod<String>('followedLiveSnapshot', {
          'owner': owner,
        });
      } on PlatformException {
        return null;
      } on MissingPluginException {
        return null;
      }
      if (raw == null) {
        return null; // Native configuration not ready or disabled.
      }
      if (generation != _generation) {
        throw const TwitchApiException('登入狀態已變更，請重新整理追隨直播。');
      }
      final snapshot = jsonDecode(raw) as Map;
      if (snapshot['owner'] != owner || snapshot['streams'] is! List) {
        return null;
      }
      version = snapshot['updatedAt'].toString();
      streams = (snapshot['streams'] as List)
          .map((entry) {
            final data = Map<String, dynamic>.from(entry as Map);
            return TwitchLiveStream.fromHelixJson(data).copyWith(
              profileImageUrl: data['profile_image_url']?.toString() ?? '',
            );
          })
          .toList(growable: false);
      if (_windows.length >= 4) {
        _windows.remove(_windows.keys.first);
      }
      _windows['$owner:$version'] = List.unmodifiable(streams);
    }
    if (offset > streams.length) {
      throw const TwitchApiException('追隨直播分頁無效，請重新整理。');
    }
    final end = (offset + first.clamp(1, 100)).clamp(0, streams.length);
    return TwitchStreamPageResult(
      streams: List.unmodifiable(streams.sublist(offset, end)),
      cursor: end < streams.length ? '$prefix$version:$end' : null,
    );
  }
}
