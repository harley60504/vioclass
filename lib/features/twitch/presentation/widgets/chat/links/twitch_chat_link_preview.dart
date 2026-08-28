import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../api/core/twitch_api_constants.dart';
import '../../../../models/discovery/twitch_live_stream.dart';
import '../../../../models/discovery/twitch_stream_header_metadata.dart';
import '../../../pages/twitch_watch_page.dart';
import '../../../theme/twitch_ui_tokens.dart';
import '../twitch_chat_text_style.dart';
import '../../shared/twitch_cached_image_layer.dart';
import 'twitch_chat_link_preview_models.dart';
import 'twitch_chat_link_preview_policy.dart';

export 'twitch_chat_link_preview_models.dart';
export 'twitch_chat_link_preview_policy.dart';

class _TwitchClipLink {
  final String slug;
  final String? channelLogin;

  const _TwitchClipLink({required this.slug, this.channelLogin});
}

final Dio _linkPreviewDio = Dio(
  BaseOptions(
    connectTimeout: const Duration(seconds: 5),
    receiveTimeout: const Duration(seconds: 7),
    followRedirects: true,
    headers: const <String, String>{
      'Accept':
          'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
      'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
    },
  ),
);
final Map<String, TwitchChatLinkPreviewData?> _linkPreviewCache =
    <String, TwitchChatLinkPreviewData?>{};
final Map<String, Future<TwitchChatLinkPreviewData?>> _linkPreviewInflight =
    <String, Future<TwitchChatLinkPreviewData?>>{};

const String _clipPreviewQuery = r'''
  query ChatLinkPreviewClip($slug: ID!) {
    clip(slug: $slug) {
      slug
      title
      thumbnailURL
      durationSeconds
      viewCount
      broadcaster {
        login
        displayName
      }
      curator {
        login
        displayName
      }
      game {
        displayName
      }
    }
  }
''';

List<InlineSpan> buildTwitchChatLinkifiedSpans({
  required BuildContext context,
  required String text,
  required TextStyle textStyle,
  required TextStyle linkStyle,
}) {
  final parts = splitTwitchChatLinks(text);
  if (parts.isEmpty) {
    return <InlineSpan>[TextSpan(text: text, style: textStyle)];
  }

  return <InlineSpan>[
    for (final part in parts)
      if (part.isLink)
        WidgetSpan(
          alignment: PlaceholderAlignment.baseline,
          baseline: TextBaseline.alphabetic,
          child: TwitchChatLinkText(
            text: part.text,
            style: linkStyle,
            dense: true,
          ),
        )
      else
        TextSpan(text: part.text, style: textStyle),
  ];
}

class TwitchChatLinkText extends StatelessWidget {
  final String text;
  final TextStyle style;
  final bool dense;

  const TwitchChatLinkText({
    super.key,
    required this.text,
    required this.style,
    this.dense = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(5),
      onTap: () => showTwitchChatLinkPreviewSheet(context, text),
      onLongPress: () => copyTwitchChatLink(context, text),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: dense ? 1 : 2),
        child: Text(text, textAlign: TextAlign.left, style: style),
      ),
    );
  }
}

class TwitchChatLinkPreviewColumn extends StatelessWidget {
  final List<TwitchChatPreviewUrl> items;
  final double fontScale;

  const TwitchChatLinkPreviewColumn({
    super.key,
    required this.items,
    this.fontScale = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: TwitchChatLinkPreviewCard(item: item, fontScale: fontScale),
          ),
      ],
    );
  }
}

class TwitchChatLinkPreviewCard extends StatelessWidget {
  final TwitchChatPreviewUrl item;
  final double fontScale;

  const TwitchChatLinkPreviewCard({
    super.key,
    required this.item,
    this.fontScale = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    final uri = normalizeTwitchChatUri(item.url);
    final host = uri?.host.replaceFirst(RegExp(r'^www\.'), '') ?? '連結';
    final iconColor = item.trusted
        ? TwitchUiColors.primarySoft
        : const Color(0xFFFFC857);
    final label = item.trusted ? '連結預覽' : '不自動載入的連結';

    if (item.trusted) {
      return _TrustedLinkPreviewCard(item: item, fontScale: fontScale);
    }

    return _LinkPreviewShell(
      item: item,
      fontScale: fontScale,
      icon: Icons.security_rounded,
      iconColor: iconColor,
      title: host,
      subtitle: '$label · ${prettyTwitchChatUrlLabel(item.url)}',
    );
  }
}

class _TrustedLinkPreviewCard extends StatefulWidget {
  final TwitchChatPreviewUrl item;
  final double fontScale;

