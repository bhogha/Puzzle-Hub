// ── Word Bend — Create ────────────────────────────────────────────────────────
// 4×4 … 6×6 letter board, completely filled. Every letter belongs to one hidden
// word whose cell-path tiles the board (orthogonal bends, no diagonals). Tap a
// word's first letter and drag across the rest to find it. No bonus, no loss.
// Tangerine accent; found words lock green.

puzzle = ph_wordbend_for_date(global.selected_date_key);
N      = puzzle.size;
NCELLS = N * N;
NWORDS = array_length(puzzle.words);

ACCENT      = PH_COL_TANGERINE;
ACCENT_DEEP = PH_COL_TANGERINE_DEEP;

// ── Board geometry (centred square, bottom-anchored above the toolbar) ─────────
BOARD_W = 920;
GAP     = 16;
CELL    = floor((BOARD_W - (N - 1) * GAP) / N);
grid_w  = N * CELL + (N - 1) * GAP;
grid_h  = grid_w;
grid_x  = floor((PH_W - grid_w) / 2);
grid_y  = 320 + global.safe_top_gui;
var _target_bot = PH_H - global.safe_bottom_gui - 155 - PH_PLAY_BOTTOM_GAP;
grid_y += max(0, _target_bot - (grid_y + grid_h));

TILE_R  = floor(CELL * 0.18);   // tile corner radius

// ── Live state ────────────────────────────────────────────────────────────────
found       = array_create(NWORDS, false);   // word found?
hinted      = array_create(NWORDS, false);    // first letter revealed by a hint?
cell_owner  = array_create(NCELLS, -1);       // found-word index owning a cell, or -1

// Per-word highlight colour — each found word locks in its own hue (vibrant hub
// palette, same set Color Link uses), cycled if a puzzle ever exceeds 8 words.
wb_word_palette = [
    PH_COL_PINK, PH_COL_TEAL, PH_COL_PURPLE, PH_COL_ORANGE,
    PH_COL_BLUE, PH_COL_GREEN, PH_COL_VIOLET, PH_COL_YELLOW_DEEP,
];
word_colors = array_create(NWORDS);
for (var _w = 0; _w < NWORDS; _w++) {
    word_colors[_w] = wb_word_palette[_w mod array_length(wb_word_palette)];
}

// Per-cell pop animation (on found / hint).
cell_flash  = array_create(NCELLS, 0.0);
cell_scale  = array_create(NCELLS, 1.0);

// Trace selection (ordered cell indices, orthogonally contiguous).
dragging  = false;
sel_path  = [];

// ── Feedback toast ────────────────────────────────────────────────────────────
toast_text  = "";
toast_col   = ACCENT;
toast_timer = 0;
TOAST_DUR   = 90;

// Shake feedback (invalid trace).
shake_t        = 0;
shake_offset_x = 0;
SHAKE_DUR      = 16;

coin_pulse_t     = 1.0;
coin_overshoot_t = 1.0;
COIN_BAL_X = PH_W - 160;
COIN_BAL_Y = 95 + global.safe_top_gui;

HINT_PILL_L = PH_W - 260;
HINT_PILL_R = PH_W - 50;
HINT_PILL_T = PH_H - 143 - global.safe_bottom_gui;
HINT_PILL_B = PH_H - 77  - global.safe_bottom_gui;

// ── Bonus words (dictionary) ───────────────────────────────────────────────────
// Tracing a real ≥4-letter word that isn't one of the hidden words pays
// PH_BONUS_WORD_COINS (coins only — parity with Anygram). Found bonus words live
// in the BONUS chest+pill (bottom-left) which opens a list modal when tapped.
ph_wordbend_load_dict();               // warm the membership set at boot
bonus_words      = [];                 // uppercase bonus words found this puzzle
bonus_modal_open = false;
BONUS_PILL_L = 50;   BONUS_PILL_R = 340;          // bounds rewritten by Draw
BONUS_PILL_T = PH_H - 143 - global.safe_bottom_gui;
BONUS_PILL_B = PH_H - 77  - global.safe_bottom_gui;
wb_bonus_has = function(_word) {
    for (var _i = 0; _i < array_length(bonus_words); _i++) if (bonus_words[_i] == _word) return true;
    return false;
};

// ── Helpers ───────────────────────────────────────────────────────────────────
wb_idx       = function(_r, _c) { return _r * N + _c; };
wb_manhattan = function(_a, _b) { return abs(_a div N - _b div N) + abs(_a mod N - _b mod N); };

/// Cell index under a GUI point, or -1 if in a gap / off the board.
wb_cell_at = function(_px, _py) {
    if (_px < grid_x || _py < grid_y) return -1;
    var _stride = CELL + GAP;
    var _col = (_px - grid_x) div _stride;
    var _row = (_py - grid_y) div _stride;
    if (_col < 0 || _col >= N || _row < 0 || _row >= N) return -1;
    var _in_x = (_px - grid_x) - _col * _stride;
    var _in_y = (_py - grid_y) - _row * _stride;
    if (_in_x > CELL || _in_y > CELL) return -1;
    return _row * N + _col;
};

/// Centre (GUI x,y) of a cell index.
wb_center = function(_i) {
    return {
        x: grid_x + (_i mod N) * (CELL + GAP) + CELL / 2,
        y: grid_y + (_i div N) * (CELL + GAP) + CELL / 2,
    };
};

/// Rebuild cell_owner from the set of found words.
wb_rebuild_owner = function() {
    for (var _i = 0; _i < NCELLS; _i++) cell_owner[_i] = -1;
    for (var _w = 0; _w < NWORDS; _w++) {
        if (!found[_w]) continue;
        var _cells = puzzle.words[_w].cells;
        for (var _k = 0; _k < array_length(_cells); _k++) {
            cell_owner[_cells[_k].r * N + _cells[_k].c] = _w;
        }
    }
};

