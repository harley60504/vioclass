import 'package:flutter/material.dart';

import '../../../models/discovery/twitch_stream_header_metadata.dart';
import '../../../models/discovery/twitch_live_stream.dart';
import '../../../services/discovery/twitch_discovery_service.dart';
import '../../localization/vioclass_localizations.dart';
import '../../pages/twitch_channel_page.dart';
import '../../pages/twitch_watch_page.dart';
import '../../theme/twitch_ui_tokens.dart';
import '../shared/twitch_cached_image_layer.dart';

class TwitchOfflineChannelCard extends StatelessWidget {
  final TwitchFollowedChannel channel;
  final TwitchDiscoveryService discoveryService;
  final bool? initialKnownFollowing;

  const TwitchOfflineChannelCard({
    super.key,
    required this.channel,
    required this.discoveryService,
    this.initialKnownFollowing,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.vio;
    final description = channel.description.trim();
    return Material(
      color: TwitchUiColors.surfaceCard,
      borderRadius: BorderRadius.circular(TwitchUiRadius.lg),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openMediaWatchPage(context),
        child: Container(
          padding: const EdgeInsets.all(TwitchUiSpacing.space16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(TwitchUiRadius.lg),
            border: Border.all(color: TwitchUiColors.borderSubtle),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _OfflineAvatar(imageUrl: channel.profileImageUrl.trim()),
                  const SizedBox(width: TwitchUiSpacing.space12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          channel.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: TwitchUiColors.textPrimary,
                            fontSize: TwitchUiFontSize.heading,
                            fontWeight: TwitchUiFontWeight.strong,
                          ),
                        ),
                        if (channel.channelLogin.isNotEmpty) ...[
                          const SizedBox(height: TwitchUiSpacing.space4),
                          Text(
                            channel.channelLogin,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: TwitchUiColors.textMuted,
                              fontSize: TwitchUiFontSize.meta,
                              fontWeight: TwitchUiFontWeight.medium,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const _OfflineStatusChip(),
                ],
              ),
              const SizedBox(height: TwitchUiSpacing.space12),
              Expanded(
                child: Text(
                  description.isEmpty
                      ? l10n.t('目前未開台，點擊後會先播放最新 VOD；沒有 VOD 則顯示關台圖。')
                      : description,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: TwitchUiColors.textSecondary,
                    fontSize: TwitchUiFontSize.bodyCompact,
                    height: 1.4,
                    fontWeight: TwitchUiFontWeight.regular,
                  ),
                ),
              ),
              const SizedBox(height: TwitchUiSpacing.space12),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => _openMediaWatchPage(context),
                      icon: const Icon(Icons.play_arrow_rounded, size: 17),
                      label: Text(l10n.t('觀看')),
                    ),
                  ),
                  const SizedBox(width: TwitchUiSpacing.space8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _openChannelPage(context, 2),
                      icon: const Icon(Icons.video_library_rounded, size: 16),
                      label: Text(l10n.t('媒體庫')),
                    ),
                  ),
                ],
              ),
            ],
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
          initialOfflineFallbackAllowed: true,
          initialKnownFollowing: initialKnownFollowing,
        ),
      ),
    );
  }
}

class _OfflineStatusChip extends StatelessWidget {
  const _OfflineStatusChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: TwitchUiSpacing.space8,
        vertical: TwitchUiSpacing.space4,
      ),
      decoration: BoxDecoration(
        color: TwitchUiColors.surfaceInteractive,
        borderRadius: BorderRadius.circular(TwitchUiRadius.pill),
        border: Border.all(color: TwitchUiColors.borderSubtle),
      ),
      child: const Text(
        'OFFLINE',
        style: TextStyle(
          color: TwitchUiColors.textMuted,
          fontSize: TwitchUiFontSize.micro,
          fontWeight: TwitchUiFontWeight.strong,
          letterSpacing: 0.4,
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
        color: TwitchUiColors.surfaceRaised,
        border: Border.all(color: TwitchUiColors.border),
      ),
      child: TwitchCachedImageLayer.avatar(
        imageUrl: imageUrl,
        size: size,
        cacheWidth: 88,
        cacheHeight: 88,
        fallbackColor: TwitchUiColors.surfaceRaised,
        fallbackIconColor: TwitchUiColors.textFaint,
        fallbackIconSize: 24,
      ),
    );
  }
}
