// ── Real setup ────────────────────────────────────────────────────────────────
puzzle = ph_anygram_for_date(global.selected_date_key);

// Wheel geometry (defined first so the grid clamp can read WHEEL_CY/WHEEL_R).
// WHEEL_CY is scaled proportionally to PH_H_dyn so the wheel stays in the
// lower third of the play area on all device aspect ratios.
WHEEL_CX     = PH_W / 2;
WHEEL_CY     = round(1440.0 * global.PH_H_dyn / 1920.0);
WHEEL_R      = 270;
LETTER_R     = 195;
LETTER_HIT_R = 70;

// Grid geometry — trim to the actual occupied extent so puzzles authored
// with non-zero starting row/col (e.g. row 4) don't push the visible cells
// down into the wheel area. Then top-anchor in the board strip (y=200..1180).
GAP  = 14;
var _min_r =  1000000; var _max_r = -1000000;
var _min_c =  1000000; var _max_c = -1000000;
for (var _i = 0; _i < array_length(puzzle.cells); _i++) {
    _min_r = min(_min_r, puzzle.cells[_i].r);
    _max_r = max(_max_r, puzzle.cells[_i].r);
    _min_c = min(_min_c, puzzle.cells[_i].c);
    _max_c = max(_max_c, puzzle.cells[_i].c);
}
grid_min_r = _min_r;
grid_min_c = _min_c;
var _rows  = _max_r - _min_r + 1;
var _cols  = _max_c - _min_c + 1;
CELL = (max(_cols, _rows) >= 5) ? 110 : 140;
var _grid_w = _cols * CELL + (_cols-1) * GAP;
// grid_h is exposed as an instance var so Draw_64 can centre the word-preview
// pill and the toast halfway between the grid bottom and the wheel top.
grid_h = _rows * CELL + (_rows-1) * GAP;
grid_x = floor((PH_W - _grid_w) / 2);
// Bottom-anchor the grid just above the wheel (the wheel is already bottom-
// aligned), leaving room for the word-preview pill between them, instead of
// top-anchoring it under the HUD. Clamp so a tall grid never rides up under the
// HUD strip.
var _wheel_top_y = WHEEL_CY - WHEEL_R;
grid_y = max(170 + global.safe_top_gui, _wheel_top_y - 130 - grid_h);

// Per-cell animation
tile_scales = array_create(array_length(puzzle.cells), 1.0);
tile_flash  = array_create(array_length(puzzle.cells), 0.0);

var _nL = array_length(puzzle.letters);
wheel_positions = [];
// Distribute evenly around the disc, top-centered.
for (var _i = 0; _i < _nL; _i++) {
    var _a = degtorad(-90 + (_i * 360 / _nL));
    array_push(wheel_positions, {
        x: WHEEL_CX + cos(_a)*LETTER_R,
        y: WHEEL_CY + sin(_a)*LETTER_R,
    });
}

// Input / trail
trail             = [];
trail_word        = "";   // cached preview, refreshed when trail changes
is_dragging_wheel = false;
drag_letter_idx   = -1;

// Feedback toast
toast_text  = "";
toast_col   = PH_COL_TEAL;
toast_timer = 0;
TOAST_DUR   = 90;

// Shake feedback (invalid swipe) — affects wheel + trail draw, NOT board.
shake_t        = 0;       // frames remaining
shake_offset_x = 0;
SHAKE_DUR      = 16;

