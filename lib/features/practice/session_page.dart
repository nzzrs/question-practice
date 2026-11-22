import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/providers.dart';
import '../../core/domain/models.dart';
import '../../core/platform/practice_sound_player.dart';
import '../../core/ui/widgets.dart';
import '../feedback/domain/wrong_answer_bullets.dart';
import '../feedback/feedback_actions.dart';
import '../feedback/feedback_snapshot.dart';
import '../feedback/question_feedback_view.dart';
import '../feedback/wrong_answer_bullets_controller.dart';
import '../lookup/lookup_actions.dart';
import '../lookup/ask_sheet.dart';
import '../practice/domain/session_service.dart';
import '../practice/summary_page.dart';

enum _ExitChoice { save, discard }

enum _FinishChoice { leaveUnanswered, markSkipped }

enum _NoteAction { define, ask, delete }

class SessionPage extends ConsumerStatefulWidget {
  const SessionPage({required this.start, super.key});

  final SessionStart start;

  @override
  ConsumerState<SessionPage> createState() => _SessionPageState();
}

class _SessionPageState extends ConsumerState<SessionPage>
    with WidgetsBindingObserver {
  late SessionStart _start;
  SessionQuestionItem? _item;
  int _index = 0;
  final _selectedIndexes = <int>{};
  final _notes = <int, List<Note>>{};
  WrongAnswerBulletsController? _wrongAnswerBullets;
  bool _submitted = false;
  bool _submitting = false;
  bool _distracted = false;
  bool _showOriginalLetters = false;
  AnswerOutcome? _outcome;
  SessionSummary? _summary;
  int _questionMinutes = 0;
  Timer? _questionTimer;
  FloatingToastHandle? _toast;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky),
    );
    _start = widget.start;
    _index = _start.items.isEmpty
        ? 0
        : _start.currentIndex.clamp(0, _start.items.length - 1).toInt();
    _item = _start.items.isEmpty ? null : _start.items[_index];
    _loadQuestionState();
    unawaited(_loadNotes());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_item == null) _finishExisting();
    });
  }

  Future<void> _loadNotes() async {
    try {
      final repository = ref.read(cardRepositoryProvider);
      final byQuestion = <int, List<Note>>{};
      final loaded = <int>{};
      for (final item in _start.items) {
        final questionId = item.question.id;
        if (!loaded.add(questionId)) continue;
        final notes = await repository.notesForQuestion(questionId);
        if (notes.isNotEmpty) byQuestion[questionId] = notes;
      }
      if (!mounted) return;
      setState(() {
        _notes
          ..clear()
          ..addAll(byQuestion);
      });
    } on Object catch (error) {
      if (mounted) {
        await showSnack(context, 'Could not load notes: $error');
      }
    }
  }

  Future<void> _reloadNotes(int questionId) async {
    final notes = await ref
        .read(cardRepositoryProvider)
        .notesForQuestion(questionId);
    if (!mounted) return;
    setState(() {
      if (notes.isEmpty) {
        _notes.remove(questionId);
      } else {
        _notes[questionId] = notes;
      }
    });
  }

  Future<void> _addNote(String selection, Rect? anchor) async {
    final item = _item;
    if (item == null) return;
    final text = selection.trim();
    if (text.isEmpty) return;
    final lowered = text.toLowerCase();
    final existing = _notes[item.question.id] ?? const <Note>[];
    if (existing.any((note) => note.text.trim().toLowerCase() == lowered)) {
      await showSnack(context, 'That phrase is already saved as a note.');
      return;
    }
    try {
      await ref
          .read(cardRepositoryProvider)
          .createNote(
            sessionId: _start.session.id,
            questionId: item.question.id,
            text: text,
            context: item.question.prompt,
            topicName: item.topicName,
            practiceName: item.practiceName,
            subtopic: item.question.subtopic,
            createdAt: ref.read(clockProvider).now().toUtc(),
          );
      if (!mounted) return;
      await _reloadNotes(item.question.id);
      if (!mounted) return;
      await showSnack(context, 'Note saved. It is ready in the review.');
    } on Object catch (error) {
      if (mounted) {
        await showSnack(context, 'Could not save the note: $error');
      }
    }
  }

  Future<void> _deleteNote(int questionId, String phrase) async {
    final lowered = phrase.trim().toLowerCase();
    final matches = [
      for (final note in _notes[questionId] ?? const <Note>[])
        if (note.text.trim().toLowerCase() == lowered) note,
    ];
    if (matches.isEmpty) return;
    try {
      await ref.read(cardRepositoryProvider).deleteNotes([
        for (final note in matches) note.id,
      ]);
      if (!mounted) return;
      final removed = {for (final note in matches) note.id};
      setState(() {
        final remaining = [
          for (final note in _notes[questionId] ?? const <Note>[])
            if (!removed.contains(note.id)) note,
        ];
        if (remaining.isEmpty) {
          _notes.remove(questionId);
        } else {
          _notes[questionId] = remaining;
        }
      });
      await showSnack(context, 'Note deleted.');
    } on Object catch (error) {
      if (mounted) {
        await showSnack(context, 'Could not delete the note: $error');
      }
    }
  }

  Future<void> _openNoteActions(String phrase) async {
    final item = _item;
    if (item == null) return;
    var aiAvailable = ref.read(hasApiKeyProvider).value;
    if (aiAvailable == null) {
      try {
        aiAvailable = await ref.read(hasApiKeyProvider.future);
      } on Object {
        aiAvailable = false;
      }
    }
    if (!mounted) return;
    final action = await M3EBottomSheet.show<_NoteAction>(
      context,
      initialValue: M3EBottomSheetValue.expanded,
      builder: (context) =>
          _NoteActionsSheet(phrase: phrase, showAsk: aiAvailable ?? false),
    );
    if (action == null || !mounted) return;
    switch (action) {
      case _NoteAction.define:
        await _openLookup(phrase, null);
      case _NoteAction.ask:
        await _openAsk(phrase, null);
      case _NoteAction.delete:
        await _deleteNote(item.question.id, phrase);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _questionTimer?.cancel();
    _toast?.dismiss();
    _wrongAnswerBullets?.dispose();
    unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge));
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _restartQuestionTimer();
    } else {
      _questionTimer?.cancel();
      _toast?.dismiss();
      _toast = null;
      unawaited(_wrongAnswerBullets?.flush());
    }
  }

  /// Creates the bullet editor only for a wrong, non-skipped answer.
  void _syncWrongAnswerBullets(Attempt attempt) {
    final item = _item;
    if (item == null || attempt.isCorrect || attempt.isSkipped) {
      _wrongAnswerBullets?.dispose();
      _wrongAnswerBullets = null;
      return;
    }
    if (_wrongAnswerBullets != null) return;
    final questionItem = item;
    _wrongAnswerBullets = WrongAnswerBulletsController(
      initial: WrongAnswerBullets.parse(attempt.reasoning),
      onSave: (bullets) => _saveWrongAnswerBullets(questionItem, bullets),
    );
  }

  Future<void> _saveWrongAnswerBullets(
    SessionQuestionItem item,
    List<String> bullets,
  ) async {
    final attempt = await ref
        .read(sessionServiceProvider)
        .setWrongAnswerBullets(start: _start, item: item, bullets: bullets);
    if (!mounted) return;
    _start.attempts[item.question.id] = attempt;
    ref.invalidate(dueErrorsProvider);
    if (_item?.question.id != item.question.id) return;
    setState(() {
      _outcome = AnswerOutcome(attempt: attempt, summary: _summary);
    });
  }

  /// Persists a pending bullet edit before leaving the question.
  Future<bool> _flushWrongAnswerBullets() async {
    final bullets = _wrongAnswerBullets;
    if (bullets == null) return true;
    return bullets.flush();
  }

  void _restartQuestionTimer() {
    _questionTimer?.cancel();
    _toast?.dismiss();
    _toast = null;
    _questionMinutes = 0;
    if (_item == null ||
        _submitted ||
        _start.session.status != SessionStatus.inProgress) {
      return;
    }
    _questionTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      if (!mounted) return;
      _questionMinutes += 5;
      _toast?.dismiss();
      _toast = showFloatingToast(
        context,
        message:
            '$_questionMinutes minutes on this question. Still with us? Take a breath.',
      );
    });
  }

  Future<void> _finishExisting() async {
    final summary = await ref
        .read(sessionServiceProvider)
        .completeIfReady(_start.session.id);
    if (!mounted) return;
    if (summary != null) {
      _openSummary(summary);
    }
  }

  void _loadQuestionState() {
    final item = _start.items.isEmpty ? null : _start.items[_index];
    _item = item;
    _selectedIndexes.clear();
    _outcome = null;
    _submitted = false;
    _distracted = false;
    _wrongAnswerBullets?.dispose();
    _wrongAnswerBullets = null;
    if (item == null) {
      _restartQuestionTimer();
      return;
    }
    final attempt = _start.attempts[item.question.id];
    if (attempt == null) {
      _restartQuestionTimer();
      return;
    }
    _selectedIndexes.addAll(attempt.selectedIndexes);
    _submitted = true;
    _distracted = attempt.distracted;
    _outcome = AnswerOutcome(attempt: attempt, summary: _summary);
    _syncWrongAnswerBullets(attempt);
    _restartQuestionTimer();
  }

  Future<void> _goTo(int index) async {
    if (index < 0 || index >= _start.items.length || index == _index) return;
    if (!await _flushWrongAnswerBullets()) return;
    setState(() {
      _index = index;
      _loadQuestionState();
    });
  }

  Future<void> _submit({required bool skip}) async {
    final item = _item;
    if (item == null || _submitting) return;
    if (!skip && _selectedIndexes.isEmpty) {
      await showSnack(context, 'Choose an alternative, or skip the question.');
      return;
    }
    setState(() => _submitting = true);
    try {
      final outcome = await ref
          .read(sessionServiceProvider)
          .submitAnswer(
            start: _start,
            item: item,
            selectedIndexes: skip ? const [] : _selectedIndexes.toList(),
            reasoning: '',
            distracted: false,
          );
      if (!mounted) return;
      setState(() {
        _submitted = true;
        _outcome = outcome;
        if (outcome.summary != null) _summary = outcome.summary;
        _syncWrongAnswerBullets(outcome.attempt);
      });
      _questionTimer?.cancel();
      _toast?.dismiss();
      _toast = null;
      unawaited(_playAnswerSound(outcome.attempt));
    } on SessionException catch (error) {
      if (mounted) await showSnack(context, error.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _playAnswerSound(Attempt attempt) async {
    if (attempt.isSkipped) return;
    final current = ref.read(settingsProvider).value;
    final enabled =
        current?.soundsEnabled ??
        (await ref.read(settingsRepositoryProvider).load()).soundsEnabled;
    if (!enabled) return;
    final volume =
        current?.soundVolume ??
        (await ref.read(settingsRepositoryProvider).load()).soundVolume;
    await ref
        .read(practiceSoundPlayerProvider)
        .play(
          attempt.isCorrect ? PracticeSound.correct : PracticeSound.wrong,
          volume: volume,
        );
  }

  Future<void> _setDistracted(bool value) async {
    final item = _item;
    if (item == null || _submitting) return;
    setState(() => _submitting = true);
    if (!await _flushWrongAnswerBullets()) {
      if (!mounted) return;
      setState(() => _submitting = false);
      await showSnack(context, 'Your notes are not saved. Try again.');
      return;
    }
    if (!mounted) return;
    try {
      final attempt = await ref
          .read(sessionServiceProvider)
          .setDistracted(start: _start, item: item, distracted: value);
      if (!mounted) return;
      _start.attempts[item.question.id] = attempt;
      setState(() {
        _distracted = attempt.distracted;
        _outcome = AnswerOutcome(attempt: attempt, summary: _summary);
        _syncWrongAnswerBullets(attempt);
      });
      ref.invalidate(dueErrorsProvider);
    } on SessionException catch (error) {
      if (mounted) await showSnack(context, error.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _next() async {
    if (!await _flushWrongAnswerBullets()) return;
    if (_summary != null && _index >= _start.items.length - 1) {
      _openSummary(_summary!);
      return;
    }
    if (_index + 1 < _start.items.length) {
      await _goTo(_index + 1);
      return;
    }
    final unanswered = _start.items.indexWhere(
      (entry) => !_start.attempts.containsKey(entry.question.id),
    );
    if (unanswered >= 0) {
      await _goTo(unanswered);
      return;
    }
    if (_summary != null) {
      _openSummary(_summary!);
      return;
    }
    await _finishEarly();
  }

  Future<void> _finishEarly() async {
    if (_submitting) return;
    if (!await _flushWrongAnswerBullets()) return;
    if (!mounted) return;
    final unanswered = _start.pendingUnanswered.length;
    if (unanswered <= 0) {
      final summary =
          _summary ??
          await ref
              .read(sessionServiceProvider)
              .finishEarly(start: _start, markSkipped: false);
      if (mounted) await _openSummary(summary);
      return;
    }
    final choice = await M3EDialog.show<_FinishChoice>(
      context,
      dialog: M3EDialog(
        title: 'Finish practice?',
        content: Text(
          '$unanswered question${unanswered == 1 ? '' : 's'} are unanswered. '
          'Leave them out of the score, or mark them skipped?',
        ),
        actions: [
          M3EButton.text(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          M3EButton.text(
            onPressed: () =>
                Navigator.of(context).pop(_FinishChoice.leaveUnanswered),
            child: const Text('Leave unanswered'),
          ),
          M3EButton.filled(
            onPressed: () =>
                Navigator.of(context).pop(_FinishChoice.markSkipped),
            child: const Text('Mark skipped'),
          ),
        ],
      ),
    );
    if (choice == null || !mounted) return;
    setState(() => _submitting = true);
    try {
      final summary = await ref
          .read(sessionServiceProvider)
          .finishEarly(
            start: _start,
            markSkipped: choice == _FinishChoice.markSkipped,
          );
      if (!mounted) return;
      await _openSummary(summary);
    } on SessionException catch (error) {
      if (mounted) await showSnack(context, error.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _openQuestionList() async {
    final selected = await M3EBottomSheet.show<int>(
      context,
      initialValue: M3EBottomSheetValue.expanded,
      builder: (context) =>
          _QuestionPickerSheet(start: _start, currentIndex: _index),
    );
    if (selected == null || !mounted) return;
    await _goTo(selected);
  }

  Future<void> _openSummary(SessionSummary summary) async {
    if (!mounted) return;
    SessionSummary latest;
    try {
      latest = await ref
          .read(sessionServiceProvider)
          .summaryFor(summary.session.id);
    } on SessionException {
      latest = summary;
    }
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (context) => SummaryPage(summary: latest),
      ),
    );
  }

  Future<void> _requestExit() async {
    final saved = await _flushWrongAnswerBullets();
    if (!mounted) return;
    if (!saved) {
      await showSnack(context, 'Your notes are not saved. Try again.');
      return;
    }
    if (_summary != null) {
      _openSummary(_summary!);
      return;
    }
    final choice = await M3EDialog.show<_ExitChoice>(
      context,
      dialog: M3EDialog(
        title: 'Leave this practice?',
        content: const Text(
          'Save for later to keep your answers and continue from Home. '
          'Discard deletes this unfinished session and the error cards it created.',
        ),
        actions: [
          M3EButton.text(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          M3EButton.text(
            onPressed: () => Navigator.of(context).pop(_ExitChoice.discard),
            child: const Text('Discard'),
          ),
          M3EButton.filled(
            onPressed: () => Navigator.of(context).pop(_ExitChoice.save),
            child: const Text('Save for later'),
          ),
        ],
      ),
    );
    if (choice == null || !mounted) return;
    if (choice == _ExitChoice.discard) {
      await ref.read(sessionServiceProvider).discard(_start.session.id);
    }
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _openLookup(String term, Rect? anchor) async {
    final item = _item;
    if (item == null) return;
    await openTermLookup(
      context,
      ref,
      term: term,
      question: item.question.prompt,
      topicName: item.topicName,
      practiceName: item.practiceName,
      sessionId: _start.session.id,
      questionId: item.question.id,
      subtopic: item.question.subtopic,
      anchor: anchor,
    );
  }

  Future<void> _openUrl(String value) {
    return openStudyUrl(context, ref, value);
  }

  Future<void> _openAsk(String selection, Rect? anchor) async {
    final item = _item;
    if (item == null) return;
    await showAskAboutSelection(
      context,
      selection: selection,
      question: item.question.prompt,
      topicName: item.topicName,
      practiceName: item.practiceName,
      sessionId: _start.session.id,
      questionId: item.question.id,
      subtopic: item.question.subtopic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final item = _item;
    if (item == null) {
      return AppPage(
        title: 'Practice',
        showBack: true,
        variant: M3EAppBarVariant.small,
        children: const [
          Padding(
            padding: EdgeInsets.symmetric(vertical: 64),
            child: Center(child: M3ELoadingIndicator()),
          ),
        ],
      );
    }
    final theme = M3ETheme.of(context);
    final total = _start.items.length;
    final position = _index + 1;
    final answered = _start.attempts.length;
    final unanswered = _start.pendingUnanswered.length;
    final progress = answered.clamp(0, total) / total;
    final atLast = _index >= total - 1;
    final seesResults = unanswered == 0 && _summary != null && atLast;
    final currentDone = _start.isDone(item);
    final modeTitle = switch (_start.session.mode) {
      SessionMode.practice => item.practiceName,
      SessionMode.mixed => 'Shuffled practice',
      SessionMode.pastErrors => 'Past errors',
    };

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _requestExit();
      },
      child: Scaffold(
        backgroundColor: theme.colorScheme.surface,
        appBar: M3EAppBar.top(
          titleText: modeTitle.isEmpty ? 'Practice' : modeTitle,
          actions: [
            M3EIconButton(
              variant: M3EIconButtonVariant.standard,
              icon: Icon(
                _showOriginalLetters
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
              ),
              tooltip: _showOriginalLetters
                  ? 'Hide original letters'
                  : 'Show original letters',
              onPressed: () =>
                  setState(() => _showOriginalLetters = !_showOriginalLetters),
            ),
            M3EIconButton(
              variant: M3EIconButtonVariant.standard,
              icon: const Icon(Icons.flag_outlined),
              tooltip: 'Finish practice',
              onPressed: _submitting ? null : _finishEarly,
            ),
            M3EIconButton(
              key: const ValueKey('session-leave'),
              variant: M3EIconButtonVariant.standard,
              icon: const Icon(Icons.close),
              tooltip: 'Leave practice',
              onPressed: _requestExit,
            ),
          ],
        ),
        body: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
              children: [
                _QuestionNavigator(
                  position: position,
                  total: total,
                  progress: progress,
                  pastErrors: _start.session.mode == SessionMode.pastErrors,
                  done: currentDone,
                  previousEnabled: _index > 0 && !_submitting,
                  nextEnabled: _index < total - 1 && !_submitting,
                  onPrevious: () => _goTo(_index - 1),
                  onNext: () => _goTo(_index + 1),
                  onOpenList: _openQuestionList,
                ),
                const SizedBox(height: 22),
                QuestionFeedbackView(
                  snapshot: _submitted
                      ? FeedbackSnapshot.fromAttempt(
                          item: item,
                          attempt: _outcome!.attempt,
                          mode: FeedbackMode.practice,
                          pastErrors:
                              _start.session.mode == SessionMode.pastErrors,
                          notes: _notes[item.question.id] ?? const [],
                        )
                      : FeedbackSnapshot.fromQuestion(
                          item: item,
                          selectedIndexes: _selectedIndexes,
                          pastErrors:
                              _start.session.mode == SessionMode.pastErrors,
                          notes: _notes[item.question.id] ?? const [],
                        ),
                  actions: FeedbackActions(
                    onDefine: _openLookup,
                    onOpenUrl: _openUrl,
                    onAsk: _openAsk,
                    onSaveNote: _addNote,
                    onNoteTap: _openNoteActions,
                  ),
                  controller: _wrongAnswerBullets,
                  notes: _notes[item.question.id] ?? const [],
                  checks:
                      _submitted &&
                          _outcome!.attempt.selectedIndexes.isNotEmpty &&
                          !_outcome!.attempt.isCorrect
                      ? _FeedbackCheckRow(
                          controlKey: const ValueKey('distracted-answer-check'),
                          value: _distracted,
                          title: 'I was distracted or read too fast',
                          supportingText:
                              'No error card; it does not count as skipped.',
                          onChanged: _submitting ? null : _setDistracted,
                        )
                      : null,
                  showLetters: _submitted || _showOriginalLetters,
                  onOptionTap: _submitted
                      ? null
                      : (index) => setState(() {
                          if (!item.question.allowsMultiple) {
                            _selectedIndexes
                              ..clear()
                              ..add(index);
                          } else if (!_selectedIndexes.remove(index)) {
                            _selectedIndexes.add(index);
                          }
                        }),
                ),
              ],
            ),
          ),
        ),
        bottomNavigationBar: AppActionDock(
          child: _submitted
              ? AppPrimaryButton(
                  onPressed: _submitting
                      ? null
                      : seesResults
                      ? _next
                      : atLast && unanswered > 0
                      ? _finishEarly
                      : _next,
                  label: seesResults
                      ? 'See results'
                      : atLast && unanswered > 0
                      ? 'Finish practice'
                      : 'Next question',
                  icon: seesResults
                      ? Icons.assessment_outlined
                      : atLast && unanswered > 0
                      ? Icons.flag_outlined
                      : Icons.arrow_forward,
                )
              : Row(
                  children: [
                    Expanded(
                      child: AppPrimaryButton(
                        onPressed: _submitting
                            ? null
                            : () => _submit(skip: false),
                        label: _submitting ? 'Checking…' : 'Check',
                        icon: Icons.check,
                      ),
                    ),
                    const SizedBox(width: 8),
                    M3EButton.text(
                      onPressed: _submitting ? null : () => _submit(skip: true),
                      child: const Text('Skip'),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _QuestionNavigator extends StatelessWidget {
  const _QuestionNavigator({
    required this.position,
    required this.total,
    required this.progress,
    required this.pastErrors,
    required this.done,
    required this.previousEnabled,
    required this.nextEnabled,
    required this.onPrevious,
    required this.onNext,
    required this.onOpenList,
  });

  final int position;
  final int total;
  final double progress;
  final bool pastErrors;
  final bool done;
  final bool previousEnabled;
  final bool nextEnabled;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onOpenList;

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    'Question $position of $total',
                    style: theme.typography.baseline.labelMedium.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (done)
                    const Pill(
                      'Done',
                      tone: PillTone.success,
                      icon: Icons.check,
                    ),
                  if (pastErrors) const Pill('Re-test', tone: PillTone.primary),
                ],
              ),
            ),
            M3EIconButton(
              variant: M3EIconButtonVariant.standard,
              icon: const Icon(Icons.format_list_numbered),
              tooltip: 'Question list',
              onPressed: onOpenList,
            ),
            M3EIconButton(
              variant: M3EIconButtonVariant.standard,
              icon: const Icon(Icons.chevron_left),
              tooltip: 'Previous question',
              onPressed: previousEnabled ? onPrevious : null,
            ),
            M3EIconButton(
              variant: M3EIconButtonVariant.standard,
              icon: const Icon(Icons.chevron_right),
              tooltip: 'Next question',
              onPressed: nextEnabled ? onNext : null,
            ),
          ],
        ),
        const SizedBox(height: 10),
        LinearScore(value: progress, semanticsLabel: 'Practice progress'),
      ],
    );
  }
}

class _QuestionPickerSheet extends StatelessWidget {
  const _QuestionPickerSheet({required this.start, required this.currentIndex});

  final SessionStart start;
  final int currentIndex;

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 10),
              child: Text(
                'Questions',
                style: theme.typography.emphasized.titleLarge,
              ),
            ),
            for (var index = 0; index < start.items.length; index++)
              _QuestionPickerRow(
                number: index + 1,
                item: start.items[index],
                done: start.isDone(start.items[index]),
                current: index == currentIndex,
                onTap: () => Navigator.of(context).pop(index),
              ),
          ],
        ),
      ),
    );
  }
}

