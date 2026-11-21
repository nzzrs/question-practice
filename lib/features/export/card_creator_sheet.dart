import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/providers.dart';
import '../../core/domain/models.dart';
import '../../core/ui/widgets.dart';
import '../lookup/domain/lookup_service.dart';
import '../review/domain/card_litmus.dart';
import 'card_creator_controller.dart';
import 'domain/anki_note_builder.dart';
import 'domain/card_templates.dart';

/// The error being turned into cards, with any learner edits already applied.
class CardCreatorErrorSource {
  const CardCreatorErrorSource({
    required this.card,
    required this.question,
    required this.wrongAnswer,
    required this.correctAnswer,
    this.reasoning = '',
    this.explanation = '',
    this.wrongNotes = const [],
  });

  final ErrorCard card;
  final String question;
  final String wrongAnswer;
  final String correctAnswer;
  final String reasoning;
  final String explanation;

  /// The learner's read-only bullets, sent separately to the AI breakdown.
  final List<String> wrongNotes;
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
    this.note,
    this.error,
    this.skippedQuestionId,
    this.completeErrorOnSave = true,
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

  /// Note context: enables AI suggestions and marks the note converted on save.
  final Note? note;

  /// Error context: enables AI breakdown and completes details on save.
  final CardCreatorErrorSource? error;

  /// Skipped queue record to mark handled once a card is saved.
  final int? skippedQuestionId;

  /// Whether the error's details step is completed after a card is saved.
  final bool completeErrorOnSave;
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

/// One creator for manual cards and optional AI suggestions.
///
/// Lives inside an [M3EBottomSheet], so the review surface behind it keeps the
/// mistake visible while cards are written. Manual entry never needs an AI
/// provider. Cards are collected as drafts and saved together, so the learner
/// can add several ideas little by little.
class CardCreatorSheet extends StatelessWidget {
  const CardCreatorSheet({required this.request, super.key});

  final CardCreatorRequest request;

  @override
  Widget build(BuildContext context) {
    return CardCreatorBody(
      request: request,
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
    super.key,
  });

  final CardCreatorRequest request;
  final CardCreatorController controller;
  final ValueChanged<int>? onSaved;
  final ValueChanged<int>? onDraftCountChanged;

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
      label: 'Card creator',
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
    this.showSaveButton = true,
    super.key,
  });

  final CardCreatorRequest request;
  final ValueChanged<int>? onSaved;
  final VoidCallback? onClose;
  final bool embedded;

  /// Whether the scrolling body renders its own save action.
  ///
  /// The sheet keeps it in the scroll; the embedded pane moves it to a sticky
  /// footer so it is always reachable.
  final bool showSaveButton;

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

sealed class _CardDraft {
  const _CardDraft();

  CardTemplate get template;

  String? get sourceBulletId;
}

class _BasicDraft extends _CardDraft {
  const _BasicDraft({
    required this.front,
    required this.back,
    required this.template,
    this.sourceBulletId,
  });

  final String front;
  final String back;

  @override
  final String? sourceBulletId;

  @override
  final CardTemplate template;
}

class _ConceptDraft extends _CardDraft {
  const _ConceptDraft({
    required this.term,
    required this.definition,
    required this.extra,
    required this.source,
    this.sourceBulletId,
  });

  final String term;
  final String definition;
  final String extra;
  final ConceptSource source;

  @override
  final String? sourceBulletId;

  @override
  CardTemplate get template => CardTemplate.definition;
}

enum _DefinitionSource {
  cards('From your cards'),
  ai('From AI');

  const _DefinitionSource(this.label);

  final String label;
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

