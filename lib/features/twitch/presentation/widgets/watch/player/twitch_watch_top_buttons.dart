import 'package:flutter/material.dart';

import '../../../localization/vioclass_localizations.dart';
import '../../../theme/twitch_ui_tokens.dart';
import 'twitch_player_chrome_button.dart';

class FollowButton extends StatelessWidget {
  final bool followed;
  final bool busy;
  final bool compact;
  final bool tiny;
  final double? height;
  final VoidCallback? onPressed;

  const FollowButton({
    super.key,
    required this.followed,
    required this.busy,
    this.compact = false,
    this.tiny = false,
    this.height,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return PlayerChromeButton(
      tooltip: context.vio.t(followed ? '取消追隨' : '追隨'),
      icon: followed ? Icons.favorite_rounded : Icons.favorite_border_rounded,
      selected: followed,
      busy: busy,
      accentColor: TwitchUiColors.live,
      compact: compact,
      tiny: tiny,
      height: height,
      onPressed: onPressed,
    );
  }
}

class SubscribeButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final bool compact;
  final bool tiny;
  final double? height;

  const SubscribeButton({
    super.key,
    required this.onPressed,
    this.compact = false,
    this.tiny = false,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final label = compact ? null : context.vio.t('訂閱');
    return PlayerChromeButton(
      tooltip: context.vio.t('訂閱'),
      icon: Icons.auto_awesome_rounded,
      label: label,
      primary: true,
      compact: compact,
      tiny: tiny,
      height: height,
      onPressed: onPressed,
    );
  }
}

class ChannelLibraryButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final bool compact;
  final bool tiny;
  final double? height;

  const ChannelLibraryButton({
    super.key,
    required this.onPressed,
    this.compact = false,
    this.tiny = false,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    return PlayerChromeButton(
      tooltip: context.vio.t('關於 / VOD'),
      icon: Icons.video_library_rounded,
      label: compact ? null : context.vio.t('媒體庫'),
      compact: compact,
      tiny: tiny,
      height: height,
      onPressed: onPressed,
    );
  }
}

class CreateClipButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final bool busy;
  final bool compact;
  final bool tiny;
  final double? height;

  const CreateClipButton({
    super.key,
    required this.onPressed,
    this.busy = false,
    this.compact = false,
    this.tiny = false,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    return PlayerChromeButton(
      tooltip: context.vio.t('建立片段'),
      icon: Icons.movie_creation_outlined,
      busy: busy,
      compact: compact,
      tiny: tiny,
      height: height,
      onPressed: onPressed,
    );
  }
}
