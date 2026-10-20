import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final empty in [true, false]) {
    testWidgets('Bounded cancellation comparison empty=$empty', (tester) async {
      final controller = StreamController<void>.broadcast(sync: true);
      final stream = empty ? const Stream<void>.empty() : controller.stream;
      final subscription = stream.listen((_) {});
      var complete = false;
      final cancellation = subscription.cancel().then((_) => complete = true);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      // Report the fake-frame result before flushing real-zone futures.
      debugPrint(
        'Fixture cancellation empty=$empty completedAfterPump=$complete',
      );
      await tester.runAsync(
        () => cancellation.timeout(const Duration(seconds: 1)),
      );
      expect(complete, true);
      await tester.runAsync(controller.close);
    });
  }
}