  const _TrustedLinkPreviewCard({required this.item, required this.fontScale});

  @override
  State<_TrustedLinkPreviewCard> createState() =>
      _TrustedLinkPreviewCardState();
}

class _TrustedLinkPreviewCardState extends State<_TrustedLinkPreviewCard> {
  TwitchChatLinkPreviewData? _preview;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadPreview();
  }

  @override
  void didUpdateWidget(covariant _TrustedLinkPreviewCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.url != widget.item.url) {
      _preview = null;
      _loading = true;
      _loadPreview();
    }
  }

  Future<void> _loadPreview() async {
    final preview = await fetchTwitchChatLinkPreview(widget.item.url);
    if (!mounted) return;
    setState(() {
      _preview = preview;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final uri = normalizeTwitchChatUri(widget.item.url);
    final host = uri?.host.replaceFirst(RegExp(r'^www\.'), '') ?? '連結';
    final preview = _preview;
    if (_loading) {
      return _LinkPreviewShell(
        item: widget.item,
        fontScale: widget.fontScale,
        icon: Icons.link_rounded,
        iconColor: TwitchUiColors.primarySoft,
        title: host,
        subtitle: '正在載入預覽 · ${prettyTwitchChatUrlLabel(widget.item.url)}',
        loading: true,
      );
    }

    if (preview == null || !preview.hasContent) {
      return _LinkPreviewShell(
        item: widget.item,
        fontScale: widget.fontScale,
        icon: Icons.link_rounded,
        iconColor: TwitchUiColors.primarySoft,
        title: host,
        subtitle: '連結預覽 · ${prettyTwitchChatUrlLabel(widget.item.url)}',
      );
    }

    return _LinkPreviewShell(
      item: widget.item,
      fontScale: widget.fontScale,
      icon: Icons.link_rounded,
      iconColor: TwitchUiColors.primarySoft,
      title: preview.title?.trim().isNotEmpty == true
          ? preview.title!.trim()
          : host,
      subtitle: preview.description?.trim().isNotEmpty == true
          ? preview.description!.trim()
          : preview.siteName?.trim().isNotEmpty == true
          ? preview.siteName!.trim()
          : prettyTwitchChatUrlLabel(widget.item.url),
      imageUrl: preview.imageUrl,
      siteName: preview.siteName,
      preview: preview,
    );
  }
}

class _LinkPreviewShell extends StatelessWidget {
  final TwitchChatPreviewUrl item;
  final double fontScale;
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String? imageUrl;
  final String? siteName;
  final TwitchChatLinkPreviewData? preview;
  final bool loading;

  const _LinkPreviewShell({
    required this.item,
    required this.fontScale,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    this.imageUrl,
    this.siteName,
    this.preview,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    final scale = fontScale.clamp(0.82, 1.36).toDouble();
    final image = imageUrl?.trim() ?? '';
    final kind = preview?.kind ?? '';
    final showsHeroImage =
        image.isNotEmpty &&
        (kind == 'youtube' || kind == 'clip' || kind == 'vod');

    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () {
        final clip = _parseTwitchClipLink(item.url);
        if (item.trusted && clip != null && !loading) {
          _openTwitchClipInside(
            context,
            clip: clip,
            url: item.url,
            title: preview?.title ?? title,
            thumbnailUrl: image,
          );
          return;
        }
        showTwitchChatLinkPreviewSheet(context, item.url);
      },
      onLongPress: () => copyTwitchChatLink(context, item.url),
      child: Ink(
        decoration: BoxDecoration(
          color: const Color(0xFF20202A),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: iconColor.withValues(alpha: item.trusted ? 0.30 : 0.22),
          ),
        ),
        child: showsHeroImage
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        TwitchCachedImageLayer(
                          imageUrl: image,
                          width: double.infinity,
                          height: double.infinity,
                          fit: BoxFit.cover,
                          cacheWidth: 480,
                          cacheHeight: 270,
                        ),
                        Center(
                          child: Container(
                            width: 44,
                            height: 44,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.58),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.play_arrow_rounded,
                              color: Colors.white,
                              size: 30,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(10, 8 * scale, 10, 9 * scale),
                    child: _LinkPreviewTextBlock(
                      title: title,
                      subtitle: subtitle,
                      siteName: siteName,
                      author: preview?.author,
                      scale: scale,
                    ),
                  ),
                ],
              )
            : Padding(
                padding: EdgeInsets.fromLTRB(9, 7 * scale, 9, 7 * scale),
                child: Row(
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: iconColor.withValues(alpha: 0.13),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(icon, color: iconColor, size: 17),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: _LinkPreviewTextBlock(
                        title: title,
                        subtitle: subtitle,
                        siteName: siteName,
                        author: preview?.author,
                        scale: scale,
                        compact: image.isEmpty,
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (loading)
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: iconColor.withValues(alpha: 0.9),
                        ),
                      )
                    else if (image.isNotEmpty)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(7),
                        child: TwitchCachedImageLayer(
                          imageUrl: image,
                          width: 58,
                          height: 38,
                          fit: BoxFit.cover,
                          cacheWidth: 160,
                          cacheHeight: 96,
                        ),
                      )
                    else
                      Icon(
                        _parseTwitchClipLink(item.url) == null
                            ? Icons.open_in_new_rounded
                            : Icons.play_arrow_rounded,
                        color: Colors.white38,
                        size: 17,
                      ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _LinkPreviewTextBlock extends StatelessWidget {
  final String title;
  final String subtitle;
  final String? siteName;
  final String? author;
  final double scale;
  final bool compact;

  const _LinkPreviewTextBlock({
    required this.title,
    required this.subtitle,
    required this.scale,
    this.siteName,
    this.author,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final cleanSite = siteName?.trim() ?? '';
    final cleanAuthor = author?.trim() ?? '';
    final heading = cleanSite.isNotEmpty ? cleanSite : title;
    final body = cleanSite.isNotEmpty ? title : subtitle;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                heading,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12.5 * scale,
                  fontWeight: FontWeight.w900,
                  height: 1.1,
                ),
              ),
            ),
            if (cleanAuthor.isNotEmpty) ...[
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  cleanAuthor,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: TwitchUiColors.textMuted,
                    fontSize: 10.5 * scale,
                    fontWeight: FontWeight.w700,
                    height: 1.1,
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 2),
        Text(
          body,
          maxLines: compact ? 2 : 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: TwitchUiColors.textMuted,
            fontSize: 11 * scale,
            fontWeight: FontWeight.w700,
            height: 1.16,
          ),
        ),
      ],
    );
  }
}

