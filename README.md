# Puzzle Hub

A "Daily Puzzles" mobile game built with **GameMaker**. Players solve a set of daily puzzles — earning XP, leveling up, and collecting coins.

> **Status:** `v0.3` in development. `v0.2` tagged (puzzles 6–10: Hue Sort, Color Link, Word Bend, Arrows, Ladder); `v0.1` is the rollback baseline. Private repo, shared for feedback.

## Puzzles
Ten daily puzzle types, each with its own rules:

- **Anygram** — crossword-style word find on a letter wheel
- **Sudoku** — classic 9×9 number logic
- **Word Wave** — find hidden words in a letter grid
- **Shikaku** — divide the grid into rectangles
- **Wordle** — guess the 6-letter word (the only puzzle you can lose)
- **Hue Sort** — swap tiles so the colors blend smoothly
- **Color Link** — connect colored dots, filling every cell (Flow Free)
- **Word Bend** — trace words to cover every letter on the board
- **Arrows** — slide the bent arrows out without collisions
- **Ladder** — word ladder: change one letter at a time

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
