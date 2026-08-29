import 'package:flutter/material.dart';

import '../../../models/discovery/twitch_stream_header_metadata.dart';
import '../../../models/discovery/twitch_live_stream.dart';
import '../../../services/discovery/twitch_discovery_service.dart';
import '../../pages/twitch_channel_page.dart';
import '../../pages/twitch_watch_page.dart';
import '../../theme/twitch_ui_tokens.dart';
import '../chat/twitch_chat_text_style.dart';
import '../shared/twitch_cached_image_layer.dart';

class TwitchOfflineChannelCard extends StatelessWidget {
  final TwitchFollowedChannel channel;
  final TwitchDiscoveryService discoveryService;

  const TwitchOfflineChannelCard({
    super.key,
    required this.channel,
    required this.discoveryService,
  });

  @override
  Widget build(BuildContext context) {
    const radius = BorderRadius.all(Radius.circular(18));
    final avatarUrl = channel.profileImageUrl.trim();
    final description = channel.description.trim();

    return Material(
      color: Colors.transparent,
      borderRadius: radius,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openMediaWatchPage(context),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: radius,
            color: Colors.white.withValues(alpha: 0.055),
            border: Border.all(color: Colors.white.withValues(alpha: 0.09)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _OfflineAvatar(imageUrl: avatarUrl),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            channel.displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              height: 1.08,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          if (channel.channelLogin.isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Text(
                              channel.channelLogin,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 11.5,
                                height: 1,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: Text(
                    description.isEmpty
                        ? '目前未開台，點擊後會先播放最新 VOD；沒有 VOD 則顯示關台圖。'
                        : description,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white60,
                      fontSize: 12,
                      height: 1.28,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _OfflineActionButton(
                        icon: Icons.play_arrow_rounded,
                        label: '觀看',
                        onPressed: () => _openMediaWatchPage(context),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _OfflineActionButton(
                        icon: Icons.video_library_rounded,
                        label: '媒體庫',
                        onPressed: () => _openChannelPage(context, 2),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openChannelPage(BuildContext context, int initialTabIndex) {
    showTwitchChannelSheet(
      context: context,
      discoveryService: discoveryService,
      channel: channel,
      initialTabIndex: initialTabIndex,
    );
  }

  void _openMediaWatchPage(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => TwitchWatchPage(
          initialMetadata: TwitchStreamHeaderMetadata(
            channelLogin: channel.channelLogin,
            streamTitle: channel.description,
            profileImageUrl: channel.profileImageUrl,
          ),
          initialOfflineChannel: channel,
          initialDiscoveryService: discoveryService,
        ),
      ),
    );
  }
}

class _OfflineAvatar extends StatelessWidget {
  final String imageUrl;

  const _OfflineAvatar({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    const size = 44.0;

    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.07),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: TwitchCachedImageLayer.avatar(
        imageUrl: imageUrl,
        size: size,
        cacheWidth: 88,
        cacheHeight: 88,
        fallbackColor: Colors.white.withValues(alpha: 0.07),
        fallbackIconColor: Colors.white38,
        fallbackIconSize: 24,
      ),
    );
  }
}

class _OfflineActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  const _OfflineActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 34,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 15),
        label: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: twitchChatTextStyle(
            const TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
          ),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: TwitchUiColors.primarySoft,
          side: BorderSide(
            color: TwitchUiColors.primary.withValues(alpha: 0.55),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          textStyle: twitchChatTextStyle(
            const TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}
