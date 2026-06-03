# Puzzle Hub — Project Cache (for Claude)

_Internal reference map of the codebase, written to make future work faster. Not player- or design-facing — for design rules see `GDD.md`. Last synced: 2026-06-01 against v0.2 (incl. Shikaku)._

> Keep this in sync when files move, globals are added, or the boot/save flow changes. If it drifts from the code, the code wins — re-verify before relying on a line here.

---

## 1. What this is

GameMaker (IDE `2026.0.0.16`, runtime `2026.0.0.23` — LTS) mobile daily-puzzle app. Portrait, designed at **1080×1920**. Project file: `Puzzle Hub.yyp` (lives in this folder, which is a sibling of the `Daily Puzzle` reference folder — see auto-memory `project_puzzle_hub_paths`).

Four puzzles implemented — **Anygram**, **Sudoku**, **Word Wave**, **Shikaku** — plus a locked **Mix-Up** placeholder. Economy = XP / Levels / Coins. Full design rules in `GDD.md`.

---

## 2. Directory map

```
Puzzle Hub/
├─ Puzzle Hub.yyp              project manifest (resource + room order list)
├─ GDD.md                      design doc — source of truth for rules
├─ README.md                   short public overview
├─ PROJECT_CACHE.md            (this file)
├─ scripts/                    all shared logic (pure functions, ph_ prefix)
├─ objects/                    screens + puzzle controllers (one per screen)
├─ rooms/                      one room per screen (rm_*)
├─ datafiles/                  shipped at working_directory at runtime
│  ├─ puzzles_anygram.json     date-keyed + seed-fallback puzzle pool
│  ├─ puzzles_sudoku.json
│  ├─ puzzles_wordwave.json
│  ├─ icons/                   ~40 PNGs, loaded via sprite_add in obj_persistent
│  └─ fonts/                   Lilita One (display), Nunito (body)
└─ options/                    per-platform export settings
```

`datafiles/` contents are copied to `working_directory` at runtime, so code reads e.g. `working_directory + "icons/..."` and `working_directory + "puzzles_anygram.json"`.

---

## 3. Scripts (the API surface) — `scripts/`

All functions are global, prefixed `ph_`. No structs-with-methods except inline closures in objects.

| Script | LOC | Holds |
|---|---|---|
| `scr_constants` | 107 | All `#macro`s: palette colors, canvas, **economy numbers**, daily schedule indices, save filename, debug flags. Also `ph_game_cards()` (hub card list). |
| `scr_economy` | 29 | `ph_level_from_xp`, `ph_xp_in_level`, `ph_grant_xp` (returns `{levels_gained, coins_awarded, new_level}`), `ph_grant_coins`, `ph_spend_coins`. |
| `scr_save` | 252 | Load/write/reset save; per-puzzle solved tracking; streak recompute; bonus-word tracking; Sudoku grid persistence. **Central data layer.** |
| `scr_dates` | 44 | Date-key formatting (`ph_today_key`, `ph_date_key`), `ph_seed_from_key` (day-index seed), weekday/month math, `ph_date_add_days`. |
| `scr_puzzles` | 484 | Anygram + Word Wave loaders, normalizers, classifiers, solved checks. Both puzzles' pure logic. |
| `scr_sudoku` | 162 | Sudoku loader, normalizer, conflict/row/col/box/all-solved checks, grid serialize. |
| `scr_shikaku` | ~210 | Shikaku loader, normalizer (clues + solution rects), per-rect correctness, full-partition solution check, state serialize/restore, done flag. |
| `scr_draw` | 181 | Reusable draw helpers: `ph_draw_rounded/chip/text/text_shadow/icon`, easing, `ph_scissor_gui`, hit tests, `ph_draw_nav` (bottom tab bar), `ph_draw_burst`, cached `ph_draw_dot_bg`. |
| `scr_fonts` | 19 | `ph_load_fonts()` — registers all `global.fnt_*` via `font_add`. |

