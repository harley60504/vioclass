import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';

import '../../api/chat/twitch_vod_comments_api_service.dart';
import '../../models/chat/twitch_chat_runtime_message.dart';

class TwitchVodChatReplayRuntime extends ChangeNotifier {
  static const int visibleMax = 200;
  static const Duration tickInterval = Duration(milliseconds: 750);
  static const double seekBackThresholdSeconds = 0.75;
  static const double seekForwardThresholdSeconds = 20;
  static const double backlogLeadSeconds = 15;
  static const int refillWithin = 40;
  static const Duration seekSettleDelay = Duration(milliseconds: 400);

  final TwitchVodCommentsApiService api;

  TwitchVodChatReplayRuntime({required this.api});

  final List<TwitchVodComment> _buffer = <TwitchVodComment>[];
  final List<TwitchChatRuntimeMessage> _messages = <TwitchChatRuntimeMessage>[];
  final Set<String> _seen = <String>{};

  Timer? _ticker;
  Timer? _seekTimer;
  Player? _player;
  String _videoId = '';
  String _channelLogin = '';
  double _timelineOffsetBaseSeconds = 0;
  double _playerPositionBaseSeconds = 0;
  int _ptr = 0;
  double _lastTime = 0;
  double _nextFetchOffset = 0;
  bool _fetching = false;
  bool _reachedFrontier = false;
  bool _active = false;
  bool _disposed = false;
  Object? _error;

  List<TwitchChatRuntimeMessage> get messages {
    return List<TwitchChatRuntimeMessage>.unmodifiable(_messages);
  }

  bool get active => _active;
  bool get fetching => _fetching;
  Object? get error => _error;
  String get channelLogin => _channelLogin;

  Future<void> start({
    required String videoId,
    required String channelLogin,
    required Player player,
    double? timelineOffsetSeconds,
  }) async {
    stop();
    _videoId = videoId.trim();
    _channelLogin = channelLogin.trim().toLowerCase();
    _player = player;
    final currentPlayerSeconds = player.state.position.inMilliseconds / 1000;
    _playerPositionBaseSeconds = currentPlayerSeconds;
    _timelineOffsetBaseSeconds = (timelineOffsetSeconds ?? currentPlayerSeconds)
        .clamp(0, double.infinity);
    _active = _videoId.isNotEmpty && _channelLogin.isNotEmpty;
    _lastTime = _playerTimeSeconds();
    _nextFetchOffset = (_lastTime - backlogLeadSeconds).clamp(
      0,
      double.infinity,
    );
    _notifyIfAlive();

    if (!_active) return;
    unawaited(_fetchAt(_nextFetchOffset));
    _ticker = Timer.periodic(tickInterval, (_) => _tick());
  }

  void stop() {
    _ticker?.cancel();
    _seekTimer?.cancel();
    _ticker = null;
    _seekTimer = null;
    _player = null;
    _videoId = '';
    _channelLogin = '';
    _timelineOffsetBaseSeconds = 0;
    _playerPositionBaseSeconds = 0;
    _buffer.clear();
    _messages.clear();
    _seen.clear();
    _ptr = 0;
    _lastTime = 0;
    _nextFetchOffset = 0;
    _fetching = false;
    _reachedFrontier = false;
    _active = false;
    _error = null;
    _notifyIfAlive();
  }

  Future<void> nudge() async {
    _tick();
  }

  Future<void> _fetchAt(double offset) async {
    if (_fetching || !_active) return;
    _fetching = true;
    _error = null;
    _notifyIfAlive();

    final requestVideoId = _videoId;
    try {
      final page = await api.fetchComments(
        videoId: requestVideoId,
        channelLogin: _channelLogin,
        offsetSeconds: offset,
      );
      if (!_active || _videoId != requestVideoId) return;

      var added = 0;
      var maxOffset = _nextFetchOffset;
      for (final comment in page) {
        final id = comment.message.id;
        if (id.isNotEmpty && _seen.contains(id)) continue;
        if (id.isNotEmpty) _seen.add(id);
        _buffer.add(comment);
        added++;
        if (comment.contentOffsetSeconds > maxOffset) {
          maxOffset = comment.contentOffsetSeconds;
        }
      }
      if (added > 0) {
        _buffer.sort(
          (a, b) => a.contentOffsetSeconds.compareTo(b.contentOffsetSeconds),
        );
      }
      _nextFetchOffset = maxOffset;
      _reachedFrontier = added == 0;
    } catch (error) {
      _error = error;
    } finally {
      _fetching = false;
      _notifyIfAlive();
    }
  }

  void _notifyIfAlive() {
    if (_disposed) return;
    notifyListeners();
  }

  void _tick() {
    if (!_active) return;
    final now = _playerTimeSeconds();
    if (now < _lastTime - seekBackThresholdSeconds ||
        now > _lastTime + seekForwardThresholdSeconds) {
      _lastTime = now;
      if (_reseekFromBuffer(now)) return;
      _scheduleSeekResync(now);
      return;
    }

    _lastTime = now;
    if (_seekTimer != null) return;

    var emitted = false;
    while (_ptr < _buffer.length && _buffer[_ptr].contentOffsetSeconds <= now) {
      _messages.add(_buffer[_ptr].message);
      _ptr++;
      emitted = true;
    }
    if (_messages.length > visibleMax) {
      _messages.removeRange(0, _messages.length - visibleMax);
      emitted = true;
    }
    if (emitted) _notifyIfAlive();

    if (!_fetching &&
        !_reachedFrontier &&
        _buffer.length - _ptr < refillWithin) {
      unawaited(_fetchAt(_nextFetchOffset));
    } else if (!_fetching &&
        _reachedFrontier &&
        _ptr >= _buffer.length &&
        now > _nextFetchOffset + 1) {
      _reachedFrontier = false;
      unawaited(_fetchAt(now.floorToDouble()));
    }
  }

  bool _reseekFromBuffer(double timeSeconds) {
    if (_buffer.isEmpty) return false;
    if (timeSeconds < _buffer.first.contentOffsetSeconds - 1) return false;
    _ptr = 0;
    _messages.clear();
    while (_ptr < _buffer.length &&
        _buffer[_ptr].contentOffsetSeconds <= timeSeconds) {
      _messages.add(_buffer[_ptr].message);
      _ptr++;
    }
    if (_messages.length > visibleMax) {
      _messages.removeRange(0, _messages.length - visibleMax);
    }
    _notifyIfAlive();
    return true;
  }

  void _scheduleSeekResync(double timeSeconds) {
    _seekTimer?.cancel();
    _seekTimer = Timer(seekSettleDelay, () {
      _seekTimer = null;
      _buffer.clear();
      _messages.clear();
      _seen.clear();
      _ptr = 0;
      _reachedFrontier = false;
      _nextFetchOffset = (timeSeconds - backlogLeadSeconds).clamp(
        0,
        double.infinity,
      );
      _notifyIfAlive();
      unawaited(_fetchAt(_nextFetchOffset));
    });
  }

  double _playerTimeSeconds() {
    final player = _player;
    if (player == null) return 0;
    final playerSeconds = player.state.position.inMilliseconds / 1000;
    final elapsed = playerSeconds - _playerPositionBaseSeconds;
    return (_timelineOffsetBaseSeconds + elapsed).clamp(0, double.infinity);
  }

  @override
  void dispose() {
    _disposed = true;
    stop();
    super.dispose();
  }
}
