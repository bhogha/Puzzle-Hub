# Puzzle Hub — Game Design Document

_Last updated: 2026-06-01 · Version: 0.2 (in development; v0.1 tagged baseline)_

This document captures **what is actually implemented in code** today, not the long-term vision. Update it whenever an economy rule changes, a new puzzle ships, or a balancing constant is tuned. All gameplay numbers live in `scripts/scr_constants/scr_constants.gml` as `#macro`s — change them there and reflect the change here.

---

## 1. High-level concept

Puzzle Hub is a daily-puzzle container app. Each calendar day surfaces **10 unique puzzles** on a hub screen; the player earns XP and coins by solving them. Each daily puzzle can be solved exactly once — solving it locks a "finish time" for that day, and the player can travel back to play previous days from the calendar but cannot replay a day already solved. Future days are not accessible.

Four puzzle types — **Anygram**, **Sudoku**, **Word Wave**, and **Shikaku** — are implemented. The remaining slot on the hub (Mix-Up) is a placeholder showing "COMING SOON".

---

## 2. Economy

### 2.1 XP

| Rule | Value | Constant |
|---|---|---|
| Starting XP (new player) | 100 | `PH_INITIAL_XP` |
| XP per puzzle solved | 100 | `PH_XP_PER_PUZZLE` |
| XP per level | 500 | `PH_XP_PER_LEVEL` |

XP can be earned by playing any day's puzzle — including past days — so retroactive solves still progress the player.

**One XP grant per puzzle.** XP is awarded **exactly once** when a daily puzzle becomes fully solved — not per word, sub-step, or mini-objective. For Anygram that means: solving Main 1 alone grants 0 XP, solving Main 2 alone grants 0 XP, finding a bonus word grants 0 XP. The single +100 XP fires only when Main 1 *and* Main 2 are both complete.

### 2.2 Levels

Level is derived from total XP: `level = floor(xp / 500) + 1`. So:

- 0–499 XP → Level 1
- 500–999 XP → Level 2
- 1000–1499 XP → Level 3
- …

Each level-up grants **100 coins** (`PH_COINS_PER_LEVEL`). A single XP grant can cross multiple level thresholds; the reward scales accordingly (`levels_gained × 100`).

### 2.3 Coins

| Rule | Value | Constant |
|---|---|---|
| Starting coins (new player) | 300 | `PH_INITIAL_COINS` |
| Reward per level-up | 100 | `PH_COINS_PER_LEVEL` |
| Reward for solving the 4th puzzle of a day ("gift box") | 100 | `PH_COINS_FOR_4TH` |
| Anygram bonus word coin reward | 10 | `PH_BONUS_WORD_COINS` |
| Hint cost (Anygram) | 100 | `PH_HINT_COST` |

Bonus words pay coins only — they award no XP and do not count toward puzzle completion.

The "gift box" reward fires once per calendar day when the player crosses the 4-solved threshold (`PH_GIFT_PUZZLE_INDEX = 3`, 0-based), and is tracked in `save.gift_claimed_dates`.

**Canonical coin sources (spec).** Players earn coins from **level-ups** and from the **gift box** (the 4th-puzzle-of-the-day reward). These are the two designed earn paths.

> **Note on the bonus-word coin reward.** The +10 coins per Anygram bonus word is implemented in code but sits outside the two canonical sources above. Treat as an intentional secondary reward unless we decide to remove it.

### 2.4 Streak

`save.streak` is the count of consecutive calendar days (ending at today or yesterday) on which **at least one puzzle was solved**. It is recomputed on save load and after every Anygram completion (`ph_update_streak`).

If the player did not solve a puzzle today but did solve one yesterday, the streak still counts (it just doesn't grow until they solve today's). If neither today nor yesterday has any solve, the streak resets to 0.

---

## 3. Daily structure

- A "day" is the player's local calendar date, formatted `YYYY-MM-DD` (`ph_today_key()`).
- Each day exposes 10 puzzle slots (`PH_PUZZLES_PER_DAY`). Today's puzzle for each game is picked deterministically from that game's puzzle pool using a seed derived from the date (`ph_seed_from_key(key) mod pool_size`).
- The hub renders three navigable views:
  1. A 7-day strip centred on today (index 3 = today; the user can tap any day).
  2. A collapsible month grid (tap the teal calendar bar to expand).
  3. A scrollable list of game cards.
- The progress tube above the cards reads `solved_today / 10`. A gift-box marker sits at position 4/10.

---

## 4. Implemented puzzles

### 4.1 Anygram

**Genre.** Multi-word crossword with a letter wheel. Each puzzle has **4–7 interlocking main words** drawn from a 5-letter pool shared on the wheel below (see the standalone Anygram GDD in `../Daily Puzzle App/Anygram_GDD.md` for the authoring spec).

