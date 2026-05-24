enum TwitchViewerSpecialMessageAvailability {
  unknown,
  unavailable,
  available,
  sent,
  failed,
}

class TwitchViewerSpecialMessageBackendIssue {
  final String area;
  final String message;
  final Object? raw;

  const TwitchViewerSpecialMessageBackendIssue({
    required this.area,
    required this.message,
    this.raw,
  });

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'area': area,
      'message': message,
      if (raw != null) 'raw': raw.toString(),
    };
  }
}

class TwitchWatchStreakStatusStage251 {
  final String channelLogin;
  final String? channelId;
  final int? streakCount;
  final String unitLabel;
  final bool canShare;
  final String? shareToken;
  final String? title;
  final String? description;
  final dynamic raw;

  const TwitchWatchStreakStatusStage251({
    required this.channelLogin,
    this.channelId,
    this.streakCount,
    this.unitLabel = '場',
    this.canShare = false,
    this.shareToken,
    this.title,
    this.description,
    this.raw,
  });

  TwitchViewerSpecialMessageAvailability get availability {
    return canShare
        ? TwitchViewerSpecialMessageAvailability.available
        : TwitchViewerSpecialMessageAvailability.unavailable;
  }

  String get displayTitle {
    final clean = title?.trim();
    if (clean != null && clean.isNotEmpty) return clean;
    final count = streakCount;
    if (count == null || count <= 0) return 'Watch Streak';
    return '連續觀看 $count$unitLabel';
  }

  String get displayDescription {
    final clean = description?.trim();
    if (clean != null && clean.isNotEmpty) return clean;
    if (canShare) return '可分享連續觀看狀態。';
    return '目前沒有可分享的連續觀看訊息。';
  }

  factory TwitchWatchStreakStatusStage251.fromRaw({
    required String channelLogin,
    String? channelId,
    required dynamic raw,
  }) {
    final found = _findFirstMap(raw, const <String>{
      'watchStreak',
      'watch_streak',
      'streak',
      'viewerWatchStreak',
      'communityWatchStreak',
    });
    final map = found ?? _asMap(raw) ?? const <String, dynamic>{};

    final count = _readIntAny(map, const <String>[
      'streakCount',
      'watchStreakCount',
      'count',
      'value',
      'currentStreak',
      'consecutiveStreams',
    ]);
    final token = _readStringAny(map, const <String>[
      'shareToken',
      'token',
      'id',
      'streakId',
    ]);
    final canShare =
        _readBoolAny(map, const <String>[
          'canShare',
          'isShareable',
          'shareable',
          'available',
        ]) ||
        (token != null && token.isNotEmpty);

    return TwitchWatchStreakStatusStage251(
      channelLogin: channelLogin,
      channelId: channelId,
      streakCount: count,
      unitLabel:
          _readStringAny(map, const <String>['unit', 'unitLabel']) ?? '場',
      canShare: canShare,
      shareToken: token,
      title: _readStringAny(map, const <String>['title', 'headline']),
      description: _readStringAny(map, const <String>[
        'description',
        'subtitle',
        'message',
      ]),
      raw: raw,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'channelLogin': channelLogin,
      'channelId': channelId,
      'streakCount': streakCount,
      'unitLabel': unitLabel,
      'canShare': canShare,
      'shareToken': shareToken,
      'title': title,
      'description': description,
      'availability': availability.name,
      'raw': raw,
    };
  }
}

class TwitchResubNotificationStage251 {
  final String channelLogin;
  final String? channelId;
  final int? cumulativeMonths;
  final int? streakMonths;
  final int? durationMonths;
  final String? subPlan;
  final bool canShare;
  final String? token;
  final String? defaultMessage;
  final dynamic raw;

  const TwitchResubNotificationStage251({
    required this.channelLogin,
    this.channelId,
    this.cumulativeMonths,
    this.streakMonths,
    this.durationMonths,
    this.subPlan,
    this.canShare = false,
    this.token,
    this.defaultMessage,
    this.raw,
  });

  TwitchViewerSpecialMessageAvailability get availability {
    return canShare
        ? TwitchViewerSpecialMessageAvailability.available
        : TwitchViewerSpecialMessageAvailability.unavailable;
  }

  String get displayTitle {
    final months = cumulativeMonths;
    if (months != null && months > 0) return '訂閱 $months 個月';
    return 'Resub 分享';
  }

  String get displayDescription {
    final parts = <String>[];
    if (streakMonths != null && streakMonths! > 0) {
      parts.add('連續訂閱 $streakMonths 個月');
    }
    if (durationMonths != null && durationMonths! > 0) {
      parts.add('這次訂閱 $durationMonths 個月');
    }
    if (subPlan != null && subPlan!.trim().isNotEmpty) {
      parts.add('方案 $subPlan');
    }
    if (parts.isEmpty) {
      return canShare ? '可分享訂閱訊息。' : '目前沒有可分享的訂閱訊息。';
    }
    return parts.join('，');
  }

