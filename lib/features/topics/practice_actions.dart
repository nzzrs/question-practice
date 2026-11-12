import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/providers.dart';
import '../../core/domain/models.dart';
import '../../core/ui/widgets.dart';
import '../import/domain/import_models.dart';
import '../practice_edit/domain/practice_edit_service.dart';
import '../practice_edit/practice_update_preview_page.dart';
import 'anki_deck_picker.dart';

/// Actions offered when a practice row is long-pressed.
enum PracticeAction { edit, delete, markDone, markActive, split }

enum _PracticeEditAction { rename, description, downloadJson, updateJson, deck }

/// Opens the practice options sheet and returns the chosen action.
Future<PracticeAction?> showPracticeActions(
  BuildContext context,
  PracticeSummary summary,
) {
  return M3EBottomSheet.show<PracticeAction>(
    context,
    initialValue: M3EBottomSheetValue.expanded,
    builder: (context) => _PracticeOptionsSheet(summary: summary),
  );
}

/// Opens the edit menu for a practice: rename, description, files and deck.
Future<void> showPracticeEditMenu(
  BuildContext context,
  WidgetRef ref,
  PracticeSummary summary,
) async {
  final topic = await ref
      .read(topicRepositoryProvider)
      .topicById(summary.practice.topicId);
  if (!context.mounted) return;
  if (topic == null) {
    await showSnack(context, 'This topic no longer exists.');
    return;
  }
  final defaultDeck =
      ref.read(settingsProvider).value?.ankiDeck ?? 'Question Practice';
  final action = await M3EBottomSheet.show<_PracticeEditAction>(
    context,
    initialValue: M3EBottomSheetValue.expanded,
    builder: (context) => _PracticeEditOptionsSheet(
      summary: summary,
      defaultDeck: defaultDeck,
      deck: topic.ankiDeck,
    ),
  );
  if (action == null || !context.mounted) return;
  switch (action) {
    case _PracticeEditAction.rename:
      await _renamePractice(context, ref, summary);
    case _PracticeEditAction.description:
      await _editDescription(context, ref, summary);
    case _PracticeEditAction.downloadJson:
      await _downloadJson(context, ref, summary);
    case _PracticeEditAction.updateJson:
      await _updateFromJson(context, ref, summary);
    case _PracticeEditAction.deck:
      await _chooseDeck(context, ref, topic, defaultDeck);
  }
}

