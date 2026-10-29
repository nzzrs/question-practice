import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/providers.dart';
import '../../core/domain/models.dart';
import '../../core/platform/practice_sound_player.dart';
import '../../core/ui/widgets.dart';
import '../lookup/lookup_actions.dart';
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
  bool _submitted = false;
  bool _submitting = false;
  bool _distracted = false;
  bool _reasoningOpen = false;
  AnswerOutcome? _outcome;
  SessionSummary? _summary;
  int _reminderMinutes = 0;
  bool _showReminder = false;
  Timer? _reminderTimer;
  Timer? _hideReminderTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _start = widget.start;
    _index = _start.items.isEmpty
        ? 0
        : _start.currentIndex.clamp(0, _start.items.length - 1).toInt();
    _item = _start.items.isEmpty ? null : _start.items[_index];
    _loadQuestionState();
    _startReminder();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_item == null) _finishExisting();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _reminderTimer?.cancel();
    _hideReminderTimer?.cancel();
    _reasoning.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startReminder();
    } else {
      _reminderTimer?.cancel();
      _hideReminderTimer?.cancel();
    }
  }

  void _startReminder() {
    _reminderTimer?.cancel();
    if (_start.session.status != SessionStatus.inProgress) return;
    _reminderTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      if (!mounted) return;
      setState(() {
        _reminderMinutes += 5;
        _showReminder = true;
      });
      _hideReminderTimer?.cancel();
      _hideReminderTimer = Timer(const Duration(seconds: 8), () {
        if (mounted) setState(() => _showReminder = false);
      });
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
    _reasoning.clear();
    _outcome = null;
    _submitted = false;
    _distracted = false;
    _reasoningOpen = false;
    if (item == null) return;
    final attempt = _start.attempts[item.question.id];
    if (attempt == null) return;
    _selectedIndexes.addAll(attempt.selectedIndexes);
    _reasoning.text = attempt.reasoning;
    _submitted = true;
    _distracted = attempt.distracted;
    _reasoningOpen = attempt.reasoning.trim().isNotEmpty;
    _outcome = AnswerOutcome(attempt: attempt, summary: _summary);
  }

  void _goTo(int index) {
    if (index < 0 || index >= _start.items.length || index == _index) return;
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
        _reasoningOpen = _reasoning.text.trim().isNotEmpty;
        if (outcome.summary != null) _summary = outcome.summary;
      });
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
    await ref
        .read(practiceSoundPlayerProvider)
        .play(attempt.isCorrect ? PracticeSound.correct : PracticeSound.wrong);
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

  void _next() {
    if (_summary != null && _index >= _start.items.length - 1) {
      _openSummary(_summary!);
      return;
    }
    if (_index + 1 < _start.items.length) {
      _goTo(_index + 1);
      return;
    }
    final unanswered = _start.items.indexWhere(
      (entry) => !_start.attempts.containsKey(entry.question.id),
    );
    if (unanswered >= 0) {
      _goTo(unanswered);
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
                if (_showReminder) ...[
                  const SizedBox(height: 14),
                  _ReminderBanner(minutes: _reminderMinutes),
                ],
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
                for (
                  var index = 0;
                  index < item.question.alternatives.length;
                  index++
                )
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _OptionCard(
                      index: index,
                      text: item.question.alternatives[index],
                      selected: _selectedIndexes.contains(index),
                      submitted: _submitted,
                      multiSelect: item.question.allowsMultiple,
                      isCorrect: item.question.correctIndexes.contains(index),
                      explanation:
                          item.question.alternativeExplanations.length > index
                          ? item.question.alternativeExplanations[index]
                          : '',
                      onDefine: _openLookup,
                      onOpenUrl: _openUrl,
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
                    controller: _reasoning,
                    onToggle: () =>
                        setState(() => _reasoningOpen = !_reasoningOpen),
                  )
                else if (_reasoning.text.trim().isNotEmpty)
                  TonalBox(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Your reasoning',
                          style: theme.typography.baseline.labelSmall.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _reasoning.text,
                          style: theme.typography.baseline.bodyMedium,
                        ),
                      ],
                    ),
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
                    _DistractedCheck(
                      value: _distracted,
                      onChanged: _submitting ? null : _setDistracted,
                    ),
                  ],
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

class _ReminderBanner extends StatelessWidget {
  const _ReminderBanner({required this.minutes});

