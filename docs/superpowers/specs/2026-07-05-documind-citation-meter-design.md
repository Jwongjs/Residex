# Documind Citation Duplication Fix + Emoji Cleanup (Design)

**Date:** 2026-07-05
**Status:** Approved, pre-implementation
**Scope:** Item 3 from `HANDOFF.md` section 4 ("why is there another pop up that displays the same output as shown in the chatbot") plus the new standing rule: no emojis anywhere in this app — use icons instead.

---

## 1. Background

`documind_screen.dart` currently shows every AI answer twice whenever it has citations:

- **Chat bubble** (`buildDocuMindAssistantText` in `documind_chat_logic.dart`) — the full `answer.answer` text, plus a plain-text `Sources:` list (filename, category, page) for up to 3 citations.
- **Certified-extract card** (`_buildCertifiedExtractCard`) — a fixed card pinned above the chat list, showing the *same* `answer.answer` text again, plus the *same* citations again (filename/page) with an added visual relevance-score bar per citation. Only shown for the latest turn (`_lastAnswerForCard`), gated by `shouldRenderAsCertifiedExtract` (true whenever `answer.citations.isNotEmpty`).

This is the "pop up that displays the same output" the user flagged. The only genuinely new information in the card is the relevance-score bar (`citation.score`, the cross-encoder rerank score — how well that source page matches the specific question asked, recomputed per question).

An initial design assumed `dash_chat_2` 0.0.21 has no way to attach a custom widget to a specific message (matching an earlier, incorrect note in `HANDOFF.md`). That assumption was wrong: inspecting the installed package (`dash_chat_2-0.0.21`) shows `MessageOptions.bottom` — a builder rendered directly under a specific bubble's content — and `ChatMessage.customProperties`, a free-form map for attaching per-message data. Together these let the relevance meter live attached to the exact AI bubble it belongs to, for every historical turn, not just a pinned card for the newest one.

Separately, the user set a standing rule: no emojis anywhere in this app going forward, including retroactively — use icon glyphs instead. This pass folds in the emoji cleanup for the file being touched, plus the app's other clearly UI-facing emoji usages.

---

## 2. Citation duplication fix

### Changes
- **Remove entirely:** `_buildCertifiedExtractCard`, `_buildCitationLine`, `_lastAnswerForCard`, `shouldRenderAsCertifiedExtract` (in `documind_chat_logic.dart`), and the call site in `_buildChatInterface()`.
- **Attach citations to the message:** in `_consumeAnswer`, when constructing the AI's `ChatMessage`, set `customProperties: {'citations': answer.citations}` (only when `answer.citations.isNotEmpty`; omit/null otherwise).
- **Remove the plain-text sources block** from `buildDocuMindAssistantText` — delete the sources section entirely (see section 3 for the icon/emoji cleanup of the rest of that function). The relevance-meter widget becomes the single place citations are shown.
- **Add `MessageOptions.bottom`** to the `DashChat` widget in `_buildChatInterface()`:
  ```dart
  bottom: (message, previousMessage, nextMessage) {
    final citations = message.customProperties?['citations'] as List<Citation>?;
    if (citations == null || citations.isEmpty) return const SizedBox.shrink();
    return _buildRelevanceMeter(citations);
  },
  ```
- **New widget `_buildRelevanceMeter(List<Citation> citations)`**: a slim card (white `card` background, `hairline` border, rounded corners, small padding) directly under the bubble it belongs to, containing:
  - A small header row: an icon (e.g. `Icons.verified_outlined` or `Icons.fact_check_outlined` — pick one at implementation time, not emoji) + "SOURCE RELEVANCE" label (`labelSmall` style, `registry` color)
  - One row per citation (max 3, matching the prior cap): `filename · p.N` (monospace, `textMuted`) + the same thin relevance bar (`hairline` track, `registry` fill, `widthFactor: citation.score.clamp(0.0, 1.0)`) reused from the deleted `_buildCitationLine`

### Result
Each AI message with citations shows its answer text once (in the bubble) and its relevance meter once (attached directly under that same bubble). Works identically for every message in history as the user scrolls back — an improvement over the old pinned-card approach, which only ever showed the latest turn.

### Out of scope
No change to how the score itself is computed or normalized (flagged separately: the cross-encoder score is unbounded and today's `.clamp(0.0, 1.0)` can make the bar look flatter/fuller than the real spread — not part of this fix).

---

## 3. Emoji → icon cleanup

Per the new standing rule (no emojis, use icons; applies retroactively), clean up both user-facing strings and code comments in the files touched by this work.

### User-facing strings
| File | Current | Change |
|---|---|---|
| `documind_chat_logic.dart:55` | `'\n\n✅ Reply with \`confirm\` or \`cancel\`...'` | Drop the emoji; keep the text as plain instructional copy (no icon substitute needed — it's inline chat text, not a label with an icon slot) |
| `documind_chat_logic.dart:80` | `'\n\n🏷️ Categories: ...'` | Drop the emoji; keep as plain text (`Categories: ...`) |
| `documind_chat_logic.dart:9,84` | sources regex/string markers | Removed as part of deleting the sources block entirely (section 2) |
| `documind_screen.dart:957` | `_showSnackBar('✅ Document uploaded successfully!')` | Drop the emoji from the string; the snackbar's existing background color (`AppColors.success`) already carries the success signal. Optionally add a leading `Icon(Icons.check_circle_outline)` to `_showSnackBar`'s `SnackBar.content` when `!isError`, and `Icons.error_outline` when `isError`, for a consistent icon treatment across both cases. |
| `documind_screen.dart:1091` | `_showSnackBar('✅ Document deleted successfully!')` | Same as above |
| `documind_screen.dart:1364` | `text: '❌ Error: ${e.toString()}'` | Drop the emoji from the message text |

### Code comments
| File | Current | Change |
|---|---|---|
| `documind_screen.dart:738,750,867,877,882,889,895,928,937,946,949,1079` | comments with a leading emoji marker | Remove the emoji prefix from each comment, keep the comment text as-is |

### Out of scope
Emoji elsewhere in the app outside `documind_screen.dart` / `documind_chat_logic.dart` (if any) are not part of this pass — only the files already being touched for the citation fix. A broader app-wide emoji sweep can be a separate quick task if the user wants one later.

---

## 4. Testing / verification

- `flutter analyze` — expect to stay at the current baseline (0 errors); removing the certified-extract card and its dead citation-score usage should not introduce new issues.
- Manual run: ask a question that returns citations, confirm the relevance meter appears directly under that AI bubble (not as a separate pinned card), confirm it persists correctly when scrolling back through history, confirm messages without citations (or user messages) show no meter. Confirm upload/delete snackbars and error text no longer show emoji.
- No backend changes; no test suite impact expected.
