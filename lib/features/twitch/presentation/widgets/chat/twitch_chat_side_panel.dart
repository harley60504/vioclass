import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../../auth/services/twitch_web_cookie_service.dart';
import '../../../data/models/twitch_stream_model.dart';

class TwitchChatSidePanel extends StatefulWidget {
  final TwitchStreamModel stream;
  final double width;
  final ValueChanged<double> onWidthDelta;
  final VoidCallback onWidthDragEnd;

  const TwitchChatSidePanel({
    super.key,
    required this.stream,
    required this.width,
    required this.onWidthDelta,
    required this.onWidthDragEnd,
  });

  @override
  State<TwitchChatSidePanel> createState() => _TwitchChatSidePanelState();
}

class _TwitchChatSidePanelState extends State<TwitchChatSidePanel> {
  static const String _ircUrl = 'wss://irc-ws.chat.twitch.tv:443';
  static const String _webClientId = 'kimne78kx3ncx6brgo4mv6wki5h1ko';
  static const int _maxMessages = 450;

  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: const <String, String>{
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
      },
    ),
  );

  final TextEditingController _inputController = TextEditingController();
  final FocusNode _inputFocusNode = FocusNode();

  WebSocketChannel? _ircChannel;
  StreamSubscription<dynamic>? _ircSubscription;

  final List<_SimpleChatMessage> _messages = <_SimpleChatMessage>[];
  final Set<String> _seenMessageIds = <String>{};
  final Map<String, _SimpleEmote> _emotesByExactName = <String, _SimpleEmote>{};
  final Map<String, _SimpleEmote> _emotesByLowerName = <String, _SimpleEmote>{};
  final Map<String, _SimpleEmote> _recentEmotes = <String, _SimpleEmote>{};

  String _statusText = '初始化聊天室...';
  String? _errorText;
  String? _authToken;
  String? _viewerLogin;
  String? _channelId;
  bool _connecting = false;
  bool _connected = false;
  bool _loadingEmotes = false;
  bool _sending = false;
  int _rawLineCount = 0;

  String get _channelLogin {
    final login = widget.stream.userLogin.trim();
    if (login.isNotEmpty) return login.toLowerCase();
    return widget.stream.userName.trim().toLowerCase();
  }

  String get _displayName {
    final name = widget.stream.userName.trim();
    if (name.isNotEmpty) return name;
    return _channelLogin;
  }

  String get _recentStorageKey => 'simple_twitch_recent_emotes_$_channelLogin';

  @override
  void initState() {
    super.initState();
    unawaited(_restart());
  }

  @override
  void didUpdateWidget(covariant TwitchChatSidePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldLogin = oldWidget.stream.userLogin.trim().isNotEmpty
        ? oldWidget.stream.userLogin.trim().toLowerCase()
        : oldWidget.stream.userName.trim().toLowerCase();
    if (oldLogin != _channelLogin) {
      unawaited(_restart());
    }
  }

  @override
  void dispose() {
    unawaited(_disconnectIrc());
    _dio.close(force: true);
    _inputController.dispose();
    _inputFocusNode.dispose();
    super.dispose();
  }

  Future<void> _restart() async {
    await _disconnectIrc();
    if (!mounted) return;

    setState(() {
      _messages.clear();
      _seenMessageIds.clear();
      _emotesByExactName.clear();
      _emotesByLowerName.clear();
      _recentEmotes.clear();
      _statusText = '初始化聊天室...';
      _errorText = null;
      _connected = false;
      _connecting = true;
      _rawLineCount = 0;
    });

    await _loadRecentEmotes();
    await _loadAuthAndChannelContext();

    if (!mounted) return;

    unawaited(_loadEmoteCatalog());
    await _connectIrc();
  }

  Future<void> _loadAuthAndChannelContext() async {
    final token = await TwitchWebCookieService.readAuthToken();
    String? viewerLogin;
    String? channelId;

    try {
      channelId = await _fetchChannelIdByLogin(_channelLogin);
    } catch (e) {
      _setError('讀取頻道 ID 失敗：$e');
    }

    if (token != null && token.trim().isNotEmpty) {
      try {
        viewerLogin = await _fetchViewerLogin(token.trim());
      } catch (e) {
        _setError('讀取登入使用者失敗：$e');
      }
    }

    if (!mounted) return;

    setState(() {
      _authToken = token?.trim();
      _viewerLogin = viewerLogin?.trim().toLowerCase();
      _channelId = channelId?.trim();
    });
  }

  Future<String?> _fetchChannelIdByLogin(String login) async {
    if (login.trim().isEmpty) return null;

    final response = await _dio.post<dynamic>(
      'https://gql.twitch.tv/gql',
      data: <String, dynamic>{
        'operationName': 'SimpleChatChannelId',
        'query': r'''
          query SimpleChatChannelId($login: String!) {
            user(login: $login) {
              id
              displayName
            }
          }
        ''',
        'variables': <String, dynamic>{'login': login.trim().toLowerCase()},
      },
      options: Options(
        headers: const <String, String>{
          'Client-ID': _webClientId,
          'Content-Type': 'application/json',
        },
        validateStatus: (status) => status != null && status < 500,
      ),
    );

    final data = response.data;
    if (data is! Map) return null;
    final root = data['data'];
    if (root is! Map) return null;
    final user = root['user'];
    if (user is! Map) return null;
    final id = user['id']?.toString().trim();
    return id == null || id.isEmpty ? null : id;
  }

  Future<String?> _fetchViewerLogin(String token) async {
    final response = await _dio.get<dynamic>(
      'https://api.twitch.tv/helix/users',
      options: Options(
        headers: <String, String>{
          'Client-ID': _webClientId,
          'Authorization': 'Bearer $token',
        },
        validateStatus: (status) => status != null && status < 500,
      ),
    );

    final data = response.data;
    if (data is! Map) return null;
    final list = data['data'];
    if (list is! List || list.isEmpty) return null;
    final first = list.first;
    if (first is! Map) return null;
    final login = first['login']?.toString().trim().toLowerCase();
    return login == null || login.isEmpty ? null : login;
  }

  Future<void> _connectIrc() async {
    if (!mounted) return;

    setState(() {
      _connecting = true;
      _statusText = '連線 Twitch IRC...';
    });

    try {
      final ws = WebSocketChannel.connect(Uri.parse(_ircUrl));
      _ircChannel = ws;

      _ircSubscription = ws.stream.listen(
        _handleIrcSocketEvent,
        onError: (Object error, StackTrace stackTrace) {
          _setError('IRC 連線錯誤：$error');
        },
        onDone: () {
          if (!mounted) return;
          setState(() {
            _connected = false;
            _connecting = false;
            _statusText = '聊天室已中斷';
          });
        },
        cancelOnError: false,
      );

      final token = _authToken;
      final viewerLogin = _viewerLogin;
      final nick = token != null && token.isNotEmpty &&
              viewerLogin != null && viewerLogin.isNotEmpty
          ? viewerLogin
          : 'justinfan${DateTime.now().millisecondsSinceEpoch.remainder(900000) + 100000}';

      _sendRaw('CAP REQ :twitch.tv/tags twitch.tv/commands twitch.tv/membership');
      if (token != null && token.isNotEmpty && viewerLogin != null && viewerLogin.isNotEmpty) {
        _sendRaw('PASS oauth:$token');
        _sendRaw('NICK $viewerLogin');
      } else {
        _sendRaw('PASS SCHMOOPIIE');
        _sendRaw('NICK $nick');
      }
      _sendRaw('JOIN #$_channelLogin');

      if (!mounted) return;
      setState(() {
        _connected = true;
        _connecting = false;
        _statusText = token == null || token.isEmpty
            ? '匿名讀取聊天室'
            : '聊天室已連線';
      });
    } catch (e) {
      _setError('IRC 連線失敗：$e');
      if (!mounted) return;
      setState(() {
        _connected = false;
        _connecting = false;
      });
    }
  }

  Future<void> _disconnectIrc() async {
    await _ircSubscription?.cancel();
    _ircSubscription = null;
    final ws = _ircChannel;
    _ircChannel = null;
    await ws?.sink.close();
  }

  void _sendRaw(String line) {
    _ircChannel?.sink.add('$line\r\n');
  }

  void _handleIrcSocketEvent(dynamic event) {
    final text = event is List<int> ? utf8.decode(event) : event.toString();
    final lines = text
        .split(RegExp(r'\r?\n'))
        .where((line) => line.trim().isNotEmpty)
        .toList(growable: false);

    for (final line in lines) {
      _rawLineCount += 1;
      if (line.startsWith('PING')) {
        final payload = line.contains(':')
            ? line.substring(line.indexOf(':'))
            : ':tmi.twitch.tv';
        _sendRaw('PONG $payload');
        continue;
      }

      final parsed = _ParsedIrcLine.parse(line);
      if (parsed.command.isEmpty) continue;

      switch (parsed.command) {
        case 'PRIVMSG':
          _handlePrivMsg(parsed);
          break;
        case 'NOTICE':
          _handleNotice(parsed);
          break;
        case 'USERNOTICE':
          _handleUserNotice(parsed);
          break;
        case 'CLEARMSG':
          _handleClearMsg(parsed);
          break;
        case 'CLEARCHAT':
          _handleClearChat(parsed);
          break;
        case 'ROOMSTATE':
          break;
        case 'USERSTATE':
        case 'GLOBALUSERSTATE':
          break;
      }
    }
  }

  void _handlePrivMsg(_ParsedIrcLine line) {
    final text = line.trailing.trimRight();
    if (text.isEmpty) return;

    final id = line.tags['id']?.trim();
    final safeId = id != null && id.isNotEmpty
        ? id
        : 'msg-${DateTime.now().microsecondsSinceEpoch}-${_messages.length}';

    if (_seenMessageIds.contains(safeId)) return;
    _seenMessageIds.add(safeId);

    final login = line.userLogin.trim().isNotEmpty ? line.userLogin : 'unknown';
    final displayName = line.tags['display-name']?.trim().isNotEmpty == true
        ? line.tags['display-name']!.trim()
        : login;

    _appendMessage(_SimpleChatMessage(
      id: safeId,
      login: login,
      displayName: displayName,
      color: _parseUserColor(line.tags['color']) ?? _colorFromText(login),
      text: text,
      emotesTag: line.tags['emotes'] ?? '',
      receivedAt: DateTime.now(),
      system: false,
    ));
  }

  void _handleNotice(_ParsedIrcLine line) {
    final text = line.trailing.trim();
    if (text.isEmpty) return;
    _appendSystemMessage(text);
  }

  void _handleUserNotice(_ParsedIrcLine line) {
    final systemMessage = line.tags['system-msg']?.trim();
    final text = line.trailing.trim();
    final display = systemMessage != null && systemMessage.isNotEmpty
        ? systemMessage
        : text;
    if (display.isEmpty) return;
    _appendSystemMessage(display);
  }

  void _handleClearMsg(_ParsedIrcLine line) {
    final targetId = line.tags['target-msg-id']?.trim();
    if (targetId == null || targetId.isEmpty) return;
    if (!mounted) return;
    setState(() {
      _messages.removeWhere((message) => message.id == targetId);
      _seenMessageIds.remove(targetId);
    });
  }

  void _handleClearChat(_ParsedIrcLine line) {
    final targetLogin = line.trailing.trim().toLowerCase();
    if (!mounted) return;

    if (targetLogin.isEmpty) {
      setState(() {
        _messages.clear();
        _seenMessageIds.clear();
      });
      _appendSystemMessage('聊天室已被清除。');
      return;
    }

    setState(() {
      _messages.removeWhere(
        (message) => message.login.toLowerCase() == targetLogin,
      );
    });
  }

  void _appendSystemMessage(String text) {
    final clean = text.trim();
    if (clean.isEmpty) return;
    _appendMessage(_SimpleChatMessage(
      id: 'system-${DateTime.now().microsecondsSinceEpoch}',
      login: 'system',
      displayName: 'Twitch',
      color: const Color(0xFFBF94FF),
      text: clean,
      emotesTag: '',
      receivedAt: DateTime.now(),
      system: true,
    ));
  }

  void _appendMessage(_SimpleChatMessage message) {
    if (!mounted) return;
    setState(() {
      _messages.add(message);
      if (_messages.length > _maxMessages) {
        final removeCount = _messages.length - _maxMessages;
        for (var i = 0; i < removeCount; i += 1) {
          final removed = _messages.removeAt(0);
          _seenMessageIds.remove(removed.id);
        }
      }
    });
  }

  Future<void> _sendMessage() async {
    if (_sending) return;
    final text = _inputController.text.replaceAll(RegExp(r'[\r\n]+'), ' ').trim();
    if (text.isEmpty) return;

    final token = _authToken;
    final viewerLogin = _viewerLogin;
    if (token == null || token.isEmpty || viewerLogin == null || viewerLogin.isEmpty) {
      _appendSystemMessage('尚未取得可發言的 Twitch Web token，請重新登入。');
      return;
    }

    setState(() => _sending = true);

    try {
      _sendRaw('PRIVMSG #$_channelLogin :$text');
      _inputController.clear();
    } catch (e) {
      _appendSystemMessage('送出失敗：$e');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _loadEmoteCatalog() async {
    if (!mounted) return;
    setState(() {
      _loadingEmotes = true;
      _statusText = '讀取貼圖...';
    });

    final loaded = <_SimpleEmote>[];
    final channelId = _channelId;
    final token = _authToken;

    try {
      if (token != null && token.isNotEmpty) {
        loaded.addAll(await _fetchHelixGlobalEmotes(token));
        if (channelId != null && channelId.isNotEmpty) {
          loaded.addAll(await _fetchHelixChannelEmotes(token, channelId));
        }
      }

      if (channelId != null && channelId.isNotEmpty) {
        loaded.addAll(await _fetchSevenTvEmotes(channelId));
        loaded.addAll(await _fetchBttvEmotes(channelId));
        loaded.addAll(await _fetchFfzEmotes(channelId));
      }
    } catch (e) {
      _setError('貼圖讀取失敗：$e');
    }

    if (!mounted) return;

    setState(() {
      _emotesByExactName.clear();
      _emotesByLowerName.clear();
      for (final emote in loaded) {
        _addEmoteToLookup(emote);
      }
      for (final emote in _recentEmotes.values) {
        _addEmoteToLookup(emote);
      }
      _loadingEmotes = false;
      _statusText = _connected ? '聊天室已連線' : _statusText;
    });
  }

  void _addEmoteToLookup(_SimpleEmote emote) {
    final name = emote.name.trim();
    final url = emote.imageUrl.trim();
    if (name.isEmpty || url.isEmpty) return;

    final existing = _emotesByExactName[name];
    if (existing == null || emote.kind.index < existing.kind.index) {
      _emotesByExactName[name] = emote;
      _emotesByLowerName[name.toLowerCase()] = emote;
    }
  }

  Future<List<_SimpleEmote>> _fetchHelixGlobalEmotes(String token) async {
    final response = await _dio.get<dynamic>(
      'https://api.twitch.tv/helix/chat/emotes/global',
      options: Options(
        headers: <String, String>{
          'Client-ID': _webClientId,
          'Authorization': 'Bearer $token',
        },
        validateStatus: (status) => status != null && status < 500,
      ),
    );
    return _parseHelixEmotes(response.data, _SimpleEmoteKind.twitchGlobal);
  }

  Future<List<_SimpleEmote>> _fetchHelixChannelEmotes(
    String token,
    String channelId,
  ) async {
    final response = await _dio.get<dynamic>(
      'https://api.twitch.tv/helix/chat/emotes',
      queryParameters: <String, dynamic>{'broadcaster_id': channelId},
      options: Options(
        headers: <String, String>{
          'Client-ID': _webClientId,
          'Authorization': 'Bearer $token',
        },
        validateStatus: (status) => status != null && status < 500,
      ),
    );
    return _parseHelixEmotes(response.data, _SimpleEmoteKind.twitchChannel);
  }

  List<_SimpleEmote> _parseHelixEmotes(dynamic raw, _SimpleEmoteKind kind) {
    if (raw is! Map) return const <_SimpleEmote>[];
    final data = raw['data'];
    if (data is! List) return const <_SimpleEmote>[];

    final output = <_SimpleEmote>[];
    for (final item in data.whereType<Map>()) {
      final id = item['id']?.toString().trim() ?? '';
      final name = item['name']?.toString().trim() ?? '';
      if (id.isEmpty || name.isEmpty) continue;
      output.add(_SimpleEmote(
        id: id,
        name: name,
        imageUrl: _twitchEmoteUrl(id),
        kind: kind,
      ));
    }
    return output;
  }

  Future<List<_SimpleEmote>> _fetchSevenTvEmotes(String channelId) async {
    try {
      final response = await _dio.get<dynamic>(
        'https://7tv.io/v3/users/twitch/$channelId',
        options: Options(validateStatus: (status) => status != null && status < 500),
      );
      final raw = response.data;
      if (raw is! Map) return const <_SimpleEmote>[];
      final set = raw['emote_set'];
      if (set is! Map) return const <_SimpleEmote>[];
      final emotes = set['emotes'];
      if (emotes is! List) return const <_SimpleEmote>[];

      final output = <_SimpleEmote>[];
      for (final item in emotes.whereType<Map>()) {
        final name = item['name']?.toString().trim() ?? '';
        final data = item['data'];
        final id = data is Map ? data['id']?.toString().trim() ?? '' : '';
        final host = data is Map ? data['host'] : null;
        final hostUrl = host is Map ? host['url']?.toString().trim() ?? '' : '';
        if (name.isEmpty || id.isEmpty || hostUrl.isEmpty) continue;
        output.add(_SimpleEmote(
          id: id,
          name: name,
          imageUrl: 'https:$hostUrl/2x.webp',
          kind: _SimpleEmoteKind.sevenTv,
        ));
      }
      return output;
    } catch (_) {
      return const <_SimpleEmote>[];
    }
  }

  Future<List<_SimpleEmote>> _fetchBttvEmotes(String channelId) async {
    final output = <_SimpleEmote>[];

    try {
      final global = await _dio.get<dynamic>(
        'https://api.betterttv.net/3/cached/emotes/global',
        options: Options(validateStatus: (status) => status != null && status < 500),
      );
      output.addAll(_parseBttvList(global.data));
    } catch (_) {}

    try {
      final channel = await _dio.get<dynamic>(
        'https://api.betterttv.net/3/cached/users/twitch/$channelId',
        options: Options(validateStatus: (status) => status != null && status < 500),
      );
      final raw = channel.data;
      if (raw is Map) {
        output.addAll(_parseBttvList(raw['channelEmotes']));
        output.addAll(_parseBttvList(raw['sharedEmotes']));
      }
    } catch (_) {}

    return output;
  }

  List<_SimpleEmote> _parseBttvList(dynamic raw) {
    if (raw is! List) return const <_SimpleEmote>[];
    final output = <_SimpleEmote>[];
    for (final item in raw.whereType<Map>()) {
      final id = item['id']?.toString().trim() ?? '';
      final code = item['code']?.toString().trim() ?? '';
      if (id.isEmpty || code.isEmpty) continue;
      output.add(_SimpleEmote(
        id: id,
        name: code,
        imageUrl: 'https://cdn.betterttv.net/emote/$id/2x',
        kind: _SimpleEmoteKind.bttv,
      ));
    }
    return output;
  }

  Future<List<_SimpleEmote>> _fetchFfzEmotes(String channelId) async {
    final output = <_SimpleEmote>[];

    try {
      final response = await _dio.get<dynamic>(
        'https://api.frankerfacez.com/v1/room/id/$channelId',
        options: Options(validateStatus: (status) => status != null && status < 500),
      );
      final raw = response.data;
      if (raw is! Map) return const <_SimpleEmote>[];
      final sets = raw['sets'];
      if (sets is! Map) return const <_SimpleEmote>[];
      for (final set in sets.values.whereType<Map>()) {
        final emoticons = set['emoticons'];
        if (emoticons is! List) continue;
        for (final item in emoticons.whereType<Map>()) {
          final id = item['id']?.toString().trim() ?? '';
          final name = item['name']?.toString().trim() ?? '';
          final urls = item['urls'];
          String url = '';
          if (urls is Map) {
            url = (urls['2'] ?? urls['1'] ?? urls['4'])?.toString().trim() ?? '';
          }
          if (id.isEmpty || name.isEmpty || url.isEmpty) continue;
          output.add(_SimpleEmote(
            id: id,
            name: name,
            imageUrl: url.startsWith('//') ? 'https:$url' : url,
            kind: _SimpleEmoteKind.ffz,
          ));
        }
      }
    } catch (_) {}

    return output;
  }

  Future<void> _loadRecentEmotes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_recentStorageKey) ?? const <String>[];
      final next = <String, _SimpleEmote>{};
      for (final text in raw) {
        final parts = text.split('\t');
        if (parts.length < 4) continue;
        final kindIndex = int.tryParse(parts[3]) ?? _SimpleEmoteKind.twitchChannel.index;
        final kind = _SimpleEmoteKind.values[math.min(kindIndex, _SimpleEmoteKind.values.length - 1)];
        final emote = _SimpleEmote(
          id: parts[0],
          name: parts[1],
          imageUrl: parts[2],
          kind: kind,
        );
        if (emote.name.trim().isNotEmpty && emote.imageUrl.trim().isNotEmpty) {
          next[emote.name] = emote;
        }
      }
      if (!mounted) return;
      setState(() {
        _recentEmotes
          ..clear()
          ..addAll(next);
      });
    } catch (_) {}
  }

  Future<void> _saveRecentEmotes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = _recentEmotes.values
          .take(80)
          .map((emote) => '${emote.id}\t${emote.name}\t${emote.imageUrl}\t${emote.kind.index}')
          .toList(growable: false);
      await prefs.setStringList(_recentStorageKey, data);
    } catch (_) {}
  }

  void _markRecentEmote(_SimpleEmote emote) {
    setState(() {
      final next = <String, _SimpleEmote>{emote.name: emote};
      for (final entry in _recentEmotes.entries) {
        if (entry.key == emote.name) continue;
        if (next.length >= 80) break;
        next[entry.key] = entry.value;
      }
      _recentEmotes
        ..clear()
        ..addAll(next);
      _addEmoteToLookup(emote);
    });
    unawaited(_saveRecentEmotes());
  }

  void _insertEmoteText(_SimpleEmote emote) {
    final controller = _inputController;
    final text = controller.text;
    final selection = controller.selection;
    final start = selection.isValid ? selection.start : text.length;
    final end = selection.isValid ? selection.end : text.length;
    final safeStart = start.clamp(0, text.length).toInt();
    final safeEnd = end.clamp(0, text.length).toInt();

    final before = text.substring(0, safeStart);
    final after = text.substring(safeEnd);
    final needsLeftSpace = before.isNotEmpty && !before.endsWith(RegExp(r'\s'));
    final needsRightSpace = after.isNotEmpty && !after.startsWith(RegExp(r'\s'));
    final insert = '${needsLeftSpace ? ' ' : ''}${emote.name}${needsRightSpace ? ' ' : ' '}';
    final nextText = '$before$insert$after';
    final nextOffset = (before.length + insert.length).clamp(0, nextText.length).toInt();

    controller.value = TextEditingValue(
      text: nextText,
      selection: TextSelection.collapsed(offset: nextOffset),
    );
    _inputFocusNode.requestFocus();
    _markRecentEmote(emote);
  }

  void _setError(String message) {
    if (!mounted) return;
    setState(() {
      _errorText = message;
      _statusText = message;
    });
  }

  _SimpleEmote? _lookupEmoteByName(String text) {
    final clean = text.trim();
    if (clean.isEmpty) return null;
    return _emotesByExactName[clean] ?? _emotesByLowerName[clean.toLowerCase()];
  }

  List<_SimpleEmote> _emotesForKind(_SimpleEmoteFilter filter) {
    Iterable<_SimpleEmote> source;
    switch (filter) {
      case _SimpleEmoteFilter.recent:
        source = _recentEmotes.values;
        break;
      case _SimpleEmoteFilter.twitch:
        source = _emotesByExactName.values.where((item) => item.kind.isTwitch);
        break;
      case _SimpleEmoteFilter.sevenTv:
        source = _emotesByExactName.values.where((item) => item.kind == _SimpleEmoteKind.sevenTv);
        break;
      case _SimpleEmoteFilter.bttv:
        source = _emotesByExactName.values.where((item) => item.kind == _SimpleEmoteKind.bttv);
        break;
      case _SimpleEmoteFilter.ffz:
        source = _emotesByExactName.values.where((item) => item.kind == _SimpleEmoteKind.ffz);
        break;
      case _SimpleEmoteFilter.all:
        source = _emotesByExactName.values;
        break;
    }

    final list = source.toList(growable: false)
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return list;
  }

  Future<void> _showEmotePicker() async {
    final searchController = TextEditingController();
    String keyword = '';

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF0E0E10),
      barrierColor: Colors.black.withOpacity(0.42),
      isScrollControlled: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SizedBox(
              height: MediaQuery.of(context).size.height * 0.62,
              child: DefaultTabController(
                length: _SimpleEmoteFilter.values.length,
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.fromLTRB(14, 12, 8, 8),
                      decoration: const BoxDecoration(
                        color: Color(0xFF18181B),
                        border: Border(bottom: BorderSide(color: Color(0xFF2D2D35))),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.emoji_emotions, color: Color(0xFFBF94FF), size: 20),
                          const SizedBox(width: 9),
                          Expanded(
                            child: Text(
                              _loadingEmotes ? '貼圖讀取中...' : '貼圖',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: null,
                            onPressed: () => unawaited(_loadEmoteCatalog()),
                            icon: const Icon(Icons.refresh, color: Colors.white70, size: 20),
                          ),
                          IconButton(
                            tooltip: null,
                            onPressed: () => Navigator.of(sheetContext).pop(),
                            icon: const Icon(Icons.close, color: Colors.white70, size: 20),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                      child: TextField(
                        controller: searchController,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                        cursorColor: const Color(0xFFBF94FF),
                        decoration: InputDecoration(
                          isDense: true,
                          hintText: '搜尋貼圖',
                          hintStyle: const TextStyle(color: Colors.white38),
                          prefixIcon: const Icon(Icons.search, color: Colors.white54, size: 18),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.065),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        onChanged: (value) {
                          setSheetState(() => keyword = value.trim().toLowerCase());
                        },
                      ),
                    ),
                    const TabBar(
                      isScrollable: true,
                      labelColor: Color(0xFFBF94FF),
                      unselectedLabelColor: Colors.white54,
                      indicatorColor: Color(0xFF9146FF),
                      tabs: [
                        Tab(text: 'Recent'),
                        Tab(text: 'Twitch'),
                        Tab(text: '7TV'),
                        Tab(text: 'BTTV'),
                        Tab(text: 'FFZ'),
                        Tab(text: '全部'),
                      ],
                    ),
                    Expanded(
                      child: TabBarView(
                        children: _SimpleEmoteFilter.values.map((filter) {
                          final items = _emotesForKind(filter).where((emote) {
                            if (keyword.isEmpty) return true;
                            return emote.name.toLowerCase().contains(keyword);
                          }).toList(growable: false);

                          if (items.isEmpty) {
                            return Center(
                              child: Text(
                                _loadingEmotes ? '讀取中...' : '沒有貼圖',
                                style: const TextStyle(color: Colors.white54),
                              ),
                            );
                          }

                          return GridView.builder(
                            padding: const EdgeInsets.all(12),
                            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                              maxCrossAxisExtent: 92,
                              mainAxisSpacing: 10,
                              crossAxisSpacing: 10,
                              childAspectRatio: 0.82,
                            ),
                            itemCount: items.length,
                            itemBuilder: (context, index) {
                              final emote = items[index];
                              return _EmotePickerTile(
                                emote: emote,
                                onTap: () => _insertEmoteText(emote),
                              );
                            },
                          );
                        }).toList(growable: false),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    searchController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF0E0E10),
      child: Row(
        children: [
          _ResizeHandle(
            onDelta: widget.onWidthDelta,
            onEnd: widget.onWidthDragEnd,
          ),
          Expanded(
            child: Column(
              children: [
                _buildHeader(),
                if (_errorText != null)
                  _ChatStatusBanner(
                    text: _errorText!,
                    color: Colors.redAccent,
                  ),
                Expanded(child: _buildMessageList()),
                _buildInputBar(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      height: 58,
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      decoration: const BoxDecoration(
        color: Color(0xFF18181B),
        border: Border(bottom: BorderSide(color: Color(0xFF2D2D35))),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFF9146FF).withOpacity(0.18),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF9146FF).withOpacity(0.35)),
            ),
            child: const Icon(Icons.chat_bubble, color: Color(0xFFBF94FF), size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$_displayName 聊天室',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${_connected ? '已連線' : _statusText}｜${_messages.length} 則｜${_emotesByExactName.length} 貼圖｜raw $_rawLineCount',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: null,
            onPressed: _showEmotePicker,
            icon: const Icon(Icons.emoji_emotions_outlined, color: Colors.white70, size: 20),
          ),
          IconButton(
            tooltip: null,
            onPressed: () => unawaited(_restart()),
            icon: _connecting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFBF94FF)),
                  )
                : const Icon(Icons.refresh, color: Colors.white70, size: 20),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageList() {
    if (_messages.isEmpty) {
      return Center(
        child: Text(
          _connecting ? '正在連線聊天室...' : '等待聊天室訊息...',
          style: const TextStyle(color: Colors.white54),
        ),
      );
    }

    return ListView.builder(
      reverse: true,
      padding: const EdgeInsets.fromLTRB(6, 8, 6, 8),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final message = _messages[_messages.length - 1 - index];
        return _SimpleChatMessageTile(
          key: ValueKey<String>(message.id),
          message: message,
          emoteResolver: _lookupEmoteByName,
        );
      },
    );
  }

  Widget _buildInputBar() {
    final canSend = _connected && !_sending;

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
      decoration: const BoxDecoration(
        color: Color(0xFF18181B),
        border: Border(top: BorderSide(color: Color(0xFF2D2D35))),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: null,
            onPressed: _showEmotePicker,
            icon: const Icon(Icons.emoji_emotions_outlined, color: Colors.white70, size: 21),
          ),
          Expanded(
            child: TextField(
              controller: _inputController,
              focusNode: _inputFocusNode,
              enabled: canSend,
              maxLines: 1,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => unawaited(_sendMessage()),
              style: const TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w700),
              cursorColor: const Color(0xFFBF94FF),
              decoration: InputDecoration(
                isDense: true,
                hintText: _authToken == null || _authToken!.isEmpty
                    ? '登入後可發言'
                    : '輸入聊天室訊息...',
                hintStyle: const TextStyle(color: Colors.white38),
                filled: true,
                fillColor: Colors.white.withOpacity(0.065),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(999),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Material(
            color: canSend ? const Color(0xFF9146FF) : Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(999),
            child: InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: canSend ? () => unawaited(_sendMessage()) : null,
              child: SizedBox(
                width: 42,
                height: 42,
                child: Center(
                  child: _sending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Icon(Icons.send_rounded, color: canSend ? Colors.white : Colors.white38, size: 19),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SimpleChatMessageTile extends StatelessWidget {
  final _SimpleChatMessage message;
  final _SimpleEmote? Function(String text) emoteResolver;

  const _SimpleChatMessageTile({
    super.key,
    required this.message,
    required this.emoteResolver,
  });

  @override
  Widget build(BuildContext context) {
    final background = message.system
        ? const Color(0xFF241A35)
        : const Color(0xFF18181B);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withOpacity(message.system ? 0.10 : 0.055)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(9, 6, 9, 7),
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: message.displayName,
                  style: TextStyle(
                    color: message.color,
                    fontSize: 13.2,
                    fontWeight: FontWeight.w900,
                    height: 1.28,
                  ),
                ),
                TextSpan(
                  text: message.system ? '：' : ': ',
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 13.2,
                    fontWeight: FontWeight.w700,
                    height: 1.28,
                  ),
                ),
                ..._buildMessageContentSpans(message, emoteResolver),
              ],
            ),
            textAlign: TextAlign.left,
          ),
        ),
      ),
    );
  }
}

List<InlineSpan> _buildMessageContentSpans(
  _SimpleChatMessage message,
  _SimpleEmote? Function(String text) emoteResolver,
) {
  final text = message.text;
  final ranges = _parseTwitchEmoteRanges(text, message.emotesTag);
  final spans = <InlineSpan>[];
  var cursor = 0;

  for (final range in ranges) {
    if (range.start > cursor) {
      _appendTextLookupSpans(spans, text.substring(cursor, range.start), emoteResolver);
    }
    spans.add(_emoteSpan(
      imageUrl: _twitchEmoteUrl(range.id),
      fallback: range.code,
      height: 28,
    ));
    cursor = math.max(cursor, range.endExclusive);
  }

  if (cursor < text.length) {
    _appendTextLookupSpans(spans, text.substring(cursor), emoteResolver);
  }

  if (spans.isEmpty) {
    spans.add(TextSpan(text: text, style: _messageTextStyle));
  }

  return spans;
}

void _appendTextLookupSpans(
  List<InlineSpan> spans,
  String text,
  _SimpleEmote? Function(String text) emoteResolver,
) {
  if (text.isEmpty) return;
  final regex = RegExp(r'(\s+|\S+)');

  for (final match in regex.allMatches(text)) {
    final raw = match.group(0) ?? '';
    if (raw.isEmpty) continue;
    if (raw.trim().isEmpty) {
      spans.add(TextSpan(text: raw, style: _messageTextStyle));
      continue;
    }

    final normalized = _stripLookupPunctuation(raw);
    final emote = normalized.core.isEmpty ? null : emoteResolver(normalized.core);
    if (emote == null) {
      spans.add(TextSpan(text: raw, style: _messageTextStyle));
      continue;
    }

    if (normalized.leading.isNotEmpty) {
      spans.add(TextSpan(text: normalized.leading, style: _messageTextStyle));
    }
    spans.add(_emoteSpan(imageUrl: emote.imageUrl, fallback: emote.name, height: 28));
    if (normalized.trailing.isNotEmpty) {
      spans.add(TextSpan(text: normalized.trailing, style: _messageTextStyle));
    }
  }
}

WidgetSpan _emoteSpan({
  required String imageUrl,
  required String fallback,
  required double height,
}) {
  return WidgetSpan(
    alignment: PlaceholderAlignment.middle,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 1.5),
      child: Image.network(
        imageUrl,
        height: height,
        fit: BoxFit.contain,
        gaplessPlayback: true,
        filterQuality: FilterQuality.medium,
        errorBuilder: (context, error, stackTrace) {
          return Text(fallback, style: _messageTextStyle);
        },
      ),
    ),
  );
}