  final int minutes;

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    return Semantics(
      liveRegion: true,
      child: TonalBox(
        color: theme.colorScheme.secondaryContainer,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Icon(
              Icons.schedule,
              size: 18,
              color: theme.colorScheme.onSecondaryContainer,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '$minutes minutes. Still with us? Take a breath.',
                style: theme.typography.baseline.bodySmall.copyWith(
                  color: theme.colorScheme.onSecondaryContainer,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReasoningSection extends StatelessWidget {
  const _ReasoningSection({
    required this.open,
    required this.controller,
    required this.onToggle,
  });

  final bool open;
  final TextEditingController controller;
  final VoidCallback onToggle;

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
                      'Add reasoning (optional)',
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
            placeholder: 'What led you to this answer?',
            minLines: 2,
            maxLines: 5,
            supportingText: 'Useful when reviewing an error later.',
          ),
        ],
      ],
    );
  }
}

class _DistractedCheck extends StatelessWidget {
  const _DistractedCheck({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    return TonalBox(
      color: theme.colorScheme.surfaceContainerLow,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          M3ECheckbox(
            value: value,
            onChanged: onChanged == null
                ? null
                : (next) => onChanged!(next ?? false),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              'I was distracted or read too fast',
              style: theme.typography.baseline.bodyMedium,
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
    final (color, icon, text) = switch ((
      pastErrors,
      attempt.isCorrect,
      skipped,
      distracted,
    )) {
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

class _OptionCard extends StatelessWidget {
  const _OptionCard({
    required this.index,
    required this.text,
    required this.selected,
    required this.submitted,
    required this.multiSelect,
    required this.isCorrect,
    required this.explanation,
    required this.onDefine,
    required this.onOpenUrl,
    required this.onPressed,
  });

  final int index;
  final String text;
  final bool selected;
  final bool submitted;
  final bool multiSelect;
  final bool isCorrect;
  final String explanation;
  final void Function(String selection, Rect? anchor) onDefine;
  final ValueChanged<String> onOpenUrl;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    final correctNow = submitted && isCorrect;
    final wrongNow = submitted && selected && !isCorrect;
    final background = correctNow
        ? AppSuccess.container(context)
        : wrongNow
        ? theme.colorScheme.errorContainer
        : selected
        ? theme.colorScheme.secondaryContainer
        : theme.colorScheme.surfaceContainerLow;
    final foreground = correctNow
        ? AppSuccess.onContainer(context)
        : wrongNow
        ? theme.colorScheme.onErrorContainer
        : selected
        ? theme.colorScheme.onSecondaryContainer
        : theme.colorScheme.onSurface;
    final badgeBackground = correctNow
        ? AppSuccess.foreground(context)
        : wrongNow
        ? theme.colorScheme.error
        : selected
        ? theme.colorScheme.secondary
        : theme.colorScheme.surfaceContainerHighest;
    final badgeForeground = correctNow
        ? theme.colorScheme.surface
        : wrongNow
        ? theme.colorScheme.onError
        : selected
        ? theme.colorScheme.onSecondary
        : theme.colorScheme.onSurfaceVariant;
    final letter = String.fromCharCode(65 + index);
    return Semantics(
      button: !submitted,
      selected: selected,
      label: 'Alternative $letter: $text',
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(22),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 30,
                  height: 30,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: badgeBackground,
                    borderRadius: BorderRadius.circular(multiSelect ? 9 : 15),
                  ),
                  child: correctNow
                      ? Icon(Icons.check, size: 18, color: badgeForeground)
                      : wrongNow
                      ? Icon(Icons.close, size: 18, color: badgeForeground)
                      : Text(
                          letter,
                          style: theme.typography.baseline.labelMedium.copyWith(
                            color: badgeForeground,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SelectableLinkifiedText(
                        text: text,
                        selectable: submitted,
                        style: theme.typography.baseline.bodyMedium.copyWith(
                          color: foreground,
                          height: 1.4,
                        ),
                        onDefine: onDefine,
                        onOpenUrl: onOpenUrl,
                      ),
                      if (submitted && explanation.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        SelectableLinkifiedText(
                          text: explanation,
                          style: theme.typography.baseline.bodySmall.copyWith(
                            color: foreground.withValues(alpha: 0.82),
                            height: 1.4,
                          ),
                          onDefine: onDefine,
                          onOpenUrl: onOpenUrl,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
