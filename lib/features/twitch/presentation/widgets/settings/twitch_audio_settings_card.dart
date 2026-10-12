import 'dart:async';
import 'package:flutter/material.dart';

import '../../../services/playback/twitch_audio_settings.dart';
import '../../localization/vioclass_localizations.dart';

class TwitchAudioSettingsCard extends StatefulWidget {
  const TwitchAudioSettingsCard({super.key});

  @override
  State<TwitchAudioSettingsCard> createState() =>
      _TwitchAudioSettingsCardState();
}

class _TwitchAudioSettingsCardState extends State<TwitchAudioSettingsCard> {
  TwitchAudioConfig _draft = twitchAudioSettings.config;

  @override
  void initState() {
    super.initState();
    twitchAudioSettings.addListener(_changed);
    unawaited(twitchAudioSettings.load());
  }

  void _changed() {
    if (!mounted) return;
    setState(() => _draft = twitchAudioSettings.config);
  }

  @override
  void dispose() {
    twitchAudioSettings.removeListener(_changed);
    super.dispose();
  }

  void _commit(TwitchAudioConfig config) {
    unawaited(twitchAudioSettings.update(config));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.vio;
    final active = _draft.enabled && !twitchAudioSettings.busy;
    final filtersActive = active && twitchAudioSettings.filtersAvailable;
    return Container(
      padding: const EdgeInsets.all(13),
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
                child: Text(
                  l10n.t('音效'),
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              TextButton(
                onPressed: twitchAudioSettings.busy
                    ? null
                    : () => _commit(TwitchAudioConfig()),
                child: Text(l10n.t('重設')),
              ),
              Switch(
                value: _draft.enabled,
                onChanged: twitchAudioSettings.busy
                    ? null
                    : (value) => _commit(_draft.copyWith(enabled: value)),
              ),
            ],
          ),
          Text(
            l10n.t('預設維持原音；播放中可調整，關閉即可還原。'),
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
          const SizedBox(height: 12),
          _slider(
            context,
            label: '音量增益',
            value: _draft.gainDb,
            min: 0,
            max: 6,
            divisions: 12,
            active: active,
            onChanged: (v) =>
                setState(() => _draft = _draft.copyWith(gainDb: v)),
            onEnd: (v) => _commit(_draft.copyWith(gainDb: v)),
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.t('減少突然大聲')),
            subtitle: Text(l10n.t('柔和壓縮大音量；可能降低音樂的動態感。')),
            value: twitchAudioSettings.filtersAvailable && _draft.compressor,
            onChanged: filtersActive
                ? (v) => _commit(_draft.copyWith(compressor: v))
                : null,
          ),
          const SizedBox(height: 8),
          Text(
            l10n.t('五段等化器'),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          for (var i = 0; i < 5; i++)
            _slider(
              context,
              label: const [
                '低音 · 125 Hz',
                '中低音 · 500 Hz',
                '中音 · 1 kHz',
                '中高音 · 4 kHz',
                '高音 · 8 kHz',
              ][i],
              value: _draft.bands[i],
              min: -6,
              max: 6,
              divisions: 24,
              active: filtersActive,
              onChanged: (v) => setState(() {
                final bands = _draft.bands.toList()..[i] = v;
                _draft = _draft.copyWith(bands: bands);
              }),
              onEnd: (v) {
                final bands = _draft.bands.toList()..[i] = v;
                _commit(_draft.copyWith(bands: bands));
              },
            ),
          Text(
            l10n.t(
              twitchAudioSettings.filtersAvailable
                  ? '音效啟用時會限制數位峰值；無法修復來源破音，請先降低音量測試。'
                  : '此平台尚未啟用防爆音與等化器。增益可使用，但大音量可能破音；請先降低音量測試。',
            ),
            style: const TextStyle(color: Colors.white54, fontSize: 11),
          ),
          if (twitchAudioSettings.error case final String message) ...[
            const SizedBox(height: 8),
            Text(l10n.t(message), style: const TextStyle(color: Colors.orange)),
          ],
        ],
      ),
    );
  }

  Widget _slider(
    BuildContext context, {
    required String label,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required bool active,
    required ValueChanged<double> onChanged,
    required ValueChanged<double> onEnd,
  }) => Column(
    children: [
      Row(
        children: [
          Expanded(child: Text(context.vio.t(label))),
          Text(
            '${value > 0 ? '+' : ''}${value.toStringAsFixed(1)} dB',
            style: const TextStyle(color: Colors.white70),
          ),
        ],
      ),
      Slider(
        value: value,
        min: min,
        max: max,
        divisions: divisions,
        onChanged: active ? onChanged : null,
        onChangeEnd: active ? onEnd : null,
      ),
    ],
  );
}
