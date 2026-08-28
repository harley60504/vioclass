import 'twitch_chat_link_preview_models.dart';

final RegExp twitchChatUrlRegex = RegExp(
  r'(https?:\/\/[^\s]+|www\.[^\s]+)',
  caseSensitive: false,
);

const List<String> _defaultTrustedPreviewDomains = <String>[
  'youtube.com',
  'youtu.be',
  'twitch.tv',
  'twitter.com',
  'x.com',
  'imgur.com',
  'giphy.com',
  'gph.is',
  'tenor.com',
  'reddit.com',
  'redd.it',
  'github.com',
  'streamable.com',
  'kick.com',
  'spotify.com',
  'soundcloud.com',
  'tiktok.com',
  'discord.gg',
  'discord.com',
  'discordapp.com',
  'steampowered.com',
  'steamcommunity.com',
  'instagram.com',
  'bsky.app',
  'vimeo.com',
  'bandcamp.com',
];

bool _chatLinkPreviewsEnabled = true;
List<String> _customTrustedPreviewDomains = const <String>[];

void configureTwitchChatLinkPreviews({
  required bool enabled,
  required List<String> trustedDomains,
}) {
  _chatLinkPreviewsEnabled = enabled;
  _customTrustedPreviewDomains = trustedDomains
      .map(normalizeTwitchChatPreviewDomain)
      .where((domain) => domain.isNotEmpty)
      .toSet()
      .toList(growable: false);
}

List<TwitchChatTextPart> splitTwitchChatLinks(String text) {
  if (text.isEmpty) return const <TwitchChatTextPart>[];

  final parts = <TwitchChatTextPart>[];
  var cursor = 0;
  for (final match in twitchChatUrlRegex.allMatches(text)) {
    if (match.start > cursor) {
      parts.add(
        TwitchChatTextPart(
          text: text.substring(cursor, match.start),
          isLink: false,
        ),
      );
    }

    parts.add(TwitchChatTextPart(text: match.group(0) ?? '', isLink: true));
    cursor = match.end;
  }

  if (cursor < text.length) {
    parts.add(TwitchChatTextPart(text: text.substring(cursor), isLink: false));
  }
  return parts;
}

List<TwitchChatPreviewUrl> extractTwitchChatPreviewUrls(
  String text, {
  int max = 2,
}) {
  if (!_chatLinkPreviewsEnabled) return const <TwitchChatPreviewUrl>[];
  if (text.isEmpty || (!text.contains('http') && !text.contains('www.'))) {
    return const <TwitchChatPreviewUrl>[];
  }

  final output = <TwitchChatPreviewUrl>[];
  final seen = <String>{};
  for (final match in twitchChatUrlRegex.allMatches(text)) {
    if (output.length >= max) break;
    final uri = normalizeTwitchChatUri(match.group(0) ?? '');
    if (uri == null) continue;

    final url = uri.toString();
    if (!seen.add(url)) continue;
    output.add(
      TwitchChatPreviewUrl(url: url, trusted: isTrustedTwitchChatUri(uri)),
    );
  }
  return output;
}

bool isTrustedTwitchChatUri(Uri uri) {
  final scheme = uri.scheme.toLowerCase();
  final host = uri.host.toLowerCase();
  if ((scheme != 'http' && scheme != 'https') || _isUnsafePreviewHost(host)) {
    return false;
  }
  return _isPreviewAllowedHost(host);
}

String normalizeTwitchChatPreviewDomain(String value) {
  var text = value.trim().toLowerCase();
  if (text.isEmpty) return '';
  if (!text.contains('://')) text = 'https://$text';

  final uri = Uri.tryParse(text);
  final host = uri?.host.trim().toLowerCase() ?? '';
  if (host.isEmpty || _isUnsafePreviewHost(host)) return '';
  return host.replaceFirst(RegExp(r'^www\.'), '');
}

String prettyTwitchChatUrlLabel(String rawUrl, {int maxLength = 44}) {
  final uri = normalizeTwitchChatUri(rawUrl);
  if (uri == null) {
    return rawUrl.length > maxLength
        ? '${rawUrl.substring(0, maxLength - 1)}...'
        : rawUrl;
  }

  final host = uri.host.replaceFirst(RegExp(r'^www\.'), '');
  final rest =
      (uri.path == '/' ? '' : uri.path) +
      (uri.hasQuery ? '?${uri.query}' : '') +
      (uri.hasFragment ? '#${uri.fragment}' : '');
  final full = '$host$rest';
  if (full.length <= maxLength) return full;

  final room = (maxLength - host.length - 3).clamp(0, maxLength);
  return '$host${rest.substring(0, room)}...';
}

Uri? normalizeTwitchChatUri(String rawUrl) {
  var text = rawUrl.trim();
  while (text.endsWith('.') ||
      text.endsWith(',') ||
      text.endsWith('!') ||
      text.endsWith('?') ||
      text.endsWith(')') ||
      text.endsWith(']')) {
    text = text.substring(0, text.length - 1).trimRight();
  }
  if (text.isEmpty) return null;
  if (text.startsWith('www.')) {
    text = 'https://$text';
  }

  final uri = Uri.tryParse(text);
  if (uri == null) return null;
  final scheme = uri.scheme.toLowerCase();
  if (scheme != 'http' && scheme != 'https') return null;
  return uri;
}

bool _isPreviewAllowedHost(String host) {
  final domains = <String>[
    ..._defaultTrustedPreviewDomains,
    ..._customTrustedPreviewDomains,
  ];
  return domains.any((base) {
    return host == base || host.endsWith('.$base');
  });
}

bool _isUnsafePreviewHost(String rawHost) {
  final host = rawHost.trim().toLowerCase();
  if (host.isEmpty || host == 'localhost') return true;
  if (host == '::1' || host == '[::1]') return true;
  if (host.endsWith('.local') || host.endsWith('.localhost')) return true;

  final ipv4 = RegExp(r'^(\d{1,3}\.){3}\d{1,3}$');
  if (!ipv4.hasMatch(host)) return false;

  final parts = host.split('.').map(int.tryParse).toList(growable: false);
  if (parts.any((part) => part == null || part < 0 || part > 255)) return true;
  final a = parts[0]!;
  final b = parts[1]!;
  return a == 0 ||
      a == 10 ||
      a == 127 ||
      (a == 169 && b == 254) ||
      (a == 172 && b >= 16 && b <= 31) ||
      (a == 192 && b == 168);
}
