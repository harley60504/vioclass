import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../platform/android_pip/twitch_android_pip_controller.dart';
import '../../../settings/twitch_player_settings_controller.dart';
import 'twitch_player_common_buttons.dart';

class AndroidPipButton extends StatefulWidget {
  final bool dense;
  final double size;

  const AndroidPipButton({super.key, this.dense = false, this.size = 23});

  @override
  State<AndroidPipButton> createState() => _AndroidPipButtonState();
}

class _AndroidPipButtonState extends State<AndroidPipButton> {
  final TwitchAndroidPipController _pip = TwitchAndroidPipController.instance;
  bool _available = Platform.isAndroid;
  bool _enabled = true;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    unawaited(_refreshAvailability());
  }

  Future<void> _refreshAvailability() async {
    if (!Platform.isAndroid || _checking) return;
    _checking = true;
    final prefs = await SharedPreferences.getInstance();
    final available = await _pip.isPictureInPictureAvailable();
    _checking = false;
    if (!mounted) return;
    setState(() {
      _available = available;
      _enabled =
          prefs.getBool(
            TwitchPlayerSettingsController.androidPipEnabledPreferenceKey,
          ) ??
          true;
    });
  }

  Future<void> _enterPip() async {
    if (!Platform.isAndroid || !_enabled) return;
    final entered = await _pip.enterPictureInPicture(
      aspectRatioWidth: 16,
      aspectRatioHeight: 9,
    );
    if (!entered && mounted) {
      ScaffoldMessenger.maybeOf(
        context,
      )?.showSnackBar(const SnackBar(content: Text('目前裝置不支援系統子母畫面')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!Platform.isAndroid || !_available || !_enabled) {
      return const SizedBox.shrink();
    }

    return PlainIconButton(
      tooltip: '系統子母畫面',
      icon: Icons.picture_in_picture_alt_rounded,
      size: widget.size,
      dense: widget.dense,
      onPressed: _enterPip,
    );
  }
}