// Bonus modal + BONUS chest+pill button (bottom-left). Pill bounds are
// re-written every frame by Draw so layout & input agree; defaults here avoid
// an undefined read on the first Step.
bonus_modal_open = false;
BONUS_ICON_X     = 77;         // chest centre inside the pill (fly-tile target)
BONUS_ICON_Y     = PH_H - 110 - global.safe_bottom_gui;
BONUS_ICON_R     = 60;
BONUS_PILL_L     = 50;
BONUS_PILL_R     = 340;
BONUS_PILL_T     = PH_H - 143 - global.safe_bottom_gui;
BONUS_PILL_B     = PH_H - 77  - global.safe_bottom_gui;
// Coin balance target (re-written every frame by Draw to point at the HUD pill
// in the top-right, so the coin-fly arc lands on the moving pulse target).
COIN_BAL_X       = PH_W - 160;
COIN_BAL_Y       = 95 + global.safe_top_gui;
coin_pulse_t     = 1.0;        // 1.0 == idle; reset to 0 on coin gain
coin_overshoot_t = 1.0;        // 1.0 == idle; reset to 0 on coin arrival for the bounce

// Hint pill tap target — re-written every frame by Draw so layout & input agree.
HINT_PILL_L = PH_W - 260;
HINT_PILL_R = PH_W - 50;
HINT_PILL_T = PH_H - 143 - global.safe_bottom_gui;
HINT_PILL_B = PH_H - 77  - global.safe_bottom_gui;

// Hydrate per-word found state from save (resume mid-puzzle)
for (var _wi = 0; _wi < array_length(puzzle.words); _wi++) {
    puzzle.words[_wi].found = ph_anygram_is_word_found(
        global.save, global.selected_date_key, _wi);
}
// Honor legacy ANYGRAM_DONE flag (e.g. completed prior to this build): mark all
// words found so the player sees the completed state on re-entry.
if (ph_anygram_is_done(global.save, global.selected_date_key)) {
    for (var _wi = 0; _wi < array_length(puzzle.words); _wi++) {
        puzzle.words[_wi].found = true;
    }
}

// Hydrate bonus-word discovery state from save
for (var _i = 0; _i < array_length(puzzle.bonus); _i++) {
    puzzle.bonus_found[_i] = ph_anygram_is_bonus_found(global.save, global.selected_date_key, puzzle.bonus[_i]);
}

// Pre-fill solved cells based on per-word found state
for (var _ci = 0; _ci < array_length(puzzle.cells); _ci++) {
    var _c = puzzle.cells[_ci];
    for (var _wi = 0; _wi < array_length(_c.word_indices); _wi++) {
        if (puzzle.words[_c.word_indices[_wi]].found) {
            _c.filled = true;
            break;
        }
    }
    puzzle.cells[_ci] = _c;
}

// ── Hint flow ─────────────────────────────────────────────────────────────────
// The HINT pill opens the shared hint modal (pay coins OR watch a placeholder
// rewarded video). The controller struct is created below, once the puzzle's
// reveal methods exist — see ag_apply_hint / ag_can_use_hint.

// ── Win state (defaults) ──────────────────────────────────────────────────────
// fly_tiles entries:
//   { letter, x, y, tx, ty, t, kind: "main"|"bonus"|"coin", word_idx, letter_idx }
//   Negative t = stagger delay; positive 0..1 = animation progress.
global.fly_tiles = [];

win_phase        = 0;   // 0=playing 1=complete
xp_gained        = 0;
coins_bonus      = 0;
win_anim_t       = 0;
win_btn_back_y   = 0;
win_time_str     = "0:00";
timer_key        = "anygram_" + global.selected_date_key;
timer_base_secs  = ph_timer_get(global.save, timer_key);
session_start_ms = current_time;

// ── Confetti state ────────────────────────────────────────────────────────────
// Two-phase celebration that runs for a fixed 3-second window so it doesn't
// loop forever on the win screen:
//   1) `confetti_burst_pending` triggers a one-shot radial burst from the centre
//      of the card the moment win_phase flips to 1.
//   2) `confetti_pieces` is a steady-state pool that keeps gentle pieces falling
//      from above the screen — but only while `confetti_run_frames` is under
//      `CONFETTI_DURATION_FRAMES`. Past that, no new pieces spawn; whatever's
//      already in the air keeps falling so the tail doesn't pop visually.
// A piece: { x, y, vx, vy, rot, vrot, size, col, shape (0=rect 1=tri 2=circle) }
confetti_pieces           = [];
confetti_burst_pending    = false;
confetti_run_frames       = 0;
CONFETTI_TARGET_FALL      = 70;    // steady-state pool size for the falling layer
CONFETTI_DURATION_FRAMES  = 180;   // 3.0s at 60 fps

