// ignore_for_file: avoid_relative_lib_imports
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_test/flutter_test.dart';
import '../lib/features/twitch/presentation/widgets/shared/twitch_login_navigation_errors.dart';

void main() {
  for (final completing in [false, true]) {
    test('Explicit cancellation is expected; completing=$completing', () {
      expect(
        isExpectedTwitchLoginNavigationAbort(
          uri: Uri.parse('https://www.twitch.tv/'),
          type: WebResourceErrorType.CANCELLED,
          completingLogin: completing,
        ),
        isTrue,
      );
    });
    test('Blank host abort is expected; completing=$completing', () {
      expect(
        isExpectedTwitchLoginNavigationAbort(
          uri: Uri.parse('about:blank'),
          type: WebResourceErrorType.CONNECTION_ABORTED,
          completingLogin: completing,
        ),
        isTrue,
      );
    });
    test(
      'Ordinary connection abort is hidden only during login handoff; completing=$completing',
      () {
        expect(
          isExpectedTwitchLoginNavigationAbort(
            uri: Uri.parse('https://www.twitch.tv/'),
            type: WebResourceErrorType.CONNECTION_ABORTED,
            completingLogin: completing,
          ),
          completing,
        );
      },
    );
    test('Unrelated loading failure stays visible; completing=$completing', () {
      expect(
        isExpectedTwitchLoginNavigationAbort(
          uri: Uri.parse('https://id.twitch.tv/'),
          type: WebResourceErrorType.HOST_LOOKUP,
          completingLogin: completing,
        ),
        isFalse,
      );
    });
  }
}
