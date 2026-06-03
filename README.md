# Puzzle Hub

A "Daily Puzzles" mobile game built with **GameMaker**. Players solve a set of daily puzzles — earning XP, leveling up, and collecting coins.

> **Status:** `v0.2` in development (baseline `v0.1` tagged). Private repo, shared for feedback.

## Puzzles
- **Anygram**
- **Sudoku**
- **Word Wave**
- **Shikaku**
- **Wordle** _(coming soon)_
- **Mix-Up** _(coming soon)_

## Core loop
- Solve up to 10 daily puzzles; each solve grants **100 XP**.
- Solve 4 puzzles in a day for a **100 coin** bonus.
- Level up every **500 XP** (each level-up rewards **100 coins**).
- Spend coins on tips and boosters.
- Travel to previous days via the calendar to play missed puzzles.

## Built with
- GameMaker IDE `2026.0.0.16`
- Runtime `2026.0.0.23`

## Opening the project
Open `Puzzle Hub.yyp` in GameMaker.

## Project layout
- `objects/` — game objects (hub, puzzles, shop, profile, etc.)
- `rooms/` — rooms for each screen / puzzle
- `scripts/` — game logic (economy, save, dates, puzzles, drawing)
- `datafiles/` — fonts, icons, and puzzle data (`puzzles_*.json`)
- `options/` — per-platform export settings
- `GDD.md` — Game Design Document
