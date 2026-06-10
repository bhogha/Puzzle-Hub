# Puzzle Hub — Project Cache (for Claude)

_Internal reference map of the codebase, written to make future work faster. Not player- or design-facing — for design rules see `GDD.md`. Last synced: 2026-06-10 against v0.2 (incl. Ladder — 10th puzzle, word ladder: seed word + 10 rungs, change one letter/step, tap-select + type-replace, green/red feedback, letters-only keyboard, no loss; Arrows — 9th puzzle, tap-to-clear bent "snake" arrows, tip-lane escape, no loss / +5 s time penalty; Word Bend, Color Link, Hue Sort, Wordle with loss flow, Shikaku, shared hint modal + Level-Up reward screen)._

> Keep this in sync when files move, globals are added, or the boot/save flow changes. If it drifts from the code, the code wins — re-verify before relying on a line here.

---

## 1. What this is

GameMaker (IDE `2026.0.0.16`, runtime `2026.0.0.23` — LTS) mobile daily-puzzle app. Portrait, designed at **1080×1920**. Project file: `Puzzle Hub.yyp` (lives in this folder, which is a sibling of the `Daily Puzzle` reference folder — see auto-memory `project_puzzle_hub_paths`).

Ten puzzles implemented — **Anygram**, **Sudoku**, **Word Wave**, **Shikaku**, **Wordle**, **Hue Sort**, **Color Link** (Flow Free), **Word Bend** (tile-the-board word trace, Elevate-style), **Arrows** (9th; tap-to-clear bent "snake" arrows, *Arrows – Puzzle Escape*-style), **Ladder** (10th; classic word ladder — seed word + 10 rungs, change one letter per step). Economy = XP / Levels / Coins. Full design rules in `GDD.md`. **Wordle is the only puzzle that can be lost** (out of guesses → consolation XP + "missed" state); see `WORDLE_PLAN.md` for its phased build. **Arrows** has no loss state — a blocked tap costs a +5 s time penalty only; see `ARROWS_PLAN.md`. **Ladder** has no loss state — a wrong letter just flashes red and reverts; see `LADDER_PLAN.md`.

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
| `scr_economy` | ~520 | Economy: `ph_level_from_xp`, `ph_xp_in_level`, `ph_grant_xp(save, amt, _auto_coins=true)` (pass `false` to **defer** level-up coins to the Level-Up screen), `ph_grant_coins`, `ph_spend_coins`, `ph_levelup_pending`, `ph_xp_claimed/mark`, share helpers. **Shared Win Screen** (`ph_win_create/step/input/draw/grant/begin_claim/celebrate`). **Win-screen nav shortcuts:** `ph_puzzle_is_solved(room,date)`, `ph_win_next_unsolved_room(date)` (wrap), `ph_win_prev_unsolved_date(room,date)`, `ph_win_go_next`, `ph_win_go_yesterday`, `ph_win_route(room,date)` (detours via `rm_win` when a level-up is pending, stashing `global.post_levelup`). |
| `scr_hint` | ~200 | **Shared hint-acquisition flow** (modal + placeholder rewarded video), struct-based, reused by all 5 puzzles. `ph_hint_create(apply_method, accent)` → struct; `ph_hint_open/tick/input/is_open`; `ph_hint_draw_feedback/modal/video`. `ph_input` returns `"none"/"consumed"/"paid"/"freed"/"poor"`. Also the **generic** `ph_video_overlay(timer, delay, accent)` dark "VIDEO PLAYING" placeholder (shared by hint + Level-Up + Wordle lose screens). |
| `scr_save` | ~350 | Load/write/reset save; per-puzzle solved tracking; streak recompute; bonus-word tracking; Sudoku grid + Wordle state persistence; `WORDLE_MISSED` skip in `ph_solved_count_on`; **shared pause/resume play-timer** (`ph_timer_get/set/now/commit/step` over `save.timers["<puzzle>_<date>"]`). **Central data layer.** |
| `scr_dates` | 44 | Date-key formatting (`ph_today_key`, `ph_date_key`), `ph_seed_from_key` (day-index seed), weekday/month math, `ph_date_add_days`. |
| `scr_puzzles` | 484 | Anygram + Word Wave loaders, normalizers, classifiers, solved checks. Both puzzles' pure logic. |
| `scr_sudoku` | 162 | Sudoku loader, normalizer, conflict/row/col/box/all-solved checks, grid serialize. |
| `scr_shikaku` | ~210 | Shikaku loader, normalizer (clues + solution rects), per-rect correctness, full-partition solution check, state serialize/restore, done flag. |
| `scr_colorlink` | ~225 | Color Link (Flow Free) pure logic: JSON loader/cache + two-pass date select, `ph_colorlink_make` (a/b/path → {r,c}), `ph_colorlink_color` (vibrant palette by index), `ph_colorlink_endpoint_color`, `ph_colorlink_is_solved` (all flows connect endpoints + non-overlap + full coverage), `ph_colorlink_longest_unsolved` (hint target), routes serialise/restore, `ph_colorlink_is_done`/`mark_done`. Fallback 6-flow board. |
| `scr_huesort` | ~270 | Hue Sort pure logic: JSON loader/cache, hex⇄`{r,g,b}` + colour helpers, `ph_huesort_make` (bilinear corner gradient → target + locked-corner arrays), two-pass date select, `ph_huesort_scramble` (date-seeded interior Fisher-Yates), `ph_huesort_is_solved_arr`, board serialise/restore. Save helpers (`ph_huesort_is_done`/`mark_done`, `ph_huesort_save_state`/`load_state`) live here too (mirrors Shikaku). |
| `scr_arrows` | ~230 | Arrows pure logic: JSON loader/cache + two-pass date select, `ph_arrows_make` (raw→{size, arrows:[{head,cells,len,color_idx}]}), `ph_arrows_delta`, `ph_arrows_sweep_clear` (TIP-lane clear test — straight from cells[0]+dir to edge vs other alive arrows), `ph_arrows_is_solved`, `ph_arrows_first_clear` (longest currently-clear arrow → hint), `ph_arrows_at` (cell→arrow hit-test), state serialise/restore (`save.arrows_state[date]={cleared,penalty}`, `alive=!cleared`), `ph_arrows_is_done`/`mark_done` (`ARROWS`), hardcoded 8×8 fallback. Boards are reverse-generated solvable (`tools/gen_arrows.py`). |
| `scr_ladder` | ~150 | Ladder (Word Ladder) pure logic: JSON loader/cache + two-pass date select, `ph_ladder_make` (raw→{length,start,words[],clues[],count}), `ph_ladder_diff_pos` (single differing index), `ph_ladder_current_word` (step→shown word: start at step 0, else words[step-1]), hardcoded 4-letter `COLD→…→CORK` fallback. Save helpers (`ph_ladder_is_done`/`mark_done`, `save_state`/`load_state` `{step,hinted}`) live in `scr_save`. |
| `scr_wordbend` | ~210 | Word Bend pure logic: JSON loader/cache + two-pass date select, `ph_wordbend_make` (rebuilds the letter `grid` by placing each word's chars along its `path`), fallback 4×4, `ph_wordbend_match` (traced cell-index seq vs each unfound word's path, forward/reverse), `ph_wordbend_is_solved` (all words found), `ph_wordbend_longest_unfound` (hint target), found/hinted index serialise/restore (`save.wordbend_state[date]`), `ph_wordbend_is_done`/`mark_done` (`WORDBEND` flag). |
| `scr_wordle` | ~190 | Wordle pure logic: answer + validation-list loaders/caches, two-pass date select, `ph_wordle_make`, `ph_wordle_score_guess` (green/yellow/gray dup logic), `ph_wordle_is_allowed`, `ph_wordle_add_guess` (win/loss), `ph_wordle_grant_extra_moves`, `ph_wordle_keyboard_states`, guess serialise. Save-struct helpers (is_done/mark/is_missed/state) live in `scr_save`. |
| `scr_draw` | ~360 | Reusable draw helpers: `ph_draw_rounded/chip/text/text_shadow/icon`, easing, `ph_scissor_gui`, hit tests, `ph_draw_nav` (bottom tab bar), `ph_draw_burst`, cached `ph_draw_dot_bg`. **Shared blue button widgets** (Penpot Win Screen design): `ph_draw_reward_btn(...)` and `ph_draw_nav_btn(...)`. **Shared puzzle widgets:** `ph_draw_game_tip(grid_top,str)` (one-line objective hint, Nunito-reg 44 faint ink, wraps to 2 lines — see `ph_game_tip` in `scr_constants`); `ph_draw_bonus_pill(l,cy,count)` (white capsule · chest · "BONUS" · pink count badge; returns `{l,r,t,b,icon_x,icon_y}`; used by Anygram + Word Wave); `ph_draw_word_tile(cx,cy,w,h,r,text,found)` (Word Wave "words to find" pill — found = pink+white+strike, to-find = tan+faint ink; `PH_COL_WORD_*`). |
| `scr_fonts` | 19 | `ph_load_fonts()` — registers all `global.fnt_*` via `font_add`. |

