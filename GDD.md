# Puzzle Hub — Game Design Document

_Last updated: 2026-06-01 · Version: 0.2 (in development; v0.1 tagged baseline)_

This document captures **what is actually implemented in code** today, not the long-term vision. Update it whenever an economy rule changes, a new puzzle ships, or a balancing constant is tuned. All gameplay numbers live in `scripts/scr_constants/scr_constants.gml` as `#macro`s — change them there and reflect the change here.

---

## 1. High-level concept

Puzzle Hub is a daily-puzzle container app. Each calendar day surfaces **10 unique puzzles** on a hub screen; the player earns XP and coins by solving them. Each daily puzzle can be solved exactly once — solving it locks a "finish time" for that day, and the player can travel back to play previous days from the calendar but cannot replay a day already solved. Future days are not accessible.

Five puzzle types — **Anygram**, **Sudoku**, **Word Wave**, **Shikaku**, and **Wordle** — are implemented. The remaining slot on the hub (Mix-Up) is a placeholder showing "COMING SOON".

**Wordle is the one puzzle that can be lost.** Every other puzzle can only be solved or left unfinished; Wordle adds a fail state (running out of guesses). A missed Wordle still records a finish time and pays a small consolation XP reward, but it does **not** count as a daily solve (no gift/streak credit) and shows a distinct "missed" state on the hub. See §4.5.

---

## 2. Economy

### 2.1 XP

| Rule | Value | Constant |
|---|---|---|
| Starting XP (new player) | 100 | `PH_INITIAL_XP` |
| XP per puzzle solved | 100 | `PH_XP_PER_PUZZLE` |
| XP per level | 500 | `PH_XP_PER_LEVEL` |

XP can be earned by playing any day's puzzle — including past days — so retroactive solves still progress the player.

**One XP grant per puzzle.** XP is awarded **exactly once** per daily puzzle — not per word, sub-step, or mini-objective. For Anygram that means: solving Main 1 alone grants 0 XP, solving Main 2 alone grants 0 XP, finding a bonus word grants 0 XP.

**Claimed on the win screen (not at completion).** The XP is no longer added the instant the puzzle is solved. Completing the puzzle opens the Win Screen (§2.7), where the player **claims** the reward — and may **double** it (100 → 200 XP) by watching a placeholder rewarded video. The single grant happens inside `ph_win_grant` when the claim button is pressed; a persisted `save.xp_claimed[<puzzle>_<date>]` flag guards against a second grant when an already-solved puzzle is re-opened in review mode. `*_check_win` therefore records time / done-flags / streak / gift but does **not** grant XP.

### 2.2 Levels

Level is derived from total XP: `level = floor(xp / 500) + 1`. So:

- 0–499 XP → Level 1
- 500–999 XP → Level 2
- 1000–1499 XP → Level 3
- …

Each level-up grants **100 coins** (`PH_COINS_PER_LEVEL`), but these coins are no longer added silently — they are awarded through the **Level-Up reward screen** (§2.6), where the player can choose to **double** them to 200 by watching a placeholder rewarded video. Because each puzzle grants exactly 100 XP and a level is 500 XP, at most one level-up can occur per puzzle, so the reward screen always concerns a single level.

At puzzle completion `ph_grant_xp(save, 100, /*auto_coins*/ false)` adds the XP but **defers** the level-up coins; if `levels_gained > 0` it sets `global.pending_levelup = { level, base_reward:100 }` for the reward screen to consume.

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

### 2.5 Hint acquisition flow (modal + rewarded video)

This flow is shared by **all four playable puzzles** (Anygram, Sudoku, Word Wave, Shikaku) via one helper script, `scr_hint` (see implementation note below).

Hints are no longer a single-tap coin spend. Tapping the HINT pill opens a **slide-up bottom-sheet modal** that offers two ways to pay for the same reveal:

