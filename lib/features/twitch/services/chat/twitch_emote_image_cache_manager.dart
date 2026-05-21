// PATCH VERSION: twitch_emote_image_cache_manager_stage233c_static_precache

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

  static String buildCacheKey({
    required String providerLabel,
    required String id,
    required String name,
    required bool staticVariant,
    required String url,
  }) {
    final provider = providerLabel.trim().isEmpty ? 'emote' : providerLabel.trim();
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