const TextStyle _messageTextStyle = TextStyle(
  color: Colors.white,
  fontSize: 13.2,
  height: 1.28,
  fontWeight: FontWeight.w500,
);

List<_TwitchEmoteRange> _parseTwitchEmoteRanges(String text, String tag) {
  final clean = tag.trim();
  if (clean.isEmpty) return const <_TwitchEmoteRange>[];

  final output = <_TwitchEmoteRange>[];
  for (final group in clean.split('/')) {
    final separator = group.indexOf(':');
    if (separator <= 0 || separator >= group.length - 1) continue;
    final id = group.substring(0, separator).trim();
    final ranges = group.substring(separator + 1).split(',');
    for (final range in ranges) {
      final dash = range.indexOf('-');
      if (dash <= 0 || dash >= range.length - 1) continue;
      final start = int.tryParse(range.substring(0, dash));
      final end = int.tryParse(range.substring(dash + 1));
      if (start == null || end == null || start < 0 || end < start || start >= text.length) {
        continue;
      }
      final endExclusive = math.min(end + 1, text.length);
      output.add(_TwitchEmoteRange(
        id: id,
        start: start,
        endExclusive: endExclusive,
        code: text.substring(start, endExclusive),
      ));
    }
  }

  output.sort((a, b) => a.start.compareTo(b.start));
  final filtered = <_TwitchEmoteRange>[];
  var cursor = 0;
  for (final item in output) {
    if (item.start < cursor) continue;
    filtered.add(item);
    cursor = item.endExclusive;
  }
  return filtered;
}

