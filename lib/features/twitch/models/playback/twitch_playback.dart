class TwitchPlaybackAccessToken {
  final String value;
  final String signature;

  const TwitchPlaybackAccessToken({
    required this.value,
    required this.signature,
  });

  bool get isValid {
    return value.trim().isNotEmpty && signature.trim().isNotEmpty;
  }

  factory TwitchPlaybackAccessToken.fromJson(Map<String, dynamic> json) {
    return TwitchPlaybackAccessToken(
      value: json['value']?.toString() ?? '',
      signature: json['signature']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{'value': value, 'signature': signature};
  }
}

class TwitchPlaybackPlaylistRequest {
  static const String defaultTwitchWebClientId =
      'kimne78kx3ncx6brgo4mv6wki5h1ko';

  final String channelLogin;
  final TwitchPlaybackAccessToken accessToken;
  final String clientId;
  final bool allowSource;
  final bool allowAudioOnly;
  final bool fastBread;
  final String playerBackend;
  final String supportedCodecs;
  final bool playlistIncludeFramerate;
  final bool reassignmentsSupported;

  const TwitchPlaybackPlaylistRequest({
    required this.channelLogin,
    required this.accessToken,
    this.clientId = defaultTwitchWebClientId,
    this.allowSource = true,
    this.allowAudioOnly = true,
    this.fastBread = true,
    this.playerBackend = 'mediaplayer',
    this.supportedCodecs = 'avc1',
    this.playlistIncludeFramerate = true,
    this.reassignmentsSupported = true,
  });

  Uri buildUsherUri() {
    return Uri.https('usher.ttvnw.net', '/api/channel/hls/$channelLogin.m3u8', <
      String,
      String
    >{
      'allow_source': allowSource.toString(),
      'allow_audio_only': allowAudioOnly.toString(),
      'client_id': clientId,
      'fast_bread': fastBread.toString(),
      'p': DateTime.now().millisecondsSinceEpoch.remainder(10000000).toString(),
      'play_session_id': DateTime.now().microsecondsSinceEpoch.toString(),
      'player_backend': playerBackend,
      'playlist_include_framerate': playlistIncludeFramerate.toString(),
      'reassignments_supported': reassignmentsSupported.toString(),
      'sig': accessToken.signature,
      'supported_codecs': supportedCodecs,
      'token': accessToken.value,
    });
  }
}

class TwitchVodPlaylistRequest {
  static const String defaultTwitchWebClientId =
      TwitchPlaybackPlaylistRequest.defaultTwitchWebClientId;

  final String videoId;
  final TwitchPlaybackAccessToken accessToken;
  final String clientId;
  final bool allowSource;
  final bool allowAudioOnly;
  final String supportedCodecs;
  final bool playlistIncludeFramerate;
  final bool reassignmentsSupported;

  const TwitchVodPlaylistRequest({
    required this.videoId,
    required this.accessToken,
    this.clientId = defaultTwitchWebClientId,
    this.allowSource = true,
    this.allowAudioOnly = true,
    this.supportedCodecs = 'av1,h264,h265',
    this.playlistIncludeFramerate = true,
    this.reassignmentsSupported = true,
  });

  Uri buildUsherUri() {
    return Uri.https('usher.ttvnw.net', '/vod/$videoId', <String, String>{
      'platform': 'web',
      'player_type': 'embed',
      'allow_source': allowSource.toString(),
      'allow_audio_only': allowAudioOnly.toString(),
      'client_id': clientId,
      'nauth': accessToken.value,
      'nauthsig': accessToken.signature,
      'p': DateTime.now().millisecondsSinceEpoch.remainder(10000000).toString(),
      'playlist_include_framerate': playlistIncludeFramerate.toString(),
      'reassignments_supported': reassignmentsSupported.toString(),
      'supported_codecs': supportedCodecs,
    });
  }
}