Future<TwitchChatLinkPreviewData?> fetchTwitchChatLinkPreview(String rawUrl) {
  final uri = normalizeTwitchChatUri(rawUrl);
  if (uri == null || !isTrustedTwitchChatUri(uri)) {
    return Future<TwitchChatLinkPreviewData?>.value(null);
  }

  final url = uri.toString();
  if (_linkPreviewCache.containsKey(url)) {
    return Future<TwitchChatLinkPreviewData?>.value(_linkPreviewCache[url]);
  }

  final existing = _linkPreviewInflight[url];
  if (existing != null) return existing;

  final future = _fetchTwitchChatLinkPreview(uri)
      .then((preview) {
        _linkPreviewCache[url] = preview;
        _linkPreviewInflight.remove(url);
        return preview;
      })
      .catchError((Object _) {
        _linkPreviewCache[url] = null;
        _linkPreviewInflight.remove(url);
        return null;
      });
  _linkPreviewInflight[url] = future;
  return future;
}

_TwitchClipLink? _parseTwitchClipLink(String rawUrl) {
  final uri = normalizeTwitchChatUri(rawUrl);
  if (uri == null) return null;

  final host = uri.host.toLowerCase();
  final segments = uri.pathSegments
      .map((part) => part.trim())
      .where((part) => part.isNotEmpty)
      .toList(growable: false);
  if (segments.isEmpty) return null;

  if (host == 'clips.twitch.tv' || host.endsWith('.clips.twitch.tv')) {
    return _TwitchClipLink(slug: segments.first);
  }

  if (host == 'twitch.tv' ||
      host.endsWith('.twitch.tv') ||
      host == 'm.twitch.tv') {
    final clipIndex = segments.indexWhere(
      (part) => part.toLowerCase() == 'clip',
    );
    if (clipIndex >= 0 && clipIndex + 1 < segments.length) {
      return _TwitchClipLink(
        slug: segments[clipIndex + 1],
        channelLogin: clipIndex > 0 ? segments[clipIndex - 1] : null,
      );
    }
  }

  return null;
}

