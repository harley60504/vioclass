import 'twitch_live_stream.dart';

class TwitchStreamHeaderMetadata {
  final String streamId;
  final String channelLogin;
  final String broadcasterDisplayName;
  final String streamTitle;
  final String gameName;
  final String language;
  final List<String> tags;
  final bool isMature;
  final int? viewerCount;
  final String profileImageUrl;
  final DateTime? startedAt;

  const TwitchStreamHeaderMetadata({
    this.streamId = '',
    required this.channelLogin,
    this.broadcasterDisplayName = '',
    this.streamTitle = '',
    this.gameName = '',
    this.language = '',
    this.tags = const <String>[],
    this.isMature = false,
    this.viewerCount,
    this.profileImageUrl = '',
    this.startedAt,
  });

  const TwitchStreamHeaderMetadata.empty({
    String fallbackChannelLogin = 'roger9527',
  }) : this(channelLogin: fallbackChannelLogin);

  /// Human-readable broadcaster name. Prefer Twitch's display name (which may
  /// contain localized/CJK characters) and fall back to the stable login.
  String get displayName {
    final display = broadcasterDisplayName.trim();
    if (display.isNotEmpty) return display;
    return channelLogin.trim();
  }

  /// Compatibility channel id used by UI fallback APIs.
  ///
  /// Stream header metadata is created from Helix stream rows, which do not
  /// always travel with a broadcaster id in this app's current model. Runtime
  /// code should prefer the channel id resolved by chat startup when available.
  String get channelId => '';

  factory TwitchStreamHeaderMetadata.fromLiveStream(TwitchLiveStream stream) {
    return TwitchStreamHeaderMetadata(
      streamId: stream.id,
      channelLogin: stream.channelLogin,
      broadcasterDisplayName: stream.displayName,
      streamTitle: stream.title,
      gameName: stream.gameName,
      language: stream.language,
      tags: stream.tags,
      isMature: stream.isMature,
      viewerCount: stream.viewerCount,
      profileImageUrl: stream.profileImageUrl,
      startedAt: stream.startedAt,
    );
  }

  TwitchStreamHeaderMetadata copyWith({
    String? streamId,
    String? channelLogin,
    String? broadcasterDisplayName,
    String? streamTitle,
    String? gameName,
    String? language,
    List<String>? tags,
    bool? isMature,
    int? viewerCount,
    bool clearViewerCount = false,
    String? profileImageUrl,
    DateTime? startedAt,
    bool clearStartedAt = false,
  }) {
    return TwitchStreamHeaderMetadata(
      streamId: streamId ?? this.streamId,
      channelLogin: channelLogin ?? this.channelLogin,
      broadcasterDisplayName:
          broadcasterDisplayName ?? this.broadcasterDisplayName,
      streamTitle: streamTitle ?? this.streamTitle,
      gameName: gameName ?? this.gameName,
      language: language ?? this.language,
      tags: tags ?? this.tags,
      isMature: isMature ?? this.isMature,
      viewerCount: clearViewerCount ? null : viewerCount ?? this.viewerCount,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      startedAt: clearStartedAt ? null : startedAt ?? this.startedAt,
    );
  }
}
