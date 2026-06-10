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

// ── "Words to find" list — NEW Penpot layout: ABOVE the grid ──────────────────
// Two columns of pill tiles (drawn by ph_draw_word_tile). Metrics are exposed so
// Draw can place them and the game tip can sit above the whole block.
WL_COLS    = 2;
WL_GAP_X   = 24;
WL_GAP_Y   = 22;
WL_TILE_H  = 72;
WL_RADIUS  = 22;

// Tile width AUTO-FITS the longest word so long words never clip. Measured at the
// pill font (fnt_tip, the same font ph_draw_word_tile renders with), plus inner
// padding (and room for the found-word strike-through). Clamped to the original
// design width as a minimum and to a maximum that still keeps both columns on
// screen with a comfortable side margin.
draw_set_font(global.fnt_tip);
var _wl_need = 0;
for (var _wi = 0; _wi < array_length(puzzle.words); _wi++) {
    _wl_need = max(_wl_need, string_width(puzzle.words[_wi].text));
}
var _wl_min = 223;                                       // original design tile width
var _wl_max = floor((PH_W - 80 - (WL_COLS - 1) * WL_GAP_X) / WL_COLS);
WL_TILE_W  = clamp(_wl_need + 56, _wl_min, _wl_max);     // +56 = inner padding + strike room
WL_BLOCK_W = WL_COLS * WL_TILE_W + (WL_COLS - 1) * WL_GAP_X;
WL_X0      = floor((PH_W - WL_BLOCK_W) / 2);   // left edge of the 2-col block
WL_ROWS    = ceil(array_length(puzzle.words) / WL_COLS);
WL_BLOCK_H = WL_ROWS * WL_TILE_H + (WL_ROWS - 1) * WL_GAP_Y;
WL_TO_GRID = 44;   // gap between the list block bottom and the grid top

