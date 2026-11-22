import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/providers.dart';
import '../../core/domain/models.dart';
import '../../core/domain/reading_time.dart';
import '../../core/ui/widgets.dart';
import '../lookup/domain/lookup_service.dart';
import '../review/domain/card_litmus.dart';
import '../review/domain/review_service.dart';
import 'card_creator_controller.dart';
import 'domain/anki_note_builder.dart';
import 'domain/card_templates.dart';

/// Lets a review host save the creator's drafts from its own action.
///
/// Pass it to [CardCreatorBody] or [CardCreatorPane] together with
/// `showSaveButton: false`; the creator then renders no competing save action.
class CardCreatorSaveHandle {
  Future<int> Function()? _handler;

  /// Whether a mounted creator is attached and can save.
  bool get isAttached => _handler != null;

  /// Saves the current drafts and returns how many cards were created.
  Future<int> save() async => await _handler?.call() ?? 0;

  void _attach(Future<int> Function() handler) {
    _handler = handler;
  }

  void _detach(Future<int> Function() handler) {
    if (_handler == handler) _handler = null;
  }
}

/// The error being turned into cards, with any learner edits already applied.
class CardCreatorErrorSource {
  const CardCreatorErrorSource({
    required this.card,
    required this.question,
    required this.wrongAnswer,
    required this.correctAnswer,
    this.reasoning = '',
    this.explanation = '',
    this.wrongAnswerBullets = const [],
  });

  final ErrorCard card;
  final String question;
  final String wrongAnswer;
  final String correctAnswer;
  final String reasoning;
  final String explanation;

  /// The learner's read-only bullets, sent separately to the AI breakdown.
  final List<String> wrongAnswerBullets;
}

/// Everything one card-creation flow needs from its review surface.
class CardCreatorRequest {
  const CardCreatorRequest({
    required this.title,
    this.sessionId,
    this.questionId,
    this.questionContext = '',
    this.topicName = '',
    this.subtopic = '',
    this.initialTemplate,
    this.initialFront = '',
    this.initialBack = '',
    this.initialTerm = '',
    this.initialDefinition = '',
    this.existingFronts = const [],
    this.note,
    this.error,
    this.skippedQuestionId,
    this.completeErrorOnSave = true,
    this.itemKey,
  });

  final String title;
  final int? sessionId;
  final int? questionId;
  final String questionContext;
  final String topicName;
  final String subtopic;

  /// The template selected when the creator opens, when the caller knows it.
  final CardTemplate? initialTemplate;
  final String initialFront;
  final String initialBack;
  final String initialTerm;
  final String initialDefinition;

  /// Fronts or terms known for this review context.
  ///
  /// AI suggestions that repeat any of them are dropped. The creator also
  /// reads saved cards and adds its own drafts before asking the AI.
  final List<String> existingFronts;

  /// Note context: enables AI suggestions and marks the note converted on save.
  final Note? note;

  /// Error context: enables AI breakdown and completes details on save.
  final CardCreatorErrorSource? error;

  /// Skipped queue record to mark handled once a card is saved.
  final int? skippedQuestionId;

  /// Whether the error's details step is completed after a card is saved.
  final bool completeErrorOnSave;

  /// Page-scoped cache key. Review hosts set it so the creator can keep a
  /// snapshot per reviewed item while its sheet is closed.
  final String? itemKey;
}

/// Opens the shared card creator in a bottom sheet and returns the number of
/// cards saved.
///
/// The sheet starts at [M3EBottomSheetValue.collapsed], so the error, note or
/// skipped question it was opened from stays readable above it. Dragging the
/// handle up gives the creator more room.
Future<int> showCardCreator(
  BuildContext context, {
  required CardCreatorRequest request,
}) async {
  final created = await M3EBottomSheet.show<int>(
    context,
    initialValue: M3EBottomSheetValue.collapsed,
    builder: (context) => CardCreatorSheet(request: request),
  );
  return created ?? 0;
}

/// Opens the creator for a review step and keeps its state on [controller].
///
/// The sheet has no save action; the review dock owns the single Save. The
/// repeated source recap stays out because the review already shows it.
Future<int> showReviewCardCreator(
  BuildContext context, {
  required CardCreatorRequest request,
  required CardCreatorController controller,
}) async {
  final created = await M3EBottomSheet.show<int>(
    context,
    initialValue: M3EBottomSheetValue.collapsed,
    builder: (context) => CardCreatorSheet(
      request: request,
      controller: controller,
      showContextRecap: false,
      showSeedSource: false,
      showSaveButton: false,
    ),
  );
  return created ?? 0;
}

/// One creator for manual cards and optional AI suggestions.
///
/// Lives inside an [M3EBottomSheet], so the review surface behind it keeps the
/// mistake visible while cards are written. Manual entry never needs an AI
/// provider. Cards are collected as drafts and saved together, so the learner
/// can add several ideas little by little.
class CardCreatorSheet extends StatelessWidget {
  const CardCreatorSheet({
    required this.request,
    this.controller,
    this.showContextRecap = true,
    this.showSeedSource = true,
    this.showSaveButton = true,
    super.key,
  });

  final CardCreatorRequest request;
  final CardCreatorController? controller;

  /// Whether the sheet repeats the reviewed question, error or note.
  final bool showContextRecap;

  /// Whether a bullet or note seed repeats its own source line and quote.
  final bool showSeedSource;

  /// Whether the sheet renders its own Save action.
  ///
  /// Review hosts pass false because the review dock owns the single Save.
  final bool showSaveButton;

  @override
  Widget build(BuildContext context) {
    return CardCreatorBody(
      request: request,
      controller: controller,
      showContextRecap: showContextRecap,
      showSeedSource: showSeedSource,
      showSaveButton: showSaveButton,
      onClose: () => Navigator.of(context).pop(0),
      onSaved: (count) => Navigator.of(context).pop(count),
    );
  }
}

/// An embedded creator with no modal, close button or context recap.
///
/// The pane owns its scroll position and its sticky save footer. The body never
/// renders a second save action, and [onDraftCountChanged] lets the review page
/// guard navigation while drafts are unsaved.
class CardCreatorPane extends StatefulWidget {
  const CardCreatorPane({
    required this.request,
    required this.controller,
    this.onSaved,
    this.onDraftCountChanged,
    this.saveHandle,
    this.showSaveButton = true,
    super.key,
  });

  final CardCreatorRequest request;
  final CardCreatorController controller;
  final ValueChanged<int>? onSaved;
  final ValueChanged<int>? onDraftCountChanged;

  /// Lets the host save drafts when [showSaveButton] is false.
  final CardCreatorSaveHandle? saveHandle;

  /// Whether the pane renders its sticky save footer.
  final bool showSaveButton;

  @override
  State<CardCreatorPane> createState() => _CardCreatorPaneState();
}

class _CardCreatorPaneState extends State<CardCreatorPane> {
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    return Semantics(
      container: true,
      label: 'Create cards',
      child: ColoredBox(
        color: theme.colorScheme.surfaceContainerLow,
        child: CardCreatorBody(
          request: widget.request,
          embedded: true,
          controller: widget.controller,
          scrollController: _scroll,
          scrollStorageKey: PageStorageKey<String>(
            'creator-scroll-${widget.request.questionId ?? widget.request.title}',
          ),
          onSaved: widget.onSaved,
          onDraftCountChanged: widget.onDraftCountChanged,
          saveHandle: widget.saveHandle,
          showSaveButton: widget.showSaveButton,
        ),
      ),
    );
  }
}

/// The reusable creator UI shared by the sheet and the embedded pane.
class CardCreatorBody extends ConsumerStatefulWidget {
  const CardCreatorBody({
    required this.request,
    this.onSaved,
    this.onClose,
    this.embedded = false,
    this.controller,
    this.onDraftCountChanged,
    this.scrollController,
    this.scrollStorageKey,
    this.saveHandle,
    this.showSaveButton = true,
    this.showContextRecap = true,
    this.showSeedSource = true,
    super.key,
  });

  final CardCreatorRequest request;
  final ValueChanged<int>? onSaved;
  final VoidCallback? onClose;
  final bool embedded;