  factory TwitchResubNotificationStage251.fromRaw({
    required String channelLogin,
    String? channelId,
    required dynamic raw,
  }) {
    final found = _findFirstMap(raw, const <String>{
      'resubNotification',
      'resub_notification',
      'resub',
      'currentUser',
      'viewer',
    });
    final map = found ?? _asMap(raw) ?? const <String, dynamic>{};

    final token = _readStringAny(map, const <String>[
      'token',
      'resubToken',
      'notificationToken',
      'id',
    ]);
    final canShare =
        _readBoolAny(map, const <String>[
          'canShare',
          'isShareable',
          'available',
          'hasNotification',
        ]) ||
        (token != null && token.isNotEmpty);

    return TwitchResubNotificationStage251(
      channelLogin: channelLogin,
      channelId: channelId,
      cumulativeMonths: _readIntAny(map, const <String>[
        'cumulativeMonths',
        'cumulative_months',
        'totalMonths',
        'months',
      ]),
      streakMonths: _readIntAny(map, const <String>[
        'streakMonths',
        'streak_months',
        'streak',
      ]),
      durationMonths: _readIntAny(map, const <String>[
        'durationMonths',
        'duration_months',
        'multiMonthDuration',
      ]),
      subPlan: _readStringAny(map, const <String>['subPlan', 'plan', 'tier']),
      canShare: canShare,
      token: token,
      defaultMessage: _readStringAny(map, const <String>[
        'defaultMessage',
        'message',
        'text',
      ]),
      raw: raw,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'channelLogin': channelLogin,
      'channelId': channelId,
      'cumulativeMonths': cumulativeMonths,
      'streakMonths': streakMonths,
      'durationMonths': durationMonths,
      'subPlan': subPlan,
      'canShare': canShare,
      'token': token,
      'defaultMessage': defaultMessage,
      'availability': availability.name,
      'raw': raw,
    };
  }
}

class TwitchChatIdentityBadgeStage251 {
  final String id;
  final String setId;
  final String version;
  final String title;
  final String? imageUrl;
  final bool selected;
  final dynamic raw;

  const TwitchChatIdentityBadgeStage251({
    required this.id,
    required this.setId,
    required this.version,
    required this.title,
    this.imageUrl,
    this.selected = false,
    this.raw,
  });

  factory TwitchChatIdentityBadgeStage251.fromRaw(dynamic raw) {
    final map = _asMap(raw) ?? const <String, dynamic>{};
    final setId =
        _readStringAny(map, const <String>[
          'setID',
          'setId',
          'set_id',
          'badgeSetID',
          'badgeSetId',
        ]) ??
        '';
    final version =
        _readStringAny(map, const <String>[
          'version',
          'badgeVersion',
          'versionId',
        ]) ??
        '';
    final id =
        _readStringAny(map, const <String>['id', 'badgeId']) ??
        '$setId:$version';
    return TwitchChatIdentityBadgeStage251(
      id: id,
      setId: setId,
      version: version,
      title:
          _readStringAny(map, const <String>['title', 'name', 'label']) ??
          setId,
      imageUrl: _readStringAny(map, const <String>[
        'image4x',
        'image2x',
        'image1x',
        'imageUrl',
        'image_url',
        'url',
        'image',
      ]),
      selected: _readBoolAny(map, const <String>[
        'selected',
        'isSelected',
        'active',
      ]),
      raw: raw,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'setId': setId,
      'version': version,
      'title': title,
      'imageUrl': imageUrl,
      'selected': selected,
      'raw': raw,
    };
  }
}

class TwitchChatIdentityStatusStage251 {
  final String channelLogin;
  final String? channelId;
  final List<TwitchChatIdentityBadgeStage251> badges;
  final dynamic raw;

  const TwitchChatIdentityStatusStage251({
    required this.channelLogin,
    this.channelId,
    this.badges = const <TwitchChatIdentityBadgeStage251>[],
    this.raw,
  });

  bool get hasBadges => badges.isNotEmpty;
  TwitchChatIdentityBadgeStage251? get selectedBadge {
    for (final badge in badges) {
      if (badge.selected) return badge;
    }
    return null;
  }

