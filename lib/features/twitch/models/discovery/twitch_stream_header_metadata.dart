import 'twitch_live_stream.dart';

class TwitchStreamHeaderMetadata {
  final String channelLogin;
  final String streamTitle;
  final String gameName;
  final String language;
  final List<String> tags;
  final bool isMature;
  final int? viewerCount;
  final String profileImageUrl;

  const TwitchStreamHeaderMetadata({
    required this.channelLogin,
    this.streamTitle = '',
    this.gameName = '',
    this.language = '',
    this.tags = const <String>[],
    this.isMature = false,
    this.viewerCount,
    this.profileImageUrl = '',
  });

  const TwitchStreamHeaderMetadata.empty({
    String fallbackChannelLogin = 'roger9527',
  }) : this(channelLogin: fallbackChannelLogin);

  factory TwitchStreamHeaderMetadata.fromLiveStream(TwitchLiveStream stream) {
    return TwitchStreamHeaderMetadata(
      channelLogin: stream.channelLogin,
      streamTitle: stream.title,
      gameName: stream.gameName,
      language: stream.language,
      tags: stream.tags,
      isMature: stream.isMature,
      viewerCount: stream.viewerCount,
      profileImageUrl: stream.profileImageUrl,
    );
  }

  TwitchStreamHeaderMetadata copyWith({
    String? channelLogin,
    String? streamTitle,
    String? gameName,
    String? language,
    List<String>? tags,
    bool? isMature,
    int? viewerCount,
    bool clearViewerCount = false,
    String? profileImageUrl,
  }) {
    return TwitchStreamHeaderMetadata(
      channelLogin: channelLogin ?? this.channelLogin,
      streamTitle: streamTitle ?? this.streamTitle,
      gameName: gameName ?? this.gameName,
      language: language ?? this.language,
      tags: tags ?? this.tags,
      isMature: isMature ?? this.isMature,
      viewerCount: clearViewerCount ? null : viewerCount ?? this.viewerCount,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
    );
  }
}