void _openTwitchClipInside(
  BuildContext context, {
  required _TwitchClipLink clip,
  required String url,
  required String title,
  required String thumbnailUrl,
}) {
  final channelLogin = clip.channelLogin?.trim();
  final fallbackLogin = channelLogin?.isNotEmpty == true
      ? channelLogin!
      : 'twitch';
  final cleanTitle = title.trim();
  final cleanThumbnail = thumbnailUrl.trim();

  Navigator.of(context, rootNavigator: true).push(
    MaterialPageRoute<void>(
      builder: (_) => TwitchWatchPage(
        initialMetadata: TwitchStreamHeaderMetadata(
          channelLogin: fallbackLogin,
          streamTitle: cleanTitle,
        ),
        initialClip: TwitchChannelClip(
          id: clip.slug,
          url: url,
          embedUrl: '',
          broadcasterId: '',
          broadcasterName: fallbackLogin,
          creatorName: '',
          videoId: '',
          gameId: '',
          language: '',
          title: cleanTitle.isEmpty ? 'Twitch 片段' : cleanTitle,
          viewCount: 0,
          createdAt: null,
          thumbnailUrl: cleanThumbnail,
          duration: 0,
          vodOffset: 0,
        ),
      ),
    ),
  );
}

Future<TwitchChatLinkPreviewData?> _fetchTwitchChatLinkPreview(Uri uri) async {
  final youtubeId = _parseYouTubeVideoId(uri);
  if (youtubeId != null) {
    return _fetchYouTubePreview(uri, youtubeId);
  }

  final twitchClip = _parseTwitchClipLink(uri.toString());
  if (twitchClip != null) {
    final preview = await _fetchTwitchClipPreview(uri, twitchClip);
    if (preview != null) return preview;
  }

  final response = await _linkPreviewDio.getUri<String>(
    uri,
    options: Options(
      responseType: ResponseType.plain,
      headers: const <String, String>{'Range': 'bytes=0-262143'},
      validateStatus: (status) => status != null && status < 500,
    ),
  );

  final status = response.statusCode ?? 0;
  final html = response.data ?? '';
  if (status >= 400 || html.trim().isEmpty) return null;
  final responseUri = response.realUri;

  final title =
      _readMeta(html, const <String>['og:title', 'twitter:title']) ??
      _readTitle(html);
  final description = _readMeta(html, const <String>[
    'og:description',
    'twitter:description',
    'description',
  ]);
  final image = _readMeta(html, const <String>[
    'og:image',
    'twitter:image',
    'twitter:image:src',
  ]);
  final siteName = _readMeta(html, const <String>[
    'og:site_name',
    'application-name',
  ]);

  return TwitchChatLinkPreviewData(
    url: uri.toString(),
    kind: _detectPreviewKind(responseUri),
    host: responseUri.host.replaceFirst(RegExp(r'^www\.'), ''),
    title: _cleanPreviewText(title),
    description: _cleanPreviewText(description),
    imageUrl: image == null ? null : responseUri.resolve(image).toString(),
    siteName: _cleanPreviewText(siteName),
  );
}

