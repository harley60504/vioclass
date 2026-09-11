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
                      color: Colors.white.withValues(alpha: 0.52),
                      fontSize: 11,
                      height: 1.42,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 1),
                        child: Icon(
                          Icons.info_outline_rounded,
                          color: Colors.white30,
                          size: 14,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          l10n.t('來源解析度低於螢幕解析度時最有感；來源已接近原生解析度時，超分收益會變小。'),
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.36),
                            fontSize: 10.25,
                            height: 1.35,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
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
                    subtitle: l10n.t('超分後再做自適應銳化；讓邊緣更清楚，但過強可能放大壓縮雜訊。'),
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
      TwitchVideoEnhancementMode.lanczos => l10n.t('Lanczos｜最快、最穩'),
      TwitchVideoEnhancementMode.ewaLanczos => l10n.t('EWA Lanczos｜自然平滑'),
      TwitchVideoEnhancementMode.ewaLanczosSharp =>
        l10n.t('EWA Sharp｜均衡推薦'),
      TwitchVideoEnhancementMode.ewaLanczos4Sharpest =>
        l10n.t('EWA 4 Sharpest｜文字最銳利'),
      TwitchVideoEnhancementMode.fsr => l10n.t('AMD FSR 1.0｜低解析放大'),
      TwitchVideoEnhancementMode.ssimSuperRes =>
        l10n.t('SSimSuperRes｜自然細節修復'),
      TwitchVideoEnhancementMode.artCnn => l10n.t('ArtCNN C4F16｜AI 細節強化'),
      TwitchVideoEnhancementMode.anime4kFast =>
        l10n.t('Anime4K Fast｜動畫輕量'),
      TwitchVideoEnhancementMode.anime4kHigh =>
        l10n.t('Anime4K High｜動畫高品質'),
    };
  }

  String _modeDescription(
    VioClassLocalizations l10n,
    TwitchVideoEnhancementMode mode,
  ) {
    return switch (mode) {
      TwitchVideoEnhancementMode.lanczos => l10n.t(
        '負載：低。特點：傳統高品質縮放，畫面乾淨、延遲與 GPU 消耗最低。適合：平板、低階 GPU、1080p60/1440p 高幀率直播。缺點：不會主動補出新細節。',
      ),
      TwitchVideoEnhancementMode.ewaLanczos => l10n.t(
        '負載：低～中。特點：比 Lanczos 更自然平滑，斜線與曲線較柔順。適合：真人、攝影、一般遊戲。缺點：銳利感較保守，文字與細小 HUD 不會特別突出。',
      ),
      TwitchVideoEnhancementMode.ewaLanczosSharp => l10n.t(
        '負載：中。特點：在自然感與銳利度之間取得平衡，是一般直播最通用的選擇。適合：遊戲、真人、聊天台。缺點：不是 AI 超分，低解析來源的細節提升有限。',
      ),
      TwitchVideoEnhancementMode.ewaLanczos4Sharpest => l10n.t(
        '負載：中。特點：EWA 系列最強銳化，文字、遊戲 UI、細線最清楚。適合：策略遊戲、介面很多的遊戲、桌面內容。缺點：高對比邊緣較容易出現 ringing／白邊。',
      ),
      TwitchVideoEnhancementMode.fsr => l10n.t(
        '負載：低～中。特點：AMD FSR 1.0 空間超分，放大速度快並帶有邊緣強化。適合：480p／720p 遊戲直播放大到 1080p 或更高。缺點：壓縮雜訊也可能一起被銳化，真人畫面有時偏硬。',
      ),
      TwitchVideoEnhancementMode.ssimSuperRes => l10n.t(
        '負載：中。特點：著重結構與局部對比，能抑制一般縮放的 ringing，同時恢復較自然的細節。適合：真人、攝影、3D 遊戲。缺點：提升較自然，不會像 ArtCNN 或 Anime4K 那麼「一眼變銳」。',
      ),
      TwitchVideoEnhancementMode.artCnn => l10n.t(
        '負載：高。特點：CNN 亮度細節重建，對低解析紋理、細線與文字的提升最明顯。適合：480p／720p、舊遊戲或低 bitrate 來源。缺點：GPU 消耗最高之一，平板可能掉幀或發熱。',
      ),
      TwitchVideoEnhancementMode.anime4kFast => l10n.t(
        '負載：中。特點：針對 2D 線稿、字幕與色塊做快速強化，邊線會比一般 scaler 更乾淨。適合：動畫、VTuber、2D 遊戲。缺點：真人皮膚與自然影像可能顯得不自然。',
      ),
      TwitchVideoEnhancementMode.anime4kHigh => l10n.t(
        '負載：高。特點：比 Fast 更積極地重建動畫線條與細節，2D 內容最銳利。適合：低解析動畫、VTuber、桌機高階 GPU。缺點：負載高，真人／3D 內容可能過度銳化。',
      ),
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
