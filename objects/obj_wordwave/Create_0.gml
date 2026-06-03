// ── Word Wave — Create ────────────────────────────────────────────────────────
// 8×8 letter grid. Players swipe straight lines (any of 8 directions) to find
// the hidden words listed below the grid. Valid straight-line words that are
// not in the hidden list but ARE in the puzzle's bonus_pool pay +10 coins.

puzzle = ph_wordwave_for_date(global.selected_date_key);
GRID_N = puzzle.size;   // 8

// ── Grid geometry ─────────────────────────────────────────────────────────────
// Board is a fixed-width square centred horizontally and top-anchored below the
// HUD strip. CELL is derived so the 8×8 board fits BOARD_W exactly.
BOARD_W = 900;
GAP     = 10;
CELL    = floor((BOARD_W - (GRID_N - 1) * GAP) / GRID_N);
grid_w  = GRID_N * CELL + (GRID_N - 1) * GAP;
grid_h  = grid_w;   // square
grid_x  = floor((PH_W - grid_w) / 2);
grid_y  = 250 + global.safe_top_gui;

// Per-cell pop animation (indexed r*GRID_N + c).
cell_flash  = array_create(GRID_N * GRID_N, 0.0);
cell_scales = array_create(GRID_N * GRID_N, 1.0);

// ── Per-word highlight colours ────────────────────────────────────────────────
// Pulled from the hub palette so found words read as part of the same UI.
// Each hidden word gets a distinct strong colour; the cells it occupies are
// capsule-highlighted in that colour with white letters once found.
word_palette = [
    PH_COL_PINK, PH_COL_TEAL, PH_COL_PURPLE, PH_COL_ORANGE,
    PH_COL_YELLOW_DEEP, PH_COL_PINK_DEEP, PH_COL_TEAL_DEEP, PH_COL_PURPLE_DEEP,
];
word_colors = array_create(array_length(puzzle.words));
for (var _wi = 0; _wi < array_length(puzzle.words); _wi++) {
    word_colors[_wi] = word_palette[_wi mod array_length(word_palette)];
}

// ── Swipe state ───────────────────────────────────────────────────────────────
is_dragging   = false;
drag_start    = undefined;   // {r,c}
sel_path      = [];          // array of {r,c} for the current straight-line selection
sel_valid     = false;       // path forms a legal straight line

// ── Hint cells ────────────────────────────────────────────────────────────────
// Hint reveals only the FIRST letter of an unfound word: its starting cell gets
// a persistent ring marker. Stored as "r,c" keys so re-hinting the same word is
// a no-op and resume restores them.
hint_cells = {};

// ── Feedback toast ──────────────────────────────────────────────────────────
toast_text  = "";
toast_col   = PH_COL_TEAL;
toast_timer = 0;
TOAST_DUR   = 90;

// Shake feedback (invalid swipe).
shake_t        = 0;
shake_offset_x = 0;
SHAKE_DUR      = 16;

// ── Bottom toolbar targets (re-written every frame by Draw, mirrored here) ────
bonus_modal_open = false;
BONUS_ICON_X = 100;
BONUS_ICON_Y = PH_H - 120 - global.safe_bottom_gui;
BONUS_ICON_R = 60;
COIN_BAL_X   = PH_W / 2 - 80;
COIN_BAL_Y   = PH_H - 110 - global.safe_bottom_gui;
coin_pulse_t     = 1.0;
coin_overshoot_t = 1.0;

HINT_PILL_L = PH_W - 450;
HINT_PILL_R = PH_W - 50;
HINT_PILL_T = PH_H - 155 - global.safe_bottom_gui;
HINT_PILL_B = PH_H - 65  - global.safe_bottom_gui;

// ── Hydrate found state from save (resume mid-puzzle) ─────────────────────────
for (var _wi = 0; _wi < array_length(puzzle.words); _wi++) {
    puzzle.words[_wi].found = ph_wordwave_is_word_found(
        global.save, global.selected_date_key, _wi);
}
if (ph_wordwave_is_done(global.save, global.selected_date_key)) {
    for (var _wi = 0; _wi < array_length(puzzle.words); _wi++) puzzle.words[_wi].found = true;
}
for (var _i = 0; _i < array_length(puzzle.bonus_pool); _i++) {
    puzzle.bonus_found[_i] = ph_wordwave_is_bonus_found(
        global.save, global.selected_date_key, puzzle.bonus_pool[_i]);
}

// ── Flying tiles (coin reward arc) ────────────────────────────────────────────
global.fly_tiles = [];

// ── Win / celebration state ───────────────────────────────────────────────────
win_phase        = 0;   // 0=playing 1=complete
xp_gained        = 0;
coins_bonus      = 0;
win_anim_t       = 0;
win_btn_back_y   = 0;
win_time_str     = "0:00";
session_start_ms = current_time;

confetti_pieces          = [];
confetti_burst_pending   = false;
confetti_run_frames      = 0;
CONFETTI_TARGET_FALL     = 70;
CONFETTI_DURATION_FRAMES = 180;

// Win-review re-entry: hub sets global.wordwave_review_mode before navigating.
var _review = variable_global_exists("wordwave_review_mode") && global.wordwave_review_mode;
if (_review) global.wordwave_review_mode = false;

if (_review || ph_wordwave_all_solved(puzzle)) {
    var _time_key = "wordwave_time_" + global.selected_date_key;
    win_time_str  = variable_struct_exists(global.save, _time_key)
                    ? global.save[$ _time_key] : "--:--";
    xp_gained  = PH_XP_PER_PUZZLE;
    win_phase  = 1;
    win_anim_t = 1.0;
    confetti_burst_pending = true;
}

