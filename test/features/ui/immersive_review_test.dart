import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:question_practice/core/ui/immersive_review.dart';

import '../../helpers/test_harness.dart';

void main() {
  testWidgets(
    'an open review hides the system bars and restores them on exit',
    (tester) async {
      final recorder = SystemUiCallRecorder()..install();
      addTearDown(recorder.dispose);

      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: ImmersiveReview(child: SizedBox.expand()),
        ),
      );
      await tester.pump();

      expect(recorder.modes, ['SystemUiMode.immersiveSticky']);

      await tester.pumpWidget(const SizedBox());
      await tester.pump();

      expect(recorder.modes.last, 'SystemUiMode.edgeToEdge');
    },
  );

  testWidgets('returning to the app keeps the review immersive', (
    tester,
  ) async {
    final recorder = SystemUiCallRecorder()..install();
    addTearDown(recorder.dispose);

    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: ImmersiveReview(child: SizedBox.expand()),
      ),
    );
    await tester.pump();
    expect(
      recorder.modes.where((mode) => mode == 'SystemUiMode.immersiveSticky'),
      hasLength(1),
    );

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();

    expect(
      recorder.modes.where((mode) => mode == 'SystemUiMode.immersiveSticky'),
      hasLength(2),
    );

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    expect(recorder.modes.last, 'SystemUiMode.edgeToEdge');
  });

  testWidgets('a page covering the review restores the bars until it returns', (
    tester,
  ) async {
    final recorder = SystemUiCallRecorder()..install();
    addTearDown(recorder.dispose);
    final navigatorKey = GlobalKey<NavigatorState>();

    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        navigatorObservers: [reviewRouteObserver],
        home: Builder(
          builder: (context) => ImmersiveReview(
            child: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (context) => const SizedBox.expand(),
                ),
              ),
              child: const Text('Cover'),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(recorder.modes.last, 'SystemUiMode.immersiveSticky');

    await tester.tap(find.text('Cover'));
    await tester.pumpAndSettle();
    expect(recorder.modes.last, 'SystemUiMode.edgeToEdge');

    navigatorKey.currentState!.pop();
    await tester.pumpAndSettle();
    expect(recorder.modes.last, 'SystemUiMode.immersiveSticky');

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    expect(recorder.modes.last, 'SystemUiMode.edgeToEdge');
  });
}
