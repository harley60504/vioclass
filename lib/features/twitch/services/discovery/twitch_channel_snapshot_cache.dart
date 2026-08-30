import '../../models/discovery/twitch_live_stream.dart';
import '../../models/discovery/twitch_stream_header_metadata.dart';

class TwitchChannelSnapshot {
  final String broadcasterId;
  final String broadcasterLogin;
  final String broadcasterName;
  final String profileImageUrl;
  final String offlineImageUrl;
  final String description;
  final String streamTitle;
  final String gameName;
  final String language;
  final List<String> tags;
  final bool? isMature;
  final int? viewerCount;
  final bool? isFollowed;

  const TwitchChannelSnapshot({
    this.broadcasterId = '',
    this.broadcasterLogin = '',
    this.broadcasterName = '',
    this.profileImageUrl = '',
    this.offlineImageUrl = '',
    this.description = '',
    this.streamTitle = '',
    this.gameName = '',
    this.language = '',
    this.tags = const <String>[],
    this.isMature,
    this.viewerCount,
    this.isFollowed,
  });

  factory TwitchChannelSnapshot.fromLiveStream(TwitchLiveStream stream) {
    return TwitchChannelSnapshot.fromLiveStreamWithFollowStatus(stream);
  }

  factory TwitchChannelSnapshot.fromLiveStreamWithFollowStatus(
    TwitchLiveStream stream, {
    bool? isFollowed,
  }) {
    return TwitchChannelSnapshot(
      broadcasterId: stream.userId,
      broadcasterLogin: stream.channelLogin,
      broadcasterName: stream.displayName,
      profileImageUrl: stream.profileImageUrl,
      streamTitle: stream.title,
      gameName: stream.gameName,
      language: stream.language,
      tags: stream.tags,
      isMature: stream.isMature,
      viewerCount: stream.viewerCount,
      isFollowed: isFollowed,
    );
  }

  factory TwitchChannelSnapshot.fromFollowedChannel(
    TwitchFollowedChannel channel,
  ) {
    return TwitchChannelSnapshot.fromFollowedChannelWithFollowStatus(channel);
  }

  factory TwitchChannelSnapshot.fromFollowedChannelWithFollowStatus(
    TwitchFollowedChannel channel, {
    bool? isFollowed,
  }) {
    return TwitchChannelSnapshot(
      broadcasterId: channel.broadcasterId,
      broadcasterLogin: channel.channelLogin,
      broadcasterName: channel.displayName,
      profileImageUrl: channel.profileImageUrl,
      offlineImageUrl: channel.offlineImageUrl,
      description: channel.description,
      isFollowed: isFollowed,
    );
  }

  TwitchChannelSnapshot copyWith({
    String? broadcasterId,
    String? broadcasterLogin,
    String? broadcasterName,
    String? profileImageUrl,
    String? offlineImageUrl,
    String? description,
    String? streamTitle,
    String? gameName,
    String? language,
    List<String>? tags,
    bool? isMature,
    int? viewerCount,
    bool? isFollowed,
  }) {
    return TwitchChannelSnapshot(
      broadcasterId: broadcasterId ?? this.broadcasterId,
      broadcasterLogin: broadcasterLogin ?? this.broadcasterLogin,
      broadcasterName: broadcasterName ?? this.broadcasterName,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      offlineImageUrl: offlineImageUrl ?? this.offlineImageUrl,
      description: description ?? this.description,
      streamTitle: streamTitle ?? this.streamTitle,
      gameName: gameName ?? this.gameName,
      language: language ?? this.language,
      tags: tags ?? this.tags,
      isMature: isMature ?? this.isMature,
      viewerCount: viewerCount ?? this.viewerCount,
      isFollowed: isFollowed ?? this.isFollowed,
    );
  }

  TwitchChannelSnapshot merge(TwitchChannelSnapshot next) {
    return TwitchChannelSnapshot(
      broadcasterId: _prefer(next.broadcasterId, broadcasterId),
      broadcasterLogin: _prefer(next.broadcasterLogin, broadcasterLogin),
      broadcasterName: _prefer(next.broadcasterName, broadcasterName),
      profileImageUrl: _prefer(next.profileImageUrl, profileImageUrl),
      offlineImageUrl: _prefer(next.offlineImageUrl, offlineImageUrl),
      description: _prefer(next.description, description),
      streamTitle: _prefer(next.streamTitle, streamTitle),
      gameName: _prefer(next.gameName, gameName),
      language: _prefer(next.language, language),
      tags: next.tags.isNotEmpty ? next.tags : tags,
      isMature: next.isMature ?? isMature,
      viewerCount: next.viewerCount ?? viewerCount,
      isFollowed: next.isFollowed ?? isFollowed,
    );
  }

  TwitchStreamHeaderMetadata mergeHeaderMetadata(
    TwitchStreamHeaderMetadata metadata,
  ) {
    return metadata.copyWith(
      channelLogin: metadata.channelLogin.trim().isNotEmpty
          ? metadata.channelLogin
          : broadcasterLogin,
      streamTitle: metadata.streamTitle.trim().isNotEmpty
          ? metadata.streamTitle
          : streamTitle,
      gameName: metadata.gameName.trim().isNotEmpty
          ? metadata.gameName
          : gameName,
      language: metadata.language.trim().isNotEmpty
          ? metadata.language
          : language,
      tags: metadata.tags.isNotEmpty ? metadata.tags : tags,
      isMature: metadata.isMature || (isMature ?? false),
      viewerCount: metadata.viewerCount ?? viewerCount,
      profileImageUrl: metadata.profileImageUrl.trim().isNotEmpty
          ? metadata.profileImageUrl
          : profileImageUrl,
    );
  }

