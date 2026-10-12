// ignore_for_file: avoid_relative_lib_imports, invalid_use_of_visible_for_testing_member, depend_on_referenced_packages
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import '../lib/features/twitch/presentation/settings/twitch_chat_appearance_controller.dart';
import '../lib/features/twitch/presentation/widgets/chat/message/twitch_chat_message_visual_metrics.dart';
import '../lib/features/twitch/presentation/widgets/chat/links/twitch_chat_link_preview_policy.dart';

class _Store extends InMemorySharedPreferencesStore {
  _Store(this.key, this.throws, Map<String, Object> seed)
    : super.withData(seed);
  final String key;
  final bool throws;
  int attempts = 0;
  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    if (key == 'flutter.${this.key}') {
      attempts++;
      if (attempts == 1) {
        if (throws) throw StateError('fixture save failure');
        return false;
      }
    }
    return super.setValue(valueType, key, value);
  }
}

void main() {
  test('new chat retains 100 percent with larger base text and unchanged emotes', () {
    const metrics = TwitchChatMessageVisualMetrics(1.0);
    expect(metrics.messageFontSize, 14);
    expect(metrics.nameFontSize, 14);
    expect(metrics.compactMessageFontSize, 13.4);
    expect(metrics.emoteSize, 28);
    expect(metrics.badgeSize, 18);
  });
  test('new chat defaults to 100 percent and preserves saved sizes', () async {
    SharedPreferences.setMockInitialValues({});
    final fresh = TwitchChatAppearanceController();
    addTearDown(fresh.dispose);
    expect(fresh.fontScale, 1.0);
    await fresh.load();
    expect(fresh.fontScale, 1.0);
    SharedPreferences.setMockInitialValues({'twitch_chat_font_scale_v1': 1.2});
    final existing = TwitchChatAppearanceController();
    addTearDown(existing.dispose);
    await existing.load();
    expect(existing.fontScale, 1.2);
    await existing.reset();
    expect(existing.fontScale, 1.0);
  });
  TestWidgetsFlutterBinding.ensureInitialized();
  const scale = 'twitch_chat_font_scale_v1';
  const links = 'twitch_chat_link_previews_enabled_v1';
  const times = 'twitch_chat_message_timestamps_enabled_v1';
  const domains = 'twitch_chat_trusted_preview_domains_v1';
  test(
    'Queued changes retain both new domains and the final switch value',
    () async {
      SharedPreferences.setMockInitialValues({});
      final controller = TwitchChatAppearanceController();
      addTearDown(controller.dispose);
      addTearDown(
        () =>
            configureTwitchChatLinkPreviews(enabled: true, trustedDomains: []),
      );
      await controller.load();
      await Future.wait([
        controller.addTrustedPreviewDomain('first.example'),
        controller.addTrustedPreviewDomain('second.example'),
        controller.setLinkPreviewsEnabled(false),
        controller.setLinkPreviewsEnabled(true),
      ]);
      expect(controller.trustedPreviewDomains, [
        'first.example',
        'second.example',
      ]);
      expect(controller.linkPreviewsEnabled, true);
      await (await SharedPreferences.getInstance()).reload();
      final restored = TwitchChatAppearanceController();
      addTearDown(restored.dispose);
      await restored.load();
      expect(restored.trustedPreviewDomains, controller.trustedPreviewDomains);
      expect(restored.linkPreviewsEnabled, true);
    },
  );
  for (final scenario in [
    'scale',
    'links',
    'timestamps',
    'add-domain',
    'remove-domain',
    'reset',
  ]) {
    for (final throws in [false, true]) {
      test(
        '$scenario failure preserves appearance and retries throws=$throws',
        () async {
          final seed = <String, Object>{
            scale: 1.2,
            links: true,
            times: false,
            domains: ['fixture.example'],
          };
          SharedPreferences.setMockInitialValues(seed);
          final key = switch (scenario) {
            'links' => links,
            'timestamps' => times,
            'add-domain' || 'remove-domain' => domains,
            _ => scale,
          };
          final previous = SharedPreferencesStorePlatform.instance;
          final store = _Store(key, throws, {
            for (final entry in seed.entries)
              'flutter.${entry.key}': entry.value,
          });
          SharedPreferencesStorePlatform.instance = store;
          addTearDown(() => SharedPreferencesStorePlatform.instance = previous);
          addTearDown(
            () => configureTwitchChatLinkPreviews(
              enabled: true,
              trustedDomains: [],
            ),
          );
          final controller = TwitchChatAppearanceController();
          addTearDown(controller.dispose);
          await controller.load();
          Future<void> change() => switch (scenario) {
            'scale' => controller.setFontScale(1.3),
            'links' => controller.setLinkPreviewsEnabled(false),
            'timestamps' => controller.setMessageTimestampsEnabled(true),
            'add-domain' => controller.addTrustedPreviewDomain('added.example'),
            'remove-domain' => controller.removeTrustedPreviewDomain(
              'fixture.example',
            ),
            _ => controller.reset(),
          };
          await expectLater(change(), throwsStateError);
          expect(controller.fontScale, 1.2);
          expect(controller.linkPreviewsEnabled, true);
          expect(controller.messageTimestampsEnabled, false);
          expect(controller.trustedPreviewDomains, ['fixture.example']);
          expect(
            extractTwitchChatPreviewUrls('https://fixture.example/a'),
            hasLength(1),
          );
          expect(
            extractTwitchChatPreviewUrls(
              'https://fixture.example/a',
            ).single.trusted,
            true,
          );
          expect(
            extractTwitchChatPreviewUrls('https://added.example/a'),
            isEmpty,
          );
          final prefs = await SharedPreferences.getInstance();
          expect({for (final key in seed.keys) key: prefs.get(key)}, seed);
          await change();
          expect(store.attempts, 2);
          await prefs.reload();
          final restored = TwitchChatAppearanceController();
          addTearDown(restored.dispose);
          await restored.load();
          expect(
            restored.fontScale,
            scenario == 'scale'
                ? 1.3
                : scenario == 'reset'
                ? TwitchChatAppearanceController.defaultFontScale
                : 1.2,
          );
          expect(restored.linkPreviewsEnabled, scenario != 'links');
          expect(restored.messageTimestampsEnabled, scenario == 'timestamps');
          expect(
            restored.trustedPreviewDomains,
            scenario == 'remove-domain'
                ? <String>[]
                : scenario == 'add-domain'
                ? ['added.example', 'fixture.example']
                : ['fixture.example'],
          );
        },
      );
    }
  }
}
