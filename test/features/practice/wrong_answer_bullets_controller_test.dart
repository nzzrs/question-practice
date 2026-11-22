import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:question_practice/features/feedback/wrong_answer_bullets_controller.dart';

void main() {
  test(
    'flush waits for the running save and persists the latest rows',
    () async {
      final firstSave = Completer<void>();
      final saves = <List<String>>[];
      final controller = WrongAnswerBulletsController(
        initial: const [],
        onSave: (notes) async {
          saves.add(notes);
          if (saves.length == 1) await firstSave.future;
        },
      );
      addTearDown(controller.dispose);

      controller.setRow(0, 'first');
      final running = controller.save();
      await Future<void>.delayed(Duration.zero);
      expect(controller.saveState, WrongAnswerBulletsSaveState.saving);

      controller.setRow(0, 'second');
      final flushed = controller.flush();
      firstSave.complete();

      expect(await running, isTrue);
      expect(await flushed, isTrue);
      expect(saves, [
        ['first'],
        ['second'],
      ]);
      expect(controller.isDirty, isFalse);
      expect(controller.saveState, WrongAnswerBulletsSaveState.clean);
    },
  );

  test('a failed save stays dirty so a later flush retries it', () async {
    var attempts = 0;
    final controller = WrongAnswerBulletsController(
      initial: const [],
      onSave: (notes) async {
        attempts++;
        if (attempts == 1) throw StateError('database is busy');
      },
    );
    addTearDown(controller.dispose);

    controller.setRow(0, 'keep me');
    expect(await controller.flush(), isFalse);
    expect(controller.saveState, WrongAnswerBulletsSaveState.failed);
    expect(controller.isDirty, isTrue);

    expect(await controller.flush(), isTrue);
    expect(attempts, 2);
    expect(controller.saveState, WrongAnswerBulletsSaveState.clean);
    expect(controller.isDirty, isFalse);
  });
}
