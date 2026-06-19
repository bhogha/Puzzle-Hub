// ── Sudoku — Create ───────────────────────────────────────────────────────────
puzzle = ph_sudoku_for_date(global.selected_date_key);

// ── Grid geometry ─────────────────────────────────────────────────────────────
// 9×9 board centred horizontally, top-anchored just below the HUD strip.
GAP    = 0;                                   // cells are flush; lines drawn over them
BOARD  = 990;                                 // total board pixel size
CELL   = BOARD / 9;                           // 110 px per cell
grid_x = floor((PH_W - BOARD) / 2);           // 45
grid_y = 215 + global.safe_top_gui;
grid_h = BOARD;

// Bottom-anchor the whole play cluster (board → number pad → delete) just above
// the bottom HUD toolbar instead of top-anchoring it under the HUD. NUM_Y/DEL_Y
// derive from grid_y below, so shifting grid_y moves them too. (Heights: pad gap
// 95 + NUM_H 110 + del gap 40 + DEL_H 96.)
var _cluster_h  = grid_h + 95 + 110 + 40 + 96;
var _target_bot = PH_H - global.safe_bottom_gui - 155 - PH_PLAY_BOTTOM_GAP;
grid_y += max(0, _target_bot - (grid_y + _cluster_h));

// ── Number pad (1..9) geometry ────────────────────────────────────────────────
NUM_Y  = grid_y + grid_h + 95;
NUM_H  = 110;
var _pad_margin = 40;
var _avail = PH_W - _pad_margin * 2;
NUM_W  = 92;
var _ngap = (_avail - 9 * NUM_W) / 8;
num_x  = array_create(9, 0);
for (var _i = 0; _i < 9; _i++) {
    num_x[_i] = _pad_margin + _i * (NUM_W + _ngap);   // left edge of tile i (digit i+1)
}

// ── Delete button geometry ────────────────────────────────────────────────────
DEL_W  = 320;
DEL_H  = 96;
DEL_L  = floor((PH_W - DEL_W) / 2);
DEL_Y  = NUM_Y + NUM_H + 40;     // top edge

// ── Selection + animation state ───────────────────────────────────────────────
sel_idx     = -1;                         // selected cell index (0..80), -1 = none
cell_flash  = array_create(81, 0.0);      // green "unit solved" pulse, frames remaining
cell_scale  = array_create(81, 1.0);      // per-cell pop scale

// ── Hint reveal/number-pop state (shared iris via ph_hint_draw_reveal) ────────
// The revealed number is hidden under the closing iris, then pops in (positive
// green cell — see Draw) once the reveal lands.
sd_last_hint_idx   = -1;
sd_hint_reveal_idx = -1;                  // cell whose number is hidden during the iris
sd_hint_pop_idx    = -1;                  // cell whose number is popping in
sd_hint_pop_t      = 1;                   // 0..1 pop progress (1 == idle)

// Per-unit solved tracking — used to detect the *transition* into solved so the
// positive feedback flash fires exactly once per row/column/box.
row_solved = array_create(9, false);
col_solved = array_create(9, false);
box_solved = array_create(9, false);

// ── Feedback toast ────────────────────────────────────────────────────────────
toast_text  = "";
toast_col   = PH_COL_PURPLE;
toast_timer = 0;
TOAST_DUR   = 90;

// ── HUD / toolbar tap targets (re-written every frame by Draw, read by Step) ──
HINT_PILL_L = PH_W - 390;
HINT_PILL_R = PH_W - 50;
HINT_PILL_T = PH_H - 155 - global.safe_bottom_gui;
HINT_PILL_B = PH_H - 65  - global.safe_bottom_gui;
COIN_BAL_X  = PH_W / 2 - 80;
COIN_BAL_Y  = PH_H - 110 - global.safe_bottom_gui;
coin_pulse_t     = 1.0;
coin_overshoot_t = 1.0;

// ── Restore in-progress grid (resume) ─────────────────────────────────────────
var _saved = ph_sudoku_load_grid(global.save, global.selected_date_key);
if (!is_undefined(_saved) && string_length(_saved) == 81) {
    for (var _i = 0; _i < 81; _i++) {
        var _v = real(string_char_at(_saved, _i + 1));
        // Never let a saved blank wipe a locked given.
        if (puzzle.givens[_i] != 0) puzzle.grid[_i] = puzzle.givens[_i];
        else                        puzzle.grid[_i] = _v;
    }
}

// ── Debug: start ~90% solved (testing only — gated by PH_SUDOKU_TEST_PREFILL) ──
// Fills correct values into empty, non-given cells until only ~10% of the whole
// board (≈8 cells) remain blank, so the win flow is fast to reach.
if (PH_SUDOKU_TEST_PREFILL && !ph_sudoku_is_done(global.save, global.selected_date_key)) {
    var _empty = [];
    for (var _i = 0; _i < 81; _i++) {
        if (puzzle.givens[_i] == 0 && puzzle.grid[_i] == 0) array_push(_empty, _i);
    }
    // Shuffle so the remaining blanks are spread around the board.
    for (var _i = array_length(_empty) - 1; _i > 0; _i--) {
        var _j = irandom(_i);
        var _t = _empty[_i]; _empty[_i] = _empty[_j]; _empty[_j] = _t;
    }
    var _leave_blank = max(1, round(81 * 0.10));   // keep ~8 cells empty
    var _to_fill = max(0, array_length(_empty) - _leave_blank);
    for (var _k = 0; _k < _to_fill; _k++) {
        puzzle.grid[_empty[_k]] = puzzle.solution[_empty[_k]];
    }
}

