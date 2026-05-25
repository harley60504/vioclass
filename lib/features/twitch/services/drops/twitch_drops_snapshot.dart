class TwitchDropsSnapshot {
  final String viewerId;
  final String viewerLogin;
  final List<TwitchDropCampaign> inventoryCampaigns;
  final List<TwitchDropCampaignSummary> activeCampaigns;

  const TwitchDropsSnapshot({
    required this.viewerId,
    required this.viewerLogin,
    required this.inventoryCampaigns,
    required this.activeCampaigns,
  });

  factory TwitchDropsSnapshot.fromResponses({
    required Object? inventoryResponse,
    required Object? campaignsResponse,
  }) {
    final inventoryUser = _currentUser(inventoryResponse);
    final campaignsUser = _currentUser(campaignsResponse);

    final inventory = _asMap(inventoryUser?['inventory']);
    final rawInventoryCampaigns = _asList(
      inventory?['dropCampaignsInProgress'],
    );
    final rawActiveCampaigns = _asList(campaignsUser?['dropCampaigns']);

    final activeCampaigns = rawActiveCampaigns
        .whereType<Map>()
        .map(TwitchDropCampaignSummary.fromJson)
        .where((campaign) => campaign.id.isNotEmpty)
        .toList(growable: false);
    final activeById = <String, TwitchDropCampaignSummary>{
      for (final campaign in activeCampaigns) campaign.id: campaign,
    };

    return TwitchDropsSnapshot(
      viewerId: _string(inventoryUser?['id']).isNotEmpty
          ? _string(inventoryUser?['id'])
          : _string(campaignsUser?['id']),
      viewerLogin: _string(campaignsUser?['login']),
      inventoryCampaigns: rawInventoryCampaigns
          .whereType<Map>()
          .map((raw) {
            final campaign = TwitchDropCampaign.fromJson(raw);
            final active = activeById[campaign.id];
            if (active == null ||
                active.imageUrl.isEmpty ||
                campaign.imageUrl.isNotEmpty) {
              return campaign;
            }
            return campaign.copyWith(imageUrl: active.imageUrl);
          })
          .where((campaign) => campaign.id.isNotEmpty)
          .toList(growable: false),
      activeCampaigns: activeCampaigns,
    );
  }

  List<TwitchDrop> get allDrops {
    return inventoryCampaigns
        .expand((campaign) => campaign.timeBasedDrops)
        .toList(growable: false);
  }

  List<TwitchDrop> get readyDrops {
    return allDrops
        .where((drop) => drop.readyToCollect)
        .toList(growable: false);
  }

  List<TwitchDrop> get watchingDrops {
    return allDrops
        .where((drop) => !drop.isClaimed && !drop.readyToCollect)
        .toList(growable: false);
  }

  int get inventoryCampaignCount => inventoryCampaigns.length;
  int get activeCampaignCount => activeCampaigns.length;
  int get totalDropCount => allDrops.length;
  int get readyDropCount => readyDrops.length;
  int get watchingDropCount => watchingDrops.length;

  int get linkedCampaignCount {
    return inventoryCampaigns
        .where((campaign) => campaign.isAccountConnected)
        .length;
  }

  int get unlinkedCampaignCount {
    return inventoryCampaigns
        .where((campaign) => !campaign.isAccountConnected)
        .length;
  }

  bool get hasReadyDrops => readyDropCount > 0;

  String get compactSummary {
    return <String>[
      'inventoryCampaigns=$inventoryCampaignCount',
      'activeCampaigns=$activeCampaignCount',
      'drops=$totalDropCount',
      'ready=$readyDropCount',
      'watching=$watchingDropCount',
      'linked=$linkedCampaignCount',
      'unlinked=$unlinkedCampaignCount',
    ].join('\n');
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'viewerId': viewerId,
      'viewerLogin': viewerLogin,
      'inventoryCampaignCount': inventoryCampaignCount,
      'activeCampaignCount': activeCampaignCount,
      'totalDropCount': totalDropCount,
      'readyDropCount': readyDropCount,
      'watchingDropCount': watchingDropCount,
      'linkedCampaignCount': linkedCampaignCount,
      'unlinkedCampaignCount': unlinkedCampaignCount,
      'readyDrops': readyDrops.map((drop) => drop.toJson()).toList(),
      'inventoryCampaigns': inventoryCampaigns
          .map((campaign) => campaign.toJson())
          .toList(),
    };
  }

  static Map? _currentUser(Object? response) {
    final root = _asMap(response);
    final data = _asMap(root?['data']);
    return _asMap(data?['currentUser']);
  }
}

class TwitchDropCampaign {
  final String id;
  final String name;
  final String status;
  final String gameName;
  final String gameId;
  final String imageUrl;
  final String detailsUrl;
  final String accountLinkUrl;
  final DateTime? startAt;
  final DateTime? endAt;
  final bool isAccountConnected;
  final List<TwitchDrop> timeBasedDrops;

