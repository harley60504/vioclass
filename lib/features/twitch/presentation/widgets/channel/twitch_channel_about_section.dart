import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../models/discovery/twitch_live_stream.dart';
import '../../../models/discovery/twitch_stream_header_metadata.dart';
import '../../localization/vioclass_localizations.dart';
import '../../theme/twitch_ui_tokens.dart';
import '../shared/twitch_cached_image_layer.dart';

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
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
      color: const Color(0xFF0E0E10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              _Avatar(imageUrl: metadata.profileImageUrl),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      metadata.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      metadata.channelLogin,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (cleanDescription.isNotEmpty) ...<Widget>[
            const SizedBox(height: 14),
            Text(
              cleanDescription,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
                height: 1.45,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          const SizedBox(height: 20),
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
    return ClipOval(
      child: TwitchCachedImageLayer(
        imageUrl: imageUrl,
        width: 54,
        height: 54,
        fit: BoxFit.cover,
        fallbackColor: Colors.white.withValues(alpha: 0.08),
        fallbackIcon: Icons.person_rounded,
        fallbackIconColor: Colors.white38,
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
        padding: EdgeInsets.symmetric(vertical: 18),
        child: Center(
          child: CircularProgressIndicator(color: TwitchUiColors.primary),
        ),
      );
    }

    final error = errorText?.trim();
    if (panels.isEmpty && error != null && error.isNotEmpty) {
      return OutlinedButton.icon(
        onPressed: onRetry,
        icon: const Icon(Icons.image_not_supported_outlined, size: 16),
        label: Text(context.vio.t('關於圖片讀取失敗')),
        style: OutlinedButton.styleFrom(
          foregroundColor: TwitchUiColors.primarySoft,
          side: BorderSide(
            color: TwitchUiColors.primary.withValues(alpha: 0.45),
          ),
        ),
      );
    }

    if (panels.isEmpty && socialLinks.isEmpty) {
      return Text(
        context.vio.t('這個頻道目前沒有關於面板。'),
        style: const TextStyle(
          color: Colors.white38,
          fontSize: 12.5,
          fontWeight: FontWeight.w800,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (socialLinks.isNotEmpty) ...<Widget>[
          _SocialLinkSection(links: socialLinks),
          const SizedBox(height: 20),
        ],
        if (panels.isNotEmpty) ...<Widget>[
          Row(
            children: <Widget>[
              const Icon(
                Icons.dashboard_customize_rounded,
                color: TwitchUiColors.primarySoft,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                context.vio.t('關於面板'),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = (constraints.maxWidth / 330).floor().clamp(1, 3);
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: panels.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  mainAxisExtent: columns == 1 ? 340 : 314,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                ),
                itemBuilder: (context, index) =>
                    _PanelCard(panel: panels[index]),
              );
            },
          ),
        ],
      ],
    );
  }
}

class _SocialLinkSection extends StatelessWidget {
  final List<TwitchChannelSocialLink> links;

  const _SocialLinkSection({required this.links});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            const Icon(
              Icons.hub_outlined,
              color: TwitchUiColors.primarySoft,
              size: 18,
            ),
            const SizedBox(width: 8),
            Text(
              context.vio.t('社群連結'),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: links.map((link) => _SocialLinkCard(link: link)).toList(),
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
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openExternalUrl(link.url),
        child: Ink(
          height: 42,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.030),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: visual.color.withValues(alpha: 0.18)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(visual.icon, color: visual.color, size: 17),
              const SizedBox(width: 8),
              Text(
                link.title.isEmpty ? link.name : link.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.open_in_new_rounded,
                color: Colors.white.withValues(alpha: 0.45),
                size: 14,
              ),
            ],
          ),
        ),
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
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: linkUrl.isEmpty ? null : () => _openExternalUrl(linkUrl),
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[
                Colors.white.withValues(alpha: 0.045),
                Colors.white.withValues(alpha: 0.014),
              ],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.070)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return TwitchCachedImageLayer(
                      imageUrl: imageUrl,
                      width: constraints.maxWidth,
                      height: constraints.maxHeight,
                      fit: BoxFit.contain,
                      fallbackColor: Colors.white.withValues(alpha: 0.045),
                      fallbackIcon: Icons.article_outlined,
                      fallbackIconColor: Colors.white38,
                      fallbackIconSize: 34,
                    );
                  },
                ),
              ),
              if (panel.title.isNotEmpty ||
                  panel.description.isNotEmpty ||
                  linkUrl.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 9, 12, 11),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          _panelLabel(context, panel),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            height: 1.2,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      if (linkUrl.isNotEmpty) ...<Widget>[
                        const SizedBox(width: 8),
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
        ),
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
      color: Color(0xFFFF5A5F),
    );
  }
  if (key.contains('discord')) {
    return const _SocialVisual(
      icon: Icons.forum_rounded,
      color: Color(0xFF7B86FF),
    );
  }
  if (key.contains('facebook')) {
    return const _SocialVisual(
      icon: Icons.facebook_rounded,
      color: Color(0xFF5EA2FF),
    );
  }
  if (key.contains('instagram')) {
    return const _SocialVisual(
      icon: Icons.camera_alt_rounded,
      color: Color(0xFFFF7AC8),
    );
  }
  if (key.contains('twitter') || key == 'x') {
    return const _SocialVisual(
      icon: Icons.alternate_email_rounded,
      color: Color(0xFF9FB4C7),
    );
  }
  if (key.contains('tiktok')) {
    return const _SocialVisual(
      icon: Icons.music_note_rounded,
      color: Color(0xFF5FFFE0),
    );
  }
  return const _SocialVisual(
    icon: Icons.language_rounded,
    color: Color(0xFF9FB4C7),
  );
}

Future<void> _openExternalUrl(String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null) return;
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}
