import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/providers.dart';
import '../../core/domain/models.dart';
import '../../core/platform/web_launcher.dart';
import '../../core/ui/widgets.dart';
import '../lookup/lookup_sheet.dart';
import '../practice/domain/session_service.dart';
import '../practice/selectable_linkified_text.dart';
import '../practice/summary_page.dart';

enum _ExitChoice { save, discard }

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
    if (item == null) return;
    final attempt = _start.attempts[item.question.id];
    if (attempt == null) return;
    _selectedIndexes.addAll(attempt.selectedIndexes);
    _reasoning.text = attempt.reasoning;
    _submitted = true;
    _distracted = attempt.distracted;
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
        if (outcome.summary != null) _summary = outcome.summary;
      });
    } on SessionException catch (error) {
      if (mounted) await showSnack(context, error.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
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
    final settings = ref.read(settingsProvider).value ?? const AppSettings();
    if (settings.lookupMode == LookupMode.ai) {
      await showAiDefinitionBubble(
        context,
        term: term,
        question: _item?.question.prompt ?? '',
        topicName: _item?.topicName ?? '',
        practiceName: _item?.practiceName ?? '',
        sessionId: _start.session.id,
        questionId: _item?.question.id,
        anchor: anchor,
        onSearchWeb: () => _openWebLookup(term),
      );
      return;
    }
    await _openWebLookup(term);
  }

  Future<void> _openWebLookup(String term) async {
    final item = _item;
    if (item == null) return;
    await M3EBottomSheet.show<void>(
      context,
      initialValue: M3EBottomSheetValue.expanded,
      builder: (context) => LookupSheet(
        term: term,
        question: item.question.prompt,
        topicName: item.topicName,
        practiceName: item.practiceName,
        sessionId: _start.session.id,
        questionId: item.question.id,
      ),
    );
  }

  Future<void> _openUrl(String value) async {
    final uri = Uri.tryParse(value);
    if (uri == null) return;
    try {
      await ref.read(webLauncherProvider).open(uri);
    } on WebLaunchException {
      if (mounted) await showSnack(context, 'Could not open that link.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = _item;
    if (item == null) {
      return const AppScaffold(
        title: 'Practice',
        showBack: true,
        body: Center(child: M3ELoadingIndicator()),
      );
    }
    final theme = M3ETheme.of(context);
    final total = _start.items.length;
    final position = _index + 1;
    final answered = _start.attempts.length;
    final progress = answered.clamp(0, total) / total;
    final atLast = _index >= total - 1;
    final seesResults = _summary != null && atLast;
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
      child: AppScaffold(
        title: modeTitle.isEmpty ? 'Practice' : modeTitle,
        showBack: false,
        actions: [
          M3EIconButton(
            variant: M3EIconButtonVariant.standard,
            icon: const Icon(Icons.close),
            tooltip: 'Leave practice',
            onPressed: _requestExit,
          ),
        ],
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
          children: [
            Row(
              children: [
                Text(
                  'Question $position of $total',
                  style: theme.typography.baseline.labelMedium.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const Spacer(),
                if (_start.session.mode == SessionMode.pastErrors) ...[
                  Text(
                    'Re-test',
                    style: theme.typography.baseline.labelMedium.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 4),
                ],
                M3EIconButton(
                  variant: M3EIconButtonVariant.standard,
                  icon: const Icon(Icons.chevron_left),
                  tooltip: 'Previous question',
                  onPressed: _index > 0 && !_submitting
                      ? () => _goTo(_index - 1)
                      : null,
                ),
                M3EIconButton(
                  variant: M3EIconButtonVariant.standard,
                  icon: const Icon(Icons.chevron_right),
                  tooltip: 'Next question',
                  onPressed: _index < total - 1 && !_submitting
                      ? () => _goTo(_index + 1)
                      : null,
                ),
              ],
            ),
            const SizedBox(height: 8),
            LinearScore(value: progress),
            if (_showReminder) ...[
              const SizedBox(height: 16),
              _ReminderBanner(minutes: _reminderMinutes),
            ],
            const SizedBox(height: 24),
            if (item.topicName.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  item.topicName,
                  style: theme.typography.baseline.labelSmall.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            SelectableLinkifiedText(
              text: item.question.prompt,
              style: theme.typography.baseline.headlineSmall.copyWith(
                height: 1.35,
              ),
              onDefine: _openLookup,
              onOpenUrl: _openUrl,
            ),
            const SizedBox(height: 6),
            Text(
              item.question.allowsMultiple
                  ? 'Select every correct alternative. Select text to define a term.'
                  : 'Select text to define a term.',
              style: theme.typography.baseline.labelSmall.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
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
            const SizedBox(height: 12),
            M3ETextField(
              controller: _reasoning,
              label: 'Your reasoning',
              placeholder: 'Optional. What led you to this answer?',
              minLines: 3,
              maxLines: 6,
              readOnly: _submitted,
              supportingText: _submitted
                  ? 'Reasoning locked after submitting.'
                  : 'Optional, but useful when reviewing an error.',
            ),
            if (!_submitted) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  M3EButton.filled(
                    onPressed: _submitting ? null : () => _submit(skip: false),
                    icon: const Icon(Icons.check),
                    label: Text(_submitting ? 'Checking…' : 'Check'),
                  ),
                  const SizedBox(width: 8),
                  M3EButton.text(
                    onPressed: _submitting ? null : () => _submit(skip: true),
                    child: const Text('Skip'),
                  ),
                ],
              ),
            ] else ...[
              const SizedBox(height: 16),
              _FeedbackStatus(
                outcome: _outcome!,
                distracted: _distracted,
                pastErrors: _start.session.mode == SessionMode.pastErrors,
              ),
              const SizedBox(height: 16),
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
              const SizedBox(height: 16),
              M3EButton.filled(
                onPressed: _next,
                icon: Icon(
                  seesResults ? Icons.assessment_outlined : Icons.arrow_forward,
                ),
                label: Text(seesResults ? 'See results' : 'Next question'),
              ),
            ],
          ],
        ),
      ),
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
        theme.colorScheme.primaryContainer,
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
        theme.colorScheme.primaryContainer,
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
        ? theme.colorScheme.primaryContainer
        : wrongNow
        ? theme.colorScheme.errorContainer
        : selected
        ? theme.colorScheme.secondaryContainer
        : theme.colorScheme.surfaceContainerLow;
    final foreground = correctNow
        ? theme.colorScheme.onPrimaryContainer
        : wrongNow
        ? theme.colorScheme.onErrorContainer
        : selected
        ? theme.colorScheme.onSecondaryContainer
        : theme.colorScheme.onSurface;
    return Semantics(
      button: !submitted,
      selected: selected,
      label: 'Alternative ${String.fromCharCode(65 + index)}: $text',
      child: Container(
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(18),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    correctNow
                        ? Icons.check_circle
                        : wrongNow
                        ? Icons.cancel
                        : selected
                        ? multiSelect
                              ? Icons.check_box
                              : Icons.radio_button_checked
                        : multiSelect
                        ? Icons.check_box_outline_blank
                        : Icons.radio_button_off,
                    size: 20,
                    color: foreground,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SelectableLinkifiedText(
                          text: text,
                          selectable: submitted,
                          style: theme.typography.baseline.bodyMedium.copyWith(
                            color: foreground,
                            height: 1.35,
                          ),
                          onDefine: onDefine,
                          onOpenUrl: onOpenUrl,
                        ),
                        if (submitted && explanation.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          SelectableLinkifiedText(
                            text: explanation,
                            style: theme.typography.baseline.bodySmall.copyWith(
                              color: foreground.withValues(alpha: 0.85),
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
      ),
    );
  }
}