  const TwitchDropCampaign({
    required this.id,
    required this.name,
    required this.status,
    required this.gameName,
    required this.gameId,
    required this.imageUrl,
    required this.detailsUrl,
    required this.accountLinkUrl,
    required this.startAt,
    required this.endAt,
    required this.isAccountConnected,
    required this.timeBasedDrops,
  });

  factory TwitchDropCampaign.fromJson(Map raw) {
    final self = _asMap(raw['self']);
    final game = _asMap(raw['game']);
    final drops = _asList(raw['timeBasedDrops']);

    final campaign = TwitchDropCampaign(
      id: _string(raw['id']),
      name: _string(raw['name']),
      status: _string(raw['status']),
      gameName: _string(game?['name']).isNotEmpty
          ? _string(game?['name'])
          : _string(game?['displayName']),
      gameId: _string(game?['id']),
      imageUrl: _campaignDisplayImageUrl(raw: raw, game: game),
      detailsUrl: _string(raw['detailsURL']),
      accountLinkUrl: _string(raw['accountLinkURL']),
      startAt: _date(raw['startAt']),
      endAt: _date(raw['endAt']),
      isAccountConnected: self?['isAccountConnected'] == true,
      timeBasedDrops: const <TwitchDrop>[],
    );

    return campaign.copyWith(
      timeBasedDrops: drops
          .whereType<Map>()
          .map(
            (drop) => TwitchDrop.fromJson(
              drop,
              campaignId: campaign.id,
              campaignName: campaign.name,
              gameName: campaign.gameName,
              accountConnected: campaign.isAccountConnected,
            ),
          )
          .where((drop) => drop.id.isNotEmpty)
          .toList(growable: false),
    );
  }

  TwitchDropCampaign copyWith({
    String? imageUrl,
    List<TwitchDrop>? timeBasedDrops,
  }) {
    return TwitchDropCampaign(
      id: id,
      name: name,
      status: status,
      gameName: gameName,
      gameId: gameId,
      imageUrl: imageUrl ?? this.imageUrl,
      detailsUrl: detailsUrl,
      accountLinkUrl: accountLinkUrl,
      startAt: startAt,
      endAt: endAt,
      isAccountConnected: isAccountConnected,
      timeBasedDrops: timeBasedDrops ?? this.timeBasedDrops,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'status': status,
      'gameName': gameName,
      'gameId': gameId,
      'imageUrl': imageUrl,
      'detailsUrl': detailsUrl,
      'accountLinkUrl': accountLinkUrl,
      'startAt': startAt?.toIso8601String(),
      'endAt': endAt?.toIso8601String(),
      'isAccountConnected': isAccountConnected,
      'timeBasedDrops': timeBasedDrops.map((drop) => drop.toJson()).toList(),
    };
  }
}

class TwitchDrop {
  final String id;
  final String campaignId;
  final String campaignName;
  final String gameName;
  final String name;
  final String rewardName;
  final String rewardImageUrl;
  final int requiredMinutesWatched;
  final int currentMinutesWatched;
  final bool isClaimed;
  final bool hasPreconditionsMet;
  final bool accountConnected;
  final String dropInstanceId;
  final DateTime? startAt;
  final DateTime? endAt;

  const TwitchDrop({
    required this.id,
    required this.campaignId,
    required this.campaignName,
    required this.gameName,
    required this.name,
    required this.rewardName,
    required this.rewardImageUrl,
    required this.requiredMinutesWatched,
    required this.currentMinutesWatched,
    required this.isClaimed,
    required this.hasPreconditionsMet,
    required this.accountConnected,
    required this.dropInstanceId,
    required this.startAt,
    required this.endAt,
  });

  factory TwitchDrop.fromJson(
    Map raw, {
    required String campaignId,
    required String campaignName,
    required String gameName,
    required bool accountConnected,
  }) {
    final self = _asMap(raw['self']);
    final benefitEdges = _asList(raw['benefitEdges']);
    final firstBenefitEdge = benefitEdges.whereType<Map>().isNotEmpty
        ? benefitEdges.whereType<Map>().first
        : null;
    final benefit = _asMap(firstBenefitEdge?['benefit']);

    return TwitchDrop(
      id: _string(raw['id']),
      campaignId: campaignId,
      campaignName: campaignName,
      gameName: gameName,
      name: _string(raw['name']),
      rewardName: _string(benefit?['name']),
      rewardImageUrl: _string(benefit?['imageAssetURL']),
      requiredMinutesWatched: _int(raw['requiredMinutesWatched']),
      currentMinutesWatched: _int(self?['currentMinutesWatched']),
      isClaimed: self?['isClaimed'] == true,
      hasPreconditionsMet: self?['hasPreconditionsMet'] != false,
      accountConnected: accountConnected,
      dropInstanceId: _string(self?['dropInstanceID']),
      startAt: _date(raw['startAt']),
      endAt: _date(raw['endAt']),
    );
  }

  int get remainingMinutes {
    final remaining = requiredMinutesWatched - currentMinutesWatched;
    return remaining < 0 ? 0 : remaining;
  }