Future<TwitchChatLinkPreviewData> _fetchYouTubePreview(
  Uri uri,
  String videoId,
) async {
  String? title;
  String? author;

  try {
    final response = await _linkPreviewDio.getUri<Map<String, dynamic>>(
      Uri.https('www.youtube.com', '/oembed', <String, String>{
        'url': uri.toString(),
        'format': 'json',
      }),
      options: Options(
        responseType: ResponseType.json,
        validateStatus: (status) => status != null && status < 500,
      ),
    );
    final data = response.data;
    if ((response.statusCode ?? 0) < 400 && data != null) {
      title = data['title']?.toString();
      author = data['author_name']?.toString();
    }
  } catch (_) {
    // Thumbnail is deterministic from the id; oEmbed is only for nicer labels.
  }

  return TwitchChatLinkPreviewData(
    url: uri.toString(),
    kind: 'youtube',
    host: uri.host.replaceFirst(RegExp(r'^www\.'), ''),
    title: _cleanPreviewText(title) ?? 'YouTube 影片',
    description: prettyTwitchChatUrlLabel(uri.toString()),
    imageUrl: 'https://i.ytimg.com/vi/$videoId/hqdefault.jpg',
    siteName: 'YouTube',
    author: _cleanPreviewText(author),
    videoId: videoId,
  );
}

Future<TwitchChatLinkPreviewData?> _fetchTwitchClipPreview(
  Uri uri,
  _TwitchClipLink clipLink,
) async {
  final response = await _linkPreviewDio.post<Map<String, dynamic>>(
    TwitchApiConstants.gqlEndpoint,
    data: <String, dynamic>{
      'operationName': 'ChatLinkPreviewClip',
      'variables': <String, dynamic>{'slug': clipLink.slug},
      'query': _clipPreviewQuery,
    },
    options: Options(
      responseType: ResponseType.json,
      headers: const <String, String>{
        'Client-ID': TwitchApiConstants.twitchWebClientId,
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'Origin': 'https://www.twitch.tv',
        'Referer': 'https://www.twitch.tv/',
        'User-Agent': TwitchApiConstants.browserUserAgent,
      },
      validateStatus: (status) => status != null && status < 500,
    ),
  );

  if ((response.statusCode ?? 0) >= 400) return null;
  final root = response.data;
  final data = _asJsonObject(root?['data']);
  final clip = _asJsonObject(data?['clip']);
  if (clip == null) return null;

  final broadcaster = _asJsonObject(clip['broadcaster']);
  final curator = _asJsonObject(clip['curator']);
  final game = _asJsonObject(clip['game']);
  final broadcasterName = _cleanPreviewText(
    broadcaster?['displayName']?.toString() ??
        broadcaster?['login']?.toString(),
  );
  final curatorName = _cleanPreviewText(
    curator?['displayName']?.toString() ?? curator?['login']?.toString(),
  );
  final gameName = _cleanPreviewText(game?['displayName']?.toString());
  final thumbnail = clip['thumbnailURL']?.toString().trim();

  final descriptionParts = <String>[
    ?broadcasterName,
    ?gameName,
    if (curatorName != null) '$curatorName 建立的片段',
  ];

  return TwitchChatLinkPreviewData(
    url: uri.toString(),
    kind: 'clip',
    host: uri.host.replaceFirst(RegExp(r'^www\.'), ''),
    title: _cleanPreviewText(clip['title']?.toString()) ?? 'Twitch 片段',
    description: descriptionParts.isEmpty
        ? prettyTwitchChatUrlLabel(uri.toString())
        : descriptionParts.join(' · '),
    imageUrl: thumbnail?.isEmpty == false ? thumbnail : null,
    siteName: 'Twitch 片段',
    author: broadcasterName,
  );
}

Map<String, dynamic>? _asJsonObject(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((key, value) => MapEntry(key.toString(), value));
  }
  return null;
}

String _detectPreviewKind(Uri uri) {
  final host = uri.host.toLowerCase();
  if (_parseTwitchClipLink(uri.toString()) != null) return 'clip';
  if (host == 'youtu.be' || host.endsWith('.youtube.com')) return 'youtube';
  final path = uri.path.toLowerCase();
  if (path.endsWith('.jpg') ||
      path.endsWith('.jpeg') ||
      path.endsWith('.png') ||
      path.endsWith('.webp') ||
      path.endsWith('.gif')) {
    return 'image';
  }
  return 'generic';
}

