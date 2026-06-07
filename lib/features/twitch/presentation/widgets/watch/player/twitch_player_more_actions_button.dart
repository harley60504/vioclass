import 'package:flutter/material.dart';

import '../../../../services/playback/twitch_playlist_player_runtime.dart';

class PlayerMoreActionsButton extends StatelessWidget {
  final TwitchPlaylistPlayerRuntime playerRuntime;

  const PlayerMoreActionsButton({super.key, required this.playerRuntime});

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}
