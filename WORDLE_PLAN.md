# Wordle — Implementation Plan (spec + checklist)

_Status: ✅ **IMPLEMENTED** — all phases 0–6 built and verified in-engine (2026-06-05). Drafted 2026-06-04 against v0.2. GDD §4.5 + PROJECT_CACHE.md synced. Remaining (optional, non-blocking): boxing-glove art + exact Penpot key/tile styling (currently in-engine primitives); expand the test validation list for production._
_Wordle was a **locked coming-soon card**; now the **5th playable puzzle**, mirroring how Shikaku was added on 2026-06-01._

---

## 1. Concept & fit

Classic Wordle: guess a hidden **5-letter** word in **6 tries**. Each submitted guess colours its tiles — **green** (right letter, right spot), **yellow** (in word, wrong spot), **gray** (not in word) — and the on-screen keyboard recolours to match. One word per calendar day, same as every other puzzle.

It slots into the existing daily framework cleanly: one solve per day, retroactive play on past days via the calendar, +100 XP on solve, counts toward the 4th-puzzle gift box and the streak.

**The one structural novelty: Wordle can be _lost_** (6 wrong guesses). No other puzzle can fail. This is the single biggest design decision and is called out in §8 — everything else follows existing patterns.

---

## 2. Rules

| Rule | Value | Source |
|---|---|---|
| Word length | **6** (per Penpot design — 6×6 board) | new `PH_WORDLE_LEN` macro |
| Max guesses | 6 | new `PH_WORDLE_GUESSES` macro |
| XP on solve | 100 | existing `PH_XP_PER_PUZZLE` |
| XP on give-up (consolation) | 25 (→50 if doubled) | new `PH_WORDLE_GIVEUP_XP` |
| Extra moves (one-time only) | +3 guesses | new `PH_WORDLE_EXTRA_MOVES` |
| Cost of extra moves | 100 coins | new `PH_WORDLE_EXTRA_COST` |
| Hint cost | 100 coins / video | existing `PH_HINT_COST` |
| Accent colour | green **#00be49** | new `PH_COL_GREEN` / `_SOFT` / `_DEEP` |
| Daily index (gift/streak) | next free index | new `PH_WORDLE_INDEX` |

> **Note:** the designed board is **6 letters × 6 guesses** (the mockup spells "WORDLE" across the top row), not the classic 5-letter game. Keep length in a macro so it's tunable, but author the answer/allow-list as 6-letter words.

Feedback uses true Wordle duplicate-letter logic (two-pass): mark greens first, then yellows are assigned only from remaining unmatched answer letters, so a guessed letter that appears once in the answer but twice in the guess only lights one tile.

---

## 3. Layout (per Penpot "Game Screen - Wordle", 1080×1920 portrait)

The Wordle screen's HUD differs from Sudoku/Shikaku — match the **design**, not the other puzzles:

- **Top bar:** back arrow `<` far left, **"WORDLE"** title centred in green (#00be49, ~100px display font), **coin-balance pill top-right** (star-coin icon + balance + pink "＋", shared `Pill` component; coin-fly target).
- **Message Prompt pill** (900×100 design px → ~648×72 GUI, expands to fit) directly under the top bar — the shared semantic toast (same as Anygram): green for FOUND/HINT-USED, pink for NOT A WORD, etc. Mockup shows it green reading "HINT USED".
- **Guess grid:** **6 rows × 6 columns** of rounded tiles (215×215 design px each, small gap). Empty = light-gray; current row fills as letters are typed (black letter on light tile); submitted rows tint **green** (#00be49, correct spot) / **yellow** (present, wrong spot) / **light-gray** (absent), black letters. Flip/reveal animation on submit (per-column stagger, reuse the Anygram cell-reveal tween timing).
- **Custom on-screen keyboard** (REQUIRED — **game-specific keyboard, NOT the OS keyboard**): 3 rows of letter keys (QWERTY ordering: 10 / 9 / 7), a **⌫ DEL** key at the right end of the bottom letter row, and a centred **SEND** (Enter) key below the rows. Each letter key recolours to its best-known state (green > yellow > gray > untouched), matching the grid. Keys are the light pill style from the design.
- **Bottom bar:** **timer pill** (clock icon + mm:ss) on the left and the **HINT pill** (bulb + "HINT") on the right — both in the bottom bar per the design. No bonus chest. No coin balance here (it's top-right).

---

## 4. Interaction

- Tap the **custom on-screen keyboard** letters to fill the current row left-to-right (max 6). The OS/system keyboard is never invoked — input is entirely our own keyboard widget.
- **⌫ DEL** deletes the last letter in the current row.
- **SEND** submits when the row has 6 letters:
  - If not a valid word (see §6 dictionary) → row shakes, "NOT A WORD" toast, no guess consumed.
  - If valid → run feedback colouring, flip-reveal the row, recolour keyboard, persist, advance to next row, then check win/loss.
- On **win** (row all green) → stop timer, win overlay + confetti (shared `ph_win_*`).
- On **running out of guesses** (6th guess wrong) → the **Lost-Aversion flow** (see §8) — not an immediate loss.

---

## 5. Hint (shared `scr_hint`, §2.5 of GDD)

HINT pill opens the shared bottom-sheet modal (pay 100 coins **or** watch placeholder rewarded video). Reveal method `wd_apply_hint` + availability gate `wd_can_hint`, green accent for the close-X discs.

**Proposed reveal:** lock one correct letter into its correct column of the **current** (unsubmitted) row — a green "hint" tile the player can't overtype — targeting the leftmost still-unknown position. Persisted so it survives resume. Gate rejects ("NO HINTS LEFT") when the puzzle is solved/lost or all positions are already known/green.
_Alt options to decide: (a) recolour one keyboard letter as present/absent, or (b) reveal a definition/clue. Recommend the locked-green-tile reveal for clarity and parity with other puzzles' "reveal one cell" model._

---

## 6. Data & dictionary

Two files in `datafiles/` (copied to `working_directory` at runtime like the others):

- **`puzzles_wordle.json`** — answer pool of **6-letter** words, same two-pass date selection as every puzzle (exact `date` wins, else `seed mod length`):
  ```json
  [ { "date": "2026-06-04", "answer": "PUZZLE" }, { "answer": "WORDLE" }, ... ]
  ```
  Missing file → hardcoded fallback answer (e.g. `PUZZLE`).
- **`wordle_allowed.json`** — the **real 6-letter guess-validation list you'll provide.** Structure it as a flat JSON array of uppercase 6-letter strings so the loader can hash it into a lookup set directly:
  ```json
  ["ABASED","ABATED","ABBESS","ABDUCT", ... ]
  ```
  Cached in `global.ph_wordle_allowed`. Every answer in `puzzles_wordle.json` should also appear in this list (the loader can assert this in debug). A submitted guess is accepted only if it's in this set.

Answers are stored/compared uppercase. Loader caches parsed arrays in `global.ph_wordle_cache` (answers) and `global.ph_wordle_allowed` (guess set, stored as a struct/map keyed by word for O(1) membership).

---

## 7. Save shape (extends §5)

- **Win** flag in the generic `puzzles_solved[date]` map under key **`WORDLE`** (so `ph_solved_count_on` counts it toward the gift/streak — only on a true solve).
- **Loss** is tracked **separately** so it does **not** count as a solve: a `WORDLE_MISSED` flag in the same day-struct (skipped by `ph_solved_count_on`, like the `ANYGRAM_`/`WW_W` bookkeeping keys), **or** the `status` field inside `wordle_state` below. Either way, a missed Wordle locks the day (no replay) and shows the hub MISSED state, but doesn't inflate the daily-solved count.
- `wordle_time_<date>` — mm:ss finish time, recorded on **both win and loss** (per your instruction: a missed game still has a completion time — the Lose screen shows "You finished todays WORDLE in mm:ss").
- `wordle_state` — struct keyed by date → resume data: submitted guesses (e.g. `"CRANE;SLATED"` … 6-letter words), purchased hint positions, `extra_moves_bought` (0/1), and `status` (`in_progress` / `won` / `lost`). On `won` also writes `WORDLE` + time; on `lost` writes the MISSED flag + time.
- Forward-compat backfill in `ph_save_load`, same as `shikaku_state`.

---

## 8. Loss & lost-aversion flow (now designed in Penpot)

Decided: **a missed Wordle locks the day, records a finish time, and grants a small consolation reward** — it does **not** count as a solve. There's a multi-step lost-aversion funnel before the loss is final. All four screens exist in Penpot (`Game Screen - Wordle - Lost 1`, `… Lost 2`, `Lose Screen`, `Lose Screen - After XP Claim`).

**Step A — out of guesses → "Lost-Aversion" modal (`Lost 1`).** After the 6th wrong guess, a yellow bottom-sheet slides up: boxing-glove art, **"You can still win!"**, subtitle **"Get 3 more moves to solve the puzzle"**, and two pill buttons:
- **Pay 100 coins → +3 extra moves** (extends the board to 9 guesses).
- **FREE (watch rewarded video) → +3 extra moves** (same placeholder `ph_video_overlay`, then grants the 3 moves).
- A **"Give up"** text link at the bottom, and a close **X** (top-right disc).
Extra moves can be bought **once only** per puzzle. After the +3 are also exhausted, the modal offers only Give up / X (no second buy).

**Step B — "Giving up?" confirm modal (`Lost 2`).** Tapping "Give up" (or the X) shows a confirm sheet: **"Giving up?" / "Are you sure you want to give up this time?"** with **Give up** (red) and **Cancel** (green). Cancel returns to the board (or back to Step A).

**Step C — Lose / "UNLUCKY!" screen (`Lose Screen`).** Confirming give-up (or exhausting the extra moves) reveals the full-screen red-coral loss screen: **"UNLUCKY!"** headline → puzzle **recap** = the player's **6×6 Wordle guess grid** labelled **"WORDLE"** _(the current Penpot frame still shows a duplicated Word-Wave board + "WORDWAVE" label — to be swapped to the Wordle grid)_ → **"You finished todays WORDLE in mm:ss"** (timer pill) → level progress bar → **"Claim your reward"** with two buttons:
- **25 + star → 25 XP.** A finished puzzle's reward is always **XP** (the star icon = XP, same as the level star). Confirmed: give-up grants **25 XP**.
- **DOUBLE + TV** — watch the placeholder video to **double it to 50 XP**.
Like the win screen, claiming routes through the same XP-grant path (`ph_win_grant`-style), so a 25/50 XP claim that crosses a level boundary still queues the **Level-Up screen** (§2.6 of GDD). There is no decline — both buttons grant.

**Step D — `Lose Screen - After XP Claim`.** After claiming, the reward buttons are replaced by a single black **BACK TO HUB** button (no SHARE on the loss screen). Back routes via `room_goto(ph_levelup_pending() ? rm_win : rm_hub)`.

**Hub MISSED state.** A missed Wordle shows the **Missed** Pill variant on the hub card (`Design System > Pill`, property `Icon: Missed`, id `091b1857-3f69-804a-8008-205c999dac63`): a white pill (402×195, inner Rectangle 16 350×100) with the **timer icon** and the recorded finish time rendered in **dark red `#a52424`**. So a missed day reads as the completion time shown in **red**, distinct from a solved day's normal/green time and from the PLAY pill. The hub card logic picks: solved → time (normal), missed → time (`#a52424` Missed pill), else PLAY.

**Streak/gift:** a missed game is **not** a solve, so it does **not** advance the streak or count toward the 4th-puzzle gift box. The 25 XP consolation still applies (and can trigger a level-up) — intended: finishing a puzzle, win or lose, always pays XP; only a *win* counts as a daily solve.

---

## 9. Penpot design (connected — all game + loss screens exist)

Penpot is connected and the **Screens** board now contains the full Wordle set, so screens are build-to-match, not design-from-scratch:

- **`Game Screen - Wordle`** (1474×3061) — main board (see §3).
- **`Game Screen - Wordle - Lost 1`** — lost-aversion "You can still win!" modal (Step A).
- **`Game Screen - Wordle - Lost 2`** — "Giving up?" confirm modal (Step B).
- **`Lose Screen`** — "UNLUCKY!" reward-claim screen (Step C).
- **`Lose Screen - After XP Claim`** — BACK TO HUB state (Step D).

Win screen reuses the shared `ph_win_*` teal celebration (green accent, recap = mini guess grid).

**Resolved (2026-06-04):**
- **MISSED pill** — found: `Design System > Pill`, variant `Icon: Missed` (white pill + timer icon + finish time in `#a52424`). Use for the hub missed state.
- **Extra-moves cost** → **100 coins** (matches `Lost 1`).
- **Give-up reward** → **25 XP** (always XP; star icon = XP), DOUBLE → 50 XP.
- **Extra moves** → **one-time only**.
- **Level bar 800 / 1000** → placeholder art; code uses **500 XP/level** (`PH_XP_PER_LEVEL`).

**Minor design cleanup still to do in Penpot (not blocking):**
- **Lose Screen recap** still shows a duplicated **Word-Wave** board + "WORDWAVE" label → swap to the Wordle 6×6 guess grid + "WORDLE".
- **Tile/key state variants** — confirm exact yellow/gray key fills + pressed state against the `Wordle Tile` / `Pill` components.

_Note: a separate "Game Screen - Cross" frame and "Crossword Area" board also exist — an unrelated crossword puzzle in early design._

---

## 10. Implementation checklist (build order, when approved)

Mirrors the Shikaku add (GDD §7b). **Per project rules: no automated testing — you verify in-engine. Update GDD.md + PROJECT_CACHE.md as part of the work.**

1. **Constants** (`scr_constants`): add `PH_COL_GREEN` / `_SOFT` / `_DEEP`, `PH_WORDLE_LEN` (6), `PH_WORDLE_GUESSES` (6), `PH_WORDLE_EXTRA_MOVES` (3), `PH_WORDLE_EXTRA_COST` (100), `PH_WORDLE_GIVEUP_XP` (25), `PH_WORDLE_INDEX`. Flip the `WORDLE` entry in `ph_game_cards()` → `room:"rm_wordle"`, `locked:false`, `btn_type:"play_light"`.
2. **Logic script** `scripts/scr_wordle/scr_wordle.gml`: loader + caches (answers & allow-list-as-map), date selection, `ph_wordle_make`, two-pass feedback colouring (`ph_wordle_score_guess`), allow-list membership check, win/loss detection, state serialise/restore, `ph_wordle_is_done` (won) / `ph_wordle_is_missed` (lost) / mark helpers.
3. **Save** (`scr_save`): backfill + read/write for `wordle_time_<date>` (win **and** loss) and `wordle_state` (guesses, hints, `extra_moves_bought`, `status`); add `WORDLE_MISSED` to the `ph_solved_count_on` skip list so a loss doesn't inflate the daily count; `WORDLE` (win only) flows through normally.
4. **Controller** `obj_wordle` (Create/Step/Draw_64) + **room** `rm_wordle`: grid render, custom keyboard + input + key-state colouring, flip-reveal anim, shared hint wiring (`wd_apply_hint`/`wd_can_hint`), **lost-aversion funnel** (Lost-1 buy/free/give-up modal → Lost-2 confirm → reveal answer), win overlay via `ph_win_*`, **Lose/"UNLUCKY!" screen** (25/50 XP claim → BACK TO HUB), confetti, review mode (`global.wordle_review_mode`) for both won and missed states.
5. **Data** `datafiles/puzzles_wordle.json` (dated 6-letter answer pool) + `datafiles/wordle_allowed.json` (**your real 6-letter validation list**).
6. **Persistent** (`obj_persistent/Create_0` + `CleanUp_0`): card_green/game_wordle already loaded; load + free any new sprites the Wordle/Lose frames introduce (e.g. boxing-glove art, MISSED pill, key-state tiles) once exported from Penpot.
7. **Hub** (`obj_hub`): add `global.wordle_review_mode` in Step, `wordle_time_` finish-time prefix in Draw, and the new **MISSED** card state (distinct from PLAY/SOLVED) for a missed Wordle.
8. **`.yyp` registration**: add `scr_wordle`, `obj_wordle`, `rm_wordle` to the resource list and room order. _Expect a possible YYC link failure on first build → fix with a **Clean rebuild**, not code changes (auto-memory `project_puzzle_hub_yyc_clean_rebuild`)._
9. **Docs**: rewrite GDD §4.5 (Wordle — full spec incl. loss flow), update puzzle count (4→5 playable), add the new save fields/flags to §5 and the new constants to §2, add a dated "Recent code changes" block; re-sync PROJECT_CACHE.md (scripts, objects, rooms, data formats, globals).
10. **Gotchas to respect**: build any non-constant structs with explicit property assignment (no YYC linker traps); avoid reserved built-in names for instance vars; all gameplay numbers as macros; drawing is GUI-space; reuse `ph_video_overlay` for the FREE/DOUBLE placeholders.

---

## 11. Effort estimate

The heaviest puzzle add so far. Beyond a Shikaku-sized base it adds: the **custom keyboard** (widget + per-key state), the **lost-aversion funnel** (two modals + buy-moves/video logic), and a **full Lose screen with its own XP-claim flow** — all genuinely new to the codebase, plus a new **hub MISSED state**. Rough order: logic script ~200–250 LOC; controller ~600–800 LOC (keyboard + grid + reveal anim + 2 modals + lose screen); data authoring (answers + your allow-list). The lost-aversion + lose-claim flow is the main net-new engineering; the allow-list is the main authoring chore.

---

## 12. Phased build (resumable across sessions)

Because this is a large job, it's split into **7 phases, each one ~one session**. The guiding rule: **every phase ends with a project that compiles and is committed to git**, so a session boundary is always a safe stopping point and a fresh session can resume from this plan + the last commit. Per project rules, **you do the in-engine verification at each phase boundary** before we move on, and resources added trigger a **Clean rebuild** (auto-memory `project_puzzle_hub_yyc_clean_rebuild`).

| Phase | Scope | Ends with (committable state) |
|---|---|---|
| **0 — Scaffolding & wiring** | Constants (§2); empty `scr_wordle`; skeleton `obj_wordle` (Create/Step/Draw_64) + `rm_wordle`; register in `.yyp`; flip the `WORDLE` card to playable. | Game compiles; Wordle card opens a blank green room. |
| **1 — Logic only** | `puzzles_wordle.json` seed pool + your `wordle_allowed.json`; all pure functions in `scr_wordle` (make, date-select, two-pass scoring, allow-list check, win/loss detect, state (de)serialize). No UI. | Logic complete & self-contained; game still compiles. |
| **2 — Playable core** | 6×6 grid render; custom keyboard (QWERTY + DEL + SEND); type/DEL/SEND input; invalid-word rejection; feedback colouring + flip reveal; keyboard recolour; win → shared `ph_win_*`. | A Wordle you can actually win. |
| **3 — Save & resume** | `wordle_state` persist/resume; `wordle_time`; `WORDLE` solved flag + backfill; hub solved badge + review mode. | Progress survives app restart; hub shows solved state. |
| **4 — Hint** | Wire shared `scr_hint` (`wd_apply_hint` / `wd_can_hint`), green accent. | Hint modal + reveal work. |
| **5 — Loss flow** | Lost-1 modal (buy +3 for 100 / free video / give up, one-time) → Lost-2 confirm → reveal → Lose "UNLUCKY!" screen (25→50 XP claim) → back to hub; `WORDLE_MISSED` + skip rule; time-on-loss; hub **Missed** pill (`#a52424`). | Full lose path; missed games show on hub. |
| **6 — Polish & docs** | Confetti + anim timing; export/load new Penpot assets; rewrite GDD §4.5 + §2/§5; re-sync `PROJECT_CACHE.md`; bump puzzle count 4→5; tag version. | Ship-ready; docs in sync. |

**Dependencies:** strictly sequential except Phase 4 (Hint) and Phase 5 (Loss) which both depend only on Phase 3 and could be done in either order. A live task list tracks the 7 phases.

**Resuming in a fresh session:** read `PROJECT_CACHE.md` + this plan + `git log`, check the task list for the first unfinished phase, and continue. Auto-memory `project_puzzle_hub_wordle_plan` points here.