// ── Win state ─────────────────────────────────────────────────────────────────
win_phase        = 0;
xp_gained        = 0;
coins_bonus      = 0;
win_anim_t       = 0;
win_btn_back_y   = 0;
win_time_str     = "0:00";
timer_key        = "sudoku_" + global.selected_date_key;
timer_base_secs  = ph_timer_get(global.save, timer_key);
session_start_ms = current_time;

// ── Confetti state (mirrors Anygram celebration) ──────────────────────────────
confetti_pieces           = [];
confetti_burst_pending    = false;
confetti_run_frames       = 0;
CONFETTI_TARGET_FALL      = 70;
CONFETTI_DURATION_FRAMES  = 180;

// ── Instance methods ──────────────────────────────────────────────────────────

/// Flash every cell in a row/column/box that just became solved.
sd_flash_cells = function(_indices) {
    for (var _k = 0; _k < array_length(_indices); _k++) {
        cell_flash[_indices[_k]] = 18;
    }
};

/// Re-scan all rows/columns/boxes; flash any unit that transitioned to solved.
sd_check_units = function() {
    for (var _r = 0; _r < 9; _r++) {
        var _now = ph_sudoku_row_solved(puzzle, _r);
        if (_now && !row_solved[_r]) {
            var _idx = array_create(9, 0);
            for (var _c = 0; _c < 9; _c++) _idx[_c] = _r * 9 + _c;
            sd_flash_cells(_idx);
        }
        row_solved[_r] = _now;
    }
    for (var _c = 0; _c < 9; _c++) {
        var _nowc = ph_sudoku_col_solved(puzzle, _c);
        if (_nowc && !col_solved[_c]) {
            var _idxc = array_create(9, 0);
            for (var _r2 = 0; _r2 < 9; _r2++) _idxc[_r2] = _r2 * 9 + _c;
            sd_flash_cells(_idxc);
        }
        col_solved[_c] = _nowc;
    }
    for (var _b = 0; _b < 9; _b++) {
        var _br = _b div 3;
        var _bc = _b mod 3;
        var _nowb = ph_sudoku_box_solved(puzzle, _br, _bc);
        if (_nowb && !box_solved[_b]) {
            var _idxb = array_create(9, 0);
            var _n = 0;
            for (var _dr = 0; _dr < 3; _dr++) {
                for (var _dc = 0; _dc < 3; _dc++) {
                    _idxb[_n++] = (_br * 3 + _dr) * 9 + (_bc * 3 + _dc);
                }
            }
            sd_flash_cells(_idxb);
        }
        box_solved[_b] = _nowb;
    }
};

/// Win bookkeeping — fires exactly once when the grid is fully correct.
sd_check_win = function() {
    if (!ph_sudoku_all_solved(puzzle)) return;
    var _fin_s  = ph_timer_now(timer_base_secs, session_start_ms);
    var _fin_m  = _fin_s div 60;
    var _fin_ss = _fin_s mod 60;
    win_time_str = string(_fin_m) + ":" + ((_fin_ss < 10) ? "0" : "") + string(_fin_ss);
    global.save[$ "sudoku_time_" + global.selected_date_key] = win_time_str;

    ph_sudoku_save_grid(global.save, global.selected_date_key, ph_sudoku_grid_to_str(puzzle));
    ph_sudoku_mark_done(global.save, global.selected_date_key);

    // XP is claimed on the win screen now (ph_win_grant), which also routes any
    // level-up to the Level-Up reward screen (rm_win). Nothing granted here.
    // Gift box for the 4th solved puzzle of the day.
    var _count = ph_solved_count_on(global.save, global.selected_date_key);
    coins_bonus = 0;
    if (_count >= PH_GIFT_PUZZLE_INDEX + 1 && !ph_has_gift_been_claimed(global.save, global.selected_date_key)) {
        ph_claim_gift(global.save, global.selected_date_key);
        ph_grant_coins(global.save, PH_COINS_FOR_4TH);
        coins_bonus = PH_COINS_FOR_4TH;
    }
    ph_update_streak(global.save);
    ph_save_write(global.save);

    sel_idx                = -1;
    win_phase              = 1;
    win.cfg.time_str = win_time_str;
    ph_win_celebrate(win);
};

// ── Hint helpers (used by the shared hint modal) ──────────────────────────────
/// True if any non-given cell is still empty (i.e. a reveal is possible).
sd_can_hint = function() {
    for (var _i = 0; _i < 81; _i++) {
        if (!ph_sudoku_is_given(puzzle, _i) && puzzle.grid[_i] == 0) return true;
    }
    return false;
};