  _CardDraft toDraft() {
    if (template == CardTemplate.definition) {
      return _ConceptDraft(
        term: front.text.trim(),
        definition: back.text.trim(),
        extra: '',
        source: ConceptSource.ai,
      );
    }
    return _BasicDraft(
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

class _CardCreatorBodyState extends ConsumerState<CardCreatorBody> {
  late final TextEditingController _front;
  late final TextEditingController _back;
  late final TextEditingController _term;

  late CardTemplate? _template;
  String _appliedScaffoldFront = '';
  String _appliedScaffoldBack = '';

  String _meaning = '';
  String _meaningExtra = '';
  String _meaningTerm = '';
  _DefinitionSource? _meaningSource;
  bool _definitionLoading = false;
  String? _definitionError;
  LookupFailure? _definitionFailure;
  Timer? _definitionDebounce;
  int _definitionRequest = 0;

  final _drafts = <_CardDraft>[];
  List<_SuggestedIdea>? _ideas;
  final _retiredIdeas = <_SuggestedIdea>[];
  final _retiredVariants = <_AiVariant>[];
  String? _aiError;
  bool _aiLoading = false;
  bool _saving = false;

  int _appliedSeedRevision = -1;
  String? _seedBulletId;
  Note? _seedNote;
  Note? _noteToConvert;
  String _seedInitialFront = '';
  String _seedInitialBack = '';
  SuggestedCard? _seedSuggestion;
  bool _seedTouched = false;
  bool _seedLoading = false;
  bool _applyingSeed = false;
  bool _seedHint = false;
  String? _seedError;
  int _seedRequest = 0;
  int _reportedDraftCount = 0;

  @override
  void initState() {
    super.initState();
    widget.controller?.addListener(_onControllerChanged);
    final request = widget.request;
    _front = TextEditingController(text: request.initialFront);
    _back = TextEditingController(text: request.initialBack);
    _term = TextEditingController(text: request.initialTerm);
    _template = _initialTemplate();
    if (_template == CardTemplate.definition) {
      if (request.initialDefinition.trim().isNotEmpty &&
          request.initialTerm.trim().isNotEmpty) {
        _meaning = request.initialDefinition.trim();
        _meaningTerm = request.initialTerm.trim();
        _meaningSource = _DefinitionSource.cards;
      } else if (request.initialTerm.trim().isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _scheduleDefinitionLookup(immediate: true);
        });
      }
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _reportDraftCount(force: true);
      _onControllerChanged();
    });
  }

  @override
  void didUpdateWidget(covariant CardCreatorBody oldWidget) {
    super.didUpdateWidget(oldWidget);
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
      if (_hasSeedComposer) setState(_clearSeedComposer);
      return;
    }
    if (controller.seedRevision == _appliedSeedRevision) return;
    _appliedSeedRevision = controller.seedRevision;
    _definitionDebounce?.cancel();
    _definitionRequest++;
    final requestId = ++_seedRequest;

