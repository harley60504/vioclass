import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../models/discovery/twitch_live_stream.dart';
import '../../../models/discovery/twitch_stream_header_metadata.dart';
import '../../localization/vioclass_localizations.dart';
import '../../theme/twitch_ui_tokens.dart';
import '../shared/twitch_cached_image_layer.dart';
import '../shared/twitch_ui_primitives.dart';

class TwitchChannelAboutSection extends StatelessWidget {
  final TwitchStreamHeaderMetadata metadata;
  final String description;
  final List<TwitchChannelPanel> panels;
  final List<TwitchChannelSocialLink> socialLinks;
  final bool loading;
  final String? errorText;
  final VoidCallback onRetry;

  const TwitchChannelAboutSection({
    super.key,
    required this.metadata,
    this.description = '',
    required this.panels,
    required this.socialLinks,
    required this.loading,
    required this.errorText,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final cleanDescription = description.trim();
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
      color: TwitchUiColors.appBackground,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _Avatar(imageUrl: metadata.profileImageUrl),
              const SizedBox(width: TwitchUiSpacing.space12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      metadata.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: TwitchUiColors.textPrimary,
                        fontSize: TwitchUiFontSize.title,
                        fontWeight: TwitchUiFontWeight.strong,
                      ),
                    ),
                    const SizedBox(height: TwitchUiSpacing.space4),
                    Text(
                      metadata.channelLogin,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: TwitchUiColors.textMuted,
                        fontSize: TwitchUiFontSize.bodyCompact,
                        fontWeight: TwitchUiFontWeight.medium,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (cleanDescription.isNotEmpty) ...[
            const SizedBox(height: TwitchUiSpacing.space16),
            Text(
              cleanDescription,
              style: const TextStyle(
                color: TwitchUiColors.textSecondary,
                fontSize: TwitchUiFontSize.body,
                height: 1.5,
                fontWeight: TwitchUiFontWeight.regular,
              ),
            ),
          ],
          const SizedBox(height: TwitchUiSpacing.space24),
          _PanelSection(
            panels: panels,
            socialLinks: socialLinks,
            loading: loading,
            errorText: errorText,
            onRetry: onRetry,
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String imageUrl;

  const _Avatar({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: TwitchUiColors.border),
      ),
      child: TwitchCachedImageLayer.avatar(
        imageUrl: imageUrl,
        size: 56,
        cacheWidth: 112,
        cacheHeight: 112,
        fallbackColor: TwitchUiColors.surfaceRaised,
        fallbackIconColor: TwitchUiColors.textFaint,
        fallbackIconSize: 26,
      ),
    );
  }
}

class _PanelSection extends StatelessWidget {
  final List<TwitchChannelPanel> panels;
  final List<TwitchChannelSocialLink> socialLinks;
  final bool loading;
  final String? errorText;
  final VoidCallback onRetry;

  const _PanelSection({
    required this.panels,
    required this.socialLinks,
    required this.loading,
    required this.errorText,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: TwitchUiSpacing.space24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final error = errorText?.trim();
    if (panels.isEmpty && error != null && error.isNotEmpty) {
      return OutlinedButton.icon(
        onPressed: onRetry,
        icon: const Icon(Icons.refresh_rounded, size: 16),
        label: Text(context.vio.t('關於圖片讀取失敗')),
      );
    }
    if (panels.isEmpty && socialLinks.isEmpty) {
      return Text(
        context.vio.t('這個頻道目前沒有關於面板。'),
        style: const TextStyle(
          color: TwitchUiColors.textMuted,
          fontSize: TwitchUiFontSize.bodyCompact,
          fontWeight: TwitchUiFontWeight.medium,
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (socialLinks.isNotEmpty) ...[
          _SectionTitle(icon: Icons.hub_outlined, label: context.vio.t('社群連結')),
          const SizedBox(height: TwitchUiSpacing.space12),
          Wrap(
            spacing: TwitchUiSpacing.space8,
            runSpacing: TwitchUiSpacing.space8,
            children: socialLinks
                .map((link) => _SocialLinkCard(link: link))
                .toList(growable: false),
          ),
          const SizedBox(height: TwitchUiSpacing.space24),
        ],
        if (panels.isNotEmpty) ...[
          _SectionTitle(
            icon: Icons.dashboard_customize_rounded,
            label: context.vio.t('關於面板'),
          ),
          const SizedBox(height: TwitchUiSpacing.space12),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = (constraints.maxWidth / 330).floor().clamp(1, 3);
              final cardWidth =
                  (constraints.maxWidth - (columns - 1) * 12) / columns;
              return Wrap(
                spacing: TwitchUiSpacing.space12,
                runSpacing: TwitchUiSpacing.space12,
                children: panels
                    .map(
                      (panel) => SizedBox(
                        width: cardWidth,
                        child: _PanelCard(panel: panel),
                      ),
                    )
                    .toList(growable: false),
              );
            },
          ),
        ],
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String label;

  const _SectionTitle({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: TwitchUiColors.primarySoft, size: 18),
        const SizedBox(width: TwitchUiSpacing.space8),
        Text(
          label,
          style: const TextStyle(
            color: TwitchUiColors.textPrimary,
            fontSize: TwitchUiFontSize.heading,
            fontWeight: TwitchUiFontWeight.strong,
          ),
        ),
      ],
    );
  }
}

class _SocialLinkCard extends StatelessWidget {
  final TwitchChannelSocialLink link;