_NormalizedToken _stripLookupPunctuation(String token) {
  var start = 0;
  var end = token.length;
  while (start < end && _isLeadingPunctuation(token.codeUnitAt(start))) {
    start += 1;
  }
  while (end > start && _isTrailingPunctuation(token.codeUnitAt(end - 1))) {
    end -= 1;
  }
  return _NormalizedToken(
    leading: token.substring(0, start),
    core: token.substring(start, end),
    trailing: token.substring(end),
  );
}

bool _isLeadingPunctuation(int codeUnit) {
  return codeUnit == 0x28 || codeUnit == 0x5B || codeUnit == 0x7B ||
      codeUnit == 0x3C || codeUnit == 0x22 || codeUnit == 0x27;
}

bool _isTrailingPunctuation(int codeUnit) {
  return codeUnit == 0x29 || codeUnit == 0x5D || codeUnit == 0x7D ||
      codeUnit == 0x3E || codeUnit == 0x22 || codeUnit == 0x27 ||
      codeUnit == 0x2E || codeUnit == 0x2C || codeUnit == 0x21 ||
      codeUnit == 0x3F || codeUnit == 0x3A || codeUnit == 0x3B;
}

String _twitchEmoteUrl(String id) {
  return 'https://static-cdn.jtvnw.net/emoticons/v2/$id/default/dark/2.0';
}