**Layout** (1080×1920 portrait; see Anygram GDD §7 for the full diagram).
- **HUD strip** (y=0..200): back arrow on the far left, live timer pill next to it, "ANYGRAM" title centred, coin-balance pill on the right (coin icon + balance; pulses on coin gain, doubles as the coin-fly target).
- **Board area** (y=200..1180, h=980): crossword grid centred horizontally. 4–7 main words placed on a shared grid. Each word has a `row`, `col`, and direction (`H` or `V`). Words that share a cell must agree on the letter at that cell (validated at load time with a debug warning if not). Cell size shrinks from 140→110 when `max(cols,rows) ≥ 5` so the grid stays clear of the wheel. Empty cells (shared or not) render in a uniform warm cream; yellow tint appears only after a shared cell is *filled*, signalling the crossing reveal.
- **Wheel area:** letter wheel centred at (540, 1440), R=270, letters on inner radius 195. Sits between the grid (top edge ≈ y=1170) and the bottom toolbar (top edge ≈ y=1765) with ~45 px clearance above and ~55 px below. Node count tracks `puzzle.letters.length`, distributed evenly around the disc. Letter tiles are pink-filled with white text by default; the in-trail (selected) state pops with a soft white glow halo, a deeper-pink fill, and an 8% scale-up. A shuffle button at the centre re-randomises wheel positions. (Original GDD §7 spec was center 1530 / R=300, but that overlapped both the tallest puzzles and the toolbar.)
- **Bottom toolbar** (~y=1810): bonus-words chest icon with count badge on the left (opens a modal listing every bonus word found this session), wide HINT pill on the right (bulb · "HINT" · cost · coin icon — single tap target). No coin balance lives here; it's in the top HUD pill.

**Input.** Drag-to-spell on the wheel. The player traces a path through letters and releases to submit. Backtracking by reversing onto the second-to-last letter is allowed.

**Word classification** (`ph_classify_word`) returns `{kind, index}` where kind is one of:
- `main` → marks `puzzle.words[index].found = true`, spawns letter tiles that fly from each wheel node to the matching cells (in word-letter order), reveals cells on arrival. No XP awarded yet.
- `bonus` → grants 10 coins (no XP), spawns letter tiles that fly from each wheel node into the bonus icon; a coin sprite then arcs from the icon into the coin balance with a counter pulse.
- `dup` → already-found main or bonus; "ALREADY FOUND" toast, no reward.
- `neutral` → uses only wheel letters, ≥ 2 chars, not a key word; "NOT A KEY WORD" toast.
- `bad` → otherwise; "NOT A VALID WORD" toast, swipe trail shakes briefly before clearing.

**Hint.** The bulb button (bottom-right toolbar) costs **100 coins** and reveals one unfilled, non-hint cell. If no such cell exists or the puzzle is already complete, the action is rejected with a toast and no coins are spent.

**Completion.** When *every* main word is solved (`ph_anygram_all_solved`), `ag_check_win` fires:
- Records elapsed time as `save.anygram_time_<date_key>` (mm:ss).
- Marks each word found as `ANYGRAM_W<i>` and sets the consolidated `ANYGRAM_DONE` flag in `save.puzzles_solved[date_key]`.
- Grants the single 100 XP reward for the puzzle.
- Triggers the 4th-puzzle gift if applicable.
- Updates streak.
- Shows the win overlay (see *Win screen* below).
- Sets `confetti_burst_pending = true` so the next Step spawns the celebration burst.

**Win screen.** The white card slides up over a teal backdrop and stacks, top to bottom: Blinky character → "WELL DONE!" → **mini crossword recap** (the just-solved grid, scaled to fit a 380×320 box using the same tile-tint logic as the live board — yellow for shared cells, light-pink for hints, pink for solved, dark/white letters as the live board paints them) → "+100 XP" pill → level row with XP progress bar → finish-time + streak chips → optional GIFT banner (if the 4th-puzzle bonus fired) → BACK TO HUB button. Card height is computed dynamically from the mini grid's height so the back button keeps a fixed bottom margin regardless of puzzle shape.

**Celebration confetti.** A particle confetti system replaces the previous static star bursts. It runs in two layers any time `win_phase == 1`, capped at a fixed 3-second window so it doesn't loop forever:
1. *Initial burst.* A 60-piece radial spray fires from the centre of the card the frame `confetti_burst_pending` flips true (set by `ag_check_win` on live completion **and** by `Create_0` when re-entering in review mode, so the celebration plays every time the screen is shown). Firing the burst also resets `confetti_run_frames = 0` so the 3-second window is anchored to the burst, not to room creation.
2. *Falling layer.* While `confetti_run_frames < CONFETTI_DURATION_FRAMES` (180 frames ≈ 3.0s at 60 fps), a steady-state pool of ~70 pieces drifts down from above the screen with light gravity and per-piece rotation. Once the window closes, no new pieces spawn — in-flight pieces are still ticked so the tail dissipates naturally instead of cutting hard.

Pieces are coloured from the project palette (pink, yellow, teal, purple, white, orange) and rendered as one of three shapes — rotated rectangle (paper streamer), equilateral triangle, or circle. Burst pieces use higher launch velocities than falling pieces; both share the same gravity (`vy += 0.35` per step) and air-drag values, so the two layers blend naturally.

**Review mode.** Tapping an already-completed Anygram on the hub re-enters the room with `global.anygram_review_mode = true`, which goes straight to the win overlay with the recorded finish time and queues the confetti burst. The hub queries `ph_anygram_is_done` to decide whether to show the solved state on the card.

**Data source.** `datafiles/puzzles_anygram.json` — an array of puzzles in either shape:

- **New (N-word, GDD §10):** `{letters: [5 letters], words: [{text,row,col,dir}, ...], bonus: [...]}`. The `bonus` key may also be spelled `bonus_pool` (the spelling used in the Anygram GDD example); the loader accepts either. Optional informational fields `date` and `grid_size` are tolerated and ignored.
- **Legacy (2-word):** `{main1, main2, cross_letter, main1_index, main2_index, bonus}` — still supported. `ph_anygram_make_legacy` converts these into the same runtime struct (2 words) so all downstream code is shape-agnostic.

