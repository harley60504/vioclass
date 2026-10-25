import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';

import '../../../../services/playback/twitch_playlist_player_runtime.dart';
import '../../../localization/vioclass_localizations.dart';
import '../../../settings/twitch_player_settings_controller.dart';
import '../../../sheets/twitch_app_settings_sheet.dart';
import '../../../theme/twitch_ui_tokens.dart';
import 'twitch_player_common_buttons.dart';
import 'twitch_player_volume_control.dart';
import 'twitch_player_settings_drawer.dart';

class PlayerMoreActionsButton extends StatelessWidget {
  final TwitchPlaylistPlayerRuntime playerRuntime;
  final Player? player;

  const PlayerMoreActionsButton({
    super.key,
    required this.playerRuntime,
    this.player,
  });

  @override
  Widget build(BuildContext context) {
    if (player == null) return const SizedBox.shrink();
    return PlainIconButton(
      controlSize: 36,
      size: 22,
      tooltip: context.vio.t('播放器設定'),
      icon: Icons.settings_rounded,
      onPressed: () async {
        const VolumeControlInteraction().dispatch(context);
        final controller = TwitchPlayerSettingsController();
        try {
          await controller.load();
          if (!context.mounted) return;
          await PlayerSettingsDrawerHost.show(
            context,
            (drawerContext, close) => Material(
              key: const ValueKey('player-settings-drawer'),
              color: TwitchUiColors.playerOverlay,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              shape: const Border(
                left: BorderSide(color: TwitchUiColors.border),
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
                    child: Row(
                      children: [
                        const Icon(Icons.settings_rounded, size: 20),
                        const SizedBox(width: 10),
                        Expanded(child: Text(context.vio.t('播放器設定'))),
                        IconButton(
                          tooltip: context.vio.t('關閉'),
                          icon: const Icon(Icons.close_rounded),
                          onPressed: close,
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(child: buildTwitchPlayerSettingsPane(controller)),
                ],
              ),
            ),
          );
        } catch (_) {
          if (context.mounted) {
            ScaffoldMessenger.maybeOf(context)?.showSnackBar(
              SnackBar(content: Text(context.vio.t('設定讀取失敗，請稍後再試。'))),
            );
          }
        } finally {
          controller.dispose();
        }
      },
    );
  }
}