// Enter win-review mode: hub sets global.anygram_review_mode = true before navigating;
// fall back to checking solved flags in case the flag is missing.
var _review = variable_global_exists("anygram_review_mode") && global.anygram_review_mode;
if (_review) global.anygram_review_mode = false;   // consume the flag
var _already_solved = _review || ph_anygram_all_solved(puzzle);

// ── Shared win screen (scr_economy §Shared Win Screen) ────────────────────────
// Mini-crossword recap, delegated to the shared controller.
win_draw_recap = function(_cx, _top, _bw, _bh) {
    var _max_r = grid_min_r, _max_c = grid_min_c;
    for (var _gi = 0; _gi < array_length(puzzle.cells); _gi++) {
        var _gc = puzzle.cells[_gi];
        if (_gc.r > _max_r) _max_r = _gc.r;
        if (_gc.c > _max_c) _max_c = _gc.c;
    }
    var _rows = _max_r - grid_min_r + 1, _cols = _max_c - grid_min_c + 1;
    var _gap  = 8;
    var _cell = clamp(floor(min((_bw-(_cols-1)*_gap)/_cols, (_bh-(_rows-1)*_gap)/_rows)), 28, 150);
    var _gw = _cols*_cell + (_cols-1)*_gap, _gh = _rows*_cell + (_rows-1)*_gap;
    var _ox = _cx - _gw/2, _oy = _top + (_bh - _gh)/2;
    var _tsc = _cell/256;
    for (var _ci = 0; _ci < array_length(puzzle.cells); _ci++) {
        var _mc  = puzzle.cells[_ci];
        var _mcx = _ox + (_mc.c-grid_min_c)*(_cell+_gap) + _cell/2;
        var _mcy = _oy + (_mc.r-grid_min_r)*(_cell+_gap) + _cell/2;
        var _tint;
        if      (_mc.shared && _mc.filled) _tint = PH_COL_YELLOW;
        else if (_mc.hint)                 _tint = make_color_rgb(255,180,220);
        else if (_mc.filled)               _tint = PH_COL_PINK;
        else                               _tint = make_color_rgb(234,216,200);
        draw_sprite_ext(global.spr_tile, 0, _mcx, _mcy, _tsc, _tsc, 0, _tint, 1);
        if (_mc.filled || _mc.hint) {
            var _lc  = (_mc.shared && _mc.filled) ? PH_COL_DARK : (_mc.hint ? PH_COL_DARK : PH_COL_WHITE);
            var _fnt = (_cell >= 90) ? global.fnt_disp_lg : ((_cell >= 55) ? global.fnt_disp_md : global.fnt_body_md);
            ph_draw_text(_mcx, _mcy, _mc.letter, _fnt, _lc, fa_center, fa_middle);
        }
    }
};
win = ph_win_create({
    puzzle_name: "ANYGRAM",
    title_col:   PH_COL_PINK,
    bg_col:      PH_COL_TEAL,
    claim_key:   "anygram_" + global.selected_date_key,
    already:     _already_solved,
    share_url:   PH_SHARE_URL,
    time_str:    win_time_str,
    draw_recap:  win_draw_recap,
});

if (_already_solved) {
    var _time_key = "anygram_time_" + global.selected_date_key;
    win_time_str  = variable_struct_exists(global.save, _time_key) ? global.save[$ _time_key] : "--:--";
    win.cfg.time_str = win_time_str;
    win_phase = 1;            // jump straight to the (already-claimed) win screen
    ph_win_celebrate(win);    // celebration replays on hub re-entry
}

