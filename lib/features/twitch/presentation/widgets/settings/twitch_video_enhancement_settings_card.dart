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
                      l10n.t('所有增強都由你手動開啟；可在播放中切換，不需重開直播'),
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
                    l10n.t('主要增強模式'),
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
                  const SizedBox(height: 14),
                  Divider(
                    height: 1,
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    l10n.t('進階處理'),
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    l10n.t('可疊加在主要模式上；平板或低階裝置建議逐項開啟測試效能。'),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.42),
                      fontSize: 10.5,
                      height: 1.35,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _EnhancementToggle(
                    title: l10n.t('Chroma Enhance'),
                    subtitle: l10n.t('使用 CfL 重建色度細節，改善彩色文字、HUD 與紅藍邊緣。'),
                    loadLabel: l10n.t('中負載'),
                    value: controller.videoChromaEnhance,
                    onChanged: controller.setVideoChromaEnhance,
                  ),
                  _EnhancementToggle(
                    title: l10n.t('Deband'),
                    subtitle: l10n.t('使用 mpv 內建 deband 減少漸層色帶與直播壓縮造成的 banding。'),
                    loadLabel: l10n.t('低～中負載'),
                    value: controller.videoDeband,
                    onChanged: controller.setVideoDeband,
                  ),
                  _EnhancementToggle(
                    title: l10n.t('Adaptive Sharpen'),
                    subtitle: l10n.t('超分後再做自適應銳化；可能增加高頻細節與 GPU 負載。'),
                    loadLabel: l10n.t('中負載'),
                    value: controller.videoSharpen,
                    onChanged: controller.setVideoSharpen,
                  ),
                  if (controller.videoEnhancementUsesShader) ...[
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
                            l10n.t('第一次啟用需要的 shader 會下載並快取；之後可離線使用。'),
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
      TwitchVideoEnhancementMode.fsr => l10n.t('AMD FSR 1.0（低～中負載）'),
      TwitchVideoEnhancementMode.ssimSuperRes =>
        l10n.t('SSimSuperRes（中負載）'),
      TwitchVideoEnhancementMode.artCnn => l10n.t('ArtCNN C4F16（高負載）'),
      TwitchVideoEnhancementMode.anime4kFast =>
        l10n.t('Anime4K Fast（中負載）'),
      TwitchVideoEnhancementMode.anime4kHigh =>
        l10n.t('Anime4K High（高負載）'),
    };
  }

  String _modeDescription(
    VioClassLocalizations l10n,
    TwitchVideoEnhancementMode mode,
  ) {
    return switch (mode) {
      TwitchVideoEnhancementMode.lanczos =>
        l10n.t('基本 GPU 縮放，效能消耗最低，適合平板、低階裝置或高幀率直播。'),
      TwitchVideoEnhancementMode.ewaLanczos =>
        l10n.t('比一般 Lanczos 更平滑，適合真人、遊戲與攝影內容。'),
      TwitchVideoEnhancementMode.ewaLanczosSharp =>
        l10n.t('兼顧細節與效能的銳化縮放，適合大多數直播內容。'),
      TwitchVideoEnhancementMode.ewaLanczos4Sharpest =>
        l10n.t('更強的銳利度，文字與遊戲 UI 清楚，但可能增加 ringing。'),
      TwitchVideoEnhancementMode.fsr =>
        l10n.t('AMD FidelityFX FSR 1.0 shader，適合 480p/720p 放大到高解析螢幕。'),
      TwitchVideoEnhancementMode.ssimSuperRes =>
        l10n.t('修正一般縮放造成的 ringing 並恢復局部細節；真人與遊戲都適合。'),
      TwitchVideoEnhancementMode.artCnn =>
        l10n.t('CNN 2× luma 超分模式，低解析來源細節較強，但 GPU 負載明顯較高。'),
      TwitchVideoEnhancementMode.anime4kFast =>
        l10n.t('Anime4K 輕量模式，針對動畫線條與低解析動畫來源。'),
      TwitchVideoEnhancementMode.anime4kHigh =>
        l10n.t('Anime4K 高品質模式，GPU 負載最高；桌機或高階 GPU 建議使用。'),
    };
  }
}

class _EnhancementToggle extends StatelessWidget {
  final String title;
  final String subtitle;
  final String loadLabel;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _EnhancementToggle({
    required this.title,
    required this.subtitle,
    required this.loadLabel,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 7),
      padding: const EdgeInsets.fromLTRB(10, 8, 7, 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(width: 7),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.07),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        loadLabel,
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.42),
                    fontSize: 10.5,
                    height: 1.3,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}