### Key economy/save facts to remember
- Level is **derived**, never stored: `level = floor(xp / 500) + 1`. `ph_grant_xp` computes `levels_gained × 100` coins, but the four `*_check_win` now call it with `_auto_coins=false` so the level-up coins are **deferred** to the **Level-Up reward screen** (`obj_win`/`rm_win`). On level gain they set `global.pending_levelup = {level, base_reward:100}`; the screen grants 100, or 200 if the player picks DOUBLE (placeholder video). Only 1 level-up possible per puzzle (100 XP grant vs 500/level).
- `ph_solved_count_on` counts a day's solves but **skips bookkeeping keys** prefixed `ANYGRAM_` and `WW_W` so per-word flags don't inflate the daily count. Adding a new multi-flag puzzle? Add the same skip rule.
- Anygram completion = `ANYGRAM_DONE` (new) or legacy `ANYGRAM_M1 && ANYGRAM_M2`, via `ph_anygram_is_done`. Sudoku = `SUDOKU` key. Word Wave = `WORDWAVE` key.
- Streak recomputed on every save load and after completions via `ph_update_streak`.
- **Puzzle timer measures active play time, not wall-clock.** Each controller sets `timer_key = "<puzzle>_" + date` and `timer_base_secs = ph_timer_get(...)` in Create, then displays/records `ph_timer_now(timer_base_secs, session_start_ms)`. Step calls `ph_timer_step(...)` while playing (persists ≤ once/sec → kill-safe); the back-button handler calls `ph_timer_commit(...)` + `ph_save_write`. Stored in `save.timers`; backfilled in `ph_save_load`. Wordle gates ticking on `puzzle.status == "in_progress"`. See GDD §5.2.

