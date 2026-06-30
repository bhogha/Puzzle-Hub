// ── Colordoku — Create ────────────────────────────────────────────────────────
// "Queens / Meowdoku" colour-region logic puzzle. Place one teal gem (queen) per
// row, per column and per colour region, with no two gems touching (incl.
// diagonally). No loss state. Tap = X (rule-out), double-tap = place/remove a gem.
puzzle  = ph_colordoku_for_date(global.selected_date_key);
N       = puzzle.size;                          // 6
NCELLS  = N * N;
regions = puzzle.regions;

// ── Grid geometry (mirrors Hue Sort: centred board, bottom-anchored) ──────────
BOARD    = 960;
CELL     = BOARD / N;                           // 160 px per cell at N=6
grid_x   = floor((PH_W - BOARD) / 2);           // 60
grid_y   = 320 + global.safe_top_gui;
TILE_GAP = 8;                                   // inset between coloured tiles

var _target_bot = PH_H - global.safe_bottom_gui - 155 - PH_PLAY_BOTTOM_GAP;
grid_y += max(0, _target_bot - (grid_y + BOARD));

ACCENT      = PH_COL_BRTEAL;        // #5af2bc — gem / hint / win accent
ACCENT_DEEP = PH_COL_BRTEAL_DEEP;   // readable deep teal for titles / text

// ── Live board: 0 empty · 1 X · 2 queen ──────────────────────────────────────
state = array_create(NCELLS, 0);

// Hint-placed LOCKED X's — these are correct rule-outs and can't be removed by
// tapping (persisted in save so the rule survives a resume).
hint_x_locked = array_create(NCELLS, false);

// ── Hint reveal/pop state ─────────────────────────────────────────────────────
// A hint places PH_COLORDOKU_HINT_XS forced X's. The shared iris
// (ph_hint_draw_reveal) targets the placed cluster; the X's stay HIDDEN under it
// (cd_hint_reveal), then pop in ONE BY ONE (cd_pop_f, staggered) once it lands.
cd_x_order     = array_create(NCELLS, -1);   // per-cell pop index (or -1)
cd_hint_cells  = [];                         // cells placed by the most recent hint
cd_hint_reveal = false;                      // hide placed X's while the iris closes in
cd_pop_f       = -1;                         // pop frame counter (<0 = idle)
CD_POP_STAG    = 5;                          // frames between each X popping in
CD_POP_DUR     = 12;                         // frames for one X's overshoot pop

// Input model: a single tap cycles a cell empty → X → queen → empty (see Step).
// No double-tap / timing — simplest and most reliable on touch.

// ── Feedback toast ────────────────────────────────────────────────────────────
toast_text  = "";
toast_col   = ACCENT_DEEP;
toast_timer = 0;
TOAST_DUR   = 90;

// ── HUD / toolbar tap targets (re-written every frame by Draw, read by Step) ──
HINT_PILL_L = PH_W - 400;
HINT_PILL_R = PH_W - 50;
HINT_PILL_T = PH_H - 155 - global.safe_bottom_gui;
HINT_PILL_B = PH_H - 65  - global.safe_bottom_gui;
COIN_BAL_X  = PH_W / 2 - 80;
COIN_BAL_Y  = PH_H - 110 - global.safe_bottom_gui;
coin_pulse_t     = 1.0;
coin_overshoot_t = 1.0;

// ── Win state ─────────────────────────────────────────────────────────────────
win_phase        = 0;
coins_bonus      = 0;
win_time_str     = "0:00";
timer_key        = "colordoku_" + global.selected_date_key;
timer_base_secs  = ph_timer_get(global.save, timer_key);
session_start_ms = current_time;

// ── Instance methods ──────────────────────────────────────────────────────────

/// Persist the live board + the hint-locked-X mask.
cd_save = function() {
    ph_colordoku_save_state(global.save, global.selected_date_key, state, hint_x_locked);
    ph_save_write(global.save);
};

/// Win bookkeeping — fires once when the placement is correct.
cd_check_win = function() {
    if (!ph_colordoku_is_solved(state, N, regions)) return;
    var _fin_s = ph_timer_now(timer_base_secs, session_start_ms);
    win_time_str = string(_fin_s div 60) + ":" + (((_fin_s mod 60) < 10) ? "0" : "") + string(_fin_s mod 60);
    global.save[$ "colordoku_time_" + global.selected_date_key] = win_time_str;

    cd_save();
    ph_colordoku_mark_done(global.save, global.selected_date_key);

    // Colordoku counts toward the daily goal like any puzzle (the goal is "any
    // PH_PUZZLES_PER_DAY solves" out of all available), so a Colordoku solve can
    // be the 4th of the day and trigger the gift box.
    var _count = ph_solved_count_on(global.save, global.selected_date_key);
    coins_bonus = 0;
    if (_count >= PH_GIFT_PUZZLE_INDEX + 1 && !ph_has_gift_been_claimed(global.save, global.selected_date_key)) {
        ph_claim_gift(global.save, global.selected_date_key);
        ph_grant_coins(global.save, PH_COINS_FOR_4TH);
        coins_bonus = PH_COINS_FOR_4TH;
    }
    ph_update_streak(global.save);
    ph_save_write(global.save);

    win_phase        = 1;
    win.cfg.time_str = win_time_str;
    ph_win_celebrate(win);
};