/// Index of a cell within sel_path, or -1.
wb_path_index = function(_cell) {
    for (var _i = 0; _i < array_length(sel_path); _i++) if (sel_path[_i] == _cell) return _i;
    return -1;
};

wb_flash_cells = function(_cells_idx) {
    for (var _i = 0; _i < array_length(_cells_idx); _i++) cell_flash[_cells_idx[_i]] = 12;
};

/// First-cell index of word _w (the letter a hint reveals).
wb_first_cell = function(_w) {
    var _c = puzzle.words[_w].cells[0];
    return _c.r * N + _c.c;
};

/// Persist found + hinted words and the finish-time bookkeeping.
wb_save = function() {
    ph_wordbend_save_state(global.save, global.selected_date_key, found, hinted, bonus_words);
    ph_save_write(global.save);
};

// ── Hint: reveal the first letter of the longest word not yet found OR hinted ──
// Excluding already-hinted words means each hint targets a NEW word (and the
// HINT pill greys out once every remaining word's first letter is shown).
wb_hint_target = function() {
    var _skip = array_create(NWORDS);
    for (var _w = 0; _w < NWORDS; _w++) _skip[_w] = (found[_w] || hinted[_w]);
    return ph_wordbend_longest_unfound(puzzle, _skip);
};

wb_can_hint = function() {
    return wb_hint_target() >= 0;
};

wb_apply_hint = function() {
    var _w = wb_hint_target();
    if (_w < 0) return false;
    hinted[_w] = true;
    cell_flash[wb_first_cell(_w)] = 14;
    wb_save();
    return true;
};

// Shared hint-flow controller (modal + placeholder rewarded video). Tangerine.
hint = ph_hint_create(wb_apply_hint, ACCENT, "This hint will reveal the first\nletter of the longest word", "wordbend_" + global.selected_date_key);

// ── Win bookkeeping ───────────────────────────────────────────────────────────
win_phase        = 0;
coins_bonus      = 0;
win_time_str     = "0:00";
timer_key        = "wordbend_" + global.selected_date_key;
timer_base_secs  = ph_timer_get(global.save, timer_key);
session_start_ms = current_time;

wb_check_win = function() {
    if (!ph_wordbend_is_solved(puzzle, found)) return;
    var _fin_s  = ph_timer_now(timer_base_secs, session_start_ms);
    var _fin_m  = _fin_s div 60;
    var _fin_ss = _fin_s mod 60;
    win_time_str = string(_fin_m) + ":" + ((_fin_ss < 10) ? "0" : "") + string(_fin_ss);
    global.save[$ "wordbend_time_" + global.selected_date_key] = win_time_str;

    ph_wordbend_mark_done(global.save, global.selected_date_key);

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
    ph_win_celebrate(win);
};

// Mini result board for the shared win screen (all words shown solved/green).
win_draw_recap = function(_cx, _top, _bw, _bh) {
    var _gap  = max(4, floor(CELL * 0.05));
    var _cell = floor((min(_bw, _bh) - (N - 1) * _gap) / N);
    var _gw   = N * _cell + (N - 1) * _gap;
    var _ox   = _cx - _gw / 2;
    var _oy   = _top + (_bh - _gw) / 2;
    var _fnt  = (_cell >= 56) ? global.fnt_disp_sm : global.fnt_body_md;
    // Map each cell to its word's colour.
    var _col_of = array_create(N * N, PH_COL_WB_FOUND);
    for (var _w = 0; _w < NWORDS; _w++) {
        var _cs = puzzle.words[_w].cells;
        for (var _k = 0; _k < array_length(_cs); _k++) _col_of[_cs[_k].r * N + _cs[_k].c] = word_colors[_w];
    }
    for (var _r = 0; _r < N; _r++) for (var _c = 0; _c < N; _c++) {
        var _x = _ox + _c * (_cell + _gap);
        var _y = _oy + _r * (_cell + _gap);
        ph_draw_rounded(_x, _y, _x + _cell, _y + _cell, floor(_cell*0.18), _col_of[_r * N + _c]);
        ph_draw_text(_x + _cell/2, _y + _cell/2, puzzle.grid[_r][_c],
                     _fnt, PH_COL_WHITE, fa_center, fa_middle);
    }
};

// Review re-entry: hub sets global.wordbend_review_mode before navigating.
var _review = variable_global_exists("wordbend_review_mode") && global.wordbend_review_mode;
if (_review) global.wordbend_review_mode = false;

// Restore in-progress found/hinted state (resume).
var _st = ph_wordbend_load_state(global.save, global.selected_date_key, NWORDS);
if (_st != undefined) {
    found       = _st.found;
    hinted      = _st.hinted;
    bonus_words = _st.bonus;
}
var _already_solved = _review || ph_wordbend_is_done(global.save, global.selected_date_key);
if (_already_solved) {
    for (var _w = 0; _w < NWORDS; _w++) found[_w] = true;
}
wb_rebuild_owner();

win = ph_win_create({
    puzzle_name: "WORD BEND",
    title_col:   ACCENT_DEEP,
    bg_col:      ACCENT,
    claim_key:   "wordbend_" + global.selected_date_key,
    already:     _already_solved,
    share_url:   PH_SHARE_URL,
    time_str:    win_time_str,
    draw_recap:  win_draw_recap,
});

if (_already_solved) {
    var _time_key = "wordbend_time_" + global.selected_date_key;
    win_time_str  = variable_struct_exists(global.save, _time_key) ? global.save[$ _time_key] : "--:--";
    win.cfg.time_str = win_time_str;
    win_phase = 1;
    ph_win_celebrate(win);
}