Future<void> _renamePractice(
  BuildContext context,
  WidgetRef ref,
  PracticeSummary summary,
) async {
  final practice = summary.practice;
  final name = TextEditingController(text: practice.name);
  String? error;
  final saved = await M3EDialog.show<bool>(
    context,
    dialog: StatefulBuilder(
      builder: (context, setDialogState) {
        return M3EDialog(
          title: 'Rename practice',
          content: M3ETextField(
            controller: name,
            label: 'Name',
            isRequired: true,
            autofocus: true,
            errorText: error,
          ),
          actions: [
            M3EButton.text(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            M3EButton.filled(
              onPressed: () async {
                final trimmed = name.text.trim();
                if (trimmed.isEmpty) {
                  setDialogState(() => error = 'Name is required.');
                  return;
                }
                if (trimmed.length > 120) {
                  setDialogState(() => error = 'Use 120 characters or fewer.');
                  return;
                }
                await ref
                    .read(topicRepositoryProvider)
                    .renamePractice(practice.id, trimmed);
                if (context.mounted) Navigator.of(context).pop(true);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    ),
  );
  name.dispose();
  if (saved == true && context.mounted) {
    await showSnack(context, 'Practice renamed.');
  }
}

Future<void> _editDescription(
  BuildContext context,
  WidgetRef ref,
  PracticeSummary summary,
) async {
  final practice = summary.practice;
  final description = TextEditingController(text: practice.description);
  String? error;
  final saved = await M3EDialog.show<bool>(
    context,
    dialog: StatefulBuilder(
      builder: (context, setDialogState) {
        return M3EDialog(
          title: 'Edit description',
          content: M3ETextField(
            controller: description,
            label: 'Description',
            maxLines: 4,
            minLines: 2,
            autofocus: true,
            errorText: error,
          ),
          actions: [
            M3EButton.text(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            M3EButton.filled(
              onPressed: () async {
                final trimmed = description.text.trim();
                if (trimmed.length > 2000) {
                  setDialogState(
                    () => error = 'Use 2,000 characters or fewer.',
                  );
                  return;
                }
                await ref
                    .read(topicRepositoryProvider)
                    .updatePracticeDescription(practice.id, trimmed);
                if (context.mounted) Navigator.of(context).pop(true);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    ),
  );
  description.dispose();
  if (saved == true && context.mounted) {
    await showSnack(context, 'Practice description updated.');
  }
}

Future<void> _downloadJson(
  BuildContext context,
  WidgetRef ref,
  PracticeSummary summary,
) async {
  try {
    await ref
        .read(practiceEditServiceProvider)
        .sharePracticeJson(summary.practice.id);
  } on Object catch (error) {
    if (context.mounted) {
      await showSnack(context, 'Could not export the practice JSON: $error');
    }
  }
}

Future<void> _updateFromJson(
  BuildContext context,
  WidgetRef ref,
  PracticeSummary summary,
) async {
  try {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['json', 'txt'],
    );
    if (files.isEmpty || !context.mounted) return;
    final file = files.single;
    final bytes = await file.readAsBytes();
    final preview = await ref
        .read(practiceEditServiceProvider)
        .previewUpdateBytes(
          bytes,
          fileName: file.name,
          practiceId: summary.practice.id,
        );
    if (!context.mounted) return;
    final applied = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (context) => PracticeUpdatePreviewPage(preview: preview),
      ),
    );
    if (applied == true && context.mounted) {
      await showSnack(
        context,
        'Practice updated: ${preview.newCount} new, '
        '${preview.modifiedCount} modified, '
        '${preview.deletedCount} deleted.',
      );
    }
  } on ImportException catch (error) {
    if (context.mounted) {
      await _showIssues(context, error.issues);
    }
  } on PracticeFileException catch (error) {
    if (context.mounted) await showSnack(context, error.message);
  } on Object catch (error) {
    if (context.mounted) {
      await showSnack(context, 'Could not read that file: $error');
    }
  }
}

Future<void> _showIssues(BuildContext context, List<ImportIssue> issues) async {
  await M3EDialog.show<void>(
    context,
    dialog: M3EDialog(
      title: 'Update file rejected',
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${issues.length} problem${issues.length == 1 ? '' : 's'} found. '
                'Nothing was changed.',
              ),
              const SizedBox(height: 12),
              for (final issue in issues.take(20))
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text('${issue.displayPath}: ${issue.message}'),
                ),
              if (issues.length > 20) Text('…and ${issues.length - 20} more.'),
            ],
          ),
        ),
      ),
      actions: [
        M3EButton.filled(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    ),
  );
}

Future<void> _chooseDeck(
  BuildContext context,
  WidgetRef ref,
  Topic topic,
  String defaultDeck,
) async {
  final selected = await showAnkiDeckPicker(
    context,
    ref,
    current: topic.ankiDeck ?? '',
  );
  if (selected == null || !context.mounted) return;
  final deck = selected.trim();
  await ref
      .read(topicRepositoryProvider)
      .updateTopic(
        id: topic.id,
        name: topic.name,
        description: topic.description,
        priority: topic.priority,
        ankiDeck: deck.isEmpty ? null : deck,
      );
  if (!context.mounted) return;
  await showSnack(
    context,
    deck.isEmpty
        ? 'Deck reset to $defaultDeck (default).'
        : 'Anki deck set to $deck.',
  );
}

class _PracticeOptionsSheet extends StatelessWidget {
  const _PracticeOptionsSheet({required this.summary});

  final PracticeSummary summary;

  @override
  Widget build(BuildContext context) {
    final practice = summary.practice;
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SheetHeader(
              title: practice.name,
              subtitle:
                  '${summary.questionCount} questions · '
                  '${practice.isDone ? 'Marked as done' : 'Active'}',
            ),
            PracticeOptionTile(
              icon: Icons.edit_outlined,
              title: 'Edit practice',
              subtitle: 'Rename, edit the description or update the JSON',
              onTap: () => Navigator.of(context).pop(PracticeAction.edit),
            ),
            PracticeOptionTile(
              icon: practice.isDone
                  ? Icons.restart_alt
                  : Icons.check_circle_outline,
              title: practice.isDone ? 'Mark active' : 'Mark as done',
              subtitle: practice.isDone
                  ? 'Return it to the active list'
                  : 'Keep it without deleting it',
              onTap: () => Navigator.of(context).pop(
                practice.isDone
                    ? PracticeAction.markActive
                    : PracticeAction.markDone,
              ),
            ),
            PracticeOptionTile(
              icon: Icons.call_split,
              title: 'Split into two',
              subtitle: summary.questionCount.isEven
                  ? 'Create Slice A and Slice B with half the questions each'
                  : 'Needs an even number of questions',
              onTap: () => Navigator.of(context).pop(PracticeAction.split),
            ),
            PracticeOptionTile(
              icon: Icons.delete_outline,
              title: 'Delete',
              subtitle: 'Remove the practice and its questions',
              destructive: true,
              onTap: () => Navigator.of(context).pop(PracticeAction.delete),
            ),
          ],
        ),
      ),
    );
  }
}

class _PracticeEditOptionsSheet extends StatelessWidget {
  const _PracticeEditOptionsSheet({
    required this.summary,
    required this.defaultDeck,
    required this.deck,
  });

  final PracticeSummary summary;
  final String defaultDeck;
  final String? deck;

  @override
  Widget build(BuildContext context) {
    final deckName = deck?.trim();
    final deckLabel = deckName == null || deckName.isEmpty
        ? '$defaultDeck (default)'
        : deckName;
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SheetHeader(
              title: 'Edit practice',
              subtitle: summary.practice.name,
            ),
            PracticeOptionTile(
              icon: Icons.drive_file_rename_outline,
              title: 'Rename',
              subtitle: 'Change the practice name',
              onTap: () =>
                  Navigator.of(context).pop(_PracticeEditAction.rename),
            ),
            PracticeOptionTile(
              icon: Icons.notes_outlined,
              title: 'Edit description',
              subtitle: 'Describe what this practice covers',
              onTap: () =>
                  Navigator.of(context).pop(_PracticeEditAction.description),
            ),
            PracticeOptionTile(
              icon: Icons.download_outlined,
              title: 'Download practice JSON',
              subtitle: 'Share a file with every question and its identity',
              onTap: () =>
                  Navigator.of(context).pop(_PracticeEditAction.downloadJson),
            ),
            PracticeOptionTile(
              icon: Icons.upload_file_outlined,
              title: 'Update practice JSON',
              subtitle: 'Add, modify or delete questions from a JSON file',
              onTap: () =>
                  Navigator.of(context).pop(_PracticeEditAction.updateJson),
            ),
            PracticeOptionTile(
              icon: Icons.style_outlined,
              title: 'AnkiDroid deck',
              subtitle: deckLabel,
              onTap: () => Navigator.of(context).pop(_PracticeEditAction.deck),
            ),
          ],
        ),
      ),
    );
  }
}

class _SheetHeader extends StatelessWidget {
  const _SheetHeader({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.typography.emphasized.titleLarge,
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.typography.baseline.bodySmall.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class PracticeOptionTile extends StatelessWidget {
  const PracticeOptionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.destructive = false,
    super.key,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    final foreground = destructive
        ? theme.colorScheme.error
        : theme.colorScheme.onSurface;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              IconBadge(
                icon,
                size: 42,
                tone: destructive ? PillTone.error : PillTone.neutral,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.typography.baseline.titleMedium.copyWith(
                        color: foreground,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: theme.typography.baseline.bodySmall.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right,
                color: destructive
                    ? theme.colorScheme.error
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
