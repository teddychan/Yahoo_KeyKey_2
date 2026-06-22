# Plan: Sub-project 2 (Tranche A) — Engine Breadth + App Wiring

**Date:** 2026-06-22
**Branch:** `claude/sharp-rubin-81a9dd` (worktree isolation)
**Baseline:** 29/29 engine tests green; Smart Phonetic + Standard layout shipped (sub-project 1).

## Goal

Extend the proven Smart Phonetic engine with the remaining **phonetic layouts**, the
deferred **multi-syllable phrase override**, two **filters**, and the **app wiring** to
select layouts — all TDD'd and reviewed. This is the engine-level breadth of spec
sub-project 2 (input-method breadth — Cangjie/Simplex — and UI surfaces SP3+ are separate).

Source of truth for all layout key maps: **McBopomofo `Mandarin.cpp`** (same lineage the
project already adopted; `StandardLayout` already cites it).

## Success criteria

- All existing 29 tests still pass (no regressions).
- Each new layout has unit tests proving its key map + (for 26-key layouts) disambiguation.
- Multi-syllable override lets a user move the cursor and pick a candidate at any position.
- Filters are pure, tested transforms.
- App builds + ad-hoc signs; layouts selectable; input modes registered; display name shows "Yahoo KeyKey 2".

## Tasks

### Task F — Layout abstraction (FOUNDATION, sequential, must land first)
Introduce `protocol PhoneticLayout { func component(for key: Character) -> Component? }`.
Make `StandardLayout` conform (keep the existing static enum API working OR adapt tests).
Refactor `ReadingBuffer` to hold an injected `PhoneticLayout` (default = Standard), and
`SmartPhoneticEngine` to accept a layout in its initializer (default = Standard).
**Verify:** all 29 existing tests pass unchanged (or minimally adapted), plus a test that a
custom layout injects correctly. No behavior change for the Standard path.

### Task L1 — ETen layout (parallel after F)
New `EtenLayout.swift` conforming to `PhoneticLayout`, full-keyboard direct mapping from
McBopomofo `Mandarin.cpp` ETen table. Unit tests for representative consonants/medials/vowels/tones.
Do NOT register it anywhere yet (integration is Task W).

### Task L2 — Hsu layout (parallel after F)
New `HsuLayout.swift`. Hsu is a 26-key layout with **ambiguous keys** resolved by context
(McBopomofo `Mandarin.cpp` Hsu handling). Implement the disambiguation faithfully. Tests
must cover the ambiguous cases, not just direct keys.

### Task L3 — ETen26 layout (parallel after F)
New `Eten26Layout.swift`. Also 26-key with disambiguation per McBopomofo. Tests cover ambiguity.

### Task M — Multi-syllable phrase override + cursor (after F)
Extend `SmartPhoneticEngine` so candidate selection can target any reading position, not just
the last. Add cursor state (move left/right over the composing readings) and
`candidates(at:)`/`selectCandidate(at:)` semantics. Tests for selecting a non-final syllable
and for the walk respecting it.

### Task FW — Full-width filter (parallel)
New pure filter mapping ASCII printable -> full-width forms; toggleable. Unit tests.

### Task HC — Han conversion TC<->SC filter (parallel)
New pure filter using an open TC<->SC mapping table (OpenCC-style; bundle a compact table).
Document the data source + license in THIRD-PARTY-NOTICES.md. Unit tests for sample chars.

### Task W — App wiring (INTEGRATION, sequential, last)
- Layout registry + selection (IMK input-method menu via `menu(_:)` or input modes).
- Register the layouts/modes in `Info.plist`.
- Add `InfoPlist.strings` (or equivalent) so the input source shows **"Yahoo KeyKey 2"**
  instead of the raw bundle id (fixes the live-test cosmetic bug).
- Rebuild + ad-hoc sign; confirm bundle identity.

## Execution

Subagent-driven: implementer + spec review + quality review per task, fix-loops until green.
F and M and W touch shared engine/app files -> sequential. L1/L2/L3/FW/HC create disjoint new
files -> may run as parallel implementers. Commit after each task.
