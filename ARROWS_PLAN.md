# Arrows — Implementation Plan (spec + checklist)

_Status: 🟡 **PROPOSED — for discussion.** Drafted 2026-06-10 against v0.2; revised same day after reviewing the Penpot **`Game Screen - Arrows`** frame + the supplied assets. Decisions in §2 are now locked per your answers; remaining opens in §11. Mirrors the Color Link / Word Bend add pattern._

Arrows would be the **9th puzzle**, taking the locked coming-soon card slot the same way Word Bend (8th) and Color Link (7th) did.

---

## 1. Concept & fit — and the one big revision from the first draft

**Arrows – Puzzle Escape**: clear a board packed with arrows by tapping each one to send it flying off the grid, but only when the lane ahead is clear.

⚠️ **Revision after seeing your Penpot design + the icon:** the arrows are **not single-cell glyphs**. Each arrow is a **bent, multi-cell "snake" shape** that occupies a connected orthogonal path of cells and ends in an **arrowhead** pointing one of 4 directions. (The mockup shows a straight pink arrow, an S-bent orange one, an L-shaped teal one, etc.) This is the genuine mechanic, and structurally it puts Arrows in the **path-based family with Color Link and Word Bend**, not the simple single-tile model I first sketched. The rest of this plan reflects the bent-arrow model.

Fits the daily framework exactly like the others: one board per calendar day, retroactive play via the calendar, **+100 XP** on solve, counts toward the 4th-puzzle gift box and the streak.

**The one rule we change from the source game (your instruction): no "lives," no mistakes counter, no lose condition — only _time_ can be lost.** A blocked tap doesn't fail the run; it applies a **+5 s time penalty** to the finish time. This keeps Arrows in the no-loss family (Hue Sort / Color Link / Word Bend; Wordle stays the only loseable puzzle) while giving the timer a real stake — your finish time is your score, and careless taps cost you.

---

## 2. Rules — locked decisions

| Rule | Value | Note |
|---|---|---|
| Board | **8×8** grid | your call |
| Arrow shape | **bent multi-cell snake**, connected orthogonal path, arrowhead at one end | per Penpot design |
| Arrow directions | **4 orthogonal** (head points U / D / L / R) | your call |
| Escape rule | tap → arrow slides rigidly in its head's direction; escapes iff the cells it sweeps on the way off-board are clear of every other arrow | core mechanic |
| Blocked tap | shake + red flash + floating "+5s"; **+5 s** added to finish time | `PH_ARROWS_PENALTY_SECS = 5` (your call) |
| Win | all arrows cleared | board solved |
| Loss | **none** | your instruction |
| XP on solve | 100 | existing `PH_XP_PER_PUZZLE` |
| Hint cost | 100 coins / video | existing `PH_HINT_COST` (shared flow) |
| Bonus | none | like Sudoku / Shikaku / Color Link |
| Accent colour (title/HUD/theme) | **silver `#b8b9bd`** | from design; new `PH_COL_SILVER*` |
| Arrow body colours | **reuse Color Link's vibrant palette** (`ph_colorlink_color`), flat fills, each arrow distinct | your call |
| Difficulty | **flat — fixed 8×8, constant density every day** | your call (no weekday ramp) |
| Win recap | **show the initial (full) board state** | your call |
| Daily index (gift/streak) | next free `PH_ARROWS_INDEX` | new macro |

Boards are **always generated solvable** (§6), so a full clear always exists; the only variable outcome is time + how many blocked taps you ate.

---

## 3. The "only time is lost" mechanic

A blocked tap shakes the arrow (red flash), floats a brief **"+5s"** near the tap, and does `timer_base_secs += PH_ARROWS_PENALTY_SECS`. The timer is the existing shared **active-play timer** (`ph_timer_*`), so the penalty simply raises the base — it persists through pause/resume and is folded into the recorded finish time automatically. No fail state, ever.

---

## 4. Layout (per `Game Screen - Arrows`, 1080×1920 portrait)

The frame is a `column` flex (rowGap 100) — build to match:

- **Top bar:** back arrow `<` far left (black); **"ARROWS"** title centred in **silver `#b8b9bd`**; **coin-balance pill top-right** (shared `Pill`, star-coin + balance + pink "＋", coin-fly target).
- **Message-prompt pill** under the top bar — the shared semantic toast (same component as Anygram/Wordle). The mockup shows it silver-grey reading **"HINT USED"**.
- **Objective tip** (`ph_draw_game_tip`): **"Guide arrows out without causing any collisions"** — black @ 60% opacity, ~60px (matches the existing tip helper).
- **Board:** a **white rounded play-area card** with a faint **dot-grid** background (8×8). Each arrow is drawn as a **thick rounded path** (rounded caps/joins, like Color Link flows) in its vibrant colour, capped at the head end with an **arrowhead**. Board is bottom-anchored above the toolbar per the layout convention (PROJECT_CACHE §8).
- **Bottom bar:** **timer pill** (clock + mm:ss) left, **HINT pill** (bulb + "HINT") right. No bonus chest, no number pad — same minimal bar as Color Link / Word Bend.
- **Win overlay + confetti:** shared `ph_win_*` in the silver accent; **recap = the puzzle's initial (full) board** — all arrows in place as the player first saw them — plus "Cleared in mm:ss". (Persist the starting layout, since the live grid is empty on solve.)

---

## 5. Interaction

- **Tap anywhere on an arrow** (hit-test against any of its body cells) → attempt to launch it in its head direction.
  - **Compute the sweep:** translate the whole arrow one cell at a time in head_dir until every one of its cells has left the board. The set of off-arrow cells it passes over = the sweep. If the sweep contains **no other arrow's cells** → it escapes: animate the whole shape sliding out in head_dir, clear its cells, check win.
  - If the sweep hits another arrow → **blocked**: shake + red flash + "+5s" + `timer_base_secs += 5`. Nothing else changes.
