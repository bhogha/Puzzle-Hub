# Puzzle Hub — Project Cache (for Claude)

_Internal reference map of the codebase, written to make future work faster. Not player- or design-facing — for design rules see `GDD.md`. Last synced: 2026-06-05 against v0.2 (incl. Wordle — 5th puzzle with custom keyboard + loss/lost-aversion flow, Shikaku, shared hint modal + rewarded-video flow, Level-Up reward screen)._

> Keep this in sync when files move, globals are added, or the boot/save flow changes. If it drifts from the code, the code wins — re-verify before relying on a line here.

---

## 1. What this is

GameMaker (IDE `2026.0.0.16`, runtime `2026.0.0.23` — LTS) mobile daily-puzzle app. Portrait, designed at **1080×1920**. Project file: `Puzzle Hub.yyp` (lives in this folder, which is a sibling of the `Daily Puzzle` reference folder — see auto-memory `project_puzzle_hub_paths`).

Five puzzles implemented — **Anygram**, **Sudoku**, **Word Wave**, **Shikaku**, **Wordle** — plus a locked **Mix-Up** placeholder. Economy = XP / Levels / Coins. Full design rules in `GDD.md`. **Wordle is the only puzzle that can be lost** (out of guesses → consolation XP + "missed" state); see `WORDLE_PLAN.md` for its phased build.

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
| `scr_economy` | 44 | `ph_level_from_xp`, `ph_xp_in_level`, `ph_grant_xp(save, amt, _auto_coins=true)` (returns `{levels_gained, coins_awarded, new_level}`; pass `false` to **defer** level-up coins to the Level-Up screen), `ph_grant_coins`, `ph_spend_coins`, `ph_levelup_pending()`. |
| `scr_hint` | ~200 | **Shared hint-acquisition flow** (modal + placeholder rewarded video), struct-based, reused by all 5 puzzles. `ph_hint_create(apply_method, accent)` → struct; `ph_hint_open/tick/input/is_open`; `ph_hint_draw_feedback/modal/video`. `ph_input` returns `"none"/"consumed"/"paid"/"freed"/"poor"`. Also the **generic** `ph_video_overlay(timer, delay, accent)` dark "VIDEO PLAYING" placeholder (shared by hint + Level-Up + Wordle lose screens). |
| `scr_save` | ~300 | Load/write/reset save; per-puzzle solved tracking; streak recompute; bonus-word tracking; Sudoku grid + Wordle state persistence; `WORDLE_MISSED` skip in `ph_solved_count_on`. **Central data layer.** |
| `scr_dates` | 44 | Date-key formatting (`ph_today_key`, `ph_date_key`), `ph_seed_from_key` (day-index seed), weekday/month math, `ph_date_add_days`. |
| `scr_puzzles` | 484 | Anygram + Word Wave loaders, normalizers, classifiers, solved checks. Both puzzles' pure logic. |
| `scr_sudoku` | 162 | Sudoku loader, normalizer, conflict/row/col/box/all-solved checks, grid serialize. |
| `scr_shikaku` | ~210 | Shikaku loader, normalizer (clues + solution rects), per-rect correctness, full-partition solution check, state serialize/restore, done flag. |
| `scr_wordle` | ~190 | Wordle pure logic: answer + validation-list loaders/caches, two-pass date select, `ph_wordle_make`, `ph_wordle_score_guess` (green/yellow/gray dup logic), `ph_wordle_is_allowed`, `ph_wordle_add_guess` (win/loss), `ph_wordle_grant_extra_moves`, `ph_wordle_keyboard_states`, guess serialise. Save-struct helpers (is_done/mark/is_missed/state) live in `scr_save`. |
| `scr_draw` | 181 | Reusable draw helpers: `ph_draw_rounded/chip/text/text_shadow/icon`, easing, `ph_scissor_gui`, hit tests, `ph_draw_nav` (bottom tab bar), `ph_draw_burst`, cached `ph_draw_dot_bg`. |
| `scr_fonts` | 19 | `ph_load_fonts()` — registers all `global.fnt_*` via `font_add`. |