  double get progressRatio {
    if (requiredMinutesWatched <= 0) return 0.0;
    final ratio = currentMinutesWatched / requiredMinutesWatched;
    return ratio.clamp(0.0, 1.0).toDouble();
  }

  int get progressPercent {
    return (progressRatio * 100).round().clamp(0, 100);
  }

  bool get progressComplete {
    return requiredMinutesWatched > 0 &&
        currentMinutesWatched >= requiredMinutesWatched;
  }

  bool get readyToCollect {
    return !isClaimed && dropInstanceId.trim().isNotEmpty;
  }

  String get displayRewardName {
    if (rewardName.trim().isNotEmpty) return rewardName.trim();
    if (name.trim().isNotEmpty) return name.trim();
    return 'Unknown Drop';
  }

  String get statusLabel {
    if (isClaimed) return '已領取';
    if (readyToCollect) return '可領取';
    if (!hasPreconditionsMet) return '前置條件未完成';
    if (!accountConnected) return '帳號未連結';
    return '$progressPercent%｜剩餘 $remainingMinutes 分鐘';
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'campaignId': campaignId,
      'campaignName': campaignName,
      'gameName': gameName,
      'name': name,
      'rewardName': rewardName,
      'rewardImageUrl': rewardImageUrl,
      'requiredMinutesWatched': requiredMinutesWatched,
      'currentMinutesWatched': currentMinutesWatched,
      'progressPercent': progressPercent,
      'remainingMinutes': remainingMinutes,
      'isClaimed': isClaimed,
      'readyToCollect': readyToCollect,
      'hasPreconditionsMet': hasPreconditionsMet,
      'accountConnected': accountConnected,
      'dropInstanceId': dropInstanceId,
      'statusLabel': statusLabel,
    };
  }
}

class TwitchDropCampaignSummary {
  final String id;
  final String name;
  final String status;
  final String gameName;
  final String gameId;
  final String imageUrl;
  final String detailsUrl;
  final String accountLinkUrl;
  final DateTime? startAt;
  final DateTime? endAt;
  final bool isAccountConnected;

  const TwitchDropCampaignSummary({
    required this.id,
    required this.name,
    required this.status,
    required this.gameName,
    required this.gameId,
    required this.imageUrl,
    required this.detailsUrl,
    required this.accountLinkUrl,
    required this.startAt,
    required this.endAt,
    required this.isAccountConnected,
  });

  factory TwitchDropCampaignSummary.fromJson(Map raw) {
    final self = _asMap(raw['self']);
    final game = _asMap(raw['game']);

    return TwitchDropCampaignSummary(
      id: _string(raw['id']),
      name: _string(raw['name']),
      status: _string(raw['status']),
      gameName: _string(game?['displayName']).isNotEmpty
          ? _string(game?['displayName'])
          : _string(game?['name']),
      gameId: _string(game?['id']),
      imageUrl: _campaignDisplayImageUrl(raw: raw, game: game),
      detailsUrl: _string(raw['detailsURL']),
      accountLinkUrl: _string(raw['accountLinkURL']),
      startAt: _date(raw['startAt']),
      endAt: _date(raw['endAt']),
      isAccountConnected: self?['isAccountConnected'] == true,
    );
  }
}

String _campaignDisplayImageUrl({required Map raw, required Map? game}) {
  return _firstNonEmptyString(<String>[
    _twitchImageUrl(_string(game?['boxArtURL']), width: 144, height: 192),
    _twitchImageUrl(_string(game?['boxArtUrl']), width: 144, height: 192),
    _twitchImageUrl(_string(game?['box_art_url']), width: 144, height: 192),
    _twitchImageUrl(_string(raw['boxArtURL']), width: 144, height: 192),
    _twitchImageUrl(_string(raw['boxArtUrl']), width: 144, height: 192),
    _twitchImageUrl(_string(raw['imageURL']), width: 144, height: 192),
    _twitchImageUrl(_string(raw['imageUrl']), width: 144, height: 192),
    _twitchImageUrl(_string(raw['image_url']), width: 144, height: 192),
  ]);
}

String _twitchImageUrl(String raw, {required int width, required int height}) {
  var text = raw.trim();
  if (text.isEmpty) return '';
  text = text.replaceAll('{width}', width.toString());
  text = text.replaceAll('{height}', height.toString());
  return text;
}

String _firstNonEmptyString(List<String> values) {
  for (final value in values) {
    final text = value.trim();
    if (text.isNotEmpty) return text;
  }
  return '';
}

Map? _asMap(Object? value) {
  return value is Map ? value : null;
}

List _asList(Object? value) {
  return value is List ? value : const [];
}

String _string(Object? value) {
  return value?.toString().trim() ?? '';
}

int _int(Object? value) {
  if (value is int) return value;
  if (value is num) return value.round();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

DateTime? _date(Object? value) {
  final text = _string(value);
  if (text.isEmpty) return null;
  return DateTime.tryParse(text);
}