1. **Pay 100 coins** (`PH_HINT_COST`) — the modal closes, 100 coins are deducted (`ph_spend_coins`), a **"-100" feedback** rises and fades next to the top-HUD coin pill, and the hint is revealed. If the player can't afford it, the modal closes and a "NOT ENOUGH COINS" toast shows instead.
2. **Watch a free rewarded video** — opens a full-screen dark **placeholder** screen showing "VIDEO PLAYING". After 5 seconds a close **X** appears top-right; tapping it closes the placeholder and reveals the hint with **no coins removed**.

The modal layout (per design reference): large bulb icon up top, the title "Want to use a hint?", and two pill buttons at the bottom — left "100" + coin icon, right "FREE" + retro-TV icon. A pink close-X sits at the sheet's top-right; tapping it (or the dimmed area above the sheet) dismisses the modal with no charge and no reveal.

**Placeholder status.** The dark "VIDEO PLAYING" screen is a stand-in for the ad SDK, used to validate the flow before any rewarded-ad network is integrated. The 5-second delay before the X appears emulates a non-skippable ad. When the SDK lands, only the placeholder screen and its timer are replaced; the modal, coin path, and reveal logic stay as-is.

**Implementation (`scr_hint`).** The whole flow lives in one struct-based helper so the four puzzles share a single source of truth. Each controller creates a flow struct in Create — `hint = ph_hint_create(<apply_method>, <accent>)` — passing a puzzle-specific reveal method (which reveals exactly one hint and does **not** touch coins) and an accent colour for the close-X discs (Anygram pink, Sudoku purple, Word Wave teal, Shikaku blue). The helper's API:

- `ph_hint_open(h)` — open the modal (call after the controller's own availability gate passes).
- `ph_hint_tick(h)` — advance the slide / "-100" / video timers; called once per Step.
- `ph_hint_input(h)` — handle taps while an overlay is open; returns `"none"` (nothing open — continue normal input), `"consumed"`, `"paid"`, `"freed"`, or `"poor"`. The coin spend (`ph_spend_coins`), "-100" trigger, reveal (`h.apply()`), and save are all done inside. Controllers `exit` whenever the result isn't `"none"`.
- `ph_hint_draw_feedback(h)` / `ph_hint_draw_modal(h)` / `ph_hint_draw_video(h)` — draw the "-100" at the coin pill, the slide-up sheet, and the full-screen dark placeholder (drawn last so it covers every layer).

Per puzzle, the reveal + availability methods are: Anygram `ag_apply_hint` / `ag_can_use_hint`; Sudoku `sd_apply_hint` / `sd_can_hint`; Word Wave `ww_apply_hint` / `ww_can_hint`; Shikaku `sk_apply_hint` / `sk_can_hint`. Each controller's HINT-pill handler runs its own "puzzle complete / nothing to reveal" gate (with the puzzle's existing toast wording) and only then calls `ph_hint_open`. The FREE button uses `global.spr_tv` (loaded from `retro tv icon.png` in obj_persistent). The video placeholder shows for `VIDEO_X_DELAY` (300 frames ≈ 5 s) before its close X appears.

### 2.6 Level-Up reward screen

When a puzzle's completion pushes the player past a level boundary, a dedicated **Level-Up screen** appears **after** that puzzle's win card and **before** the hub. It celebrates the new level and lets the player choose how to collect the level-up coins:

- **Take 100 coins** — grants `base_reward` (100, = `PH_COINS_PER_LEVEL`) and returns to the hub.
- **DOUBLE** — opens the shared placeholder rewarded video (`ph_video_overlay`, the same dark "VIDEO PLAYING" screen as the hint flow). After 5 s a close X appears; tapping it grants `base_reward × 2` (200) and returns to the hub.

There is no decline option — both buttons grant coins. The screen shows a star icon, "LEVEL UP!", a "LEVEL N" badge, a one-shot confetti burst, and the two pill buttons (100 + coin, DOUBLE + TV) on a purple backdrop.