### Key economy/save facts to remember
- Level is **derived**, never stored: `level = floor(xp / 500) + 1`. `ph_grant_xp` computes `levels_gained × 100` coins, but the four `*_check_win` now call it with `_auto_coins=false` so the level-up coins are **deferred** to the **Level-Up reward screen** (`obj_win`/`rm_win`). On level gain they set `global.pending_levelup = {level, base_reward:100}`; the screen grants 100, or 200 if the player picks DOUBLE (placeholder video). Only 1 level-up possible per puzzle (100 XP grant vs 500/level).
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
| `obj_wordle` | Create(~330), Step(~110), Draw(~175) | 6×6 board, **custom on-screen keyboard** (slot-based active row so a hint locks a position), staggered reveal, shared hint (`wd_apply_hint`/`wd_can_hint`), win via shared `ph_win_*`. **Loss flow is self-contained here:** `lose_phase` ∈ `none/aversion/confirm/screen` with `wd_lose_step/input/draw`; buy/free +3 moves (board grows to 9 rows, cells shrink), UNLUCKY screen grants 25/50 XP via `wd_lose_claim`. Green accent; HUD = coin top-right, timer+hint bottom bar. |
| `obj_shop` | Create(2), Step(18), Draw(24) | Shop tab — minimal/stub. |
| `obj_profile` | Create(18), Step(56), Draw(42) | Profile tab + **hidden triple-tap-Level save-reset** gesture. |
| `obj_win` | Create, Step, Draw | **Level-Up reward screen** (in `rm_win`). Repurposed from the old dead win-overlay stub. Reads `global.pending_levelup`, shows a purple card ("LEVEL UP!" + "LEVEL N" + confetti) with **100** / **DOUBLE** pill buttons; grants coins (`lu_claim`), clears the flag, `room_goto(rm_hub)`. DOUBLE → `ph_video_overlay` 5 s → 200 coins. NB: its video flag is `vid_open` because `video_open` is a reserved built-in. |

Pattern: each puzzle controller embeds its own **win overlay** + confetti (not `obj_win`); review mode re-enters the puzzle room with a `global.*_review_mode` flag and jumps straight to the win overlay. The **Level-Up screen** is the one thing that lives in its own room: each puzzle's win-screen BACK button does `room_goto(ph_levelup_pending() ? rm_win : rm_hub)`.

**Shared hint flow (all 4 puzzles):** each controller's Create builds `hint = ph_hint_create(<x>_apply_hint, <accent>)` and defines `<x>_apply_hint` / `<x>_can_hint` (`ag_`/`sd_`/`ww_`/`sk_` prefixes). Step calls `ph_hint_tick(hint)` near the timers and `ph_hint_input(hint)` before normal input (exit if result ≠ `"none"`); the HINT-pill handler gates on `<x>_can_hint()` then calls `ph_hint_open(hint)`. Draw calls `ph_hint_draw_feedback/modal/video(hint)`. See `scr_hint` + GDD §2.5–2.6.

---

## 5. Rooms — `rooms/`

`rm_boot` (first, per RoomOrderNodes) → `rm_hub`. Then one room per screen: `rm_anygram`, `rm_sudoku`, `rm_wordwave`, `rm_shikaku`, `rm_wordle`, `rm_shop`, `rm_profile`, and `rm_win` (= the **Level-Up reward screen**, no longer unused). Each room hosts its matching object.

---

## 6. Global state surface

Set up in `obj_persistent/Create_0`. Most-referenced globals:

**Data / session**
- `global.save` — the entire save struct (89 refs). All progression lives here.
- `global.selected_date_key` — which day the player is viewing/playing (47 refs).
- `global.input_locked_until` — frame-time input lock during animations (20 refs).
- `global.pending_levelup` — `{level, base_reward}` when a completed puzzle queued a level-up reward; `undefined` otherwise (init in persistent, set in `*_check_win`, consumed/cleared by `obj_win`). Gate via `ph_levelup_pending()`.
- `global.PH_H_dyn` — runtime canvas height (`PH_H` macro reads this).
- `global.safe_top_gui` / `global.safe_bottom_gui` — iOS notch / home-indicator insets.

**Puzzle caches** (lazy-loaded, may be `undefined` sentinel if file missing)
- `global.ph_anygram_cache`, `global.ph_sudoku_cache`, `global.ph_wordwave_cache`, `global.ph_shikaku_cache`, `global.ph_wordle_cache` (answers), `global.ph_wordle_allowed` (validation list as a `{WORD:true}` map).

