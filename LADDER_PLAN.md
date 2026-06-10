# Ladder — Build Plan (10th puzzle)

_Word Ladder ("Ladder"). Design: Penpot "Game Screen - Ladder" (V1 - Puzzle Hub). Icon: `datafiles/icons/game_ladder.png`. Accent `#ffc04c` (amber). Added 2026-06-10._

## 1. Concept / rules

A word-ladder chain. The player is shown a **seed word** (pre-filled) and must reach **10 consecutive words**, changing **exactly one letter** per step. Progress shows `N/10`.

- Per day all words share one **length** (declared in JSON; varies day-to-day, classic ladder).
- The chain is `start → words[0] → words[1] → … → words[9]` (11 words total; 10 to find).
- Each step has a **clue/description** (JSON-fed) shown in a box right above the keyboard.
- **Interaction:** tap a letter tile → it highlights (selected, amber `#ffc04c`); type a key → that tile's letter is replaced. If the resulting word equals the step's target → **all tiles flash green `#aaca31`**, the board advances to the new word, the next clue loads, tiles reset to base `#f1eae1`. If wrong → **tiles flash red `#eb5a5a`**, the letter reverts, selection clears.
- **Keyboard:** 3 QWERTY rows, letters only — **no DEL, no SEND**.
- **Hint:** highlights only the background of the tile that needs to change (the differing position), soft amber `#ffe5a8`. Costs `PH_HINT_COST` via the shared hint modal.
- **No loss state.** Unlimited attempts; wrong guesses only flash red. (Wordle remains the only losable puzzle.)
- **Win:** all 10 words found → shared win screen. `PH_XP_PER_PUZZLE` (100) XP, 4th-of-day gift, streak, level-up deferral — identical to the other puzzles.

## 2. Colors (from Penpot)

| Use | Hex | Macro |
|---|---|---|
| Base / empty tile + desc box | `#f1eae1` | `PH_COL_BOARD_BG` (exists) |
| Correct flash | `#aaca31` | `PH_COL_WB_FOUND` (exists) |
| Wrong flash | `#eb5a5a` | `PH_COL_LADDER_BAD` (new) |
| Accent / title / selected tile / toast | `#ffc04c` | `PH_COL_AMBER` (new) |
| Hint highlight | `#ffe5a8` | `PH_COL_AMBER_SOFT` (new) |
| Clue / progress / tip text | `#000` @ 60% | dark @ alpha 0.6 |

## 3. JSON — `datafiles/puzzles_ladder.json`

```json
[
  {
    "date": "2026-06-10",
    "length": 5,
    "start": "COLD",
    "steps": [
      { "word": "CORD", "clue": "A thin rope or string" }
    ]
  }
]
```

- `length` — letters per word for this day.
- `start` — seed word (shown pre-filled, not counted in N/10).
- `steps` — exactly 10 `{word, clue}`. Each `word` is `length` letters; consecutive words (incl. `start`→`steps[0]`) differ by **exactly one position**.
- Two-pass date select (exact `date` wins, else `seed mod len`), like every other puzzle. Missing file → hardcoded 5-letter fallback ladder.

## 4. Files

| File | Change |
|---|---|
| `scripts/scr_ladder/scr_ladder.gml` | NEW — loader/cache, `ph_ladder_for_date`, `ph_ladder_make`, `ph_ladder_diff_pos`, fallback. |
| `scripts/scr_constants/scr_constants.gml` | `PH_LADDER_INDEX 9`, color macros, `ph_game_cards()` card (card_orange + amber text), `ph_game_tip("ladder")`. |
| `scripts/scr_save/scr_save.gml` | `ph_ladder_is_done/mark_done`, `ph_ladder_save_state/load_state` (`save.ladder_state[date] = {step, hinted}`). |
| `datafiles/puzzles_ladder.json` | NEW — authored ladders. |
| `objects/obj_ladder/*` | NEW — Create/Step/Draw_64 + `.yy` (eventType 0/3/8·64). |
| `rooms/rm_ladder/rm_ladder.yy` | NEW — single `obj_ladder` instance. |
| `objects/obj_persistent/Create_0.gml` | load `global.spr_game_ladder`. |
| `objects/obj_hub/Step_0.gml` | LADDER review-mode block. |
| `Puzzle Hub.yyp` | register scr/obj/room + `puzzles_ladder.json` + `game_ladder.png` IncludedFiles + RoomOrder. |
| `GDD.md`, `PROJECT_CACHE.md` | document. |

## 5. Save schema

- Solved flag: `puzzles_solved[date]["LADDER"] = true` (single key → counted by `ph_solved_count_on` automatically; no skip rule).
- Progress: `save.ladder_state[date] = { step:int, hinted:int }` where `hinted` = step index with an active hint highlight (`-1` none). `current` word is derived: `step==0 ? start : words[step-1]`.
- Timer: shared `ph_timer_*` with key `"ladder_" + date`.

## 6. Layout (GUI, 1080×PH_H)

Top→bottom: HUD (back · LADDER · coin) → toast/game-tip → **word row** (N tiles, sized to fit) → `Question N/10` → **clue box** → **keyboard (3 rows, letters only)** → bottom bar (timer · HINT). Keyboard cluster bottom-anchored above the bottom bar (per project convention); word row sits in the upper-middle below the tip.

## 7. Build / registration note

`.yyp` is rewritten by GameMaker on save — register resources only while **GameMaker is fully quit**, then reopen and do a **Clean rebuild** (YYC link). Testing is left to the user per project rules.