**Flow / state.** When the player **claims** their XP on the Win Screen (§2.7) and that grant crosses a level boundary, `ph_win_grant` defers the coins (see §2.2) and sets `global.pending_levelup = { level, base_reward }`. The Win Screen's BACK button then routes via `room_goto(ph_levelup_pending() ? rm_win : rm_hub)`. The screen lives in the repurposed (formerly dead) **`rm_win` / `obj_win`** pair — the in-game win overlay is drawn inside each puzzle controller, so this room/object slot was free. `obj_win` reads `global.pending_levelup` in Create (bouncing straight to the hub if it's somehow empty), grants the chosen amount via `ph_grant_coins` + `ph_save_write`, clears the flag, and `room_goto(rm_hub)`. The reward is granted exactly once (`claimed` guard). Re-opening an already-solved puzzle (review mode) never grants XP, so it never queues a level-up.

### 2.7 Win Screen (shared)

Every puzzle's completion screen is drawn by **one shared controller** (`ph_win_*` in `scr_economy`) so all four puzzles share identical layout, flow, and animation; each puzzle supplies only its accent colour, name, claim key, and a `draw_recap(cx, top, box_w, box_h)` method that renders its mini solved board. The screen is full-screen on a teal backdrop (no white card) per the Penpot "Win Screen" design, stacking top-to-bottom: **WELL DONE!** → puzzle recap → "You solved todays \<PUZZLE\>" → "in \<mm:ss\>" time pill → level progress bar (star badge + `xp / 500`) → action area.

**Flow / states.**

1. **choose** — shows two buttons: **100 XP** (claim) and **DOUBLE** (watch video).
2. **DOUBLE** opens the same placeholder rewarded video as the Level-Up screen (`ph_video_overlay`); its top-right close **X** (after ~5 s) advances to **after_video**.
3. **after_video** — a single **200 XP** claim button.
4. **claiming** — pressing either claim button grants the XP once (`ph_win_grant`), then a flight of stars animates from the button to the progress bar while the bar fills and the `xp / 500` number counts up. A level-crossing fills the bar to full and queues the Level-Up screen (§2.6).
5. **done** — **SHARE** and **BACK TO HUB** slide up from the bottom. There is no way back to the hub until the reward is claimed.

**Share.** The SHARE button calls `ph_share_url(PH_SHARE_URL)` — the OS share sheet where a native extension is wired up (`global.ph_native_share`), otherwise a placeholder that copies the App Store link (`https://apps.apple.com/tr/app/puzzle/id1190624509?l=tr`) to the clipboard and shows a "LINK COPIED" confirmation. The celebratory confetti burst is owned by the controller (`ph_win_celebrate`).

**Review mode.** Re-opening an already-solved puzzle starts the controller directly in **done** (Share + Back) with the bar already full and `granted` locked, so XP is never re-claimed.

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

- **Message Prompt** (between the word grid and the wheel): a single unified feedback pill that surfaces **every** in-puzzle prompt — main word found, bonus word found, "already found", "not a key word", "not a valid word", and hint results. It is centred vertically in the gap between the grid bottom and the wheel top (the same slot the live word-preview pill occupies, so the swipe pill swaps seamlessly into the result message on release). Per the Penpot design (`Game Screen - Anygram`), it renders as a fully-rounded pill (design 900×100 px → 648×72 GUI px, expanding to fit longer messages) with bold white display-font text. Colour is semantic per result: teal for FOUND, purple for BONUS, yellow for ALREADY FOUND, gray for NOT A KEY WORD / puzzle-complete, pink for NOT A VALID WORD (with a wheel shake). It auto-hides after `TOAST_DUR` (90 frames). Found/bonus messages use a " - " separator, e.g. `FOUND - OCEAN`.

**Input.** Drag-to-spell on the wheel. The player traces a path through letters and releases to submit. Backtracking by reversing onto the second-to-last letter is allowed.