The loader caches the parsed array in `global.ph_anygram_cache`. If the file is missing, the game falls back to a hardcoded puzzle (`LIVE / VILE`).

**Date selection.** `ph_anygram_for_date(date_key)` picks the puzzle in two passes: first it scans for any entry whose `date` field equals `date_key` (exact match wins — lets us hand-author specific dates like launch day or holidays); if no exact match exists, it falls back to `seed mod array_length(list)` so every calendar day still gets a stable, device-agnostic puzzle.

**Feedback timing (matches Anygram GDD §8).**
- Cell reveal: pulse to scale 1.10 → 1.0 over 12 frames with a brief letter-color flash.
- Flying letter tile: ease-out-cubic, ~350ms duration, ~60ms stagger per letter. On arrival, scales to 85% of source (main word → grid cell) or 40% (bonus word → bonus icon).
- Coin arc: parabolic, ~500ms from bonus icon to coin balance, then a damped sine overshoot bounce + a 1.0→1.25→1.0 balance-text pulse.
- Invalid swipe: horizontal sinusoidal shake on the wheel and trail line for ~16 frames (~250ms). No screen shake — the rest of the UI stays calm.

**Per-puzzle save shape.** Per-word found state is persisted as `ANYGRAM_W0`, `ANYGRAM_W1`, … so a player who exits mid-puzzle resumes with the right cells pre-filled. `ANYGRAM_DONE` is the single flag the Hub reads. `ph_anygram_is_done` checks `ANYGRAM_DONE` first and falls back to legacy `ANYGRAM_M1 && ANYGRAM_M2` so pre-refactor saves remain valid.

### 4.2 Sudoku

Classic 9×9 Sudoku. The board is divided into nine 3×3 boxes; the solved grid contains the digits 1–9 exactly once in every **row**, every **column**, and every **3×3 box**. Each daily puzzle ships with roughly half the cells (~40 of 81) pre-filled as locked **givens**; the player fills the rest.

**Reward.** Solving the puzzle grants a single **+100 XP** (`PH_XP_PER_PUZZLE`), exactly once on full completion — identical to Anygram. Sudoku counts toward the daily "4th puzzle" gift box and the streak like any other puzzle.

**Layout (mirrors Anygram).** Back arrow + live timer in the top HUD strip; coin balance and HINT pill in the bottom toolbar. There is no Bonus icon. The accent colour is **purple** (`PH_COL_PURPLE`), versus Anygram's pink. Between the board and the toolbar sit a 1–9 number pad (purple tiles, mirroring Anygram's letter tiles) and a DELETE button.

**Interaction.**
- Tap an editable cell to **select** it — the selected cell is filled purple and its row, column, and box are softly highlighted. Locked givens cannot be selected.
- With a cell selected, tap a number (1–9) to place it. Tap **DELETE** to clear the selected cell.
- Entries that **conflict** with another filled cell in the same row, column, or box are drawn in deep pink so the player can self-correct. Givens are dark; player entries are purple; hint-revealed cells are gold.
- When a row, column, or 3×3 box becomes completely and correctly filled, its cells pulse green (positive feedback).
- Completing the whole grid stops the timer and shows the win celebration (same confetti / level-up card as Anygram).

**Hint (`PH_HINT_COST` = 100 coins).** Reveals one correct number. If a cell is selected and empty, that cell is revealed; otherwise a random empty cell is chosen. Revealed cells are flagged as hints (gold) and persist in the saved grid.

**Data format.** Loaded from `datafiles/puzzles_sudoku.json` (cached in `global.ph_sudoku_cache`). Each entry:

```json
{ "date": "YYYY-MM-DD", "difficulty": "easy",
  "givens": "<81 chars, '0' = blank>", "solution": "<81 chars>" }
```

Indexing is row-major (`index = row*9 + col`). `date` is optional. **Date selection** uses the same two-pass logic as Anygram: exact `date` match wins, otherwise `seed mod array_length(list)` gives every calendar day a stable puzzle. If the file is missing, a hardcoded fallback puzzle is used.

**Save shape.** Completion is tracked through the generic `puzzles_solved` map under the `SUDOKU` key (so `ph_solved_count_on` counts it automatically). Finish time is stored as `sudoku_time_<date>`, and the in-progress grid is persisted as an 81-char string under `sudoku_grid` (keyed by date) so a player who leaves mid-puzzle resumes their entries.

### 4.3 Word Wave

**Genre.** Classic word-search on an **8×8 letter grid**. Hidden words are listed below the grid; the player finds each by swiping a straight line across the letters. The grid letters are always visible (unlike Anygram, where tiles fill in).

**Layout** (1080×1920 portrait).
- **HUD strip** (top): back arrow on the far left, "WORD WAVE" title centred (teal), live timer pill on the right — identical structure to Anygram/Sudoku.
- **Board area:** an 8×8 grid centred horizontally (`BOARD_W = 900`, `GAP = 10`, so `CELL ≈ 103`), top-anchored at `y = 250 + safe_top`. Cells render as warm-cream tiles with dark letters.
- **Word list:** the hidden words appear directly below the grid in a 2-column list. Unfound words show a hollow dot + ink-soft text; found words show a filled coloured dot, the word in its highlight colour, and a strike-through line.
- **Bottom toolbar** (identical to Anygram): bonus-words **chest** icon with count badge on the left (opens the bonus-words modal), **coin balance** pill in the centre (pulses on coin gain, doubles as the coin-fly target), wide **HINT** pill on the right (bulb · "HINT" · cost · coin icon).

