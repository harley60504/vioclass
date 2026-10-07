// ignore_for_file: avoid_relative_lib_imports
import 'dart:async';
import 'dart:ui' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import '../lib/features/twitch/api/core/twitch_api_client.dart';
import '../lib/features/twitch/api/moderation/twitch_moderation_api_service.dart';
import '../lib/features/twitch/models/chat/twitch_chat_message.dart';
import '../lib/features/twitch/models/chat/twitch_chat_message_metadata.dart';
import '../lib/features/twitch/models/chat/twitch_chat_runtime_message.dart';
import '../lib/features/twitch/presentation/sheets/twitch_moderation_batch_sheet.dart';

TwitchChatRuntimeMessage _message(String id, {String room = '20'}) {
  final raw = TwitchChatMessage(
    raw: '',
    command: 'PRIVMSG',
    channel: 'fixture',
    userLogin: 'fixture',
    displayName: 'Fixture $id',
    message: 'Message $id',
    tags: {'id': id, 'room-id': room, 'user-id': '30'},
  );
  return TwitchChatRuntimeMessage(
    source: raw,
    resolvedBadges: const [],
    receivedAt: DateTime.utc(2026),
    fragments: const [],
    segments: const [],
    metadata: TwitchChatMessageMetadata.fromMessage(raw),
  );
}

class _Api extends TwitchModerationApiService {
  final sent = <String>[];
  Future<void> Function()? response;
  _Api()
    : super(
        client: TwitchApiClient(),
        tokenProviders: const [],
        broadcasterId: '20',
        moderatorId: '10',
      );
  @override
  Future<void> deleteMessages({String? messageId}) async {
    sent.add(messageId!);
    await response?.call();
  }
}

