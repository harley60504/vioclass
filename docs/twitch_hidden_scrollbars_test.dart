// ignore_for_file: avoid_relative_lib_imports
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import '../lib/features/twitch/presentation/widgets/shared/twitch_app_scroll_behavior.dart';

void main() {
  for (final platform in [TargetPlatform.windows, TargetPlatform.android]) {
    testWidgets(
      'Hidden scrollbars keep wheel and touch scrolling on $platform',
      (tester) async {
        final controller = ScrollController();
        addTearDown(controller.dispose);
        await tester.pumpWidget(
          MaterialApp(
            scrollBehavior: twitchAppScrollBehavior,
            theme: ThemeData(platform: platform),
            home: Scaffold(
              body: ListView.builder(
                controller: controller,
                itemCount: 80,
                itemExtent: 50,
                itemBuilder: (_, index) => Text('row $index'),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(Scrollbar), findsNothing);
        expect(find.byType(RawScrollbar), findsNothing);
        final position = tester.getCenter(find.byType(ListView));
        tester.binding.handlePointerEvent(
          PointerScrollEvent(
            position: position,
            scrollDelta: const Offset(0, 150),
          ),
        );
        await tester.pumpAndSettle();
        expect(controller.offset, greaterThan(0));
        final before = controller.offset;
        await tester.drag(find.byType(ListView), const Offset(0, -180));
        await tester.pumpAndSettle();
        expect(controller.offset, greaterThan(before));
        expect(find.byType(Scrollbar), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}
