# CLAUDE.md — Puzzle Hub

Guidance for AI assistants working in this repo. Keep this file SHORT: house rules + pointers only. Detailed knowledge lives in the docs below — don't duplicate it here.

## What this is
GameMaker (LTS, IDE `2026.0.0.16` / runtime `2026.0.0.23`) portrait mobile **daily-puzzle** app, designed at 1080×1920. Project manifest: `Puzzle Hub.yyp` (in this folder). A "Daily Puzzles" container: the player solves any `PH_PUZZLES_PER_DAY` (10) puzzles out of all available (currently 11), earning XP → Levels → Coins.

## Read these first (sources of truth, in order)
1. **`PROJECT_CACHE.md`** (this folder) — the codebase map: every script's API, object/room table, globals, data-file formats, conventions & gotchas. **Read it at the start of every session.** If it disagrees with the code, the code wins — re-verify before relying on a line.
2. **`../Daily Puzzle/Docs/GDD.md`** — design source of truth for all rules (XP, Levels, Coins, per-puzzle rules).
3. **`../Daily Puzzle/Docs/*_PLAN.md`** and `MISSIONS_PLAN.md` — per-feature plans.
4. Reference assets and docs live in the sibling `../Daily Puzzle/` folder.

## House rules
- **Don't run tests or verify builds yourself — ask Bora to do it manually**, unless he explicitly asks otherwise.
- **Keep docs in sync.** When gameplay numbers, files, globals, or boot/save flow change: update `PROJECT_CACHE.md`, and reflect rule/economy changes in `GDD.md`. Update the GDD as each puzzle/feature is built.
- **First look for optimization, logic errors, and fixes** before adding new work, per project intent.
- **All gameplay numbers are `#macro`s in `scr_constants`** — change them there, never hardcode. Reflect in `GDD.md`.

## Design (Penpot)
- UI designs live in **Penpot**, reached via the Penpot MCP. Before building or changing any screen/UI, check the current design there (run `high_level_overview` first) instead of guessing at layout, colours, or spacing.
- **If the Penpot MCP is unreachable, pause and ask Bora** — don't invent a design or proceed from memory; getting the UI wrong is costly to redo.
- V1/V2 boards are **read-only component instances**. Build new wireframes from scratch and reuse the component image fills; don't try to edit the locked instances.

## GameMaker gotchas (full detail in PROJECT_CACHE §8)
- **Adding resources / events corrupts on save:** GM rewrites `Puzzle Hub.yyp` on save. Register new resources only with **GameMaker fully quit**, then reopen + do a **YYC Clean rebuild** (a clean rebuild, not code changes, fixes the YYC link failure new resources trigger).
- **No struct literals with non-constant fields** — the YYC compiler throws linker errors. Build structs with explicit property assignment.
- **Watch reserved built-in names** (e.g. `video_open`) — prefix puzzle-specific state instead.
- **Native extensions** (iOS Safe Area, Local Notifications) have manual import/framework steps — see PROJECT_CACHE §8 before touching them.
- `PH_SUDOKU_TEST_PREFILL` must be `false` before shipping.

## Conventions
- Shared logic = pure functions in `scripts/`, prefixed `ph_`. One object + one room per screen.
- Drawing is GUI-space (`Draw_64`), sized to `PH_W × PH_H_dyn`. Use `ph_scissor_gui` for clipping.
- Level is derived, never stored: `level = floor(xp / 500) + 1`.
- iOS safe-area insets come from a native extension into `global.safe_top_gui` / `safe_bottom_gui`; anchor new screens to `ph_safe_top()` / `ph_safe_bottom()`.

## Repo
Private: `github.com/bhogha/Puzzle-Hub`. Current dev = v0.3 (project ver `0.3.0.0`); v0.2 tagged milestone, v0.1 baseline.
