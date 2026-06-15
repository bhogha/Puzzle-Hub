// ── Hue Sort — Create ─────────────────────────────────────────────────────────
puzzle = ph_huesort_for_date(global.selected_date_key);
N      = puzzle.size;                         // 5
NCELLS = N * N;

// ── Grid geometry (mirrors Shikaku: centred board below the HUD strip) ────────
BOARD  = 960;
CELL   = BOARD / N;                           // 192 px per cell at N=5
grid_x = floor((PH_W - BOARD) / 2);           // 60
grid_y = 320 + global.safe_top_gui;
TILE_GAP = 7;                                 // inset between tiles

// Bottom-anchor the board just above the bottom toolbar instead of top-anchoring
// under the HUD (tiles derive from grid_y at draw time).
var _target_bot = PH_H - global.safe_bottom_gui - 155 - PH_PLAY_BOTTOM_GAP;
grid_y += max(0, _target_bot - (grid_y + BOARD));

ACCENT      = PH_COL_VIOLET;
ACCENT_DEEP = PH_COL_VIOLET_DEEP;

// ── Live board (array of {r,g,b}); scrambled deterministically for the day ────
tiles = ph_huesort_scramble(puzzle, global.selected_date_key);

// Hint-locked positions — revealed by a hint (already correct → can't be moved).
hint_locked = array_create(NCELLS, false);

// ── Drag-and-drop state ───────────────────────────────────────────────────────
dragging  = false;
drag_from = -1;
drag_mx   = 0;
drag_my   = 0;

// ── Feedback toast ────────────────────────────────────────────────────────────
toast_text  = "";
toast_col   = ACCENT;
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
timer_key        = "huesort_" + global.selected_date_key;
timer_base_secs  = ph_timer_get(global.save, timer_key);
session_start_ms = current_time;

// ── Instance methods ──────────────────────────────────────────────────────────

/// Persist the live board + which positions have been hint-revealed.
hs_save = function() {
    var _idx = [];
    for (var _i = 0; _i < NCELLS; _i++) if (hint_locked[_i]) array_push(_idx, _i);
    ph_huesort_save_state(global.save, global.selected_date_key, tiles, _idx);
    ph_save_write(global.save);
};

/// Win bookkeeping — fires once when the board matches the target gradient.
hs_check_win = function() {
    if (!ph_huesort_is_solved_arr(puzzle, tiles)) return;
    var _fin_s = ph_timer_now(timer_base_secs, session_start_ms);
    win_time_str = string(_fin_s div 60) + ":" + (((_fin_s mod 60) < 10) ? "0" : "") + string(_fin_s mod 60);
    global.save[$ "huesort_time_" + global.selected_date_key] = win_time_str;

    hs_save();
    ph_huesort_mark_done(global.save, global.selected_date_key);

    // XP is claimed on the win screen (ph_win_grant), which also routes any
    // level-up to the Level-Up reward screen. Gift box for the 4th solve of day.
    var _count = ph_solved_count_on(global.save, global.selected_date_key);
    coins_bonus = 0;
    if (_count >= PH_GIFT_PUZZLE_INDEX + 1 && !ph_has_gift_been_claimed(global.save, global.selected_date_key)) {
        ph_claim_gift(global.save, global.selected_date_key);
        ph_grant_coins(global.save, PH_COINS_FOR_4TH);
        coins_bonus = PH_COINS_FOR_4TH;
    }
    ph_update_streak(global.save);
    ph_save_write(global.save);

    dragging         = false;
    win_phase        = 1;
    win.cfg.time_str = win_time_str;
    ph_win_celebrate(win);
};

/// Swap two board positions (no-op if either is locked/equal). Saves + checks win.
hs_swap = function(_a, _b) {
    if (_a == _b) return;
    if (puzzle.locked[_a] || puzzle.locked[_b]) return;
    if (hint_locked[_a] || hint_locked[_b]) return;
    var _t = tiles[_a]; tiles[_a] = tiles[_b]; tiles[_b] = _t;
    hs_save();
    hs_check_win();
};

// ── Hint helpers (used by the shared hint modal) ──────────────────────────────
/// First movable position whose colour is still wrong, or -1.
hs_first_wrong = function() {
    for (var _i = 0; _i < NCELLS; _i++) {
        if (puzzle.locked[_i] || hint_locked[_i]) continue;
        if (!ph_huesort_rgb_eq(tiles[_i], puzzle.target[_i])) return _i;
    }
    return -1;
};

