# Testing

## Automated

```bash
flutter analyze
flutter test
```

The suite runs on the Dart VM. Drift uses an in-memory SQLite database; HTTP and browser calls use fakes.

| Area | Coverage |
|---|---|
| Import | Schema rejection, JSON syntax paths, BOM/text files, semantic validation, `correctIndex`, `correctIndexes`, optional subtopics, duplicate handling, size limit |
| Practice | Scoring, multi-answer set matching, skipped answers, distraction checked and unchecked after feedback, resume/discard, mixed sessions, summary counts, session arrows, done/solved/skipped history, shuffled inclusion, redo prompt, done tag |
| Practice edit | JSON export with stable question identities, diff counts for unchanged/modified/new/deleted, prompt fallback without identities, reworded questions with identities, wrong practice rejection, answers and cards preserved across apply, deleted-question cascade, edit menu and update preview Apply/Cancel |
| Error queue | Exact 48-hour boundary, due query, resolution, history, wrong retry scheduling |
| Review | Error steps, shared error-card review view, skipped concept/basic branches, missing definitions, AI bias/vaccine suggestions, structured skipped/unknown review with reasoning and other alternatives |
| Highlights | Highlight persistence, painted phrases, keep/convert review steps, highlights in Cards, plain-text download |
| Ask | AI request carries passage/context/message, plain-text answer, ask sheet and card action |
| Cards browser | Combined error and skipped section with checkboxes and pencils, unified review all/selected, formatted previews, filters, editor switches between concept and basic fields |
| Past errors | Due queue and resolved history collapsed by default, review action above the list |
| Settings | AI key handling, data actions keep visible labels |
| Skipped queue | Persistence across the session, unknown toggle, early finish, late reasoning, combined Cards section and conversion |
| Lookup | OpenAI-compatible and Gemini requests, AI JSON parsing, fenced JSON, 401 fallback, missing key/model, provider model lists, web URL selection, auto-saved concepts |
| Export | Cloze format, HTML/cloze escaping, six error fields, distractor explanation, multi-answer fields, TSV content, per-topic deck routing, default deck fallback, permission/status failures, partial failures |
| Data | Topic/practice summaries, accuracy/progress, due counts, unfinished sessions excluded, archive filtering, per-topic sort settings, subtopic grouping, deletion cascades through statistics |
| Statistics | Regression line math (flat, upward, downward, fewer than two points), weekly learning rate and its one-week threshold, per-subtopic stats with Uncategorized, JSON statistics payload and share action |
| Widgets | Empty home, multiple paused sessions, help, topic list, topic details, topic long-press edit/archive/delete, archived-topics sheet, topic and practice sort persistence, shuffle FAB start sheet, question feedback/explanation, question arrows, distraction checkbox in feedback, five-minute reminder, sample import, subtopic statistics section and its hidden state, statistics export button |

## Manual Android checklist

Use the connected Pixel 9 Pro XL (Android 17) and AnkiDroid 2.25.3.

1. Fresh install; open Help from the `i` icon.
2. Import the sample; confirm two topics and eight questions.
3. Import a file with `correctIndexes`; confirm checkboxes and that a partial selection fails while the complete set passes.
4. Start a practice; answer one correctly, one wrongly and skip one.
5. Confirm feedback stays on the same screen and every alternative expands. Use the top arrows to move forward and back.
6. Submit a wrong answer; check “I was distracted or read too fast” in the feedback; confirm the new error card disappears. Uncheck it; confirm the card returns. Then check “I didn’t know this”; confirm the card disappears, the answer counts as skipped and the review asks for a concept.
7. Close another session and choose **Save for later**; confirm Home lists each paused session.
8. Finish; confirm the score and looked-up count.
9. Complete the error review: bias, vaccine, concept card and basic card.
10. Open Cards; confirm the Show exported filter chip, select an incomplete error card and confirm export is replaced by Review selected. Complete it and confirm export returns.
11. Complete one error card with **Complete**, then try **Review all** at the top of the error section and **Review selected**.
12. Preview, deselect and delete a card.
13. Set a topic's deck from the live AnkiDroid list (or type a new deck), export, and verify cards land in that deck while a blank topic uses the default. Use **Browse decks** in Settings for the default deck.
14. Export to AnkiDroid; verify the deck, Cloze model, six-field `Question Practice: Error v2` model and basic note type.
15. Delete `Question Practice: Error v2` in AnkiDroid and export again; confirm it is recreated.
16. Use Define with web mode; confirm the Custom Tab opens and the editable definition sheet still appears.
17. Configure OpenAI or Groq, load models, save the key, and test one definition. Confirm it appears in a read-only bubble and is saved without a Save button. Define an acronym such as SRE and confirm the bubble shows the full form under “Stands for”.
18. In an error card review, write bias and vaccine and use “Check with AI”; confirm feedback appears without leaving the review.
19. Configure Gemini, load models, and test one definition.
20. Seed an old error (or use a clock override in development), confirm it is hidden until 48 hours and resolves after a correct answer.
21. Try selecting text in a prompt, alternative and explanation; confirm Define appears. Confirm an http(s) link opens.
22. On a fresh install, confirm wallpaper colors are on; toggle them off and back on. Check dark mode.
23. Set the font scale to 2.0; confirm no overflow on home, session, review and cards.
24. Erase all data; confirm topics, cards, settings and key are gone.
25. On Home, use the sort icon for name/recency and both directions; restart the app and confirm the order is kept.
26. Long-press a topic and open **Edit topic**; save a change. Long-press it again and choose **Archive topic**; confirm it leaves Home. Open the archived-topics icon, unarchive the topic, and confirm it returns with its practices intact.
27. Open two topics, choose a different practice sort in each (for example Name decreasing and Recency increasing), leave and reopen them, then restart the app; confirm each topic keeps its own order.
28. Tap the **Shuffle** floating button; confirm the **Start shuffled practice** sheet lists the options and starts a mixed session. Solve or skip every question, then tap Shuffle again and confirm the no-questions message appears.
29. Long-press a practice and open **Edit practice**; rename it, change its description and pick a deck. Download its JSON, change a question, add one and remove one, then update from that file. Confirm the preview counts, apply, and verify answers/cards for matched questions survive while the removed question's records are gone.

## Notes

- Widget tests use `TestHarness` with an in-memory database and an `UncontrolledProviderScope` that is disposed before the test ends. This flushes Drift stream-cancellation timers.
- `pumpAndSettle` is avoided where a page contains a continuous M3E animation; bounded frame pumps are used instead.
- No golden tests: font and engine changes make them noisy. Semantics and layout assertions cover the important UI contracts.
