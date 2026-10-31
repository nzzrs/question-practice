import 'package:flutter_test/flutter_test.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';
import 'package:question_practice/core/domain/models.dart';
import 'package:question_practice/core/platform/practice_sound_player.dart';
import 'package:question_practice/features/settings/settings_page.dart';

import '../../helpers/test_harness.dart';

void main() {
  testWidgets('volume slider saves the level and plays a test sound', (
    tester,
  ) async {
    final harness = TestHarness(soundPlayer: RecordingPracticeSoundPlayer());
    addTearDown(harness.close);
    await harness.settings.save(const AppSettings(soundVolume: 0.6));

    await pumpTestApp(tester, home: const SettingsPage(), harness: harness);

    expect(find.text('Sound volume'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.play_arrow));
    await pumpFrames(tester);

    final player = harness.soundPlayer as RecordingPracticeSoundPlayer;
    expect(player.played, contains(PracticeSound.correct));
    expect(player.volumes.last, closeTo(0.6, 0.001));

    final slider = tester.widget<M3ESlider>(find.byType(M3ESlider));
    slider.onChangeEnd!(1);
    await pumpFrames(tester);
    expect((await harness.settings.load()).soundVolume, closeTo(1, 0.001));
  });

  testWidgets('turning practice sounds off disables the test button', (
    tester,
  ) async {
    final harness = TestHarness(soundPlayer: RecordingPracticeSoundPlayer());
    addTearDown(harness.close);
    await harness.settings.save(const AppSettings(soundsEnabled: false));

    await pumpTestApp(tester, home: const SettingsPage(), harness: harness);

    await tester.tap(find.byIcon(Icons.play_arrow));
    await pumpFrames(tester);

    final player = harness.soundPlayer as RecordingPracticeSoundPlayer;
    expect(player.played, isEmpty);
  });
}
