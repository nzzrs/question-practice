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
                'Import a practice file, write what went wrong, review '
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
            'The archive icon lists archived topics. Long-press a topic to edit, archive or delete it. Valid topic edits save automatically; closing with an invalid value offers Discard changes.',
            'Long-press a practice to edit, split or delete it. Split asks for a part count, mixes the questions and names the parts Slice A, Slice B and so on.',
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
            'After a wrong answer, What went wrong? keeps one idea per bullet and saves automatically.',
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
            'A wrong answer creates an error card with the question, your answer, the correct answer, your bullets and the explanation.',
            'Check I was distracted or read too fast to remove a new card. Uncheck it to restore the card. A distracted re-test keeps an older card due and warns you in review.',
            'The review shows the same feedback as practice, with read-only bullets and the notes saved for the question. Each note has a three-dot menu to copy it, create a card from it, define it, or ask about it when a provider is set. Notes are deleted from Cards, not from a review.',
            'Create cards is the floating card button above the shared bottom dock. It opens as a bottom sheet, so the feedback stays visible above it.',
            'A read-only bullet has a three-dot menu with Copy and Create card with AI, which seeds Create cards from it. With AI it drafts the front and back; without AI it fills the front and asks you to write the back. In practice the bullets stay editable and have no Copy or Create card menu.',
            'The review does not edit the question or options.',
            'Add cards to the list by hand one at a time, then save them together with Save in the dock. No AI provider is needed.',
            'Drafts and typed text stay with their item when the sheet closes or you move between steps. Save asks you to add a typed card to the list first; leaving the last step asks before discarding anything.',
            'The dock has no Create or Delete button. Save creates the listed cards and moves on. The back and forward arrows move between steps and disable at the first and last item. Save on the last item reads Save and finish.',
            'Five templates write the front and back: Definition, Contrast, Cause and effect, Scenario and rule, and Steps. Selecting one fills the empty fields, and your own text is kept.',
            'The sparkle icon beside the template shows optional AI suggestions when a provider is set. Each idea offers up to three variants; keep the ones that help and add them to your list. The retry icon asks again and keeps your drafts.',
            'Card quality shows the estimated reading time and flags yes/no questions, long fronts, long cards, answer clues, template mismatches and missing fields. It never blocks saving.',
            'A Definition card uses a raw cloze: put the term in {{c1::…}} and the definition in {{c2::…}}. Both are required before it can be added.',
            'Topic and subtopic are saved as Anki tags, never inside the card text.',
            'Review opens fullscreen. Missing details can be completed later from Cards.',
          ],
        ),
        const _Section(
          number: '05',
          title: 'Past errors',
          points: [
            'Wrong answers wait 48 hours before they are offered again.',
            'A correct answer resolves the card and keeps it in history.',
            'A wrong answer schedules the next attempt 48 hours later and makes the card reviewable again.',
            'Distraction on a re-test does not resolve the card.',
          ],
        ),
        const _Section(
          number: '06',
          title: 'Cards',
          points: [
            'Cards holds concepts, basic cards, error and skipped questions, and notes.',
            'Filter by All, Cards, Errors or Notes. Cards groups concepts and basic cards; Errors also includes skipped questions. The visibility action includes exported cards. The ? icon opens a short guide to Cloze and Basic cards, tags, decks and what stays in Question Practice.',
            'Long-press a card to select it. While selection is active, a tap toggles that card. Tap the selected rows again to clear the selection; there is no separate clear action. Rows have no checkboxes or action icons.',
            'Select all sits on the right below the filters and selects what the current filter shows; each section header has its own select-all icon. The selection starts empty and survives leaving Cards and restarting the app.',
            'Review all pending sits beside Select all on the right. It opens every pending error and skipped question, even ones not selected. Items you finish leave the selection.',
            'The main action exports ready cards. When selected items still need review it becomes Review pending and opens that review instead.',
            'Tap a card to preview it. Error and skipped previews include Review. A concept without a definition can be completed from its preview.',
            'Errors are reviewed into atomic cards first; skipped questions stay in Cards until converted.',
            'Delete selected removes the chosen cards, skipped questions and notes. A deleted note leaves cards already made from it in place.',
            'A deleted skipped question leaves the queue but stays in its practice.',
            'Tap a note to open Note preview with its selectable text and question context. Close returns to Cards and Review opens the note review. The Notes header saves every note as plain text or selects the note rows.',
          ],
        ),
        const _Section(
          number: '07',
          title: 'Notes',
          points: [
            'Select text during practice and choose Save as note.',
            'Notes stay in Cards. Tap one to open Note preview with its selectable text and question context; Review opens the note review and See context shows the original question and your attempt.',
            'Create cards opens the same sheet: add cards by hand one by one, or use the sparkle icon beside the template for AI suggestions when a provider is set.',
            'Notes are deleted from Cards, never from a review. A note with a card keeps its saved text until you delete it there.',
            'The download and select-all icons in the Notes header save notes as plain text or select the note rows. Notes are never sent to AnkiDroid.',
          ],
        ),
        const _Section(
          number: '08',
          title: 'AnkiDroid export',
          points: [
            'Export to AnkiDroid sends the selected cards to AnkiDroid.',
            'Concepts use the Cloze note type. Contrast, Cause and effect, Scenario and rule, and Steps cards use the Basic note type with Front and Back.',
            'Cards carry question-practice, topic::<topic> and subtopic::<subtopic> tags. Those tags are never written inside the card text.',
            'File exports put tags in a third column. Map that column to Tags when importing; if an app ignores it, the tags are dropped rather than placed in the text.',
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
            'The insights icon opens Statistics: latest, best, question-weighted average, progress over time and a weighted trend line over questions answered.',
            "A topic's Readiness is the correct share of its last 100 answered questions, including wrong and skipped answers.",
            'Long-press a completed session to select it, tap more to toggle them, then delete the selected sessions with their answers, cards, notes and skipped records.',
            'Learning rate shows percentage points per 100 questions and per week. It appears as soon as two sessions give a usable fit.',
            'Long-press a subtopic to select it. One selected category can be renamed or deleted; two or more can be merged.',
            'Renaming changes only this topic. Deleting keeps every question and moves it to Uncategorized. Merge picks one name for all selected categories.',
            'The share icon exports the visible statistics as JSON, including the regression slope and both learning rates.',
          ],
        ),
        const _Section(
          number: '11',
          title: 'Lookup and Ask',
          points: [
            'Select text, then Define, to save a missing concept.',
            'Web search opens DuckDuckGo or Wikipedia and keeps an editable definition sheet.',
            'AI writes a short definition and saves it automatically. Configure the provider, model and key in Settings.',
            'Ask sends the selected passage to AI. Create cards opens with its answer filled in.',
            'Only the selected text, question and topic are sent, and only when you use Define or Ask.',
          ],
        ),
        const _Section(
          number: '12',
          title: 'Backup and data',
          points: [
            'Settings → Data exports one backup with topics, practices, questions, sessions, answers, cards, notes and settings.',
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
            'Shuffled practice uses every topic and asks how many questions to include (default 15).',
            'It keeps only questions that are neither solved nor skipped, and shuffles questions and alternatives.',
            'Asking for more includes all eligible questions; if none are eligible, it says so.',
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
