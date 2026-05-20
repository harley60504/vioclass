import 'package:flutter/material.dart';

import '../../../data/models/twitch_stream_model.dart';
import 'twitch_chat_side_panel.dart';

class TwitchOfficialChatPanel extends StatelessWidget {
  final dynamic stream;
  final String? clientId;
  final Future<String?> Function()? accessTokenProvider;
  final String? viewerId;
  final String? viewerLogin;

  const TwitchOfficialChatPanel({
    super.key,
    required this.stream,
    this.clientId,
    this.accessTokenProvider,
    this.viewerId,
    this.viewerLogin,
  });

  @override
  Widget build(BuildContext context) {
    return TwitchChatSidePanel(
      stream: _normalizeStream(stream),
      width: 380,
      onWidthDelta: (_) {},
      onWidthDragEnd: () {},
    );
  }

  TwitchStreamModel _normalizeStream(dynamic value) {
    if (value is TwitchStreamModel) return value;

    final json = _tryToJson(value);
    if (json != null) {
      return TwitchStreamModel.fromJson(json);
    }

    final userLogin = _read(value, const <String>[
      'userLogin',
      'login',
      'channelLogin',
      'broadcasterLogin',
    ]);

    final userName = _read(value, const <String>[
      'userName',
      'displayName',
      'channelName',
      'broadcasterName',
    ]);

    final userId = _read(value, const <String>[
      'userId',
      'channelId',
      'broadcasterId',
      'id',
    ]);

    final profileImageUrl = _read(value, const <String>[
      'profileImageUrl',
      'profile_image_url',
      'avatarUrl',
    ]);

    return TwitchStreamModel(
      userId: userId,
      userLogin: userLogin,
      userName: userName.isNotEmpty ? userName : userLogin,
      profileImageUrl: profileImageUrl,
    );
  }

  Map<String, dynamic>? _tryToJson(dynamic value) {
    try {
      final raw = value?.toJson();
      if (raw is Map<String, dynamic>) return raw;
      if (raw is Map) return Map<String, dynamic>.from(raw);
    } catch (_) {}
    return null;
  }

  String _read(dynamic value, List<String> fields) {
    for (final field in fields) {
      try {
        final json = value?.toJson();
        if (json is Map && json[field] != null) {
          final text = json[field].toString().trim();
          if (text.isNotEmpty) return text;
        }
      } catch (_) {}
    }

    for (final field in fields) {
      try {
        dynamic raw;
        switch (field) {
          case 'userLogin':
            raw = value.userLogin;
            break;
          case 'login':
            raw = value.login;
            break;
          case 'channelLogin':
            raw = value.channelLogin;
            break;
          case 'broadcasterLogin':
            raw = value.broadcasterLogin;
            break;
          case 'userName':
            raw = value.userName;
            break;
          case 'displayName':
            raw = value.displayName;
            break;
          case 'channelName':
            raw = value.channelName;
            break;
          case 'broadcasterName':
            raw = value.broadcasterName;
            break;
          case 'userId':
            raw = value.userId;
            break;
          case 'channelId':
            raw = value.channelId;
            break;
          case 'broadcasterId':
            raw = value.broadcasterId;
            break;
          case 'id':
            raw = value.id;
            break;
          case 'profileImageUrl':
            raw = value.profileImageUrl;
            break;
          case 'profile_image_url':
            raw = value.profile_image_url;
            break;
          case 'avatarUrl':
            raw = value.avatarUrl;
            break;
        }

        final text = raw?.toString().trim() ?? '';
        if (text.isNotEmpty) return text;
      } catch (_) {}
    }

    return '';
  }
}