// ── Instance methods (defined once here, called from Step_0 each frame) ───────
ag_hit_letter = function(_px,_py) {
    for (var _i = 0; _i < array_length(wheel_positions); _i++) {
        var _wp = wheel_positions[_i];
        if (ph_point_in_circle(_px,_py, _wp.x, _wp.y, LETTER_HIT_R)) return _i;
    }
    return -1;
};

ag_trail_contains = function(_idx) {
    for (var _i = 0; _i < array_length(trail); _i++) {
        if (trail[_i] == _idx) return true;
    }
    return false;
};

/// Flash every cell that contains the given word (by index into puzzle.words).
ag_flash_word_by_index = function(_word_idx) {
    for (var _ci = 0; _ci < array_length(puzzle.cells); _ci++) {
        var _c = puzzle.cells[_ci];
        for (var _wi = 0; _wi < array_length(_c.word_indices); _wi++) {
            if (_c.word_indices[_wi] == _word_idx) {
                tile_flash[_ci] = 12;          // GDD §8: 12-frame cell reveal
                break;
            }
        }
    }
};

ag_rebuild_trail_word = function() {
    var _s = "";
    for (var _i = 0; _i < array_length(trail); _i++) {
        _s += puzzle.letters[trail[_i]];
    }
    trail_word = _s;
};

ag_play_shake = function() {
    shake_t = SHAKE_DUR;
};

/// Spawn flying letter tiles from each wheel node into a main word's grid cells.
ag_spawn_fly_main = function(_word_idx) {
    var _cells_for_word = ph_anygram_cells_for_word(puzzle, _word_idx);
    var _word_text      = puzzle.words[_word_idx].text;
    for (var _k = 0; _k < array_length(_cells_for_word); _k++) {
        var _cell = _cells_for_word[_k];
        if (is_undefined(_cell)) continue;
        var _ch  = string_char_at(_word_text, _k + 1);
        var _src = _ag_find_wheel_pos_for_letter(_ch);
        var _tx  = grid_x + (_cell.c - grid_min_c)*(CELL+GAP) + CELL/2;
        var _ty  = grid_y + (_cell.r - grid_min_r)*(CELL+GAP) + CELL/2;
        array_push(global.fly_tiles, {
            letter:     _ch,
            x:          _src.x,
            y:          _src.y,
            tx:         _tx,
            ty:         _ty,
            t:          0 - _k * 0.17,    // 60ms stagger per letter (GDD §8)
            kind:       "main",
            word_idx:   _word_idx,
            letter_idx: _k,
            is_last:    (_k == array_length(_cells_for_word) - 1),
            cell_idx:   _ag_find_cell_idx(_cell.r, _cell.c),
        });
    }
};

/// Spawn flying letter tiles from each wheel node into the bonus icon.
ag_spawn_fly_bonus = function(_word_text) {
    _word_text = string_upper(_word_text);
    for (var _k = 0; _k < string_length(_word_text); _k++) {
        var _ch  = string_char_at(_word_text, _k + 1);
        var _src = _ag_find_wheel_pos_for_letter(_ch);
        array_push(global.fly_tiles, {
            letter:     _ch,
            x:          _src.x,
            y:          _src.y,
            tx:         BONUS_ICON_X,
            ty:         BONUS_ICON_Y,
            t:          0 - _k * 0.17,   // 60ms stagger per letter (GDD §8)
            kind:       "bonus",
            word_idx:   -1,
            letter_idx: _k,
            is_last:    (_k == string_length(_word_text) - 1),
            cell_idx:   -1,
        });
    }
};