Future<void> _open(
  WidgetTester tester,
  _Api api,
  bool Function() permitted, {
  List<TwitchChatRuntimeMessage>? messages,
  String? initialMessageId,
  double scale = 1,
  bool Function(String)? canManageTarget,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showTwitchModerationBatchSheet(
              context: context,
              api: api,
              initialMessageId: initialMessageId,
              canManageTarget: canManageTarget,
              messages:
                  messages ??
                  [
                    _message('a'),
                    _message('b'),
                    _message('shared', room: '99'),
                  ],
              channelName: 'fixture',
              canModerate: permitted,
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

Future<void> _visible(WidgetTester tester, Finder finder, double delta) async {
  await tester.scrollUntilVisible(
    finder,
    delta,
    scrollable: find
        .descendant(
          of: find.byType(CustomScrollView),
          matching: find.byType(Scrollable),
        )
        .first,
  );
  await tester.pump();
}

Future<void> _preview(WidgetTester tester) async {
  for (var index = 0; index < 2; index++) {
    final check = find.byKey(ValueKey('batch-select-$index'));
    await _visible(tester, check, 150);
    await tester.tap(check);
    await tester.pump();
  }
  await _visible(tester, find.text('預覽刪除'), -150);
  await tester.tap(find.text('預覽刪除'));
  await tester.pumpAndSettle();
  await _visible(tester, find.text('繼續確認'), -100);
  await tester.tap(find.text('繼續確認'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'User range over fifty sources preserves selection without truncation',
    (tester) async {
      final api = _Api();
      addTearDown(() => api.client.close());
      final messages = List.generate(51, (index) {
        final message = _message('$index');
        message.source.tags.remove('id');
        message.source.tags['user-id'] = '${100 + index}';
        return message;
      });
      await _open(
        tester,
        api,
        () => true,
        messages: messages,
        canManageTarget: (_) => true,
      );
      await tester.tap(find.text('選取模式：訊息'));
      await tester.pumpAndSettle();
      await _visible(tester, find.text('範圍選取：關'), 100);
      await tester.tap(find.text('範圍選取：關'));
      await tester.pump();
      for (final index in [0, 50]) {
        final row = find.byKey(ValueKey('batch-select-$index'));
        await _visible(tester, row, 150);
        await tester.tap(row);
        await tester.pump();
      }
      expect(
        tester
            .widget<CheckboxListTile>(
              find.byKey(const ValueKey('batch-select-50')),
            )
            .value,
        isFalse,
      );
      await _visible(tester, find.text('範圍超過 50 則，未變更原選取；請縮小範圍。'), -150);
      expect(find.text('已選取 1 / 50'), findsOneWidget);
      expect(api.sent, isEmpty);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  for (final size in [const Size(320, 640), const Size(844, 290)]) {
    testWidgets('User mode touch drag opens form with enlarged text at $size', (
      tester,
    ) async {
      final api = _Api();
      addTearDown(() => api.client.close());
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final messages = List.generate(12, (index) {
        final message = _message('$index');
        message.source.tags.remove('id');
        message.source.tags['user-id'] = '${100 + index}';
        return message;
      });
      await _open(
        tester,
        api,
        () => true,
        scale: 1.3,
        messages: messages,
        canManageTarget: (_) => true,
      );
      await _visible(tester, find.text('選取模式：訊息'), 100);
      await tester.tap(find.text('選取模式：訊息'));
      await tester.pumpAndSettle();
      await _visible(tester, find.text('拖曳選取：關'), 100);
      await tester.tap(find.text('拖曳選取：關'));
      await tester.pump();
      final viewport = find.byType(CustomScrollView);
      final scrollStart = tester.getTopLeft(viewport) + const Offset(40, 30);
      final navigation = await tester.startGesture(scrollStart);
      await navigation.moveTo(scrollStart - const Offset(0, 40));
      await navigation.moveTo(scrollStart - const Offset(0, 400));
      await tester.pump();
      await navigation.up();
      await tester.pump();
      final row = find.byType(CheckboxListTile).hitTestable().first;
      expect(row, findsOneWidget);
      final gesture = await tester.startGesture(tester.getCenter(row));
      await gesture.moveTo(
        tester.getBottomRight(viewport) - const Offset(40, 8),
      );
      for (var frame = 0; frame < 8; frame++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      await gesture.up();
      await tester.pump();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
      expect(find.text('批次禁言／警告'), findsWidgets);
      expect(find.byType(TextField), findsOneWidget);
      expect(tester.widget<CustomScrollView>(viewport).physics, isNull);
      expect(api.sent, isEmpty);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets(
    'User range skips shared source and shortcut opens only user form',
    (tester) async {
      final api = _Api();
      addTearDown(() => api.client.close());
      final messages = [
        _message('a'),
        _message('shared', room: '99'),
        _message('b'),
      ];
      for (final message in messages) {
        message.source.tags.remove('id');
      }
      await _open(
        tester,
        api,
        () => true,
        messages: messages,
        canManageTarget: (_) => true,
      );
      await tester.tap(find.text('選取模式：訊息'));
      await tester.pumpAndSettle();
      await _visible(tester, find.text('範圍選取：關'), 100);
      await tester.tap(find.text('範圍選取：關'));
      await tester.pump();
      for (final index in [0, 2]) {
        final row = find.byKey(ValueKey('batch-select-$index'));
        await _visible(tester, row, 150);
        await tester.tap(row);
        await tester.pump();
      }
      await _visible(
        tester,
        find.byKey(const ValueKey('batch-select-1')),
        -100,
      );
      expect(
        tester
            .widget<CheckboxListTile>(
              find.byKey(const ValueKey('batch-select-1')),
            )
            .value,
        isFalse,
      );
      await _visible(tester, find.text('已選取 2 / 50'), -150);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
      expect(find.text('原因（警告必填）'), findsOneWidget);
      expect(find.text('確認批次刪除'), findsNothing);
      expect(api.sent, isEmpty);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'User mode selects missing message ID, clears selection on switch and cannot delete it',
    (tester) async {
      final api = _Api();
      addTearDown(() => api.client.close());
      final missing = _message('missing');
      missing.source.tags.remove('id');
      await _open(
        tester,
        api,
        () => true,
        messages: [missing, _message('official')],
        canManageTarget: (_) => true,
      );
      final row = find.byKey(const ValueKey('batch-select-0'));
      await _visible(tester, row, 150);
      expect(tester.widget<CheckboxListTile>(row).onChanged, isNull);
      await _visible(tester, find.text('選取模式：訊息'), -150);
      await tester.tap(find.text('選取模式：訊息'));
      await tester.pumpAndSettle();
      await _visible(tester, row, 150);
      expect(tester.widget<CheckboxListTile>(row).onChanged, isNotNull);
      await tester.tap(row);
      await tester.pump();
      await _visible(tester, find.text('預覽使用者操作'), -150);
      await tester.tap(find.text('預覽使用者操作'));
      await tester.pumpAndSettle();
      expect(find.text('原因（警告必填）'), findsOneWidget);
      expect(api.sent, isEmpty);
      await tester.tap(find.byIcon(Icons.close_rounded).last);
      await tester.pumpAndSettle();
      await _visible(tester, find.text('選取模式：使用者'), -150);
      await tester.tap(find.text('選取模式：使用者'));
      await tester.pumpAndSettle();
      expect(find.text('已選取 0 / 50'), findsOneWidget);
      await _visible(tester, find.text('預覽刪除'), 150);
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, '預覽刪除'))
            .onPressed,
        isNull,
      );
      await _visible(tester, row, 150);
      expect(tester.widget<CheckboxListTile>(row).onChanged, isNull);
      expect(api.sent, isEmpty);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'User mode excludes contradictory role, self, broadcaster and shared source',
    (tester) async {
      final api = _Api();
      addTearDown(() => api.client.close());
      final mod = _message('mod');
      mod.source.tags['badges'] = 'moderator/1';
      final self = _message('self');
      self.source.tags['user-id'] = '10';
      final owner = _message('owner');
      owner.source.tags['user-id'] = '20';
      final valid = _message('valid');
      valid.source.tags['user-id'] = '40';
      await _open(
        tester,
        api,
        () => true,
        messages: [
          _message('old'),
          mod,
          self,
          owner,
          _message('shared', room: '99'),
          valid,
        ],
        canManageTarget: (_) => true,
      );
      await tester.tap(find.text('選取模式：訊息'));
      await tester.pumpAndSettle();
      for (var index = 0; index < 6; index++) {
        final row = find.byKey(ValueKey('batch-select-$index'));
        await _visible(tester, row, 150);
        expect(
          tester.widget<CheckboxListTile>(row).onChanged,
          index == 5 ? isNotNull : isNull,
        );
      }
      expect(api.sent, isEmpty);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'Selected message opens user-action form only with a target gate',
    (tester) async {
      final api = _Api();
      addTearDown(() => api.client.close());
      await _open(
        tester,
        api,
        () => true,
        initialMessageId: 'a',
        canManageTarget: (_) => true,
      );
      await _visible(tester, find.text('批次禁言／警告'), 100);
      await tester.tap(find.text('批次禁言／警告'));
      await tester.pumpAndSettle();
      expect(find.text('原因（警告必填）'), findsOneWidget);
      expect(find.text('預覽使用者'), findsOneWidget);
      expect(api.sent, isEmpty);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'Revoking permission during edge drag stops scrolling and cannot preview',
    (tester) async {
      final api = _Api();
      addTearDown(() => api.client.close());
      var permission = true;
      tester.view.physicalSize = const Size(900, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await _open(
        tester,
        api,
        () => permission,
        messages: List.generate(25, (index) => _message('$index')),
      );
      await tester.tap(find.text('拖曳選取：關'));
      await tester.pump();
      final state = tester.state<ScrollableState>(
        find
            .descendant(
              of: find.byType(CustomScrollView),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(const ValueKey('batch-select-0'))),
      );
      await gesture.moveTo(
        tester.getBottomRight(find.byType(CustomScrollView)) -
            const Offset(40, 8),
      );
      await tester.pump(const Duration(milliseconds: 50));
      permission = false;
      final beforeRevocation = state.position.pixels;
      await tester.pump(const Duration(milliseconds: 200));
      expect(state.position.pixels, beforeRevocation);
      await gesture.up();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
      expect(find.text('繼續確認'), findsNothing);
      expect(api.sent, isEmpty);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  for (final size in [const Size(320, 640), const Size(844, 290)]) {
    testWidgets(
      'Touch drag mode remains navigable with enlarged text at $size',
      (tester) async {
        final api = _Api();
        addTearDown(() => api.client.close());
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await _open(
          tester,
          api,
          () => true,
          scale: 1.3,
          messages: List.generate(12, (index) => _message('$index')),
        );
        await _visible(tester, find.text('拖曳選取：關'), 100);
        await tester.tap(find.text('拖曳選取：關'));
        await tester.pump();
        final viewport = find.byType(CustomScrollView);
        final scrollStart = tester.getTopLeft(viewport) + const Offset(40, 30);
        final navigation = await tester.startGesture(scrollStart);
        await navigation.moveTo(scrollStart - const Offset(0, 40));
        await navigation.moveTo(scrollStart - const Offset(0, 300));
        await tester.pump();
        await navigation.up();
        await tester.pump();
        final row = find.byType(CheckboxListTile).hitTestable().first;
        expect(row, findsOneWidget);
        final gesture = await tester.startGesture(tester.getCenter(row));
        await gesture.moveTo(
          tester.getBottomRight(viewport) - const Offset(40, 8),
        );
        for (var frame = 0; frame < 8; frame++) {
          await tester.pump(const Duration(milliseconds: 50));
        }
        await gesture.up();
        await tester.pump();
        await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
        await tester.pumpAndSettle();
        expect(find.byType(CheckboxListTile), findsNothing);
        expect(
          tester
              .widget<CustomScrollView>(find.byType(CustomScrollView))
              .physics,
          isNull,
        );
        expect(api.sent, isEmpty);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
  testWidgets(
    'Mouse drag edge autoscroll survives lazy row disposal and closes cleanly',
    (tester) async {
      final api = _Api();
      addTearDown(() => api.client.close());
      tester.view.physicalSize = const Size(900, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await _open(
        tester,
        api,
        () => true,
        messages: List.generate(25, (index) => _message('$index')),
      );
      await tester.tap(find.text('拖曳選取：關'));
      await tester.pump();
      final scroll = find
          .descendant(
            of: find.byType(CustomScrollView),
            matching: find.byType(Scrollable),
          )
          .first;
      final state = tester.state<ScrollableState>(scroll);
      final original = state.position.pixels;
      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(const ValueKey('batch-select-0'))),
        kind: PointerDeviceKind.mouse,
      );
      await gesture.moveTo(
        tester.getBottomRight(find.byType(CustomScrollView)) -
            const Offset(40, 8),
      );
      for (var frame = 0; frame < 30; frame++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(state.position.pixels, greaterThan(original + 200));
      expect(
        tester
            .widgetList<CheckboxListTile>(find.byType(CheckboxListTile))
            .where((tile) => tile.value == true),
        isNotEmpty,
      );
      expect(api.sent, isEmpty);
      await tester.pumpWidget(const SizedBox());
      await gesture.cancel();
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Reverse range can remove previously selected items without submission',
    (tester) async {
      final api = _Api();
      addTearDown(() => api.client.close());
      await _open(
        tester,
        api,
        () => true,
        messages: [_message('a'), _message('b'), _message('c')],
      );
      await tester.tap(find.text('範圍選取：關'));
      await tester.pump();
      final first = find.byKey(const ValueKey('batch-select-0'));
      final last = find.byKey(const ValueKey('batch-select-2'));
      await _visible(tester, last, 150);
      await tester.tap(last);
      await tester.pump();
      await _visible(tester, first, -100);
      await tester.tap(first);
      await tester.pump();
      expect(
        tester
            .widget<CheckboxListTile>(
              find.byKey(const ValueKey('batch-select-1')),
            )
            .value,
        isTrue,
      );
      await _visible(tester, last, 100);
      await tester.tap(last);
      await tester.pump();
      await _visible(tester, find.text('已選取 0 / 50'), -100);
      expect(find.text('已選取 0 / 50'), findsOneWidget);
      expect(api.sent, isEmpty);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'Explicit drag selection and backtracking use the original baseline',
    (tester) async {
      final api = _Api();
      addTearDown(() => api.client.close());
      tester.view.physicalSize = const Size(900, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await _open(
        tester,
        api,
        () => true,
        messages: [_message('a'), _message('b'), _message('c')],
      );
      await tester.tap(find.text('拖曳選取：關'));
      await tester.pump();
      final first = find.byKey(const ValueKey('batch-select-0'));
      final second = find.byKey(const ValueKey('batch-select-1'));
      final last = find.byKey(const ValueKey('batch-select-2'));
      final gesture = await tester.startGesture(tester.getCenter(first));
      await gesture.moveTo(tester.getCenter(last));
      await tester.pump();
      expect(tester.widget<CheckboxListTile>(last).value, isTrue);
      await gesture.moveTo(tester.getCenter(second));
      await tester.pump();
      expect(tester.widget<CheckboxListTile>(second).value, isTrue);
      expect(tester.widget<CheckboxListTile>(last).value, isFalse);
      await gesture.up();
      await tester.pumpAndSettle();
      expect(api.sent, isEmpty);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  for (final mobile in [false, true]) {
    testWidgets(
      'Range selection skips invalid entries and shortcut only previews: mobile=$mobile',
      (tester) async {
        final api = _Api();
        addTearDown(() => api.client.close());
        await _open(
          tester,
          api,
          () => true,
          messages: [
            _message('a'),
            _message('shared', room: '99'),
            _message('b'),
            _message('c'),
          ],
        );
        if (mobile) {
          await tester.tap(find.text('範圍選取：關'));
          await tester.pump();
        }
        final first = find.byKey(const ValueKey('batch-select-0'));
        final last = find.byKey(const ValueKey('batch-select-3'));
        await _visible(tester, first, 150);
        await tester.tap(first);
        await tester.pump();
        await _visible(tester, last, 150);
        if (!mobile) {
          await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
        }
        await tester.tap(last);
        await tester.pump();
        if (!mobile) await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
        await _visible(
          tester,
          find.byKey(const ValueKey('batch-select-2')),
          -100,
        );
        expect(
          tester
              .widget<CheckboxListTile>(
                find.byKey(const ValueKey('batch-select-2')),
              )
              .value,
          isTrue,
        );
        await _visible(
          tester,
          find.byKey(const ValueKey('batch-select-1')),
          -100,
        );
        expect(
          tester
              .widget<CheckboxListTile>(
                find.byKey(const ValueKey('batch-select-1')),
              )
              .value,
          isFalse,
        );
        await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
        await tester.pumpAndSettle();
        expect(find.text('預覽刪除'), findsNothing);
        await _visible(tester, find.text('繼續確認'), -100);
        expect(find.text('預覽 3 · 排除或重複 0'), findsOneWidget);
        await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
        await tester.pumpAndSettle();
        expect(find.text('確認批次刪除'), findsNothing);
        expect(api.sent, isEmpty);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
  testWidgets(
    'Range above limit is rejected atomically, not silently truncated',
    (tester) async {
      final api = _Api();
      addTearDown(() => api.client.close());
      await _open(
        tester,
        api,
        () => true,
        messages: List.generate(51, (index) => _message('$index')),
      );
      await tester.tap(find.text('範圍選取：關'));
      await tester.pump();
      await _visible(tester, find.byKey(const ValueKey('batch-select-0')), 150);
      await tester.tap(find.byKey(const ValueKey('batch-select-0')));
      await tester.pump();
      await _visible(
        tester,
        find.byKey(const ValueKey('batch-select-50')),
        150,
      );
      await tester.tap(find.byKey(const ValueKey('batch-select-50')));
      await tester.pump();
      expect(
        tester
            .widget<CheckboxListTile>(
              find.byKey(const ValueKey('batch-select-50')),
            )
            .value,
        isFalse,
      );
      await _visible(tester, find.text('範圍超過 50 則，未變更原選取；請縮小範圍。'), -150);
      expect(find.text('已選取 1 / 50'), findsOneWidget);
      expect(api.sent, isEmpty);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'Fifty selections disable only additional targets and can be reduced',
    (tester) async {
      final api = _Api();
      addTearDown(() => api.client.close());
      await _open(
        tester,
        api,
        () => true,
        messages: List.generate(51, (index) => _message('$index')),
      );
      for (var index = 0; index < 50; index++) {
        final finder = find.byKey(ValueKey('batch-select-$index'));
        await _visible(tester, finder, 150);
        await tester.tap(finder);
        await tester.pump();
      }
      final extra = find.byKey(const ValueKey('batch-select-50'));
      await _visible(tester, extra, 150);
      expect(tester.widget<CheckboxListTile>(extra).onChanged, isNull);
      final previous = find.byKey(const ValueKey('batch-select-49'));
      await _visible(tester, previous, -100);
      expect(tester.widget<CheckboxListTile>(previous).onChanged, isNotNull);
      await tester.tap(previous);
      await tester.pump();
      await _visible(tester, extra, 100);
      expect(tester.widget<CheckboxListTile>(extra).onChanged, isNotNull);
      expect(api.sent, isEmpty);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'Initial target is only selected, source mutation cannot redirect deletion',
    (tester) async {
      final api = _Api();
      addTearDown(() => api.client.close());
      final message = _message('a');
      final messages = [message, _message('b')];
      await _open(
        tester,
        api,
        () => true,
        messages: messages,
        initialMessageId: 'a',
      );
      expect(
        tester
            .widget<CheckboxListTile>(
              find.byKey(const ValueKey('batch-select-0')),
            )
            .value,
        isTrue,
      );
      expect(api.sent, isEmpty);
      message.source.tags['id'] = 'changed';
      message.source.tags['room-id'] = '99';
      messages.add(_message('new'));
      await _visible(tester, find.text('預覽刪除'), -100);
      await tester.tap(find.text('預覽刪除'));
      await tester.pumpAndSettle();
      await _visible(tester, find.textContaining('ID: a'), 100);
      expect(find.textContaining('ID: changed'), findsNothing);
      await _visible(tester, find.text('繼續確認'), -100);
      await tester.tap(find.text('繼續確認'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('確認刪除'));
      await tester.pumpAndSettle();
      expect(api.sent, ['a']);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  late _Api api;
  var permitted = true;
  setUp(() {
    api = _Api();
    permitted = true;
  });
  tearDown(() => api.client.close());
  for (final size in [
    const Size(900, 700),
    const Size(320, 640),
    const Size(844, 290),
  ]) {
    testWidgets('Batch selection preview and confirmation at $size', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await _open(tester, api, () => permitted);
      await _visible(tester, find.byKey(const ValueKey('batch-select-2')), 150);
      expect(
        tester
            .widget<CheckboxListTile>(
              find.byKey(const ValueKey('batch-select-2')),
            )
            .onChanged,
        isNull,
      );
      await _visible(
        tester,
        find.byKey(const ValueKey('batch-select-0')),
        -150,
      );
      await _preview(tester);
      expect(api.sent, isEmpty);
      expect(find.text('確認批次刪除'), findsOneWidget);
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(api.sent, isEmpty);
      await tester.tap(find.text('繼續確認'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('確認刪除'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(api.sent, ['a', 'b']);
      expect(find.text('繼續確認'), findsNothing);
      expect(find.text('批次處理結束'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
  testWidgets('Permission change while confirming sends nothing', (
    tester,
  ) async {
    await _open(tester, api, () => permitted);
    await _preview(tester);
    permitted = false;
    await tester.tap(find.text('確認刪除'));
    await tester.pumpAndSettle();
    expect(api.sent, isEmpty);
    expect(find.text('管理身分或頻道已變更，未送出操作。'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'Unknown response displays uncertainty and never exposes resubmit',
    (tester) async {
      api.response = () async => throw StateError('fixture transport');
      await _open(tester, api, () => permitted);
      await _preview(tester);
      await tester.tap(find.text('確認刪除'));
      await tester.pumpAndSettle();
      expect(api.sent, ['a']);
      expect(find.text('批次已停止'), findsOneWidget);
      expect(find.text('繼續確認'), findsNothing);
      await _visible(tester, find.textContaining('ID: a'), 100);
      expect(find.textContaining('結果不明；請先核對，勿直接重送'), findsOneWidget);
      await _visible(tester, find.textContaining('ID: b'), 100);
      expect(find.text('Message b\nID: b\n未送出'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  for (final close in [false, true]) {
    testWidgets(
      'Stop or close during submission only stops later targets: close=$close',
      (tester) async {
        final gate = Completer<void>();
        api.response = () => gate.future;
        await _open(tester, api, () => permitted);
        await _preview(tester);
        await tester.tap(find.text('確認刪除'));
        await tester.pumpAndSettle();
        expect(api.sent, ['a']);
        await tester.tap(
          close ? find.byIcon(Icons.close_rounded) : find.text('停止後續操作'),
        );
        await tester.pumpAndSettle();
        gate.complete();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pumpAndSettle();
        expect(api.sent, ['a']);
        expect(
          close ? find.text('open') : find.text('已停止後續操作'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}