**Word classification** (`ph_classify_word`) returns `{kind, index}` where kind is one of:
- `main` → marks `puzzle.words[index].found = true`, spawns letter tiles that fly from each wheel node to the matching cells (in word-letter order), reveals cells on arrival. No XP awarded yet.
- `bonus` → grants 10 coins (no XP), spawns letter tiles that fly from each wheel node into the bonus icon; a coin sprite then arcs from the icon into the coin balance with a counter pulse.
- `dup` → already-found main or bonus; "ALREADY FOUND" toast, no reward.
- `neutral` → uses only wheel letters, ≥ 2 chars, not a key word; "NOT A KEY WORD" toast.
- `bad` → otherwise; "NOT A VALID WORD" toast, swipe trail shakes briefly before clearing.

**Hint.** The bulb button (bottom-right toolbar) reveals one unfilled, non-hint cell. Tapping it no longer charges coins immediately — it opens the **hint modal** (see §2.5). If no revealable cell exists or the puzzle is already complete, the modal does not open and the action is rejected with a toast and no coins are spent. The actual reveal is performed by `ag_apply_hint()` (find the next unfilled, non-hint cell, mark it `hint`+`filled`, save); `ag_can_use_hint()` is the up-front availability guard.

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

**Hint.** The HINT pill opens the shared hint modal (§2.5 — pay 100 coins or watch a placeholder rewarded video). The reveal (`sd_apply_hint`) exposes one correct number: the selected empty cell if any, otherwise a random empty cell. Revealed cells are flagged as hints (gold) and persist in the saved grid. If no empty non-given cell remains, the modal doesn't open ("NO CELLS TO REVEAL").

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

**Hint.** The HINT pill opens the shared hint modal (§2.5 — pay 100 coins or watch a placeholder rewarded video). The reveal (`ww_apply_hint`) rings **only the first letter** of the first unfound word whose start isn't already ringed (the player still traces the rest). If none qualifies or the puzzle is complete, the modal doesn't open and a toast explains why. Hinted cells persist via re-derivation on resume (the rings re-appear because they mark word starts; only hinted starts are stored in the live `hint_cells` map for the session).

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

**Hint.** The HINT pill opens the shared hint modal (§2.5 — pay 100 coins or watch a placeholder rewarded video). The reveal (`sk_apply_hint`) exposes the *shape* of one number's correct rectangle as a **small rounded glyph in that number's cell corner** — its proportions match the solution's width×height (e.g. 9 → a small 3×3 square glyph; 3 → a small 1×3 bar). The glyph is deliberately smaller than the number and does **not** place the rectangle for the player; it only communicates the orientation/dimensions. It targets the first number that isn't already hinted and isn't already correctly enclosed. If none qualify, the modal doesn't open ("NO HINTS LEFT"). Revealed hint glyphs persist across resume.

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