// Bottom-anchor the grid just above the toolbar, with the word list stacked above
// it; clamp so the list never rides up under the top HUD / game tip.
var _target_bot   = PH_H - global.safe_bottom_gui - 155 - PH_PLAY_BOTTOM_GAP;
var _grid_top_min = 250 + global.safe_top_gui + WL_BLOCK_H + WL_TO_GRID;
grid_y = max(_grid_top_min, _target_bot - grid_h);
WL_Y0  = grid_y - WL_TO_GRID - WL_BLOCK_H;   // top of the list block

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
BONUS_ICON_X = 77;
BONUS_ICON_Y = PH_H - 110 - global.safe_bottom_gui;
BONUS_ICON_R = 60;
// Bonus pill hit box (rect now, not a bare chest circle) — rewritten by Draw.
BONUS_PILL_L = 50;
BONUS_PILL_R = 340;
BONUS_PILL_T = PH_H - 143 - global.safe_bottom_gui;
BONUS_PILL_B = PH_H - 77  - global.safe_bottom_gui;
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
// Restore any hinted letters revealed earlier this day (persisted by ww_apply_hint).
var _hk = "wordwave_hints_" + global.selected_date_key;
if (variable_struct_exists(global.save, _hk)) {
    var _harr = global.save[$ _hk];
    for (var _i = 0; _i < array_length(_harr); _i++) hint_cells[$ _harr[_i]] = true;
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
timer_key        = "wordwave_" + global.selected_date_key;
timer_base_secs  = ph_timer_get(global.save, timer_key);
session_start_ms = current_time;

confetti_pieces          = [];
confetti_burst_pending   = false;
confetti_run_frames      = 0;
CONFETTI_TARGET_FALL     = 70;
CONFETTI_DURATION_FRAMES = 180;

// Win-review re-entry: hub sets global.wordwave_review_mode before navigating.
var _review = variable_global_exists("wordwave_review_mode") && global.wordwave_review_mode;
if (_review) global.wordwave_review_mode = false;
var _already_solved = _review || ph_wordwave_all_solved(puzzle);

// ── Shared win screen (scr_economy §Shared Win Screen) ────────────────────────
// 8×8 result grid with the found-word highlights preserved, fitted into the box.
win_draw_recap = function(_cx, _top, _bw, _bh) {
    var _gap  = 6;
    var _cell = floor((min(_bw, _bh) - (GRID_N-1)*_gap) / GRID_N);
    var _gw   = GRID_N*_cell + (GRID_N-1)*_gap;
    var _ox   = _cx - _gw/2;
    var _oy   = _top + (_bh - _gw)/2;
    var _ctr  = function(_ox0,_oy0,_cm,_gm,_r,_c){ return { x:_ox0+_c*(_cm+_gm)+_cm/2, y:_oy0+_r*(_cm+_gm)+_cm/2 }; };
    var _tsc  = _cell/256;
    for (var _r = 0; _r < GRID_N; _r++) for (var _c = 0; _c < GRID_N; _c++) {
        var _p = _ctr(_ox,_oy,_cell,_gap,_r,_c);
        draw_sprite_ext(global.spr_tile, 0, _p.x, _p.y, _tsc, _tsc, 0, make_color_rgb(234,216,200), 1);
    }
    for (var _wi = 0; _wi < array_length(puzzle.words); _wi++) {
        var _cells = puzzle.words[_wi].cells;
        var _a = _ctr(_ox,_oy,_cell,_gap, _cells[0].r, _cells[0].c);
        var _b = _ctr(_ox,_oy,_cell,_gap, _cells[array_length(_cells)-1].r, _cells[array_length(_cells)-1].c);
        ph_draw_highlight(_a.x, _a.y, _b.x, _b.y, _cell*0.78, word_colors[_wi], 0.45);
    }
    var _mfnt = (_cell >= 56) ? global.fnt_disp_sm : global.fnt_body_md;
    for (var _r = 0; _r < GRID_N; _r++) for (var _c = 0; _c < GRID_N; _c++) {
        var _p  = _ctr(_ox,_oy,_cell,_gap,_r,_c);
        var _fc = ww_cell_found_color(_r, _c);
        var _lc = (_fc != undefined) ? make_color_rgb(58,46,66) : PH_COL_INK_SOFT;
        ph_draw_text(_p.x, _p.y, puzzle.grid[_r][_c], _mfnt, _lc, fa_center, fa_middle);
    }
};
win = ph_win_create({
    puzzle_name: "WORDWAVE",
    title_col:   PH_COL_TEAL_DEEP,
    bg_col:      PH_COL_TEAL,
    claim_key:   "wordwave_" + global.selected_date_key,
    already:     _already_solved,
    share_url:   PH_SHARE_URL,
    time_str:    win_time_str,
    draw_recap:  win_draw_recap,
});

if (_already_solved) {
    var _time_key = "wordwave_time_" + global.selected_date_key;
    win_time_str  = variable_struct_exists(global.save, _time_key) ? global.save[$ _time_key] : "--:--";
    win.cfg.time_str = win_time_str;
    win_phase = 1;
    ph_win_celebrate(win);
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
    var _fin_s  = ph_timer_now(timer_base_secs, session_start_ms);
    var _fin_m  = _fin_s div 60;
    var _fin_ss = _fin_s mod 60;
    win_time_str = string(_fin_m) + ":" + ((_fin_ss < 10) ? "0" : "") + string(_fin_ss);
    global.save[$ "wordwave_time_" + global.selected_date_key] = win_time_str;

    for (var _wi = 0; _wi < array_length(puzzle.words); _wi++) {
        ph_wordwave_mark_word(global.save, global.selected_date_key, _wi);
    }
    ph_wordwave_mark_done(global.save, global.selected_date_key);

    // XP is claimed on the win screen now (ph_win_grant), which also routes any
    // level-up to the Level-Up reward screen (rm_win). Nothing granted here.
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

// ── Hint helpers (used by the shared hint modal) ──────────────────────────────
/// Cells eligible to be hinted: any letter of an unfound hidden word that isn't
/// already ringed and isn't already part of a found word. (A hint reveals ANY one
/// letter of a hidden word — not necessarily its first.) Deduped across crossings.
ww_hint_candidates = function() {
    var _cands = [];
    var _seen  = {};
    for (var _wi = 0; _wi < array_length(puzzle.words); _wi++) {
        if (puzzle.words[_wi].found) continue;
        var _cells = puzzle.words[_wi].cells;
        for (var _k = 0; _k < array_length(_cells); _k++) {
            var _r = _cells[_k].r, _c = _cells[_k].c;
            var _key = string(_r) + "," + string(_c);
            if (variable_struct_exists(_seen, _key))      continue;   // dedupe crossings
            if (variable_struct_exists(hint_cells, _key)) continue;   // already revealed
            if (ww_cell_found_color(_r, _c) != undefined) continue;   // already in a found word
            _seen[$ _key] = true;
            array_push(_cands, { r:_r, c:_c });
        }
    }
    return _cands;
};

/// True if at least one un-revealed letter of a hidden word remains.
ww_can_hint = function() {
    return array_length(ww_hint_candidates()) > 0;
};

/// Ring one random un-revealed letter of a hidden word (persisted so it survives a
/// resume). Returns true on success. Does NOT touch coins.
ww_apply_hint = function() {
    var _cands = ww_hint_candidates();
    if (array_length(_cands) == 0) return false;
    var _pick = _cands[irandom(array_length(_cands) - 1)];
    var _key  = string(_pick.r) + "," + string(_pick.c);
    hint_cells[$ _key] = true;
    cell_flash[_pick.r * GRID_N + _pick.c] = 12;
    // Persist the revealed letter for this date so resume restores it.
    var _hk  = "wordwave_hints_" + global.selected_date_key;
    var _arr = variable_struct_exists(global.save, _hk) ? global.save[$ _hk] : [];
    array_push(_arr, _key);
    global.save[$ _hk] = _arr;
    ph_save_write(global.save);
    return true;
};

// Shared hint-flow controller (modal + placeholder video). Teal accent.
hint = ph_hint_create(ww_apply_hint, PH_COL_TEAL);