  /// Whether the creator renders its own save action.
  ///
  /// The sheet keeps it in the scroll; the embedded pane moves it to a sticky
  /// footer so it is always reachable. Set false and pass [saveHandle] when a
  /// review host owns the single save action.
  final bool showSaveButton;

  /// Lets the host save drafts from its own action.
  final CardCreatorSaveHandle? saveHandle;

  /// Whether the creator opens with the reviewed question, error or note.
  ///
  /// Review hosts pass false because the reading surface behind the sheet
  /// already shows that source.
  final bool showContextRecap;

  /// Whether a bullet or note seed shows its own source label and quote.
  ///
  /// Review hosts pass false when the review already shows the source.
  final bool showSeedSource;

  /// The page's seed bridge, used by the embedded pane only.
  final CardCreatorController? controller;

  /// Reports how many drafts are waiting to be saved.
  final ValueChanged<int>? onDraftCountChanged;

  /// Lets the host own the creator scroll position.
  final ScrollController? scrollController;

  /// Keeps the creator scroll position per reviewed card.
  final PageStorageKey<String>? scrollStorageKey;

  @override
  ConsumerState<CardCreatorBody> createState() => _CardCreatorBodyState();
}

class _SuggestedIdea {
  _SuggestedIdea(SuggestedCardIdea idea)
    : template = idea.template,
      variants = [
        for (final variant in idea.variants)
          _AiVariant(
            template: idea.template,
            front: variant.front,
            back: variant.back,
            selected: variant.variantIndex == 0,
          ),
      ];

  final CardTemplate template;
  final List<_AiVariant> variants;

  int get variantCount => variants.length;

  void dispose() {
    for (final variant in variants) {
      variant.dispose();
    }
  }
}

class _AiVariant {
  _AiVariant({
    required this.template,
    required String front,
    required String back,
    required this.selected,
  }) : front = TextEditingController(text: front),
       back = TextEditingController(text: back);

  final CardTemplate template;
  final TextEditingController front;
  final TextEditingController back;
  bool selected;

  bool get isComplete =>
      front.text.trim().isNotEmpty && back.text.trim().isNotEmpty;

  LitmusReport get report =>
      checkCardLitmus(front: front.text, back: back.text, template: template);

  bool get waiting => front.text.trim().isEmpty && back.text.trim().isEmpty;

  CardCreatorDraft toDraft() {
    if (template == CardTemplate.definition) {
      return CardCreatorConceptDraft(
        term: front.text.trim(),
        definition: back.text.trim(),
        extra: '',
        source: ConceptSource.ai,
      );
    }
    return CardCreatorBasicDraft(
      front: front.text.trim(),
      back: back.text.trim(),
      template: template,
    );
  }

  void dispose() {
    front.dispose();
    back.dispose();
  }
}

/// The outcome of saving a creator draft list.
class CardCreatorSaveResult {
  const CardCreatorSaveResult({
    required this.created,
    required this.remaining,
    this.failure,
    this.completionPending = false,
  });

  final int created;
  final List<CardCreatorDraft> remaining;
  final Object? failure;

  /// Whether writing cards worked but marking the item complete did not.
  ///
  /// Review hosts keep the item open and retry with [saveCardCreatorDrafts]
  /// and `retryCompletion: true` so saved cards are never created twice.
  final bool completionPending;

  bool get succeeded => failure == null;
  bool get hasRemaining => remaining.isNotEmpty;
}

/// The snack shown after [saveCardCreatorDrafts] reports a failure.
String cardCreatorSaveFailureMessage(CardCreatorSaveResult result) {
  final failure = result.failure;
  if (result.completionPending && !result.hasRemaining) {
    return result.created > 0
        ? '${result.created} card${result.created == 1 ? '' : 's'} saved, '
              'but this item could not be completed: $failure'
        : 'The cards are saved, but this item could not be completed: '
              '$failure';
  }
  return result.created > 0
      ? '${result.created} card${result.created == 1 ? '' : 's'} saved, '
            'but the rest could not be saved: $failure'
      : 'Could not create the cards: $failure';
}

/// Saves [drafts] with the same rules as the creator's own save action.
///
/// Review docks call this after the sheet has closed, so a review host can own
/// the only Save action while every draft still reaches the database.
///
/// Set [retryCompletion] after a previous call created cards but could not
/// mark the note converted or complete the error details. No draft is created
/// again; only the missing completion is retried.
Future<CardCreatorSaveResult> saveCardCreatorDrafts({
  required CardCreatorRequest request,
  required Iterable<CardCreatorDraft> drafts,
  required ReviewService service,
  int? noteToConvertId,
  bool retryCompletion = false,
}) async {
  final pending = retryCompletion
      ? const <CardCreatorDraft>[]
      : List<CardCreatorDraft>.of(drafts);
  final remaining = retryCompletion
      ? const <CardCreatorDraft>[]
      : List<CardCreatorDraft>.of(pending);
  var created = 0;
  int? manualCardId;
  Object? failure;
  var completionPending = false;
  for (final draft in pending) {
    try {
      switch (draft) {
        case CardCreatorBasicDraft():
          final id = await service.createBasicCard(
            sessionId: request.sessionId,
            questionId: request.questionId,
            question: draft.front,
            answer: draft.back,
            context: request.questionContext,
            topicName: request.topicName,
            subtopic: request.subtopic,
            cognitiveType: draft.template.cognitiveType,
            skippedQuestionId: request.skippedQuestionId,
          );
          manualCardId ??= id;
        case CardCreatorConceptDraft():
          await service.createConcept(
            sessionId: request.sessionId,
            questionId: request.questionId,
            term: draft.term,
            definition: draft.definition,
            extra: draft.extra,
            context: request.questionContext,
            topicName: request.topicName,
            subtopic: request.subtopic,
            source: draft.source,
            skippedQuestionId: request.skippedQuestionId,
          );
      }
      created++;
      remaining.remove(draft);
    } on Object catch (error) {
      failure = error;
      break;
    }
  }

  if (created > 0 || retryCompletion) {
    try {
      final noteIds = <int>{
        if (request.note != null) request.note!.id,
        if (noteToConvertId != null) noteToConvertId,
      };
      for (final noteId in noteIds) {
        await service.markNoteConverted(noteId, manualCardId: manualCardId);
      }
      final error = request.error;
      if (error != null && request.completeErrorOnSave) {
        await service.completeErrorDetails(error.card.id);
      }
    } on Object catch (error) {
      failure ??= error;
      completionPending = true;
    }
  }

  return CardCreatorSaveResult(
    created: created,
    remaining: remaining,
    failure: failure,
    completionPending: completionPending,
  );
}

class _CardCreatorBodyState extends ConsumerState<CardCreatorBody> {
  late final TextEditingController _front;
  late final TextEditingController _back;
  late final TextEditingController _definitionCloze;
  late final Future<int> Function() _saveHandler = _save;

  late CardTemplate? _template;
  String _appliedScaffoldFront = '';
  String _appliedScaffoldBack = '';
  String _appliedDefinitionCloze = '';

  final _drafts = <CardCreatorDraft>[];
  List<String> _savedCardTexts = const [];
  List<_SuggestedIdea>? _ideas;
  final _retiredIdeas = <_SuggestedIdea>[];
  final _retiredVariants = <_AiVariant>[];
  String? _aiError;
  bool _aiLoading = false;
  bool _aiPanelOpen = false;
  bool _aiUnavailable = false;
  bool _saving = false;

  int _appliedSeedRevision = -1;
  String? _seedBulletId;
  Note? _seedNote;
  Note? _noteToConvert;
  String _seedInitialFront = '';
  String _seedInitialBack = '';
  String _seedInitialCloze = '';
  SuggestedCard? _seedSuggestion;
  bool _seedTouched = false;
  bool _seedLoading = false;
  bool _applyingSeed = false;
  bool _seedHint = false;
  String? _seedError;
  int _seedRequest = 0;
  int _reportedDraftCount = 0;
  bool _composerDirty = false;

