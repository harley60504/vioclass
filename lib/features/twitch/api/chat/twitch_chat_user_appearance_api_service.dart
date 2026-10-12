import 'package:dio/dio.dart';
import '../core/twitch_api_constants.dart';
import '../../models/chat/twitch_chat_badge.dart';
import '../../models/channel/twitch_user.dart';
import 'twitch_chat_user_external_badges_api_service.dart';

class TwitchChatUserAppearanceApiService {
  final Dio? client;
  const TwitchChatUserAppearanceApiService({this.client});

  static const _twitchQuery = r'''
    query VioClassProfileAppearance($login: String!, $room: String!) {
      user(login: $login) { id login displayName description createdAt
        profileImageURL(width: 150) offlineImageURL bannerImageURL chatColor
        displayBadges { setID version title imageURL(size: QUADRUPLE) }
      }
      own: channelViewer(userLogin: $login, channelLogin: $login) {
        earnedBadges { setID version title imageURL(size: QUADRUPLE) }
      }
      room: channelViewer(userLogin: $login, channelLogin: $room) {
        earnedBadges { setID version title imageURL(size: QUADRUPLE) }
      }
    }
  ''';
  static const _cosmeticsQuery = r'''
    query VioClassProfileCosmetics($id: String!) {
      users { userByConnection(platform: TWITCH, platformId: $id) {
        id style { activePaint { id } activeBadge { id }
          activeProfilePicture { images { url scale frameCount } }
        }
        inventory {
          badges { to { badge { id name description images { url scale frameCount } } } }
          paints { to { paint { id name data { layers { ty {
            ... on PaintLayerTypeSingleColor { color { hex } }
            ... on PaintLayerTypeLinearGradient { stops { at color { hex } } }
            ... on PaintLayerTypeRadialGradient { stops { at color { hex } } }
            ... on PaintLayerTypeImage { images { url scale frameCount } }
          } } } } } }
        }
      } }
    }
  ''';

  Future<TwitchChatUserAppearance?> load({
    required String login,
    required String channelLogin,
    required String userId,
    required bool Function() isCurrent,
  }) async {
    final validLogin = RegExp(r'^[a-z0-9_]{1,25}$');
    final name = login.toLowerCase().trim();
    final room = channelLogin.toLowerCase().trim();
    if (!validLogin.hasMatch(name) ||
        !RegExp(r'^\d+$').hasMatch(userId) ||
        !isCurrent()) {
      return null;
    }
    final http =
        client ??
        Dio(
          BaseOptions(
            connectTimeout: const Duration(seconds: 5),
            receiveTimeout: const Duration(seconds: 5),
            followRedirects: false,
          ),
        );
    Future<Map?> query(
      String endpoint,
      String query,
      Map<String, String> variables, {
      bool twitch = false,
    }) async {
      try {
        final response = await http
            .post<dynamic>(
              endpoint,
              data: {'query': query, 'variables': variables},
              options: Options(
                headers: twitch
                    ? {'Client-ID': TwitchApiConstants.twitchWebClientId}
                    : {},
              ),
            )
            .timeout(const Duration(seconds: 3));
        final json = response.data;
        return json is Map && json['data'] is Map ? json['data'] as Map : null;
      } catch (_) {
        return null;
      }
    }

    try {
      final parts = await Future.wait([
        query(TwitchApiConstants.gqlEndpoint, _twitchQuery, {
          'login': name,
          'room': validLogin.hasMatch(room) ? room : name,
        }, twitch: true),
        query('https://7tv.io/v4/gql', _cosmeticsQuery, {'id': userId}),
        TwitchChatUserExternalBadgesApiService.load(
          userId,
          http,
          cache: client == null,
        ),
      ]);
      if (!isCurrent()) return null;
      final candidate = parts[0]?['user'];
      final user =
          candidate is Map &&
              candidate['id']?.toString() == userId &&
              candidate['login']?.toString().toLowerCase() == name
          ? candidate
          : null;
      final cosmetics = _map(_map(parts[1]?['users'])?['userByConnection']);
      if (user == null && cosmetics == null) return null;
      final badges = <TwitchChatBadge>[];
      final seen = <String>{};
      for (final source in [
        user?['displayBadges'],
        _map(parts[0]?['own'])?['earnedBadges'],
        _map(parts[0]?['room'])?['earnedBadges'],
      ]) {
        if (user == null || source is! List) continue;
        for (final row in source.whereType<Map>()) {
          final set = row['setID']?.toString() ?? '';
          final version = row['version']?.toString() ?? '';
          final url = _url(row['imageURL']);
          if (set.isEmpty || !seen.add('$set/$version/$url')) continue;
          badges.add(
            _badge(
              'twitch-${badges.length}',
              set,
              version,
              row['title']?.toString() ?? set,
              url,
            ),
          );
        }
      }
      final inventory = _map(cosmetics?['inventory']);
      final thirdParty = <TwitchChatBadge>[];
      for (final entry in _list(inventory?['badges'])) {
        final badge = _map(_map(entry['to'])?['badge']);
        final id = badge?['id']?.toString() ?? '';
        if (id.isEmpty) continue;
        thirdParty.add(
          _badge(
            '7tv-$id',
            '7tv',
            id,
            badge?['name']?.toString() ?? '7TV',
            _image(badge?['images']),
          ),
        );
      }
      final activePaint = _map(
        _map(cosmetics?['style'])?['activePaint'],
      )?['id'];
      final paints = <TwitchChatNamePaint>[];
      for (final entry in _list(inventory?['paints'])) {
        final paint = _map(_map(entry['to'])?['paint']);
        final id = paint?['id']?.toString() ?? '';
        if (id.isEmpty) continue;
        final colors = <String>[];
        var image = '';
        for (final layer in _list(_map(paint?['data'])?['layers'])) {
          final type = _map(layer['ty']);
          final hex = _map(type?['color'])?['hex'];
          if (hex is String) colors.add(hex);
          for (final stop in _list(type?['stops'])) {
            final hex = _map(stop['color'])?['hex'];
            if (hex is String) colors.add(hex);
          }
          final url = _image(type?['images']);
          if (url.isNotEmpty) image = url;
        }
        paints.add(
          TwitchChatNamePaint(
            id: id,
            name: paint?['name']?.toString() ?? id,
            active: id == activePaint,
            colors: colors,
            imageUrl: image,
          ),
        );
      }
      return TwitchChatUserAppearance(
        user: user == null
            ? null
            : TwitchUser.fromGqlUserJson(Map<String, dynamic>.from(user)),
        bannerUrl: _url(user?['bannerImageURL']),
        externalBadges: Map<String, List<TwitchChatBadge>>.from(
          parts[2] as Map,
        ),
        chatColor: user?['chatColor']?.toString() ?? '',
        earnedBadges: badges,
        sevenTvBadges: thirdParty,
        paints: paints,
        sevenTvAvatar: _image(
          _map(_map(cosmetics?['style'])?['activeProfilePicture'])?['images'],
        ),
      );
    } finally {
      if (client == null) http.close(force: true);
    }
  }

