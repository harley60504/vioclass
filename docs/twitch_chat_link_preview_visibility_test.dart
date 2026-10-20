// ignore_for_file: avoid_relative_lib_imports
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../lib/features/twitch/presentation/widgets/chat/links/twitch_chat_link_preview.dart';

void main() {
  setUp(
    () => configureTwitchChatLinkPreviews(enabled: true, trustedDomains: []),
  );
  tearDown(
    () => configureTwitchChatLinkPreviews(enabled: true, trustedDomains: []),
  );

  test('Only allowlisted links consume preview slots', () {
    final items = extractTwitchChatPreviewUrls(
      'https://unknown.example/1 https://other.example/2 '
      'https://github.com/example/project https://www.youtube.com/watch?v=test',
    );
    expect(items.map((item) => Uri.parse(item.url).host), [
      'github.com',
      'www.youtube.com',
    ]);
    expect(items.every((item) => item.trusted), isTrue);
    expect(extractTwitchChatPreviewUrls('https://unknown.example'), isEmpty);
    expect(
      extractTwitchChatPreviewUrls('https://github.com.attacker.example'),
      isEmpty,
    );
    expect(extractTwitchChatPreviewUrls('http://127.0.0.1'), isEmpty);
  });

  test('Custom allowlist and disabled previews retain their policy', () {
    configureTwitchChatLinkPreviews(
      enabled: true,
      trustedDomains: ['custom.example'],
    );
    expect(
      extractTwitchChatPreviewUrls('https://custom.example/a'),
      hasLength(1),
    );
    configureTwitchChatLinkPreviews(
      enabled: false,
      trustedDomains: ['custom.example'],
    );
    expect(
      extractTwitchChatPreviewUrls(
        'https://custom.example/a https://github.com',
      ),
      isEmpty,
    );
  });

  testWidgets('Untrusted cards and columns occupy no height', (tester) async {
    const item = TwitchChatPreviewUrl(
      url: 'https://unknown.example',
      trusted: false,
    );
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              TwitchChatLinkPreviewColumn(
                key: ValueKey('column'),
                items: [item],
              ),
              TwitchChatLinkPreviewCard(key: ValueKey('card'), item: item),
              Text('message remains'),
            ],
          ),
        ),
      ),
    );
    expect(tester.getSize(find.byKey(const ValueKey('column'))).height, 0);
    expect(tester.getSize(find.byKey(const ValueKey('card'))).height, 0);
    expect(find.byType(InkWell), findsNothing);
    expect(find.text('不自動載入的連結'), findsNothing);
    expect(find.text('message remains'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Unknown URL remains linkified with tap and copy actions', (
    tester,
  ) async {
    late List<InlineSpan> spans;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              spans = buildTwitchChatLinkifiedSpans(
                context: context,
                text: 'hello https://unknown.example/a',
                textStyle: const TextStyle(),
                linkStyle: const TextStyle(),
              );
              return Text.rich(TextSpan(children: spans));
            },
          ),
        ),
      ),
    );
    expect(find.text('https://unknown.example/a'), findsOneWidget);
    final link = tester.widget<InkWell>(find.byType(InkWell));
    expect(link.onTap, isNotNull);
    expect(link.onLongPress, isNotNull);
    expect(
      extractTwitchChatPreviewUrls('hello https://unknown.example/a'),
      isEmpty,
    );
    expect(tester.takeException(), isNull);
  });
}
