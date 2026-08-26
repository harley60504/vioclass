import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../api/clips/twitch_clip_api_service.dart';
import '../widgets/responsive/twitch_responsive_sheet.dart';

const double _minClipLength = 5;
const double _maxClipLength = 60;

Future<void> showTwitchClipEditorDialog({
  required BuildContext context,
  required TwitchClipApiService clipApi,
  String? vodId,
  String? broadcastId,
  required double offsetSeconds,
  required String channelName,
}) async {
  await showTwitchResponsiveSheet<void>(
    context: context,
    maxWidth: 1060,
    portraitHeightFactor: 0.92,
    landscapeHeightFactor: 0.96,
    builder: (_) => SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.86,
      child: _TwitchClipEditorDialogBody(
        clipApi: clipApi,
        vodId: vodId,
        broadcastId: broadcastId,
        offsetSeconds: offsetSeconds,
        channelName: channelName,
      ),
    ),
  );
}

class _TwitchClipEditorDialogBody extends StatefulWidget {
  final TwitchClipApiService clipApi;
  final String? vodId;
  final String? broadcastId;
  final double offsetSeconds;
  final String channelName;

  const _TwitchClipEditorDialogBody({
    required this.clipApi,
    required this.vodId,
    required this.broadcastId,
    required this.offsetSeconds,
    required this.channelName,
  });

  @override
  State<_TwitchClipEditorDialogBody> createState() =>
      _TwitchClipEditorDialogBodyState();
}

