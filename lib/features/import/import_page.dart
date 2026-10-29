import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/providers.dart';
import '../../core/ui/widgets.dart';
import 'domain/import_models.dart';

class ImportPage extends ConsumerStatefulWidget {
  const ImportPage({super.key});

  @override
  ConsumerState<ImportPage> createState() => _ImportPageState();
}

class _ImportPageState extends ConsumerState<ImportPage> {
  bool _busy = false;
  ImportPreview? _preview;

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    return AppScaffold(
      title: 'Import practice',
      showBack: true,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Text(
            'Choose a .json file, or a .txt file that contains JSON.',
            style: theme.typography.baseline.bodyLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'The whole file is checked before anything is saved. Existing topics are reused; exact duplicate practices are skipped.',
            style: theme.typography.baseline.bodySmall.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          M3EButton.filled(
            onPressed: _busy ? null : _pickFile,
            icon: const Icon(Icons.file_open_outlined),
            label: Text(_busy ? 'Reading…' : 'Choose file'),
          ),
          const SizedBox(height: 8),
          M3EButton.tonal(
            onPressed: _busy ? null : _loadSample,
            icon: const Icon(Icons.science_outlined),
            label: const Text('Load sample'),
          ),
          const SizedBox(height: 28),
          if (_preview == null) ...[
            TonalBox(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Expected shape',
                    style: theme.typography.emphasized.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: const Text(
                        '{"formatVersion": 1, "topics": [{"name": "Cloud", '
                        '"practices": [{"name": "Core", "questions": [{"prompt": "…", '
                        '"alternatives": ["…", "…"], "correctIndex": 0, '
                        '"explanation": "…", "alternativeExplanations": ["…", "…"]}]}]}]}',
                        style: TextStyle(fontFamily: 'monospace', height: 1.4),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Each question needs one explanation per alternative. See the help screen for the full format.',
                    style: theme.typography.baseline.bodySmall.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ] else
            _Preview(
              preview: _preview!,
              busy: _busy,
              onImport: _import,
              onCancel: () => setState(() => _preview = null),
            ),
        ],
      ),
    );
  }

  Future<void> _pickFile() async {
    setState(() => _busy = true);
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['json', 'txt'],
      );
      if (files.isEmpty) return;
      final file = files.single;
      final bytes = await file.readAsBytes();
      final preview = await ref
          .read(importServiceProvider)
          .previewBytes(bytes, fileName: file.name);
      if (mounted) setState(() => _preview = preview);
    } on ImportException catch (error) {
      if (mounted) {
        await _showIssues(error.issues, fileTitle: 'Import rejected');
      }
    } on Object catch (error) {
      if (mounted) await showSnack(context, 'Could not read that file: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _loadSample() async {
    setState(() => _busy = true);
    try {
      final text = await rootBundle.loadString(
        'assets/samples/sample_practice.json',
      );
      final preview = await ref
          .read(importServiceProvider)
          .previewText(text, fileName: 'sample_practice.json');
      if (mounted) setState(() => _preview = preview);
    } on ImportException catch (error) {
      if (mounted) {
        await _showIssues(error.issues, fileTitle: 'Sample rejected');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _import() async {
    final preview = _preview;
    if (preview == null) return;
    setState(() => _busy = true);
    try {
      final result = await ref.read(importServiceProvider).import(preview);
      if (!mounted) return;
      ref.invalidate(homeStatsProvider);
      await M3EDialog.show<void>(
        context,
        dialog: M3EDialog(
          title: 'Practice imported',
          content: Text(
            '${result.topicsCreated} topics created, ${result.topicsReused} reused.\n'
            '${result.practicesImported} practices and ${result.questionsImported} questions imported'
            '${result.practicesSkipped == 0 ? '.' : '; ${result.practicesSkipped} duplicates skipped.'}',
          ),
          actions: [
            M3EButton.filled(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Done'),
            ),
          ],
        ),
      );
      if (mounted) Navigator.of(context).pop(true);
    } on ImportException catch (error) {
      if (mounted) {
        await _showIssues(error.issues, fileTitle: 'Import rejected');
      }
    } on Object catch (error) {
      if (mounted) await showSnack(context, 'Import failed: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _showIssues(
    List<ImportIssue> issues, {
    required String fileTitle,
  }) async {
    await M3EDialog.show<void>(
      context,
      dialog: M3EDialog(
        title: fileTitle,
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${issues.length} problem${issues.length == 1 ? '' : 's'} found. Nothing was imported.',
                ),
                const SizedBox(height: 12),
                for (final issue in issues.take(20))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text('${issue.displayPath}: ${issue.message}'),
                  ),
                if (issues.length > 20)
                  Text('…and ${issues.length - 20} more.'),
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
}

class _Preview extends StatelessWidget {
  const _Preview({
    required this.preview,
    required this.busy,
    required this.onImport,
    required this.onCancel,
  });

  final ImportPreview preview;
  final bool busy;
  final VoidCallback onImport;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TonalBox(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Ready to import',
                style: theme.typography.emphasized.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(preview.fileName),
              const SizedBox(height: 8),
              Text(
                '${preview.topicCount} topics · ${preview.practiceCount} practices · ${preview.questionCount} questions',
                style: theme.typography.baseline.bodySmall.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        if (preview.notes.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text('Duplicates', style: theme.typography.emphasized.titleSmall),
          const SizedBox(height: 4),
          for (final note in preview.notes)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                '• $note',
                style: theme.typography.baseline.bodySmall.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
        ],
        const SizedBox(height: 20),
        for (final topic in preview.topics.take(5)) ...[
          Text(topic.name, style: theme.typography.emphasized.titleSmall),
          for (final practice in topic.practices)
            Padding(
              padding: const EdgeInsets.only(left: 8, top: 2),
              child: Text(
                '${practice.name} · ${practice.questions.length} questions',
                style: theme.typography.baseline.bodySmall,
              ),
            ),
          const SizedBox(height: 8),
        ],
        if (preview.topics.length > 5)
          Text(
            '…and ${preview.topics.length - 5} more topics.',
            style: theme.typography.baseline.bodySmall,
          ),
        const SizedBox(height: 20),
        Row(
          children: [
            M3EButton.filled(
              onPressed: busy ? null : onImport,
              icon: const Icon(Icons.check),
              label: Text(busy ? 'Importing…' : 'Import'),
            ),
            const SizedBox(width: 8),
            M3EButton.text(
              onPressed: busy ? null : onCancel,
              child: const Text('Cancel'),
            ),
          ],
        ),
      ],
    );
  }
}