**Genre.** Classic Wordle on a **6-letter × 6-guess** board (the design spells "WORDLE" across the top row). Guess the hidden word; each submitted guess colours its tiles — **green** (right letter, right spot), **yellow** (in word, wrong spot), **gray** (absent) — using true two-pass duplicate-letter logic (`ph_wordle_score_guess`). The accent colour is **green** (`PH_COL_GREEN`, #00be49).

**Reward.** Solving grants the single **+100 XP** (`PH_XP_PER_PUZZLE`), claimed on the shared win screen like the other puzzles; a win counts toward the 4th-puzzle gift box and the streak. **A loss** (see below) instead grants a **25 XP** consolation (`PH_WORDLE_GIVEUP_XP`, doublable to 50) and does **not** count as a solve.

**Layout** (per the Penpot "Game Screen - Wordle"; differs from Sudoku/Shikaku):
- **Top bar:** back arrow, **"WORDLE"** title centred in green, **coin-balance pill top-right**.
- **Message-prompt pill** under the HUD — the shared semantic toast (NOT A WORD, HINT USED, etc.).
- **Guess grid:** 6×6 rounded tiles; the active row fills as you type; submitted rows reveal green/yellow/gray with a per-column staggered settle animation; the on-screen keyboard recolours to each letter's best-known state.
- **Custom on-screen keyboard** (the OS keyboard is never used): 3 QWERTY rows + a **DEL** key and a centred **SEND** key.
- **Bottom bar:** **timer pill** (left) and **HINT pill** (right).

**Input.** Tap the custom keyboard to fill the active row, DEL to erase, SEND to submit. A guess must be a valid word in the validation list (`ph_wordle_is_allowed`) or it's rejected ("NOT A WORD"); the current answer is always allowed.

**Hint.** The HINT pill opens the shared hint modal (§2.5 — pay 100 coins or watch a placeholder video). The reveal (`wd_apply_hint`) locks the correct letter at the **leftmost not-yet-revealed position** into the active row as a green, un-deletable tile. Revealed letters **persist across rows and resume** (saved positions are re-applied each new row). When every position is revealed, the pill shows "NO HINTS LEFT".

**Completion (win).** Guessing the answer records `wordle_time_<date>`, sets the `WORDLE` solved flag, grants the gift/streak, and shows the shared win screen (teal backdrop, green accent, recap = the mini guess grid) where the +100 XP is claimed.

**Loss / lost-aversion flow.** When the player runs out of guesses (6th wrong guess), a funnel runs before the loss is final:
1. **"You can still win!" modal** — buy **+3 extra moves for 100 coins** (`PH_WORDLE_EXTRA_COST` / `PH_WORDLE_EXTRA_MOVES`), or watch a **free** placeholder video for the same, or **Give up**. The extra-moves purchase is **one-time**; using it extends the board to 9 rows (cells shrink to fit the same space).
2. **"Giving up?" confirm** — Give up / Cancel.
3. **"UNLUCKY!" lose screen** (red backdrop) — guess-grid recap, **"You finished todays WORDLE in mm:ss"** (a finish time is recorded even on a loss), level progress bar, and a **Claim your reward** of **25 XP** (or **DOUBLE** → 50 via placeholder video), then **BACK TO HUB**. The XP claim routes through the same level-up deferral as the win screen (a crossing queues the Level-Up reward screen). A loss sets `WORDLE_MISSED` (skipped by `ph_solved_count_on`, so no gift/streak credit) and locks the day.

**Hub state.** A solved Wordle shows the finish time (normal). A **missed** Wordle shows the finish time in **red** (the Penpot Pill "Missed" variant), distinct from PLAY/SOLVED, and re-opening it returns to the UNLUCKY screen. A missed day is not replayable.

**Data source.** `datafiles/puzzles_wordle.json` — array of `{ "date"?: "YYYY-MM-DD", "answer": "<6 letters>" }`, two-pass date selection (exact `date` wins, else `seed mod length`), hardcoded fallback `STREAM` if the file is missing. Validation list: `datafiles/wordle_allowed.json` — a flat array of uppercase 6-letter strings (`global.ph_wordle_allowed` map). _Current pool is a small test set; expand the allow-list for production._

**Save shape.** Win → `WORDLE` in `puzzles_solved`; loss → `WORDLE_MISSED` (skipped from the daily count). Finish time `wordle_time_<date>` on both. In-progress + final state in `save.wordle_state[date] = { guesses, extra, hints, status }` for resume (`status` ∈ `in_progress`/`won`/`lost`). XP claim guarded by `save.xp_claimed["wordle_<date>"]`.

### 4.6 Hue Sort

**Genre.** Colour-gradient sorting puzzle (the "I Love Hue" mechanic) on a **5×5 grid** (`PH_HUESORT_SIZE`). The tiles form a smooth two-dimensional colour gradient; at the start the interior tiles are scrambled and the player rearranges them so the colour field reads smoothly again. The accent colour is **violet** (`PH_COL_VIOLET`, #a838de).

**Reward.** Solving grants the single **+100 XP** (`PH_XP_PER_PUZZLE`), claimed on the shared win screen like the other puzzles; it counts toward the 4th-puzzle gift box and the streak. There is **no loss state** — the puzzle can always be solved.

**Board & gradient.** The four **corner tiles are locked anchors** (drawn with a small white pin dot) and define the whole board: every cell's target colour is the **bilinear interpolation** of the four corner colours (`tl`, `tr`, `bl`, `br`). With a 5×5 board that leaves **21 movable interior tiles**. Geometry mirrors Shikaku — a 960 px board centred horizontally, sat below the HUD.

**Layout** (1080×1920 portrait).
- **Top HUD strip:** back arrow on the left, **"HUE SORT"** title centred in violet, coin-balance pill top-right.
- **Instruction line** above the board: "Swap tiles so the colours blend smoothly".
- **Board:** the 5×5 grid of rounded colour swatches on a white backing card; locked corners carry a pin dot.
- **Bottom toolbar:** **timer pill** (centre) and **HINT pill** (right) — same structure as Shikaku (no chest, no number pad).

**Input — drag-and-drop swap.** Press a movable tile to pick it up (it lifts onto the finger, slightly enlarged with a halo; its home cell shows an empty slot). Release over another movable tile to **swap** the two. Releasing over a locked tile, an already-anchored tile, the source cell, or off the board cancels the move. Each committed swap saves the board and checks for a win (`hs_swap` → `hs_check_win`).

**Hint.** The HINT pill opens the shared hint modal (§2.5 — pay 100 coins or watch a placeholder rewarded video). The reveal (`hs_apply_hint`) takes the **first still-wrong interior tile**, brings its correct colour into place, and **anchors** that position (it gains a pin dot and can no longer be moved), so a hint is permanent progress. When no wrong interior tile remains, the pill shows "NO HINTS LEFT".

**Completion.** When every position matches its target colour (`ph_huesort_is_solved_arr`), `hs_check_win` fires: records `huesort_time_<date>` (mm:ss), sets the `HUESORT` solved flag, triggers the 4th-puzzle gift if applicable, updates the streak, and shows the shared win screen (violet accent, recap = the mini solved gradient) where the +100 XP is claimed.

**Review mode.** Tapping a completed Hue Sort on the hub re-enters with `global.huesort_review_mode = true`, going straight to the win overlay with the solved board and recorded time. The hub queries `ph_huesort_is_done` for the solved-state badge.

**Data source.** `datafiles/puzzles_huesort.json` — an array of puzzles, cached in `global.ph_huesort_cache`. Each entry:

```json
{ "date": "YYYY-MM-DD",
  "size": 5,
  "corners": { "tl": "RRGGBB", "tr": "RRGGBB", "bl": "RRGGBB", "br": "RRGGBB" } }
```

`date` and `size` are optional (size defaults to `PH_HUESORT_SIZE`). Corner colours are `RRGGBB` hex (a leading `#` is tolerated). **Date selection** uses the same two-pass logic as the other puzzles (exact `date` match wins, else `seed mod length`). If the file is missing, a hardcoded pink→yellow→purple→teal fallback is used. Authoring is just four corner colours — the gradient and the scramble are generated; the scramble is seeded by the date so every device sees the same daily board.

**Save shape.** Completion is tracked through the generic `puzzles_solved` map under the `HUESORT` key (a single flag, no per-tile bookkeeping keys, so `ph_solved_count_on` counts it automatically). Finish time is `huesort_time_<date>`. The in-progress board + anchored hint positions are persisted under `save.huesort_state[date] = { tiles, hints }` (`tiles` = comma-joined `RRGGBB`, `hints` = comma-joined indices) for resume. XP claim guarded by `save.xp_claimed["huesort_<date>"]`.

### 4.7 Mix-Up

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
| `wordle_time_<date>` | mm:ss string — recorded Wordle finish time per date (set on **both** win and loss) |
| `wordle_state` | Struct keyed by date → `{guesses, extra, hints, status}`: ";"-joined submitted guesses, the one-time extra-moves flag, ";"-joined revealed hint positions, and `status` (`in_progress`/`won`/`lost`) for resume |
| `huesort_time_<date>` | mm:ss string — recorded Hue Sort finish time per date |
| `huesort_state` | Struct keyed by date → `{tiles, hints}`: the player's in-progress board (comma-joined `RRGGBB`) and anchored hint positions (comma-joined indices) for resume |
| `xp_claimed` | Struct of `{claim_key: true}` guarding against a second XP grant on re-entry (e.g. `"wordle_<date>"`, `"huesort_<date>"`) |

In `puzzles_solved`, a Wordle **win** sets the `WORDLE` key (counts as a solve); a **loss** sets `WORDLE_MISSED`, which `ph_solved_count_on` skips so it does not count toward the daily total / gift / streak.

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

## 7. Recent code changes (2026-06-06)

**New puzzle: Hue Sort.** Added the sixth playable puzzle (see §4.6) — an "I Love Hue"-style colour-gradient sort — inserted on the hub before the locked Mix-Up card.

- New logic script `scripts/scr_huesort/scr_huesort.gml`: JSON loader/cache, hex⇄`{r,g,b}` helpers, bilinear corner-gradient build (`ph_huesort_make`), two-pass date selection, date-seeded interior scramble (`ph_huesort_scramble`), solved check, board serialise/restore, and completion tracking (`ph_huesort_is_done`/`mark_done`, `ph_huesort_save_state`/`load_state` — kept in this script, mirroring Shikaku).
- New controller `obj_huesort` (Create/Step/Draw_64) + room `rm_huesort`: 5×5 board with locked corner anchors, **drag-and-drop swap**, shared hint flow (`hs_apply_hint` anchors one correct tile), win via shared `ph_win_*`. No loss state.
- New data `datafiles/puzzles_huesort.json` (corner-colour palettes; one dated entry for 2026-06-06), registered as an IncludedFile.
- `scr_constants`: `PH_COL_VIOLET`/`_SOFT`/`_DEEP` (#a838de), `PH_HUESORT_INDEX`, `PH_HUESORT_SIZE`; HUE SORT entry added to `ph_game_cards()`.
- Hub card reuses the **orange card tile** (`spr_card_orange`, shared with the locked Mix-Up card) with orange-deep title text. `obj_persistent` loads `spr_game_huesort` for the card icon with a graceful fallback (mix-up icon) until dedicated icon art lands.
- `obj_hub`: `global.huesort_review_mode` wired in Step.
- Project manifest (`.yyp`): registered `obj_huesort`, `rm_huesort`, `scr_huesort`, the room order, and the data file.
- **Icon art pending:** `datafiles/icons/game_huesort.png` (drop in + register as an Included File to replace the mix-up-icon fallback). The card tile is final (orange).

## 7a. Recent code changes (2026-06-05)

**New puzzle: Wordle.** Added the fifth playable puzzle (see §4.5), promoting the former coming-soon green card. Built in phases (see `WORDLE_PLAN.md`):

- New logic script `scripts/scr_wordle/scr_wordle.gml`: loader/caches (answers + validation list), two-pass date selection, `ph_wordle_make`, `ph_wordle_score_guess` (green/yellow/gray duplicate logic), allow-list membership, win/loss detection, extra-moves grant, keyboard-state map, guess/state serialise.
- New controller `obj_wordle` (Create/Step/Draw_64) + room `rm_wordle`: 6×6 board, **custom on-screen keyboard** (QWERTY + DEL + SEND), staggered reveal, shared hint flow (`wd_apply_hint` locks a correct letter in place), win via shared `ph_win_*`, and the full **loss / lost-aversion flow** (aversion modal → give-up confirm → red UNLUCKY screen with 25/50 XP claim).
- New data `datafiles/puzzles_wordle.json` (6-letter answer pool) + `datafiles/wordle_allowed.json` (validation list). Both registered as IncludedFiles.
- `scr_constants`: `PH_COL_GREEN`/`_SOFT`/`_DEEP` (#00be49), `PH_WORDLE_LEN`/`GUESSES`/`EXTRA_MOVES`/`EXTRA_COST`/`GIVEUP_XP`/`INDEX`; WORDLE entry in `ph_game_cards()` flipped to playable.
- `scr_save`: `ph_wordle_is_done`/`mark_done`, `ph_wordle_is_missed`/`mark_missed`, `ph_wordle_save_state`/`load_state`; `WORDLE_MISSED` added to the `ph_solved_count_on` skip list.
- `obj_hub`: `global.wordle_review_mode` in Step; `wordle_time_` finish-time badge in Draw; **MISSED** card state (finish time in red `#a52424`).
- **Assets still to add (Phase 6 art, optional):** boxing-glove illustration for the lost-aversion modals and the Penpot key/tile styling are currently drawn as in-engine primitives. The puzzle plays fully without them.

---

## 7b. Recent code changes (2026-06-02)

**Hub-screen art pass — date badges, segmented progress bar, title.**

Four custom assets in `datafiles/icons/` replace primitive-drawn hub elements:

- `today_circle.png` (124×124, solid yellow disc) — background behind the "today/selected" date number in the 7-day strip. Replaces the `draw_circle` call. `global.spr_today_circle`, origin centred.
- `icon_check.png` (38×38, pink disc + white tick baked in) — the solved-day badge in the 7-day strip. Replaces the old "pink `draw_circle` + white `spr_icon_check`" pair, so it is drawn full-colour (no tint). `global.spr_check_badge`, origin centred. *(The card-list "SOLVED" pill still uses the white `spr_icon_check`; only the strip badge changed.)*
- `progress_bar_*` segment set (195×90 each): `purple_left`, `purple_center`, `purple_right`, `grey_center`, `grey_right`. Loaded with origin x=0/y=45 for left-to-right tiling. There is **no** `grey_left.png`; the unfilled left cap is produced by mirroring `grey_right` (negative x-scale).
- The hub progress tube (track + purple fill + tick dividers) is now `ph_draw_progress_segments(x1,x2,cy,h,total,filled)` in `scr_draw` — one cell per daily puzzle, first `solved_today` cells purple, rest grey, rounded end caps. Gift (at 4/10) and trophy markers are unchanged.
- **Game title:** "PUZZLE HUB" is drawn centred (pink, `fnt_disp_md`) between the LVL and coin pills at the top of the hub (`obj_hub/Draw_64`).
- **Progress bar hidden when calendar is open:** the whole progress-tube band (segments, gift, trophy, X/10 counter) now draws only while `_strip_alpha > 0.02` and fades out with the 7-day strip as the month grid expands. The expanded calendar is allowed to cover that band. `ph_draw_progress_segments` gained an optional `_alpha` argument for the fade.
- **Expanded month-grid day boxes:** the selected and today highlights in the open calendar now use box sprites — `calendar_day_bg_box_purple.png` (renders pink) for the selected day and `calendar_day_bg_box_yellow.png` for today (both 106×107, origin centred, `global.spr_cal_day_sel` / `spr_cal_day_today`). Solved days keep the teal rounded pill.
- **Open-calendar layout reflow:** since the progress tube no longer shows when the calendar is open, the post-calendar content is now anchored to the actual month-grid bottom (`_grid_rows = ceil(len(month_days)/7)`), blended by `cal_anim_t`. The teal background ends at `_grid_bottom + 16` (just under the last date row), and `_post_cal` drives the "TODAY'S GAMES" header (which rides higher — 40% of the section band when open vs 70% closed) and the card-list `_body_top`. Closed-state values are mathematically unchanged. `_body_top` is computed identically in `Draw_64` and `Step_0` so card tap targets stay aligned.
- **Game-tile text restyle:** card titles and subtitles are now black at 60% opacity (instead of a darkened shade of each card colour), with a larger title (`fnt_disp_md`, 44px) and subtitle (`fnt_body_sm`, 28px). Spacing unchanged. The `text_col` card field is retained — it still colours the PLAY-button label.
- `obj_persistent/Create_0` loads the nine new sprites; `CleanUp_0` frees them.

---

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

## 7c. Recent code changes (2026-06-01)

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