class _QuestionPickerRow extends StatelessWidget {
  const _QuestionPickerRow({
    required this.number,
    required this.item,
    required this.done,
    required this.current,
    required this.onTap,
  });

  final int number;
  final SessionQuestionItem item;
  final bool done;
  final bool current;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    final question = item.question;
    return Material(
      color: current
          ? theme.colorScheme.secondaryContainer
          : Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              SizedBox(
                width: 28,
                child: Text(
                  '$number',
                  style: theme.typography.emphasized.labelLarge.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  question.prompt,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.typography.baseline.bodyMedium,
                ),
              ),
              if (done) ...[
                const SizedBox(width: 8),
                const Pill('Done', tone: PillTone.success, icon: Icons.check),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _NoteActionsSheet extends StatelessWidget {
  const _NoteActionsSheet({required this.phrase, required this.showAsk});

  final String phrase;
  final bool showAsk;

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    phrase,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: theme.typography.emphasized.titleLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Saved note',
                    style: theme.typography.baseline.labelSmall.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            OptionTile(
              icon: Icons.menu_book_outlined,
              title: 'Define',
              subtitle: 'Look up this phrase',
              onTap: () => Navigator.of(context).pop(_NoteAction.define),
            ),
            if (showAsk)
              OptionTile(
                icon: Icons.auto_awesome_outlined,
                title: 'Ask',
                subtitle: 'Ask the configured AI about this passage',
                onTap: () => Navigator.of(context).pop(_NoteAction.ask),
              ),
            OptionTile(
              icon: Icons.delete_outline,
              title: 'Delete note',
              subtitle: 'Remove it everywhere for this question',
              destructive: true,
              onTap: () => Navigator.of(context).pop(_NoteAction.delete),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeedbackCheckRow extends StatelessWidget {
  const _FeedbackCheckRow({
    required this.controlKey,
    required this.value,
    required this.title,
    required this.supportingText,
    required this.onChanged,
  });

  final Key controlKey;
  final bool value;
  final String title;
  final String supportingText;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    return TonalBox(
      color: theme.colorScheme.surfaceContainerLow,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          M3ECheckbox(
            key: controlKey,
            value: value,
            onChanged: onChanged == null
                ? null
                : (next) => onChanged!(next ?? false),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.typography.baseline.bodyMedium),
                  const SizedBox(height: 2),
                  Text(
                    supportingText,
                    style: theme.typography.baseline.labelSmall.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