Color? _parseUserColor(String? raw) {
  final text = raw?.trim();
  if (text == null || text.isEmpty) return null;
  final normalized = text.startsWith('#') ? text.substring(1) : text;
  if (!RegExp(r'^[0-9a-fA-F]{6}$').hasMatch(normalized)) return null;
  return Color(int.parse('FF$normalized', radix: 16));
}

Color _colorFromText(String text) {
  final source = text.trim().isEmpty ? 'twitch' : text.trim().toLowerCase();
  var hash = 0;
  for (final unit in source.codeUnits) {
    hash = (hash * 31 + unit) & 0x7fffffff;
  }
  const colors = <Color>[
    Color(0xFFBF94FF),
    Color(0xFF00A3FF),
    Color(0xFF00F5D4),
    Color(0xFFFF75E6),
    Color(0xFFFFB000),
    Color(0xFFFF5C7A),
    Color(0xFF7DD3FC),
  ];
  return colors[hash % colors.length];
}

class _EmotePickerTile extends StatelessWidget {
  final _SimpleEmote emote;
  final VoidCallback onTap;

  const _EmotePickerTile({
    required this.emote,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withOpacity(0.055),
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(7),
          child: Column(
            children: [
              Expanded(
                child: Center(
                  child: Image.network(
                    emote.imageUrl,
                    fit: BoxFit.contain,
                    gaplessPlayback: true,
                    errorBuilder: (context, error, stackTrace) {
                      return const Icon(Icons.broken_image, color: Colors.white38, size: 20);
                    },
                  ),
                ),
              ),
              const SizedBox(height: 5),
              Text(
                emote.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChatStatusBanner extends StatelessWidget {
  final String text;
  final Color color;

  const _ChatStatusBanner({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      color: color.withOpacity(0.14),
      child: Text(
        text,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: color,
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
          height: 1.25,
        ),
      ),
    );
  }
}

class _ResizeHandle extends StatelessWidget {
  final ValueChanged<double> onDelta;
  final VoidCallback onEnd;

  const _ResizeHandle({required this.onDelta, required this.onEnd});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragUpdate: (details) => onDelta(details.delta.dx),
      onHorizontalDragEnd: (_) => onEnd(),
      child: MouseRegion(
        cursor: SystemMouseCursors.resizeLeftRight,
        child: SizedBox(
          width: 7,
          child: Center(
            child: Container(
              width: 2,
              height: 46,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.16),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SimpleChatMessage {
  final String id;
  final String login;
  final String displayName;
  final Color color;
  final String text;
  final String emotesTag;
  final DateTime receivedAt;
  final bool system;

  const _SimpleChatMessage({
    required this.id,
    required this.login,
    required this.displayName,
    required this.color,
    required this.text,
    required this.emotesTag,
    required this.receivedAt,
    required this.system,
  });
}

class _SimpleEmote {
  final String id;
  final String name;
  final String imageUrl;
  final _SimpleEmoteKind kind;

  const _SimpleEmote({
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.kind,
  });
}

enum _SimpleEmoteKind {
  twitchChannel,
  twitchGlobal,
  sevenTv,
  bttv,
  ffz;

  bool get isTwitch {
    return this == _SimpleEmoteKind.twitchChannel ||
        this == _SimpleEmoteKind.twitchGlobal;
  }
}

enum _SimpleEmoteFilter {
  recent,
  twitch,
  sevenTv,
  bttv,
  ffz,
  all,
}

class _TwitchEmoteRange {
  final String id;
  final int start;
  final int endExclusive;
  final String code;

  const _TwitchEmoteRange({
    required this.id,
    required this.start,
    required this.endExclusive,
    required this.code,
  });
}

class _NormalizedToken {
  final String leading;
  final String core;
  final String trailing;

  const _NormalizedToken({
    required this.leading,
    required this.core,
    required this.trailing,
  });
}

class _ParsedIrcLine {
  final Map<String, String> tags;
  final String prefix;
  final String command;
  final List<String> params;
  final String trailing;

  const _ParsedIrcLine({
    required this.tags,
    required this.prefix,
    required this.command,
    required this.params,
    required this.trailing,
  });

  String get userLogin {
    if (prefix.isEmpty) return '';
    final bang = prefix.indexOf('!');
    if (bang <= 0) return prefix;
    return prefix.substring(0, bang);
  }

  static _ParsedIrcLine parse(String line) {
    var rest = line.trimRight();
    final tags = <String, String>{};
    var prefix = '';
    var trailing = '';

    if (rest.startsWith('@')) {
      final space = rest.indexOf(' ');
      if (space > 0) {
        final rawTags = rest.substring(1, space);
        rest = rest.substring(space + 1);
        for (final pair in rawTags.split(';')) {
          if (pair.isEmpty) continue;
          final equals = pair.indexOf('=');
          if (equals < 0) {
            tags[pair] = '';
          } else {
            tags[pair.substring(0, equals)] = _decodeIrcTag(pair.substring(equals + 1));
          }
        }
      }
    }

    if (rest.startsWith(':')) {
      final space = rest.indexOf(' ');
      if (space > 0) {
        prefix = rest.substring(1, space);
        rest = rest.substring(space + 1);
      }
    }

    final trailingIndex = rest.indexOf(' :');
    if (trailingIndex >= 0) {
      trailing = rest.substring(trailingIndex + 2);
      rest = rest.substring(0, trailingIndex);
    }

    final parts = rest.split(' ').where((part) => part.isNotEmpty).toList(growable: false);
    final command = parts.isEmpty ? '' : parts.first;
    final params = parts.length <= 1 ? const <String>[] : parts.sublist(1);

    return _ParsedIrcLine(
      tags: tags,
      prefix: prefix,
      command: command,
      params: params,
      trailing: _decodeIrcTag(trailing),
    );
  }
}

String _decodeIrcTag(String value) {
  return value
      .replaceAll(r'\s', ' ')
      .replaceAll(r'\:', ';')
      .replaceAll(r'\\', r'\')
      .replaceAll(r'\r', '\r')
      .replaceAll(r'\n', '\n');
}