    _applyingSeed = true;
    setState(() {
      _seedSuggestion = null;
      _seedTouched = false;
      _seedLoading = false;
      _seedHint = false;
      _seedError = null;
      switch (seed) {
        case BulletCardSeed(:final bulletId, :final bullet):
          _seedBulletId = bulletId;
          _seedNote = null;
          _template = null;
          _front.text = bullet;
          _back.clear();
          _appliedScaffoldFront = '';
          _appliedScaffoldBack = '';
          _seedInitialFront = bullet;
          _seedInitialBack = '';
          _clearMeaningFields();
        case NoteCardSeed(:final note):
          _seedBulletId = null;
          _seedNote = note;
          _noteToConvert = note;
          _template = CardTemplate.definition;
          _term.text = note.text;
          _front.clear();
          _back.clear();
          _appliedScaffoldFront = '';
          _appliedScaffoldBack = '';
          _seedInitialFront = note.text;
          _seedInitialBack = '';
          _clearMeaningFields();
      }
    });
    _applyingSeed = false;
    _seedScrollToTop();
    await _runSeedRequest(seed, requestId);
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
          final suggestion = await lookup.suggestCardFromWrongNote(
            note: bullet,
            question: error?.question ?? request.questionContext,
            wrongAnswer: error?.wrongAnswer ?? '',
            correctAnswer: error?.correctAnswer ?? '',
            explanation: error?.explanation ?? '',
            topicName: request.topicName,
            subtopic: request.subtopic,
            otherNotes: error?.wrongNotes ?? const [],
          );
          if (!mounted || requestId != _seedRequest) return;
          setState(() {
            _seedLoading = false;
            if (suggestion == null) {
              _seedError =
                  'The AI found nothing to draft. Write the card yourself.';
            } else if (_seedTouched ||
                _front.text.trim() != _seedInitialFront.trim() ||
                _back.text.trim().isNotEmpty) {
              _seedSuggestion = suggestion;
            } else {
              _template = suggestion.template;
              _front.text = suggestion.front;
              _back.text = suggestion.back;
              _seedInitialFront = suggestion.front;
              _seedInitialBack = suggestion.back;
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
          setState(() {
            _seedLoading = false;
            _retiredIdeas.addAll(_ideas ?? const []);
            _ideas = [for (final idea in ideas) _SuggestedIdea(idea)];
            if (ideas.isEmpty) {
              _seedError =
                  'The AI found nothing to draft. Write the card yourself.';
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
    _definitionDebounce?.cancel();
    _front.dispose();
    _back.dispose();
    _term.dispose();
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

  bool get _canAdd {
    if (_saving) return false;
    if (_template == CardTemplate.definition) {
      return _term.text.trim().isNotEmpty;
    }
    return _front.text.trim().isNotEmpty && _back.text.trim().isNotEmpty;
  }

  bool get _waitingForText => _template == CardTemplate.definition
      ? _term.text.trim().isEmpty
      : _front.text.trim().isEmpty && _back.text.trim().isEmpty;

  LitmusReport get _currentReport => checkCardLitmus(
    front: _template == CardTemplate.definition ? _term.text : _front.text,
    back: _template == CardTemplate.definition ? _meaning : _back.text,
    template: _effectiveTemplate,
  );

  bool get _hasCustomText {
    final template = _template;
    if (template == null || template == CardTemplate.definition) return false;
    if (_front.text.trim().isEmpty && _back.text.trim().isEmpty) return false;
    return _front.text != _appliedScaffoldFront ||
        _back.text != _appliedScaffoldBack;
  }

  void _selectTemplate(CardTemplate template) {
    if (_saving) return;
    if (template == CardTemplate.definition) {
      final term = _term.text.trim();
      final keepMeaning =
          _meaning.isNotEmpty &&
          _meaningTerm.toLowerCase() == term.toLowerCase();
      setState(() => _template = template);
      if (term.isEmpty) {
        setState(_clearMeaningFields);
      } else if (!keepMeaning && !_definitionLoading) {
        _scheduleDefinitionLookup(immediate: true);
      }
      return;
    }
    final scaffold = fillScaffold(
      template,
      wrongAnswer: widget.request.error?.wrongAnswer ?? '',
      correctAnswer: widget.request.error?.correctAnswer ?? '',
    );
    final fieldsEmpty = _front.text.trim().isEmpty && _back.text.trim().isEmpty;
    final matchesApplied =
        _appliedScaffoldFront.isNotEmpty &&
        _front.text == _appliedScaffoldFront &&
        _back.text == _appliedScaffoldBack;
    setState(() {
      _template = template;
      if (scaffold != null && (fieldsEmpty || matchesApplied)) {
        _front.text = scaffold.front;
        _back.text = scaffold.back;
        _appliedScaffoldFront = scaffold.front;
        _appliedScaffoldBack = scaffold.back;
        _placeCursorAtPlaceholder(_front);
      }
    });
  }

  Future<void> _fillTemplate() async {
    final template = _template;
    if (template == null || template == CardTemplate.definition || _saving) {
      return;
    }
    final scaffold = fillScaffold(
      template,
      wrongAnswer: widget.request.error?.wrongAnswer ?? '',
      correctAnswer: widget.request.error?.correctAnswer ?? '',
    );
    if (scaffold == null) return;
    final hasText =
        _front.text.trim().isNotEmpty || _back.text.trim().isNotEmpty;
    if (hasText) {
      final confirmed = await confirmDialog(
        context,
        title: 'Replace the text with this template?',
        message:
            'The current front and back will be replaced by the '
            '${template.chipLabel} template.',
        confirmLabel: 'Replace',
      );
      if (!confirmed || !mounted) return;
    }
    setState(() {
      _front.text = scaffold.front;
      _back.text = scaffold.back;
      _appliedScaffoldFront = scaffold.front;
      _appliedScaffoldBack = scaffold.back;
      _placeCursorAtPlaceholder(_front);
    });
  }

  void _placeCursorAtPlaceholder(TextEditingController controller) {
    final index = controller.text.indexOf('[');
    if (index < 0) return;
    controller.selection = TextSelection.collapsed(offset: index);
  }

  void _markSeedEdited() {
    if (_applyingSeed) return;
    if (_seedBulletId == null && _seedNote == null) return;
    final changed =
        _front.text != _seedInitialFront ||
        _back.text != _seedInitialBack ||
        (_seedNote != null && _term.text != _seedInitialFront);
    if (!changed) return;
    _seedTouched = true;
    widget.controller?.markSeedDirty();
  }

  void _onTermChanged(String value) {
    if (_template != CardTemplate.definition) {
      setState(_markSeedEdited);
      return;
    }
    setState(_markSeedEdited);
    _scheduleDefinitionLookup();
  }

  void _onFrontBackChanged(String value) {
    setState(_markSeedEdited);
  }

  void _scheduleDefinitionLookup({bool immediate = false}) {
    _definitionDebounce?.cancel();
    final term = _term.text.trim();
    final requestId = ++_definitionRequest;
    if (term.isEmpty) {
      if (mounted) setState(_clearMeaningFields);
      return;
    }
    if (mounted) {
      setState(() {
        _meaning = '';
        _meaningExtra = '';
        _meaningTerm = '';
        _meaningSource = null;
        _definitionError = null;
        _definitionFailure = null;
        _definitionLoading = true;
      });
    }
    if (immediate) {
      _resolveMeaning(term, requestId);
      return;
    }
    _definitionDebounce = Timer(
      const Duration(milliseconds: 600),
      () => _resolveMeaning(term, requestId),
    );
  }

  void _clearMeaningFields() {
    _meaning = '';
    _meaningExtra = '';
    _meaningTerm = '';
    _meaningSource = null;
    _definitionLoading = false;
    _definitionError = null;
    _definitionFailure = null;
  }

  void _retryDefinition() {
    if (_saving) return;
    _scheduleDefinitionLookup(immediate: true);
  }

  bool _isCurrentDefinition(String term, int requestId) {
    return mounted &&
        requestId == _definitionRequest &&
        _term.text.trim() == term;
  }

  Future<void> _resolveMeaning(String term, int requestId) async {
    final initialDefinition = widget.request.initialDefinition.trim();
    final initialTerm = widget.request.initialTerm.trim();
    if (initialDefinition.isNotEmpty &&
        term.toLowerCase() == initialTerm.toLowerCase()) {
      if (!_isCurrentDefinition(term, requestId)) return;
      setState(() {
        _meaning = initialDefinition;
        _meaningExtra = '';
        _meaningTerm = term;
        _meaningSource = _DefinitionSource.cards;
        _definitionLoading = false;
        _definitionError = null;
        _definitionFailure = null;
      });
      return;
    }

    Concept? existing;
    try {
      existing = await ref
          .read(cardRepositoryProvider)
          .latestConceptForTerm(term);
    } on Object {
      existing = null;
    }
    if (!_isCurrentDefinition(term, requestId)) return;
    if (existing != null && existing.definition.trim().isNotEmpty) {
      setState(() {
        _meaning = existing!.definition.trim();
        _meaningExtra = existing.extra;
        _meaningTerm = term;
        _meaningSource = _DefinitionSource.cards;
        _definitionLoading = false;
        _definitionError = null;
        _definitionFailure = null;
      });
      return;
    }

    try {
      final suggestion = await ref
          .read(lookupServiceProvider)
          .resolveDefinition(
            term: term,
            question: widget.request.questionContext,
            topicName: widget.request.topicName,
            subtopic: widget.request.subtopic,
          );
      if (!_isCurrentDefinition(term, requestId)) return;
      setState(() {
        _meaning = suggestion.definition.trim();
        _meaningExtra = suggestion.extra;
        _meaningTerm = term;
        _meaningSource = _DefinitionSource.ai;
        _definitionLoading = false;
        _definitionError = null;
        _definitionFailure = null;
      });
    } on LookupException catch (error) {
      if (!_isCurrentDefinition(term, requestId)) return;
      setState(() {
        _definitionLoading = false;
        if (error.failure == LookupFailure.noProvider) {
          _definitionFailure = LookupFailure.noProvider;
          _definitionError = null;
        } else {
          _definitionFailure = LookupFailure.providerError;
          _definitionError = error.message;
        }
      });
    } on Object catch (error) {
      if (!_isCurrentDefinition(term, requestId)) return;
      setState(() {
        _definitionLoading = false;
        _definitionFailure = LookupFailure.providerError;
        _definitionError = 'Could not look up the meaning: $error';
      });
    }
  }

  void _addDraft() {
    if (!_canAdd || _saving) return;
    final bulletId = _seedBulletId;
    if (_template == CardTemplate.definition) {
      final term = _term.text.trim();
      final source = _meaningSource == _DefinitionSource.ai
          ? ConceptSource.ai
          : ConceptSource.manual;
      _definitionDebounce?.cancel();
      _definitionRequest++;
      setState(() {
        _drafts.add(
          _ConceptDraft(
            term: term,
            definition: _meaning.trim(),
            extra: _meaningExtra,
            source: source,
            sourceBulletId: bulletId,
          ),
        );
        _term.clear();
        _clearMeaningFields();
        _clearSeedComposer();
      });
      _afterDraftAdded(bulletId);
      return;
    }
    final template = _template ?? CardTemplate.mechanism;
    setState(() {
      _drafts.add(
        _BasicDraft(
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

  Future<void> _loadAiSuggestions() async {
    if (_aiLoading || _saving) return;
    setState(() {
      _aiLoading = true;
      _aiError = null;
      _retiredIdeas.addAll(_ideas ?? const []);
      _ideas = null;
    });
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
          wrongNotes: error.wrongNotes,
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
      setState(() {
        _ideas = [for (final idea in ideas) _SuggestedIdea(idea)];
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

  Future<void> _save() async {
    if (_drafts.isEmpty || _saving) return;
    setState(() => _saving = true);
    final service = ref.read(reviewServiceProvider);
    final request = widget.request;
    final pending = List<_CardDraft>.of(_drafts);
    var created = 0;
    int? manualCardId;
    Object? failure;
    for (final draft in pending) {
      try {
        switch (draft) {
          case _BasicDraft():
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
          case _ConceptDraft():
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
        if (mounted) setState(() => _drafts.remove(draft));
      } on Object catch (error) {
        failure = error;
        break;
      }
    }

    if (created > 0) {
      try {
        final note = request.note;
        final seededNote = _noteToConvert;
        final noteIds = <int>{
          if (note != null) note.id,
          if (seededNote != null) seededNote.id,
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
      }
    }

    if (!mounted) return;
    setState(() {
      _saving = false;
      if (created > 0) {
        _clearSeedComposer();
        _noteToConvert = null;
      }
    });
    _reportDraftCount();
    if (failure != null) {
      await showSnack(
        context,
        created > 0
            ? '$created card${created == 1 ? '' : 's'} saved, but the rest '
                  'could not be saved: $failure'
            : 'Could not create the cards: $failure',
      );
      return;
    }
    widget.onSaved?.call(created);
  }

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    final request = widget.request;
    final hasKey = ref.watch(hasApiKeyProvider);
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Card creator',
                  style: theme.typography.emphasized.titleLarge,
                ),
                const SizedBox(height: 2),
                Text(
                  'One idea per card.',
                  style: theme.typography.baseline.labelSmall.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
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
                  tooltip: 'Close card creator',
                  onPressed: _saving ? null : widget.onClose,
                ),
            ],
          ),
        if (!widget.embedded) const SizedBox(height: 8),
        if (!widget.embedded && hasContext) ...[
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
        if (_hasAiContext) ...[
          const SizedBox(height: 20),
          _buildAiSection(theme, hasKey),
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
      label: _saving ? 'Saving…' : 'Save $count card${count == 1 ? '' : 's'}',
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
            Text(
              fromBullet ? 'From this bullet' : 'From this note',
              style: theme.typography.emphasized.titleSmall,
            ),
            if (sourceText.trim().isNotEmpty) ...[
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
                'AI is optional. Add an API key in Settings to draft the back '
                'automatically.',
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
                    _template = suggestion.template;
                    _front.text = suggestion.front;
                    _back.text = suggestion.back;
                    _seedInitialFront = suggestion.front;
                    _seedInitialBack = suggestion.back;
                    _seedSuggestion = null;
                    _seedTouched = false;
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
    Widget? trailing;
    if (_template == null) {
      trailing = const Pill('Custom card');
    } else if (_hasCustomText && !_saving) {
      trailing = M3EButton.text(
        key: const ValueKey('creator-template-fill'),
        onPressed: _fillTemplate,
        child: const Text('Fill template'),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(
          'Card template',
          supporting:
              'Each template writes the front and back. Replace the bracketed '
              'parts.',
          trailing: trailing,
        ),
        Semantics(
          container: true,
          label: 'Card template',
          child: M3ETheme(
            data: theme.copyWith(
              chipTheme: theme.chipTheme.copyWith(height: 48),
            ),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final template in CardTemplate.values)
                  M3EChip(
                    key: ValueKey('creator-template-${template.name}'),
                    type: M3EChipType.filter,
                    label: template.chipLabel,
                    selected: _template == template,
                    onPressed: _saving ? null : () => _selectTemplate(template),
                  ),
              ],
            ),
          ),
        ),
      ],
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
          key: const ValueKey('creator-term'),
          controller: _term,
          label: 'Term',
          isRequired: true,
          enabled: !_saving,
          onChanged: _onTermChanged,
        ),
        const SizedBox(height: 12),
        _buildMeaningBlock(theme),
        const SizedBox(height: 12),
        _buildDefinitionPreview(theme),
      ],
    );
  }

  Widget _buildMeaningBlock(M3EThemeData theme) {
    final termEmpty = _term.text.trim().isEmpty;
    if (termEmpty && _meaning.isEmpty) {
      return TonalBox(
        key: const ValueKey('creator-definition-idle'),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Text(
          'Type a term. The meaning is filled from your cards or AI.',
          style: theme.typography.baseline.bodySmall.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            height: 1.45,
          ),
        ),
      );
    }
    if (_definitionLoading) {
      return TonalBox(
        key: const ValueKey('creator-definition-loading'),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        child: Row(
          children: [
            const M3ELoadingIndicator(),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                'Looking up the meaning…',
                style: theme.typography.baseline.bodyMedium,
              ),
            ),
          ],
        ),
      );
    }
    if (_definitionFailure == LookupFailure.noProvider) {
      return TonalBox(
        key: const ValueKey('creator-definition-unavailable'),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Text(
          'No definition found. This card will be saved without a definition '
          'and will not export until one is added. Turn on AI lookup in '
          'Settings to fill it automatically.',
          style: theme.typography.baseline.bodySmall.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            height: 1.45,
          ),
        ),
      );
    }
    if (_definitionError != null) {
      return Semantics(
        liveRegion: true,
        child: TonalBox(
          key: const ValueKey('creator-definition-error'),
          color: theme.colorScheme.errorContainer,
          padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Could not look up the meaning. You can try again or '
                      'save the term now.',
                      style: theme.typography.baseline.bodySmall.copyWith(
                        color: theme.colorScheme.onErrorContainer,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _definitionError!,
                      style: theme.typography.baseline.bodySmall.copyWith(
                        color: theme.colorScheme.onErrorContainer.withValues(
                          alpha: 0.8,
                        ),
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              M3EIconButton(
                key: const ValueKey('creator-definition-refresh'),
                variant: M3EIconButtonVariant.standard,
                icon: const Icon(Icons.refresh),
                tooltip: 'Look up the meaning again',
                onPressed: _saving ? null : _retryDefinition,
              ),
            ],
          ),
        ),
      );
    }
    if (_meaning.isNotEmpty) {
      return Column(
        key: const ValueKey('creator-definition-meaning'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(child: _RecapLabel('Meaning')),
              M3EIconButton(
                key: const ValueKey('creator-definition-refresh'),
                variant: M3EIconButtonVariant.standard,
                icon: const Icon(Icons.refresh),
                tooltip: 'Look up the meaning again',
                onPressed: _saving ? null : _retryDefinition,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            _meaning,
            style: theme.typography.baseline.bodyMedium.copyWith(height: 1.4),
          ),
          if (_meaningSource != null) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [Pill(_meaningSource!.label, tone: PillTone.secondary)],
            ),
          ],
        ],
      );
    }
    return TonalBox(
      key: const ValueKey('creator-definition-idle'),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Text(
        'Type a term. The meaning is filled from your cards or AI.',
        style: theme.typography.baseline.bodySmall.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          height: 1.45,
        ),
      ),
    );
  }

  Widget _buildDefinitionPreview(M3EThemeData theme) {
    final term = _term.text.trim();
    final meaning = _meaning.trim();
    return Semantics(
      label:
          'Anki front field. Definition of $term. The meaning is shown in '
          'the Meaning section.',
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
              definitionPreview(term, meaning),
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

  Widget _buildAiSection(M3EThemeData theme, AsyncValue<bool> hasKey) {
    final keyLoading = hasKey.isLoading;
    final keyAvailable = hasKey.value ?? false;
    final showRetry = !_aiLoading && (_aiError != null || _ideas != null);
    final trailing = _aiLoading
        ? M3EIconButton(
            key: const ValueKey('creator-ai-retry'),
            variant: M3EIconButtonVariant.standard,
            icon: const Icon(Icons.refresh),
            tooltip: 'Suggest again',
            onPressed: null,
          )
        : showRetry
        ? M3EIconButton(
            key: const ValueKey('creator-ai-retry'),
            variant: M3EIconButtonVariant.standard,
            icon: const Icon(Icons.refresh),
            tooltip: 'Suggest again',
            onPressed: _saving ? null : _loadAiSuggestions,
          )
        : null;

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
    } else if (_aiError != null) {
      body = Semantics(
        liveRegion: true,
        child: TonalBox(
          key: const ValueKey('creator-ai-error'),
          color: theme.colorScheme.errorContainer,
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _aiError!,
                style: theme.typography.baseline.bodyMedium.copyWith(
                  color: theme.colorScheme.onErrorContainer,
                  height: 1.4,
                ),
              ),
              if (_aiError!.toLowerCase().contains('settings')) ...[
                const SizedBox(height: 4),
                Text(
                  'Open Settings to add an AI provider and key.',
                  style: theme.typography.baseline.labelSmall.copyWith(
                    color: theme.colorScheme.onErrorContainer,
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    } else if (_ideas == null) {
      if (keyLoading) {
        body = SizedBox(
          width: double.infinity,
          child: M3EButton.tonal(
            key: const ValueKey('creator-ai-suggest'),
            onPressed: null,
            icon: const Icon(Icons.auto_awesome_outlined),
            label: const Text('Suggest with AI'),
          ),
        );
      } else if (!keyAvailable) {
        body = TonalBox(
          key: const ValueKey('creator-ai-unavailable'),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Text(
            'AI suggestions need a provider. Add an API key in Settings. '
            'Manual cards work without one.',
            style: theme.typography.baseline.bodySmall.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.45,
            ),
          ),
        );
      } else {
        body = SizedBox(
          width: double.infinity,
          child: M3EButton.tonal(
            key: const ValueKey('creator-ai-suggest'),
            onPressed: _saving ? null : _loadAiSuggestions,
            icon: const Icon(Icons.auto_awesome_outlined),
            label: const Text('Suggest with AI'),
          ),
        );
      }
    } else if (_ideas!.isEmpty) {
      body = TonalBox(
        key: const ValueKey('creator-ai-empty'),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Text(
          'The AI found no new cards here.',
          style: theme.typography.baseline.bodyMedium.copyWith(height: 1.45),
        ),
      );
    } else {
      body = _buildAiResults(theme);
    }

    return Column(
      key: const ValueKey('creator-ai-section'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(
          'AI suggestions',
          supporting:
              'Optional. AI proposes ideas; keep the variants that help.',
          trailing: trailing,
        ),
        body,
      ],
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
        Text(
          '${ideas.length} idea${ideas.length == 1 ? '' : 's'} · '
          '$variants variant${variants == 1 ? '' : 's'}',
          style: theme.typography.baseline.labelSmall.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
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
        if (error.card.mistakeKinds.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final kind in error.card.mistakeKinds)
                Pill(kind.label, tone: PillTone.secondary),
            ],
          ),
        ],
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

  final _CardDraft draft;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    final (title, body, report, pending) = switch (draft) {
      _BasicDraft(:final front, :final back, :final template) => (
        front,
        back,
        checkCardLitmus(front: front, back: back, template: template),
        false,
      ),
      _ConceptDraft(:final term, :final definition) => (
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
                child: _QualityBadge(
                  key: ValueKey('creator-ai-litmus-$ideaIndex-$variantIndex'),
                  report: report,
                  waiting: variant.waiting,
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
    required this.badgeKey,
    required this.detailKey,
  });

  final LitmusReport report;
  final bool waiting;
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
