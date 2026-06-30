# Puzzle Hub — Project Cache (for Claude)

_Internal codebase map, kept terse to save tokens. Design rules live in `../Daily Puzzle/Docs/` (`GDD.md` = source of truth; per-puzzle `*_PLAN.md`, `MISSIONS_PLAN.md`). **If this drifts from the code, the code wins — re-verify before relying on a line.**_

---

## 1. What this is

GameMaker LTS (IDE `2026.0.0.16`, runtime `2026.0.0.23`) portrait mobile daily-puzzle app, designed at **1080×1920**. Project file: `Puzzle Hub.yyp` (this folder; sibling of the `Daily Puzzle` reference folder — see auto-memory `project_puzzle_hub_paths`).

**11 puzzles** (internal names): Anygram, Sudoku, Word Wave, Shikaku, Wordle, Hue Sort, Color Link (Flow Free), Word Bend (Elevate-style word trace), Arrows (tap-to-clear bent snake arrows), Ladder (word ladder), Colordoku (Queens/Meowdoku colour-region logic). **Daily goal = any `PH_PUZZLES_PER_DAY` (10) solves out of all available puzzles; every puzzle counts, display caps at 10/10.** Economy = XP / Levels / Coins.

**Player-facing display names + hub order (2026-06-30) — display text ONLY; internal `obj_*`/`rm_*`/`scr_*` names, solved keys, tip keys, save fields and review globals all keep the internal names.** Set in `ph_game_cards()` (`scr_constants`); each puzzle's on-screen title (in `obj_*/Draw`) and `puzzle_name` field match. Hub-tap logic in `obj_hub` keys on `_card.room` (not the name), so renames don't break it.

| Hub # | Display | Internal (room) |
|---|---|---|
| 1 | ARROW | Arrows (`rm_arrows`) |
| 2 | DOTS | Color Link (`rm_colorlink`) |
| 3 | WHEEL | Anygram (`rm_anygram`) |
| 4 | SUDOKU | Sudoku (`rm_sudoku`) |
| 5 | SHIKAKU | Shikaku (`rm_shikaku`) |
| 6 | WORD HUNT | Word Wave (`rm_wordwave`) |
| 7 | WORD | Wordle (`rm_wordle`) |
| 8 | COLORS | Hue Sort (`rm_huesort`) |
| 9 | LADDER | Ladder (`rm_ladder`) |
| 10 | DIAMOND | Colordoku (`rm_colordoku`) |
| 11 | BEND | Word Bend (`rm_wordbend`) |

