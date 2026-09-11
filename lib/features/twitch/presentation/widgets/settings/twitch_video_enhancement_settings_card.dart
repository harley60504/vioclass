import 'package:flutter/material.dart';

import '../../../services/playback/twitch_video_enhancement.dart';
import '../../localization/vioclass_localizations.dart';
import '../../settings/twitch_player_settings_controller.dart';
import '../../theme/twitch_ui_tokens.dart';

class TwitchVideoEnhancementSettingsCard extends StatelessWidget {
  final TwitchPlayerSettingsController controller;

  const TwitchVideoEnhancementSettingsCard({
    super.key,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.vio;
    final enabled = controller.videoEnhancementEnabled;
    final busy = controller.videoEnhancementBusy;

    return Container(
      padding: const EdgeInsets.fromLTRB(13, 12, 13, 13),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.045),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.09)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.t('影像增強 / 超分辨率'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      l10n.t('使用 mpv GPU scaler 或 GLSL shader；可在播放中切換，不需重開直播'),
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              if (busy)
                const Padding(
                  padding: EdgeInsets.only(right: 10),
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: TwitchUiColors.primarySoft,
                    ),
                  ),
                ),
              Switch(
                value: enabled,
                onChanged: busy ? null : controller.setVideoEnhancementEnabled,
              ),
            ],
          ),
          const SizedBox(height: 12),
          IgnorePointer(
            ignoring: busy || !enabled,
            child: AnimatedOpacity(
              opacity: enabled ? 1 : 0.45,
              duration: const Duration(milliseconds: 160),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.t('增強模式'),
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 7),
                  DropdownButtonFormField<TwitchVideoEnhancementMode>(
                    value: controller.videoEnhancementMode,
                    isExpanded: true,
                    dropdownColor: const Color(0xFF18151F),
                    decoration: InputDecoration(
                      isDense: true,
                      filled: true,
                      fillColor: Colors.black.withValues(alpha: 0.20),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 11,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(11),
                        borderSide: BorderSide(
                          color: Colors.white.withValues(alpha: 0.09),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(11),
                        borderSide: BorderSide(
                          color: Colors.white.withValues(alpha: 0.09),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(11),
                        borderSide: const BorderSide(
                          color: TwitchUiColors.primarySoft,
                        ),
                      ),
                    ),
                    items: [
                      for (final mode in TwitchVideoEnhancementMode.values)
                        DropdownMenuItem<TwitchVideoEnhancementMode>(
                          value: mode,
                          child: Text(
                            _modeLabel(l10n, mode),
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                    ],
                    onChanged: (mode) {
                      if (mode != null) {
                        controller.setVideoEnhancementMode(mode);
                      }
                    },
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _modeDescription(l10n, controller.videoEnhancementMode),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.48),
                      fontSize: 11,
                      height: 1.35,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (controller.videoEnhancementMode.usesShader) ...[
                    const SizedBox(height: 7),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 1),
                          child: Icon(
                            Icons.cloud_download_outlined,
                            color: Colors.white38,
                            size: 15,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            l10n.t('第一次啟用此 shader 會下載並快取檔案；之後可離線使用。'),
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.40),
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _modeLabel(
    VioClassLocalizations l10n,
    TwitchVideoEnhancementMode mode,
  ) {
    return switch (mode) {
      TwitchVideoEnhancementMode.lanczos => l10n.t('Lanczos（低負載）'),
      TwitchVideoEnhancementMode.ewaLanczos => l10n.t('EWA Lanczos（高品質）'),
      TwitchVideoEnhancementMode.ewaLanczosSharp =>
        l10n.t('EWA Lanczos Sharp（推薦）'),
      TwitchVideoEnhancementMode.ewaLanczos4Sharpest =>
        l10n.t('EWA Lanczos 4 Sharpest（最銳利）'),
      TwitchVideoEnhancementMode.fsr => l10n.t('AMD FSR 1.0（一般超分）'),
      TwitchVideoEnhancementMode.anime4kFast =>
        l10n.t('Anime4K Fast（動畫快速）'),
      TwitchVideoEnhancementMode.anime4kHigh =>
        l10n.t('Anime4K High（動畫高品質）'),
    };
  }

  String _modeDescription(
    VioClassLocalizations l10n,
    TwitchVideoEnhancementMode mode,
  ) {
    return switch (mode) {
      TwitchVideoEnhancementMode.lanczos =>
        l10n.t('基本 GPU 縮放，效能消耗最低，適合低階裝置或高幀率直播。'),
      TwitchVideoEnhancementMode.ewaLanczos =>
        l10n.t('比一般 Lanczos 更平滑，適合真人、遊戲與攝影內容。'),
      TwitchVideoEnhancementMode.ewaLanczosSharp =>
        l10n.t('兼顧細節與效能的銳化縮放，適合大多數直播內容。'),
      TwitchVideoEnhancementMode.ewaLanczos4Sharpest =>
        l10n.t('更強的銳利度，文字與遊戲 UI 清楚，但可能增加 ringing。'),
      TwitchVideoEnhancementMode.fsr =>
        l10n.t('AMD FidelityFX FSR 1.0 shader，適合 480p/720p 放大到高解析螢幕。'),
      TwitchVideoEnhancementMode.anime4kFast =>
        l10n.t('Anime4K 輕量模式，針對動畫線條與低解析動畫來源。'),
      TwitchVideoEnhancementMode.anime4kHigh =>
        l10n.t('Anime4K 高品質模式，GPU 負載最高；桌機或高階 GPU 建議使用。'),
    };
  }
}