/// True if a tile reveal is still available.
hs_can_hint = function() {
    return hs_first_wrong() >= 0;
};

/// Reveal one tile: bring its correct colour into place and lock it. Returns true
/// on success. Does NOT touch coins (the shared hint flow handles the spend).
hs_apply_hint = function() {
    var _p = hs_first_wrong();
    if (_p < 0) return false;
    // Find the movable position currently holding _p's correct colour.
    var _src = -1;
    for (var _i = 0; _i < NCELLS; _i++) {
        if (_i == _p || puzzle.locked[_i] || hint_locked[_i]) continue;
        if (ph_huesort_rgb_eq(tiles[_i], puzzle.target[_p])) { _src = _i; break; }
    }
    if (_src < 0) return false;            // unresolved (shouldn't happen for a real gradient)
    var _t = tiles[_p]; tiles[_p] = tiles[_src]; tiles[_src] = _t;
    hint_locked[_p] = true;                // now correct + anchored
    hs_save();
    hs_check_win();
    return true;
};

// Shared hint-flow controller (modal + placeholder video). Violet accent.
hint = ph_hint_create(hs_apply_hint, PH_COL_VIOLET, "This hint will place one tile\nin its correct spot", "huesort_" + global.selected_date_key);

/// Draw a single tile (flat swatch, no shadow; solid dark dot if anchored —
/// Penpot redesign: corner radius 10, no drop shadow, locked dot = #484644).
hs_draw_tile = function(_r, _c, _rgb, _anchored) {
    var _x0 = grid_x + _c * CELL + TILE_GAP;
    var _y0 = grid_y + _r * CELL + TILE_GAP;
    var _x1 = grid_x + (_c + 1) * CELL - TILE_GAP;
    var _y1 = grid_y + (_r + 1) * CELL - TILE_GAP;
    ph_draw_rounded(_x0, _y0, _x1, _y1, 10, ph_huesort_col(_rgb));   // fill only
    if (_anchored) {
        var _cx = (_x0 + _x1) / 2, _cy = (_y0 + _y1) / 2;
        draw_set_color(PH_COL_HUE_LOCK);
        draw_circle(_cx, _cy, 19, false);
    }
};

// ── Restore in-progress board (resume) ────────────────────────────────────────
var _saved = ph_huesort_load_state(global.save, global.selected_date_key);
if (!is_undefined(_saved) && array_length(_saved.tiles) == NCELLS) {
    tiles = _saved.tiles;
    for (var _i = 0; _i < array_length(_saved.hints); _i++) {
        var _hi = _saved.hints[_i];
        if (_hi >= 0 && _hi < NCELLS) hint_locked[_hi] = true;
    }
}

// ── Enter review/solved mode when re-opening a finished puzzle ─────────────────
var _review = variable_global_exists("huesort_review_mode") && global.huesort_review_mode;
if (_review) global.huesort_review_mode = false;
var _already_solved = _review || ph_huesort_is_done(global.save, global.selected_date_key);

// ── Shared win screen (scr_economy §Shared Win Screen) ────────────────────────
// Mini solved gradient fitted into the recap box.
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
            ph_draw_rounded(_x1, _y1, _x2, _y2, 8, ph_huesort_col(puzzle.target[_i]));
        }
    }
};
win = ph_win_create({
    puzzle_name: "HUE SORT",
    title_col:   ACCENT,
    bg_col:      ACCENT,
    claim_key:   "huesort_" + global.selected_date_key,
    already:     _already_solved,
    share_url:   PH_SHARE_URL,
    time_str:    win_time_str,
    draw_recap:  win_draw_recap,
});

if (_already_solved) {
    // Show the completed gradient.
    for (var _i = 0; _i < NCELLS; _i++) tiles[_i] = puzzle.target[_i];
    var _tk = "huesort_time_" + global.selected_date_key;
    win_time_str = variable_struct_exists(global.save, _tk) ? global.save[$ _tk] : "--:--";
    win.cfg.time_str = win_time_str;
    win_phase = 1;
    ph_win_celebrate(win);
}
