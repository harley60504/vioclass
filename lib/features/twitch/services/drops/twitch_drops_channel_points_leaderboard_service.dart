import 'package:dio/dio.dart';

import '../../api/auth/twitch_auth_api_service.dart';
import '../../api/core/twitch_api_client.dart';
import '../../api/core/twitch_api_constants.dart';
import '../auth/twitch_auth_service.dart';
import '../auth/twitch_drops_auth_service.dart';
import '../discovery/twitch_discovery_service.dart';

class TwitchDropsChannelPointsLeaderboardService {
  static const int _batchSize = 35;
  static const Duration _cacheDuration = Duration(seconds: 30);
  static const String _channelPointsContextQuery = r'''
query ChannelPointsContext($channelLogin: String!) {
  user(login: $channelLogin) {
    channel {
      self {
        communityPoints {
          balance
        }
      }
    }
  }
}
''';

  static DateTime? _cachedAt;
  static List<TwitchDropsChannelPointsLeaderboardEntry> _cachedEntries =
      const <TwitchDropsChannelPointsLeaderboardEntry>[];

  final TwitchDiscoveryService discoveryService;
  final TwitchApiClient apiClient;
  final TwitchDropsAuthService dropsAuthService;

  const TwitchDropsChannelPointsLeaderboardService({
    required this.discoveryService,
    required this.apiClient,
    required this.dropsAuthService,
  });

  factory TwitchDropsChannelPointsLeaderboardService.create({
    required TwitchApiClient apiClient,
    required TwitchAuthService authService,
    required TwitchAuthApiService authApi,
    required TwitchDropsAuthService dropsAuthService,
  }) {
    return TwitchDropsChannelPointsLeaderboardService(
      discoveryService: TwitchDiscoveryService(
        client: apiClient,
        authService: authService,
        authApi: authApi,
      ),
      apiClient: apiClient,
      dropsAuthService: dropsAuthService,
    );
  }

  Future<List<TwitchDropsChannelPointsLeaderboardEntry>> load({
    int followedLimit = 100,
    int balanceLimit = 100,
    bool force = false,
  }) async {
    final cachedAt = _cachedAt;
    if (!force &&
        cachedAt != null &&
        DateTime.now().difference(cachedAt) < _cacheDuration) {
      return _cachedEntries;
    }

    final followed = await discoveryService.fetchFollowedChannels(
      first: followedLimit.clamp(1, 100),
      attachProfiles: true,
    );

    await dropsAuthService.loadStoredSession();
    final token = await dropsAuthService.getToken();
    final clientId = dropsAuthService.dropsClientId.trim();
    if (token == null || token.trim().isEmpty || clientId.isEmpty) {
      return const <TwitchDropsChannelPointsLeaderboardEntry>[];
    }

    final entries = <TwitchDropsChannelPointsLeaderboardEntry>[];
    final channels = followed.channels
        .take(balanceLimit.clamp(1, 100))
        .toList();
    for (final chunk in _chunks(channels, _batchSize)) {
      try {
        final response = await apiClient.dio.post<dynamic>(
          TwitchApiConstants.gqlEndpoint,
          data: <Map<String, Object?>>[
            for (final channel in chunk)
              <String, Object?>{
                'operationName': 'ChannelPointsContext',
                'query': _channelPointsContextQuery,
                'variables': <String, String>{
                  'channelLogin': channel.channelLogin,
                },
              },
          ],
          options: Options(
            responseType: ResponseType.json,
            validateStatus: (status) => status != null && status < 500,
            headers: <String, String>{
              ...TwitchApiConstants.twitchWebHeaders,
              'Client-ID': clientId,
              'Content-Type': 'application/json',
              'Authorization': 'OAuth ${token.trim()}',
            },
          ),
        );

        final data = response.data;
        if (data is! List) continue;

        for (var i = 0; i < chunk.length && i < data.length; i++) {
          final balance = _readBalance(data[i]);
          if (balance == null || balance <= 0) continue;
          final channel = chunk[i];
          entries.add(
            TwitchDropsChannelPointsLeaderboardEntry(
              rank: 0,
              channelLogin: channel.channelLogin,
              displayName: channel.displayName,
              profileImageUrl: channel.profileImageUrl,
              points: balance,
            ),
          );
        }
      } catch (_) {
        // Some followed channels do not expose a usable ChannelPointsContext.
      }
    }

    entries.sort((a, b) => b.points.compareTo(a.points));
    final ranked = <TwitchDropsChannelPointsLeaderboardEntry>[
      for (var i = 0; i < entries.length; i++) entries[i].copyWith(rank: i + 1),
    ];
    _cachedEntries = ranked;
    _cachedAt = DateTime.now();
    return ranked;
  }

  static Iterable<List<T>> _chunks<T>(List<T> values, int size) sync* {
    for (var i = 0; i < values.length; i += size) {
      final end = i + size > values.length ? values.length : i + size;
      yield values.sublist(i, end);
    }
  }

  static int? _readBalance(Object? raw) {
    return _readInt(
      _readPath(raw, const <String>[
        'data',
        'user',
        'channel',
        'self',
        'communityPoints',
        'balance',
      ]),
    );
  }

  static Object? _readPath(Object? raw, List<String> path) {
    Object? current = raw;
    for (final key in path) {
      if (current is! Map) return null;
      current = current[key];
    }
    return current;
  }

  static int? _readInt(Object? raw) {
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    if (raw is String) return int.tryParse(raw);
    return null;
  }
}

class TwitchDropsChannelPointsLeaderboardEntry {
  final int rank;
  final String channelLogin;
  final String displayName;
  final String profileImageUrl;
  final int points;

  const TwitchDropsChannelPointsLeaderboardEntry({
    required this.rank,
    required this.channelLogin,
    required this.displayName,
    required this.profileImageUrl,
    required this.points,
  });

  TwitchDropsChannelPointsLeaderboardEntry copyWith({int? rank}) {
    return TwitchDropsChannelPointsLeaderboardEntry(
      rank: rank ?? this.rank,
      channelLogin: channelLogin,
      displayName: displayName,
      profileImageUrl: profileImageUrl,
      points: points,
    );
  }
}
