part of twitch_watch_player_area;

class _WatchCompactAvatarTile extends StatelessWidget {
  final TwitchStreamHeaderMetadata metadata;
  final bool tiny;
  final double height;

  const _WatchCompactAvatarTile({
    required this.metadata,
    required this.tiny,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    final channelLogin = metadata.channelLogin.trim();
    final profileImageUrl = metadata.profileImageUrl.trim();
    final tileSize = height;
    final size = math.min(tileSize - 12.0, tiny ? 36.0 : 40.0);

    return Tooltip(
      message: channelLogin.isEmpty ? 'Twitch Stream' : channelLogin,
      child: TwitchGlassSurface(
        borderRadius: BorderRadius.circular(tiny ? 14 : 16),
        backgroundColor: Colors.black.withOpacity(0.36),
        borderColor: Colors.white.withOpacity(0.10),
        blurSigma: 18,
        boxShadow: TwitchGlassPanelShadow.compact(opacity: 0.20),
        child: SizedBox(
          width: tileSize,
          height: tileSize,
          child: Center(
            child: _WatchChannelAvatar(
              imageUrl: profileImageUrl,
              channelLogin: channelLogin,
              size: size,
            ),
          ),
        ),
      ),
    );
  }
}

class _WatchStreamHeaderCard extends StatelessWidget {
  final TwitchStreamHeaderMetadata metadata;
  final bool compact;
  final double height;

  const _WatchStreamHeaderCard({
    required this.metadata,
    required this.compact,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    final channelLogin = metadata.channelLogin.trim();
    final streamTitle = metadata.streamTitle.trim();
    final gameName = metadata.gameName.trim();
    final viewerCount = metadata.viewerCount;
    final profileImageUrl = metadata.profileImageUrl.trim();
    final language = metadata.language.trim().toUpperCase();

    final avatarSize = compact ? 34.0 : 44.0;

    return TwitchGlassSurface(
      borderRadius: BorderRadius.circular(compact ? 16 : 20),
      backgroundColor: Colors.black.withOpacity(0.38),
      borderColor: Colors.white.withOpacity(0.11),
      blurSigma: 18,
      boxShadow: TwitchGlassPanelShadow.soft(opacity: compact ? 0.24 : 0.30),
      child: SizedBox(
        height: height,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 10 : 16,
            vertical: compact ? 5 : 9,
          ),
          child: Row(
            children: [
              _WatchChannelAvatar(
                imageUrl: profileImageUrl,
                channelLogin: channelLogin,
                size: avatarSize,
              ),
              SizedBox(width: compact ? 8 : 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Tooltip(
                            message: channelLogin.isEmpty ? 'Twitch Stream' : channelLogin,
                            child: Text(
                              channelLogin.isEmpty ? 'Twitch Stream' : channelLogin,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: compact ? 13.5 : 17,
                                fontWeight: FontWeight.w900,
                                height: 1.05,
                              ),
                            ),
                          ),
                        ),
                        if (viewerCount != null && viewerCount > 0) ...[
                          SizedBox(width: compact ? 5 : 7),
                          _WatchInfoPill(
                            icon: Icons.visibility_rounded,
                            label: _formatViewerCount(viewerCount),
                            compact: compact,
                          ),
                        ],
                        if (gameName.isNotEmpty) ...[
                          SizedBox(width: compact ? 5 : 7),
                          _WatchInfoPill(
                            icon: Icons.sports_esports_rounded,
                            label: gameName,
                            copyText: gameName,
                            compact: compact,
                          ),
                        ],
                        if (language.isNotEmpty) ...[
                          SizedBox(width: compact ? 5 : 7),
                          _WatchInfoPill(
                            icon: Icons.translate_rounded,
                            label: language,
                            copyText: metadata.language.trim(),
                            compact: compact,
                            maxWidth: compact ? 62 : 72,
                          ),
                        ],
                      ],
                    ),
                    if (streamTitle.isNotEmpty) ...[
                      SizedBox(height: compact ? 3 : 4),
                      Tooltip(
                        message: streamTitle,
                        child: Text(
                          streamTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: compact ? 11.5 : 13,
                            fontWeight: FontWeight.w800,
                            height: 1.05,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

}

class _WatchChannelAvatar extends StatelessWidget {
  final String imageUrl;
  final String channelLogin;
  final double size;

  const _WatchChannelAvatar({
    required this.imageUrl,
    required this.channelLogin,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    final cleanUrl = imageUrl.trim();
    final fallbackLetter = channelLogin.trim().isEmpty
        ? 'T'
        : channelLogin.trim().characters.first.toUpperCase();

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF2A2236),
            border: Border.all(color: Colors.white.withOpacity(0.14)),
          ),
          clipBehavior: Clip.antiAlias,
          child: cleanUrl.isEmpty
              ? Center(
                  child: Text(
                    fallbackLetter,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: size * 0.42,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                )
              : Image.network(
                  cleanUrl,
                  fit: BoxFit.cover,
                  cacheWidth: (size * 2).round(),
                  cacheHeight: (size * 2).round(),
                  errorBuilder: (_, __, ___) => Center(
                    child: Text(
                      fallbackLetter,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: size * 0.42,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
        ),
        Positioned(
          right: -1,
          bottom: -1,
          child: Container(
            width: size * 0.30,
            height: size * 0.30,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF57F287),
              border: Border.all(color: const Color(0xDD0E0E10), width: 2),
            ),
          ),
        ),
      ],
    );
  }
}

String _formatViewerCount(int value) {
  if (value >= 10000) {
    final text = (value / 10000).toStringAsFixed(value >= 100000 ? 0 : 1);
    return '${text.replaceFirst(RegExp(r'\.0$'), '')}萬人';
  }
  if (value >= 1000) {
    final text = (value / 1000).toStringAsFixed(value >= 10000 ? 0 : 1);
    return '${text.replaceFirst(RegExp(r'\.0$'), '')}k 人';
  }
  return '$value 人';
}

class _WatchInfoPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? copyText;
  final bool compact;
  final double? maxWidth;

  const _WatchInfoPill({
    required this.icon,
    required this.label,
    this.copyText,
    this.compact = false,
    this.maxWidth,
  });

  @override
  Widget build(BuildContext context) {
    final canCopy = copyText != null && copyText!.trim().isNotEmpty;

    return Tooltip(
      message: canCopy ? '點擊複製：$label' : label,
      child: Material(
        color: Colors.white.withOpacity(0.075),
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: canCopy
              ? () async {
                  await Clipboard.setData(ClipboardData(text: copyText!.trim()));
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('已複製：$label')),
                  );
                }
              : null,
          child: Container(
            height: compact ? 24 : 28,
            constraints: BoxConstraints(maxWidth: maxWidth ?? (compact ? 120 : 190)),
            padding: EdgeInsets.symmetric(horizontal: compact ? 7 : 9),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: Colors.white.withOpacity(0.11)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: compact ? 13 : 15, color: const Color(0xFFBF94FF)),
                SizedBox(width: compact ? 4 : 5),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: compact ? 10.5 : 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