**Review-mode flags** (jump straight to win overlay; set on hub tap)
- `global.anygram_review_mode`, `global.sudoku_review_mode`, `global.wordwave_review_mode`, `global.shikaku_review_mode`, `global.wordle_review_mode`. (Wordle: a *missed* day isn't "done", so its review flag stays false — `obj_wordle` Create reopens the lose screen from the persisted `status`/`WORDLE_MISSED` instead.)

**Transient anim**
- `global.fly_tiles` — shared fly-tile particle list (22 refs, Anygram).
- `global.ph_dot_surface` — cached dotted-background surface.

**Assets** — `global.fnt_*` (fonts), `global.spr_*` (all sprites). Loaded once in persistent. Includes `global.spr_tv` (`retro tv icon.png`) for the FREE / DOUBLE rewarded-video buttons.

---

## 7. Data file formats (authoring)

- **Anygram** (`puzzles_anygram.json`): array. New shape `{letters:[5], words:[{text,row,col,dir("H"|"V")}], bonus|bonus_pool:[...], date?, grid_size?}`. Legacy 2-word shape still accepted. Date selection: exact `date` match wins, else `seed mod length`.
- **Sudoku** (`puzzles_sudoku.json`): array of `{date?, difficulty?, givens:"81 chars (0=blank)", solution:"81 chars"}`, row-major.
- **Word Wave** (`puzzles_wordwave.json`): array of `{date?, grid:[8×"8 chars"], words:[{text,row,col,dir}], bonus_pool:[...]}`. `dir` ∈ H/H_REV/V/V_REV/DR/DL/UR/UL. Each word and bonus word must trace a straight line on the grid.
- **Shikaku** (`puzzles_shikaku.json`): array of `{date?, size, rects:[{r,c,w,h,cr,cc}]}` (rects are both clue source and unique solution).
- **Wordle** (`puzzles_wordle.json`): array of `{date?, answer:"<6 uppercase letters>"}`, two-pass date selection, fallback `STREAM`. Plus **`wordle_allowed.json`**: a flat array of uppercase 6-letter validation strings (answers should be a subset). Both registered as `IncludedFiles` in the `.yyp`.

All three: missing file → hardcoded fallback puzzle. Same two-pass date selection.

---

## 8. Conventions & gotchas

- **No struct literals with non-constant fields.** GameMaker's YYC compiler generates anonymous C++ constructors for non-constant expressions inside struct literals, which can cause **linker errors**. Build such structs with explicit property assignment (see `obj_hub/Create_0` `LAYOUT` and `hub_center_strip_on`). Related: adding resources can trigger a YYC link failure fixed by a **Clean rebuild**, not code changes (auto-memory `project_puzzle_hub_yyc_clean_rebuild`).
- **All gameplay numbers are `#macro`s in `scr_constants`.** Change them there and reflect in `GDD.md`. Never hardcode economy values.
- **Watch for reserved built-in names.** GameMaker ships functions like `video_open`, `video_close`, etc. Naming an instance variable `video_open` fails to compile ("read-only function"). The Level-Up screen uses `vid_open` for this reason. When in doubt, prefix puzzle-specific state.
- **Adding events to an existing object** (e.g. the Create/Step added to `obj_win`) means editing its `.yy` `eventList` (eventType: 0=Create, 3=Step, 8 + eventNum 64=Draw GUI) **and** adding the matching `*.gml` file. Like adding resources, this can need a **Clean rebuild**.
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
| Hint modal / rewarded-video flow | `scr_hint` (shared); per-puzzle `<x>_apply_hint`/`<x>_can_hint` in each Create |
| Level-Up reward screen | `obj_win` (Create/Step/Draw) + `ph_grant_xp(..., false)` in `*_check_win` |
| New screen | new `obj_*` + `rm_*`, register in `.yyp`, wire nav in Step events |

---

## 10. Repo / versioning

Private repo `github.com/bhogha/Puzzle-Hub`. Tag `v0.1` = rollback baseline; current dev = `0.2` (auto-memory `project_puzzle_hub_github`, `project_puzzle_hub_version`).
