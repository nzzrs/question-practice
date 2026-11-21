import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';
import 'package:question_practice/app/theme.dart';
import 'package:question_practice/core/ui/adaptive_split_view.dart';

const _leadingKey = ValueKey('leading-pane');
const _trailingKey = ValueKey('trailing-pane');
const _leadingListKey = ValueKey('leading-list');
const _trailingListKey = ValueKey('trailing-list');

Widget _app(Widget child) {
  return M3EMaterialApp(
    data: appThemeData(),
    autoTheming: false,
    dynamicColoring: false,
    home: Scaffold(body: child),
  );
}

Widget _split({Key? storageKey, bool? horizontal}) {
  return AdaptiveSplitView(
    storageKey: storageKey,
    horizontal: horizontal,
    leading: const SizedBox.expand(key: _leadingKey),
    trailing: const SizedBox.expand(key: _trailingKey),
  );
}

Widget _scaled(Widget child, TextScaler textScaler) {
  return Builder(
    builder: (context) {
      return MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: textScaler),
        child: child,
      );
    },
  );
}

Future<void> _setSize(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Size _sizeOf(WidgetTester tester, Key key) {
  return tester.getSize(find.byKey(key));
}

void main() {
  testWidgets('picks the split axis from the window and allows an override', (
    tester,
  ) async {
    await _setSize(tester, const Size(400, 800));
    await tester.pumpWidget(_app(_split()));

    expect(_sizeOf(tester, AdaptiveSplitView.dividerKey), const Size(400, 48));
    expect(_sizeOf(tester, _leadingKey).height, closeTo(752 * 0.52, 0.01));
    expect(_sizeOf(tester, _leadingKey).width, 400);

    await _setSize(tester, const Size(800, 600));
    await tester.pumpWidget(_app(_split()));

    expect(_sizeOf(tester, AdaptiveSplitView.dividerKey), const Size(48, 600));
    expect(_sizeOf(tester, _leadingKey).width, closeTo(752 * 0.56, 0.01));
    expect(_sizeOf(tester, _leadingKey).height, 600);

    await _setSize(tester, const Size(640, 360));
    await tester.pumpWidget(_app(_split()));

    expect(_sizeOf(tester, AdaptiveSplitView.dividerKey), const Size(48, 360));

    await _setSize(tester, const Size(800, 600));
    await tester.pumpWidget(_app(_split(horizontal: false)));

    expect(_sizeOf(tester, AdaptiveSplitView.dividerKey), const Size(800, 48));
    expect(_sizeOf(tester, _leadingKey).height, closeTo(552 * 0.52, 0.01));
    expect(_sizeOf(tester, _leadingKey).width, 800);
  });

  testWidgets('drag updates the ratio and clamps at both pane minimums', (
    tester,
  ) async {
    await _setSize(tester, const Size(800, 600));
    await tester.pumpWidget(_app(_split()));

    final start = _sizeOf(tester, _leadingKey).width;
    await tester.drag(
      find.byKey(AdaptiveSplitView.dividerKey),
      const Offset(30, 0),
    );
    await tester.pumpAndSettle();

    expect(_sizeOf(tester, _leadingKey).width, greaterThan(start));

    await tester.drag(
      find.byKey(AdaptiveSplitView.dividerKey),
      const Offset(-1000, 0),
    );
    await tester.pumpAndSettle();

    expect(_sizeOf(tester, _leadingKey).width, closeTo(300, 0.01));
    expect(_sizeOf(tester, _trailingKey).width, closeTo(452, 0.01));

    await tester.drag(
      find.byKey(AdaptiveSplitView.dividerKey),
      const Offset(1000, 0),
    );
    await tester.pumpAndSettle();

    expect(_sizeOf(tester, _leadingKey).width, closeTo(472, 0.01));
    expect(_sizeOf(tester, _trailingKey).width, closeTo(280, 0.01));
    expect(
      _sizeOf(tester, _leadingKey).width +
          _sizeOf(tester, _trailingKey).width +
          AdaptiveSplitView.dividerExtent,
      closeTo(800, 0.01),
    );
  });

  testWidgets(
    'keeps a ratio per axis in PageStorage and resets for a new key',
    (tester) async {
      await _setSize(tester, const Size(800, 600));
      final bucket = PageStorageBucket();
      const key = PageStorageKey<String>('review-split');

      Widget page(Key? storageKey) {
        return _app(
          PageStorage(
            bucket: bucket,
            child: _split(storageKey: storageKey),
          ),
        );
      }

      await tester.pumpWidget(page(key));
      final initial = _sizeOf(tester, _leadingKey).width;
      await tester.drag(
        find.byKey(AdaptiveSplitView.dividerKey),
        const Offset(90, 0),
      );
      await tester.pumpAndSettle();
      final dragged = _sizeOf(tester, _leadingKey).width;
      expect(dragged, greaterThan(initial));

      await tester.pumpWidget(_app(const SizedBox()));
      await tester.pumpWidget(page(key));

      expect(_sizeOf(tester, _leadingKey).width, closeTo(dragged, 0.01));

      await tester.pumpWidget(
        page(const PageStorageKey<String>('other-split')),
      );

      expect(_sizeOf(tester, _leadingKey).width, closeTo(initial, 0.01));
    },
  );

  testWidgets('keeps separate ratios for stacked and side-by-side layouts', (
    tester,
  ) async {
    await _setSize(tester, const Size(400, 800));
    await tester.pumpWidget(_app(_split()));

    final stackedDefault = _sizeOf(tester, _leadingKey).height;
    await tester.drag(
      find.byKey(AdaptiveSplitView.dividerKey),
      const Offset(0, 100),
    );
    await tester.pumpAndSettle();
    final stackedDragged = _sizeOf(tester, _leadingKey).height;
    expect(stackedDragged, greaterThan(stackedDefault));

    await _setSize(tester, const Size(800, 600));
    await tester.pumpWidget(_app(_split()));

    final sideBySideDefault = _sizeOf(tester, _leadingKey).width;
    expect(sideBySideDefault, closeTo(752 * 0.56, 0.01));
    await tester.drag(
      find.byKey(AdaptiveSplitView.dividerKey),
      const Offset(-100, 0),
    );
    await tester.pumpAndSettle();
    expect(_sizeOf(tester, _leadingKey).width, lessThan(sideBySideDefault));

    await _setSize(tester, const Size(400, 800));
    await tester.pumpWidget(_app(_split()));

    expect(_sizeOf(tester, _leadingKey).height, closeTo(stackedDragged, 0.01));
  });

  testWidgets('fits when a keyboard leaves very little height', (tester) async {
    await _setSize(tester, const Size(360, 200));
    await tester.pumpWidget(_app(_split()));

    expect(tester.takeException(), isNull);
    expect(
      _sizeOf(tester, _leadingKey).height +
          _sizeOf(tester, _trailingKey).height +
          AdaptiveSplitView.dividerExtent,
      closeTo(200, 0.01),
    );
  });

  testWidgets('semantics and keyboard adjust the divider', (tester) async {
    final semantics = tester.ensureSemantics();
    await _setSize(tester, const Size(800, 600));
    await tester.pumpWidget(_app(_split()));

    final initial = _sizeOf(tester, _leadingKey).width;
    await tester.drag(
      find.byKey(AdaptiveSplitView.dividerKey),
      const Offset(-100, 0),
    );
    await tester.pumpAndSettle();

    final start = _sizeOf(tester, _leadingKey).width;
    expect(start, lessThan(initial));
    final node = tester.getSemantics(find.byKey(AdaptiveSplitView.dividerKey));
    expect(node.label, 'Resize panes');
    expect(node.value, contains('percent'));
    expect(node.value, isNot(contains('minimum')));
    expect(node.value, isNot(contains('maximum')));

    node.owner!.performAction(node.id, SemanticsAction.increase);
    await tester.pumpAndSettle();

    final increased = _sizeOf(tester, _leadingKey).width;
    expect(increased, closeTo(start + 752 * 0.10, 0.6));

    node.owner!.performAction(node.id, SemanticsAction.decrease);
    await tester.pumpAndSettle();

    expect(_sizeOf(tester, _leadingKey).width, closeTo(start, 0.6));

    await tester.tap(find.byKey(AdaptiveSplitView.dividerKey));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();

    expect(
      _sizeOf(tester, _leadingKey).width,
      closeTo(start + 752 * 0.05, 0.6),
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();

    expect(_sizeOf(tester, _leadingKey).width, closeTo(start, 0.6));
    semantics.dispose();
  });

  testWidgets('keeps a 48dp divider and fits at 320dp and 2x text', (
    tester,
  ) async {
    await _setSize(tester, const Size(320, 480));
    await tester.pumpWidget(
      _app(_scaled(_split(), const TextScaler.linear(2))),
    );

    expect(tester.takeException(), isNull);
    expect(_sizeOf(tester, AdaptiveSplitView.dividerKey), const Size(320, 48));
    expect(_sizeOf(tester, _leadingKey).width, 320);
    expect(
      _sizeOf(tester, _leadingKey).height +
          _sizeOf(tester, _trailingKey).height +
          AdaptiveSplitView.dividerExtent,
      closeTo(480, 0.01),
    );

    await tester.drag(
      find.byKey(AdaptiveSplitView.dividerKey),
      const Offset(0, -100),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(
      _sizeOf(tester, _leadingKey).height +
          _sizeOf(tester, _trailingKey).height +
          AdaptiveSplitView.dividerExtent,
      closeTo(480, 0.01),
    );

    await _setSize(tester, const Size(720, 500));
    await tester.pumpWidget(
      _app(_scaled(_split(), const TextScaler.linear(2))),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(_sizeOf(tester, AdaptiveSplitView.dividerKey), const Size(48, 500));
  });

  testWidgets('the panes scroll independently', (tester) async {
    final leadingController = ScrollController();
    final trailingController = ScrollController();
    addTearDown(leadingController.dispose);
    addTearDown(trailingController.dispose);
    await _setSize(tester, const Size(800, 600));

    Widget list(Key key, ScrollController controller) {
      return ListView.builder(
        key: key,
        controller: controller,
        itemCount: 60,
        itemBuilder: (context, index) =>
            SizedBox(height: 48, child: Text('item $index')),
      );
    }

    await tester.pumpWidget(
      _app(
        AdaptiveSplitView(
          leading: list(_leadingListKey, leadingController),
          trailing: list(_trailingListKey, trailingController),
        ),
      ),
    );

    await tester.drag(find.byKey(_leadingListKey), const Offset(0, -180));
    await tester.pumpAndSettle();

    expect(leadingController.offset, greaterThan(0));
    expect(trailingController.offset, 0);
    final leadingOffset = leadingController.offset;

    await tester.drag(find.byKey(_trailingListKey), const Offset(0, -180));
    await tester.pumpAndSettle();

    expect(trailingController.offset, greaterThan(0));
    expect(leadingController.offset, leadingOffset);
  });
}
