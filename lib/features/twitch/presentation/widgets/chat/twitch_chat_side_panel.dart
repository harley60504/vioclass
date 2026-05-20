import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vio_class/features/twitch/auth/services/twitch_web_cookie_service.dart';
import 'package:vio_class/features/twitch/data/models/twitch_stream_model.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

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
  static const String _clientId = 'kimne78kx3ncx6brgo4mv6wki5h1ko';
  static const int _maxMessages = 450;

  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: const <String, String>{
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)',
      },
    ),
  );

  final TextEditingController _inputController = TextEditingController();
  final FocusNode _inputFocusNode = FocusNode();

  WebSocketChannel? _irc;
  StreamSubscription<dynamic>? _ircSub;

  final List<_ChatMsg> _messages = <_ChatMsg>[];
  final Set<String> _seenIds = <String>{};
  final Map<String, _Emote> _emoteExact = <String, _Emote>{};
  final Map<String, _Emote> _emoteLower = <String, _Emote>{};
  final Map<String, _Emote> _recent = <String, _Emote>{};

  String? _authToken;
  String? _viewerLogin;
  String? _channelId;
  String? _errorText;
  String _status = '初始化聊天室...';
  bool _connecting = false;
  bool _connected = false;
  bool _loadingEmotes = false;
  bool _sending = false;
  int _rawCount = 0;

  String get _channelLogin {
    final login = widget.stream.userLogin.trim();
    if (login.isNotEmpty) return login.toLowerCase();
    return widget.stream.userName.trim().toLowerCase();
  }

  String get _displayName {
    final name = widget.stream.userName.trim();
    return name.isNotEmpty ? name : _channelLogin;
  }

  String get _recentKey => 'simple_twitch_recent_emotes_$_channelLogin';

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
    if (oldLogin != _channelLogin) unawaited(_restart());
  }

  @override
  void dispose() {
    unawaited(_disconnect());
    _dio.close(force: true);
    _inputController.dispose();
    _inputFocusNode.dispose();
    super.dispose();
  }

  Future<void> _restart() async {
    await _disconnect();
    if (!mounted) return;
    setState(() {
      _messages.clear();
      _seenIds.clear();
      _emoteExact.clear();
      _emoteLower.clear();
      _recent.clear();
      _status = '初始化聊天室...';
      _errorText = null;
      _connected = false;
      _connecting = true;
      _rawCount = 0;
    });
    await _loadRecent();
    await _loadContext();
    if (!mounted) return;
    unawaited(_loadEmotes());
    await _connect();
  }

  Future<void> _loadContext() async {
    final token = await TwitchWebCookieService.readAuthToken();
    String? viewerLogin;
    String? channelId;

    try {
      channelId = await _fetchChannelId(_channelLogin);
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

  Future<String?> _fetchChannelId(String login) async {
    final clean = login.trim().toLowerCase();
    if (clean.isEmpty) return null;
    final res = await _dio.post<dynamic>(
      'https://gql.twitch.tv/gql',
      data: <String, dynamic>{
        'operationName': 'SimpleChatChannelId',
        'query': 'query SimpleChatChannelId(\$login: String!) { user(login: \$login) { id displayName } }',
        'variables': <String, dynamic>{'login': clean},
      },
      options: Options(
        headers: const <String, String>{
          'Client-ID': _clientId,
          'Content-Type': 'application/json',
        },
        validateStatus: (s) => s != null && s < 500,
      ),
    );
    final data = res.data;
    if (data is! Map) return null;
    final root = data['data'];
    if (root is! Map) return null;
    final user = root['user'];
    if (user is! Map) return null;
    final id = user['id']?.toString().trim();
    return id == null || id.isEmpty ? null : id;
  }

  Future<String?> _fetchViewerLogin(String token) async {
    final res = await _dio.get<dynamic>(
      'https://api.twitch.tv/helix/users',
      options: Options(
        headers: <String, String>{
          'Client-ID': _clientId,
          'Authorization': 'Bearer $token',
        },
        validateStatus: (s) => s != null && s < 500,
      ),
    );
    final data = res.data;
    if (data is! Map) return null;
    final list = data['data'];
    if (list is! List || list.isEmpty) return null;
    final first = list.first;
    if (first is! Map) return null;
    final login = first['login']?.toString().trim().toLowerCase();
    return login == null || login.isEmpty ? null : login;
  }

  Future<void> _connect() async {
    if (!mounted) return;
    setState(() {
      _connecting = true;
      _status = '連線 Twitch IRC...';
    });
    try {
      final ws = WebSocketChannel.connect(Uri.parse(_ircUrl));
      _irc = ws;
      _ircSub = ws.stream.listen(
        _onIrcEvent,
        onError: (Object e, StackTrace s) => _setError('IRC 連線錯誤：$e'),
        onDone: () {
          if (!mounted) return;
          setState(() {
            _connected = false;
            _connecting = false;
            _status = '聊天室已中斷';
          });
        },
        cancelOnError: false,
      );

      final token = _authToken;
      final viewer = _viewerLogin;
      final canAuth = token != null && token.isNotEmpty && viewer != null && viewer.isNotEmpty;
      final nick = canAuth
          ? viewer
          : 'justinfan${DateTime.now().millisecondsSinceEpoch.remainder(900000) + 100000}';

      _sendRaw('CAP REQ :twitch.tv/tags twitch.tv/commands twitch.tv/membership');
      if (canAuth) {
        _sendRaw('PASS oauth:$token');
        _sendRaw('NICK $nick');
      } else {
        _sendRaw('PASS SCHMOOPIIE');
        _sendRaw('NICK $nick');
      }
      _sendRaw('JOIN #$_channelLogin');

      if (!mounted) return;
      setState(() {
        _connected = true;
        _connecting = false;
        _status = canAuth ? '聊天室已連線' : '匿名讀取聊天室';
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

  Future<void> _disconnect() async {
    await _ircSub?.cancel();
    _ircSub = null;
    final socket = _irc;
    _irc = null;
    await socket?.sink.close();
  }

  void _sendRaw(String line) {
    _irc?.sink.add('$line\r\n');
  }

  void _onIrcEvent(dynamic event) {
    final text = event is List<int> ? utf8.decode(event) : event.toString();
    for (final rawLine in text.split(RegExp(r'\r?\n'))) {
      final line = rawLine.trimRight();
      if (line.trim().isEmpty) continue;
      _rawCount += 1;
      if (line.startsWith('PING')) {
        _sendRaw('PONG :tmi.twitch.tv');
        continue;
      }
      final parsed = _IrcLine.parse(line);
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
      }
    }
  }

  void _handlePrivMsg(_IrcLine line) {
    final text = line.trailing.trimRight();
    if (text.isEmpty) return;
    final id = line.tags['id']?.trim();
    final safeId = id != null && id.isNotEmpty
        ? id
        : 'msg-${DateTime.now().microsecondsSinceEpoch}-${_messages.length}';
    if (_seenIds.contains(safeId)) return;
    _seenIds.add(safeId);
    final login = line.userLogin.isNotEmpty ? line.userLogin : 'unknown';
    final displayName = line.tags['display-name']?.trim().isNotEmpty == true
        ? line.tags['display-name']!.trim()
        : login;
    _appendMessage(_ChatMsg(
      id: safeId,
      login: login,
      displayName: displayName,
      color: _parseColor(line.tags['color']) ?? _colorFromText(login),
      text: text,
      emotesTag: line.tags['emotes'] ?? '',
      system: false,
    ));
  }

  void _handleNotice(_IrcLine line) {
    final text = line.trailing.trim();
    if (text.isNotEmpty) _appendSystem(text);
  }

  void _handleUserNotice(_IrcLine line) {
    final system = line.tags['system-msg']?.trim();
    final text = system != null && system.isNotEmpty ? system : line.trailing.trim();
    if (text.isNotEmpty) _appendSystem(text);
  }

  void _handleClearMsg(_IrcLine line) {
    final id = line.tags['target-msg-id']?.trim();
    if (id == null || id.isEmpty || !mounted) return;
    setState(() {
      _messages.removeWhere((m) => m.id == id);
      _seenIds.remove(id);
    });
  }

  void _handleClearChat(_IrcLine line) {
    if (!mounted) return;
    final login = line.trailing.trim().toLowerCase();
    if (login.isEmpty) {
      setState(() {
        _messages.clear();
        _seenIds.clear();
      });
      _appendSystem('聊天室已被清除。');
      return;
    }
    setState(() {
      _messages.removeWhere((m) => m.login.toLowerCase() == login);
    });
  }

  void _appendSystem(String text) {
    _appendMessage(_ChatMsg(
      id: 'system-${DateTime.now().microsecondsSinceEpoch}',
      login: 'system',
      displayName: 'Twitch',
      color: const Color(0xFFBF94FF),
      text: text,
      emotesTag: '',
      system: true,
    ));
  }

  void _appendMessage(_ChatMsg msg) {
    if (!mounted) return;
    setState(() {
      _messages.add(msg);
      while (_messages.length > _maxMessages) {
        final old = _messages.removeAt(0);
        _seenIds.remove(old.id);
      }
    });
  }

  Future<void> _sendMessage() async {
    if (_sending) return;
    final text = _inputController.text.replaceAll(RegExp(r'[\r\n]+'), ' ').trim();
    if (text.isEmpty) return;
    final token = _authToken;
    final viewer = _viewerLogin;
    if (token == null || token.isEmpty || viewer == null || viewer.isEmpty) {
      _appendSystem('尚未取得可發言的 Twitch Web token，請重新登入。');
      return;
    }
    setState(() => _sending = true);
    try {
      _sendRaw('PRIVMSG #$_channelLogin :$text');
      _inputController.clear();
    } catch (e) {
      _appendSystem('送出失敗：$e');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _loadEmotes() async {
    if (!mounted) return;
    setState(() {
      _loadingEmotes = true;
      _status = '讀取貼圖...';
    });
    final out = <_Emote>[];
    final token = _authToken;
    final channelId = _channelId;
    try {
      if (token != null && token.isNotEmpty) {
        out.addAll(await _fetchTwitchGlobal(token));
        if (channelId != null && channelId.isNotEmpty) {
          out.addAll(await _fetchTwitchChannel(token, channelId));
        }
      }
      if (channelId != null && channelId.isNotEmpty) {
        out.addAll(await _fetchSevenTv(channelId));
        out.addAll(await _fetchBttv(channelId));
        out.addAll(await _fetchFfz(channelId));
      }
    } catch (e) {
      _setError('貼圖讀取失敗：$e');
    }
    if (!mounted) return;
    setState(() {
      _emoteExact.clear();
      _emoteLower.clear();
      for (final e in out) {
        _addEmote(e);
      }
      for (final e in _recent.values) {
        _addEmote(e);
      }
      _loadingEmotes = false;
      _status = _connected ? '聊天室已連線' : _status;
    });
  }

  void _addEmote(_Emote e) {
    final name = e.name.trim();
    if (name.isEmpty || e.imageUrl.trim().isEmpty) return;
    final old = _emoteExact[name];
    if (old == null || e.kind.index < old.kind.index) {
      _emoteExact[name] = e;
      _emoteLower[name.toLowerCase()] = e;
    }
  }

  Future<List<_Emote>> _fetchTwitchGlobal(String token) async {
    final res = await _dio.get<dynamic>(
      'https://api.twitch.tv/helix/chat/emotes/global',
      options: _helixOptions(token),
    );
    return _parseHelixEmotes(res.data, _EmoteKind.twitchGlobal);
  }

  Future<List<_Emote>> _fetchTwitchChannel(String token, String channelId) async {
    final res = await _dio.get<dynamic>(
      'https://api.twitch.tv/helix/chat/emotes',
      queryParameters: <String, dynamic>{'broadcaster_id': channelId},
      options: _helixOptions(token),
    );
    return _parseHelixEmotes(res.data, _EmoteKind.twitchChannel);
  }

  Options _helixOptions(String token) {
    return Options(
      headers: <String, String>{
        'Client-ID': _clientId,
        'Authorization': 'Bearer $token',
      },
      validateStatus: (s) => s != null && s < 500,
    );
  }

  List<_Emote> _parseHelixEmotes(dynamic raw, _EmoteKind kind) {
    if (raw is! Map || raw['data'] is! List) return const <_Emote>[];
    final out = <_Emote>[];
    for (final item in (raw['data'] as List).whereType<Map>()) {
      final id = item['id']?.toString().trim() ?? '';
      final name = item['name']?.toString().trim() ?? '';
      if (id.isEmpty || name.isEmpty) continue;
      out.add(_Emote(id: id, name: name, imageUrl: _twitchEmoteUrl(id), kind: kind));
    }
    return out;
  }

  Future<List<_Emote>> _fetchSevenTv(String channelId) async {
    try {
      final res = await _dio.get<dynamic>('https://7tv.io/v3/users/twitch/$channelId');
      final raw = res.data;
      if (raw is! Map) return const <_Emote>[];
      final set = raw['emote_set'];
      if (set is! Map || set['emotes'] is! List) return const <_Emote>[];
      final out = <_Emote>[];
      for (final item in (set['emotes'] as List).whereType<Map>()) {
        final name = item['name']?.toString().trim() ?? '';
        final data = item['data'];
        final id = data is Map ? data['id']?.toString().trim() ?? '' : '';
        final host = data is Map ? data['host'] : null;
        final hostUrl = host is Map ? host['url']?.toString().trim() ?? '' : '';
        if (name.isEmpty || id.isEmpty || hostUrl.isEmpty) continue;
        out.add(_Emote(id: id, name: name, imageUrl: 'https:$hostUrl/2x.webp', kind: _EmoteKind.sevenTv));
      }
      return out;
    } catch (_) {
      return const <_Emote>[];
    }
  }

  Future<List<_Emote>> _fetchBttv(String channelId) async {
    final out = <_Emote>[];
    try {
      final g = await _dio.get<dynamic>('https://api.betterttv.net/3/cached/emotes/global');
      out.addAll(_parseBttv(g.data));
    } catch (_) {}
    try {
      final c = await _dio.get<dynamic>('https://api.betterttv.net/3/cached/users/twitch/$channelId');
      final raw = c.data;
      if (raw is Map) {
        out.addAll(_parseBttv(raw['channelEmotes']));
        out.addAll(_parseBttv(raw['sharedEmotes']));
      }
    } catch (_) {}
    return out;
  }

  List<_Emote> _parseBttv(dynamic raw) {
    if (raw is! List) return const <_Emote>[];
    final out = <_Emote>[];
    for (final item in raw.whereType<Map>()) {
      final id = item['id']?.toString().trim() ?? '';
      final code = item['code']?.toString().trim() ?? '';
      if (id.isEmpty || code.isEmpty) continue;
      out.add(_Emote(id: id, name: code, imageUrl: 'https://cdn.betterttv.net/emote/$id/2x', kind: _EmoteKind.bttv));
    }
    return out;
  }

  Future<List<_Emote>> _fetchFfz(String channelId) async {
    try {
      final res = await _dio.get<dynamic>('https://api.frankerfacez.com/v1/room/id/$channelId');
      final raw = res.data;
      if (raw is! Map || raw['sets'] is! Map) return const <_Emote>[];
      final out = <_Emote>[];
      for (final set in (raw['sets'] as Map).values.whereType<Map>()) {
        final emoticons = set['emoticons'];
        if (emoticons is! List) continue;
        for (final item in emoticons.whereType<Map>()) {
          final id = item['id']?.toString().trim() ?? '';
          final name = item['name']?.toString().trim() ?? '';
          final urls = item['urls'];
          final url = urls is Map ? (urls['2'] ?? urls['1'] ?? urls['4'])?.toString().trim() ?? '' : '';
          if (id.isEmpty || name.isEmpty || url.isEmpty) continue;
          out.add(_Emote(id: id, name: name, imageUrl: url.startsWith('//') ? 'https:$url' : url, kind: _EmoteKind.ffz));
        }
      }
      return out;
    } catch (_) {
      return const <_Emote>[];
    }
  }

  Future<void> _loadRecent() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rows = prefs.getStringList(_recentKey) ?? const <String>[];
      final next = <String, _Emote>{};
      for (final row in rows) {
        final p = row.split('\t');
        if (p.length < 4) continue;
        final kindIndex = int.tryParse(p[3]) ?? _EmoteKind.twitchChannel.index;
        final kind = _EmoteKind.values[math.min(kindIndex, _EmoteKind.values.length - 1)];
        final e = _Emote(id: p[0], name: p[1], imageUrl: p[2], kind: kind);
        if (e.name.isNotEmpty && e.imageUrl.isNotEmpty) next[e.name] = e;
      }
      if (!mounted) return;
      setState(() => _recent.addAll(next));
    } catch (_) {}
  }

  Future<void> _saveRecent() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rows = _recent.values.take(80).map((e) => '${e.id}\t${e.name}\t${e.imageUrl}\t${e.kind.index}').toList(growable: false);
      await prefs.setStringList(_recentKey, rows);
    } catch (_) {}
  }

  void _markRecent(_Emote e) {
    setState(() {
      final next = <String, _Emote>{e.name: e};
      for (final entry in _recent.entries) {
        if (entry.key == e.name) continue;
        if (next.length >= 80) break;
        next[entry.key] = entry.value;
      }
      _recent
        ..clear()
        ..addAll(next);
      _addEmote(e);
    });
    unawaited(_saveRecent());
  }

  void _insertEmote(_Emote e) {
    final text = _inputController.text;
    final sel = _inputController.selection;
    final start = (sel.isValid ? sel.start : text.length).clamp(0, text.length).toInt();
    final end = (sel.isValid ? sel.end : text.length).clamp(0, text.length).toInt();
    final before = text.substring(0, start);
    final after = text.substring(end);
    final leftSpace = before.isEmpty || before.endsWith(' ') || before.endsWith('\t');
    final rightSpace = after.isEmpty || after.startsWith(' ') || after.startsWith('\t');
    final insert = '${leftSpace ? '' : ' '}${e.name}${rightSpace ? ' ' : ' '}';
    final next = '$before$insert$after';
    _inputController.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: (before.length + insert.length).clamp(0, next.length).toInt()),
    );
    _inputFocusNode.requestFocus();
    _markRecent(e);
  }

  _Emote? _lookupEmote(String code) {
    final clean = code.trim();
    if (clean.isEmpty) return null;
    return _emoteExact[clean] ?? _emoteLower[clean.toLowerCase()];
  }

  List<_Emote> _emotesFor(_EmoteFilter filter) {
    Iterable<_Emote> source;
    switch (filter) {
      case _EmoteFilter.recent:
        source = _recent.values;
        break;
      case _EmoteFilter.twitch:
        source = _emoteExact.values.where((e) => e.kind.isTwitch);
        break;
      case _EmoteFilter.sevenTv:
        source = _emoteExact.values.where((e) => e.kind == _EmoteKind.sevenTv);
        break;
      case _EmoteFilter.bttv:
        source = _emoteExact.values.where((e) => e.kind == _EmoteKind.bttv);
        break;
      case _EmoteFilter.ffz:
        source = _emoteExact.values.where((e) => e.kind == _EmoteKind.ffz);
        break;
      case _EmoteFilter.all:
        source = _emoteExact.values;
        break;
    }
    final list = source.toList(growable: false)
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return list;
  }

  Future<void> _showEmotes() async {
    final search = TextEditingController();
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
                length: _EmoteFilter.values.length,
                child: Column(
                  children: [
                    _EmoteSheetHeader(
                      title: _loadingEmotes ? '貼圖讀取中...' : '貼圖',
                      onRefresh: () => unawaited(_loadEmotes()),
                      onClose: () => Navigator.of(sheetContext).pop(),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                      child: TextField(
                        controller: search,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                        cursorColor: const Color(0xFFBF94FF),
                        decoration: InputDecoration(
                          isDense: true,
                          hintText: '搜尋貼圖',
                          hintStyle: const TextStyle(color: Colors.white38),
                          prefixIcon: const Icon(Icons.search, color: Colors.white54, size: 18),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.065),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        ),
                        onChanged: (v) => setSheetState(() => keyword = v.trim().toLowerCase()),
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
                        children: _EmoteFilter.values.map((filter) {
                          final items = _emotesFor(filter).where((e) => keyword.isEmpty || e.name.toLowerCase().contains(keyword)).toList(growable: false);
                          if (items.isEmpty) {
                            return Center(child: Text(_loadingEmotes ? '讀取中...' : '沒有貼圖', style: const TextStyle(color: Colors.white54)));
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
                            itemBuilder: (context, i) => _EmoteTile(emote: items[i], onTap: () => _insertEmote(items[i])),
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
    search.dispose();
  }

  void _setError(String msg) {
    if (!mounted) return;
    setState(() {
      _errorText = msg;
      _status = msg;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF0E0E10),
      child: Row(
        children: [
          _ResizeHandle(onDelta: widget.onWidthDelta, onEnd: widget.onWidthDragEnd),
          Expanded(
            child: Column(
              children: [
                _header(),
                if (_errorText != null) _StatusBanner(text: _errorText!, color: Colors.redAccent),
                Expanded(child: _messageList()),
                _inputBar(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _header() {
    return Container(
      height: 58,
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      decoration: const BoxDecoration(color: Color(0xFF18181B), border: Border(bottom: BorderSide(color: Color(0xFF2D2D35)))),
      child: Row(
        children: [
          const Icon(Icons.chat_bubble, color: Color(0xFFBF94FF), size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$_displayName 聊天室', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 14.5, fontWeight: FontWeight.w900)),
                const SizedBox(height: 2),
                Text('${_connected ? '已連線' : _status}｜${_messages.length} 則｜${_emoteExact.length} 貼圖｜raw $_rawCount', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          IconButton(tooltip: '貼圖', onPressed: _showEmotes, icon: const Icon(Icons.emoji_emotions_outlined, color: Colors.white70, size: 20)),
          IconButton(tooltip: '重新整理', onPressed: () => unawaited(_restart()), icon: _connecting ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFBF94FF))) : const Icon(Icons.refresh, color: Colors.white70, size: 20)),
        ],
      ),
    );
  }

  Widget _messageList() {
    if (_messages.isEmpty) {
      return Center(child: Text(_connecting ? '正在連線聊天室...' : '等待聊天室訊息...', style: const TextStyle(color: Colors.white54)));
    }
    return ListView.builder(
      reverse: true,
      padding: const EdgeInsets.fromLTRB(6, 8, 6, 8),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final msg = _messages[_messages.length - 1 - index];
        return _ChatTile(key: ValueKey<String>(msg.id), message: msg, resolveEmote: _lookupEmote);
      },
    );
  }

  Widget _inputBar() {
    final canSend = _connected && !_sending;
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
      decoration: const BoxDecoration(color: Color(0xFF18181B), border: Border(top: BorderSide(color: Color(0xFF2D2D35)))),
      child: Row(
        children: [
          IconButton(tooltip: '貼圖', onPressed: _showEmotes, icon: const Icon(Icons.emoji_emotions_outlined, color: Colors.white70, size: 21)),
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
                hintText: _authToken == null || _authToken!.isEmpty ? '登入後可發言' : '輸入聊天室訊息...',
                hintStyle: const TextStyle(color: Colors.white38),
                filled: true,
                fillColor: Colors.white.withOpacity(0.065),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(999), borderSide: BorderSide.none),
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
                  child: _sending ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Icon(Icons.send_rounded, color: canSend ? Colors.white : Colors.white38, size: 19),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatTile extends StatelessWidget {
  final _ChatMsg message;
  final _Emote? Function(String code) resolveEmote;

  const _ChatTile({super.key, required this.message, required this.resolveEmote});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: message.system ? const Color(0xFF241A35) : const Color(0xFF18181B),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withOpacity(message.system ? 0.10 : 0.055)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(9, 6, 9, 7),
          child: Text.rich(TextSpan(children: [
            TextSpan(text: message.displayName, style: TextStyle(color: message.color, fontSize: 13.2, fontWeight: FontWeight.w900, height: 1.28)),
            const TextSpan(text: ': ', style: TextStyle(color: Colors.white54, fontSize: 13.2, fontWeight: FontWeight.w700, height: 1.28)),
            ..._contentSpans(message, resolveEmote),
          ])),
        ),
      ),
    );
  }
}

List<InlineSpan> _contentSpans(_ChatMsg msg, _Emote? Function(String code) resolveEmote) {
  final text = msg.text;
  final ranges = _parseTwitchRanges(text, msg.emotesTag);
  final out = <InlineSpan>[];
  var cursor = 0;
  for (final r in ranges) {
    if (r.start > cursor) _appendTextSpans(out, text.substring(cursor, r.start), resolveEmote);
    out.add(_imageSpan(_twitchEmoteUrl(r.id), r.code));
    cursor = math.max(cursor, r.endExclusive);
  }
  if (cursor < text.length) _appendTextSpans(out, text.substring(cursor), resolveEmote);
  if (out.isEmpty) out.add(TextSpan(text: text, style: _msgStyle));
  return out;
}

void _appendTextSpans(List<InlineSpan> out, String text, _Emote? Function(String code) resolveEmote) {
  for (final m in RegExp(r'(\s+|\S+)').allMatches(text)) {
    final raw = m.group(0) ?? '';
    if (raw.isEmpty) continue;
    if (raw.trim().isEmpty) {
      out.add(TextSpan(text: raw, style: _msgStyle));
      continue;
    }
    final token = _stripToken(raw);
    final emote = token.core.isEmpty ? null : resolveEmote(token.core);
    if (emote == null) {
      out.add(TextSpan(text: raw, style: _msgStyle));
      continue;
    }
    if (token.leading.isNotEmpty) out.add(TextSpan(text: token.leading, style: _msgStyle));
    out.add(_imageSpan(emote.imageUrl, emote.name));
    if (token.trailing.isNotEmpty) out.add(TextSpan(text: token.trailing, style: _msgStyle));
  }
}

WidgetSpan _imageSpan(String url, String fallback) {
  return WidgetSpan(
    alignment: PlaceholderAlignment.middle,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 1.5),
      child: Image.network(
        url,
        height: 28,
        fit: BoxFit.contain,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) => Text(fallback, style: _msgStyle),
      ),
    ),
  );
}

const TextStyle _msgStyle = TextStyle(color: Colors.white, fontSize: 13.2, height: 1.28, fontWeight: FontWeight.w500);

List<_TwitchRange> _parseTwitchRanges(String text, String tag) {
  if (tag.trim().isEmpty) return const <_TwitchRange>[];
  final out = <_TwitchRange>[];
  for (final group in tag.split('/')) {
    final colon = group.indexOf(':');
    if (colon <= 0) continue;
    final id = group.substring(0, colon).trim();
    for (final range in group.substring(colon + 1).split(',')) {
      final dash = range.indexOf('-');
      if (dash <= 0) continue;
      final start = int.tryParse(range.substring(0, dash));
      final end = int.tryParse(range.substring(dash + 1));
      if (start == null || end == null || start < 0 || end < start || start >= text.length) continue;
      final endExclusive = math.min(end + 1, text.length);
      out.add(_TwitchRange(id: id, start: start, endExclusive: endExclusive, code: text.substring(start, endExclusive)));
    }
  }
  out.sort((a, b) => a.start.compareTo(b.start));
  return out;
}

_Token _stripToken(String token) {
  var start = 0;
  var end = token.length;
  while (start < end && _isLeading(token.codeUnitAt(start))) start += 1;
  while (end > start && _isTrailing(token.codeUnitAt(end - 1))) end -= 1;
  return _Token(leading: token.substring(0, start), core: token.substring(start, end), trailing: token.substring(end));
}

bool _isLeading(int c) => c == 0x28 || c == 0x5B || c == 0x7B || c == 0x3C || c == 0x22 || c == 0x27;
bool _isTrailing(int c) => _isLeading(c) || c == 0x29 || c == 0x5D || c == 0x7D || c == 0x3E || c == 0x2E || c == 0x2C || c == 0x21 || c == 0x3F || c == 0x3A || c == 0x3B;

String _twitchEmoteUrl(String id) => 'https://static-cdn.jtvnw.net/emoticons/v2/$id/default/dark/2.0';

Color? _parseColor(String? raw) {
  final text = raw?.trim();
  if (text == null || text.isEmpty) return null;
  final hex = text.startsWith('#') ? text.substring(1) : text;
  if (!RegExp(r'^[0-9a-fA-F]{6}$').hasMatch(hex)) return null;
  return Color(int.parse('FF$hex', radix: 16));
}

Color _colorFromText(String text) {
  var hash = 0;
  for (final unit in text.toLowerCase().codeUnits) hash = (hash * 31 + unit) & 0x7fffffff;
  const colors = <Color>[Color(0xFFBF94FF), Color(0xFF00A3FF), Color(0xFF00F5D4), Color(0xFFFF75E6), Color(0xFFFFB000), Color(0xFFFF5C7A), Color(0xFF7DD3FC)];
  return colors[hash % colors.length];
}

class _EmoteSheetHeader extends StatelessWidget {
  final String title;
  final VoidCallback onRefresh;
  final VoidCallback onClose;

  const _EmoteSheetHeader({required this.title, required this.onRefresh, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 8),
      decoration: const BoxDecoration(color: Color(0xFF18181B), border: Border(bottom: BorderSide(color: Color(0xFF2D2D35)))),
      child: Row(children: [
        const Icon(Icons.emoji_emotions, color: Color(0xFFBF94FF), size: 20),
        const SizedBox(width: 9),
        Expanded(child: Text(title, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900))),
        IconButton(tooltip: '重新整理', onPressed: onRefresh, icon: const Icon(Icons.refresh, color: Colors.white70, size: 20)),
        IconButton(tooltip: '關閉', onPressed: onClose, icon: const Icon(Icons.close, color: Colors.white70, size: 20)),
      ]),
    );
  }
}

class _EmoteTile extends StatelessWidget {
  final _Emote emote;
  final VoidCallback onTap;
  const _EmoteTile({required this.emote, required this.onTap});

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
          child: Column(children: [
            Expanded(child: Center(child: Image.network(emote.imageUrl, fit: BoxFit.contain, gaplessPlayback: true, errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, color: Colors.white38, size: 20)))),
            const SizedBox(height: 5),
            Text(emote.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70, fontSize: 10.5, fontWeight: FontWeight.w800)),
          ]),
        ),
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  final String text;
  final Color color;
  const _StatusBanner({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      color: color.withOpacity(0.14),
      child: Text(text, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: color, fontSize: 11.5, fontWeight: FontWeight.w800, height: 1.25)),
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
      onHorizontalDragUpdate: (d) => onDelta(d.delta.dx),
      onHorizontalDragEnd: (_) => onEnd(),
      child: MouseRegion(
        cursor: SystemMouseCursors.resizeLeftRight,
        child: SizedBox(width: 7, child: Center(child: Container(width: 2, height: 46, decoration: BoxDecoration(color: Colors.white.withOpacity(0.16), borderRadius: BorderRadius.circular(999))))),
      ),
    );
  }
}

class _ChatMsg {
  final String id;
  final String login;
  final String displayName;
  final Color color;
  final String text;
  final String emotesTag;
  final bool system;
  const _ChatMsg({required this.id, required this.login, required this.displayName, required this.color, required this.text, required this.emotesTag, required this.system});
}

class _Emote {
  final String id;
  final String name;
  final String imageUrl;
  final _EmoteKind kind;
  const _Emote({required this.id, required this.name, required this.imageUrl, required this.kind});
}

enum _EmoteKind {
  twitchChannel,
  twitchGlobal,
  sevenTv,
  bttv,
  ffz;

  bool get isTwitch => this == _EmoteKind.twitchChannel || this == _EmoteKind.twitchGlobal;
}

enum _EmoteFilter { recent, twitch, sevenTv, bttv, ffz, all }

class _TwitchRange {
  final String id;
  final int start;
  final int endExclusive;
  final String code;
  const _TwitchRange({required this.id, required this.start, required this.endExclusive, required this.code});
}

class _Token {
  final String leading;
  final String core;
  final String trailing;
  const _Token({required this.leading, required this.core, required this.trailing});
}

class _IrcLine {
  final Map<String, String> tags;
  final String prefix;
  final String command;
  final String trailing;

  const _IrcLine({required this.tags, required this.prefix, required this.command, required this.trailing});

  String get userLogin {
    final bang = prefix.indexOf('!');
    if (bang > 0) return prefix.substring(0, bang);
    return prefix;
  }

  static _IrcLine parse(String line) {
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
          final eq = pair.indexOf('=');
          if (eq < 0) tags[pair] = '';
          if (eq >= 0) tags[pair.substring(0, eq)] = _decodeTag(pair.substring(eq + 1));
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

    final trail = rest.indexOf(' :');
    if (trail >= 0) {
      trailing = rest.substring(trail + 2);
      rest = rest.substring(0, trail);
    }

    final parts = rest.split(' ').where((p) => p.isNotEmpty).toList(growable: false);
    return _IrcLine(tags: tags, prefix: prefix, command: parts.isEmpty ? '' : parts.first, trailing: _decodeTag(trailing));
  }
}

String _decodeTag(String value) {
  return value
      .replaceAll(r'\s', ' ')
      .replaceAll(r'\:', ';')
      .replaceAll(r'\\', r'\')
      .replaceAll(r'\r', '\r')
      .replaceAll(r'\n', '\n');
}
