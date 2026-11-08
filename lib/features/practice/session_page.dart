import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/providers.dart';
import '../../core/domain/models.dart';
import '../../core/platform/practice_sound_player.dart';
import '../../core/ui/widgets.dart';
import '../lookup/lookup_actions.dart';
import '../lookup/ask_sheet.dart';
import '../practice/domain/session_service.dart';
import '../practice/selectable_linkified_text.dart';
import '../practice/summary_page.dart';

enum _ExitChoice { save, discard }

enum _FinishChoice { leaveUnanswered, markSkipped }

class SessionPage extends ConsumerStatefulWidget {
  const SessionPage({required this.start, super.key});

  final SessionStart start;

  @override
  ConsumerState<SessionPage> createState() => _SessionPageState();
}

class _SessionPageState extends ConsumerState<SessionPage>
    with WidgetsBindingObserver {
  final _reasoning = TextEditingController();
  late SessionStart _start;
  SessionQuestionItem? _item;
  int _index = 0;
  final _selectedIndexes = <int>{};
  final _highlights = <int, Set<String>>{};
  bool _submitted = false;
  bool _submitting = false;
  bool _distracted = false;
  bool _unknown = false;
  bool _reasoningOpen = false;
  bool _showOriginalLetters = false;
  AnswerOutcome? _outcome;
  SessionSummary? _summary;
  int _questionMinutes = 0;
  Timer? _questionTimer;
  Timer? _reasoningSaveTimer;
  Future<void>? _reasoningSaveFuture;
  String _savedReasoning = '';
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
    unawaited(_loadHighlights());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_item == null) _finishExisting();
    });
  }

  Future<void> _loadHighlights() async {
    try {
      final highlights = await ref
          .read(cardRepositoryProvider)
          .highlightsForSession(_start.session.id);
      if (!mounted) return;
      setState(() {
        _highlights.clear();
        for (final highlight in highlights) {
          final questionId = highlight.questionId;
          if (questionId == null) continue;
          (_highlights[questionId] ??= <String>{}).add(highlight.text);
        }
      });
    } on Object catch (error) {
      if (mounted) {
        await showSnack(context, 'Could not load highlights: $error');
      }
    }
  }

  Future<void> _addHighlight(String selection, Rect? anchor) async {
    final item = _item;
    if (item == null) return;
    final text = selection.trim();
    if (text.isEmpty) return;
    if (_highlights[item.question.id]?.contains(text) ?? false) {
      await showSnack(context, 'That phrase is already highlighted.');
      return;
    }
    try {
      await ref
          .read(cardRepositoryProvider)
          .createHighlight(
            sessionId: _start.session.id,
            questionId: item.question.id,
            text: text,
            context: item.question.prompt,
            topicName: item.topicName,
            practiceName: item.practiceName,
            createdAt: ref.read(clockProvider).now().toUtc(),
          );
      if (!mounted) return;
      setState(() {
        (_highlights[item.question.id] ??= <String>{}).add(text);
      });
      await showSnack(context, 'Highlight saved. It is ready in the review.');
    } on Object catch (error) {
      if (mounted) {
        await showSnack(context, 'Could not save the highlight: $error');
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _questionTimer?.cancel();
    _reasoningSaveTimer?.cancel();
    _toast?.dismiss();
    _reasoning.dispose();
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
    }
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
    _reasoningSaveTimer?.cancel();
    _reasoning.clear();
    _savedReasoning = '';
    _outcome = null;
    _submitted = false;
    _distracted = false;
    _unknown = false;
    _reasoningOpen = false;
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
    _reasoning.text = attempt.reasoning;
    _savedReasoning = attempt.reasoning.trim();
    _submitted = true;
    _distracted = attempt.distracted;
    _unknown = attempt.unknown;
    _reasoningOpen = attempt.reasoning.trim().isNotEmpty;
    _outcome = AnswerOutcome(attempt: attempt, summary: _summary);
    _restartQuestionTimer();
  }

  Future<void> _goTo(int index) async {
    if (index < 0 || index >= _start.items.length || index == _index) return;
    await _persistReasoning();
    if (!mounted) return;
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
            reasoning: _reasoning.text,
            distracted: false,
          );
      if (!mounted) return;
      setState(() {
        _submitted = true;
        _outcome = outcome;
        _savedReasoning = _reasoning.text.trim();
        _reasoningOpen = _reasoning.text.trim().isNotEmpty;
        if (outcome.summary != null) _summary = outcome.summary;
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

  void _onReasoningChanged(String _) {
    if (!_submitted) return;
    _reasoningSaveTimer?.cancel();
    _reasoningSaveTimer = Timer(const Duration(milliseconds: 600), () {
      if (mounted) unawaited(_persistReasoning());
    });
  }

  /// Saves the reasoning of an answered question, including late notes.
  Future<void> _persistReasoning() async {
    _reasoningSaveTimer?.cancel();
    while (mounted) {
      final inFlight = _reasoningSaveFuture;
      if (inFlight != null) {
        await inFlight;
        continue;
      }
      final item = _item;
      if (!_submitted || item == null) return;
      final text = _reasoning.text.trim();
      if (text == _savedReasoning) return;
      final save = _saveReasoning(item, text);
      _reasoningSaveFuture = save;
      var saved = false;
      try {
        saved = await save;
      } finally {
        if (identical(_reasoningSaveFuture, save)) {
          _reasoningSaveFuture = null;
        }
      }
      if (!saved) return;
    }
  }

  Future<bool> _saveReasoning(SessionQuestionItem item, String text) async {
    try {
      final attempt = await ref
          .read(sessionServiceProvider)
          .updateReasoning(start: _start, item: item, reasoning: text);
      if (!mounted) return false;
      _start.attempts[item.question.id] = attempt;
      setState(() {
        _savedReasoning = attempt.reasoning.trim();
        _outcome = AnswerOutcome(attempt: attempt, summary: _summary);
      });
      ref.invalidate(dueErrorsProvider);
      return true;
    } on SessionException catch (error) {
      if (mounted) await showSnack(context, error.message);
      return false;
    }
  }

  Future<void> _setDistracted(bool value) async {
    final item = _item;
    if (item == null || _submitting) return;
    setState(() => _submitting = true);
    try {
      final attempt = await ref
          .read(sessionServiceProvider)
          .setDistracted(start: _start, item: item, distracted: value);
      if (!mounted) return;
      _start.attempts[item.question.id] = attempt;
      setState(() {
        _distracted = attempt.distracted;
        _outcome = AnswerOutcome(attempt: attempt, summary: _summary);
      });
      ref.invalidate(dueErrorsProvider);
    } on SessionException catch (error) {
      if (mounted) await showSnack(context, error.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _setUnknown(bool value) async {
    final item = _item;
    if (item == null || _submitting) return;
    setState(() => _submitting = true);
    try {
      final attempt = await ref
          .read(sessionServiceProvider)
          .setUnknown(start: _start, item: item, unknown: value);
      if (!mounted) return;
      _start.attempts[item.question.id] = attempt;
      setState(() {
        _unknown = attempt.unknown;
        _distracted = attempt.distracted;
        _outcome = AnswerOutcome(attempt: attempt, summary: _summary);
      });
      ref.invalidate(dueErrorsProvider);
    } on SessionException catch (error) {
      if (mounted) await showSnack(context, error.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _next() async {
    await _persistReasoning();
    if (!mounted) return;
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
    _finishExisting();
  }

  Future<void> _finishEarly() async {
    if (_submitting) return;
    await _persistReasoning();
    if (!mounted) return;
    final unanswered = _start.items.length - _start.attempts.length;
    if (unanswered <= 0) {
      final summary =
          _summary ??
          await ref
              .read(sessionServiceProvider)
              .completeIfReady(_start.session.id);
      if (summary != null && mounted) await _openSummary(summary);
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
    await _persistReasoning();
    if (!mounted) return;
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
    final unanswered = total - answered;
    final progress = answered.clamp(0, total) / total;
    final atLast = _index >= total - 1;
    final seesResults = unanswered == 0 && _summary != null && atLast;
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
                  previousEnabled: _index > 0 && !_submitting,
                  nextEnabled: _index < total - 1 && !_submitting,
                  onPrevious: () => _goTo(_index - 1),
                  onNext: () => _goTo(_index + 1),
                ),
                const SizedBox(height: 22),
                if (item.topicName.isNotEmpty)
                  Text(
                    item.topicName.toUpperCase(),
                    style: theme.typography.baseline.labelSmall.copyWith(
                      color: theme.colorScheme.primary,
                      letterSpacing: 0.8,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                const SizedBox(height: 6),
                SelectableLinkifiedText(
                  text: item.question.prompt,
                  style: theme.typography.baseline.headlineSmall.copyWith(
                    height: 1.3,
                  ),
                  onDefine: _openLookup,
                  onOpenUrl: _openUrl,
                  onHighlight: _addHighlight,
                  onAsk: _openAsk,
                  highlights:
                      _highlights[item.question.id]?.toList() ?? const [],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.text_fields,
                      size: 14,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        item.question.allowsMultiple
                            ? 'Select every correct alternative. Select text to define a term.'
                            : 'Select text to define a term.',
                        style: theme.typography.baseline.labelSmall.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                for (final index in item.displayOrder)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _OptionCard(
                      key: ValueKey(
                        'alternative-card-${item.question.id}-$index',
                      ),
                      originalIndex: index,
                      text: item.question.alternatives[index],
                      selected: _selectedIndexes.contains(index),
                      submitted: _submitted,
                      isCorrect: item.question.correctIndexes.contains(index),
                      multiSelect: item.question.allowsMultiple,
                      showLetter: _submitted || _showOriginalLetters,
                      explanation:
                          item.question.alternativeExplanations.length > index
                          ? item.question.alternativeExplanations[index]
                          : '',
                      onDefine: _openLookup,
                      onOpenUrl: _openUrl,
                      onHighlight: _addHighlight,
                      onAsk: _openAsk,
                      highlights:
                          _highlights[item.question.id]?.toList() ?? const [],
                      onPressed: _submitted
                          ? null
                          : () => setState(() {
                              if (!item.question.allowsMultiple) {
                                _selectedIndexes
                                  ..clear()
                                  ..add(index);
                              } else if (!_selectedIndexes.remove(index)) {
                                _selectedIndexes.add(index);
                              }
                            }),
                    ),
                  ),
                const SizedBox(height: 6),
                if (!_submitted)
                  _ReasoningSection(
                    open: _reasoningOpen,
                    title: 'Add reasoning (optional)',
                    supportingText: 'Useful when reviewing an error later.',
                    placeholder: 'What led you to this answer?',
                    controller: _reasoning,
                    onToggle: () =>
                        setState(() => _reasoningOpen = !_reasoningOpen),
                  ),
                if (_submitted) ...[
                  const SizedBox(height: 16),
                  _FeedbackStatus(
                    outcome: _outcome!,
                    distracted: _distracted,
                    pastErrors: _start.session.mode == SessionMode.pastErrors,
                  ),
                  const SizedBox(height: 12),
                  TonalBox(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Why this answer',
                          style: theme.typography.emphasized.titleSmall,
                        ),
                        const SizedBox(height: 6),
                        SelectableLinkifiedText(
                          text: item.question.explanation,
                          style: theme.typography.baseline.bodyMedium.copyWith(
                            height: 1.45,
                          ),
                          onDefine: _openLookup,
                          onOpenUrl: _openUrl,
                        ),
                      ],
                    ),
                  ),
                  if (_outcome!.attempt.selectedIndexes.isNotEmpty &&
                      !_outcome!.attempt.isCorrect) ...[
                    const SizedBox(height: 10),
                    _FeedbackChecks(
                      distracted: _distracted,
                      unknown: _unknown,
                      onDistractedChanged: _submitting ? null : _setDistracted,
                      onUnknownChanged: _submitting ? null : _setUnknown,
                    ),
                  ],
                  const SizedBox(height: 12),
                  _ReasoningSection(
                    open: _reasoningOpen,
                    title: 'Your reasoning (optional)',
                    supportingText: _savedReasoning.isEmpty
                        ? 'You can still note what led to your answer.'
                        : 'Saved automatically.',
                    placeholder: 'What led you to this answer?',
                    controller: _reasoning,
                    onChanged: _onReasoningChanged,
                    onToggle: () =>
                        setState(() => _reasoningOpen = !_reasoningOpen),
                  ),
                ],
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
    required this.previousEnabled,
    required this.nextEnabled,
    required this.onPrevious,
    required this.onNext,
  });

  final int position;
  final int total;
  final double progress;
  final bool pastErrors;
  final bool previousEnabled;
  final bool nextEnabled;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    return Column(
      children: [
        Row(
          children: [
            Text(
              'Question $position of $total',
              style: theme.typography.baseline.labelMedium.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (pastErrors) ...[
              const SizedBox(width: 8),
              const Pill('Re-test', tone: PillTone.primary),
            ],
            const Spacer(),
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

class _ReasoningSection extends StatelessWidget {
  const _ReasoningSection({
    required this.open,
    required this.title,
    required this.supportingText,
    required this.placeholder,
    required this.controller,
    required this.onToggle,
    this.onChanged,
  });

  final bool open;
  final String title;
  final String supportingText;
  final String placeholder;
  final TextEditingController controller;
  final VoidCallback onToggle;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Material(
          color: theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(20),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Icon(
                    Icons.edit_note,
                    size: 20,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: theme.typography.baseline.bodyMedium,
                    ),
                  ),
                  Icon(
                    open ? Icons.expand_less : Icons.expand_more,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
        ),
        if (open) ...[
          const SizedBox(height: 10),
          M3ETextField(
            controller: controller,
            label: 'Your reasoning',
            placeholder: placeholder,
            minLines: 2,
            maxLines: 5,
            supportingText: supportingText,
            onChanged: onChanged,
          ),
        ],
      ],
    );
  }
}

class _FeedbackChecks extends StatelessWidget {
  const _FeedbackChecks({
    required this.distracted,
    required this.unknown,
    required this.onDistractedChanged,
    required this.onUnknownChanged,
  });

  final bool distracted;
  final bool unknown;
  final ValueChanged<bool>? onDistractedChanged;
  final ValueChanged<bool>? onUnknownChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _FeedbackCheckRow(
          controlKey: const ValueKey('distracted-answer-check'),
          value: distracted,
          title: 'I was distracted or read too fast',
          supportingText: 'No error card; it does not count as skipped.',
          onChanged: onDistractedChanged,
        ),
        const SizedBox(height: 8),
        _FeedbackCheckRow(
          controlKey: const ValueKey('unknown-answer-check'),
          value: unknown,
          title: "I didn't know this",
          supportingText: 'No error card; counts as skipped and the review asks for the concept.',
          onChanged: onUnknownChanged,
        ),
      ],
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

class _FeedbackStatus extends StatelessWidget {
  const _FeedbackStatus({
    required this.outcome,
    required this.distracted,
    required this.pastErrors,
  });

  final AnswerOutcome outcome;
  final bool distracted;
  final bool pastErrors;

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    final attempt = outcome.attempt;
    final skipped = attempt.isSkipped;
    final (color, icon, text) = attempt.unknown
        ? (
            theme.colorScheme.secondaryContainer,
            Icons.help_outline,
            "You didn't know this. No error card was created; the review asks "
                'which concept was missing.',
          )
        : switch ((pastErrors, attempt.isCorrect, skipped, distracted)) {
            (true, true, _, _) => (
              AppSuccess.container(context),
              Icons.check_circle_outline,
              'Error resolved. It stays in your history.',
            ),
            (true, false, _, true) => (
              theme.colorScheme.secondaryContainer,
              Icons.pause_circle_outline,
              'Not counted because you were distracted. The card stays due.',
            ),
            (true, false, _, false) => (
              theme.colorScheme.errorContainer,
              Icons.schedule,
              'Still in the error queue. Next attempt in 48 hours.',
            ),
            (false, true, _, _) => (
              AppSuccess.container(context),
              Icons.check_circle_outline,
              'Correct.',
            ),
            (false, false, true, _) => (
              theme.colorScheme.secondaryContainer,
              Icons.skip_next_outlined,
              'Skipped. No error card is created; the review asks what was missing.',
            ),
            (false, false, false, true) => (
              theme.colorScheme.secondaryContainer,
              Icons.pause_circle_outline,
              'Marked as distracted. No error card was created.',
            ),
            _ => (
              theme.colorScheme.errorContainer,
              Icons.error_outline,
              'Not quite. The error card will ask what went wrong.',
            ),
          };
    return TonalBox(
      color: color,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: theme.typography.baseline.bodySmall.copyWith(height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}

class _OptionCard extends StatefulWidget {
  const _OptionCard({
    required this.originalIndex,
    required this.text,
    required this.selected,
    required this.submitted,
    required this.isCorrect,
    required this.multiSelect,
    required this.showLetter,
    required this.explanation,
    required this.onDefine,
    required this.onOpenUrl,
    required this.onHighlight,
    required this.onAsk,
    required this.highlights,
    required this.onPressed,
    super.key,
  });

  final int originalIndex;
  final String text;
  final bool selected;
  final bool submitted;
  final bool isCorrect;
  final bool multiSelect;
  final bool showLetter;
  final String explanation;
  final void Function(String selection, Rect? anchor) onDefine;
  final ValueChanged<String> onOpenUrl;
  final Future<void> Function(String selection, Rect? anchor) onHighlight;
  final Future<void> Function(String selection, Rect? anchor) onAsk;
  final List<String> highlights;
  final VoidCallback? onPressed;

  @override
  State<_OptionCard> createState() => _OptionCardState();
}

class _OptionCardState extends State<_OptionCard> {
  late bool _explanationOpen;
  int? _pointer;
  Duration? _pointerDownAt;
  Offset? _pointerDownPosition;

  bool get _shouldOpenExplanation =>
      widget.submitted && (widget.isCorrect || widget.selected);

  @override
  void initState() {
    super.initState();
    _explanationOpen = _shouldOpenExplanation;
  }

  void _handlePointerDown(PointerDownEvent event) {
    if (_pointer != null) return;
    _pointer = event.pointer;
    _pointerDownAt = event.timeStamp;
    _pointerDownPosition = event.position;
  }

  void _handlePointerUp(PointerUpEvent event) {
    if (event.pointer != _pointer) return;
    final elapsed = _pointerDownAt == null
        ? Duration.zero
        : event.timeStamp - _pointerDownAt!;
    final distance = _pointerDownPosition == null
        ? 0.0
        : (event.position - _pointerDownPosition!).distance;
    _pointer = null;
    _pointerDownAt = null;
    _pointerDownPosition = null;
    if (widget.submitted) return;
    final isTap = elapsed < const Duration(milliseconds: 500) && distance < 12;
    if (isTap) widget.onPressed?.call();
  }

  void _handlePointerCancel(PointerCancelEvent event) {
    if (event.pointer != _pointer) return;
    _pointer = null;
    _pointerDownAt = null;
    _pointerDownPosition = null;
  }

  @override
  void didUpdateWidget(_OptionCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text ||
        oldWidget.originalIndex != widget.originalIndex ||
        (!oldWidget.submitted && widget.submitted)) {
      _explanationOpen = _shouldOpenExplanation;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    final correctNow = widget.submitted && widget.isCorrect;
    final wrongNow = widget.submitted && widget.selected && !widget.isCorrect;
    final background = correctNow
        ? AppSuccess.container(context)
        : wrongNow
        ? theme.colorScheme.errorContainer
        : widget.selected
        ? theme.colorScheme.secondaryContainer
        : theme.colorScheme.surfaceContainerLow;
    final foreground = correctNow
        ? AppSuccess.onContainer(context)
        : wrongNow
        ? theme.colorScheme.onErrorContainer
        : widget.selected
        ? theme.colorScheme.onSecondaryContainer
        : theme.colorScheme.onSurface;
    final badgeBackground = correctNow
        ? AppSuccess.foreground(context)
        : wrongNow
        ? theme.colorScheme.error
        : widget.selected
        ? theme.colorScheme.secondary
        : theme.colorScheme.surfaceContainerHighest;
    final badgeForeground = correctNow
        ? theme.colorScheme.surface
        : wrongNow
        ? theme.colorScheme.onError
        : widget.selected
        ? theme.colorScheme.onSecondary
        : theme.colorScheme.onSurfaceVariant;
    final letter = String.fromCharCode(65 + widget.originalIndex);
    return Semantics(
      button: !widget.submitted,
      selected: widget.selected,
      label: widget.showLetter
          ? 'Alternative $letter: ${widget.text}'
          : 'Alternative: ${widget.text}',
      child: Listener(
        onPointerDown: _handlePointerDown,
        onPointerUp: _handlePointerUp,
        onPointerCancel: _handlePointerCancel,
        child: Material(
          color: background,
          borderRadius: BorderRadius.circular(22),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            // Text selection owns touches inside the card. Tapping is resolved
            // from the pointer stream so selecting text and choosing an
            // alternative can both work before an answer is submitted.
            onTap: widget.submitted ? null : () {},
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    key: ValueKey(
                      'alternative-letter-badge-${widget.originalIndex}',
                    ),
                    width: 30,
                    height: 30,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: badgeBackground,
                      shape: widget.multiSelect
                          ? BoxShape.rectangle
                          : BoxShape.circle,
                      borderRadius: widget.multiSelect
                          ? BorderRadius.circular(8)
                          : null,
                    ),
                    child: widget.showLetter
                        ? Text(
                            letter,
                            style: theme.typography.baseline.labelMedium
                                .copyWith(
                                  color: badgeForeground,
                                  fontWeight: FontWeight.w700,
                                ),
                          )
                        : correctNow
                        ? Icon(Icons.check, size: 18, color: badgeForeground)
                        : wrongNow
                        ? Icon(Icons.close, size: 18, color: badgeForeground)
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SelectableLinkifiedText(
                          key: ValueKey(
                            'alternative-${widget.originalIndex}-text',
                          ),
                          text: widget.text,
                          style: theme.typography.baseline.bodyMedium.copyWith(
                            color: foreground,
                            height: 1.4,
                          ),
                          onDefine: widget.onDefine,
                          onOpenUrl: widget.onOpenUrl,
                          onHighlight: widget.onHighlight,
                          onAsk: widget.onAsk,
                          highlights: widget.highlights,
                        ),
                        if (widget.submitted &&
                            widget.explanation.isNotEmpty &&
                            _explanationOpen) ...[
                          const SizedBox(height: 6),
                          SelectableLinkifiedText(
                            text: widget.explanation,
                            style: theme.typography.baseline.bodySmall.copyWith(
                              color: foreground.withValues(alpha: 0.82),
                              height: 1.4,
                            ),
                            onDefine: widget.onDefine,
                            onOpenUrl: widget.onOpenUrl,
                            onHighlight: widget.onHighlight,
                            onAsk: widget.onAsk,
                            highlights: widget.highlights,
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (widget.submitted && widget.explanation.isNotEmpty) ...[
                    const SizedBox(width: 4),
                    Semantics(
                      button: true,
                      label: _explanationOpen
                          ? 'Hide explanation'
                          : 'Show explanation',
                      child: InkResponse(
                        key: ValueKey(
                          'alternative-explanation-'
                          '${widget.originalIndex}-toggle',
                        ),
                        onTap: () => setState(
                          () => _explanationOpen = !_explanationOpen,
                        ),
                        radius: 18,
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Icon(
                            _explanationOpen
                                ? Icons.expand_less
                                : Icons.expand_more,
                            size: 20,
                            color: foreground.withValues(alpha: 0.82),
                          ),
                        ),
                      ),
                    ),
                  ],
                  if (correctNow || wrongNow) ...[
                    const SizedBox(width: 8),
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Icon(
                        correctNow ? Icons.check : Icons.close,
                        size: 20,
                        color: foreground,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