**Loss states:** only **Wordle** can be lost (out of guesses → consolation XP + "missed" state; see `WORDLE_PLAN.md`). Arrows and Ladder have no loss — a bad move costs a +5 s time penalty / red flash only.

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
├─ datafiles/                  copied to working_directory at runtime
│  ├─ puzzles_*.json           date-keyed + seed-fallback puzzle pools
│  ├─ icons/                   PNGs, loaded via sprite_add in obj_persistent
│  └─ fonts/                   Lilita One (display), Nunito (body)
├─ extensions/                 iOSSafeArea, LocalNotifications, Haptics (iOS native)
└─ options/                    per-platform export settings
```

Code reads datafiles as `working_directory + "icons/..."` / `working_directory + "puzzles_*.json"`.

---

## 3. Scripts (the API surface) — `scripts/`

All functions global, prefixed `ph_`. No structs-with-methods except inline closures in objects.

| Script | Holds |
|---|---|
| `scr_constants` | All `#macro`s: palette colours, canvas, **economy numbers**, daily schedule indices, save filename, debug flags. Also `ph_game_cards()` (hub card list). |
| `scr_economy` | `ph_level_from_xp`, `ph_xp_in_level`, `ph_grant_xp(save,amt,_auto_coins=true)` (pass `false` to defer level-up coins to the Level-Up screen), `ph_grant_coins`, `ph_spend_coins`, `ph_levelup_pending`, `ph_xp_claimed/mark`, share helpers. **Shared Win Screen** (`ph_win_create/step/input/draw/grant/begin_claim/celebrate`): result line "Completed in [time pill]" + "Claim your reward!" + large reward-amount (`<amt>`+3D star) above the XP bar; reward buttons word-labelled (CLAIM / DOUBLE+TV); bottom nav stack SHARE·HOME / NEXT GAME / YESTERDAY. Nav helpers: `ph_puzzle_is_solved(room,date)`, `ph_win_next_unsolved_room(date)`, `ph_win_prev_unsolved_date(room,date)`, `ph_win_go_next`, `ph_win_go_yesterday`, `ph_win_route(room,date)` (detours via `rm_win` when a level-up is pending, stashing `global.post_levelup`). |
| `scr_hint` | **Shared hint flow** (modal + placeholder rewarded video), struct-based, used by every puzzle. `ph_hint_create(apply_method,accent,subtitle="",key="")`; `ph_hint_open/tick/input/is_open`; draw helpers. `ph_hint_input` → `"none"/"consumed"/"paid"/"freed"/"poor"`. Modal = "100 🪙" row + BUY/FREE+TV; greys/disables BUY when `coins < PH_HINT_COST`. **Post-buy reveal:** `apply()` returns target `{x,y,r}` (or `{iris:false,frames}` for custom reveal); BUY/FREE defers the result + plays a reveal, emitting `"paid"/"freed"` only after it ends — so the win-check lands after the reveal. ⚠️ controllers must poll `ph_hint_input` EVERY frame. `ph_hint_draw_reveal` = default iris; `ph_hint_revealing`/`_reveal_p` drive custom reveals (Color Link snake). `ph_hint_pill_draw(l,t,r,b,shadow)` draws the standard HINT pill and bounces it after `PH_HINT_IDLE_SECS` (5 s) idle (reads `global.ph_idle_anchor`). |
| `scr_save` | Load/write/reset save; per-puzzle solved tracking; streak recompute; bonus-word tracking; Sudoku grid + Wordle state persistence; `WORDLE_MISSED` skip in `ph_solved_count_on`; **shared pause/resume play-timer** (`ph_timer_get/set/now/commit/step` over `save.timers["<puzzle>_<date>"]`). Per-puzzle tip flags (`ph_tip_seen`/`ph_tip_mark_seen`, `save.tips_seen[$KEY]`). Ladder save-state helpers. **Central data layer.** |
| `scr_dates` | Date-key formatting (`ph_today_key`, `ph_date_key`), `ph_seed_from_key`, weekday/month math, `ph_date_add_days`. |
| `scr_puzzles` | Anygram + Word Wave loaders, normalizers, classifiers, solved checks. |
| `scr_sudoku` | Sudoku loader, normalizer, conflict/row/col/box/all-solved checks, grid serialize. |
| `scr_shikaku` | Shikaku loader, normalizer (clues + solution rects), per-rect correctness, full-partition check, state serialize/restore, done flag. |
| `scr_colorlink` | Color Link (Flow Free) logic: loader/cache + two-pass date select, `ph_colorlink_make` (reads `rows`/`cols`, legacy `size` ok; row-major `r*cols+c`), `ph_colorlink_color` (10-hue palette), `ph_colorlink_endpoint_color`, `ph_colorlink_is_solved`, `ph_colorlink_longest_unsolved` (hint), routes serialise/restore, `is_done`/`mark_done`. **Tall 9×7 (rows×cols)**, 6–7 flows, fallback 9×7. |
| `scr_huesort` | Hue Sort logic: loader/cache, hex⇄`{r,g,b}` helpers, `ph_huesort_make` (bilinear corner gradient → target + locked-corner arrays), date select, `ph_huesort_scramble` (date-seeded), `ph_huesort_is_solved_arr`, board serialise/restore, save helpers. |
| `scr_arrows` | Arrows logic: loader/cache + date select, `ph_arrows_make` (`{size,arrows:[{head,cells,len,color_idx}]}`), `ph_arrows_delta`, `ph_arrows_sweep_clear` (tip-lane clear test), `ph_arrows_is_solved`, `ph_arrows_first_clear` (hint), `ph_arrows_at` (cell hit-test), state serialise/restore (`save.arrows_state[date]={cleared,penalty,hinted}`), `ph_arrows_block_info`, `is_done`/`mark_done`. **Non-square 17×14 (rows×cols)**, ~83% fill, ~32–45 arrows/board, fallback 17×14. |
| `scr_ladder` | Ladder logic: loader/cache + date select, `ph_ladder_make` (`{length,start,words[],clues[],count}`), `ph_ladder_diff_pos`, `ph_ladder_current_word` (step→shown word), fallback `COLD→…→CORK`. Save helpers `{step,hinted,hint_lvl}` live in `scr_save`. |
| `scr_colordoku` | Colordoku (Queens) logic: loader/cache + date select, `ph_colordoku_make` (`{size,regions[],solution[]}`), `ph_colordoku_region_color` (6 pastels, avoids the teal gem), `ph_colordoku_adjacent`/`_pair_conflict` (same row/col/region or touching), `ph_colordoku_conflicts` (per-cell bad-queen bools), `ph_colordoku_is_solved`, `ph_colordoku_forced_x`/`_has_forced_x`. Hint places only the first `PH_COLORDOKU_HINT_XS` (3) forced X's as LOCKED. State = `save.colordoku_state[date]={cells,xlock}` (two 36-char strings); `ph_colordoku_save_state`/`load_xlock`. `is_done`/`mark_done`. 6×6, fallback unique board. |
| `scr_wordbend` | Word Bend logic: loader/cache + date select, `ph_wordbend_make` (rebuilds letter grid from word paths), **5×5**, `ph_wordbend_match` (traced seq vs unfound paths, fwd/rev), `ph_wordbend_is_solved`, `ph_wordbend_longest_unfound` (hint), found/hinted serialise (`save.wordbend_state[date]`), `is_done`/`mark_done`. Bonus-word dict via `ph_wordbend_load_dict`. |
| `scr_wordle` | Wordle logic: answer + validation-list loaders/caches, date select, `ph_wordle_make`, `ph_wordle_score_guess` (green/yellow/gray dup logic), `ph_wordle_is_allowed`, `ph_wordle_add_guess` (win/loss), `ph_wordle_grant_extra_moves`, `ph_wordle_keyboard_states`, guess serialise. Save-struct helpers (is_done/mark/is_missed/state) in `scr_save`. |
| `scr_missions` | **Weekly missions engine** (personal install-anchored window — see `Docs/MISSIONS_PLAN.md`). Mission catalog (`ph_mission_def`/`_catalog`, per-puzzle missions via `ph_mission_puzzles()`); weekly stats (`ph_week_new_stats`, `ph_week_metric` incl. `distinct_types`/`types_ge3`); queries (`ph_mission_value/progress/title/is_complete/claimable/claim`); lifecycle (`ph_week_init` / `ph_week_draw` w/ `ph_week_pick_band` cooldown / `ph_week_check_finish` / `ph_week_collect` → `ph_week_advance`). Counter hook `ph_week_record_solve(save,claim_key)` from `ph_win_grant` + generic `ph_week_bump`. Other counters: bonus words, no-hint (keyed by `ph_hint_create` 4th arg), speed (`ph_timer_get < PH_MISSION_SPEED_SECS`), Wordle ≤3, win-streak (`wordle_win_run/best`, reset via `ph_week_record_wordle_miss`). `ph_week_claim_all(save)`; `ph_week_time_left_str` (reset countdown). `hat_trick` still deferred (needs per-day distinct-type tracking). |
| `scr_draw` | Reusable draw helpers: `ph_draw_rounded/chip/text/text_shadow/icon`, easing (`ph_ease_in/in_cubic/out/out_cubic/in_out/back/out_back`), `ph_scissor_gui`/`reset`, hit tests, `ph_draw_nav` (bottom tab bar Shop/Home/Events), `ph_draw_burst`, `ph_draw_dot_bg` (now a flat `PH_COL_BG` fill — the old tiled `BG Pattern.png` was removed; `_col` arg ignored), `ph_safe_top`/`ph_safe_bottom`, `ph_draw_speaker_icon`/`ph_draw_vibrate_icon`. **Image buttons:** `ph_draw_reward_btn`/`ph_draw_nav_btn` draw a PNG background via `ph_draw_btn_bg(spr,x1,y1,x2,y2)` (horizontal 3-slice) when `ph_btn_sprite_for(body_col)` matches blue/green/pink/red, else fall back to primitive chip. **Puzzle widgets:** `ph_draw_game_tip`, `ph_draw_bonus_pill`, `ph_draw_word_tile`, `ph_draw_pill` (chip via `Pill.png`), `ph_draw_toast`, `ph_draw_highlight`. Trans-begin: `ph_trans_begin(ox,oy,col,room)` kicks the iris transition owned by `obj_persistent`. |
| `scr_fonts` | `ph_load_fonts()` — registers all `global.fnt_*` via `font_add`. |
| `scr_haptics` | **Central haptic manager** (iOS only; mirrors `scr_audio`). `ph_haptic_supported()` (=os_ios), `ph_haptic_enabled()` (& `save.haptics_on`), `_set_enabled`/`_toggle`/`_prepare`. Semantic API beside the `ph_sfx` hooks: `ph_haptic_tap/type/select/success/error/warning/win/levelup/coin`. `ph_haptic__fire(kind,arg,min_gap)` debounces per effect. Backed by native `Haptics` extension (UIKit generators). |
| `scr_spin` | **Daily Spin prize wheel** (modal lives in `obj_hub`, no new object/room). Struct-based. `ph_spin_eligible(save)` (session ≥ `PH_SPIN_UNLOCK_SESSION`, not claimed today), `ph_spin_create`, `ph_spin_open` (pre-rolls a uniform prize + `rot_final` so the slice lands under the top pointer), `ph_spin_is_open`, `ph_spin_tick`, `ph_spin_input` → `"none"/"spun"/"claimed"`, `ph_spin__grant`. Draw: light dim + cream bottom-sheet (`PH_COL_YELLOW_SOFT`, slides up) over lower screen, hub visible above; 6-wedge wheel (`ph_spin__wedge` trianglefan), prize numbers angled radially (`draw_text_transformed`) + coin, solid-red `#f43327` pointer, centre SPIN hub; CLAIM / DOUBLE result via image buttons. `ph_spin__draw_result(_s,_cx,_slide)`. Prizes `ph_spin_prizes()` = 10/25/50/75/100/150. Phases idle→spinning→result→video. |
| `scr_tutorial` | **Soft finger-pointer hints** (no overlay/text/dim/input-capture). Finger primitive: `ph_finger_create/point_at/hide/is_visible/tick/draw` (`global.spr_finger` ← `finger.png`). Hub first-run onboarding: slides tile list up, then points at card 0's PLAY (~1 s); flag `save.tutorial_done`. **Per-puzzle "how to play" coach** (same sprite): `ph_coach_create(accent)`, `ph_coach_set_steps`, `ph_coach_tap`/`_slide`/`_pt`, `ph_coach_active/next/stop/tick/draw`. TAP = 3-phase loop (lift→press w/ contact ripple→react); SLIDE = press→eased per-segment travel w/ trail→lift→loop. Knobs `#macro PH_COACH_*`. Flag `save.tips_seen[$KEY]`, marked only on the player's first correct action; quitting mid-tip replays. Pure `.gml`, no rebuild. **Daily-progress FTUE coach** (`ph_dailytut_*`): one-time 2-step overlay shown the first time the player RETURNS to the hub from a puzzle. `ph_dailytut_create/begin/is_open/step/tick/input` (state only) + `ph_dailytut_arrow`(purple primitive up-arrow) + `ph_dailytut_bob_px`(3-phase hop curve). Step 0 = arrow at TROPHY + "Complete 10 Puzzles…"; step 1 = arrow at GIFT + "Solve 4 Puzzles…". Dim everything but the teal band; tap anywhere (gated ~1 s via `PH_DAILYTUT_TAP_DELAY`) advances/closes. Knobs `#macro PH_DAILYTUT_*` (scr_constants). Flag `save.daily_progress_tut_done`; obj_hub owns when/draw; **on finish it fires `ph_notify_request_after_first_solve` (notif prompt moved here from first-solve)**. `ph_room_is_puzzle(room)` = is a puzzle room (or rm_win). No rebuild. |
| `scr_notify` | **Local daily-reminder notification (iOS).** `ph_notify_supported()` (=os_ios), `ph_notify_boot()` (re-arm on launch), `ph_notify_request_after_first_solve()` (prompt + schedule once, sets `save.notif_requested`; **now called when the daily-progress FTUE coach finishes — i.e. after the player's first return-from-puzzle tutorial — NOT at first solve**), `ph_notify_cancel()`, `ph_notify_sync_spin()`/`ph_notify_spin_delay_secs()`. Reminder is **synced to the Daily Spin cooldown** ("Your daily spin is ready!"); native `notif_setup_daily_puzzle(seconds)`: `>0`=one-shot, `==0`=repeating daily 9:30, `<0`=none. Thin GML over native `LocalNotifications` extension. Armed on boot, after first solve, and on every spin claim. |
| `scr_audio` | **Central SFX manager.** `ph_sfx(snd,gain=1,pitch=1,min_gap=0)` plays at `PH_SFX_MASTER_VOL*gain`; debounces via `global.ph_sfx_last`; no-ops when muted / resource missing. Mute persists in `save.sfx_on`. `ph_sfx_enabled/set_enabled/toggle`. Macros: `PH_SFX_MASTER_VOL` (0.85), `PH_SFX_TAP_GAP` (40). **11 GMSound OGGs** (preload, synthesised via `tools/gen_sfx.py`): `snd_tap`/`snd_button` (UI; `snd_key` reserved/unwired), `snd_transition`, `snd_correct`/`snd_error`, `snd_coin`/`snd_star`, `snd_win`/`snd_levelup`/`snd_hint`. Hooks across tap (global, `obj_persistent` Step), transition, coin, win, level-up, hint, per-move correct/error, bonus-word coin. **Sudoku/Shikaku get NO per-move correct chime** (would reveal the solution). Mute UI = speaker chip on the Events screen header. |

### Key economy / save facts
- Level is **derived, never stored**: `level = floor(xp / 500) + 1`. `ph_grant_xp` computes `levels_gained × 100` coins, but `*_check_win` call it with `_auto_coins=false` so level-up coins are **deferred** to the Level-Up screen (`obj_win`/`rm_win`); on level gain they set `global.pending_levelup = {level, base_reward:100}`. Only 1 level-up per puzzle (100 XP grant vs 500/level).
- `ph_solved_count_on` counts a day's solves but **skips bookkeeping keys** prefixed `ANYGRAM_` and `WW_W`. Adding a new multi-flag puzzle? Add the same skip rule.
- Completion keys: Anygram = `ANYGRAM_DONE` (or legacy `ANYGRAM_M1 && ANYGRAM_M2`, via `ph_anygram_is_done`); Sudoku = `SUDOKU`; Word Wave = `WORDWAVE`; others via each puzzle's `*_is_done`/`mark_done`.
- Streak recomputed on every save load + after completions via `ph_update_streak`.
- **`save.week`** (Missions) backfilled in `ph_save_load`/`ph_save_reset` via `ph_week_init`, then `ph_week_check_finish` runs on load. Holds `{index,status("active"|"finished"),start_dt,missions[],stats,bonus_claimed,recent}`. Counters advance only through `ph_week_record_solve` inside `ph_win_grant` (never in review mode).
- **Puzzle timer = active play time, not wall-clock.** Each controller sets `timer_key = "<puzzle>_"+date` and `timer_base_secs = ph_timer_get(...)` in Create; displays/records `ph_timer_now(...)`; Step calls `ph_timer_step(...)`; back-button commits + saves. Stored in `save.timers`. Wordle gates on `status=="in_progress"`. See GDD §5.2.

---

## 4. Objects (screens & controllers) — `objects/`

Each object owns a screen: `Create_0` (setup/state), `Step_0` (input/update), `Draw_64` (GUI-space render).

| Object | Role |
|---|---|
| `obj_boot` | Spawns `obj_persistent`, jumps to `rm_hub`. |
| `obj_persistent` | **Session manager.** Sets `PH_H`, iOS safe-area insets, loads fonts + save + all sprites (`sprite_add`), configures surface/MSAA/filtering. Lives whole session. **Screen-transition owner:** Create inits `global.trans_*` + sets `depth=-100000`; Step advances the iris (cover → `room_goto(global.trans_room)` under full cover → reveal); Draw GUI renders the accent iris + white spark. Kicked via `ph_trans_begin`. Step maintains `global.ph_idle_anchor` (reset on any tap) for the HINT-pill bounce; also fires global `snd_tap` + `ph_haptic_tap`. Increments session count once per launch. **Room history:** Create inits `global.room_curr`/`room_prev`; Step updates them on room change (one frame after) so a new room's `Create_0` reads `room_curr` as the room it was opened FROM (used by the daily-progress FTUE trigger). |
| `obj_hub` | Home screen: 7-day strip, collapsible month calendar (month selector `cal_view_year`/`cal_view_month` + `hub_month_step`/`hub_view_to_selected`/`hub_build_month_grid`), scrollable game cards, daily-progress tube. Reads solved state via `ph_*_is_done`. **Cards match the Penpot "Puzzle Tile":** `card_h=317` keeps the source 1430×450 aspect at 1008px render width; tile metrics authored in source-tile space (1430×450) in Draw §6, mapped via `_card_left + sx*_card_sx`. Icon 250² at left+50; title (`fnt_disp_lg`,60) + description (`fnt_body_md`,36) left-aligned, black@0.6, right-clipped to `_pill_left-16`. **Right pill** = uniform white capsule (`ph_draw_pill`), dark text; stopwatch + trophy drawn `c_white` (full-colour 3D, no tint). solved/MISSED = stopwatch + mm:ss; `time_trophy` = trophy + time; `locked` = "COMING SOON"; else "PLAY". Finish-time pill centralized (Draw §badge): solved puzzle shows mm:ss from `save["<key>_time_<date>"]`, `<key>` from card's `rm_<key>` (new puzzles get it free); Wordle MISSED in red. **Coin-flow reward anim** (`hub_start_coinflow(amount)`, driven by `global.coin_flow_amount`): streams coins into the top-right coin pill + floats "+N"; used by Level-Up entry + Daily Spin claim. **Daily Spin:** Create builds `spin = ph_spin_create()` + opens if eligible; Step ticks it, captures all input while open (claim → coin-flow), suspends hub; Draw last. **Soft onboarding** (gated `!save.tutorial_done`): non-blocking auto-scroll sweep then soft finger at card 0's PLAY; sets `tutorial_done` on first launch. **Daily-progress FTUE coach** (`dailytut` = `ph_dailytut_create`): Create starts it if `!save.daily_progress_tut_done && !intro_active && ph_room_is_puzzle(global.room_curr) && ph_has_any_solve(save)` (first return from a puzzle AFTER the first solve; takes priority over the Daily Spin that entry); Step ticks it + captures ALL input while open (tap advances/closes, then persists the flag + requests notif permission); Draw §9 composes the dim bands + teal extension + bobbing arrow + caption + Tap-anywhere pill over the progress band. **Tile click + transition:** pressed card sinks `CARD_PRESS_DY` (`ph_ease_out`), spring-pops on release (`ph_ease_out_back`); opening calls `ph_trans_begin(tap_x,tap_y,card.text_col,room)` (iris) + input lock. `LAYOUT` struct in Create holds all hub metrics. |
| `obj_anygram` | Anygram: letter wheel, crossword grid, fly-tile anim, hint, bonus modal, win overlay, confetti. Largest controller. |
| `obj_sudoku` | 9×9 board, number pad, conflict highlighting, hint, win overlay. |
| `obj_shikaku` | 9×9 grid, drag-corner rectangles, tap-to-delete, shape-glyph hint, win overlay. Blue accent; HUD = coin + hint. |
| `obj_wordwave` | 8×8 word-search, swipe selection, per-word colours, hint, win overlay. "Words to find" = centred 2-col pill-tile block (`ph_draw_word_tile`, auto-fit `WL_TILE_W`) above the grid; toolbar = `ph_draw_bonus_pill` · timer · HINT. |
| `obj_wordle` | 6×6 board, custom on-screen keyboard (slot-based active row; tapped key darkens), staggered reveal, shared hint. **Self-contained loss flow:** `lose_phase` ∈ none/aversion/confirm/screen (`wd_lose_step/input/draw`); buy/free +3 moves (board grows to 9 rows), UNLUCKY screen grants 25/50 XP via `wd_lose_claim`. Green accent. |
| `obj_huesort` | Hue Sort: 4×4 gradient board, locked corner anchors (pin dot), drag-and-drop swap, shared hint (`hs_apply_hint`). Violet accent; no loss. |
| `obj_wordbend` | Word Bend: 5×5 board fully tiled by hidden words. Tap first letter + drag adjacent cells (orthogonal bends, backtrack trims); release matches traced seq fwd/rev → locks green. Shared hint (`wb_apply_hint`). Tangerine accent; bonus-word pill; no loss. |
| `obj_arrows` | Arrows: 17×14 white dot-grid; arrows = slim rounded-bend ribbons + triangle head, per-arrow colour via `ph_colorlink_color`. Tap → if `ph_arrows_sweep_clear`: 3-phase juiced slide-out (recoil → accelerate `ph_ease_in_cubic` + motion-smear → exit flash) then `alive=false`/save/win-check; else blocked → snake-glide head-first to blocker + back, both arrows flash red, +5 s penalty + floating "+5 s". Shared hint recolours longest safe arrow **green permanently** (`ar_hinted[]`, persisted). Silver accent; no loss. |
| `obj_colorlink` | Color Link: 9×7 board, `route[]` per flow + `cell_owner[]`, drag to draw/extend/retract flows (`cl_try_step`; override trims crossed flows; hint-locked flows immovable), shared hint (`cl_apply_hint` lays + locks longest solution flow). Lime accent; no loss. |
| `obj_ladder` | Ladder: single word row of N tiles. Tap tile → `sel` (amber), type a key → replace, compare full word vs `puzzle.words[step]`; match → green flash → `ld_advance`; mismatch → red flash + revert + **+5 s** penalty. Letters-only keyboard (`ld_build_keys`, press feedback). Clue box + N/10 above keyboard. **Two-level hint** (`hint_lvl`): tile bg, then correct keyboard letter; persisted per rung. Win via shared `ph_win_*` (100 XP granted by win-screen CLAIM, `claim_key="ladder_<date>"`). Amber accent; no loss. |
| `obj_colordoku` | Colordoku (Queens): 6×6 region-coloured board (CELL=160). Single tap cycles empty→X→queen→empty (`(state+1) mod 3`); teal gem via `cd_draw_gem`; conflicting queens (`ph_colordoku_conflicts`) flash red-orange (no block). Shared hint fills first 3 forced X's locked (`cd_apply_hint`/`cd_can_hint`). Bright-teal accent; no loss. |
| `obj_shop` | Shop tab — minimal/stub. |
| `obj_profile` | **Event Hub screen** (internal name stays `obj_profile`/`rm_profile`; nav label "Events"). Top bar (level ★ pill · EVENT HUB title · coin pill) on cream band; teal `#adfff1` body. Header = "Complete missions to win extra rewards" + white reset-timer pill (`ph_week_time_left_str`). Drag-scrollable mission list, sorted claimable→in-progress→claimed (`prof_sorted_indices`); card bg = `card_mission` sprite (`CARD_H≈279`). 3 states: In Progress (purple fill bar + "x/N" + reward ★), Completed/claimable (blue CLAIM via `ph_draw_reward_btn` + description + reward ★), Claimed (tinted card, `Checkmark` sprite). Geometry consts + `prof_metrics`/`prof_card_top`/`prof_claim_rect`/`prof_icon`/`prof_sorted_indices` in Create. CLAIM → `ph_mission_claim` + a 2-phase celebration (`claim_phase`): **STARFLY** (reward ★ duplicates into `STARFLY_N` copies, gather/mill, peel off one-by-one and fly up accelerating to the level ★ w/ flash; level ★ expands/holds/absorbs; ★→checkmark pop) then **REORDER** (claimed tile bounces, then all tiles slide to new sorted slots via `ph_ease_in_out`). Finished-week branch: "Week Complete" title, list ordered claimable(CLAIM)→CLAIM ALL→claimed(✓)→incomplete; CLAIM/CLAIM ALL fire the star burst (multi-source `fly_idxs`); `ph_week_collect` rolls over to a fresh week. Hidden triple-tap level-pill = save-reset gesture. Beat-length consts in Create (`STARFLY_N`, `SF_*`, `CHECK_POP`, `LEVELSTAR_*`, `REORDER_*`, `BOUNCE_PX`). |
| `obj_win` | **Level-Up reward screen** (in `rm_win`). Reads `global.pending_levelup`; violet screen (Congrats + level # + LEVEL UP! + 3D star + confetti) + "Claim your reward!" + reward amount ("100 🪙") + CLAIM / DOUBLE buttons. `lu_claim`: if `global.post_levelup` set, continue to that `{room,date}` (no coin anim); else stash `global.coin_flow_amount` + `room_goto(rm_hub)` for the coin-flow anim. DOUBLE → `ph_video_overlay` 5 s → 200 coins. NB: its video flag is `vid_open` (`video_open` is reserved). |

Pattern: each puzzle controller embeds its own **win overlay** + confetti (not `obj_win`); review mode re-enters the puzzle room with a `global.*_review_mode` flag and jumps to the win overlay. The **Level-Up screen** is the only screen in its own room; each win-screen BACK does `room_goto(ph_levelup_pending() ? rm_win : rm_hub)`.

**Shared hint flow (all puzzles):** Create builds `hint = ph_hint_create(<x>_apply_hint,<accent>)` + defines `<x>_apply_hint`/`<x>_can_hint`. Step calls `ph_hint_tick(hint)` + `ph_hint_input(hint)` before normal input (exit if result ≠ `"none"`); the HINT-pill handler gates on `<x>_can_hint()` then `ph_hint_open(hint)`. Draw calls the feedback/modal/video helpers. See `scr_hint` + GDD §2.5–2.6.

---

## 5. Rooms — `rooms/`

`rm_boot` (first, per RoomOrderNodes) → `rm_hub`. Then one room per screen: `rm_anygram`, `rm_sudoku`, `rm_wordwave`, `rm_shikaku`, `rm_wordle`, `rm_huesort`, `rm_colorlink`, `rm_wordbend`, `rm_arrows`, `rm_ladder`, `rm_colordoku`, `rm_shop`, `rm_profile`, and `rm_win` (= the Level-Up reward screen). Each hosts its matching object.

---

## 6. Global state surface

Set up in `obj_persistent/Create_0`.

**Data / session**
- `global.save` — entire save struct; all progression lives here.
- `global.selected_date_key` — day being viewed/played.
- `global.input_locked_until` — frame-time input lock during animations.
- `global.pending_levelup` — `{level,base_reward}` when a puzzle queued a level-up; else `undefined`. Gate via `ph_levelup_pending()`.
- `global.coin_flow_amount` — coins from the last Level-Up claim awaiting the hub coin-flow; `0` = nothing.
- `global.post_levelup` — `{kind:"room",room,date}` when a win-screen NEXT GAME / YESTERDAY fired while a level-up was pending; else `undefined`.
- `global.PH_H_dyn` — runtime canvas height (`PH_H` reads this).
- `global.safe_top_gui` / `global.safe_bottom_gui` — iOS notch / home-indicator insets.
- `global.room_curr` / `global.room_prev` — room history (obj_persistent). At a room's `Create_0`, `room_curr` is still the room we came FROM (updated by persistent Step one frame later). Drives the daily-progress FTUE "came from a puzzle" trigger.

**Puzzle caches** (lazy-loaded, may be `undefined` sentinel if file missing): `ph_anygram_cache`, `ph_sudoku_cache`, `ph_wordwave_cache`, `ph_shikaku_cache`, `ph_wordle_cache`, `ph_wordle_allowed` (`{WORD:true}` map), `ph_huesort_cache`, `ph_colorlink_cache`, `ph_wordbend_cache`, `ph_arrows_cache`, `ph_ladder_cache`, `ph_colordoku_cache`.

**Review-mode flags** (jump straight to win overlay; set on hub tap): `anygram_review_mode`, `sudoku_…`, `wordwave_…`, `shikaku_…`, `wordle_…`, `huesort_…`, `colorlink_…`, `wordbend_…`, `arrows_…`, `ladder_…`, `colordoku_…`. (Wordle: a *missed* day isn't "done", so its review flag stays false — `obj_wordle` Create reopens the lose screen from persisted `status`/`WORDLE_MISSED`.)

**Transient anim**
- `global.fly_tiles` — shared fly-tile particle list (Anygram).
- `global.ph_dot_surface` — formerly the cached tiled-background surface; now unused (background is a flat fill). `global.spr_bg_pattern` is still loaded in `obj_persistent` but no longer drawn.
- `global.ph_sfx_last` — per-sound last-play timestamps (`ph_sfx` debounce).

**Assets** — `global.fnt_*` (fonts), `global.spr_*` (all sprites). Loaded once in persistent. Includes `global.spr_tv` (`retro tv icon.png`) for FREE / DOUBLE video buttons, `global.spr_events`, `global.spr_card_mission`, `global.spr_checkmark`, `global.spr_finger`.

---

## 7. Data file formats (authoring)

- **Anygram** (`puzzles_anygram.json`): array. `{letters:[5], words:[{text,row,col,dir("H"|"V")}], bonus|bonus_pool:[...], date?, grid_size?}`. Legacy 2-word shape accepted.
- **Sudoku** (`puzzles_sudoku.json`): `{date?,difficulty?,givens:"81 chars (0=blank)",solution:"81 chars"}`, row-major.
- **Word Wave** (`puzzles_wordwave.json`): `{date?,grid:[8×"8 chars"],words:[{text,row,col,dir}],bonus_pool:[...]}`. `dir` ∈ H/H_REV/V/V_REV/DR/DL/UR/UL; each word traces a straight line.
- **Shikaku** (`puzzles_shikaku.json`): `{date?,size,rects:[{r,c,w,h,cr,cc}]}` (rects = clue source + unique solution).
- **Wordle** (`puzzles_wordle.json`): `{date?,answer:"<6 uppercase>"}`, fallback `STREAM`. Plus `wordle_allowed.json`: flat array of uppercase 6-letter validation strings. Both registered as IncludedFiles.
- **Color Link** (`puzzles_colorlink.json`): `{date?,rows,cols,flows:[{color,a:[r,c],b:[r,c],path:[[r,c]...]}]}` (9×7; legacy `size` ok). `a`/`b` = endpoints; `path` = full solution route (hint + recap). Generated via Hamiltonian-path-cut, 6–7 flows, 4–13 cells each (`tools/gen_colorlink.py`). Fallback 9×7.
- **Hue Sort** (`puzzles_huesort.json`): `{date?,size?,corners:{tl,tr,bl,br}}` (each `"RRGGBB"`). Corners define the board via bilinear interp; interior scramble date-seeded. Generated by `tools/gen_huesort.py` (60 boards; corners ~90° apart on the hue wheel, rejecting any board whose min adjacent-tile CIELAB dE76 < 18). Difficulty = smallest adjacent colour gap, not tile count. Fallback hardcoded.
- **Word Bend** (`puzzles_wordbend.json`): `{date?,size,words:[{text,path:[[r,c]...]}]}`. Word paths must tile the whole `size×size` board exactly once. Pool 60 boards (size 5, `tools/gen_wordbend.py`, `N=5`). **Bonus words:** tracing a real ≥4-letter non-hidden word pays +10 coins (`PH_BONUS_WORD_COINS`) via `wordbend_dict.json` (~24.7k common words, loaded into `global.ph_wordbend_dict`); persisted in `save.wordbend_state[date].bonus`.
- **Arrows** (`puzzles_arrows.json`): `{date?,rows,cols,arrows:[{head:"U"|"D"|"L"|"R",cells:[[r,c]...]}]}` (legacy `size` ok). `cells[0]` = arrowhead/tip; `cells[1]` directly behind; 4-connected. Generated offline by `tools/gen_arrows.py` (reverse construction → solver-verified + directed gap-filler). 17×14, ~83% fill, ~32–45 arrows/board. Tip-lane escape rule = only the straight lane in front of the tip must be clear. Fallback 17×14.
- **Ladder** (`puzzles_ladder.json`): `{date?,length,start,steps:[{word,clue}]×10}`. `start` = seed (shown, not counted); consecutive words differ by exactly one position (validated at authoring); `clue` = rung description. Fallback `COLD→…→CORK`.
- **Colordoku** (`puzzles_colordoku.json`): `{date?,size,regions:[N*N ints 0..N-1 row-major],solution:[N*N ints 0/1 row-major]}` (6×6). `regions[i]` = region id; `solution[i]`=1 marks the unique solution queen. Generated by `tools/gen_colordoku.py` (no-touch queen permutation → region growth → unique-solution solver). Pool 60 boards. Rules: one queen per row/col/region, no two touching incl. diagonally. Fallback unique 6×6.

All: missing file → hardcoded fallback. Same two-pass date selection (exact `date` match wins, else `seed mod length`).

---

## 8. Conventions & gotchas

- **No struct literals with non-constant fields.** YYC generates anonymous C++ constructors for non-constant expressions in struct literals → **linker errors**. Build such structs with explicit property assignment (see `obj_hub/Create_0` `LAYOUT`).
- **Adding resources / events corrupts on save & triggers a YYC link failure.** GM rewrites `Puzzle Hub.yyp` (and `.yy` files) on save. Register new resources / new events only with **GameMaker fully quit**, then reopen + **YYC Clean rebuild** (a clean rebuild — not code changes — fixes the link failure). Adding events to an existing object also means editing its `.yy` `eventList` (eventType 0=Create, 3=Step, 8+eventNum 64=Draw GUI) + the matching `.gml`.
- **All gameplay numbers are `#macro`s in `scr_constants`.** Change them there + reflect in `GDD.md`. Never hardcode economy values.
- **Watch reserved built-in names** (e.g. `video_open`). Prefix puzzle-specific state instead (Level-Up uses `vid_open`).
- **`PH_SUDOKU_TEST_PREFILL`** (`scr_constants`) starts Sudoku ~90% solved — **must be `false` before shipping.**
- **Drawing is GUI-space** (`Draw_64`), sized to `PH_W × PH_H_dyn` via `display_set_gui_size`. Use `ph_scissor_gui` (GUI→window px) for clipping, not raw `gpu_set_scissor`.
- **Sprites** are mostly white-on-transparent, **tinted at draw time** via `ph_draw_icon`; full-colour icons drawn with `c_white`.
- **Safe areas (iOS).** Insets computed once in `obj_persistent` into `global.safe_top_gui`/`safe_bottom_gui` (GUI units) via the **iOS Safe Area native extension** (`iOS_get_safe_area()` → JSON → px → GUI), else estimate from aspect (`PH_H*0.075` top / `PH_H*0.042` bottom). **Extension must stay imported** or the project won't compile (`iOS_get_safe_area()` is os_ios-guarded). `iOSSource/iOSSafeArea.h` needs `#import <UIKit/UIKit.h>`. Use helpers `ph_safe_top()`/`ph_safe_bottom()` (add `PH_PAD_TOP`/`PH_PAD_BOTTOM` comfort padding). Puzzle HUDs use `95 + safe_top_gui` (top) / `PH_H - 110 - safe_bottom_gui` (bottom).
- **Core-game content is bottom-anchored.** Each puzzle's `grid_y` shifts DOWN so the whole play cluster sits just above the bottom HUD: `grid_y += max(0,(PH_H - safe_bottom_gui - 155 - PH_PLAY_BOTTOM_GAP) - (grid_y + cluster_h))`. Anygram is the exception (anchors above its proportional wheel). Tune via `PH_PLAY_BOTTOM_GAP`.
- **Save path at runtime:** `working_directory + "puzzlehub_save.json"`. IDE-run on macOS → `~/Library/Application Support/com.yoyogames.macyoyorunner/puzzlehub_save.json` (auto-memory `project_puzzle_hub_save_path`).
- **Save is forward-compatible:** `ph_save_load` backfills missing fields. Add new fields with a default backfill there.
- **Desktop vs mobile canvas:** mobile derives height from real screen ratio; desktop forces 1920 + letterboxes.
- **Local notifications (iOS).** Native `LocalNotifications` extension (`extensions/LocalNotifications/`, `iOSSource/*.mm`, `UNUserNotificationCenter`); GML = `scr_notify`. Synced to the Daily Spin cooldown. ⚠️ Changing the native function arg count needs the extension reimported + quit + YYC Clean rebuild. **UserNotifications.framework** must be linked (declared in `iosSystemFrameworkEntries` in `LocalNotifications.yy` — autolinking failed). Copy = `PH_NOTIF_BODY` in `LocalNotifications.mm`.
- **Haptics (iOS).** Native `Haptics` extension (`extensions/Haptics/`, `iOSSource/Haptics.mm`, UIKit generators); GML = `scr_haptics`, fired alongside `ph_sfx`. UIKit standard-linked → no `iosSystemFrameworkEntries`. Only fires on a real iPhone. ⚠️ NEW RESOURCES → quit + register + YYC Clean rebuild. Android later = parallel module behind `os_android`.
- **Android run/build** (first device run on a Redmi/Poco `2201116TG`, MIUI). Two issues, both outside GML (YYC compile + APK assemble still succeed): (1) **Corrupted adaptive-icon paths in `options/android/options_android.yy`** → Igor `DoIcons` `DirectoryNotFoundException`; fix = repoint each `option_android_icon_adaptive*`/`adaptivebg*` field to `options/android/icons/<density>.png` (edit `.yy` only with GM fully quit). (2) **`INSTALL_FAILED_USER_RESTRICTED`** = MIUI restriction; on device enable **Install via USB** + **USB debugging (Security settings)**.

---

## 9. Where to make common changes

| Task | Go to |
|---|---|
| Tune XP/coins/hint cost | `scr_constants` (macros) + `GDD.md` |
| New puzzle solved-tracking | `scr_save` (`ph_mark_*` / `ph_*_is_done`, skip rule in `ph_solved_count_on`) |
| Per-puzzle first-play finger tip | `scr_tutorial` (coach engine) + controller Create/Step/Draw; flag `save.tips_seen[$KEY]` |
| Add/author puzzles | `datafiles/puzzles_*.json` |
| Hub layout / calendar / cards | `obj_hub` (`LAYOUT` struct in Create) |
| Shared UI widgets (chips, nav, text) | `scr_draw` |
| Fonts / sprites | `scr_fonts` / `obj_persistent/Create_0` |
| Feedback sounds | `scr_audio` (`ph_sfx`); volumes = `PH_SFX_*`; regenerate via `tools/gen_sfx.py`; new `snd_*` need quit→register→clean-rebuild |
| Win screen / confetti | inside each puzzle controller's Draw/Step (not `obj_win`) |
| Hint modal / rewarded-video flow | `scr_hint` (shared); per-puzzle `<x>_apply_hint`/`<x>_can_hint` in each Create |
| Level-Up reward screen | `obj_win` + `ph_grant_xp(..., false)` in `*_check_win` |
| New screen | new `obj_*` + `rm_*`, register in `.yyp` (quit + clean rebuild), wire nav in Step |
| Add a new puzzle end-to-end | use the `puzzle-hub-add-puzzle` skill |
| Any motion / animation / juice | use the `puzzle-hub-animation` skill |

---

## 10. Repo / versioning

Private repo `github.com/bhogha/Puzzle-Hub`. Current dev = **v0.3**; `v0.2` tagged milestone, `v0.1` baseline. (auto-memory `project_puzzle_hub_github`, `project_puzzle_hub_version`).

**iOS build/version:** `options/ios/options_ios.yy` → `option_ios_version` = marketing version, `option_ios_build_number` = build number. As of 2026-06-30 these are **0.3.1.0 / build 1**, uploaded to TestFlight (App Store Connect build `0.3.1 (1)`, bundle `piktus.puzzlehub`, team `S65F38B8UP`). **Before any ship/TestFlight build, confirm the three test flags in `scr_constants` are in ship state:** `PH_SUDOKU_TEST_PREFILL false`, `PH_SPIN_TEST_COOLDOWN_MINS 0`, `PH_DEBUG_SAFEAREA false`. **Build gotcha:** a GameMaker device *Run* does NOT regenerate the archivable Xcode project — use **Create Executable / Package** for iOS, which rewrites `GM_IOS/Puzzle_Hub/Puzzle_Hub/Puzzle_Hub.xcodeproj`; then archive in Xcode and Distribute → App Store Connect.