/// Spawn a single coin arc from the bonus icon to the coin counter.
ag_spawn_coin_drop = function() {
    array_push(global.fly_tiles, {
        letter:     "$",       // marker only — drawn as coin sprite by Draw
        x:          BONUS_ICON_X,
        y:          BONUS_ICON_Y,
        tx:         COIN_BAL_X,
        ty:         COIN_BAL_Y,
        t:          0,
        kind:       "coin",
        word_idx:   -1,
        letter_idx: 0,
        is_last:    true,
        cell_idx:   -1,
    });
};

_ag_find_wheel_pos_for_letter = function(_ch) {
    for (var _i = 0; _i < array_length(puzzle.letters); _i++) {
        if (puzzle.letters[_i] == _ch) return wheel_positions[_i];
    }
    return { x: WHEEL_CX, y: WHEEL_CY };
};

_ag_find_cell_idx = function(_r, _c) {
    for (var _i = 0; _i < array_length(puzzle.cells); _i++) {
        if (puzzle.cells[_i].r == _r && puzzle.cells[_i].c == _c) return _i;
    }
    return -1;
};

ag_check_win = function() {
    if (!ph_anygram_all_solved(puzzle)) return;
    // Snapshot elapsed time the instant the puzzle is completed
    var _fin_s  = ph_timer_now(timer_base_secs, session_start_ms);
    var _fin_m  = _fin_s div 60;
    var _fin_ss = _fin_s mod 60;
    win_time_str = string(_fin_m) + ":" + ((_fin_ss < 10) ? "0" : "") + string(_fin_ss);
    // Persist finish time so the hub card can display it later
    global.save[$ "anygram_time_" + global.selected_date_key] = win_time_str;
    // Persist per-word flags (idempotent) and the "puzzle complete" flag.
    for (var _wi = 0; _wi < array_length(puzzle.words); _wi++) {
        ph_anygram_mark_word(global.save, global.selected_date_key, _wi);
    }
    ph_anygram_mark_done(global.save, global.selected_date_key);
    // XP is no longer granted here — the player claims it (and may double it) on
    // the win screen. ph_win_grant performs the single grant and routes any
    // resulting level-up to the Level-Up reward screen (rm_win).
    // Gift for 4th puzzle?
    var _count = ph_solved_count_on(global.save, global.selected_date_key);
    coins_bonus = 0;
    if (_count >= PH_GIFT_PUZZLE_INDEX + 1 && !ph_has_gift_been_claimed(global.save, global.selected_date_key)) {
        ph_claim_gift(global.save, global.selected_date_key);
        ph_grant_coins(global.save, PH_COINS_FOR_4TH);
        coins_bonus = PH_COINS_FOR_4TH;
    }
    ph_update_streak(global.save);
    ph_save_write(global.save);
    win_phase = 1;
    win.cfg.time_str = win_time_str;
    ph_win_celebrate(win);           // shared controller owns the celebration burst
};

// ── Hint helpers ──────────────────────────────────────────────────────────────
/// True if the puzzle is unsolved AND at least one cell can still be revealed.
ag_can_use_hint = function() {
    if (ph_anygram_all_solved(puzzle)) return false;
    for (var _i = 0; _i < array_length(puzzle.cells); _i++) {
        if (!puzzle.cells[_i].filled && !puzzle.cells[_i].hint) return true;
    }
    return false;
};

/// Reveal the next unfilled, non-hint cell. Returns true if one was revealed.
/// Does NOT touch the coin balance — callers decide whether/what to charge.
ag_apply_hint = function() {
    for (var _i = 0; _i < array_length(puzzle.cells); _i++) {
        if (!puzzle.cells[_i].filled && !puzzle.cells[_i].hint) {
            puzzle.cells[_i].hint   = true;
            puzzle.cells[_i].filled = true;
            ph_save_write(global.save);
            return true;
        }
    }
    return false;
};

// Shared hint-flow controller (modal + placeholder video). Pink accent.
hint = ph_hint_create(ag_apply_hint, PH_COL_PINK, "This hint will show you the\nfirst letter of a hidden word", "anygram_" + global.selected_date_key);
