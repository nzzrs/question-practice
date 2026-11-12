import 'package:flutter/services.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/ui/widgets.dart';
import 'help_json_example.dart';

class HelpPage extends StatelessWidget {
  const HelpPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    return AppPage(
      title: 'How to use it',
      showBack: true,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(28),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconBadge(
                    Icons.auto_stories_outlined,
                    tone: PillTone.primary,
                    size: 46,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'What you can do',
                      style: theme.typography.emphasized.titleLarge.copyWith(
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'Import a practice file, answer with your reasoning, review '
                'mistakes, and export cards to AnkiDroid.',
                style: theme.typography.baseline.bodyMedium.copyWith(
                  color: theme.colorScheme.onPrimaryContainer,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        const _Section(
          number: '01',
          title: 'Home',
          points: [
            'Topic cards show practices, questions, accuracy and progress.',
            'The sort icon orders topics by name or recency, in either direction.',
            'The archive icon lists archived topics. Long-press a topic to edit, archive or delete it.',
            'Paused sessions sit at the top with Resume and Discard.',
            'The Shuffle floating button opens Start shuffled practice.',
            'Import opens a practice file. Cards and Review past errors open their screens.',
          ],
        ),
        const _Section(
          number: '02',
          title: 'Import',
          points: [
            'Choose a .json file, or a .txt file that contains JSON.',
            'The whole file is checked first. A broken file shows the problem and imports nothing.',
            'Review the counts and duplicates, then tap Import. Load sample opens the bundled example.',
            'One file can hold many topics and practices.',
          ],
        ),
        const _Section(
          number: '03',
          title: 'Practice',
          points: [
            'Select one alternative, or every correct one when the question has several.',
            'Reasoning is optional and saves automatically.',
            'Check stays on the screen: correct and wrong choices are marked, and explanations open.',
            'The arrows and question list move between questions without answering.',
            'Answered questions get a Done tag. Skip records a skipped question.',
            'Close offers Save for later. Paused sessions wait on Home.',
            'A banner appears every 5 minutes on the same question.',
          ],
        ),
        const _Section(
          number: '04',
          title: 'Feedback and error cards',
          points: [
            'A wrong answer creates an error card with the question, your answer, the correct answer, your reasoning and the explanation.',
            'Check I was distracted or read too fast to remove the card. Uncheck it to restore the card.',
            "I didn't know this counts as skipped and creates no error card.",
            'The review asks for the flawed assumption and what prevents it.',
            'Skipped answers ask whether a concept or another question was missing.',
            'Review opens fullscreen. Missing details can be completed later from Cards.',
          ],
        ),
        const _Section(
          number: '05',
          title: 'Past errors',
          points: [
            'Wrong answers wait 48 hours before they are offered again.',
            'A correct answer resolves the card and keeps it in history.',
            'A wrong answer schedules the next attempt 48 hours later.',
            'Distraction on a re-test does not resolve the card.',
          ],
        ),
        const _Section(
          number: '06',
          title: 'Cards',
          points: [
            'Cards holds concepts, error and skipped cards, basic cards and highlights.',
            'Filter by All, Concepts, Errors & skipped, Basic or Highlights. Show exported includes exported cards.',
            'Select cards, then use Review all or Review selected.',
            "Complete finishes a missing definition or an error card's details.",
            "Tap a card to preview it. In the error review, the pencil opens a full-page editor for the question, alternatives and explanations.",
            'Delete selected removes the chosen cards.',
          ],
        ),
        const _Section(
          number: '07',
          title: 'Highlights',
          points: [
            'Select text during practice and choose Highlight.',
            'Highlights stay in Cards and can become a concept or basic card.',
            'Download all saves highlights as plain text. Highlights are never sent to AnkiDroid.',
          ],
        ),
        const _Section(
          number: '08',
          title: 'AnkiDroid export',
          points: [
            'Export to AnkiDroid sends the selected cards to AnkiDroid.',
            'Concepts use the Cloze note type, error cards their own note type, and basic cards the Basic note type.',
            'Each topic can use its own deck. Topics without one use the default deck from Settings.',
            "Set a topic's deck in Edit topic. Browse decks lists live deck names.",
            'Share as files creates Anki-compatible text files without a deck.',
          ],
        ),
        const _Section(
          number: '09',
          title: 'Practice JSON',
          points: [
            'Long-press a practice and choose Edit practice to download or update its JSON.',
            'A download includes the topic and practice names, descriptions, every question, sourceId and subtopic when set.',
            'Update previews new, modified, unchanged and deleted questions before applying.',
            'Questions match by sourceId first, then by trimmed prompt. Matched questions keep their answers, cards and statistics.',
            'The topic and practice names in the file must match the stored practice.',
          ],
        ),
        const _Section(
          number: '10',
          title: 'Subtopics and statistics',
          points: [
            'A question can have an optional subtopic. Questions without one appear as Uncategorized.',
            'Statistics groups by subtopic with accuracy and progress for each group. Spelling and capitalisation define a group.',
            'The insights icon opens Statistics: latest, best and average score, progress over time and a trend line.',
            'Learning rate shows the average change per week once the history spans at least one week.',
            'The share icon exports the visible statistics as JSON.',
          ],
        ),
        const _Section(
          number: '11',
          title: 'Lookup and Ask',
          points: [
            'Select text, then Define, to save a missing concept.',
            'Web search opens DuckDuckGo or Wikipedia and keeps an editable definition sheet.',
            'AI writes a short definition and saves it automatically. Configure the provider, model and key in Settings.',
            'Ask sends the selected passage to AI. Its answer can become a concept or basic card.',
            'Only the selected text, question and topic are sent, and only when you use Define or Ask.',
          ],
        ),
        const _Section(
          number: '12',
          title: 'Backup and data',
          points: [
            'Settings → Data exports one backup with topics, practices, questions, sessions, answers, cards, highlights and settings.',
            'Restore checks the file before replacing all local data. Export a backup first.',
            'Erase all data removes practices, sessions, cards, settings and the saved AI key.',
            'The AI key stays in Android secure storage and is never exported.',
            'The app works offline and sends no analytics.',
          ],
        ),
        const _Section(
          number: '13',
          title: 'Shuffled practice',
          points: [
            'Start shuffled practice uses questions from every topic.',
            'It keeps only questions that are neither solved nor skipped, and shuffles questions and alternatives.',
            'If no question is eligible, it says so instead of starting an empty session.',
            'A shuffled session can be saved for later like any other session.',
          ],
        ),
        _Section(
          number: '14',
          title: 'JSON example',
          points: const [
            'Every file needs formatVersion: 1 and a topics list.',
            'A question needs a prompt, 2–8 alternatives, correctIndex or correctIndexes, an explanation, and one explanation per alternative.',
            'Optional fields include description, priority, subtopic and sourceId.',
          ],
          trailing: M3EButton.tonal(
            onPressed: () async {
              await Clipboard.setData(
                const ClipboardData(text: helpJsonExample),
              );
              if (context.mounted) {
                await showSnack(context, 'JSON example copied.');
              }
            },
            icon: const Icon(Icons.copy_all_outlined),
            label: const Text('Copy JSON example'),
          ),
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.number,
    required this.title,
    required this.points,
    this.trailing,
  });

  final String number;
  final String title;
  final List<String> points;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    final pointStyle = theme.typography.baseline.bodySmall.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
      height: 1.5,
    );
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(26),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                number,
                style: theme.typography.emphasized.titleMedium.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: theme.typography.emphasized.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          for (final point in points)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '•',
                    style: pointStyle.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(point, style: pointStyle)),
                ],
              ),
            ),
          if (trailing != null) ...[const SizedBox(height: 12), trailing!],
        ],
      ),
    );
  }
}