### Key economy/save facts to remember
- Level is **derived**, never stored: `level = floor(xp / 500) + 1`. `ph_grant_xp` handles multi-level jumps and pays `levels_gained × 100` coins.
- `ph_solved_count_on` counts a day's solves but **skips bookkeeping keys** prefixed `ANYGRAM_` and `WW_W` so per-word flags don't inflate the daily count. Adding a new multi-flag puzzle? Add the same skip rule.
- Anygram completion = `ANYGRAM_DONE` (new) or legacy `ANYGRAM_M1 && ANYGRAM_M2`, via `ph_anygram_is_done`. Sudoku = `SUDOKU` key. Word Wave = `WORDWAVE` key.
- Streak recomputed on every save load and after completions via `ph_update_streak`.

---

## 4. Objects (screens & controllers) — `objects/`

Each object owns a screen; logic split across `Create_0` (setup/state), `Step_0` (input/update), `Draw_64` (GUI-space render). Puzzle controllers are the big ones.

| Object | Events (LOC) | Role |
|---|---|---|
| `obj_boot` | Create(5) | Spawns `obj_persistent`, jumps to `rm_hub`. |
| `obj_persistent` | Create(104), CleanUp(43) | **Session manager.** Sets dynamic `PH_H`, iOS safe-area insets, loads fonts + save, configures surface/MSAA/filtering, loads **all sprites** via `sprite_add`. Lives whole session. |
| `obj_hub` | Create(99), Step(175), Draw(401) | Home screen: 7-day strip, collapsible month calendar, scrollable game cards, progress tube. Reads solved-state via `ph_*_is_done`. |
| `obj_anygram` | Create(321), Step(327), Draw(512) | Anygram puzzle: letter wheel, crossword grid, fly-tile anim, hint, bonus modal, win overlay, confetti. Largest controller. |
| `obj_sudoku` | Create(201), Step(166), Draw(267) | 9×9 board, number pad, conflict highlighting, hint, win overlay. |
| `obj_shikaku` | Create, Step, Draw | 6×6 grid, drag-corner-to-corner rectangles, tap-to-delete, shape-glyph hint, win overlay. Blue accent; bottom HUD = coin + hint (no chest), like Sudoku. |
| `obj_wordwave` | Create(221), Step(243), Draw(361) | 8×8 word-search grid, swipe selection, per-word colors, hint, win overlay (centered card). |
| `obj_shop` | Create(2), Step(18), Draw(24) | Shop tab — minimal/stub. |
| `obj_profile` | Create(18), Step(56), Draw(42) | Profile tab + **hidden triple-tap-Level save-reset** gesture. |
| `obj_win` | Create(2), Draw(4) | Near-empty; win UI is drawn inside each puzzle controller, not here. `rm_win` is essentially unused. |

Pattern: each puzzle controller embeds its own win overlay + confetti rather than transitioning to `rm_win`. Review mode re-enters the puzzle room with a `global.*_review_mode` flag and jumps straight to the win overlay.

---

## 5. Rooms — `rooms/`

`rm_boot` (first, per RoomOrderNodes) → `rm_hub`. Then one room per screen: `rm_anygram`, `rm_sudoku`, `rm_wordwave`, `rm_shop`, `rm_profile`, `rm_win`. Each room hosts its matching object.

---

## 6. Global state surface

Set up in `obj_persistent/Create_0`. Most-referenced globals:

**Data / session**
- `global.save` — the entire save struct (89 refs). All progression lives here.
- `global.selected_date_key` — which day the player is viewing/playing (47 refs).
- `global.input_locked_until` — frame-time input lock during animations (20 refs).
- `global.PH_H_dyn` — runtime canvas height (`PH_H` macro reads this).
- `global.safe_top_gui` / `global.safe_bottom_gui` — iOS notch / home-indicator insets.

**Puzzle caches** (lazy-loaded, may be `undefined` sentinel if file missing)
- `global.ph_anygram_cache`, `global.ph_sudoku_cache`, `global.ph_wordwave_cache`.

**Review-mode flags** (jump straight to win overlay)
- `global.anygram_review_mode`, `global.sudoku_review_mode`, `global.wordwave_review_mode`.