  TwitchFollowedChannel mergeFollowedChannel(TwitchFollowedChannel channel) {
    return TwitchFollowedChannel(
      broadcasterId: _prefer(channel.broadcasterId, broadcasterId),
      broadcasterLogin: _prefer(channel.broadcasterLogin, broadcasterLogin),
      broadcasterName: _prefer(channel.broadcasterName, broadcasterName),
      followedAt: channel.followedAt,
      profileImageUrl: _prefer(channel.profileImageUrl, profileImageUrl),
      offlineImageUrl: _prefer(channel.offlineImageUrl, offlineImageUrl),
      description: _prefer(channel.description, description),
    );
  }

  TwitchFollowedChannel toFollowedChannel() {
    return TwitchFollowedChannel(
      broadcasterId: broadcasterId,
      broadcasterLogin: broadcasterLogin,
      broadcasterName: broadcasterName,
      followedAt: null,
      profileImageUrl: profileImageUrl,
      offlineImageUrl: offlineImageUrl,
      description: description,
    );
  }

  static String _prefer(String primary, String fallback) {
    final cleanPrimary = primary.trim();
    if (cleanPrimary.isNotEmpty) return primary;
    return fallback;
  }
}

class TwitchChannelSnapshotCache {
  TwitchChannelSnapshotCache._();

  static final TwitchChannelSnapshotCache instance =
      TwitchChannelSnapshotCache._();

  final Map<String, TwitchChannelSnapshot> _byId =
      <String, TwitchChannelSnapshot>{};
  final Map<String, TwitchChannelSnapshot> _byLogin =
      <String, TwitchChannelSnapshot>{};

  void rememberLiveStream(TwitchLiveStream stream, {bool? isFollowed}) {
    remember(
      TwitchChannelSnapshot.fromLiveStreamWithFollowStatus(
        stream,
        isFollowed: isFollowed,
      ),
    );
  }

  void rememberLiveStreams(
    Iterable<TwitchLiveStream> streams, {
    bool? isFollowed,
  }) {
    for (final stream in streams) {
      rememberLiveStream(stream, isFollowed: isFollowed);
    }
  }

  void rememberFollowedChannel(
    TwitchFollowedChannel channel, {
    bool? isFollowed,
  }) {
    remember(
      TwitchChannelSnapshot.fromFollowedChannelWithFollowStatus(
        channel,
        isFollowed: isFollowed,
      ),
    );
  }

  void rememberFollowedChannels(
    Iterable<TwitchFollowedChannel> channels, {
    bool? isFollowed,
  }) {
    for (final channel in channels) {
      rememberFollowedChannel(channel, isFollowed: isFollowed);
    }
  }

  void rememberProfileImage({
    required String login,
    required String profileImageUrl,
  }) {
    final cleanLogin = login.trim().toLowerCase();
    final cleanImage = profileImageUrl.trim();
    if (cleanLogin.isEmpty || cleanImage.isEmpty) return;
    remember(
      TwitchChannelSnapshot(
        broadcasterLogin: cleanLogin,
        profileImageUrl: cleanImage,
      ),
    );
  }

  void remember(TwitchChannelSnapshot snapshot) {
    final id = snapshot.broadcasterId.trim();
    final login = snapshot.broadcasterLogin.trim().toLowerCase();
    if (id.isEmpty && login.isEmpty) return;

    final current = _findRaw(id: id, login: login);
    final merged = current == null ? snapshot : current.merge(snapshot);

    final mergedId = merged.broadcasterId.trim();
    final mergedLogin = merged.broadcasterLogin.trim().toLowerCase();
    if (mergedId.isNotEmpty) _byId[mergedId] = merged;
    if (mergedLogin.isNotEmpty) _byLogin[mergedLogin] = merged;
  }

  TwitchChannelSnapshot? find({String? id, String? login}) {
    return _findRaw(
      id: id?.trim() ?? '',
      login: login?.trim().toLowerCase() ?? '',
    );
  }

  bool? findKnownFollowStatus({String? id, String? login}) {
    return find(id: id, login: login)?.isFollowed;
  }

  TwitchStreamHeaderMetadata resolveHeaderMetadata(
    TwitchStreamHeaderMetadata metadata,
  ) {
    final snapshot = find(login: metadata.channelLogin);
    if (snapshot == null) return metadata;
    return snapshot.mergeHeaderMetadata(metadata);
  }

  TwitchFollowedChannel? resolveFollowedChannel({
    TwitchFollowedChannel? channel,
    TwitchStreamHeaderMetadata? metadata,
  }) {
    final snapshot = find(
      id: channel?.broadcasterId,
      login: channel?.channelLogin ?? metadata?.channelLogin,
    );

    if (channel != null) {
      return snapshot == null ? channel : snapshot.mergeFollowedChannel(channel);
    }

    if (snapshot != null &&
        (snapshot.broadcasterId.trim().isNotEmpty ||
            snapshot.broadcasterLogin.trim().isNotEmpty)) {
      return snapshot.toFollowedChannel();
    }

    final login = metadata?.channelLogin.trim().toLowerCase() ?? '';
    if (login.isEmpty) return null;
    return TwitchFollowedChannel(
      broadcasterId: '',
      broadcasterLogin: login,
      broadcasterName: login,
      followedAt: null,
      profileImageUrl: metadata?.profileImageUrl ?? '',
    );
  }

  TwitchChannelSnapshot? _findRaw({required String id, required String login}) {
    final cleanId = id.trim();
    if (cleanId.isNotEmpty) {
      final byId = _byId[cleanId];
      if (byId != null) return byId;
    }

    final cleanLogin = login.trim().toLowerCase();
    if (cleanLogin.isNotEmpty) {
      return _byLogin[cleanLogin];
    }

    return null;
  }
}
