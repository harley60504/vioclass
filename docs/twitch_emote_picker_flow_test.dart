// ignore_for_file: avoid_relative_lib_imports
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../lib/features/twitch/presentation/widgets/shared/twitch_emote_picker_flow.dart';
import '../lib/features/twitch/presentation/widgets/shared/twitch_native_animated_emote_image.dart';
import '../lib/features/twitch/presentation/widgets/shared/twitch_emote_picker_panel.dart';
import '../lib/features/twitch/presentation/sheets/twitch_emote_picker_sheet.dart';
import '../lib/features/twitch/api/core/twitch_api_client.dart';
import '../lib/features/twitch/api/emotes/twitch_official_emote_api_service.dart';
import '../lib/features/twitch/api/emotes/twitch_third_party_emote_api_service.dart';
import '../lib/features/twitch/models/emotes/twitch_official_emote.dart';
import '../lib/features/twitch/services/chat/twitch_official_emote_cache_service.dart';
import '../lib/features/twitch/services/chat/twitch_third_party_emote_cache_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _SubscribedCache extends TwitchOfficialEmoteCacheService {
  _SubscribedCache(TwitchApiClient client)
    : super(
        api: TwitchOfficialEmoteApiService(client: client),
        accessTokenProvider: () async => null,
        clientIdProvider: () async => null,
      );
  @override
  List<TwitchOfficialEmote> get userEmotes => [
    for (final owner in ['Alpha', 'Beta'])
      TwitchOfficialEmote(
        id: owner,
        name: '${owner}Smile',
        imageUrl: '',
        emoteType: 'subscriptions',
        tier: '1000',
        emoteSetId: owner,
        ownerId: owner,
        ownerDisplayName: owner,
        source: TwitchOfficialEmoteSource.user,
        unlocked: true,
      ),
  ];
}

void main() {
  testWidgets('Embedded chat retains each subscription category and emoji', (
    tester,
  ) async {
    // ignore: invalid_use_of_visible_for_testing_member
    SharedPreferences.setMockInitialValues({});
    final client = TwitchApiClient();
    final official = _SubscribedCache(client);
    final thirdParty = TwitchThirdPartyEmoteCacheService(
      api: TwitchThirdPartyEmoteApiService(client: client),
    );
    addTearDown(() {
      official.dispose();
      thirdParty.dispose();
      client.close();
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 220,
            child: TwitchUnifiedEmotePickerSheet(
              cache: thirdParty,
              officialCache: official,
              loading: false,
              onRefresh: () async {},
              onEmoteSelected: (_) {},
              embedded: true,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final panel = tester.widget<TwitchEmotePickerPanel>(
      find.byType(TwitchEmotePickerPanel),
    );
    for (final label in ['Alpha', 'Beta']) {
      expect(
        panel.categories
            .singleWhere((category) => category.label == label)
            .count,
        1,
      );
    }
    expect(panel.categories.any((category) => category.label == '頻道'), true);
    expect(panel.categories.any((category) => category.label == '全域'), true);
    expect(panel.categories.any((category) => category.id == 'emoji'), true);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  for (final height in [80.0, 220.0]) {
    testWidgets('Shared panel owns search/category/close at height $height', (
      tester,
    ) async {
      var closed = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 300,
              height: height,
              child: TwitchEmotePickerPanel(
                categories: const [
                  TwitchEmotePickerCategory(
                    id: 'official',
                    label: 'Twitch',
                    count: 1,
                  ),
                  TwitchEmotePickerCategory(
                    id: 'thirdParty',
                    label: '7TV',
                    count: 2,
                  ),
                ],
                onClose: () => closed = true,
                categoryBuilder: (_, id, query) =>
                    Text('$id:$query', key: const ValueKey('fixture-category')),
              ),
            ),
          ),
        ),
      );
      await tester.enterText(
        find.byKey(const ValueKey('emote-panel-search')),
        ' KAP ',
      );
      await tester.pump();
      expect(find.text('official:kap'), findsOneWidget);
      final sidebar = find.byKey(const ValueKey('emote-category-sidebar'));
      expect(sidebar, findsOneWidget);
      final categories = tester.widget<ListView>(
        find.descendant(of: sidebar, matching: find.byType(ListView)),
      );
      expect(categories.scrollDirection, Axis.vertical);
      final category = find.byKey(const ValueKey('emote-category-thirdParty'));
      await tester.scrollUntilVisible(
        category,
        40,
        scrollable: find.descendant(
          of: sidebar,
          matching: find.byType(Scrollable),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(category);
      await tester.pumpAndSettle();
      expect(find.text('thirdParty:kap'), findsOneWidget);
      expect(find.text('official:kap'), findsNothing);
      await tester.tap(find.byTooltip('關閉貼圖'));
      expect(closed, isTrue);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
  testWidgets(
    'Compact shared flow uses wrap, no grid, and retains locked/favorite actions',
    (tester) async {
      var taps = 0;
      var favorites = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 300,
              height: 200,
              child: TwitchEmotePickerFlow(
                itemCount: 12,
                itemBuilder: (context, index) => TwitchEmotePickerTile(
                  id: '$index',
                  name: 'emote$index',
                  imageUrl: '',
                  image: const Icon(Icons.face),
                  locked: index == 1,
                  favorite: index == 2,
                  onTap: () => taps++,
                  onLongPress: () => favorites++,
                ),
              ),
            ),
          ),
        ),
      );
      expect(find.byType(GridView), findsNothing);
      expect(find.byType(Wrap), findsWidgets);
      final first = find.text('emote0');
      final second = find.text('emote1');
      expect(tester.getTopLeft(first).dy, tester.getTopLeft(second).dy);
      expect(
        tester.getTopLeft(second).dx - tester.getTopLeft(first).dx,
        lessThanOrEqualTo(52),
      );
      await tester.tap(first);
      await tester.tap(second);
      expect(taps, 1);
      await tester.longPress(first);
      expect(favorites, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Official animated picker tile selects native renderer', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: TwitchEmotePickerTile(
            id: 'fixture',
            name: 'animated',
            isOfficial: true,
            isAnimated: true,
            imageUrl:
                'https://static-cdn.jtvnw.net/emoticons/v2/fixture/animated/dark/2.0',
            staticImageUrl:
                'https://static-cdn.jtvnw.net/emoticons/v2/fixture/static/dark/2.0',
          ),
        ),
      ),
    );
    expect(find.byType(TwitchNativeAnimatedEmoteImage), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