class _TwitchClipEditorDialogBodyState
    extends State<_TwitchClipEditorDialogBody> {
  final TextEditingController _titleController = TextEditingController();
  Player? _player;
  VideoController? _videoController;
  TwitchClipEditSession? _session;
  StreamSubscription<Duration>? _positionSubscription;
  double _start = 0;
  double _end = 0;
  double _position = 0;
  bool _loading = true;
  bool _creating = false;
  String? _errorText;

  double get _duration => _session?.durationSeconds ?? 0;
  double get _length => (_end - _start).clamp(0, _maxClipLength).toDouble();

  @override
  void initState() {
    super.initState();
    MediaKit.ensureInitialized();
    unawaited(_initialize());
  }

  Future<void> _initialize() async {
    final player = await Player.create(
      configuration: const PlayerConfiguration(title: 'Clip Editor'),
    );
    final controller = await VideoController.create(
      player,
      configuration: const VideoControllerConfiguration(
        enableHardwareAcceleration: true,
        androidAttachSurfaceAfterVideoParameters: false,
        hwdec: 'auto-safe',
      ),
    );
    if (!mounted) {
      await player.dispose();
      return;
    }
    _player = player;
    _videoController = controller;
    _positionSubscription = player.stream.position.listen((position) {
      if (!mounted) return;
      setState(() {
        _position = position.inMilliseconds / 1000;
      });
      if (_end > _start && _position >= _end) {
        unawaited(player.pause());
      }
    });
    await _begin();
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _titleController.dispose();
    final player = _player;
    if (player != null) unawaited(player.dispose());
    super.dispose();
  }

  Future<void> _begin() async {
    setState(() {
      _loading = true;
      _errorText = null;
    });
    try {
      final session = await widget.clipApi.beginClipEdit(
        vodId: widget.vodId,
        broadcastId: widget.broadcastId,
        offsetSeconds: widget.offsetSeconds,
      );
      final length = session.durationSeconds <= 0
          ? 30.0
          : session.durationSeconds.clamp(_minClipLength, 30.0).toDouble();
      final start = (session.durationSeconds - length)
          .clamp(0.0, session.durationSeconds)
          .toDouble();
      if (!mounted) return;
      setState(() {
        _session = session;
        _start = start;
        _end = (start + length).clamp(0.0, session.durationSeconds).toDouble();
        _loading = false;
      });
      final player = _player;
      if (player == null) return;
      await player.open(Media(session.previewUrl), play: false);
      await player.seek(Duration(milliseconds: (_start * 1000).round()));
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorText = _clipEditorErrorText(error);
      });
    }
  }

  Future<void> _previewSelection() async {
    final player = _player;
    if (player == null) return;
    await player.seek(Duration(milliseconds: (_start * 1000).round()));
    await player.play();
  }

  Future<void> _createClip() async {
    final session = _session;
    if (session == null || _creating) return;
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      setState(() => _errorText = '請先輸入 Clip 標題。');
      return;
    }
    final length = _end - _start;
    if (length < _minClipLength || length > _maxClipLength) {
      setState(() => _errorText = 'Clip 長度需介於 5 到 60 秒。');
      return;
    }
    setState(() {
      _creating = true;
      _errorText = null;
    });
    try {
      final result = await widget.clipApi.finalizeClip(
        rawMediaId: session.rawMediaId,
        startSeconds: _start,
        durationSeconds: length,
        title: title,
      );
      final url = result.publicUrl;
      if (url.isNotEmpty) {
        await Clipboard.setData(ClipboardData(text: url));
      }
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(url.isEmpty ? 'Clip 已建立。' : 'Clip 已建立，連結已複製。')),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _creating = false;
        _errorText = _clipEditorErrorText(error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final channelName = widget.channelName.trim().isEmpty
        ? 'Twitch'
        : widget.channelName.trim();

    return Column(
      children: [
        Container(
          height: 58,
          padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
          decoration: const BoxDecoration(
            color: Color(0xFF0E0E10),
            border: Border(bottom: BorderSide(color: Color(0xFF2D2D35))),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.movie_creation_outlined,
                color: Color(0xFFBF94FF),
                size: 22,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      '剪輯 Clip',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      channelName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: null,
                onPressed: _creating ? null : () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close, color: Colors.white70),
              ),
            ],
          ),
        ),
        Expanded(
          child: ColoredBox(color: Colors.black, child: _buildBody()),
        ),
      ],
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(strokeWidth: 2.4),
            SizedBox(height: 12),
            Text('正在準備可剪輯片段...', style: TextStyle(color: Colors.white70)),
          ],
        ),
      );
    }
    if (_session == null) {
      return _ErrorView(errorText: _errorText, onRetry: _begin);
    }
    final controller = _videoController;
    return Column(
      children: [
        Expanded(
          child: ColoredBox(
            color: Colors.black,
            child: controller == null
                ? const Center(child: CircularProgressIndicator())
                : Video(controller: controller, controls: NoVideoControls),
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 14),
          decoration: const BoxDecoration(
            color: Color(0xFF15151A),
            border: Border(top: BorderSide(color: Color(0xFF2D2D35))),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Text(
                    _formatSeconds(_start),
                    style: const TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Expanded(
                    child: RangeSlider(
                      min: 0,
                      max: _duration <= 0 ? 1 : _duration,
                      values: RangeValues(_start, _end),
                      onChanged: _creating
                          ? null
                          : (values) {
                              final length = values.end - values.start;
                              if (length < _minClipLength ||
                                  length > _maxClipLength) {
                                return;
                              }
                              setState(() {
                                _start = values.start;
                                _end = values.end;
                              });
                            },
                      onChangeEnd: (values) {
                        unawaited(
                          _player?.seek(
                            Duration(
                              milliseconds: (values.start * 1000).round(),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  Text(
                    _formatSeconds(_end),
                    style: const TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  Text(
                    '${_formatSeconds(_position)} / ${_formatSeconds(_duration)}',
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${_length.toStringAsFixed(1)}s',
                    style: TextStyle(
                      color:
                          _length < _minClipLength || _length > _maxClipLength
                          ? Colors.redAccent
                          : const Color(0xFFBF94FF),
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _titleController,
                      enabled: !_creating,
                      maxLength: 100,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        counterText: '',
                        hintText: 'Clip 標題',
                        hintStyle: TextStyle(color: Colors.white38),
                        filled: true,
                        fillColor: Color(0xFF202027),
                        border: OutlineInputBorder(
                          borderSide: BorderSide(color: Color(0xFF393944)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Color(0xFF393944)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Color(0xFF9146FF)),
                        ),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  IconButton.filledTonal(
                    tooltip: null,
                    onPressed: _creating ? null : _previewSelection,
                    icon: const Icon(Icons.play_arrow_rounded),
                  ),
                  const SizedBox(width: 10),
                  FilledButton.icon(
                    onPressed: _creating ? null : _createClip,
                    icon: _creating
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.movie_creation_outlined),
                    label: Text(_creating ? '建立中' : '建立 Clip'),
                  ),
                ],
              ),
              if (_errorText != null) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _errorText!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.redAccent,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String? errorText;
  final Future<void> Function() onRetry;

  const _ErrorView({required this.errorText, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.redAccent, size: 32),
            const SizedBox(height: 10),
            Text(
              errorText ?? 'Clip 片段準備失敗。',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 14),
            FilledButton(
              onPressed: () => unawaited(onRetry()),
              child: const Text('重試'),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatSeconds(double value) {
  final total = value.isFinite ? value.round().clamp(0, 999999) : 0;
  final minutes = total ~/ 60;
  final seconds = total % 60;
  return '$minutes:${seconds.toString().padLeft(2, '0')}';
}

String _clipEditorErrorText(Object error) {
  final message = error.toString();
  final lower = message.toLowerCase();
  if (lower.contains('drops / android token')) {
    return '請先補 Drops / Android token。';
  }
  if (lower.contains('disabled') ||
      lower.contains('forbidden') ||
      lower.contains('notfound') ||
      lower.contains('createclip') ||
      lower.contains('createrawmedia') ||
      lower.contains('raw media') ||
      lower.contains('rawmedia') ||
      lower.contains('clip finalize') ||
      lower.contains('沒有回傳 raw media') ||
      lower.contains('一直沒有完成處理')) {
    return '這個實況主可能沒有開放 Clip。';
  }
  return 'Clip 剪輯失敗：$message';
}
