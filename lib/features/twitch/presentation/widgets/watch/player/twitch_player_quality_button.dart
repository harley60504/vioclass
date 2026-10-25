import 'dart:async';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import '../../../../models/playback/twitch_m3u8_variant.dart';
import '../../../localization/vioclass_localizations.dart';
import '../../../watch/controllers/twitch_adaptive_quality_controller.dart';
import 'twitch_player_popover_button.dart';

class QualityButton extends StatefulWidget {
  final List<TwitchM3u8Variant> variants;
  final TwitchM3u8Variant? currentVariant;
  final ValueChanged<TwitchM3u8Variant>? onChanged;
  final Player? player;
  final bool automaticEnabled;
  const QualityButton({
    super.key,
    required this.variants,
    required this.currentVariant,
    required this.onChanged,
    this.player,
    this.automaticEnabled = true,
  });
  @override
  State<QualityButton> createState() => _QualityButtonState();
}

class _QualityButtonState extends State<QualityButton> {
  late final TwitchAdaptiveQualityController _quality;
  bool _routeActive = true;
  String _page = 'home';

  String _rateLabel(double rate) =>
      '${rate == rate.roundToDouble() ? rate.toInt() : rate}×';

  Future<void> _setRate(double rate) async {
    try {
      await widget.player!.setRate(rate);
      if (mounted) setState(() {});
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.maybeOf(
          context,
        )?.showSnackBar(SnackBar(content: Text(context.vio.t('播放速度設定失敗'))));
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _quality = TwitchAdaptiveQualityController(
      variants: () => widget.variants,
      current: () => widget.currentVariant,
      playing: () => widget.player?.state.playing == true,
      buffering: () => widget.player?.state.buffering == true,
      enabled: () =>
          _routeActive && widget.automaticEnabled && widget.onChanged != null,
      select: (variant) => widget.onChanged?.call(variant),
    )..addListener(_changed);
    if (widget.player != null) {
      unawaited(_quality.start().catchError((Object _) {}));
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _routeActive =
        TickerMode.valuesOf(context).enabled &&
        (ModalRoute.of(context)?.isCurrent ?? true);
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _quality.removeListener(_changed);
    _quality.dispose();
    super.dispose();
  }

  void _run(Future<void> action) {
    unawaited(
      action.catchError((Object _) {
        if (mounted) {
          ScaffoldMessenger.maybeOf(context)?.showSnackBar(
            SnackBar(content: Text(context.vio.t('設定儲存失敗，請稍後再試。'))),
          );
        }
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.vio;
    final modeLabel = switch (_quality.mode) {
      TwitchQualityMode.auto => l10n.t('自動'),
      TwitchQualityMode.highest => l10n.t('最高畫質'),
      TwitchQualityMode.manual =>
        widget.currentVariant?.displayName ?? l10n.t('畫質'),
    };
    return PlayerPopoverButton(
      tooltip: '${l10n.t('畫質：')}$modeLabel',
      icon: Icons.tune_rounded,
      onOpen: () => setState(() => _page = 'home'),
      contentBuilder: (context, close) => ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(vertical: 6),
        children: [
          if (_page == 'home') ...[
            ListTile(
              dense: true,
              leading: const Icon(Icons.high_quality_outlined),
              title: Text(l10n.t('畫質')),
              subtitle: Text(modeLabel),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => setState(() => _page = 'quality'),
            ),
            ListTile(
              dense: true,
              enabled: widget.player != null,
              leading: const Icon(Icons.speed_rounded),
              title: Text(l10n.t('播放速度')),
              subtitle: Text(_rateLabel(widget.player?.state.rate ?? 1)),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: widget.player == null
                  ? null
                  : () => setState(() => _page = 'speed'),
            ),
          ] else ...[
            ListTile(
              dense: true,
              leading: const Icon(Icons.arrow_back_rounded),
              title: Text(l10n.t(_page == 'speed' ? '播放速度' : '畫質')),
              onTap: () => setState(() => _page = 'home'),
            ),
            const Divider(height: 1),
          ],
          if (_page == 'speed')
            for (final rate in (<double>{
              .5,
              .75,
              1,
              1.25,
              1.5,
              1.75,
              2,
              widget.player!.state.rate,
            }.toList()..sort()))
              ListTile(
                dense: true,
                leading: SizedBox(
                  width: 24,
                  child: widget.player!.state.rate == rate
                      ? const Icon(Icons.check_rounded)
                      : null,
                ),
                title: Text(_rateLabel(rate)),
                onTap: () {
                  close();
                  unawaited(_setRate(rate));
                },
              ),
          if (_page == 'quality' && widget.variants.isEmpty)
            ListTile(enabled: false, title: Text(l10n.t('尚未取得畫質')))
          else if (_page == 'quality') ...[
            if (widget.player != null)
              for (final mode in [
                TwitchQualityMode.highest,
                TwitchQualityMode.auto,
              ])
                ListTile(
                  dense: true,
                  enabled: widget.onChanged != null && widget.automaticEnabled,
                  leading: Icon(
                    _quality.mode == mode
                        ? Icons.check_rounded
                        : Icons.high_quality_outlined,
                  ),
                  title: Text(
                    l10n.t(mode == TwitchQualityMode.auto ? '自動' : '最高畫質'),
                  ),
                  subtitle:
                      _quality.mode == mode && widget.currentVariant != null
                      ? Text(widget.currentVariant!.displayName)
                      : null,
                  onTap: widget.onChanged != null && widget.automaticEnabled
                      ? () {
                          close();
                          _run(_quality.setMode(mode));
                        }
                      : null,
                ),
            for (final variant in widget.variants)
              ListTile(
                dense: true,
                enabled: widget.onChanged != null,
                leading: SizedBox(
                  width: 24,
                  child:
                      _quality.mode == TwitchQualityMode.manual &&
                          variant.url == widget.currentVariant?.url
                      ? const Icon(Icons.check_rounded)
                      : null,
                ),
                title: Text(
                  variant.displayName.isNotEmpty
                      ? variant.displayName
                      : variant.name,
                ),
                onTap: widget.onChanged == null
                    ? null
                    : () {
                        close();
                        if (widget.player == null) {
                          widget.onChanged!(variant);
                        } else {
                          _run(_quality.chooseManual(variant));
                        }
                      },
              ),
          ],
        ],
      ),
    );
  }
}
