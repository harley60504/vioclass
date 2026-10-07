import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum TwitchChatKeyboardCommand { older, newer, user, context, clear }

class TwitchChatKeyboardController extends ChangeNotifier {
  static const storageKey = 'twitch_chat_keyboard_bindings_v1';
  static const defaults = <TwitchChatKeyboardCommand, String?>{
    TwitchChatKeyboardCommand.older: 'K',
    TwitchChatKeyboardCommand.newer: 'J',
    TwitchChatKeyboardCommand.user: 'U',
    TwitchChatKeyboardCommand.context: 'Enter',
    TwitchChatKeyboardCommand.clear: 'Escape',
  };
  static final keys = Map<String, LogicalKeyboardKey>.unmodifiable({
    for (final key in [
      LogicalKeyboardKey.keyA,
      LogicalKeyboardKey.keyB,
      LogicalKeyboardKey.keyC,
      LogicalKeyboardKey.keyD,
      LogicalKeyboardKey.keyE,
      LogicalKeyboardKey.keyF,
      LogicalKeyboardKey.keyG,
      LogicalKeyboardKey.keyH,
      LogicalKeyboardKey.keyI,
      LogicalKeyboardKey.keyJ,
      LogicalKeyboardKey.keyK,
      LogicalKeyboardKey.keyL,
      LogicalKeyboardKey.keyM,
      LogicalKeyboardKey.keyN,
      LogicalKeyboardKey.keyO,
      LogicalKeyboardKey.keyP,
      LogicalKeyboardKey.keyQ,
      LogicalKeyboardKey.keyR,
      LogicalKeyboardKey.keyS,
      LogicalKeyboardKey.keyT,
      LogicalKeyboardKey.keyU,
      LogicalKeyboardKey.keyV,
      LogicalKeyboardKey.keyW,
      LogicalKeyboardKey.keyX,
      LogicalKeyboardKey.keyY,
      LogicalKeyboardKey.keyZ,
      LogicalKeyboardKey.enter,
      LogicalKeyboardKey.escape,
    ])
      key.keyLabel: key,
  });

  final Future<String?> Function() _read;
  final Future<bool> Function(String) _write;
  Map<TwitchChatKeyboardCommand, String?> _bindings = Map.of(defaults);
  Future<void> _tail = Future.value();
  bool _loaded = false;
  bool _disposed = false;
  bool _corrupt = false;
  String? problem;

  TwitchChatKeyboardController({
    Future<String?> Function()? read,
    Future<bool> Function(String)? write,
  }) : _read =
           read ??
           (() async =>
               (await SharedPreferences.getInstance()).getString(storageKey)),
       _write =
           write ??
           ((raw) async => (await SharedPreferences.getInstance()).setString(
             storageKey,
             raw,
           ));

  Map<TwitchChatKeyboardCommand, String?> get bindings =>
      Map.unmodifiable(_bindings);
  bool get loaded => _loaded;
  bool get corrupt => _corrupt;
  LogicalKeyboardKey? keyFor(TwitchChatKeyboardCommand command) =>
      keys[_bindings[command]];

  Future<void> _queue(Future<void> Function() work) {
    final next = _tail.then((_) async {
      if (_disposed) throw StateError('鍵位設定已關閉。');
      await work();
    });
    _tail = next.catchError((Object _) {});
    return next;
  }

  Future<void> load() => _queue(_load);

  Future<void> _load() async {
    if (_loaded) return;
    final raw = await _read();
    if (raw != null) {
      try {
        if (raw.length > 8192) throw const FormatException();
        final data = jsonDecode(raw);
        if (data is! Map || data['version'] != 1 || data['bindings'] is! Map) {
          throw const FormatException();
        }
        final stored = data['bindings'] as Map;
        if (stored.length != TwitchChatKeyboardCommand.values.length) {
          throw const FormatException();
        }
        final next = <TwitchChatKeyboardCommand, String?>{};
        for (final command in TwitchChatKeyboardCommand.values) {
          if (!stored.containsKey(command.name)) throw const FormatException();
          final value = stored[command.name];
          if (value != null && value is! String) throw const FormatException();
          next[command] = value as String?;
        }
        _validate(next);
        _bindings = next;
      } catch (_) {
        _corrupt = true;
        problem = '鍵位資料損壞或版本不支援；保留原資料，請明確重設後再修改。';
      }
    }
    _loaded = true;
    _publish();
  }

  void _validate(Map<TwitchChatKeyboardCommand, String?> bindings) {
    final used = <String>{};
    for (final value in bindings.values) {
      if (value == null) continue;
      if (!keys.containsKey(value)) throw ArgumentError('不支援此鍵位。');
      if (!used.add(value)) throw ArgumentError('此鍵位已由其他聊天室操作使用。');
    }
  }

  Future<void> setBinding(TwitchChatKeyboardCommand command, String? key) =>
      _queue(() async {
        await _load();
        if (_corrupt) throw StateError(problem!);
        final next = Map<TwitchChatKeyboardCommand, String?>.of(_bindings)
          ..[command] = key;
        _validate(next);
        await _save(next);
      });

  /// Explicit recovery also permits replacing an unreadable/unsupported archive.
  Future<void> reset() => _queue(() => _save(Map.of(defaults)));

  Future<void> _save(Map<TwitchChatKeyboardCommand, String?> next) async {
    final raw = jsonEncode({
      'version': 1,
      'bindings': {
        for (final entry in next.entries) entry.key.name: entry.value,
      },
    });
    if (!await _write(raw)) throw StateError('鍵位保存失敗，未套用變更。');
    _bindings = next;
    _loaded = true;
    _corrupt = false;
    problem = null;
    _publish();
  }

  void _publish() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

final twitchChatKeyboardController = TwitchChatKeyboardController();