  @override
  void initState() {
    super.initState();
    widget.controller?.addListener(_onControllerChanged);
    widget.saveHandle?._attach(_saveHandler);
    ref.listenManual(
      existingCardTextsProvider,
      (_, next) => _savedCardTexts = next,
      fireImmediately: true,
    );
    final request = widget.request;
    _front = TextEditingController(text: request.initialFront);
    _back = TextEditingController(text: request.initialBack);
    _definitionCloze = TextEditingController();
    _template = _initialTemplate();
    if (_template == CardTemplate.definition) {
      _definitionCloze.text = _initialDefinitionCloze();
      _appliedDefinitionCloze = _definitionCloze.text;
    }
    _restoreSnapshot();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _reportDraftCount(force: true);
      _onControllerChanged();
    });
  }

  String? get _snapshotKey => widget.request.itemKey;

  void _restoreSnapshot() {
    final key = _snapshotKey;
    if (key == null) return;
    final snapshot = widget.controller?.snapshotFor(key);
    if (snapshot == null) return;
    _front.text = snapshot.front;
    _back.text = snapshot.back;
    _definitionCloze.text = snapshot.definitionCloze;
    _template = snapshot.template;
    _appliedScaffoldFront = snapshot.appliedScaffoldFront;
    _appliedScaffoldBack = snapshot.appliedScaffoldBack;
    _appliedDefinitionCloze = snapshot.appliedDefinitionCloze;
    _drafts
      ..clear()
      ..addAll(snapshot.drafts);
    _aiError = snapshot.aiError;
    _aiPanelOpen = snapshot.aiPanelOpen;
    _aiUnavailable = snapshot.aiUnavailable;
    _appliedSeedRevision = snapshot.appliedSeedRevision;
    _seedBulletId = snapshot.seedBulletId;
    _seedNote = snapshot.seedNote;
    _noteToConvert = snapshot.noteToConvert;
    _seedInitialFront = snapshot.seedInitialFront;
    _seedInitialBack = snapshot.seedInitialBack;
    _seedInitialCloze = snapshot.seedInitialCloze;
    _seedSuggestion = snapshot.seedSuggestion;
    _seedTouched = snapshot.seedTouched;
    _seedHint = snapshot.seedHint;
    _seedError = snapshot.seedError;
    _composerDirty = snapshot.composerDirty;
    final ideas = snapshot.ideas;
    if (ideas == null) {
      _ideas = null;
    } else {
      _ideas = [
        for (final idea in ideas)
          _SuggestedIdea(
            SuggestedCardIdea(
              template: idea.template,
              variants: [
                for (var index = 0; index < idea.variants.length; index++)
                  SuggestedCard(
                    front: idea.variants[index].front,
                    back: idea.variants[index].back,
                    template: idea.template,
                    variantIndex: index,
                  ),
              ],
            ),
          ),
      ];
      for (var ideaIndex = 0; ideaIndex < ideas.length; ideaIndex++) {
        final variants = _ideas![ideaIndex].variants;
        final saved = ideas[ideaIndex].variants;
        for (var index = 0; index < variants.length; index++) {
          if (index < saved.length) {
            variants[index].selected = saved[index].selected;
          }
        }
      }
    }
    widget.controller?.markDraftsAdded(
      snapshot.drafts.map((draft) => draft.sourceBulletId),
    );
  }

  CardCreatorSnapshot _buildSnapshot() {
    return CardCreatorSnapshot(
      front: _front.text,
      back: _back.text,
      definitionCloze: _definitionCloze.text,
      template: _template,
      appliedScaffoldFront: _appliedScaffoldFront,
      appliedScaffoldBack: _appliedScaffoldBack,
      appliedDefinitionCloze: _appliedDefinitionCloze,
      drafts: List<CardCreatorDraft>.unmodifiable(_drafts),
      ideas: _ideas == null
          ? null
          : [
              for (final idea in _ideas!)
                CardCreatorAiIdeaData(
                  template: idea.template,
                  variants: [
                    for (final variant in idea.variants)
                      CardCreatorAiVariantData(
                        front: variant.front.text,
                        back: variant.back.text,
                        selected: variant.selected,
                      ),
                  ],
                ),
            ],
      aiError: _aiError,
      aiPanelOpen: _aiPanelOpen && !_aiLoading,
      aiUnavailable: _aiUnavailable,
      appliedSeedRevision: _appliedSeedRevision,
      seedBulletId: _seedBulletId,
      seedNote: _seedNote,
      noteToConvert: _noteToConvert,
      seedInitialFront: _seedInitialFront,
      seedInitialBack: _seedInitialBack,
      seedInitialCloze: _seedInitialCloze,
      seedSuggestion: _seedSuggestion,
      seedTouched: _seedTouched,
      seedHint: _seedHint,
      seedError: _seedError,
      composerDirty: _composerDirty,
      canAddDraft: _canAdd,
      composerHasText:
          _front.text.trim().isNotEmpty ||
          _back.text.trim().isNotEmpty ||
          (_composerDirty && _definitionCloze.text.trim().isNotEmpty),
    );
  }

  void _storeSnapshot() {
    final key = _snapshotKey;
    final controller = widget.controller;
    if (key == null || controller == null || _saving) return;
    controller.storeSnapshot(key, _buildSnapshot());
  }

  @override
  void didUpdateWidget(covariant CardCreatorBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.saveHandle != widget.saveHandle) {
      oldWidget.saveHandle?._detach(_saveHandler);
      widget.saveHandle?._attach(_saveHandler);
    }
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?.removeListener(_onControllerChanged);
      widget.controller?.addListener(_onControllerChanged);
      _appliedSeedRevision = -1;
      _onControllerChanged();
    }
  }

  void _onControllerChanged() {
    final controller = widget.controller;
    if (!mounted || controller == null) return;
    if (controller.seedRevision != _appliedSeedRevision) {
      _applySeed();
    }
  }

  void _reportDraftCount({bool force = false}) {
    final count = _drafts.length;
    if (!force && count == _reportedDraftCount) return;
    _reportedDraftCount = count;
    final report = widget.onDraftCountChanged;
    if (report == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) report(count);
    });
  }

  Future<void> _applySeed() async {
    final controller = widget.controller;
    if (controller == null) return;
    final seed = controller.seed;
    if (seed == null) {
      _appliedSeedRevision = controller.seedRevision;
      return;
    }
    if (controller.seedRevision == _appliedSeedRevision) return;
    _appliedSeedRevision = controller.seedRevision;
    final requestId = ++_seedRequest;

    _applyingSeed = true;
    setState(() {
      _seedSuggestion = null;
      _seedTouched = false;
      _seedLoading = false;
      _seedHint = false;
      _seedError = null;
      _composerDirty = false;
      switch (seed) {
        case BulletCardSeed(:final bulletId, :final bullet):
          _seedBulletId = bulletId;
          _seedNote = null;
          _noteToConvert = null;
          _template = null;
          _front.text = bullet;
          _back.clear();
          _appliedScaffoldFront = '';
          _appliedScaffoldBack = '';
          _seedInitialFront = bullet;
          _seedInitialBack = '';
          _seedInitialCloze = _definitionCloze.text;
        case NoteCardSeed(:final note):
          _seedBulletId = null;
          _seedNote = note;
          _noteToConvert = note;
          _template = CardTemplate.definition;
          _definitionCloze.text = seedDefinitionCloze(source: note.text);
          _appliedDefinitionCloze = _definitionCloze.text;
          _front.clear();
          _back.clear();
          _appliedScaffoldFront = '';
          _appliedScaffoldBack = '';
          _seedInitialFront = note.text;
          _seedInitialBack = '';
          _seedInitialCloze = _definitionCloze.text;
      }
    });
    _applyingSeed = false;
    _seedScrollToTop();
    await _runSeedRequest(seed, requestId);
  }

  void _applySuggestion(SuggestedCard suggestion) {
    _composerDirty = true;
    _seedTouched = true;
    widget.controller?.markSeedDirty();
    _template = suggestion.template;
    if (suggestion.template == CardTemplate.definition) {
      _definitionCloze.text = seedDefinitionCloze(
        term: suggestion.front,
        definition: suggestion.back,
      );
      _appliedDefinitionCloze = _definitionCloze.text;
    } else {
      _front.text = suggestion.front;
      _back.text = suggestion.back;
    }
  }

  void _seedScrollToTop() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final scroll = widget.scrollController;
      if (!mounted || scroll == null || !scroll.hasClients) return;
      scroll.jumpTo(0);
    });
  }

  Future<bool> _hasApiKey() async {
    try {
      return await ref.read(hasApiKeyProvider.future);
    } on Object {
      return false;
    }
  }

  Future<void> _runSeedRequest(CardCreatorSeed seed, int requestId) async {
    final hasKey = await _hasApiKey();
    if (!mounted || requestId != _seedRequest) return;
    if (!hasKey) {
      setState(() {
        _seedHint = true;
        _seedLoading = false;
      });
      widget.controller?.markSeedSettled();
      return;
    }
    setState(() => _seedLoading = true);
    final lookup = ref.read(lookupServiceProvider);
    final request = widget.request;
    try {
      switch (seed) {
        case BulletCardSeed(:final bullet):
          final error = request.error;
          final draft = await lookup.suggestCardFromWrongNote(
            note: bullet,
            question: error?.question ?? request.questionContext,
            wrongAnswer: error?.wrongAnswer ?? '',
            correctAnswer: error?.correctAnswer ?? '',
            explanation: error?.explanation ?? '',
            topicName: request.topicName,
            subtopic: request.subtopic,
            otherNotes: error?.wrongAnswerBullets ?? const [],
          );
          if (!mounted || requestId != _seedRequest) return;
          final suggestion = draft != null && !_repeatsKnownCard(draft.front)
              ? draft
              : null;
          setState(() {
            _seedLoading = false;
            if (suggestion == null) {
              _seedError = draft == null
                  ? 'The AI found nothing to draft. Write the card yourself.'
                  : 'The AI repeated a card you already have. Write a '
                        'different card yourself.';
            } else if (_seedTouched ||
                _front.text.trim() != _seedInitialFront.trim() ||
                _back.text.trim().isNotEmpty) {
              _seedSuggestion = suggestion;
            } else {
              _applySuggestion(suggestion);
              _seedInitialFront = suggestion.front;
              _seedInitialBack = suggestion.back;
              _seedInitialCloze = _definitionCloze.text;
            }
          });
        case NoteCardSeed(:final note):
          final ideas = await lookup.suggestArchetypeCards(
            note: note.text,
            questionContext: request.questionContext,
            topicName: request.topicName,
            subtopic: request.subtopic,
          );
          if (!mounted || requestId != _seedRequest) return;
          final filtered = filterDuplicateIdeas(
            ideas,
            existingTexts: _knownCardTexts,
          );
          setState(() {
            _seedLoading = false;
            _retiredIdeas.addAll(_ideas ?? const []);
            _ideas = [for (final idea in filtered) _SuggestedIdea(idea)];
            if (filtered.isEmpty) {
              _seedError = ideas.isEmpty
                  ? 'The AI found nothing to draft. Write the card yourself.'
                  : 'The AI only repeated cards you already have. Write a '
                        'different card yourself.';
            }
          });
      }
      widget.controller?.markSeedSettled();
    } on LookupException catch (error) {
      if (!mounted || requestId != _seedRequest) return;
      setState(() {
        _seedLoading = false;
        _seedError = error.message;
      });
      widget.controller?.markSeedSettled();
    } on Object catch (error) {
      if (!mounted || requestId != _seedRequest) return;
      setState(() {
        _seedLoading = false;
        _seedError = 'Could not draft a card: $error';
      });
      widget.controller?.markSeedSettled();
    }
  }

  CardTemplate? _initialTemplate() {
    final request = widget.request;
    if (request.initialTemplate != null) return request.initialTemplate;
    if (request.initialTerm.trim().isNotEmpty) return CardTemplate.definition;
    if (request.error != null) return CardTemplate.contrast;
    if (request.initialFront.trim().isNotEmpty ||
        request.initialBack.trim().isNotEmpty) {
      return null;
    }
    return CardTemplate.contrast;
  }

  @override
  void dispose() {
    widget.controller?.removeListener(_onControllerChanged);
    widget.saveHandle?._detach(_saveHandler);
    _storeSnapshot();
    final controller = widget.controller;
    if (controller != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        controller.markSeedSettled();
      });
    }
    _front.dispose();
    _back.dispose();
    _definitionCloze.dispose();
    for (final idea in _ideas ?? const <_SuggestedIdea>[]) {
      idea.dispose();
    }
    for (final idea in _retiredIdeas) {
      idea.dispose();
    }
    for (final variant in _retiredVariants) {
      variant.dispose();
    }
    super.dispose();
  }

  CardTemplate get _effectiveTemplate => _template ?? CardTemplate.mechanism;

  bool get _hasAiContext =>
      widget.request.note != null || widget.request.error != null;

  ParsedDefinitionCloze get _parsedDefinition =>
      parseDefinitionCloze(_definitionCloze.text);

  String _initialDefinitionCloze() {
    final request = widget.request;
    if (request.initialTerm.trim().isNotEmpty ||
        request.initialDefinition.trim().isNotEmpty) {
      return seedDefinitionCloze(
        term: request.initialTerm,
        definition: request.initialDefinition,
      );
    }
    final note = request.note;
    if (note != null) return seedDefinitionCloze(source: note.text);
    if (request.initialFront.trim().isNotEmpty) {
      return seedDefinitionCloze(source: request.initialFront);
    }
    return seedDefinitionCloze();
  }

  bool get _canAdd {
    if (_saving) return false;
    if (_template == CardTemplate.definition) {
      return _parsedDefinition.isComplete;
    }
    return _front.text.trim().isNotEmpty && _back.text.trim().isNotEmpty;
  }

  bool get _waitingForText {
    if (_template != CardTemplate.definition) {
      return _front.text.trim().isEmpty && _back.text.trim().isEmpty;
    }
    final parsed = _parsedDefinition;
    return parsed.term.isEmpty && parsed.definition.isEmpty;
  }

  LitmusReport get _currentReport {
    final parsed = _parsedDefinition;
    return checkCardLitmus(
      front: _template == CardTemplate.definition ? parsed.term : _front.text,
      back: _template == CardTemplate.definition
          ? parsed.definition
          : _back.text,
      template: _effectiveTemplate,
    );
  }

  String get _readingText => _template == CardTemplate.definition
      ? _parsedDefinition.term
      : _front.text;

  void _selectTemplate(CardTemplate template) {
    if (_saving) return;
    setState(() {
      _template = template;
      if (template == CardTemplate.definition) {
        if (_definitionCloze.text.trim().isEmpty ||
            (_appliedDefinitionCloze.isNotEmpty &&
                _definitionCloze.text == _appliedDefinitionCloze)) {
          _definitionCloze.text = _initialDefinitionCloze();
          _appliedDefinitionCloze = _definitionCloze.text;
          _placeCursorInCloze(_definitionCloze);
        }
        return;
      }

      final scaffold = fillScaffold(
        template,
        wrongAnswer: widget.request.error?.wrongAnswer ?? '',
        correctAnswer: widget.request.error?.correctAnswer ?? '',
      );
      if (scaffold == null) return;
      final frontEmpty = _front.text.trim().isEmpty;
      final frontGenerated =
          _appliedScaffoldFront.isNotEmpty &&
          _front.text == _appliedScaffoldFront;
      if (frontEmpty || frontGenerated) {
        _front.text = scaffold.front;
        _appliedScaffoldFront = scaffold.front;
        _placeCursorAtPlaceholder(_front);
      }
      final backEmpty = _back.text.trim().isEmpty;
      final backGenerated =
          _appliedScaffoldBack.isNotEmpty && _back.text == _appliedScaffoldBack;
      if (backEmpty || backGenerated) {
        _back.text = scaffold.back;
        _appliedScaffoldBack = scaffold.back;
      }
    });
  }

  void _placeCursorAtPlaceholder(TextEditingController controller) {
    final index = controller.text.indexOf('[');
    if (index < 0) return;
    controller.selection = TextSelection.collapsed(offset: index);
  }

  void _placeCursorInCloze(TextEditingController controller) {
    final start = controller.text.indexOf('{{c1::');
    if (start < 0) return;
    final contentStart = start + '{{c1::'.length;
    final contentEnd = controller.text.indexOf('}}', contentStart);
    if (contentEnd < contentStart) return;
    controller.selection = TextSelection(
      baseOffset: contentStart,
      extentOffset: contentEnd,
    );
  }

  void _markSeedEdited() {
    if (_applyingSeed) return;
    if (_seedBulletId == null && _seedNote == null) return;
    final changed =
        _front.text != _seedInitialFront ||
        _back.text != _seedInitialBack ||
        (_seedNote != null && _definitionCloze.text != _seedInitialCloze);
    if (!changed) return;
    _seedTouched = true;
    widget.controller?.markSeedDirty();
  }

  void _onDefinitionChanged(String value) {
    setState(() {
      _composerDirty = true;
      _markSeedEdited();
    });
  }

  void _onFrontBackChanged(String value) {
    setState(() {
      _composerDirty = true;
      _markSeedEdited();
    });
  }

  void _addDraft() {
    if (!_canAdd || _saving) return;
    final bulletId = _seedBulletId;
    if (_template == CardTemplate.definition) {
      final parsed = _parsedDefinition;
      if (!parsed.isComplete) return;
      setState(() {
        _drafts.add(
          CardCreatorConceptDraft(
            term: parsed.term,
            definition: parsed.definition,
            extra: '',
            source: ConceptSource.manual,
            sourceBulletId: bulletId,
          ),
        );
        _definitionCloze.text = seedDefinitionCloze();
        _appliedDefinitionCloze = _definitionCloze.text;
        _placeCursorInCloze(_definitionCloze);
        _composerDirty = false;
        _clearSeedComposer();
      });
      _afterDraftAdded(bulletId);
      return;
    }
    final template = _template ?? CardTemplate.mechanism;
    setState(() {
      _drafts.add(
        CardCreatorBasicDraft(
          front: _front.text.trim(),
          back: _back.text.trim(),
          template: template,
          sourceBulletId: bulletId,
        ),
      );
      _front.clear();
      _back.clear();
      _appliedScaffoldFront = '';
      _appliedScaffoldBack = '';
      _composerDirty = false;
      _clearSeedComposer();
    });
    _afterDraftAdded(bulletId);
  }

  void _afterDraftAdded(String? bulletId) {
    _reportDraftCount();
    if (bulletId == null) return;
    widget.controller?.markDraftAdded(bulletId);
    widget.controller?.markSeedSettled();
  }

  void _clearSeedComposer() {
    // Ignore an AI reply that arrives after the composer was added or reset.
    _seedRequest++;
    _seedBulletId = null;
    _seedNote = null;
    _seedSuggestion = null;
    _seedTouched = false;
    _seedHint = false;
    _seedError = null;
    _seedLoading = false;
    _seedInitialFront = '';
    _seedInitialBack = '';
    _seedInitialCloze = '';
  }

  void _removeDraft(int index) {
    if (_saving || index < 0 || index >= _drafts.length) return;
    final removed = _drafts[index];
    setState(() => _drafts.removeAt(index));
    _reportDraftCount();
    final bulletId = removed.sourceBulletId;
    if (bulletId != null) {
      final stillPresent = _drafts.any(
        (draft) => draft.sourceBulletId == bulletId,
      );
      if (!stillPresent) widget.controller?.markDraftRemoved(bulletId);
    }
  }

  void _toggleAiPanel() {
    if (_saving) return;
    final open = !_aiPanelOpen;
    setState(() => _aiPanelOpen = open);
    if (!open || _aiLoading || _ideas != null || _aiError != null) return;
    _loadAiSuggestions();
  }

  /// Card fronts and terms the AI must not repeat.
  List<String> get _knownCardTexts => [
    ...widget.request.existingFronts,
    ..._savedCardTexts,
    if (widget.request.initialFront.trim().isNotEmpty)
      widget.request.initialFront,
    if (widget.request.initialTerm.trim().isNotEmpty)
      widget.request.initialTerm,
    for (final draft in _drafts)
      switch (draft) {
        CardCreatorBasicDraft(:final front) => front,
        CardCreatorConceptDraft(:final term) => term,
      },
  ];

  bool _repeatsKnownCard(String front) {
    return _knownCardTexts.any((known) => isDuplicateCardText(front, known));
  }

  Future<void> _loadAiSuggestions() async {
    if (_aiLoading || _saving) return;
    setState(() {
      _aiLoading = true;
      _aiError = null;
      _aiUnavailable = false;
      _retiredIdeas.addAll(_ideas ?? const []);
      _ideas = null;
    });
    final hasKey = await _hasApiKey();
    if (!mounted) return;
    if (!hasKey) {
      setState(() {
        _aiLoading = false;
        _aiUnavailable = true;
      });
      return;
    }
    try {
      final lookup = ref.read(lookupServiceProvider);
      final List<SuggestedCardIdea> ideas;
      final error = widget.request.error;
      final note = widget.request.note;
      if (error != null) {
        ideas = await lookup.breakdownErrorCard(
          question: error.question,
          wrongAnswer: error.wrongAnswer,
          correctAnswer: error.correctAnswer,
          reasoning: error.reasoning,
          explanation: error.explanation,
          topicName: widget.request.topicName,
          subtopic: widget.request.subtopic,
          mistakeKinds: error.card.mistakeKinds,
          wrongAnswerBullets: error.wrongAnswerBullets,
        );
      } else if (note != null) {
        ideas = await lookup.suggestArchetypeCards(
          note: note.text,
          questionContext: widget.request.questionContext,
          topicName: widget.request.topicName,
          subtopic: widget.request.subtopic,
        );
      } else {
        ideas = const [];
      }
      if (!mounted) return;
      final filtered = filterDuplicateIdeas(
        ideas,
        existingTexts: _knownCardTexts,
      );
      setState(() {
        _ideas = [for (final idea in filtered) _SuggestedIdea(idea)];
        _aiLoading = false;
      });
    } on LookupException catch (error) {
      if (!mounted) return;
      setState(() {
        _aiError = error.message;
        _aiLoading = false;
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _aiError = 'Could not suggest cards: $error';
        _aiLoading = false;
      });
    }
  }

  bool get _hasCompleteSelectedVariant {
    final ideas = _ideas;
    if (ideas == null) return false;
    return ideas.any(
      (idea) => idea.variants.any(
        (variant) => variant.selected && variant.isComplete,
      ),
    );
  }

  void _addSelectedSuggestions() {
    final ideas = _ideas;
    if (ideas == null || _saving) return;
    final accepted = <_AiVariant>[];
    final remainingIdeas = <_SuggestedIdea>[];
    setState(() {
      for (final idea in ideas) {
        idea.variants.removeWhere((variant) {
          if (!variant.selected || !variant.isComplete) return false;
          _drafts.add(variant.toDraft());
          accepted.add(variant);
          return true;
        });
        if (idea.variants.isEmpty) {
          _retiredIdeas.add(idea);
        } else {
          remainingIdeas.add(idea);
        }
      }
      _ideas = remainingIdeas;
      _retiredVariants.addAll(accepted);
    });
    _reportDraftCount();
  }

  Future<int> _save() async {
    if (_drafts.isEmpty || _saving) return 0;
    setState(() => _saving = true);
    final service = ref.read(reviewServiceProvider);
    final request = widget.request;
    final result = await saveCardCreatorDrafts(
      request: request,
      drafts: _drafts,
      service: service,
      noteToConvertId: _noteToConvert?.id,
    );

    if (!mounted) return result.created;
    setState(() {
      _saving = false;
      _drafts
        ..clear()
        ..addAll(result.remaining);
      if (result.created > 0) {
        _clearSeedComposer();
        _noteToConvert = null;
        _composerDirty = false;
      }
    });
    _reportDraftCount();
    if (result.failure != null) {
      await showSnack(context, cardCreatorSaveFailureMessage(result));
      return result.created;
    }
    widget.onSaved?.call(result.created);
    return result.created;
  }

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    final request = widget.request;
    final count = _drafts.length;
    final hasContext =
        request.error != null ||
        request.note != null ||
        request.skippedQuestionId != null ||
        request.questionContext.trim().isNotEmpty ||
        request.topicName.trim().isNotEmpty ||
        request.subtopic.trim().isNotEmpty;
    final wide = MediaQuery.sizeOf(context).width >= 600;

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.embedded)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Semantics(
              header: true,
              child: Text(
                'Create cards',
                style: theme.typography.emphasized.titleLarge,
              ),
            ),
          )
        else
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    request.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.typography.emphasized.titleLarge,
                  ),
                ),
              ),
              if (widget.onClose != null)
                M3EIconButton(
                  key: const ValueKey('creator-close'),
                  variant: M3EIconButtonVariant.standard,
                  icon: const Icon(Icons.close),
                  tooltip: 'Close',
                  onPressed: _saving ? null : widget.onClose,
                ),
            ],
          ),
        if (!widget.embedded) const SizedBox(height: 8),
        if (!widget.embedded && widget.showContextRecap && hasContext) ...[
          _CreatorContextRecap(request: request),
          const SizedBox(height: 20),
        ],
        if (_hasSeedComposer) _buildSeedComposer(theme),
        _buildTemplateSection(theme),
        const SizedBox(height: 16),
        if (_template == CardTemplate.definition)
          _buildDefinitionFields(theme)
        else
          _buildBasicFields(theme),
        const SizedBox(height: 16),
        _LitmusRow(
          report: _currentReport,
          waiting: _waitingForText,
          readingTime: readingTimeLabel(_readingText),
          badgeKey: const ValueKey('creator-litmus-current'),
          detailKey: const ValueKey('creator-litmus-detail-current'),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: M3EButton.tonal(
            key: const ValueKey('creator-add'),
            onPressed: _canAdd ? _addDraft : null,
            icon: const Icon(Icons.add_card),
            label: const Text('Add to list'),
          ),
        ),
        if (_hasAiContext && _aiPanelOpen) ...[
          const SizedBox(height: 16),
          _buildAiPanel(theme),
        ],
        if (count > 0) ...[
          const SizedBox(height: 20),
          SectionTitle('Cards to save', count: count),
          AppGroup(
            semanticsLabel: 'Cards waiting to be saved',
            children: [
              for (var index = 0; index < count; index++)
                _DraftRow(
                  key: ValueKey('creator-draft-$index'),
                  draft: _drafts[index],
                  onRemove: _saving ? null : () => _removeDraft(index),
                ),
            ],
          ),
        ],
        if (widget.showSaveButton && !widget.embedded) ...[
          const SizedBox(height: 20),
          _saveButton(count),
          const SizedBox(height: 8),
        ] else
          const SizedBox(height: 12),
      ],
    );

    final scroll = SingleChildScrollView(
      key: widget.scrollStorageKey ?? const ValueKey('creator-scroll'),
      controller: widget.scrollController,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.manual,
      padding: EdgeInsets.fromLTRB(
        wide ? 24 : 16,
        0,
        wide ? 24 : 16,
        wide ? 20 : 16,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: content,
        ),
      ),
    );

    if (widget.embedded) {
      return LayoutBuilder(
        builder: (context, constraints) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: scroll),
              if (widget.showSaveButton)
                _buildStickyFooter(
                  theme,
                  count,
                  showEmptyHint: constraints.maxHeight >= 320,
                  compact: constraints.maxHeight < 220,
                ),
            ],
          );
        },
      );
    }

    return AnimatedPadding(
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: scroll,
    );
  }

  Widget _saveButton(int count) {
    return AppPrimaryButton(
      key: const ValueKey('creator-save'),
      onPressed: count == 0 || _saving ? null : _save,
      label: _saving ? 'Saving…' : 'Save',
      icon: Icons.check,
    );
  }

  Widget _buildStickyFooter(
    M3EThemeData theme,
    int count, {
    required bool showEmptyHint,
    required bool compact,
  }) {
    return Material(
      color: theme.colorScheme.surfaceContainerLow,
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.55),
            ),
          ),
        ),
        padding: EdgeInsets.fromLTRB(
          16,
          compact ? 4 : 10,
          16,
          compact ? 4 : 10,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (count == 0 && showEmptyHint)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  'Nothing to save yet.',
                  textAlign: TextAlign.center,
                  style: theme.typography.baseline.labelSmall.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            _saveButton(count),
          ],
        ),
      ),
    );
  }

  bool get _hasSeedComposer =>
      _seedBulletId != null ||
      _seedNote != null ||
      _seedLoading ||
      _seedHint ||
      _seedError != null ||
      _seedSuggestion != null;

  Widget _buildSeedComposer(M3EThemeData theme) {
    final seed = widget.controller?.seed;
    final sourceText = switch (seed) {
      BulletCardSeed(:final bullet) => bullet,
      NoteCardSeed(:final note) => note.text,
      null => _seedInitialFront,
    };
    final fromBullet = _seedBulletId != null || seed is BulletCardSeed;
    final suggestion = _seedSuggestion;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TonalBox(
        key: const ValueKey('creator-seed-composer'),
        color: theme.colorScheme.surfaceContainerHigh,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.showSeedSource)
              Text(
                fromBullet ? 'From this bullet' : 'From this note',
                style: theme.typography.emphasized.titleSmall,
              ),
            if (widget.showSeedSource && sourceText.trim().isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                '“${sourceText.trim()}”',
                key: const ValueKey('creator-seed-quote'),
                style: theme.typography.baseline.bodySmall.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
            ],
            if (_seedLoading) ...[
              const SizedBox(height: 10),
              Row(
                key: const ValueKey('creator-seed-loading'),
                children: [
                  const M3ELoadingIndicator(),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Drafting a card…',
                      style: theme.typography.baseline.bodySmall,
                    ),
                  ),
                ],
              ),
            ],
            if (_seedHint) ...[
              const SizedBox(height: 10),
              Text(
                'Add an API key in Settings to draft the back automatically, '
                'or write it yourself.',
                key: const ValueKey('creator-seed-hint'),
                style: theme.typography.baseline.bodySmall.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
            ],
            if (_seedError != null) ...[
              const SizedBox(height: 10),
              Semantics(
                liveRegion: true,
                child: TonalBox(
                  key: const ValueKey('creator-seed-error'),
                  color: theme.colorScheme.errorContainer,
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _seedError!,
                        style: theme.typography.baseline.bodySmall.copyWith(
                          color: theme.colorScheme.onErrorContainer,
                          height: 1.4,
                        ),
                      ),
                      Wrap(
                        spacing: 4,
                        children: [
                          M3EButton.text(
                            key: const ValueKey('creator-seed-retry'),
                            onPressed: _seedLoading ? null : _retrySeed,
                            child: const Text('Try again'),
                          ),
                          M3EButton.text(
                            key: const ValueKey('creator-seed-write'),
                            onPressed: () => setState(() {
                              _seedError = null;
                            }),
                            child: const Text('Write it myself'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
            if (suggestion != null) ...[
              const SizedBox(height: 10),
              Text(
                '${suggestion.front} → ${suggestion.back}',
                key: const ValueKey('creator-seed-suggestion'),
                style: theme.typography.baseline.bodySmall.copyWith(
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 4),
              M3EButton.text(
                key: const ValueKey('creator-seed-use-ai'),
                onPressed: () {
                  setState(() {
                    _applySuggestion(suggestion);
                    _seedInitialFront = suggestion.front;
                    _seedInitialBack = suggestion.back;
                    _seedInitialCloze = _definitionCloze.text;
                    _seedSuggestion = null;
                  });
                },
                child: const Text('Use AI draft'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _retrySeed() {
    final seed = widget.controller?.seed;
    if (seed == null) return;
    final requestId = ++_seedRequest;
    setState(() {
      _seedError = null;
      _seedSuggestion = null;
      _seedHint = false;
    });
    _runSeedRequest(seed, requestId);
  }

  Widget _buildTemplateSection(M3EThemeData theme) {
    final selected = _template;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Expanded(
            child: M3EDropdownMenu<CardTemplate>(
              key: const ValueKey('creator-template-picker'),
              items: [
                for (final template in CardTemplate.values)
                  M3EDropdownItem<CardTemplate>(
                    label: template.chipLabel,
                    value: template,
                    selected: selected == template,
                  ),
              ],
              singleSelect: true,
              showChipAnimation: false,
              enabled: !_saving,
              fieldStyle: M3EDropdownFieldStyle(
                hintText: 'Card template',
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                borderRadius: BorderRadius.circular(12),
                prefixIcon: Icon(
                  Icons.style_outlined,
                  size: 20,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                selectedTextStyle: theme.typography.baseline.labelLarge,
                hintStyle: theme.typography.baseline.labelLarge.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              itemStyle: const M3EDropdownItemStyle(
                itemPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              onSelectionChanged: (items) {
                if (items.isEmpty) {
                  final current = _template;
                  if (current != null) _selectTemplate(current);
                  return;
                }
                _selectTemplate(items.first.value);
              },
            ),
          ),
          if (_hasAiContext) ...[
            const SizedBox(width: 4),
            M3EIconButton(
              key: const ValueKey('creator-ai-suggest'),
              variant: M3EIconButtonVariant.standard,
              icon: const Icon(Icons.auto_awesome_outlined),
              tooltip: _aiPanelOpen
                  ? 'Hide AI suggestions'
                  : 'Suggest cards with AI',
              onPressed: _saving ? null : _toggleAiPanel,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBasicFields(M3EThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        M3ETextField(
          key: const ValueKey('creator-front'),
          controller: _front,
          label: 'Front',
          placeholder: 'A short question',
          minLines: 2,
          maxLines: 4,
          isRequired: true,
          enabled: !_saving,
          onChanged: _onFrontBackChanged,
        ),
        const SizedBox(height: 12),
        M3ETextField(
          key: const ValueKey('creator-back'),
          controller: _back,
          label: 'Back',
          placeholder: 'One atomic answer',
          minLines: 2,
          maxLines: 4,
          isRequired: true,
          enabled: !_saving,
          onChanged: _onFrontBackChanged,
        ),
      ],
    );
  }

  Widget _buildDefinitionFields(M3EThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        M3ETextField(
          key: const ValueKey('creator-definition-cloze'),
          controller: _definitionCloze,
          label: 'Definition',
          placeholder: '{{c1::term}}: {{c2::meaning}}',
          minLines: 3,
          maxLines: 6,
          isRequired: true,
          enabled: !_saving,
          onChanged: _onDefinitionChanged,
          trailing: Tooltip(
            message:
                'Put the term in {{c1::…}} and the definition in {{c2::…}}.',
            child: Icon(
              Icons.info_outline,
              size: 20,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(height: 12),
        _buildDefinitionPreview(theme),
      ],
    );
  }

  Widget _buildDefinitionPreview(M3EThemeData theme) {
    final parsed = _parsedDefinition;
    final preview = definitionPreview(parsed.term, parsed.definition);
    return Semantics(
      label: 'Anki front field. ${stripCloze(preview)}',
      excludeSemantics: true,
      child: TonalBox(
        key: const ValueKey('creator-definition-preview'),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _RecapLabel('Anki front field'),
            const SizedBox(height: 4),
            Text(
              preview,
              style: theme.typography.baseline.bodySmall.copyWith(
                fontFamily: 'monospace',
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAiPanel(M3EThemeData theme) {
    final Widget body;
    if (_aiLoading) {
      body = TonalBox(
        key: const ValueKey('creator-ai-loading'),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        child: Row(
          children: [
            const M3ELoadingIndicator(),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                'Suggesting cards…',
                style: theme.typography.baseline.bodyMedium,
              ),
            ),
          ],
        ),
      );
    } else if (_aiUnavailable) {
      body = TonalBox(
        key: const ValueKey('creator-ai-unavailable'),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Text(
          'Add an AI provider in Settings.',
          style: theme.typography.baseline.bodySmall.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            height: 1.4,
          ),
        ),
      );
    } else if (_aiError != null) {
      body = Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Semantics(
              liveRegion: true,
              child: TonalBox(
                key: const ValueKey('creator-ai-error'),
                color: theme.colorScheme.errorContainer,
                padding: const EdgeInsets.all(14),
                child: Text(
                  _aiError!,
                  style: theme.typography.baseline.bodyMedium.copyWith(
                    color: theme.colorScheme.onErrorContainer,
                    height: 1.4,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          _aiRetryButton(),
        ],
      );
    } else if (_ideas == null) {
      body = const SizedBox.shrink();
    } else if (_ideas!.isEmpty) {
      body = Row(
        children: [
          Expanded(
            child: TonalBox(
              key: const ValueKey('creator-ai-empty'),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Text(
                'No new cards found.',
                style: theme.typography.baseline.bodyMedium.copyWith(
                  height: 1.4,
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          _aiRetryButton(),
        ],
      );
    } else {
      body = _buildAiResults(theme);
    }

    return Column(
      key: const ValueKey('creator-ai-section'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [body],
    );
  }

  Widget _aiRetryButton() {
    return M3EIconButton(
      key: const ValueKey('creator-ai-retry'),
      variant: M3EIconButtonVariant.standard,
      icon: const Icon(Icons.refresh),
      tooltip: 'Suggest again',
      onPressed: _saving ? null : _loadAiSuggestions,
    );
  }

  Widget _buildAiResults(M3EThemeData theme) {
    final ideas = _ideas!;
    final variants = ideas.fold<int>(
      0,
      (total, idea) => total + idea.variantCount,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '${ideas.length} idea${ideas.length == 1 ? '' : 's'} · '
                '$variants variant${variants == 1 ? '' : 's'}',
                style: theme.typography.baseline.labelSmall.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            _aiRetryButton(),
          ],
        ),
        const SizedBox(height: 4),
        for (var ideaIndex = 0; ideaIndex < ideas.length; ideaIndex++) ...[
          if (ideaIndex > 0) const SizedBox(height: 10),
          _AiIdeaCard(
            key: ValueKey('creator-ai-idea-$ideaIndex'),
            idea: ideas[ideaIndex],
            ideaIndex: ideaIndex,
            enabled: !_saving,
            onSelectionChanged: () => setState(() {}),
          ),
        ],
        const SizedBox(height: 10),
        M3EButton.filled(
          key: const ValueKey('creator-ai-add'),
          onPressed: _saving || !_hasCompleteSelectedVariant
              ? null
              : _addSelectedSuggestions,
          icon: const Icon(Icons.playlist_add),
          label: const Text('Add selected to list'),
        ),
      ],
    );
  }
}

class _CreatorContextRecap extends StatelessWidget {
  const _CreatorContextRecap({required this.request});

  final CardCreatorRequest request;

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    final error = request.error;
    final note = request.note;
    final tags = AnkiNoteBuilder.tagsFor(request.topicName, request.subtopic);

    final List<Widget> fields;
    if (error != null) {
      fields = [
        _RecapLabel('From this error'),
        const SizedBox(height: 4),
        Text(
          error.question.trim().isEmpty
              ? request.questionContext.trim()
              : error.question.trim(),
          style: theme.typography.baseline.titleSmall.copyWith(height: 1.35),
        ),
        const SizedBox(height: 10),
        _RecapField(
          label: 'Wrong answer chosen',
          value: error.wrongAnswer.trim(),
          valueColor: theme.colorScheme.error,
        ),
        const SizedBox(height: 8),
        _RecapField(label: 'Correct answer', value: error.correctAnswer.trim()),
      ];
    } else if (note != null) {
      fields = [
        _RecapLabel('From this note'),
        const SizedBox(height: 4),
        Text(
          note.text.trim(),
          style: theme.typography.baseline.titleSmall.copyWith(height: 1.35),
        ),
        if (request.questionContext.trim().isNotEmpty) ...[
          const SizedBox(height: 10),
          _RecapField(
            label: 'The question',
            value: request.questionContext.trim(),
          ),
        ],
      ];
    } else if (request.skippedQuestionId != null) {
      final prompt = request.questionContext.trim().isEmpty
          ? request.initialFront.trim()
          : request.questionContext.trim();
      fields = [
        _RecapLabel('Skipped question'),
        const SizedBox(height: 4),
        Text(
          prompt,
          style: theme.typography.baseline.titleSmall.copyWith(height: 1.35),
        ),
        if (request.initialBack.trim().isNotEmpty) ...[
          const SizedBox(height: 10),
          _RecapField(
            label: 'Correct answer',
            value: request.initialBack.trim(),
          ),
        ],
      ];
    } else if (request.questionContext.trim().isNotEmpty) {
      fields = [
        _RecapLabel('From the question'),
        const SizedBox(height: 4),
        Text(
          request.questionContext.trim(),
          style: theme.typography.baseline.bodySmall.copyWith(height: 1.45),
        ),
      ];
    } else {
      fields = const [];
    }

    return TonalBox(
      key: const ValueKey('creator-context'),
      padding: const EdgeInsets.all(14),
      child: SelectionArea(
        child: Semantics(
          container: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ...fields,
              if (tags.isNotEmpty) ...[
                if (fields.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Divider(color: theme.colorScheme.outlineVariant, height: 1),
                  const SizedBox(height: 10),
                ],
                Column(
                  key: const ValueKey('creator-tags'),
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _RecapLabel('Anki tags'),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (var index = 0; index < tags.length; index++)
                          Pill(
                            tags[index],
                            tone: index == 0
                                ? PillTone.primary
                                : PillTone.secondary,
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Topic and subtopic are saved as tags, never inside the '
                      'card text.',
                      style: theme.typography.baseline.bodySmall.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _RecapLabel extends StatelessWidget {
  const _RecapLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    return Text(
      text,
      style: theme.typography.baseline.labelSmall.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _RecapField extends StatelessWidget {
  const _RecapField({
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _RecapLabel(label),
        const SizedBox(height: 2),
        Text(
          value,
          style: theme.typography.baseline.bodySmall.copyWith(
            height: 1.4,
            fontWeight: FontWeight.w600,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}

class _DraftRow extends StatelessWidget {
  const _DraftRow({required this.draft, required this.onRemove, super.key});

  final CardCreatorDraft draft;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    final (title, body, report, pending) = switch (draft) {
      CardCreatorBasicDraft(:final front, :final back, :final template) => (
        front,
        back,
        checkCardLitmus(front: front, back: back, template: template),
        false,
      ),
      CardCreatorConceptDraft(:final term, :final definition) => (
        term,
        definition.trim().isEmpty ? 'Definition pending' : definition,
        checkCardLitmus(
          front: term,
          back: definition,
          template: CardTemplate.definition,
        ),
        definition.trim().isEmpty,
      ),
    };
    final waiting = title.trim().isEmpty && body.trim().isEmpty;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.typography.baseline.titleSmall.copyWith(
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  body,
                  style: theme.typography.baseline.bodySmall.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    Pill(draft.template.label, tone: PillTone.secondary),
                    if (pending) const Pill('Definition pending'),
                    _QualityBadge(report: report, waiting: waiting),
                    Pill(
                      readingTimeLabel(title),
                      tone: PillTone.neutral,
                      icon: Icons.schedule_outlined,
                    ),
                  ],
                ),
                if (!waiting && !report.isClean) ...[
                  const SizedBox(height: 4),
                  Text(
                    report.detail,
                    style: theme.typography.baseline.labelSmall.copyWith(
                      color: theme.colorScheme.error,
                      height: 1.35,
                    ),
                  ),
                ],
              ],
            ),
          ),
          M3EIconButton(
            variant: M3EIconButtonVariant.standard,
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Remove card',
            onPressed: onRemove,
          ),
        ],
      ),
    );
  }
}

class _AiIdeaCard extends StatelessWidget {
  const _AiIdeaCard({
    required this.idea,
    required this.ideaIndex,
    required this.enabled,
    required this.onSelectionChanged,
    super.key,
  });

  final _SuggestedIdea idea;
  final int ideaIndex;
  final bool enabled;
  final VoidCallback onSelectionChanged;

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    final count = idea.variantCount;
    return TonalBox(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Pill(
                idea.template.label,
                key: ValueKey('creator-ai-type-$ideaIndex'),
                tone: PillTone.primary,
              ),
              Text(
                '$count variant${count == 1 ? '' : 's'}',
                style: theme.typography.baseline.labelSmall.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          for (
            var variantIndex = 0;
            variantIndex < idea.variants.length;
            variantIndex++
          ) ...[
            if (variantIndex > 0) ...[
              const SizedBox(height: 10),
              Divider(color: theme.colorScheme.outlineVariant, height: 1),
            ],
            _AiVariantTile(
              key: ValueKey('creator-ai-variant-$ideaIndex-$variantIndex'),
              variant: idea.variants[variantIndex],
              ideaIndex: ideaIndex,
              variantIndex: variantIndex,
              enabled: enabled,
              onChanged: onSelectionChanged,
            ),
          ],
        ],
      ),
    );
  }
}

class _AiVariantTile extends StatelessWidget {
  const _AiVariantTile({
    required this.variant,
    required this.ideaIndex,
    required this.variantIndex,
    required this.enabled,
    required this.onChanged,
    super.key,
  });

  final _AiVariant variant;
  final int ideaIndex;
  final int variantIndex;
  final bool enabled;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    final report = variant.report;
    final definition = variant.template == CardTemplate.definition;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            M3ECheckbox(
              key: ValueKey('creator-ai-select-$ideaIndex-$variantIndex'),
              value: variant.selected,
              semanticLabel:
                  'Keep this ${variant.template.label} variant, option '
                  '${variantIndex + 1}',
              onChanged: enabled
                  ? (value) {
                      variant.selected = value ?? false;
                      onChanged();
                    }
                  : null,
            ),
            const SizedBox(width: 2),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _QualityBadge(
                      key: ValueKey(
                        'creator-ai-litmus-$ideaIndex-$variantIndex',
                      ),
                      report: report,
                      waiting: variant.waiting,
                    ),
                    Pill(
                      readingTimeLabel(variant.front.text),
                      tone: PillTone.neutral,
                      icon: Icons.schedule_outlined,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        M3ETextField(
          key: ValueKey('creator-ai-front-$ideaIndex-$variantIndex'),
          controller: variant.front,
          label: definition ? 'Term' : 'Front',
          minLines: 1,
          maxLines: 3,
          enabled: enabled,
          onChanged: (_) => onChanged(),
        ),
        const SizedBox(height: 8),
        M3ETextField(
          key: ValueKey('creator-ai-back-$ideaIndex-$variantIndex'),
          controller: variant.back,
          label: definition ? 'Meaning' : 'Back',
          minLines: 1,
          maxLines: 3,
          enabled: enabled,
          onChanged: (_) => onChanged(),
        ),
        if (!variant.waiting && !report.isClean) ...[
          const SizedBox(height: 6),
          Text(
            report.detail,
            key: ValueKey('creator-ai-litmus-detail-$ideaIndex-$variantIndex'),
            style: theme.typography.baseline.labelSmall.copyWith(
              color: theme.colorScheme.error,
              height: 1.35,
            ),
          ),
        ],
      ],
    );
  }
}

class _LitmusRow extends StatelessWidget {
  const _LitmusRow({
    required this.report,
    required this.waiting,
    required this.readingTime,
    required this.badgeKey,
    required this.detailKey,
  });

  final LitmusReport report;
  final bool waiting;
  final String readingTime;
  final Key badgeKey;
  final Key detailKey;

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              'Card quality',
              style: theme.typography.baseline.labelSmall.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
            _QualityBadge(key: badgeKey, report: report, waiting: waiting),
            Tooltip(
              message: 'Estimated time to read the front',
              child: Pill(
                key: const ValueKey('creator-litmus-reading-time'),
                readingTime,
                tone: PillTone.neutral,
                icon: Icons.schedule_outlined,
              ),
            ),
          ],
        ),
        if (!waiting && !report.isClean) ...[
          const SizedBox(height: 4),
          Text(
            report.detail,
            key: detailKey,
            style: theme.typography.baseline.labelSmall.copyWith(
              color: theme.colorScheme.error,
              height: 1.35,
            ),
          ),
        ],
      ],
    );
  }
}

class _QualityBadge extends StatelessWidget {
  const _QualityBadge({required this.report, this.waiting = false, super.key});

  final LitmusReport report;
  final bool waiting;

  @override
  Widget build(BuildContext context) {
    final clean = report.isClean;
    final label = waiting
        ? 'Waiting for text'
        : clean
        ? 'Ready'
        : 'Check quality';
    final icon = waiting
        ? Icons.edit_note
        : clean
        ? Icons.check_circle_outline
        : Icons.warning_amber_outlined;
    final tone = waiting
        ? PillTone.neutral
        : clean
        ? PillTone.success
        : PillTone.error;
    final semantics = waiting
        ? 'Card quality: waiting for text'
        : clean
        ? 'Card quality: Ready'
        : 'Card quality: Check quality. ${report.detail}';
    return Semantics(
      container: true,
      label: semantics,
      excludeSemantics: true,
      child: Pill(label, tone: tone, icon: icon),
    );
  }
}