  const _SocialLinkCard({required this.link});

  @override
  Widget build(BuildContext context) {
    final visual = _socialVisualFor(link.name);
    return TwitchUiInteractiveSurface(
      onTap: () => _openExternalUrl(link.url),
      radius: TwitchUiRadius.md,
      padding: const EdgeInsets.symmetric(
        horizontal: TwitchUiSpacing.space12,
        vertical: TwitchUiSpacing.space8,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(visual.icon, color: visual.color, size: 17),
          const SizedBox(width: TwitchUiSpacing.space8),
          Text(
            link.title.isEmpty ? link.name : link.title,
            style: const TextStyle(
              color: TwitchUiColors.textPrimary,
              fontSize: TwitchUiFontSize.bodyCompact,
              fontWeight: TwitchUiFontWeight.strong,
            ),
          ),
          const SizedBox(width: TwitchUiSpacing.space8),
          const Icon(
            Icons.open_in_new_rounded,
            color: TwitchUiColors.textMuted,
            size: 14,
          ),
        ],
      ),
    );
  }
}

class _PanelCard extends StatelessWidget {
  final TwitchChannelPanel panel;

  const _PanelCard({required this.panel});

  @override
  Widget build(BuildContext context) {
    final imageUrl = panel.imageUrl.trim();
    final linkUrl = panel.linkUrl.trim();
    return TwitchUiInteractiveSurface(
      onTap: linkUrl.isEmpty ? null : () => _openExternalUrl(linkUrl),
      radius: TwitchUiRadius.lg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: LayoutBuilder(
              builder: (context, constraints) => TwitchCachedImageLayer(
                imageUrl: imageUrl,
                width: constraints.maxWidth,
                height: constraints.maxHeight,
                fit: BoxFit.contain,
                fallbackColor: TwitchUiColors.surfaceRaised,
                fallbackIcon: Icons.article_outlined,
                fallbackIconColor: TwitchUiColors.textFaint,
                fallbackIconSize: 34,
              ),
            ),
          ),
          if (panel.title.isNotEmpty ||
              panel.description.isNotEmpty ||
              linkUrl.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _panelLabel(context, panel),
                      style: const TextStyle(
                        color: TwitchUiColors.textSecondary,
                        fontSize: TwitchUiFontSize.bodyCompact,
                        height: 1.3,
                        fontWeight: TwitchUiFontWeight.medium,
                      ),
                    ),
                  ),
                  if (linkUrl.isNotEmpty) ...[
                    const SizedBox(width: TwitchUiSpacing.space8),
                    const Icon(
                      Icons.open_in_new_rounded,
                      color: TwitchUiColors.primarySoft,
                      size: 16,
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _panelLabel(BuildContext context, TwitchChannelPanel panel) {
    if (panel.title.isNotEmpty) return panel.title;
    if (panel.description.isNotEmpty) return panel.description;
    return context.vio.t('開啟連結');
  }
}

class _SocialVisual {
  final IconData icon;
  final Color color;

  const _SocialVisual({required this.icon, required this.color});
}

_SocialVisual _socialVisualFor(String name) {
  final key = name.trim().toLowerCase();
  if (key.contains('youtube')) {
    return const _SocialVisual(
      icon: Icons.smart_display_rounded,
      color: Color(0xFFFF5D73),
    );
  }
  if (key.contains('discord')) {
    return const _SocialVisual(
      icon: Icons.forum_rounded,
      color: Color(0xFF8D7BFF),
    );
  }
  if (key.contains('facebook')) {
    return const _SocialVisual(
      icon: Icons.facebook_rounded,
      color: Color(0xFF68A7FF),
    );
  }
  if (key.contains('instagram')) {
    return const _SocialVisual(
      icon: Icons.camera_alt_rounded,
      color: Color(0xFFE887C5),
    );
  }
  if (key.contains('twitter') || key == 'x') {
    return const _SocialVisual(
      icon: Icons.alternate_email_rounded,
      color: Color(0xFFAFB5C1),
    );
  }
  if (key.contains('tiktok')) {
    return const _SocialVisual(
      icon: Icons.music_note_rounded,
      color: Color(0xFF5CC8FF),
    );
  }
  return const _SocialVisual(
    icon: Icons.language_rounded,
    color: Color(0xFFAFB5C1),
  );
}

Future<void> _openExternalUrl(String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null) return;
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}
