// ignore_for_file: avoid_relative_lib_imports
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../lib/features/twitch/presentation/pages/twitch_stream_home_models.dart';
import '../lib/features/twitch/presentation/theme/twitch_ui_tokens.dart';
import '../lib/features/twitch/presentation/widgets/discovery/twitch_discovery_stream_template.dart';
import '../lib/features/twitch/presentation/widgets/home/twitch_stream_home_toolbar.dart';

void main() {
  for (final width in [600.0, 720.0, 1024.0]) {
    for (final empty in [false, true]) {
      testWidgets('shared surface clears toolbar width=$width empty=$empty', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(1200, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final search = TextEditingController();
        addTearDown(search.dispose);
        const contentKey = ValueKey('search-content');
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: width,
                  height: 700,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: TwitchDiscoveryScrollSurface(
                          slivers: [
                            if (empty)
                              const SliverFillRemaining(
                                hasScrollBody: false,
                                child: SizedBox(
                                  key: contentKey,
                                  child: Center(child: Text('empty fixture')),
                                ),
                              )
                            else
                              const SliverToBoxAdapter(
                                child: SizedBox(
                                  key: contentKey,
                                  height: 150,
                                  child: Text('result fixture'),
                                ),
                              ),
                          ],
                        ),
                      ),
                      Positioned(
                        top: 8,
                        left: 16,
                        right: 16,
                        child: TwitchStreamHomeToolbar(
                          selectedSection: TwitchHomeSection.following,
                          onSelectSection: (_) {},
                          searchController: search,
                          onSearchChanged: (_) {},
                          onClearSearch: () {},
                          onShowGameMenu: () {},
                          onShowLanguageMenu: () {},
                          onRefresh: () async {},
                          onOpenDropsConnector: () async {},
                          onOpenSettings: () async {},
                          forceTwoRows: width < 720,
                          whispersEnabled: false,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final toolbar = tester.getRect(find.byType(TwitchStreamHomeToolbar));
        final content = tester.getRect(find.byKey(contentKey));
        expect(content.top, width < 720 ? 118 : 70);
        expect(content.top, greaterThan(toolbar.bottom));
        final background = tester.widget<ColoredBox>(
          find
              .descendant(
                of: find.byType(TwitchDiscoveryScrollSurface),
                matching: find.byType(ColoredBox),
              )
              .first,
        );
        expect(background.color, TwitchUiColors.appBackground);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