---

## 4. Objects (screens & controllers) — `objects/`

Each object owns a screen; logic split across `Create_0` (setup/state), `Step_0` (input/update), `Draw_64` (GUI-space render). Puzzle controllers are the big ones.

| Object | Events (LOC) | Role |
|---|---|---|
| `obj_boot` | Create(5) | Spawns `obj_persistent`, jumps to `rm_hub`. |
| `obj_persistent` | Create(104), CleanUp(43) | **Session manager.** Sets dynamic `PH_H`, iOS safe-area insets, loads fonts + save, configures surface/MSAA/filtering, loads **all sprites** via `sprite_add`. Lives whole session. |
| `obj_hub` | Create(99), Step(175), Draw(401) | Home screen: 7-day strip, collapsible month calendar, scrollable game cards, progress tube. Reads solved-state via `ph_*_is_done`. **Solved-card finish-time pill is centralized** (Draw §badge): any solved puzzle shows its `mm:ss` from `save["<key>_time_<date>"]`, where `<key>` is derived from the card's room (`rm_<key>`) — no per-name branching, so new puzzles get it for free. Wordle's MISSED day is the only exception (time in red via `ph_wordle_is_missed`). The old generic "SOLVED" badge was removed. **Coin-flow reward anim** (Create/Step §coin-flow, Draw §8): when entered straight after a Level-Up claim it streams coins into the top-right coin pill and floats a "+N" label under it; driven by `global.coin_flow_amount` (consumed on Create). |
| `obj_anygram` | Create(321), Step(327), Draw(512) | Anygram puzzle: letter wheel, crossword grid, fly-tile anim, hint, bonus modal, win overlay, confetti. Largest controller. |
| `obj_sudoku` | Create(201), Step(166), Draw(267) | 9×9 board, number pad, conflict highlighting, hint, win overlay. |
| `obj_shikaku` | Create, Step, Draw | 6×6 grid, drag-corner-to-corner rectangles, tap-to-delete, shape-glyph hint, win overlay. Blue accent; bottom HUD = coin + hint (no chest), like Sudoku. |
| `obj_wordwave` | Create(221), Step(243), Draw(361) | 8×8 word-search grid, swipe selection, per-word colors, hint, win overlay (centered card). **NEW layout (Penpot):** "words to find" list is a centred 2-col **pill-tile** block (`WL_*` metrics; `ph_draw_word_tile`, pink found / tan to-find) **above** the grid; **`WL_TILE_W` auto-fits the longest word** (measured at `fnt_tip` in Create, clamped min 223 / max = fits 2 cols) so long words don't clip; grid bottom-anchored above the toolbar. Toolbar = shared `ph_draw_bonus_pill` (left, rect hit `BONUS_PILL_*`) · timer · HINT. |
| `obj_wordle` | Create(~330), Step(~110), Draw(~175) | 6×6 board, **custom on-screen keyboard** (slot-based active row so a hint locks a position), staggered reveal, shared hint (`wd_apply_hint`/`wd_can_hint`), win via shared `ph_win_*`. **Loss flow is self-contained here:** `lose_phase` ∈ `none/aversion/confirm/screen` with `wd_lose_step/input/draw`; buy/free +3 moves (board grows to 9 rows, cells shrink), UNLUCKY screen grants 25/50 XP via `wd_lose_claim`. Green accent; HUD = coin top-right, timer+hint bottom bar. |
| `obj_huesort` | Create(~210), Step(~85), Draw(~130) | Hue Sort: 5×5 colour-gradient board, locked corner anchors (pin dot), **drag-and-drop swap** (pick up → lift onto finger → drop to swap), shared hint (`hs_apply_hint` anchors one correct tile), win via shared `ph_win_*`. Violet accent; HUD = coin top-right, timer+hint bottom bar (Shikaku-style, no chest/pad). No loss state. |
| `obj_wordbend` | Create(~210), Step(~115), Draw(~165) | Word Bend: 4×4–6×6 letter board fully tiled by hidden words. Tap a word's first letter + drag across adjacent cells (orthogonal bends, backtrack to trim); release matches the traced cell-seq vs unfound word paths (fwd/rev) → locks green. Shared hint (`wb_apply_hint` rings the first letter of the longest not-yet-found/hinted word), win via shared `ph_win_*`. Tangerine accent (`card_tangerine`); HUD = coin top-right, timer+HINT bottom (no bonus). No loss state. |
| `obj_arrows` | Create(~210), Step(~80), Draw(~110) | Arrows: 8×8 white dot-grid board; arrows drawn as slim ribbons (`RIBBON_W≈0.30·CELL`) with corner-rounded bends (`ar_round`, `AR_CORNER≈0.42`) + triangle arrowhead, per-arrow colour via `ph_colorlink_color`. Tap (`ar_cell_at`→`ph_arrows_at`) → if `ph_arrows_sweep_clear`: snake slide-out (`ar_start_launch` builds smoothed body+lane path, body glides by arc-length, clipped to board) then `alive=false`/save/win-check; else blocked → shake along head dir + `penalty_secs`+=5 + `timer_base_secs`+=5 + floating "+5 s". Shared hint (`ar_apply_hint` pulses white glow on longest safe arrow). Win via shared `ph_win_*`; recap = initial full board. Silver accent; HUD = coin top-right, timer+HINT bottom (no bonus). No loss state. |
| `obj_colorlink` | Create, Step, Draw | Color Link (Flow Free): 6×6 board, `route[]` per flow (cell-index arrays) + `cell_owner[]`, drag to draw/extend/retract flows (`cl_try_step` walks head toward finger; override trims crossed flows; hint-locked flows immovable), shared hint (`cl_apply_hint` lays the longest solution flow + locks it), win via shared `ph_win_*`. Lime accent; HUD = coin top-right, timer+HINT bottom (no bonus). No loss state. |
| `obj_ladder` | Create(~210), Step(~110), Draw(~115) | Ladder: single word row of N tiles (N = day's word length, sized to fit), tap a tile → `sel` (amber `#ffc04c` bg), type a key → replace that letter, then compare full word vs `puzzle.words[step]`; match → green flash (`#aaca31`) `FB_DUR` frames then `ld_advance` (step++, load next word/clue, or win); mismatch → red flash (`#eb5a5a`) then revert. Letters-only keyboard (`ld_build_keys`, no DEL/SEND). Clue box (`#f1eae1`) + `N/10` progress above the keyboard. Shared hint (`ld_apply_hint` highlights the differing tile bg, soft amber `#ffe5a8`, persists per rung). Win via shared `ph_win_*` (recap = full solved ladder, `win_draw_recap`); 100 XP granted by the win-screen CLAIM (`claim_key="ladder_<date>"`), NOT the controller. Amber accent; HUD = coin top-right, timer+HINT bottom. No loss state. |
| `obj_shop` | Create(2), Step(18), Draw(24) | Shop tab — minimal/stub. |
| `obj_profile` | Create(18), Step(56), Draw(42) | Profile tab + **hidden triple-tap-Level save-reset** gesture. |
| `obj_win` | Create, Step, Draw | **Level-Up reward screen** (in `rm_win`). Repurposed from the old dead win-overlay stub. Reads `global.pending_levelup`, shows a purple card ("LEVEL UP!" + "LEVEL N" + confetti) with **100** / **200** blue reward buttons (`ph_draw_reward_btn`, gold-coin icon, TV badge on double); grants coins (`lu_claim`), clears the flag. **`lu_claim` routing:** if `global.post_levelup` is set (player came from a win-screen NEXT GAME / YESTERDAY shortcut) it continues to that `{room,date}` with **no** coin animation; otherwise it stashes the amount in `global.coin_flow_amount` and `room_goto(rm_hub)` so the hub plays its coin-flow animation. DOUBLE → `ph_video_overlay` 5 s → 200 coins. NB: its video flag is `vid_open` because `video_open` is a reserved built-in. |

Pattern: each puzzle controller embeds its own **win overlay** + confetti (not `obj_win`); review mode re-enters the puzzle room with a `global.*_review_mode` flag and jumps straight to the win overlay. The **Level-Up screen** is the one thing that lives in its own room: each puzzle's win-screen BACK button does `room_goto(ph_levelup_pending() ? rm_win : rm_hub)`.

**Shared hint flow (all 4 puzzles):** each controller's Create builds `hint = ph_hint_create(<x>_apply_hint, <accent>)` and defines `<x>_apply_hint` / `<x>_can_hint` (`ag_`/`sd_`/`ww_`/`sk_` prefixes). Step calls `ph_hint_tick(hint)` near the timers and `ph_hint_input(hint)` before normal input (exit if result ≠ `"none"`); the HINT-pill handler gates on `<x>_can_hint()` then calls `ph_hint_open(hint)`. Draw calls `ph_hint_draw_feedback/modal/video(hint)`. See `scr_hint` + GDD §2.5–2.6.

---

## 5. Rooms — `rooms/`

`rm_boot` (first, per RoomOrderNodes) → `rm_hub`. Then one room per screen: `rm_anygram`, `rm_sudoku`, `rm_wordwave`, `rm_shikaku`, `rm_wordle`, `rm_huesort`, `rm_colorlink`, `rm_wordbend`, `rm_arrows`, `rm_ladder`, `rm_shop`, `rm_profile`, and `rm_win` (= the **Level-Up reward screen**, no longer unused). Each room hosts its matching object.

---

## 6. Global state surface

Set up in `obj_persistent/Create_0`. Most-referenced globals:

**Data / session**
- `global.save` — the entire save struct (89 refs). All progression lives here.
- `global.selected_date_key` — which day the player is viewing/playing (47 refs).
- `global.input_locked_until` — frame-time input lock during animations (20 refs).
- `global.pending_levelup` — `{level, base_reward}` when a completed puzzle queued a level-up reward; `undefined` otherwise (init in persistent, set in `*_check_win`, consumed/cleared by `obj_win`). Gate via `ph_levelup_pending()`.
- `global.coin_flow_amount` — coins granted by the last Level-Up claim, awaiting the hub coin-flow animation. `0` = nothing to play (init in persistent, set in `obj_win.lu_claim`, consumed in `obj_hub.Create_0`).
- `global.post_levelup` — `{kind:"room", room, date}` when the player triggered a win-screen **NEXT GAME / YESTERDAY** shortcut while a level-up was pending; the Level-Up screen continues here after claiming (no coin anim) instead of going to the hub. `undefined` otherwise (init in persistent, set in `ph_win_route`, consumed in `obj_win.lu_claim`).
- `global.PH_H_dyn` — runtime canvas height (`PH_H` macro reads this).
- `global.safe_top_gui` / `global.safe_bottom_gui` — iOS notch / home-indicator insets.

**Puzzle caches** (lazy-loaded, may be `undefined` sentinel if file missing)
- `global.ph_anygram_cache`, `global.ph_sudoku_cache`, `global.ph_wordwave_cache`, `global.ph_shikaku_cache`, `global.ph_wordle_cache` (answers), `global.ph_wordle_allowed` (validation list as a `{WORD:true}` map), `global.ph_huesort_cache`, `global.ph_colorlink_cache`, `global.ph_wordbend_cache`, `global.ph_arrows_cache`, `global.ph_ladder_cache`.

**Review-mode flags** (jump straight to win overlay; set on hub tap)
- `global.anygram_review_mode`, `global.sudoku_review_mode`, `global.wordwave_review_mode`, `global.shikaku_review_mode`, `global.wordle_review_mode`, `global.huesort_review_mode`, `global.colorlink_review_mode`, `global.wordbend_review_mode`, `global.arrows_review_mode`, `global.ladder_review_mode`. (Wordle: a *missed* day isn't "done", so its review flag stays false — `obj_wordle` Create reopens the lose screen from the persisted `status`/`WORDLE_MISSED` instead.)

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
- **Color Link** (`puzzles_colorlink.json`): array of `{date?, size, flows:[{color, a:[r,c], b:[r,c], path:[[r,c]...]}]}`. `a`/`b` = endpoint dots; `path` = full solution route (powers the hint + win recap). Generated via Hamiltonian-path-cut so flows always tile the board. Two-pass date select; hardcoded fallback.
- **Hue Sort** (`puzzles_huesort.json`): array of `{date?, size?, corners:{tl,tr,bl,br}}` where each corner is `"RRGGBB"` hex. The four corners define the whole board via bilinear interpolation; the interior scramble is date-seeded. Two-pass date selection; missing file → hardcoded pink/yellow/purple/teal fallback.
- **Word Bend** (`puzzles_wordbend.json`): array of `{date?, size, words:[{text, path:[[r,c]...]}]}`. `path` lists each word's cells in spelling order (`path[k]`↔`text[k]`); the union of all word paths must tile the whole `size×size` board exactly once (no gaps/overlaps) so it's always solvable. The letter grid is rebuilt from words+paths. Two-pass date select; hardcoded 4×4 fallback.
- **Arrows** (`puzzles_arrows.json`): array of `{date?, size, arrows:[{head:"U"|"D"|"L"|"R", cells:[[r,c]...]}]}`. `cells[0]` is the arrowhead (tip) cell; `cells[1]` is directly behind it (opposite `head`) so the tip is frontmost; cells are 4-connected. Generated offline by `tools/gen_arrows.py` via reverse construction (place each arrow only when its tip-lane is clear of placed cells → forward solution = reverse placement order), greedy-solver verified. Two-pass date select; hardcoded 8×8 fallback. Tip-lane escape rule = only the straight lane in front of the tip must be clear.

- **Ladder** (`puzzles_ladder.json`): array of `{date?, length, start, steps:[{word, clue}]×10}`. `start` = seed word (shown pre-filled, not counted in N/10); each `steps[i].word` is `length` letters and consecutive words (incl. `start`→`steps[0]`) differ by exactly one position (validated at authoring). `clue` = JSON-fed description of that rung's word. Two-pass date select; hardcoded 4-letter `COLD→…→CORK` fallback. Current word derives from `step` (not stored).

All: missing file → hardcoded fallback puzzle. Same two-pass date selection.

---

## 8. Conventions & gotchas

- **No struct literals with non-constant fields.** GameMaker's YYC compiler generates anonymous C++ constructors for non-constant expressions inside struct literals, which can cause **linker errors**. Build such structs with explicit property assignment (see `obj_hub/Create_0` `LAYOUT` and `hub_center_strip_on`). Related: adding resources can trigger a YYC link failure fixed by a **Clean rebuild**, not code changes (auto-memory `project_puzzle_hub_yyc_clean_rebuild`).
- **All gameplay numbers are `#macro`s in `scr_constants`.** Change them there and reflect in `GDD.md`. Never hardcode economy values.
- **Watch for reserved built-in names.** GameMaker ships functions like `video_open`, `video_close`, etc. Naming an instance variable `video_open` fails to compile ("read-only function"). The Level-Up screen uses `vid_open` for this reason. When in doubt, prefix puzzle-specific state.
- **Adding events to an existing object** (e.g. the Create/Step added to `obj_win`) means editing its `.yy` `eventList` (eventType: 0=Create, 3=Step, 8 + eventNum 64=Draw GUI) **and** adding the matching `*.gml` file. Like adding resources, this can need a **Clean rebuild**.
- **`PH_SUDOKU_TEST_PREFILL = true`** in `scr_constants` — debug flag that starts Sudoku ~90% solved. **Must be `false` before shipping.**
- **`PH_BONUS_WORD_XP = 25`** is dead (bonus words pay coins only, no XP). Safe to delete.
- **Safe areas.** iOS insets are computed once in `obj_persistent` into `global.safe_top_gui` / `global.safe_bottom_gui` (GUI units). **GameMaker has no working GML call for this** — `os_get_info()` does *not* expose safe-area keys (the old `ios_safe_area_*` read always returned 0, so the UI sat under the Dynamic Island). Current logic: call the **"iOS Safe Area" native extension** (`iOS_get_safe_area()` → JSON → `top`/`bottom` px → GUI units) for true per-device insets, else estimate from screen aspect for tall iPhones (`PH_H*0.075` top, `PH_H*0.042` bottom — calibrated to iPhone 16 Pro). **The extension IS installed** (`extensions/iOSSafeArea/`) and verified working on iPhone 16 Pro (`src=extension`, raw 186/102 px → 167/91 GUI). **It must stay imported or the project won't compile** (the `iOS_get_safe_area()` call is iOS-only, guarded by `os_type == os_ios`); delete that block in `obj_persistent` to revert to the estimate. `obj_persistent` records `global.safe_src`/`safe_raw_top`/`safe_raw_bottom` and logs `[safe-area]` at boot; `PH_DEBUG_SAFEAREA` (in `scr_constants`) toggles an on-hub readout. **Extension gotcha:** `iOSSource/iOSSafeArea.h` needs `#import <UIKit/UIKit.h>` (declares NSObject/CGFloat/NSString) or the iOS build fails with *"Class defined without specifying a base class"*; re-importing the `.yymp` would overwrite that fix. For full-screen layouts use the helpers `ph_safe_top()` / `ph_safe_bottom()` (in `scr_draw`), which add comfort padding (`PH_PAD_TOP` / `PH_PAD_BOTTOM` in `scr_constants`) **on top of** the raw inset so content never crowds the Dynamic Island / status bar (top) or home indicator (bottom) — and still has margin on devices/sims that report a 0 inset. The shared win screen (`ph_win_draw`) lays its vertical flow between these. Puzzle HUDs use `95 + safe_top_gui` (top) and `PH_H - 110 - safe_bottom_gui` (bottom); the hub uses `LAYOUT.*_y += safe_top_gui` and the nav extends by `safe_bottom_gui`; shop/profile headers add `safe_top_gui`. When adding a new screen, anchor top/bottom elements to these, not to raw pixels.
- **Core-game content is bottom-anchored.** Every puzzle's `grid_y` is set to a top value, then shifted DOWN so the whole play cluster (board + any number pad / keyboard / word-list / wheel) sits just above the bottom HUD toolbar, leaving the empty band under the top HUD instead. Pattern in each Create: `grid_y += max(0, (PH_H - safe_bottom_gui - 155 - PH_PLAY_BOTTOM_GAP) - (grid_y + cluster_h))`, where `cluster_h` spans grid_y to the lowest element's bottom (sub-elements like `NUM_Y`/`DEL_Y`/`KB_TOP`/word-list/`_list_y0` all derive from `grid_y`, so they follow). Anygram is the exception — its grid bottom-anchors above the (independent, proportional) wheel: `grid_y = max(170+safe_top, wheel_top - 130 - grid_h)`. Tune the gap via `PH_PLAY_BOTTOM_GAP` in `scr_constants`. Hit tests read `grid_y`/derived vars, so they stay aligned.
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
