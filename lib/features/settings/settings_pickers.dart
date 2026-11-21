import 'package:flutter/foundation.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

/// One option in a [showSettingsChoicePicker].
class SettingsChoice<T> {
  const SettingsChoice({
    required this.id,
    required this.value,
    required this.label,
  });

  /// Stable id used for the option's [ValueKey].
  final String id;
  final T value;
  final String label;
}

/// A compact field that shows the current single choice.
///
/// The whole surface is one tap target; it never renders the selected value
/// as a chip or floating bubble.
class SettingsChoiceField extends StatelessWidget {
  const SettingsChoiceField({
    super.key,
    required this.value,
    required this.hint,
    required this.semanticLabel,
    required this.onTap,
  });

  /// The current value, or an empty string when nothing is selected.
  final String value;
  final String hint;
  final String semanticLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    final scheme = theme.colorScheme;
    final hasValue = value.trim().isNotEmpty;
    return Semantics(
      button: true,
      label: semanticLabel,
      value: hasValue ? value : null,
      child: Material(
        color: scheme.surfaceContainerHighest,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: scheme.outlineVariant),
        ),
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 52, maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      hasValue ? value : hint,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.typography.baseline.bodyLarge.copyWith(
                        color: hasValue
                            ? scheme.onSurface
                            : scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: scheme.onSurfaceVariant,
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

/// Shows a single-choice list where the selected row is solidly filled.
///
/// Completes with the chosen value, or null when the dialog is dismissed.
Future<T?> showSettingsChoicePicker<T>(
  BuildContext context, {
  required String pickerId,
  required String title,
  required List<SettingsChoice<T>> choices,
  required T selected,
}) {
  return M3EDialog.show<T>(
    context,
    dialog: M3EDialog(
      title: title,
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final choice in choices)
              _ChoiceRow(
                key: ValueKey('$pickerId-option-${choice.id}'),
                label: choice.label,
                selected: choice.value == selected,
                onTap: () => Navigator.of(context).pop(choice.value),
              ),
          ],
        ),
      ),
      actions: [
        M3EButton.text(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ],
    ),
  );
}

class _ChoiceRow extends StatelessWidget {
  const _ChoiceRow({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    final scheme = theme.colorScheme;
    final foreground = selected ? scheme.onPrimaryContainer : scheme.onSurface;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Material(
          color: selected ? scheme.primaryContainer : Colors.transparent,
          clipBehavior: Clip.antiAlias,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      style: theme.typography.baseline.bodyLarge.copyWith(
                        color: foreground,
                        fontWeight: selected ? FontWeight.w600 : null,
                      ),
                    ),
                  ),
                  if (selected) ...[
                    const SizedBox(width: 8),
                    Icon(Icons.check, size: 20, color: foreground),
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

/// Model list state shared between the settings page and the model picker.
@immutable
class ModelCatalogState {
  const ModelCatalogState({
    this.models = const [],
    this.selected = '',
    this.loading = false,
    this.loaded = false,
  });

  final List<String> models;
  final String selected;
  final bool loading;
  final bool loaded;
}

/// Opens the searchable model picker.
///
/// The search query lives in the picker body, so scrolling the results never
/// resets it. Completes with the chosen model, or null when dismissed.
Future<String?> showSettingsModelPicker(
  BuildContext context, {
  required ValueListenable<ModelCatalogState> catalog,
}) {
  return M3EDialog.show<String>(
    context,
    dialog: M3EDialog(
      title: 'Choose a model',
      subhead: 'Loaded from the provider.',
      content: _ModelPickerBody(catalog: catalog),
      actions: [
        M3EButton.text(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ],
    ),
  );
}

class _ModelPickerBody extends StatefulWidget {
  const _ModelPickerBody({required this.catalog});

  final ValueListenable<ModelCatalogState> catalog;

  @override
  State<_ModelPickerBody> createState() => _ModelPickerBodyState();
}

class _ModelPickerBodyState extends State<_ModelPickerBody> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    return SizedBox(
      width: double.maxFinite,
      height: 360,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          M3ETextField(
            key: const ValueKey('ai-model-search'),
            controller: _search,
            label: 'Search models',
            placeholder: 'Type to filter',
            leading: const Icon(Icons.search),
            onChanged: (value) => setState(() => _query = value),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: ValueListenableBuilder<ModelCatalogState>(
              valueListenable: widget.catalog,
              builder: (context, catalog, _) {
                final query = _query.trim().toLowerCase();
                final models = [
                  for (final model in catalog.models)
                    if (query.isEmpty || model.toLowerCase().contains(query))
                      model,
                ];
                if (catalog.models.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (catalog.loading || !catalog.loaded)
                            const M3ELoadingIndicator()
                          else
                            Icon(
                              Icons.search_off,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          const SizedBox(height: 12),
                          Text(
                            catalog.loading || !catalog.loaded
                                ? 'Loading models…'
                                : 'No models available from this provider.',
                            textAlign: TextAlign.center,
                            style: theme.typography.baseline.bodySmall.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                if (models.isEmpty) {
                  return Center(
                    child: Text(
                      'No models match “${_query.trim()}”.',
                      textAlign: TextAlign.center,
                      style: theme.typography.baseline.bodySmall.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  );
                }
                return ListView.separated(
                  key: const ValueKey('ai-model-list'),
                  padding: EdgeInsets.zero,
                  itemCount: models.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 4),
                  itemBuilder: (context, index) {
                    final model = models[index];
                    return _ChoiceRow(
                      key: ValueKey('ai-model-option-$model'),
                      label: model,
                      selected: model == catalog.selected,
                      onTap: () => Navigator.of(context).pop(model),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
