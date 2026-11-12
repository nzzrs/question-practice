import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:question_practice/core/ui/widgets.dart';

import '../../helpers/test_harness.dart';

void main() {
  testWidgets('OptionTile renders its badge, title and value and taps', (
    tester,
  ) async {
    var taps = 0;
    await pumpTestApp(
      tester,
      home: Scaffold(
        body: OptionTile(
          icon: Icons.edit_outlined,
          title: 'Edit topic',
          subtitle: 'Change the name, description, priority or deck',
          onTap: () => taps++,
        ),
      ),
    );

    expect(find.text('Edit topic'), findsOneWidget);
    expect(
      find.text('Change the name, description, priority or deck'),
      findsOneWidget,
    );
    expect(find.byType(IconBadge), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right), findsOneWidget);

    await tester.tap(find.text('Edit topic'));
    await pumpFrames(tester);
    expect(taps, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a destructive OptionTile uses the error tone', (tester) async {
    await pumpTestApp(
      tester,
      home: Scaffold(
        body: OptionTile(
          icon: Icons.delete_outline,
          title: 'Delete topic',
          subtitle: 'Remove the topic and everything inside it',
          destructive: true,
          onTap: () {},
        ),
      ),
    );

    expect(
      tester.widget<IconBadge>(find.byType(IconBadge)).tone,
      PillTone.error,
    );
    expect(find.byIcon(Icons.chevron_right), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an expandable OptionTile shows its state and inline details', (
    tester,
  ) async {
    await pumpTestApp(
      tester,
      home: Scaffold(
        body: Column(
          children: [
            OptionTile(
              icon: Icons.label_outline,
              title: 'Name',
              subtitle: 'Cloud',
              expanded: false,
              onTap: () {},
            ),
            OptionTile(
              icon: Icons.notes_outlined,
              title: 'Description',
              subtitle: 'Topic description',
              expanded: true,
              onTap: () {},
              details: const Text('Inline editor'),
            ),
          ],
        ),
      ),
    );

    expect(find.byIcon(Icons.expand_more), findsOneWidget);
    expect(find.byIcon(Icons.expand_less), findsOneWidget);
    expect(find.text('Inline editor'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a trailing widget replaces the chevron', (tester) async {
    await pumpTestApp(
      tester,
      home: Scaffold(
        body: OptionTile(
          icon: Icons.label_outline,
          title: 'Name',
          subtitle: 'Cloud',
          trailing: const Icon(Icons.done),
          onTap: () {},
        ),
      ),
    );

    expect(find.byIcon(Icons.done), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