  factory TwitchChatIdentityStatusStage251.fromRaw({
    required String channelLogin,
    String? channelId,
    required dynamic raw,
  }) {
    final badgesRaw = _findFirstList(raw, const <String>{
      'badges',
      'badgeChoices',
      'availableBadges',
      'chatBadges',
    });
    final selectedRaw = _findFirstMap(raw, const <String>{
      'selectedBadge',
      'selectedGlobalBadge',
      'selectedChannelAuthorityBadge',
    });
    final selected = selectedRaw == null
        ? null
        : TwitchChatIdentityBadgeStage251.fromRaw(selectedRaw);

    return TwitchChatIdentityStatusStage251(
      channelLogin: channelLogin,
      channelId: channelId,
      badges: (badgesRaw ?? const <dynamic>[])
          .map((rawBadge) {
            final badge = TwitchChatIdentityBadgeStage251.fromRaw(rawBadge);
            if (selected == null) return badge;
            final selectedById = badge.id.isNotEmpty && badge.id == selected.id;
            final selectedBySet =
                badge.setId.isNotEmpty &&
                badge.setId == selected.setId &&
                badge.version == selected.version;
            if (!selectedById && !selectedBySet) return badge;
            return TwitchChatIdentityBadgeStage251(
              id: badge.id,
              setId: badge.setId,
              version: badge.version,
              title: badge.title,
              imageUrl: badge.imageUrl,
              selected: true,
              raw: badge.raw,
            );
          })
          .where((badge) => badge.setId.trim().isNotEmpty)
          .toList(growable: false),
      raw: raw,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'channelLogin': channelLogin,
      'channelId': channelId,
      'badges': badges.map((badge) => badge.toJson()).toList(growable: false),
      'selectedBadge': selectedBadge?.toJson(),
      'raw': raw,
    };
  }
}

class TwitchViewerSpecialMessagesSnapshotStage251 {
  final String channelLogin;
  final String? channelId;
  final DateTime checkedAt;
  final TwitchWatchStreakStatusStage251? watchStreak;
  final TwitchResubNotificationStage251? resub;
  final TwitchChatIdentityStatusStage251? chatIdentity;
  final List<TwitchViewerSpecialMessageBackendIssue> issues;

  const TwitchViewerSpecialMessagesSnapshotStage251({
    required this.channelLogin,
    this.channelId,
    required this.checkedAt,
    this.watchStreak,
    this.resub,
    this.chatIdentity,
    this.issues = const <TwitchViewerSpecialMessageBackendIssue>[],
  });

  bool get hasIssues => issues.isNotEmpty;
  bool get hasShareableMessage {
    return (watchStreak?.canShare ?? false) || (resub?.canShare ?? false);
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'channelLogin': channelLogin,
      'channelId': channelId,
      'checkedAt': checkedAt.toIso8601String(),
      'hasIssues': hasIssues,
      'hasShareableMessage': hasShareableMessage,
      'watchStreak': watchStreak?.toJson(),
      'resub': resub?.toJson(),
      'chatIdentity': chatIdentity?.toJson(),
      'issues': issues.map((issue) => issue.toJson()).toList(growable: false),
    };
  }
}

Map<String, dynamic>? _asMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((key, value) => MapEntry(key.toString(), value));
  }
  return null;
}

Map<String, dynamic>? _findFirstMap(dynamic value, Set<String> preferredKeys) {
  final map = _asMap(value);
  if (map != null) {
    for (final key in preferredKeys) {
      final nested = _asMap(map[key]);
      if (nested != null) return nested;
    }
    for (final entry in map.entries) {
      final nested = _findFirstMap(entry.value, preferredKeys);
      if (nested != null) return nested;
    }
  }
  if (value is List) {
    for (final item in value) {
      final nested = _findFirstMap(item, preferredKeys);
      if (nested != null) return nested;
    }
  }
  return null;
}

List<dynamic>? _findFirstList(dynamic value, Set<String> preferredKeys) {
  final map = _asMap(value);
  if (map != null) {
    for (final key in preferredKeys) {
      final nested = map[key];
      if (nested is List) return nested;
    }
    for (final entry in map.entries) {
      final nested = _findFirstList(entry.value, preferredKeys);
      if (nested != null) return nested;
    }
  }
  if (value is List) return value;
  return null;
}

String? _readStringAny(Map<String, dynamic> map, List<String> keys) {
  for (final key in keys) {
    final value = map[key];
    if (value == null) continue;
    final text = value.toString().trim();
    if (text.isNotEmpty) return text;
  }
  return null;
}

int? _readIntAny(Map<String, dynamic> map, List<String> keys) {
  for (final key in keys) {
    final value = map[key];
    if (value is int) return value;
    if (value is num) return value.toInt();
    final text = value?.toString().replaceAll(',', '').trim();
    if (text == null || text.isEmpty) continue;
    final parsed = int.tryParse(text);
    if (parsed != null) return parsed;
  }
  return null;
}

bool _readBoolAny(Map<String, dynamic> map, List<String> keys) {
  for (final key in keys) {
    final value = map[key];
    if (value is bool) return value;
    final text = value?.toString().trim().toLowerCase();
    if (text == 'true' || text == '1' || text == 'yes') return true;
  }
  return false;
}
