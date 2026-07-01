# Cangjie code-table / ordering selector (第三代 · 第五代 · Yahoo! KeyKey 原版)

**Issue:** [#30](https://github.com/teddychan/yahoo-keykey-2/issues/30)
**Date:** 2026-07-02
**Status:** Approved design → implementation

## Problem

KeyKey ships only the Cangjie **5th-generation** decomposition table
(`Resources/cangjie.txt`, from `ibus-table-chinese/tables/cangjie/cangjie5.txt`),
and orders candidates by the McBopomofo language-model rank. Issue #30 raises two
things: (1) the associated-phrase ordering does not match Yahoo, and (2) long-time
Yahoo! 輸入法 users want the 3rd-generation 拆碼 (decomposition) back.

After investigation the owner refined this to: let the user pick among **three
code-table / ordering profiles** — standard 3rd-gen, standard 5th-gen, and the
**original Yahoo! KeyKey** table with its own native candidate ordering.

## Scope

**In scope:** one user setting selecting the Cangjie *code table + candidate
ordering* for both the 倉頡 and 速成 engines, with three profiles.

**Out of scope (with reasons):**
- **A separate associated-phrase (聯想) ordering setting.** Dropped. The Yahoo
  association ranking cannot be reproduced: the ranking corpus (`SinicaCorpus`,
  `YahooSearchTerms`, `BPMFMappings`) was never open-sourced (`.gitignore`d
  README placeholders in `bency/YahooKeyKey`), and the runtime used a **commercial
  encrypted SQLite (CEROD)** database. The only phrase data present is tiny curated
  addenda (`FrequentPhrases.txt` ~40 flat items; `Keke-AddBigram.txt` ~40 bigrams)
  with no usable ranking. `bpmf-ext.cin` is single-character phonetic, not phrases.
  A "Yahoo 原版" association option would therefore be fake. The finding will be
  recorded on issue #30. Current McBopomofo associations are kept unchanged.
- **Cangjie 4th generation.** No distributable v4 table exists upstream.

## Decisions (confirmed with owner)

1. One setting, three profiles: `第三代` · `第五代` · `Yahoo! KeyKey 原版`.
2. **Default = `Yahoo! KeyKey 原版`.** This changes candidate order (and some
   decompositions/coverage) for existing users on update — intended (the app's
   reason for being is Yahoo fidelity); called out in CHANGELOG + About.
3. Profiles drive **both** 倉頡 and 速成 (one control).
4. `Yahoo! KeyKey 原版` uses the original tables' **native line order** as the
   candidate order (no LM re-ranking). `第三代`/`第五代` keep the standard
   McBopomofo LM ranking, as today.
5. **User-learning stays ON for all three profiles** (a live personalization
   layered on top of the base order; orthogonal to profile choice).
6. Live reload on change (no IME reselect/restart).
7. Control lives in the **Settings ▸ 輸入方式** tab only.
8. Data files: **commit the converted files** + document conversion commands
   (matches the existing v5 `cangjie.txt` handling). No converter script.
9. Second (聯想) sorting setting: **dropped** (see Scope).

## Data files

All converted to the existing `<code>\t<char>` (Cangjie) / `<quickcode>\t<char>`
(Simplex) format the engines already parse; header + trailing frequency columns
dropped; **line order preserved** (it is the native candidate order).

| Profile | Cangjie table | Simplex table | Source |
|---|---|---|---|
| 第三代 | `Resources/cangjie3.txt` (new) | derived from `cangjie3.txt` | ibus `cangjie3.txt` |
| 第五代 | `Resources/cangjie.txt` (existing) | derived from `cangjie.txt` | ibus `cangjie5.txt` |
| Yahoo! KeyKey 原版 | `Resources/cangjie-yahoo.txt` (new) | `Resources/simplex-yahoo.txt` (new) | `bency/YahooKeyKey` `DataTables/cj-ext.cin`, `simplex-ext.cin` |

- v3/v5 Simplex is derived from the Cangjie table via `SimplexTable(cangjie:)`
  (first+last radical → quick code), as today.
- Yahoo Simplex loads `simplex-ext.cin` **directly** as already-quick-coded
  entries, preserving its native order (does not re-derive from Cangjie).
- Licensing: `cj-ext.cin`/`simplex-ext.cin` derive from opendesktop.org.tw's
  `cj.cin`/`simplex.cin` (work by yylin & b6s), released within the New-BSD Yahoo!
  KeyKey project. **Caveat to flag:** those two `.cin` headers carry no explicit
  per-file license line (unlike `bpmf-ext.cin`'s "Public Domain"); we rely on the
  project's BSD release + OpenVanilla-community origin. `CANGJIE-DATA-LICENSE.txt`
  will document provenance, attribution, and this caveat.

## Components

### Preferences (`App/Preferences.swift`)
- `enum CangjieVersion: String { case v3 = "3"; case v5 = "5"; case yahoo = "yahoo" }`.
- `static var cangjieVersion: CangjieVersion` (UserDefaults key `"cangjieVersion"`;
  unknown/missing → `.yahoo`).
- Register default `"cangjieVersion": "yahoo"`.

### SimplexTable (`Packages/KeyKeyEngine/.../SimplexTable.swift`)
- Add an initializer that loads **already-quick-coded** `<quickcode>\t<char>` lines
  directly (no first+last re-derivation), preserving order — for `simplex-yahoo.txt`.
  Keep the existing `init(cangjie:)` and test `init(text:)` unchanged. Name the new
  one unambiguously (e.g. `init(quickCodeText:)`).

### SharedResources (`App/SharedResources.swift`)
- `cangjieTable`, `simplexTable` → `private(set) var`. Add `private(set) var
  cangjieRank: [Character: Double]` — the effective single-char rank the engines
  use: the LM `characterRank` for v3/v5, or `[:]` for Yahoo (empty → engine's
  stable sort preserves native table order).
- `private func loadCangjieTables(version:)`:
  - Picks the Cangjie resource file per profile; fail-safe to empty table if missing.
  - Builds `simplexTable`: v3/v5 → `SimplexTable(cangjie:)`; Yahoo →
    `SimplexTable(quickCodeText:)` from `simplex-yahoo.txt` (fail-safe to
    derive-from-cangjie if that file is missing).
  - Sets `cangjieRank = (version == .yahoo) ? [:] : characterRank`.
- `init` calls it with `Preferences.cangjieVersion`.
- `func reloadCangjieTables()`: re-reads the preference, rebuilds the three, posts
  `.cangjieVersionChanged`.
- `extension Notification.Name { static let cangjieVersionChanged }`.

`characterRank` (the full LM rank) is still computed once at init and retained so
switching back to v3/v5 needs no LM rebuild.

### InputController (`App/InputController.swift`)
- Both module `makeEngine` closures read `SharedResources.shared.cangjieTable`,
  `.simplexTable`, and **`.cangjieRank`** live (instead of capturing copies).
  `userRank` (user-learning) capture is unchanged → learning stays on for all.
- Observe `.cangjieVersionChanged` (added in `init`, removed in `deinit`): commit
  any in-progress composition, reset `candidatePage`/`associations`, hide the
  candidate window, then `engine = currentModule.makeEngine()` — the same reset
  path `setValue(_:forTag:client:)` already uses on a mode switch.

### SettingsWindow (`App/SettingsWindow.swift`)
- In `inputMethodsView()`, add a labeled `NSPopUpButton` "倉頡碼表／排序" with items
  第三代 / 第五代 / Yahoo! KeyKey 原版 (tag ↔ `CangjieVersion`), reflecting the
  current preference.
- On change: set `Preferences.cangjieVersion`; call
  `SharedResources.shared.reloadCangjieTables()`.
- Retain the popup; set its selection in `refreshControls()` (menu-sync parity).
- Short 說明 label: applies immediately; affects 倉頡 and 速成; Yahoo 原版 uses the
  original candidate order.

### Build & packaging
- `tools/build-app.sh` and `tools/run-debug.sh`: copy `cangjie3.txt`,
  `cangjie-yahoo.txt`, `simplex-yahoo.txt` into `Contents/Resources/` (same
  error-if-missing pattern as `cangjie.txt`).

## Data flow

```
Settings popup change
  → Preferences.cangjieVersion = v3|v5|yahoo
  → SharedResources.reloadCangjieTables()
      → loadCangjieTables(version:)   (rebuild cangjieTable, simplexTable, cangjieRank)
      → post .cangjieVersionChanged
  → each InputController observer
      → commit in-progress composition, reset paging/associations, hide window
      → engine = currentModule.makeEngine()   (reads new shared tables + rank live)
  → next keystroke uses the selected profile's table and ordering
```

## Error handling
- Missing profile data file → fail-safe to empty (Cangjie) or derive-from-cangjie
  (Yahoo Simplex), logged; identical spirit to the current missing-file handling.
- Unknown/absent stored `cangjieVersion` → `.yahoo` (the default).
- Reload **commits** (not discards) any in-progress composition, so switching
  mid-composition never silently drops typed input.

## Testing
- **Cangjie tables:** each bundled table (`cangjie3.txt`, `cangjie.txt`,
  `cangjie-yahoo.txt`) loads non-empty; assert a concrete code→char difference
  proving the three are distinct (e.g. a v5-only pair vs a v3-only pair; a Yahoo
  native-order pair such as `hqi` → 我 first).
- **Yahoo native order:** `CangjieEngine(table: yahooTable, characterRank: [:])`
  returns candidates in table order (我 before its rare `hqi` variants).
- **Yahoo Simplex:** `SimplexTable(quickCodeText:)` parses `simplex-yahoo.txt` and
  preserves native order for a known quick code (e.g. `hi`).
- **Preferences round-trip:** set/read each of `v3`/`v5`/`yahoo`; unknown stored
  value → `.yahoo`.
- Existing CangjieTable / Simplex / engine tests remain green (parsers unchanged;
  new Simplex initializer is additive).

## Docs & release
- **`README.md`:** add the profile table above (Profile · Table (source) ·
  Candidate order) so the mapping is explicit.
- `CHANGELOG.md`: new-feature entry; explicitly note the **default is now Yahoo!
  KeyKey 原版**, changing candidate order for existing users.
- Version bump to **v2.1.0** (additive feature).
- About window note if space allows.
- Issue #30: comment recording why the 聯想 ordering is not reproducible.
- Memory: update `yahoo-keykey-2-project.md`.

## Non-goals / risks
- Not reproducing Yahoo's associated-phrase ranking (data withheld — see Scope).
- Default flip to Yahoo changes existing users' candidate order/coverage on update
  (intended; documented).
- `cj-ext.cin`/`simplex-ext.cin` lack an explicit per-file license line (flagged
  above); provenance + attribution documented in `CANGJIE-DATA-LICENSE.txt`.
- Reload reparses a table (Yahoo cj-ext ~82.9k lines) on an explicit, rare user
  action — acceptable; not on any hot path.