**Input.** Press on a cell to anchor the selection, drag to another cell, release to submit. The selection snaps to a straight line only when the start and current cell are colinear along one of **8 directions** — horizontal, vertical, both diagonals, each playable forwards **and** backwards (`ph_ww_delta` / `ww_build_path`). Non-colinear drags keep the last valid straight-line selection. The in-progress selection is drawn as a translucent teal capsule behind the letters.

**Word classification** (`ph_ww_classify_path`, matches by the swiped *cells* so highlights land on real grid letters):
- `main` → the swiped cells coincide with a hidden word's cells (either orientation). Marks the word found, persists it, paints a permanent capsule highlight in that word's colour with white letters, flashes the cells, and checks for win. No XP awarded yet.
- `bonus` → a straight-line path whose reading (either direction) is in the puzzle's `bonus_pool`. Grants **+10 coins** (`PH_BONUS_WORD_COINS`, no XP), flashes the path, and arcs a coin sprite from the chest into the coin balance with a counter pulse.
- `dup` → already-found word/bonus; "ALREADY FOUND" toast, no reward.
- `bad` → otherwise; "NOT A WORD" toast, grid shakes briefly.

**Highlight colours.** Each hidden word is assigned a distinct strong colour from the hub palette (`PH_COL_PINK`, `TEAL`, `PURPLE`, `ORANGE`, `YELLOW_DEEP`, plus the `_DEEP` variants), cycled by word index. The colour is used for the on-grid capsule, the word's letters (white over the capsule), and its entry in the word list.

**Hint** (`PH_HINT_COST` = 100 coins). Reveals **only the first letter** of an unfound word: its starting cell gets a persistent yellow ring marker (the player still has to trace the rest). The hint targets the first unfound word whose start isn't already ringed. If none qualifies or the puzzle is complete, the action is rejected with a toast and no coins are spent. Hinted cells persist via re-derivation on resume (the rings re-appear because they mark word starts, but only hinted starts are stored in the live `hint_cells` map for the session).

**Completion.** When every hidden word is found (`ph_wordwave_all_solved`), `ww_check_win` fires: records `save.wordwave_time_<date>` (mm:ss), marks each word as `WW_W<i>` and sets the `WORDWAVE` flag in `save.puzzles_solved[date_key]`, grants the single **+100 XP**, triggers the 4th-puzzle gift if applicable, updates streak, and shows the win overlay with the confetti burst.

**Win screen.** Same teal-backdrop celebration as the other puzzles, **but the result grid is centred** (the white card is vertically centred rather than bottom-anchored). It stacks: Blinky → "WELL DONE!" → the full **8×8 result grid centred on screen** with every found word's capsule highlight preserved → "+100 XP" pill → level row + XP bar → finish-time + streak chips → optional GIFT banner → BACK TO HUB.

**Review mode.** Tapping a completed Word Wave on the hub re-enters with `global.wordwave_review_mode = true`, going straight to the centred win overlay with the recorded finish time. The hub queries `ph_wordwave_is_done` for the solved-state badge and reads `wordwave_time_<date>` for the finish time.

**Data source.** `datafiles/puzzles_wordwave.json` — an array of puzzles, cached in `global.ph_wordwave_cache`. Each entry:

```json
{ "date": "YYYY-MM-DD",
  "grid": ["8-CHAR ROW", ... 8 rows of 8 uppercase letters],
  "words": [ {"text": "WORD", "row": 0, "col": 0, "dir": "H"}, ... ],
  "bonus_pool": ["WORD", ...] }
```

`dir` is one of `H`, `H_REV`, `V`, `V_REV`, `DR`, `DL`, `UR`, `UL`. `date` is optional; **date selection** uses the same two-pass logic as the other puzzles (exact `date` match wins, else `seed mod length`). If the file is missing, a hardcoded `CAT / DOG` fallback is used. Authoring note: each word's letters must already exist on the `grid` along its stated direction, and every `bonus_pool` word must also trace a straight line on the grid to be discoverable.

