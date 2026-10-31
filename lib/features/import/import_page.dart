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
  bool _showFormat = false;
  ImportPreview? _preview;

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    final preview = _preview;
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: M3EAppBar.top(
        titleText: 'Import practice',
        leading: M3EIconButton(
          variant: M3EIconButtonVariant.standard,
          icon: const Icon(M3EIcons.arrow_back),
          tooltip: 'Back',
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              20,
              4,
              20,
              preview == null ? 32 + MediaQuery.paddingOf(context).bottom : 24,
            ),
            children: [
              _FilePanel(
                busy: _busy,
                onChoose: _pickFile,
                onSample: _loadSample,
              ),
              const SizedBox(height: 18),
              if (preview == null) ...[
                _FormatHelp(
                  open: _showFormat,
                  onToggle: () => setState(() => _showFormat = !_showFormat),
                ),
              ] else
                _Preview(
                  preview: preview,
                  busy: _busy,
                  onCancel: () => setState(() => _preview = null),
                ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: preview == null
          ? null
          : AppActionDock(
              child: Row(
                children: [
                  Expanded(
                    child: AppPrimaryButton(
                      onPressed: _busy ? null : _import,
                      label: _busy ? 'Importing…' : 'Import',
                      icon: Icons.check,
                    ),
                  ),
                  const SizedBox(width: 8),
                  M3EButton.text(
                    onPressed: _busy
                        ? null
                        : () => setState(() => _preview = null),
                    child: const Text('Cancel'),
                  ),
                ],
              ),
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
      final duplicates = result.practicesSkipped == 0
          ? ''
          : ', ${result.practicesSkipped} duplicates skipped';
      await showSnack(
        context,
        'Practice imported: ${result.practicesImported} practices, '
        '${result.questionsImported} questions$duplicates.',
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

class _FilePanel extends StatelessWidget {
  const _FilePanel({
    required this.busy,
    required this.onChoose,
    required this.onSample,
  });

  final bool busy;
  final VoidCallback onChoose;
  final VoidCallback onSample;

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconBadge(Icons.upload_file_outlined, size: 52),
          const SizedBox(height: 14),
          Text(
            'Bring in a practice',
            style: theme.typography.emphasized.titleLarge,
          ),
          const SizedBox(height: 4),
          Text(
            'Choose a .json file, or a .txt file that contains JSON. The whole file is checked before anything is saved.',
            style: theme.typography.baseline.bodySmall.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 16),
          AppPrimaryButton(
            onPressed: busy ? null : onChoose,
            label: busy ? 'Reading…' : 'Choose file',
            icon: Icons.file_open_outlined,
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: M3EButton.tonal(
              onPressed: busy ? null : onSample,
              icon: const Icon(Icons.science_outlined),
              label: const Text('Load sample'),
            ),
          ),
        ],
      ),
    );
  }
}

class _FormatHelp extends StatelessWidget {
  const _FormatHelp({required this.open, required this.onToggle});

  final bool open;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onToggle,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(
                      Icons.data_object,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Expected shape',
                        style: theme.typography.baseline.titleSmall,
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
          if (open)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Text(
                        '{"formatVersion": 1, "topics": [{"name": "Cloud", '
                        '"practices": [{"name": "Core", "questions": [{"prompt": "…", '
                        '"alternatives": ["…", "…"], "correctIndex": 0, '
                        '"explanation": "…", "alternativeExplanations": ["…", "…"]}]}]}]}',
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          height: 1.4,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Each question has one correct answer (correctIndex) or several (correctIndexes), with one explanation per alternative. See the help screen for the full format.',
                    style: theme.typography.baseline.bodySmall.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
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
    required this.onCancel,
  });

  final ImportPreview preview;
  final bool busy;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(26),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Ready to import',
                      style: theme.typography.emphasized.titleMedium.copyWith(
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                  M3EIconButton(
                    variant: M3EIconButtonVariant.standard,
                    icon: const Icon(Icons.close),
                    tooltip: 'Clear preview',
                    onPressed: busy ? null : onCancel,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                preview.fileName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.typography.baseline.bodyMedium.copyWith(
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${preview.topicCount} topics · ${preview.practiceCount} practices · ${preview.questionCount} questions',
                style: theme.typography.baseline.bodySmall.copyWith(
                  color: theme.colorScheme.onPrimaryContainer.withValues(
                    alpha: 0.85,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (preview.notes.isNotEmpty) ...[
          const SizedBox(height: 16),
          SectionTitle('Duplicates', count: preview.notes.length),
          AppGroup(
            children: [
              for (final note in preview.notes)
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 18,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          note,
                          style: theme.typography.baseline.bodySmall.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
        const SizedBox(height: 20),
        const SectionTitle('Contents'),
        AppGroup(
          children: [
            for (final topic in preview.topics.take(5))
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      topic.name,
                      style: theme.typography.baseline.titleSmall,
                    ),
                    const SizedBox(height: 2),
                    for (final practice in topic.practices)
                      Text(
                        '${practice.name} · ${practice.questions.length} questions',
                        style: theme.typography.baseline.bodySmall.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
        if (preview.topics.length > 5) ...[
          const SizedBox(height: 8),
          Text(
            '…and ${preview.topics.length - 5} more topics.',
            style: theme.typography.baseline.bodySmall.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}
