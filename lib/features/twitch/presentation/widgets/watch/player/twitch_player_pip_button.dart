part of twitch_watch_player_area;

class _AndroidPipButton extends StatefulWidget {
  final bool dense;
  final double size;

  const _AndroidPipButton({
    this.dense = false,
    this.size = 23,
  });

  @override
  State<_AndroidPipButton> createState() => _AndroidPipButtonState();
}

class _AndroidPipButtonState extends State<_AndroidPipButton> {
  final TwitchAndroidPipController _pip = TwitchAndroidPipController.instance;
  bool _available = Platform.isAndroid;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    unawaited(_refreshAvailability());
  }

  Future<void> _refreshAvailability() async {
    if (!Platform.isAndroid || _checking) return;
    _checking = true;
    final available = await _pip.isPictureInPictureAvailable();
    _checking = false;
    if (!mounted) return;
    setState(() => _available = available);
  }

  Future<void> _enterPip() async {
    if (!Platform.isAndroid) return;
    final entered = await _pip.enterPictureInPicture(
      aspectRatioWidth: 16,
      aspectRatioHeight: 9,
    );
    if (!entered && mounted) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(content: Text('目前裝置不支援子母畫面')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!Platform.isAndroid || !_available) return const SizedBox.shrink();

    return PlainIconButton(
      tooltip: '子母畫面',
      icon: Icons.picture_in_picture_alt_rounded,
      size: widget.size,
      dense: widget.dense,
      onPressed: _enterPip,
    );
  }
}
