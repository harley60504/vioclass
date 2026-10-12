import 'package:dio/dio.dart';
import '../../models/channel/twitch_user.dart';

/// Public IVR metadata. Deliberately uses a separate anonymous client, never
/// the Twitch client with its authentication headers or interceptors.
class TwitchChatUserPublicProfileApiService {
  final Dio? client;
  const TwitchChatUserPublicProfileApiService({this.client});

  Future<TwitchChatUserPublicProfile?> load({
    required String login,
    required String channelLogin,
    required bool Function() isCurrent,
    String? userId,
  }) async {
    final name = login.trim().toLowerCase();
    final channel = channelLogin.trim().toLowerCase();
    final valid = RegExp(r'^[a-z0-9_]{1,25}$');
    if (!valid.hasMatch(name) || !valid.hasMatch(channel) || !isCurrent()) {
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
    Future<dynamic> read(String path, {Map<String, dynamic>? query}) async {
      try {
        return (await http
                .get<dynamic>(
                  'https://api.ivr.fi/v2/twitch/$path',
                  queryParameters: query,
                )
                .timeout(const Duration(seconds: 3)))
            .data;
      } catch (_) {
        return null;
      }
    }

    try {
      final results = await Future.wait([
        read('user', query: {'login': name}),
        read('subage/$name/$channel'),
        read('modvip/$channel', query: {'login': name}),
      ]);
      if (!isCurrent()) return null;
      Map? user;
      if (results[0] is List &&
          (results[0] as List).isNotEmpty &&
          (results[0] as List).first is Map) {
        final candidate = (results[0] as List).first as Map;
        if (candidate['login']?.toString().toLowerCase() == name &&
            (userId == null ||
                userId.isEmpty ||
                candidate['id']?.toString() == userId)) {
          user = candidate;
        }
      }
      final sub = results[1] is Map ? results[1] as Map : null;
      final modVip = results[2] is List
          ? (results[2] as List)
                .whereType<Map>()
                .where((row) => row['login']?.toString().toLowerCase() == name)
                .firstOrNull
          : results[2] is Map
          ? results[2] as Map
          : null;
      if (user == null && sub == null && modVip == null) return null;
      DateTime? date(dynamic value) =>
          DateTime.tryParse(value?.toString() ?? '');
      int? months(dynamic block) {
        final value = block is Map
            ? int.tryParse(block['months']?.toString() ?? '')
            : null;
        return value != null && value > 0 ? value : null;
      }

      final last = user?['lastBroadcast'];
      final meta = sub?['meta'] is Map ? sub!['meta'] as Map : null;
      final giver = meta?['giver'] is Map
          ? meta!['giver'] as Map
          : meta?['giftMeta'] is Map
          ? meta!['giftMeta'] as Map
          : null;
      int? count(dynamic value) => int.tryParse(value?.toString() ?? '');
      return TwitchChatUserPublicProfile(
        user: user == null
            ? null
            : TwitchUser(
                id: user['id']?.toString() ?? '',
                login: name,
                displayName: user['displayName']?.toString() ?? name,
                description: user['description']?.toString() ?? '',
                profileImageUrl: user['logo']?.toString() ?? '',
                broadcasterType:
                    user['roles'] is Map && user['roles']['isPartner'] == true
                    ? 'partner'
                    : user['roles'] is Map &&
                          user['roles']['isAffiliate'] == true
                    ? 'affiliate'
                    : '',
                createdAt: date(user['createdAt']),
              ),
        followedAt: date(sub?['followedAt']),
        followHidden: sub?['statusHidden'] == true,
        // A missing public date is not proof that this person does not follow.
        followKnown: date(sub?['followedAt']) != null,
        cumulativeMonths: months(sub?['cumulative']),
        streakMonths: months(sub?['streak']),
        subscribed: sub?['subscriber'] is bool
            ? sub!['subscriber'] as bool
            : meta?['type'] is String
            ? true
            : null,
        lastBroadcastAt: last is Map ? date(last['startedAt']) : null,
        followers: count(user?['followers']),
        follows: count(user?['follows']),
        chatterCount: count(user?['chatterCount']),
        banned: user?['banned'] == true,
        founder: sub?['founder'] == true,
        modSince: modVip?['isMod'] == true
            ? date(modVip?['modGrantedAt'])
            : null,
        vipSince: modVip?['isVip'] == true
            ? date(modVip?['vipGrantedAt'])
            : null,
        subscriptionTier: meta?['tier']?.toString(),
        subscriptionType: meta?['type']?.toString(),
        giftFrom:
            giver?['displayName']?.toString() ?? giver?['login']?.toString(),
      );
    } finally {
      if (client == null) http.close(force: true);
    }
  }
}

class TwitchChatUserPublicProfile {
  final TwitchUser? user;
  final DateTime? followedAt;
  final bool followHidden;
  final bool followKnown;
  final int? cumulativeMonths;
  final int? streakMonths;
  final bool? subscribed;
  final DateTime? lastBroadcastAt;
  final int? followers;
  final int? follows;
  final int? chatterCount;
  final bool banned;
  final bool founder;
  final DateTime? modSince;
  final DateTime? vipSince;
  final String? subscriptionTier;
  final String? subscriptionType;
  final String? giftFrom;
  const TwitchChatUserPublicProfile({
    this.user,
    this.followedAt,
    this.followHidden = false,
    this.followKnown = false,
    this.cumulativeMonths,
    this.streakMonths,
    this.subscribed,
    this.lastBroadcastAt,
    this.followers,
    this.follows,
    this.chatterCount,
    this.banned = false,
    this.founder = false,
    this.modSince,
    this.vipSince,
    this.subscriptionTier,
    this.subscriptionType,
    this.giftFrom,
  });
}