**Save shape.** Per-word found state is persisted as `WW_W0`, `WW_W1`, … (these keys are skipped by `ph_solved_count_on` so they don't inflate the daily count); `WORDWAVE` is the single flag the Hub reads. Bonus words are tracked under `save.wordwave_bonus[date_key]` (lowercased keys), mirroring Anygram's `anygram_bonus`.

### 4.4 Shikaku

**Genre.** Rectangle-division logic puzzle ("Shikaku" / "divide by squares") on a **6×6 grid**. The grid carries numbers; the player partitions the whole grid into rectangles so that **each rectangle contains exactly one number and that number equals the rectangle's area** (cell count). Every cell ends up inside exactly one rectangle. Generation guarantees each puzzle has a **unique** solution.

**Reward.** Solving grants a single **+100 XP** (`PH_XP_PER_PUZZLE`), once on completion — identical to the other puzzles. Shikaku counts toward the daily 4th-puzzle gift box and the streak. **No bonus-word / secondary reward** (the genre has none).

**Layout (mirrors Sudoku).** Back arrow + live timer in the top HUD strip; **coin balance + HINT pill in the bottom toolbar — no bonus chest**, exactly like Sudoku. The accent colour is **blue** (`PH_COL_BLUE`). The board is a 6×6 grid (`BOARD = 960`, `CELL = 160`) centred horizontally below the HUD. There is no number pad.

**Interaction.** **Drag corner-to-corner** to draw a rectangle: press a cell, drag to the opposite corner, release to commit. Committing removes any existing rectangles that overlap the new one (so you can redraw freely). **Single-cell tap on an existing rectangle deletes it.** Each drawn rectangle is filled soft (blue) with a coloured border: **teal** when it is correct (contains exactly one number whose value equals its area), **pink** otherwise. The in-progress drag shows a translucent blue preview.

**Hint (`PH_HINT_COST` = 100 coins).** Reveals the *shape* of one number's correct rectangle as a **small rounded glyph in that number's cell corner** — its proportions match the solution's width×height (e.g. 9 → a small 3×3 square glyph; 3 → a small 1×3 bar). The glyph is deliberately smaller than the number and does **not** place the rectangle for the player; it only communicates the orientation/dimensions. The hint targets the first number that isn't already hinted and isn't already correctly enclosed. If none qualify, the action is rejected with a toast and no coins are spent. Revealed hint glyphs persist across resume.

**Completion.** When the player's rectangles form a complete valid partition (`ph_shikaku_check_solution`), the controller records `save.shikaku_time_<date>` (mm:ss), sets the `SHIKAKU` flag in `save.puzzles_solved[date_key]`, grants the single +100 XP, triggers the 4th-puzzle gift if applicable, updates streak, and shows the win overlay with the confetti burst.

**Win screen.** Same teal-backdrop celebration as the other puzzles: Blinky → "WELL DONE!" → a **mini solved board** (the completed 6×6 partition: solution rectangles drawn as teal rings with their numbers) → "+100 XP" pill → level row + XP bar → finish-time + streak chips → optional GIFT banner → BACK TO HUB.

**Review mode.** Tapping a completed Shikaku on the hub re-enters with `global.shikaku_review_mode = true`, going straight to the win overlay (rectangles rebuilt from the solution) with the recorded finish time. The hub queries `ph_shikaku_is_done` for the solved-state badge and reads `shikaku_time_<date>`.

**Data source.** `datafiles/puzzles_shikaku.json` — an array of puzzles, cached in `global.ph_shikaku_cache`. Each entry:

```json
{ "date": "YYYY-MM-DD", "size": 6,
  "rects": [ {"r":0,"c":0,"w":2,"h":3,"cr":1,"cc":0}, ... ] }
```

Each rect is `(r,c)` top-left, `w` width (cols), `h` height (rows); the printed number = `w*h` and sits at clue cell `(cr,cc)` inside the rect. The `rects` list is **both the clue source and the unique solution**. `date` is optional; **date selection** uses the same two-pass logic as the other puzzles (exact `date` match wins, else `seed mod length`). If the file is missing, a hardcoded fallback (six 1×6 columns) is used. The shipped pool is 20 generator-verified unique puzzles dated 2026-06-01 onward.

**Save shape.** Completion is the single `SHIKAKU` key in `puzzles_solved` (counted automatically by `ph_solved_count_on` — no bookkeeping sub-keys to skip). In-progress state is persisted under `save.shikaku_state[date] = { rects: "r,c,w,h;…", hints: "i,j,…" }` so a player who leaves mid-puzzle resumes their rectangles and purchased hints. Finish time is `shikaku_time_<date>`.

### 4.5 Wordle

Not implemented. Coming-soon tile only — green card (`card_green.png`) with the `game_wordle.png` icon, `locked: true` and a "COMING SOON" badge. Tapping it does nothing.

### 4.6 Mix-Up

Not implemented. The card renders on the hub with `locked: true` and a "COMING SOON" badge. Tapping it does nothing.

---

## 5. Save format

File: `working_directory + "puzzlehub_save.json"`. JSON struct, currently `version: 1`. Fields:

| Field | Purpose |
|---|---|
| `version` | Save format version |
| `xp` | Total accumulated XP |
| `coins` | Coin wallet |
| `puzzles_solved` | Struct keyed by date string; each day is a struct of `puzzle_name → true`. Anygram persists per-word keys `ANYGRAM_W0`, `ANYGRAM_W1`, …, and a single `ANYGRAM_DONE` flag set on full completion. Legacy `ANYGRAM_M1` / `ANYGRAM_M2` keys from earlier saves remain readable via `ph_anygram_is_done`. |
| `gift_claimed_dates` | Array of date strings that have already paid out the 4th-puzzle gift |
| `anygram_bonus` | Struct keyed by date → struct of lowercased bonus words found |
| `streak` | Current consecutive-day streak |
| `anygram_time_<date>` | mm:ss string — recorded Anygram finish time per date |
| `sudoku_time_<date>` | mm:ss string — recorded Sudoku finish time per date |
| `sudoku_grid` | Struct keyed by date → 81-char string of the player's in-progress Sudoku grid (resume) |
| `shikaku_time_<date>` | mm:ss string — recorded Shikaku finish time per date |
| `shikaku_state` | Struct keyed by date → `{rects, hints}`: the player's in-progress rectangles (`"r,c,w,h;…"`) and revealed hint clue indices (`"i,j,…"`) for resume |

The save is rewritten on every solve event, hint purchase, and bonus-word discovery. Forward-compat: missing fields are backfilled to safe defaults on load.

### 5.1 Reset gesture (hidden)

The Profile screen exposes a hidden **triple-tap-Level** gesture that wipes the save. Tapping the "Level X" text three times within a 2-second window calls `ph_save_reset()`, which deletes `puzzlehub_save.json` from disk and reassigns `global.save` to a fresh struct (`xp = PH_INITIAL_XP`, `coins = PH_INITIAL_COINS`, empty `puzzles_solved` / `gift_claimed_dates` / `anygram_bonus`, `streak = 0`).

A `PROGRESSION DELETED` toast appears centered above the stats card for ~2 seconds, then the room transitions to `rm_hub` so the player sees the freshly-zeroed daily progression tube. The tap window resets between tap sessions: a single stray tap that's never followed up has no effect.

Lives in:
- `objects/obj_profile/Create_0.gml` — counter / window constants / toast / pending-hub timer
- `objects/obj_profile/Step_0.gml` — tap-region hit test, counter logic, reset trigger
- `objects/obj_profile/Draw_64.gml` — toast render
- `scripts/scr_save/scr_save.gml` — `ph_save_reset()`

Intended for player-driven QA and "start over" without an in-game settings UI. If a visible Settings → Reset Progress button is added later, this gesture can be kept (cheap to maintain) or removed.

---

## 6. Open balancing questions

- Should the 10-coin bonus-word reward stay? It pads the wallet quickly if the puzzle author packs a lot of bonus words.
- Hint pricing: 100 coins per cell is steep — players need a full level-up to afford one hint after spending their starting wallet.

---

## 7. Recent code changes (2026-06-02)

**Custom UI background art — Pill chips + tiled background pattern.**

Two new art assets replace the previous primitive-drawn UI backgrounds:

- `datafiles/icons/Pill.png` (250×84, white capsule with a baked soft drop shadow) — the shared background for every pill-shaped chip.
- `datafiles/icons/BG Pattern.png` (100×100, cream texture) — tiled background that replaces the old dot grid.

Changes:

- `obj_persistent/Create_0`: loads `global.spr_pill` and `global.spr_bg_pattern` (both with a top-left origin so 9-slice / tiling math is direct).
- `scr_draw`: new `ph_draw_pill(x1,y1,x2,y2,col,alpha)` draws `Pill.png` as a horizontal 3-slice — end-caps scaled to a true semicircle of the target height, flat middle stretched horizontally only. The white art is tinted by `col`, so any pill colour and translucency is possible.
- `scr_draw`: `ph_draw_chip` now delegates to `ph_draw_pill` for **capsule-proportioned** chips (corner radius ≈ half the height). Lower-radius rounded rectangles — panels, puzzle boards, win cards — keep the original primitive shadow+fill drawing, so nothing is distorted. This single change re-skins every pill across all screens (hub HUD LVL/Coin, toolbar check/shuffle/hint/cost chips, win-screen action and reward pills, etc.).
- `scr_draw`: `ph_draw_dot_bg` now tiles `BG Pattern.png` into its cached surface instead of drawing a dot grid. The `_col` argument is retained for call-site compatibility but is unused (the art defines its own colour). Affects all five screens that call it (hub, anygram, sudoku, shikaku, word wave).
- `obj_hub/Draw_64`: the game-card buttons (COMING SOON / PLAY / timer / SOLVED / best-time) were drawn with translucent `ph_draw_rounded` + manual `draw_set_alpha`; these are now single `ph_draw_pill` calls with the alpha passed directly.

**New coming-soon tile: Wordle.** Added a sixth hub card (locked) — see §4.5.

- `obj_persistent/Create_0`: loads `global.spr_card_green` (`card_green.png`) and `global.spr_game_wordle` (`game_wordle.png`).
- `scr_constants`: WORDLE entry added to `ph_game_cards()` before Mix-Up — green card, `locked: true`, `btn_type: "locked"`, deep-green text. No room (handled by the existing locked-card guard in `obj_hub/Step_0`).

---

## 7b. Recent code changes (2026-06-01)

**New puzzle: Shikaku.** Added a fourth playable puzzle (see §4.4).

- New logic script `scripts/scr_shikaku/scr_shikaku.gml`: loader/cache, date selection, `ph_shikaku_make`, rectangle validation (`ph_shikaku_rect_is_correct`), full-solution check (`ph_shikaku_check_solution`), save state serialise/restore, `ph_shikaku_is_done` / `ph_shikaku_mark_done`.
- New controller `obj_shikaku` (Create/Step/Draw) + room `rm_shikaku`. Drag-corner-to-corner input, tap-to-delete, blue accent, shape-glyph hint, win overlay + confetti — mirrors Sudoku.
- New data `datafiles/puzzles_shikaku.json` — 20 generator-verified uniquely-solvable 6×6 puzzles (dated 2026-06-01 onward).
- `scr_constants`: added `PH_COL_BLUE` / `_SOFT` / `_DEEP`, `PH_SHIKAKU_INDEX = 3`, and a SHIKAKU entry in `ph_game_cards()` (inserted before Mix-Up).
- `obj_persistent/Create_0`: loads `global.spr_card_blue` (`card_blue.png`) and `global.spr_game_shikaku` (`game_shikaku.png`).
- `obj_hub`: review-mode flag (`global.shikaku_review_mode`) in Step, and finish-time badge prefix (`shikaku_time_`) in Draw.
- Save: new `shikaku_time_<date>` and `shikaku_state` fields (see §5).
- **Assets to add (placeholders until provided):** `datafiles/icons/card_blue.png` (1400×400 card background, blue) and `datafiles/icons/game_shikaku.png` (512×512 game icon). Until both PNGs exist the Shikaku card sprite/icon will render blank; the puzzle itself plays fine.

---

## 8. Recent code changes (2026-05-23)

**Profile triple-tap reset gesture (easter egg).**

- New `ph_save_reset()` in `scripts/scr_save/scr_save.gml` deletes `puzzlehub_save.json` from `working_directory` and returns a fresh save struct.
- `obj_profile` now registers a Create event. `Create_0.gml` initializes the level-tap counter (`level_tap_count`, `level_tap_last`), the 2-second tap window (`LEVEL_TAP_WINDOW_MS = 2000`, `LEVEL_TAP_REQUIRED = 3`), the toast (`toast_text` / `toast_col` / `toast_timer`, `TOAST_DUR = 120`), and a `pending_hub_timer` used to defer the room transition until after the toast plays.
- `obj_profile/Step_0.gml` ticks both timers each frame (regardless of input lock), and on a confirmed press inside a 500×100 px rectangle around the Level text (centred on PH_W/2, 870), increments the counter — resetting to 1 if the gap since the last tap exceeded the window. On the 3rd qualifying tap it calls `ph_save_reset()`, sets the toast to "PROGRESSION DELETED" in `PH_COL_PINK_DEEP`, and arms `pending_hub_timer` so the room transitions to `rm_hub` once the toast finishes. Input is frozen while the toast plays.
- `obj_profile/Draw_64.gml` appends a toast block under the bottom-nav draw call, using the same chip/text style as the Anygram toast (chip at PH_W/2, 440; fades out over the last 15 frames).
- See §5.1 for the player-facing description.

---

## 9. Recent code changes (2026-05-22)

**Anygram daily-puzzle data import.**

- Replaced `datafiles/puzzles_anygram.json` with **20 date-keyed GDD-format puzzles** covering 2026-04-23 → 2026-05-22 (with 10 gaps for dates whose source files still need fixes: 04-24, 04-27, 05-01, 05-02, 05-03, 05-05, 05-06, 05-12, 05-13, 05-15).
- The previous mixed array (2 GDD-format + 29 legacy 2-word entries) is gone; every entry now has `date`, 5-letter `letters`, 4 main `words`, `bonus_pool`, and `grid_size`.
- The loader's exact-date lookup means each of the 20 imported dates serves its hand-authored puzzle. Dates outside the imported window (or in the 10 gaps) fall back to seed-mod selection across the 20 puzzles.
- Source-of-truth for these puzzles lives in `../Daily Puzzle/Anygram Levels/` as one JSON per date.

**Smoother rounded UI corners + fonts.**

- `obj_persistent/Create_0.gml` now calls `display_reset(4, true)` (4× MSAA), bumps `draw_set_circle_precision` to 64, and turns on `gpu_set_texfilter(true)`.
- The combined effect: every `ph_draw_chip` / `ph_draw_rounded` corner — PLAY buttons, HUD pills, modal panels, toast chips, hint pill, win-screen card — renders with smooth edges instead of the faceted/aliased look the 24-segment default produced. Fonts come out noticeably softer because their anti-aliased glyph atlases (produced by `font_add`) are now sampled bilinearly instead of point-sampled, which matters most when the window is downscaled (e.g. on Retina). Heavily-downscaled icon sprites (50/512, 64/512, 72/512…) benefit from the same filter.
- MSAA needs application-surface drawing enabled (already on). If a target device doesn't support 4× MSAA the call silently no-ops; the 64-segment circles + bilinear filter still help.

**Anygram wheel repositioned (overlap fix).**

- Wheel moved up and slightly shrunk: `WHEEL_CY` 1530 → 1440, `WHEEL_R` 300 → 270, `LETTER_R` 215 → 195. New layout: wheel top ≈ 1170, wheel bottom ≈ 1710. Clears the tallest authored grid above by ~45 px and the toolbar pills below by ~55 px. The previous spec made the wheel disc bleed under the toolbar's HINT pill and chest icon — that's gone now.
- Wheel constants moved to the top of `Create_0.gml` so the grid `_wheel_top_y` clamp can reference them (they used to be declared after the clamp, which would silently return 0).

**Anygram grid sizing fix (overlap bug).**

- Grid now sizes itself to the *actual occupied extent* of the puzzle's cells (max - min + 1 per axis), not to absolute row/col indices. Previously a puzzle authored at row 4 was drawn as a 10-row grid with 4 empty rows on top, pushing the visible cells 266 px down into the wheel. Today's TRACK puzzle was one of 17/20 dailies affected.
- Added a safety clamp: if a tall puzzle would still cross the wheel area, `grid_y` is shrunk to leave a 20 px gap above `WHEEL_CY - WHEEL_R`.
- Draw and fly-tile target maths now subtract `grid_min_r` / `grid_min_c` when converting a cell's (r,c) into pixel space.

**Anygram visual design pass.**

- **HUD strip restructured:** timer pill moves to the left (next to the back arrow), a new coin-balance pill takes the right side. ANYGRAM title stays centred.
- **Coin balance moves to the top HUD.** Removed the centred coin display from the bottom toolbar. The coin-fly arc now lands on the top-right pill (and the pulse + overshoot bounce play there).
- **Wheel letter tiles repainted** pink-filled with white text by default. Selected state adds a deeper-pink fill, a soft white glow halo behind the tile, and an 8% scale-up — selection now reads as "elevated" rather than "swapped colors."
- **Hint button rebuilt** as a wide pill (bulb · "HINT" · cost chip with coin icon) in the bottom-right. The tap target is driven by `HINT_PILL_{L,R,T,B}` so layout and input stay in sync.
- **Crossing-cell yellow** only appears on *filled* shared cells; empty shared cells render in the same cream as everything else. Reduces pre-play visual noise.
- **Dot background faded to ~50% opacity** so it sits behind the UI instead of competing with it.

**Bonus-word slots row removed.**

- The small "WORDS TO FIND" tile row between grid and wheel is gone — both label and tile rendering stripped from `obj_anygram/Draw_64.gml`. Found bonus words are still listed in the toolbar chest's modal; nothing else changed.

**Anygram GDD §7/§8 alignment.**

- **Wheel geometry** moved to match the Anygram GDD layout diagram: `WHEEL_CY` 1380 → 1530, `WHEEL_R` 320 → 300, `LETTER_R` 230 → 215. The wheel now sits cleanly inside the y=1180..1920 wheel area with the bottom toolbar below it.
- **Live timer** moved from a pill between wheel and toolbar into the top HUD strip (right side, next to the title), matching GDD §7.
- **Cell reveal tween** retimed to peak at scale 1.10 over 12 frames (was 1.18 / 14 frames) per GDD §8.
- **Flying letter tiles** retimed to ~350ms with 60ms stagger per letter (was ~278ms / ~80ms). Main-word tiles now settle to 85% scale on arrival (was 60%); bonus-word tiles unchanged at 40%.
- **Coin arc** retimed to ~500ms and the coin counter now does a damped sine overshoot bounce on arrival in addition to the existing 1.0 → 1.25 → 1.0 pulse.
- **JSON loader** now accepts `bonus_pool` as an alias for `bonus` so puzzles authored directly from the Anygram GDD example can be dropped in unchanged.

---



**Anygram multi-word refactor + UX polish.**

- **N-word crossword.** `ph_anygram_make` now produces a normalized puzzle struct with an array of `words` (2 to 7) instead of fixed `main1` / `main2`. The on-disk legacy 2-word shape is still accepted and converted by `ph_anygram_make_legacy`. New helpers: `ph_anygram_all_solved`, `ph_anygram_cells_for_word`.
- **Save schema.** Per-word flags `ANYGRAM_W<i>` for resume; a single `ANYGRAM_DONE` flag for Hub-side completion checks. `ph_anygram_is_done` reads `ANYGRAM_DONE` and falls back to legacy `M1 && M2`. `obj_hub` was updated to use this helper in both Step and Draw.
- **Letter-tile fly animation.** Successful main and bonus words now spawn actual letter tiles that fly from each wheel node to their destination (grid cells for main, bonus icon for bonus). Replaces the previous coin-to-chest visual. Main-word tiles reveal cells on arrival; bonus-word tiles trigger a coin arc on the last letter.
- **Coin-drop animation.** After a bonus word's letters arrive at the bonus icon, a coin sprite arcs into the center coin counter with a 1.0 → 1.25 → 1.0 pulse on the balance text.
- **Shake feedback.** Invalid swipes (`bad` classification) play a brief horizontal shake on the wheel and trail line before clearing — adds tactile "no" feedback alongside the existing toast.
- **Bonus modal.** A tap on the toolbar bonus icon (chest, badge-counted) opens a centered modal listing every bonus word found this session. Closes on the X button or tap-outside.



**Audit pass.**

- Removed dead loose scripts `scripts/scr_fly_spawn.gml` and `scripts/scr_fly_update.gml` — their functionality is inlined inside `obj_anygram`.
- Fixed a calendar-grid tap bug in `obj_hub/Step_0.gml` that could swallow strip/card taps when the iteration walked past the end of the month.
- Pulled the bonus-word coin reward out of a magic number into `PH_BONUS_WORD_COINS`.
- Brought fresh-save defaults in line with the design spec (`xp = 100`, `coins = 300`) via new `PH_INITIAL_XP` / `PH_INITIAL_COINS` constants.
- Clarified the comment in `obj_persistent/CleanUp_0.gml` explaining what does and does not need explicit freeing.

**Anygram XP rework.**

- XP is no longer awarded per word. Solving Main 1 or Main 2 individually now grants 0 XP; finding a bonus word grants 0 XP.
- A single 100 XP grant fires inside `ag_check_win` exactly once, when both main words are solved. The win screen now shows "+100 XP" instead of "+200 XP".
- Toasts updated: main-word toasts now read "FOUND • <WORD>"; bonus-word toasts read "BONUS +10 COINS • <WORD>".
- The unused `PH_BONUS_WORD_XP` constant is left in place but no longer referenced anywhere — safe to delete later if not needed.