// ── Helper methods ────────────────────────────────────────────────────────────

/// Cell {r,c} under a GUI point, or undefined if in a gap / off the board.
ww_cell_at = function(_px, _py) {
    if (_px < grid_x || _py < grid_y) return undefined;
    var _stride = CELL + GAP;
    var _col = (_px - grid_x) div _stride;
    var _row = (_py - grid_y) div _stride;
    if (_col < 0 || _col >= GRID_N || _row < 0 || _row >= GRID_N) return undefined;
    // Reject points that land in the gap between cells.
    var _in_x = (_px - grid_x) - _col * _stride;
    var _in_y = (_py - grid_y) - _row * _stride;
    if (_in_x > CELL || _in_y > CELL) return undefined;
    return { r: _row, c: _col };
};

/// Centre (GUI x,y) of cell (r,c).
ww_cell_center = function(_r, _c) {
    return {
        x: grid_x + _c * (CELL + GAP) + CELL / 2,
        y: grid_y + _r * (CELL + GAP) + CELL / 2,
    };
};

/// Build a straight-line path of cells from _start to _end if they're colinear
/// along one of the 8 directions; otherwise return undefined.
ww_build_path = function(_start, _end) {
    var _dr = _end.r - _start.r;
    var _dc = _end.c - _start.c;
    if (_dr == 0 && _dc == 0) return [{ r: _start.r, c: _start.c }];
    var _sr = sign(_dr);
    var _sc = sign(_dc);
    var _ok = (_dr == 0) || (_dc == 0) || (abs(_dr) == abs(_dc));
    if (!_ok) return undefined;
    var _steps = max(abs(_dr), abs(_dc));
    var _path = [];
    for (var _i = 0; _i <= _steps; _i++) {
        array_push(_path, { r: _start.r + _sr * _i, c: _start.c + _sc * _i });
    }
    return _path;
};

/// True if cell (r,c) belongs to any found word — used for permanent highlight.
ww_cell_found_color = function(_r, _c) {
    for (var _wi = 0; _wi < array_length(puzzle.words); _wi++) {
        if (!puzzle.words[_wi].found) continue;
        var _cells = puzzle.words[_wi].cells;
        for (var _k = 0; _k < array_length(_cells); _k++) {
            if (_cells[_k].r == _r && _cells[_k].c == _c) return word_colors[_wi];
        }
    }
    return undefined;
};

ww_flash_path = function(_path) {
    for (var _i = 0; _i < array_length(_path); _i++) {
        var _idx = _path[_i].r * GRID_N + _path[_i].c;
        cell_flash[_idx] = 12;
    }
};

ww_play_shake = function() { shake_t = SHAKE_DUR; };

/// Spawn a single coin arc from the bonus chest to the coin counter.
ww_spawn_coin_drop = function() {
    array_push(global.fly_tiles, {
        kind: "coin",
        x: BONUS_ICON_X, y: BONUS_ICON_Y,
        tx: COIN_BAL_X,  ty: COIN_BAL_Y,
        t: 0,
    });
};

/// Finalise the puzzle: time, persistence, XP, gift, streak, save, celebrate.
ww_check_win = function() {
    if (!ph_wordwave_all_solved(puzzle)) return;
    var _fin_s  = floor((current_time - session_start_ms) / 1000);
    var _fin_m  = _fin_s div 60;
    var _fin_ss = _fin_s mod 60;
    win_time_str = string(_fin_m) + ":" + ((_fin_ss < 10) ? "0" : "") + string(_fin_ss);
    global.save[$ "wordwave_time_" + global.selected_date_key] = win_time_str;

    for (var _wi = 0; _wi < array_length(puzzle.words); _wi++) {
        ph_wordwave_mark_word(global.save, global.selected_date_key, _wi);
    }
    ph_wordwave_mark_done(global.save, global.selected_date_key);

    // auto_coins=false: level-up coins are deferred to the Level-Up screen (rm_win).
    var _lvl_res = ph_grant_xp(global.save, PH_XP_PER_PUZZLE, false);
    xp_gained = PH_XP_PER_PUZZLE;
    if (_lvl_res.levels_gained > 0) {
        global.pending_levelup = { level: _lvl_res.new_level, base_reward: PH_COINS_PER_LEVEL };
    }

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
    confetti_burst_pending = true;
};

// ── Hint helpers (used by the shared hint modal) ──────────────────────────────
/// Index of the first unfound word whose start cell isn't already ringed, or -1.
ww_next_hint_word = function() {
    for (var _wi = 0; _wi < array_length(puzzle.words); _wi++) {
        if (puzzle.words[_wi].found) continue;
        var _start = puzzle.words[_wi].cells[0];
        var _key   = string(_start.r) + "," + string(_start.c);
        if (!variable_struct_exists(hint_cells, _key)) return _wi;
    }
    return -1;
};

/// True if a first-letter hint is still available.
ww_can_hint = function() {
    return ww_next_hint_word() >= 0;
};

/// Ring the first letter of the next eligible unfound word. Returns true on
/// success. Does NOT touch coins.
ww_apply_hint = function() {
    var _wi = ww_next_hint_word();
    if (_wi < 0) return false;
    var _s = puzzle.words[_wi].cells[0];
    hint_cells[$ string(_s.r) + "," + string(_s.c)] = true;
    cell_flash[_s.r * GRID_N + _s.c] = 12;
    ph_save_write(global.save);
    return true;
};

// Shared hint-flow controller (modal + placeholder video). Teal accent.
hint = ph_hint_create(ww_apply_hint, PH_COL_TEAL);