// ── Hint helpers (used by the shared hint modal) ──────────────────────────────
/// True if the hint would mark anything (≥1 blank cell is ruled out by a queen).
cd_can_hint = function() {
    return ph_colordoku_has_forced_x(state, N, regions);
};

/// Place up to PH_COLORDOKU_HINT_XS logically-safe X's (cells the current queens
/// already rule out) and LOCK them (can't be removed). Returns the iris target
/// (cluster centre + radius); the placed X's pop in after the reveal lands.
/// Does NOT touch coins (the shared hint flow handles the spend).
cd_apply_hint = function() {
    var _forced = ph_colordoku_forced_x(state, N, regions);
    if (array_length(_forced) == 0) return false;
    var _take = min(PH_COLORDOKU_HINT_XS, array_length(_forced));

    for (var _i = 0; _i < NCELLS; _i++) cd_x_order[_i] = -1;   // reset pop ordering
    cd_hint_cells = [];
    var _sx = 0, _sy = 0;
    for (var _i = 0; _i < _take; _i++) {
        var _ci = _forced[_i];
        state[_ci]         = 1;
        hint_x_locked[_ci] = true;
        cd_x_order[_ci]    = _i;
        array_push(cd_hint_cells, _ci);
        _sx += grid_x + (_ci mod N) * CELL + CELL/2;
        _sy += grid_y + (_ci div N) * CELL + CELL/2;
    }
    cd_save();

    cd_hint_reveal = true;   // hide the new X's until the iris lands
    cd_pop_f       = -1;
    var _cx = _sx / _take, _cy = _sy / _take, _rad = 0;
    for (var _i = 0; _i < _take; _i++) {
        var _ci = cd_hint_cells[_i];
        var _px = grid_x + (_ci mod N) * CELL + CELL/2;
        var _py = grid_y + (_ci div N) * CELL + CELL/2;
        _rad = max(_rad, point_distance(_cx, _cy, _px, _py));
    }
    return { x: _cx, y: _cy, r: _rad + CELL * 0.55 };
};

// Shared hint-flow controller (modal + placeholder video). Bright-teal accent.
hint = ph_hint_create(cd_apply_hint, ACCENT, "This hint locks in " + string(PH_COLORDOKU_HINT_XS) + " squares\nyour queens already rule out", "colordoku_" + global.selected_date_key);

// ── Drawing helpers ───────────────────────────────────────────────────────────

/// Draw the queen "gem": a faceted teal diamond with a white rim. Reads on any
/// region colour. _cx,_cy = cell centre, _hs = half-size.
cd_draw_gem = function(_cx, _cy, _hs, _col) {
    var _tx = _cx,        _ty = _cy - _hs;
    var _rx = _cx + _hs,  _ry = _cy;
    var _bx = _cx,        _by = _cy + _hs;
    var _lx = _cx - _hs,  _ly = _cy;
    // White rim (slightly larger diamond).
    var _o = _hs + 7;
    draw_set_color(PH_COL_WHITE);
    draw_triangle(_cx, _cy - _o, _cx + _o, _cy, _cx, _cy + _o, false);
    draw_triangle(_cx, _cy - _o, _cx, _cy + _o, _cx - _o, _cy, false);
    // Gem body.
    draw_set_color(_col);
    draw_triangle(_tx, _ty, _rx, _ry, _bx, _by, false);
    draw_triangle(_tx, _ty, _bx, _by, _lx, _ly, false);
    // Top facet highlight.
    draw_set_color(merge_color(_col, PH_COL_WHITE, 0.5));
    draw_triangle(_tx, _ty, _rx, _ry, _cx, _cy, false);
    draw_triangle(_tx, _ty, _cx, _cy, _lx, _ly, false);
};

/// Draw a white "ruled out" X centred in a cell.
cd_draw_x = function(_cx, _cy, _r) {
    draw_set_color(PH_COL_WHITE);
    draw_line_width(_cx - _r, _cy - _r, _cx + _r, _cy + _r, 14);
    draw_line_width(_cx - _r, _cy + _r, _cx + _r, _cy - _r, 14);
};