/// Reveal one correct number — the selected empty cell if any, else a random
/// empty cell. Returns true on success. Does NOT touch coins.
sd_apply_hint = function() {
    var _target = -1;
    if (sel_idx >= 0 && !ph_sudoku_is_given(puzzle, sel_idx) && puzzle.grid[sel_idx] == 0) {
        _target = sel_idx;
    } else {
        var _empties = [];
        for (var _i = 0; _i < 81; _i++) {
            if (!ph_sudoku_is_given(puzzle, _i) && puzzle.grid[_i] == 0) array_push(_empties, _i);
        }
        if (array_length(_empties) > 0) _target = _empties[irandom(array_length(_empties)-1)];
    }
    if (_target < 0) return false;
    puzzle.grid[_target]   = puzzle.solution[_target];
    puzzle.hinted[_target] = true;
    sd_check_units();
    ph_sudoku_save_grid(global.save, global.selected_date_key, ph_sudoku_grid_to_str(puzzle));
    ph_save_write(global.save);

    // Defer the win-check to the controller (after the reveal). Hide the number
    // under the closing iris; return the cell centre so the iris aims at it.
    sd_last_hint_idx   = _target;
    sd_hint_reveal_idx = _target;
    var _row = _target div 9, _col = _target mod 9;
    return { x: grid_x + _col * CELL + CELL/2, y: grid_y + _row * CELL + CELL/2, r: CELL * 0.60 };
};

// Shared hint-flow controller (modal + placeholder video). Purple accent.
hint = ph_hint_create(sd_apply_hint, PH_COL_PURPLE, "This hint will reveal one\ncorrect number", "sudoku_" + global.selected_date_key);

// ── Enter review/solved mode when re-opening a finished puzzle ─────────────────
var _review = variable_global_exists("sudoku_review_mode") && global.sudoku_review_mode;
if (_review) global.sudoku_review_mode = false;
var _already_solved = _review || ph_sudoku_is_done(global.save, global.selected_date_key) || ph_sudoku_all_solved(puzzle);

// ── Shared win screen (scr_economy §Shared Win Screen) ────────────────────────
// Mini solved Sudoku board fitted into the recap box.
win_draw_recap = function(_cx, _top, _bw, _bh) {
    var _cell = floor(min(_bw, _bh) / 9);
    var _grid = _cell * 9;
    var _ox = _cx - _grid/2, _oy = _top + (_bh - _grid)/2;
    ph_draw_chip(_ox-12, _oy-12, _ox+_grid+12, _oy+_grid+12, 16, PH_COL_PURPLE_SOFT, make_color_rgb(150,120,210), 4);
    var _fnt = (_cell >= 40) ? global.fnt_body_md : global.fnt_body_sm;
    for (var _mi = 0; _mi < 81; _mi++) {
        var _mr = _mi div 9, _mc = _mi mod 9;
        var _mcx = _ox + _mc*_cell + _cell/2, _mcy = _oy + _mr*_cell + _cell/2;
        var _mcol = ph_sudoku_is_given(puzzle, _mi) ? PH_COL_DARK
                  : (puzzle.hinted[_mi] ? PH_COL_YELLOW_DEEP : PH_COL_PURPLE_DEEP);
        ph_draw_text(_mcx, _mcy, string(puzzle.solution[_mi]), _fnt, _mcol, fa_center, fa_middle);
    }
    for (var _mk = 0; _mk <= 9; _mk++) {
        var _mbold = (_mk mod 3 == 0);
        draw_set_color(_mbold ? PH_COL_DARK : make_color_rgb(180,165,205));
        var _mlw = _mbold ? 3 : 1;
        var _mgx = _ox + _mk*_cell;
        draw_line_width(_mgx, _oy, _mgx, _oy+_grid, _mlw);
        var _mgy = _oy + _mk*_cell;
        draw_line_width(_ox, _mgy, _ox+_grid, _mgy, _mlw);
    }
};
win = ph_win_create({
    puzzle_name: "SUDOKU",
    title_col:   PH_COL_PURPLE,
    bg_col:      PH_COL_TEAL,
    claim_key:   "sudoku_" + global.selected_date_key,
    already:     _already_solved,
    share_url:   PH_SHARE_URL,
    time_str:    win_time_str,
    draw_recap:  win_draw_recap,
});

if (_already_solved) {
    for (var _i = 0; _i < 81; _i++) puzzle.grid[_i] = puzzle.solution[_i];
    var _tk = "sudoku_time_" + global.selected_date_key;
    win_time_str = variable_struct_exists(global.save, _tk) ? global.save[$ _tk] : "--:--";
    win.cfg.time_str = win_time_str;
    win_phase = 1;
    ph_win_celebrate(win);
}

// Seed the per-unit solved snapshot so already-correct units don't re-flash on
// entry; clear any flashes the seeding pass produced.
sd_check_units();
for (var _i = 0; _i < 81; _i++) cell_flash[_i] = 0.0;