  static Map? _map(dynamic value) => value is Map ? value : null;
  static Iterable<Map> _list(dynamic value) =>
      value is List ? value.whereType<Map>() : const [];
  static String _url(dynamic value) {
    var text = value?.toString() ?? '';
    if (text.startsWith('//')) text = 'https:$text';
    final uri = Uri.tryParse(text);
    return uri?.scheme == 'https' && uri!.host.isNotEmpty ? text : '';
  }

  static String _image(dynamic value) {
    final images = _list(value).toList();
    images.sort(
      (a, b) => ((a['frameCount'] == 1 ? 0 : 1)).compareTo(
        b['frameCount'] == 1 ? 0 : 1,
      ),
    );
    for (final image in images) {
      final url = _url(image['url']);
      if (url.isNotEmpty) return url;
    }
    return '';
  }

  static TwitchChatBadge _badge(
    String id,
    String set,
    String version,
    String title,
    String image,
  ) => TwitchChatBadge(
    id: id,
    setId: set,
    version: version,
    title: title,
    image1x: image,
    image2x: image,
    image4x: image,
    clickAction: '',
    clickUrl: '',
  );
}

class TwitchChatUserAppearance {
  final TwitchUser? user;
  final String bannerUrl;
  final String chatColor;
  final String sevenTvAvatar;
  final List<TwitchChatBadge> earnedBadges;
  final List<TwitchChatBadge> sevenTvBadges;
  final List<TwitchChatNamePaint> paints;
  final Map<String, List<TwitchChatBadge>> externalBadges;
  const TwitchChatUserAppearance({
    this.user,
    this.bannerUrl = '',
    this.chatColor = '',
    this.sevenTvAvatar = '',
    this.earnedBadges = const [],
    this.sevenTvBadges = const [],
    this.paints = const [],
    this.externalBadges = const {},
  });
}

class TwitchChatNamePaint {
  final String id;
  final String name;
  final bool active;
  final List<String> colors;
  final String imageUrl;
  const TwitchChatNamePaint({
    required this.id,
    required this.name,
    this.active = false,
    this.colors = const [],
    this.imageUrl = '',
  });
}