**Transient anim**
- `global.fly_tiles` — shared fly-tile particle list (22 refs, Anygram).
- `global.ph_dot_surface` — cached dotted-background surface.

**Assets** — `global.fnt_*` (fonts), `global.spr_*` (all sprites). Loaded once in persistent.

---

## 7. Data file formats (authoring)

- **Anygram** (`puzzles_anygram.json`): array. New shape `{letters:[5], words:[{text,row,col,dir("H"|"V")}], bonus|bonus_pool:[...], date?, grid_size?}`. Legacy 2-word shape still accepted. Date selection: exact `date` match wins, else `seed mod length`.
- **Sudoku** (`puzzles_sudoku.json`): array of `{date?, difficulty?, givens:"81 chars (0=blank)", solution:"81 chars"}`, row-major.
- **Word Wave** (`puzzles_wordwave.json`): array of `{date?, grid:[8×"8 chars"], words:[{text,row,col,dir}], bonus_pool:[...]}`. `dir` ∈ H/H_REV/V/V_REV/DR/DL/UR/UL. Each word and bonus word must trace a straight line on the grid.

All three: missing file → hardcoded fallback puzzle. Same two-pass date selection.

---

## 8. Conventions & gotchas

- **No struct literals with non-constant fields.** GameMaker's YYC compiler generates anonymous C++ constructors for non-constant expressions inside struct literals, which can cause **linker errors**. Build such structs with explicit property assignment (see `obj_hub/Create_0` `LAYOUT` and `hub_center_strip_on`). Related: adding resources can trigger a YYC link failure fixed by a **Clean rebuild**, not code changes (auto-memory `project_puzzle_hub_yyc_clean_rebuild`).
- **All gameplay numbers are `#macro`s in `scr_constants`.** Change them there and reflect in `GDD.md`. Never hardcode economy values.
- **`PH_SUDOKU_TEST_PREFILL = true`** in `scr_constants` — debug flag that starts Sudoku ~90% solved. **Must be `false` before shipping.**
- **`PH_BONUS_WORD_XP = 25`** is dead (bonus words pay coins only, no XP). Safe to delete.
- **Drawing is GUI-space** (`Draw_64` / GUI events), sized to `PH_W × PH_H_dyn` via `display_set_gui_size`. Use `ph_scissor_gui` (converts GUI→window px) for clipping, not raw `gpu_set_scissor`.
- **Save path at runtime:** `working_directory + "puzzlehub_save.json"`. When run from the IDE on macOS it lands at `~/Library/Application Support/com.yoyogames.macyoyorunner/puzzlehub_save.json` (auto-memory `project_puzzle_hub_save_path`).
- **Save is forward-compatible:** `ph_save_load` backfills missing fields. Add new fields with a default backfill there.
- **Desktop vs mobile canvas:** mobile derives height from real screen ratio; desktop forces 1920 and letterboxes (see `obj_persistent/Create_0` comment).
- Sprites are mostly white-on-transparent and **tinted at draw time** via `ph_draw_icon`; full-color icons drawn with `c_white`.

---

## 9. Where to make common changes

| Task | Go to |
|---|---|
| Tune XP/coins/hint cost | `scr_constants` (macros) + update `GDD.md` |
| New puzzle solved-tracking | `scr_save` (`ph_mark_*` / `ph_*_is_done`, add skip rule in `ph_solved_count_on`) |
| Add/author puzzles | `datafiles/puzzles_*.json` |
| Hub layout / calendar / cards | `obj_hub` (`LAYOUT` struct in Create) |
| Shared UI widgets (chips, nav, text) | `scr_draw` |
| Fonts / sprites | `scr_fonts` / `obj_persistent/Create_0` |
| Win screen / confetti | inside each puzzle controller's Draw/Step (not `obj_win`) |
| New screen | new `obj_*` + `rm_*`, register in `.yyp`, wire nav in Step events |

---

## 10. Repo / versioning

Private repo `github.com/bhogha/Puzzle-Hub`. Tag `v0.1` = rollback baseline; current dev = `0.2` (auto-memory `project_puzzle_hub_github`, `project_puzzle_hub_version`).