String? _parseYouTubeVideoId(Uri uri) {
  final host = uri.host.toLowerCase();
  final segments = uri.pathSegments
      .map((part) => part.trim())
      .where((part) => part.isNotEmpty)
      .toList(growable: false);

  String? candidate;
  if (host == 'youtu.be' && segments.isNotEmpty) {
    candidate = segments.first;
  } else if (host.endsWith('youtube.com')) {
    candidate = uri.queryParameters['v'];
    if (candidate == null && segments.length >= 2) {
      final mode = segments.first.toLowerCase();
      if (mode == 'shorts' ||
          mode == 'live' ||
          mode == 'embed' ||
          mode == 'v') {
        candidate = segments[1];
      }
    }
  }

  final id = candidate?.trim();
  if (id == null || id.length != 11) return null;
  if (!RegExp(r'^[A-Za-z0-9_-]{11}$').hasMatch(id)) return null;
  return id;
}

String? _readTitle(String html) {
  final match = RegExp(
    r'<title[^>]*>(.*?)<\/title>',
    caseSensitive: false,
    dotAll: true,
  ).firstMatch(html);
  return match?.group(1);
}

String? _readMeta(String html, List<String> names) {
  for (final name in names) {
    final escaped = RegExp.escape(name);
    final patterns = <RegExp>[
      RegExp(
        '<meta[^>]+(?:property|name)=["\\\']$escaped["\\\'][^>]+content=["\\\']([^"\\\']*)["\\\'][^>]*>',
        caseSensitive: false,
        dotAll: true,
      ),
      RegExp(
        '<meta[^>]+content=["\\\']([^"\\\']*)["\\\'][^>]+(?:property|name)=["\\\']$escaped["\\\'][^>]*>',
        caseSensitive: false,
        dotAll: true,
      ),
    ];
    for (final pattern in patterns) {
      final value = pattern.firstMatch(html)?.group(1);
      if (value != null && value.trim().isNotEmpty) return value;
    }
  }
  return null;
}

String? _cleanPreviewText(String? value) {
  final text = value
      ?.replaceAll(RegExp(r'\s+'), ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .trim();
  if (text == null || text.isEmpty) return null;
  return text;
}

Future<void> showTwitchChatLinkPreviewSheet(
  BuildContext context,
  String rawUrl,
) async {
  final uri = normalizeTwitchChatUri(rawUrl);
  if (uri == null) {
    await copyTwitchChatLink(context, rawUrl);
    return;
  }

  final displayUrl = uri.toString();
  await showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: const Color(0xFF141218),
    builder: (sheetContext) {
      return TwitchChatTextScope(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 6, 18, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: TwitchUiColors.primary.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: TwitchUiColors.primarySoft.withValues(
                          alpha: 0.3,
                        ),
                      ),
                    ),
                    child: const Icon(
                      Icons.link_rounded,
                      color: TwitchUiColors.primarySoft,
                      size: 21,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          uri.host.isEmpty ? '連結預覽' : uri.host,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          displayUrl,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: TwitchUiColors.textMuted,
                            fontSize: 12,
                            height: 1.25,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        Navigator.of(sheetContext).pop();
                        await copyTwitchChatLink(context, displayUrl);
                      },
                      icon: const Icon(Icons.copy_rounded),
                      label: const Text('複製'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () async {
                        Navigator.of(sheetContext).pop();
                        await openTwitchChatLink(context, displayUrl);
                      },
                      icon: const Icon(Icons.open_in_new_rounded),
                      label: const Text('開啟'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}

Future<void> openTwitchChatLink(BuildContext context, String rawUrl) async {
  final uri = normalizeTwitchChatUri(rawUrl);
  if (uri == null) {
    _showLinkSnack(context, '網址格式不正確');
    return;
  }

  final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!context.mounted) return;
  if (!opened) _showLinkSnack(context, '無法開啟連結');
}

Future<void> copyTwitchChatLink(BuildContext context, String rawUrl) async {
  final uri = normalizeTwitchChatUri(rawUrl);
  final text = uri?.toString() ?? rawUrl.trim();
  if (text.isEmpty) return;

  await Clipboard.setData(ClipboardData(text: text));
  if (!context.mounted) return;
  _showLinkSnack(context, '已複製連結');
}

void _showLinkSnack(BuildContext context, String message) {
  ScaffoldMessenger.maybeOf(context)?.showSnackBar(
    SnackBar(
      content: Text(message),
      duration: const Duration(milliseconds: 1200),
    ),
  );
}