- Single taps only — no drag, no multi-select (simplest input model; the arrow's own geometry is fixed).
- **Win** when the board has no arrows left → stop timer, shared win overlay.
- Past-day / review re-enters with `global.arrows_review_mode` and jumps to the win overlay (every puzzle does this).

---

## 6. Data & generation (always-solvable, bent arrows)

Like Color Link (Hamiltonian-cut) and Word Bend (board-tiling), boards **must be generated so a full clear order exists.** Build **in reverse**:

> Start from an empty grid. Repeatedly "un-escape" an arrow: pick a head cell + direction whose forward lane to the edge is currently empty, then grow a connected bent body **backward** from the head into still-empty cells (random orthogonal walk, allowed to bend, no self-cross). Mark those cells occupied and record the arrow `{ head_dir, cells:[...] }`. Because each arrow is placed only when its escape lane is clear, replaying the placements in reverse order is a guaranteed full solution. Density (how much of the 8×8 you fill) and bend frequency are the difficulty levers.

**`datafiles/puzzles_arrows.json`** — array, same two-pass date selection as every puzzle (exact `date` wins, else `seed mod length`):

```json
[
  { "date": "2026-06-15", "size": 8,
    "arrows": [
      { "head": "R", "cells": [[0,5],[0,6],[0,7]] },
      { "head": "D", "cells": [[2,1],[3,1],[3,2],[4,2]] }
    ] },
  { "size": 8, "arrows": [ ... ] }
]
```

- `head` ∈ `"U" | "D" | "L" | "R"`. `cells` lists the arrow's occupied cells; **`cells[0]` is the head cell** (where the arrowhead is drawn), the rest is the trailing body in order. Cells are 4-connected; the segment touching the head points along `head`.
- Validation (debug): every cell belongs to exactly one arrow; no two arrows overlap; each arrow is a valid connected non-self-crossing path; full board solvable by the reverse-order check.
- Missing file → hardcoded fallback board (a small hand-verified solvable grid), like every puzzle.
- Ship a **generator script** (Python, offline) to author a dated pool, plus a seeded runtime fallback so a daily board always exists.

`scr_arrows` (mirrors `scr_colorlink`/`scr_wordbend`): loader + cache `global.ph_arrows_cache`; `ph_arrows_for_date`; `ph_arrows_make` (raw → runtime `{ size, arrows:[{head, cells, color_idx}], cell_owner:[] }`); `ph_arrows_sweep_clear(state, arrow_idx)` (the slide-out collision test); `ph_arrows_is_solved` (no arrows left); `ph_arrows_first_clear(state)` (hint target — an arrow whose lane is currently clear); state serialise/restore (which arrows remain + accumulated penalty); `ph_arrows_is_done`/`mark_done` (`ARROWS` flag); fallback board.

---

## 7. Hint (shared `scr_hint`)

HINT pill → shared bottom-sheet (pay 100 coins **or** watch placeholder rewarded video). Reveal `ar_apply_hint` + gate `ar_can_hint`, silver disc accent.

**Reveal:** ring/pulse one arrow whose sweep is **currently clear** — a guaranteed-safe next move (`ph_arrows_first_clear`). Gate rejects ("NO MOVES TO SHOW") only when solved (there's always at least one clear arrow on an unsolved solvable board). Matches the other puzzles' "show one correct step" model; never solves it outright.

---

## 8. Save shape (extends scr_save §5)

- **Solve** flag in `puzzles_solved[date]` under key **`ARROWS`** — counts toward gift/streak via `ph_solved_count_on` normally (single flag, no skip rule).
- `arrows_time_<date>` — finish time (mm:ss) on solve, **including accumulated +5 s penalties** (they're folded into the timer base).
- `arrows_state` — struct keyed by date → resume data: the set of arrows still on the board (e.g. remaining-arrow id list or serialised grid), accumulated penalty seconds, `done` flag. Restored on re-entry, like `colorlink`/`wordbend` state.
- Forward-compat backfill in `ph_save_load`. No missed/loss flag — there's no loss.

---

## 9. Assets — supplied ✅

All three are already in `datafiles/icons/`:

- **`card_silver.png`** — hub card (silver, matches `#b8b9bd` accent). ✅
- **`game_arrows.png`** — hub card icon (silver bent-arrow maze glyph). ✅
- **`arrow.png`** — a clean straight arrow (rounded tail + head). Use it as the **arrowhead/straight-arrow art**; for bent arrows, draw the body as a thick rounded path (Color Link flow style) and cap the head with this arrow's head (or a derived arrowhead sprite). ✅

Per-arrow **vibrant colours** come from code (reuse/extend `ph_colorlink_color(index)`); the body is tinted, the dot-grid + white card are flat. New sprites loaded once in `obj_persistent/Create_0`, freed in `CleanUp_0`. The Penpot arrows use gradients — first pass can use flat vibrant fills (parity with Color Link); gradient bodies are a polish nicety, not required.

---

## 10. Implementation checklist (build order, when approved)

Mirrors the Color Link / Word Bend adds. **Per project rules: no automated testing — you verify in-engine; update GDD.md + PROJECT_CACHE.md as part of the work; register resources only while GameMaker is fully quit (auto-memory `project_puzzle_hub_yyp_clobber`); expect a YYC link failure on first build → Clean rebuild, not code changes.**

1. **Constants** (`scr_constants`): add `PH_COL_SILVER*` (`#b8b9bd` + soft/deep), `PH_ARROWS_PENALTY_SECS` (5), `PH_ARROWS_INDEX`. Flip the `ARROWS` entry in `ph_game_cards()` → `room:"rm_arrows"`, `locked:false`, `btn_type:"play_light"`, silver card.
2. **Logic script** `scripts/scr_arrows/scr_arrows.gml`: loader + cache, date select, `ph_arrows_make`, `ph_arrows_sweep_clear`, `ph_arrows_is_solved`, `ph_arrows_first_clear` (hint), state (de)serialize, `is_done`/`mark_done`, fallback board.
3. **Save** (`scr_save`): backfill + read/write for `arrows_time_<date>` and `arrows_state`; `ARROWS` flows through `ph_solved_count_on` normally.
4. **Controller** `obj_arrows` (Create/Step/Draw_64) + **room** `rm_arrows`: render the white card + dot grid + bent-arrow paths (thick rounded body + arrowhead, per-arrow vibrant colour); tap → `ph_arrows_sweep_clear` → slide-out anim **or** blocked shake + "+5s" + penalty; shared hint wiring; win via `ph_win_*`; confetti; review mode; shared timer with penalty folded into base.
5. **Data** `datafiles/puzzles_arrows.json` (dated solvable boards from the generator) + register as IncludedFile.
6. **Persistent** (`obj_persistent`): load + free `card_silver`, `game_arrows`, `arrow` sprites (+ any derived arrowhead).
7. **Hub** (`obj_hub`): add `global.arrows_review_mode` in Step + `arrows_time_` finish-time prefix in Draw (solved → time, else PLAY; no missed state).
8. **`.yyp` registration**: add `scr_arrows`, `obj_arrows`, `rm_arrows` to resources + room order (while GM is quit). Clean rebuild on first build.
9. **Generator**: offline Python script producing the dated solvable bent-arrow pool.
10. **Docs**: add GDD section (Arrows — full spec incl. bent-arrow model + time-penalty mechanic), bump count 8→9, add save fields/flags + constants, "Recent code changes" block; re-sync PROJECT_CACHE.md.

---

## 11. Decisions — all resolved ✅

1. **Difficulty** — **flat**: fixed 8×8, constant density every day. No weekday ramp.
2. **Arrow body colours** — **reuse Color Link's existing vibrant palette** (`ph_colorlink_color`).
3. **Arrow bodies** — **flat fills** (no gradients).
4. **Win recap** — **show the initial full board** (all arrows as first presented) + "Cleared in mm:ss". Requires persisting the starting layout.
5. **Penalty feedback** — shake + red flash + "+5s" (sound TBD during polish; non-blocking).

Plan is fully specified — ready for Phase 0 on your go.

---

## 12. Phased build (resumable across sessions)

Each phase ends compiling and committed, so a session boundary is a safe stop (same discipline as the Wordle plan).

| Phase | Scope | Ends with |
|---|---|---|
| **0 — Scaffolding & wiring** | Constants; empty `scr_arrows`; skeleton `obj_arrows` + `rm_arrows`; `.yyp` registration; flip ARROWS card → playable (silver). | Compiles; Arrows card opens a blank silver room. |
| **1 — Logic + generator** | `puzzles_arrows.json` seed pool + Python generator; pure functions (make, date-select, sweep-clear, solved, hint target, state). No UI. | Logic complete & solvable; game compiles. |
| **2 — Playable core** | White card + dot grid + bent-arrow render (thick path + arrowhead + per-arrow colour); tap → slide-out anim / blocked shake + "+5s" penalty; win → `ph_win_*`. | An Arrows board you can actually clear. |
| **3 — Save & resume** | `arrows_state` + `arrows_time` persist/resume; `ARROWS` solved flag; hub solved badge + review mode. | Progress survives restart; hub shows solved state. |
| **4 — Hint** | Wire shared `scr_hint` (`ar_apply_hint`/`ar_can_hint`), silver accent; ring a safe arrow. | Hint highlights a safe move. |
| **5 — Polish & docs** | Slide/penalty anim timing, confetti, optional gradient bodies; GDD + PROJECT_CACHE sync; bump count 8→9; tag. | Ship-ready; docs in sync. |

**Effort:** comparable to **Color Link** (path model, per-arrow colours, generated-solvable boards) plus a **rigid slide-out sweep animation** — heavier than my first single-cell estimate, lighter than Wordle (no keyboard, no loss funnel). Net-new work is the **bent-arrow generator** and the **sweep/slide animation**; everything else is established pattern.

---

_Rules research sources: [Arrow Escape (CrazyGames)](https://www.crazygames.com/game/arrow-escape-puzzle), [Arrows – Puzzle Escape (Google Play)](https://play.google.com/store/apps/details?id=com.ecffri.arrows), [Arrow Escape – Logic Puzzle (Google Play)](https://play.google.com/store/apps/details?id=com.infseekstudio.game.arrow.logic.escape&hl=en_US), [arrowescape.com](https://arrowescape.com/). Design source: Penpot `Game Screen - Arrows`._