/// Draw one board cell (region-coloured rounded tile + its mark + conflict rim).
cd_draw_cell = function(_r, _c, _conflict) {
    var _i  = _r * N + _c;
    var _x0 = grid_x + _c * CELL + TILE_GAP;
    var _y0 = grid_y + _r * CELL + TILE_GAP;
    var _x1 = grid_x + (_c + 1) * CELL - TILE_GAP;
    var _y1 = grid_y + (_r + 1) * CELL - TILE_GAP;
    var _cx = (_x0 + _x1) / 2, _cy = (_y0 + _y1) / 2;
    // A conflicting queen's tile flashes red-orange ("Bad Luck" cue from the
    // reference); everything else shows its region colour.
    var _fill = (_conflict && state[_i] == 2) ? PH_COL_ORANGE : ph_colordoku_region_color(regions[_i]);
    ph_draw_rounded(_x0, _y0, _x1, _y1, 14, _fill);
    if (state[_i] == 1) {
        // Hint X's hide under the closing iris, then pop in one-by-one.
        var _xs  = 1;
        var _ord = cd_x_order[_i];
        if (_ord >= 0) {
            if (cd_hint_reveal) {
                _xs = 0;
            } else if (cd_pop_f >= 0) {
                var _local = cd_pop_f - _ord * CD_POP_STAG;
                _xs = (_local <= 0) ? 0
                    : ((_local >= CD_POP_DUR) ? 1 : ph_ease_out_back(_local / CD_POP_DUR, 2.4));
            }
        }
        if (_xs > 0.01) cd_draw_x(_cx, _cy, CELL * 0.24 * _xs);
    } else if (state[_i] == 2) {
        cd_draw_gem(_cx, _cy, CELL * 0.30, (_conflict ? PH_COL_DARK : ACCENT));
    }
};

// ── Restore in-progress board (resume) ────────────────────────────────────────
var _saved = ph_colordoku_load_state(global.save, global.selected_date_key, NCELLS);
if (!is_undefined(_saved) && array_length(_saved) == NCELLS) state = _saved;
var _xl = ph_colordoku_load_xlock(global.save, global.selected_date_key, NCELLS);
if (!is_undefined(_xl) && array_length(_xl) == NCELLS) hint_x_locked = _xl;

// ── Enter review/solved mode when re-opening a finished puzzle ─────────────────
var _review = variable_global_exists("colordoku_review_mode") && global.colordoku_review_mode;
if (_review) global.colordoku_review_mode = false;
var _already_solved = _review || ph_colordoku_is_done(global.save, global.selected_date_key);

// ── Shared win screen (scr_economy §Shared Win Screen) ────────────────────────
// Mini solved board fitted into the recap box (regions + gems on solution cells).
win_draw_recap = function(_cx, _top, _bw, _bh) {
    var _cell = floor(min(_bw, _bh) / N);
    var _grid = _cell * N;
    var _ox = _cx - _grid/2, _oy = _top + (_bh - _grid)/2;
    ph_draw_chip(_ox-12, _oy-12, _ox+_grid+12, _oy+_grid+12, 16, ACCENT, ACCENT_DEEP, 4);
    for (var _r = 0; _r < N; _r++) {
        for (var _c = 0; _c < N; _c++) {
            var _i  = _r * N + _c;
            var _x1 = _ox + _c * _cell + 3, _y1 = _oy + _r * _cell + 3;
            var _x2 = _ox + (_c+1) * _cell - 3, _y2 = _oy + (_r+1) * _cell - 3;
            ph_draw_rounded(_x1, _y1, _x2, _y2, 7, ph_colordoku_region_color(regions[_i]));
            if (puzzle.solution[_i] == 1) {
                cd_draw_gem((_x1+_x2)/2, (_y1+_y2)/2, _cell*0.26, ACCENT);
            }
        }
    }
};
win = ph_win_create({
    puzzle_name: "DIAMOND",
    title_col:   ACCENT_DEEP,
    bg_col:      ACCENT,
    claim_key:   "colordoku_" + global.selected_date_key,
    already:     _already_solved,
    share_url:   PH_SHARE_URL,
    time_str:    win_time_str,
    draw_recap:  win_draw_recap,
});

if (_already_solved) {
    // Show the completed board: gems on solution cells, X elsewhere.
    for (var _i = 0; _i < NCELLS; _i++) state[_i] = (puzzle.solution[_i] == 1) ? 2 : 1;
    var _tk = "colordoku_time_" + global.selected_date_key;
    win_time_str = variable_struct_exists(global.save, _tk) ? global.save[$ _tk] : "--:--";
    win.cfg.time_str = win_time_str;
    win_phase = 1;
    ph_win_celebrate(win);
}

// ── First-play onboarding finger tip (soft, no text) ──────────────────────────
// Taps a real solution-queen cell. A single tap cycles empty→X→queen, so the
// looping tap lands the player on a correct gem after two follows. Loops until
// the first queen is placed, then the tip is marked seen.
coach = ph_coach_create(ACCENT);
if (!ph_tip_seen("COLORDOKU") && !_already_solved) {
    var _tgt = -1;
    for (var _i = 0; _i < NCELLS; _i++) {
        if (puzzle.solution[_i] == 1 && state[_i] == 0) { _tgt = _i; break; }
    }
    if (_tgt >= 0) {
        var _qx = grid_x + (_tgt mod N) * CELL + CELL/2;
        var _qy = grid_y + (_tgt div N) * CELL + CELL/2;
        ph_coach_set_steps(coach, [ ph_coach_tap(_qx, _qy) ]);
    }
}
