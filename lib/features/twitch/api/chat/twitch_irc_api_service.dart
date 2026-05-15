import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../../models/chat/twitch_chat_message.dart';
import '../../parsers/chat/twitch_irc_message_parser.dart';
import '../core/twitch_api_constants.dart';

class TwitchIrcApiService {
  final TwitchIrcMessageParser messageParser;

  TwitchIrcApiService({
    this.messageParser = const TwitchIrcMessageParser(),
  });

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  String? _currentChannelLogin;
  String? _currentNick;
  final Map<String, String> _currentUserStateTags = <String, String>{};
  Completer<Map<String, String>>? _userStateCompleter;

  final StreamController<TwitchChatMessage> _messagesController =
      StreamController<TwitchChatMessage>.broadcast();
  final StreamController<String> _rawLinesController =
      StreamController<String>.broadcast();

  Stream<TwitchChatMessage> get messages => _messagesController.stream;
  Stream<String> get rawLines => _rawLinesController.stream;

  bool get isConnected => _channel != null;
  String? get currentChannelLogin => _currentChannelLogin;
  String? get currentNick => _currentNick;
  Map<String, String> get currentUserStateTags => Map<String, String>.unmodifiable(_currentUserStateTags);
  String get currentUserBadges => _currentUserStateTags['badges'] ?? '';
  String get currentUserColor => _currentUserStateTags['color'] ?? '';
  String get currentUserId => _currentUserStateTags['user-id'] ?? '';
  bool get hasCurrentUserState => _currentUserStateTags.isNotEmpty;

  Future<void> connect({
    required String channelLogin,
    String? accessToken,
    String nick = 'justinfan12345',
  }) async {
    await disconnect();

    final login = channelLogin.trim().toLowerCase();
    if (login.isEmpty) {
      throw ArgumentError.value(
        channelLogin,
        'channelLogin',
        'channel login cannot be empty',
      );
    }

    final ws = WebSocketChannel.connect(
      Uri.parse(TwitchApiConstants.ircWebSocketUrl),
    );

    _channel = ws;
    _currentChannelLogin = login;
    _currentNick = nick.trim().isEmpty ? 'justinfan12345' : nick.trim().toLowerCase();
    _currentUserStateTags.clear();
    _userStateCompleter = Completer<Map<String, String>>();

    _subscription = ws.stream.listen(
      handleSocketMessage,
      onError: (Object error, StackTrace stackTrace) {
        _rawLinesController.add('ERROR $error');
      },
      onDone: () {
        _rawLinesController.add('DISCONNECTED');
      },
      cancelOnError: false,
    );

    final safeToken = accessToken?.trim();

    _send('CAP REQ :twitch.tv/tags twitch.tv/commands twitch.tv/membership');

    if (safeToken != null && safeToken.isNotEmpty) {
      _send('PASS oauth:$safeToken');
      _send('NICK $_currentNick');
    } else {
      _send('PASS SCHMOOPIIE');
      _send('NICK justinfan${DateTime.now().millisecondsSinceEpoch.remainder(999999)}');
    }

    _send('JOIN #$login');
  }

  void handleSocketMessage(dynamic event) {
    final text = event is List<int> ? utf8.decode(event) : event.toString();
    final lines = text
        .split(RegExp(r'\r?\n'))
        .where((line) => line.trim().isNotEmpty);

    for (final line in lines) {
      _rawLinesController.add(line);

      if (line.startsWith('PING')) {
        final payload = line.contains(':')
            ? line.substring(line.indexOf(':'))
            : ':tmi.twitch.tv';
        _send('PONG $payload');
        continue;
      }

      final parsed = messageParser.parseLine(line);
      if (parsed.command == 'USERSTATE' || parsed.command == 'GLOBALUSERSTATE') {
        _currentUserStateTags.addAll(parsed.tags);

        final completer = _userStateCompleter;
        if (completer != null && !completer.isCompleted) {
          completer.complete(Map<String, String>.unmodifiable(_currentUserStateTags));
        }
      }

      if (parsed.command.isNotEmpty) {
        _messagesController.add(parsed);
      }
    }
  }

  Future<Map<String, String>> waitForCurrentUserState({
    Duration timeout = const Duration(milliseconds: 900),
  }) async {
    if (_currentUserStateTags.isNotEmpty) {
      return Map<String, String>.unmodifiable(_currentUserStateTags);
    }

    final completer = _userStateCompleter;
    if (completer == null) {
      return const <String, String>{};
    }

    try {
      return await completer.future.timeout(timeout);
    } on TimeoutException {
      return Map<String, String>.unmodifiable(_currentUserStateTags);
    }
  }

  Future<void> sendChatMessage({
    required String message,
    String? channelLogin,
  }) async {
    final ws = _channel;
    if (ws == null) {
      throw StateError('IRC 尚未連線，不能送出聊天室訊息。');
    }

    final channel = (channelLogin ?? _currentChannelLogin ?? '')
        .trim()
        .replaceFirst('#', '')
        .toLowerCase();

    if (channel.isEmpty) {
      throw StateError('缺少 channel login，不能送出聊天室訊息。');
    }

    final text = message
        .replaceAll(RegExp(r'[\r\n]+'), ' ')
        .trim();

    if (text.isEmpty) {
      throw ArgumentError.value(message, 'message', 'message cannot be empty');
    }

    _send('PRIVMSG #$channel :$text');
  }

  void _send(String line) {
    _channel?.sink.add('$line\r\n');
  }

  Future<List<TwitchChatMessage>> collectMessages({
    required String channelLogin,
    String? accessToken,
    Duration duration = const Duration(seconds: 8),
    int maxMessages = 20,
  }) async {
    final collected = <TwitchChatMessage>[];
    final completer = Completer<List<TwitchChatMessage>>();

    late final StreamSubscription<TwitchChatMessage> sub;
    Timer? timer;

    sub = messages.listen((message) {
      if (message.isPrivMsg) {
        collected.add(message);
      }

      if (collected.length >= maxMessages && !completer.isCompleted) {
        completer.complete(List<TwitchChatMessage>.unmodifiable(collected));
      }
    });

    timer = Timer(duration, () {
      if (!completer.isCompleted) {
        completer.complete(List<TwitchChatMessage>.unmodifiable(collected));
      }
    });

    try {
      await connect(
        channelLogin: channelLogin,
        accessToken: accessToken,
        nick: accessToken == null || accessToken.trim().isEmpty
            ? 'justinfan12345'
            : 'new_twitch_app',
      );

      return await completer.future;
    } finally {
      timer.cancel();
      await sub.cancel();
      await disconnect();
    }
  }

  Future<void> disconnect() async {
    await _subscription?.cancel();
    _subscription = null;

    final channel = _channel;
    _channel = null;
    _currentChannelLogin = null;
    _currentNick = null;
    _currentUserStateTags.clear();
    final completer = _userStateCompleter;
    if (completer != null && !completer.isCompleted) {
      completer.complete(const <String, String>{});
    }
    _userStateCompleter = null;

    await channel?.sink.close();
  }

  Future<void> dispose() async {
    await disconnect();
    await _messagesController.close();
    await _rawLinesController.close();
  }
}
