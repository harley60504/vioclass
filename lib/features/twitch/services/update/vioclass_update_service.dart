import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

const String vioclassCurrentVersion = String.fromEnvironment(
  'VIOCLASS_VERSION',
  defaultValue: '1.0.6.7',
);

class VioClassUpdateService {
  static const String latestReleaseUrl =
      'https://api.github.com/repos/harley60504/vioclass/releases/latest';

  final Dio _dio;
  final bool _closeDioOnDispose;

  VioClassUpdateService({Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 8),
              receiveTimeout: const Duration(seconds: 12),
              headers: const <String, String>{
                'Accept': 'application/vnd.github+json',
                'User-Agent': 'VioClass update checker',
              },
            ),
          ),
      _closeDioOnDispose = dio == null;

  Future<VioClassUpdateInfo> checkLatest() async {
    final response = await _dio.get<Map<String, dynamic>>(latestReleaseUrl);
    final raw = response.data ?? const <String, dynamic>{};
    final release = VioClassRelease.fromGithubJson(raw);
    return VioClassUpdateInfo(
      currentVersion: vioclassCurrentVersion,
      release: release,
      updateAvailable: _compareVersions(
        release.version,
        vioclassCurrentVersion,
      ).isNewer,
    );
  }

  Future<File> downloadPreferredAsset({
    required VioClassUpdateInfo info,
    required void Function(double progress) onProgress,
  }) async {
    final asset = info.preferredAsset;
    if (asset == null || asset.downloadUrl.trim().isEmpty) {
      throw StateError('找不到適合此平台的更新檔。');
    }

    final directory = await getTemporaryDirectory();
    final updateDirectory = Directory(
      '${directory.path}${Platform.pathSeparator}vioclass_updates',
    );
    if (!updateDirectory.existsSync()) {
      updateDirectory.createSync(recursive: true);
    }
    final file = File(
      '${updateDirectory.path}${Platform.pathSeparator}${asset.name}',
    );

    await _dio.download(
      asset.downloadUrl,
      file.path,
      options: Options(
        headers: const <String, String>{'Accept': 'application/octet-stream'},
      ),
      onReceiveProgress: (received, total) {
        if (total <= 0) return;
        onProgress((received / total).clamp(0.0, 1.0));
      },
    );
    onProgress(1);
    return file;
  }

  void dispose() {
    if (_closeDioOnDispose) _dio.close(force: true);
  }

  VioClassVersionComparison _compareVersions(String latest, String current) {
    final latestParts = _versionParts(latest);
    final currentParts = _versionParts(current);
    final length = latestParts.length > currentParts.length
        ? latestParts.length
        : currentParts.length;

    for (var index = 0; index < length; index++) {
      final left = index < latestParts.length ? latestParts[index] : 0;
      final right = index < currentParts.length ? currentParts[index] : 0;
      if (left > right) return VioClassVersionComparison.newer;
      if (left < right) return VioClassVersionComparison.older;
    }
    return VioClassVersionComparison.same;
  }

  List<int> _versionParts(String value) {
    final clean = value
        .trim()
        .replaceFirst(RegExp(r'^[vV]'), '')
        .split('+')
        .first
        .split('-')
        .first;
    return clean
        .split('.')
        .map((part) => int.tryParse(part.trim()) ?? 0)
        .toList(growable: false);
  }
}

class VioClassUpdateInfo {
  final String currentVersion;
  final VioClassRelease release;
  final bool updateAvailable;

  const VioClassUpdateInfo({
    required this.currentVersion,
    required this.release,
    required this.updateAvailable,
  });

  VioClassReleaseAsset? get preferredAsset => release.preferredAsset;
}

class VioClassRelease {
  final String tagName;
  final String version;
  final String name;
  final String body;
  final String htmlUrl;
  final DateTime? publishedAt;
  final List<VioClassReleaseAsset> assets;

  const VioClassRelease({
    required this.tagName,
    required this.version,
    required this.name,
    required this.body,
    required this.htmlUrl,
    required this.publishedAt,
    required this.assets,
  });

  factory VioClassRelease.fromGithubJson(Map<String, dynamic> json) {
    final tag = json['tag_name']?.toString().trim() ?? '';
    final rawAssets = json['assets'];
    return VioClassRelease(
      tagName: tag,
      version: tag.replaceFirst(RegExp(r'^[vV]'), ''),
      name: json['name']?.toString().trim() ?? tag,
      body: json['body']?.toString().trim() ?? '',
      htmlUrl: json['html_url']?.toString().trim() ?? '',
      publishedAt: DateTime.tryParse(
        json['published_at']?.toString().trim() ?? '',
      ),
      assets: rawAssets is List
          ? rawAssets
                .whereType<Map<String, dynamic>>()
                .map(VioClassReleaseAsset.fromGithubJson)
                .where((asset) => asset.downloadUrl.isNotEmpty)
                .toList(growable: false)
          : const <VioClassReleaseAsset>[],
    );
  }

  VioClassReleaseAsset? get preferredAsset {
    if (Platform.isAndroid) {
      return _firstAsset((name) => name.endsWith('.apk'));
    }
    if (Platform.isWindows) {
      return _firstAsset(
        (name) => name.contains('windows') && name.endsWith('.zip'),
      );
    }
    return assets.isEmpty ? null : assets.first;
  }

  VioClassReleaseAsset? _firstAsset(bool Function(String name) test) {
    for (final asset in assets) {
      if (test(asset.name.toLowerCase())) return asset;
    }
    return null;
  }
}

class VioClassReleaseAsset {
  final String name;
  final String downloadUrl;
  final int size;

  const VioClassReleaseAsset({
    required this.name,
    required this.downloadUrl,
    required this.size,
  });

  factory VioClassReleaseAsset.fromGithubJson(Map<String, dynamic> json) {
    return VioClassReleaseAsset(
      name: json['name']?.toString().trim() ?? '',
      downloadUrl: json['browser_download_url']?.toString().trim() ?? '',
      size: int.tryParse(json['size']?.toString() ?? '') ?? 0,
    );
  }
}

enum VioClassVersionComparison {
  older,
  same,
  newer;

  bool get isNewer => this == VioClassVersionComparison.newer;
}
