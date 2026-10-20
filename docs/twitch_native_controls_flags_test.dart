import 'package:flutter_test/flutter_test.dart';
import '../integration_test/twitch_readonly_app_test.dart' as integration;

void main() {
  for (final flags in [
    (false, false, false),
    (true, true, false),
    (true, false, true),
  ]) {
    test('Native controls reject unsafe routing flags=$flags', () {
      expect(
        () => integration.validateIsolatedNativeControlFlags(
          enabled: true,
          localGuestSurface: flags.$1,
          remote: flags.$2,
          guestHomeMedia: flags.$3,
        ),
        throwsStateError,
      );
    });
  }
  test('Native controls permit only local isolated guest routing', () {
    expect(
      () => integration.validateIsolatedNativeControlFlags(
        enabled: true,
        localGuestSurface: true,
        remote: false,
        guestHomeMedia: false,
      ),
      returnsNormally,
    );
  });
  test('Existing routes remain unchanged with native controls disabled', () {
    expect(
      () => integration.validateIsolatedNativeControlFlags(
        enabled: false,
        localGuestSurface: false,
        remote: true,
        guestHomeMedia: true,
      ),
      returnsNormally,
    );
  });
}
