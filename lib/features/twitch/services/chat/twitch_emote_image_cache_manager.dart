import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// Shared image cache used by chat emotes.
///
/// This keeps static and animated variants under predictable cache keys so the
/// chat renderer can switch between static/animated policy without redownloading
/// the same emote repeatedly.
class TwitchEmoteImageCacheManager {
  const TwitchEmoteImageCacheManager._();

  static final CacheManager instance = CacheManager(
    Config(
      'twitchSharedEmoteImageCache',
      stalePeriod: const Duration(days: 30),
      maxNrOfCacheObjects: 16000,
    ),
  );

  static final CacheManager animatedInstance = CacheManager(
    Config(
      'twitchAnimatedEmoteImageCache',
      stalePeriod: const Duration(days: 7),
      maxNrOfCacheObjects: 300,
    ),
  );

  static final Map<String, Future<Uint8List>> _animatedLoads =
      <String, Future<Uint8List>>{};

  static Future<Uint8List> loadAnimatedBytes(String url) {
    final sourceUrl = url.trim();
    if (sourceUrl.isEmpty) {
      return Future<Uint8List>.error(
        ArgumentError.value(url, 'url', 'cannot be empty'),
      );
    }

    final existing = _animatedLoads[sourceUrl];
    if (existing != null) return existing;

    late final Future<Uint8List> load;
    load = _loadAnimatedBytes(sourceUrl).whenComplete(() {
      if (identical(_animatedLoads[sourceUrl], load)) {
        _animatedLoads.remove(sourceUrl);
      }
    });
    _animatedLoads[sourceUrl] = load;
    return load;
  }

  static Future<Uint8List> _loadAnimatedBytes(String url) async {
    final cached = await animatedInstance.getFileFromCache(url);
    if (cached != null && await cached.file.exists()) {
      return cached.file.readAsBytes();
    }

    final downloaded = await animatedInstance.downloadFile(
      url,
      key: url,
      force: false,
    );
    return downloaded.file.readAsBytes();
  }

  static String buildCacheKey({
    required String providerLabel,
    required String id,
    required String name,
    required bool staticVariant,
    required String url,
  }) {
    final provider = providerLabel.trim().isEmpty
        ? 'emote'
        : providerLabel.trim();
    final cleanId = id.trim();
    final stableId = cleanId.isNotEmpty ? cleanId : name.trim().toLowerCase();
    return '$provider:$stableId:${staticVariant ? 'static' : 'animated'}:${url.trim()}';
  }

  static Future<void> precacheStaticUrls(
    Iterable<TwitchEmoteStaticCacheRequest> requests, {
    int maxCount = 160,
    int batchSize = 8,
  }) async {
    final unique = <String, TwitchEmoteStaticCacheRequest>{};

    for (final request in requests) {
      final url = request.url.trim();
      if (url.isEmpty) continue;
      unique.putIfAbsent(request.cacheKey, () => request);
      if (unique.length >= maxCount) break;
    }

    final values = unique.values.toList(growable: false);
    for (var index = 0; index < values.length; index += batchSize) {
      final batch = values.skip(index).take(batchSize).toList(growable: false);
      await Future.wait<void>(
        batch.map((request) async {
          try {
            await instance.downloadFile(
              request.url,
              key: request.cacheKey,
              force: false,
            );
          } catch (error) {
            debugPrint(
              'Precache static emote failed: ${request.name} ${request.url} $error',
            );
          }
        }),
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
  }
}

class TwitchEmoteStaticCacheRequest {
  final String providerLabel;
  final String id;
  final String name;
  final String url;

  const TwitchEmoteStaticCacheRequest({
    required this.providerLabel,
    required this.id,
    required this.name,
    required this.url,
  });

  String get cacheKey {
    return TwitchEmoteImageCacheManager.buildCacheKey(
      providerLabel: providerLabel,
      id: id,
      name: name,
      staticVariant: true,
      url: url,
    );
  }
}
