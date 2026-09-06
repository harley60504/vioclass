import 'package:flutter/material.dart';

import '../../../localization/vioclass_localizations.dart';
import '../../../theme/twitch_ui_tokens.dart';
import '../../shared/twitch_glass.dart';

Future<Duration?> showTwitchTimeJumpSheet({
  required BuildContext context,
  required Duration current,
  required Duration? duration,
  required bool liveTail,
}) {
  return showModalBottomSheet<Duration>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: false,
    useSafeArea: true,
    enableDrag: false,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black38,
    builder: (_) => _TwitchTimeJumpSheet(
      current: current,
      duration: duration,
      liveTail: liveTail,
    ),
  );
}

class _TwitchTimeJumpSheet extends StatefulWidget {
  final Duration current;
  final Duration? duration;
  final bool liveTail;

  const _TwitchTimeJumpSheet({
    required this.current,
    required this.duration,
    required this.liveTail,
  });

  @override
  State<_TwitchTimeJumpSheet> createState() => _TwitchTimeJumpSheetState();
}

class _TwitchTimeJumpSheetState extends State<_TwitchTimeJumpSheet> {
  late final TextEditingController _controller;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _formatDuration(widget.current));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final parsed = _parseDuration(_controller.text);
    if (parsed == null) {
      setState(() => _error = context.vio.t('時間格式不正確'));
      return;
    }

    final duration = widget.duration;
    final safeValue = duration != null && duration.inMilliseconds > 0
        ? Duration(
            milliseconds: parsed.inMilliseconds.clamp(
              0,
              duration.inMilliseconds,
            ),
          )
        : parsed;
    Navigator.of(context).pop(safeValue);
  }

  void _shiftBy(Duration delta) {
    final parsed = _parseDuration(_controller.text) ?? widget.current;
    final duration = widget.duration;
    final nextMilliseconds = parsed.inMilliseconds + delta.inMilliseconds;
    final clamped = duration != null && duration.inMilliseconds > 0
        ? nextMilliseconds.clamp(0, duration.inMilliseconds)
        : nextMilliseconds.clamp(0, 1 << 62);

    setState(() {
      _error = null;
      _controller.text = _formatDuration(
        Duration(milliseconds: clamped.toInt()),
      );
      _controller.selection = TextSelection.collapsed(
        offset: _controller.text.length,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.vio;
    final screenWidth = MediaQuery.of(context).size.width;
    final sheetWidth = screenWidth.clamp(280.0, 420.0).toDouble();
    final duration = widget.duration;

    return SafeArea(
      top: false,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
          child: TwitchGlassSurface(
            borderRadius: BorderRadius.circular(20),
            backgroundColor: Colors.black.withValues(alpha: 0.64),
            borderColor: Colors.white.withValues(alpha: 0.13),
            blurSigma: 0,
            boxShadow: const <BoxShadow>[],
            child: SizedBox(
              width: sheetWidth,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.schedule_rounded,
                          color: TwitchUiColors.primarySoft,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            l10n.t('跳轉時間'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: l10n.t('關閉'),
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(
                            Icons.close_rounded,
                            color: Colors.white54,
                            size: 20,
                          ),
                          onPressed: () => Navigator.of(context).maybePop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _controller,
                      autofocus: true,
                      keyboardType: TextInputType.text,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _submit(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                      decoration: InputDecoration(
                        isDense: true,
                        prefixIcon: const Icon(
                          Icons.timer_outlined,
                          color: Colors.white54,
                          size: 18,
                        ),
                        hintText: l10n.t('例如 1:23:45 或 23:45'),
                        errorText: _error,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      duration != null && duration.inMilliseconds > 0
                          ? '${l10n.t('目前')} ${_formatDuration(widget.current)} / ${_formatDuration(duration)}${widget.liveTail ? ' · ${l10n.t('直播')}' : ''}'
                          : l10n.t('輸入要跳轉的時間'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () =>
                                _shiftBy(const Duration(seconds: -10)),
                            icon: const Icon(Icons.replay_10_rounded),
                            label: Text(l10n.t('倒退 10 秒')),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () =>
                                _shiftBy(const Duration(seconds: 10)),
                            icon: const Icon(Icons.forward_10_rounded),
                            label: Text(l10n.t('前進 10 秒')),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _submit,
                        icon: const Icon(Icons.keyboard_return_rounded),
                        label: Text(l10n.t('跳轉')),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Duration? _parseDuration(String value) {
  final text = value.trim();
  if (text.isEmpty) return null;

  final parts = text.split(':');
  if (parts.length > 3) return null;

  final numbers = <int>[];
  for (final raw in parts) {
    final number = int.tryParse(raw.trim());
    if (number == null || number < 0) return null;
    numbers.add(number);
  }

  if (numbers.length == 1) {
    return Duration(seconds: numbers[0]);
  }
  if (numbers.length == 2) {
    return Duration(minutes: numbers[0], seconds: numbers[1]);
  }
  return Duration(hours: numbers[0], minutes: numbers[1], seconds: numbers[2]);
}

String _formatDuration(Duration duration) {
  final totalSeconds = duration.inSeconds;
  final hours = totalSeconds ~/ 3600;
  final minutes = (totalSeconds % 3600) ~/ 60;
  final seconds = totalSeconds % 60;
  if (hours > 0) {
    return '$hours:${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }
  return '$minutes:${seconds.toString().padLeft(2, '0')}';
}
