import 'package:flutter/services.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/ui/widgets.dart';

class HelpPage extends StatelessWidget {
  const HelpPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    return AppScaffold(
      title: 'How to use it',
      showBack: true,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [
          TonalBox(
            color: theme.colorScheme.primaryContainer,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'A quiet loop for practice',
                  style: theme.typography.emphasized.titleMedium,
                ),
                const SizedBox(height: 6),
                Text(
                  'Import a practice, answer with your reasoning, review what went wrong, then turn those mistakes into cards.',
                  style: theme.typography.baseline.bodyMedium.copyWith(
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _Section(
            title: '1. Import practices',
            body:
                'Open Import from the home screen. The file must be .json or a .txt containing JSON. '
                'One file can contain many topics and practices. The app validates the whole file first and rejects it with a clear path if anything is wrong.',
          ),
          _Section(
            title: 'JSON shape',
            body:
                'The smallest complete question has a prompt, 2–8 alternatives, a zero-based correctIndex '
                '(or correctIndexes for several correct answers), an explanation, and exactly one alternative explanation per alternative. '
                'Topic and practice descriptions are optional; priority is 1 (highest) to 5.',
            trailing: M3EButton.tonal(
              onPressed: () async {
                await Clipboard.setData(
                  const ClipboardData(text: _jsonExample),
                );
                if (context.mounted) {
                  await showSnack(context, 'JSON example copied.');
                }
              },
              icon: const Icon(Icons.copy_all_outlined),
              label: const Text('Copy JSON example'),
            ),
          ),
          _Section(
            title: '2. Practice',
            body:
                'Select an alternative, or every correct alternative when there are several, write your reasoning if it helps, then tap Check. The answer stays on the same screen: '
                'your reasoning locks, the correct answer is marked, and every alternative expands with its explanation. '
                'Use the arrows beside the question number to move between questions without answering. '
                'Skip if you do not know. After a wrong answer, check "I was distracted or read too fast" if that is what happened; uncheck it to restore the card. '
                'The close button offers Save for later, so several paused sessions can wait on Home. '
                'Every 5 minutes a small banner appears; there is no countdown.',
          ),
          _Section(
            title: '3. Error cards',
            body:
                'A wrong answer creates an error card with the question, your answer, the correct answer, your reasoning and the explanation. '
                'The end-of-session review asks for the flawed assumption (bias) and what you need to know to prevent it (vaccine). '
                'Check the distraction box in the feedback when the mistake was reading too fast; uncheck it to bring the card back. Skipped questions create no error card; '
                'the review asks whether a concept or another question was missing. Cards can be completed later from Cards, where Review all sits at the top and Review selected appears for checked cards.',
          ),
          _Section(
            title: '4. Past errors wait 48 hours',
            body:
                'Wrong answers stay in the error queue, but they are not offered again until two days after the last mistake. '
                'Answering one correctly resolves it and keeps it in history and statistics. Answering it wrong schedules the next attempt 48 hours later.',
          ),
          _Section(
            title: '5. Define a term',
            body:
                'Long-press a word or phrase in a question, alternative or explanation and choose Define. The app saves it as a missing concept. '
                'With AI selected, the definition appears in a read-only bubble and is saved automatically; there is no save button. '
                'OpenAI, Groq and OpenRouter use chat completions; Gemini uses its native API. '
                'Without AI it opens DuckDuckGo or Wikipedia in a Custom Tab and keeps the editable definition sheet. '
                'Only the selected term, question and topic are sent, and only when you invoke Define.',
          ),
          _Section(
            title: '6. Export to Anki',
            body:
                'The Cards screen previews and selects concepts (cloze), error cards (six fields) and basic cards. '
                'Export straight to AnkiDroid through its supported API, or share Anki-compatible text files. '
                'AnkiDroid must have its API enabled and this app must have database permission. '
                'The error note type is created automatically if it is missing. Concept cards use the Cloze note type already in AnkiDroid; create a Cloze note type there if it was deleted. '
                'Each topic can target its own AnkiDroid deck. Open a topic, tap Edit, then Browse decks. '
                'A topic with no deck uses the default deck from Settings, where Browse decks lists live deck names. ',
          ),
          _Section(
            title: 'Privacy and data',
            body:
                'Practices, answers, cards and statistics are stored locally in SQLite. The AI API key is stored in Android secure storage, never in the database. '
                'The app does not track time or send analytics. Deleting all data in Settings removes practices, sessions, cards and the saved key.',
          ),
          _Section(
            title: 'Shuffle and reminders',
            body:
                'The shuffle button on the home screen turns on a mixed session: questions from all topics, in random order. '
                'The 5-minute reminder measures only foreground practice time; it pauses when the app is in the background.',
          ),
          const SizedBox(height: 8),
          Text(
            'Question Practice · local-first study',
            style: theme.typography.baseline.labelSmall.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.body, this.trailing});

  final String title;
  final String body;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.typography.emphasized.titleMedium),
          const SizedBox(height: 6),
          Text(
            body,
            style: theme.typography.baseline.bodyMedium.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.45,
            ),
          ),
          if (trailing != null) ...[const SizedBox(height: 12), trailing!],
        ],
      ),
    );
  }
}

const _jsonExample = '''
{
  "formatVersion": 1,
  "topics": [
    {
      "name": "Cloud",
      "description": "Cloud fundamentals",
      "priority": 1,
      "practices": [
        {
          "name": "Core services",
          "questions": [
            {
              "prompt": "Which service runs containers?",
              "alternatives": ["Cloud Run", "Cloud SQL"],
              "correctIndex": 0,
              "explanation": "Cloud Run is a managed container platform.",
              "alternativeExplanations": [
                "Correct. Cloud Run runs container images.",
                "Cloud SQL is a managed relational database."
              ]
            }
          ]
        }
      ]
    }
  ]
}
''';
