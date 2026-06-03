// ── Shikaku — Create ──────────────────────────────────────────────────────────
puzzle = ph_shikaku_for_date(global.selected_date_key);
N      = puzzle.size;                         // 6

// ── Grid geometry ─────────────────────────────────────────────────────────────
// N×N board centred horizontally, sat below the HUD strip with a comfortable
// gap above the bottom toolbar (Shikaku has no number pad, so it can breathe).
BOARD  = 960;
CELL   = BOARD / N;                           // 160 px per cell
grid_x = floor((PH_W - BOARD) / 2);           // 60
grid_y = 280 + global.safe_top_gui;
grid_h = BOARD;

// ── Player state ──────────────────────────────────────────────────────────────
// player_rects: array of { r, c, w, h } the player has drawn (top-left + size).
player_rects = [];

// Hint reveal flags — one per clue. A shown hint draws a small shape glyph next
// to that number indicating the dimensions/orientation of the correct rectangle.
n_clues    = array_length(puzzle.clues);
hint_shown = array_create(n_clues, false);

// ── Drag-to-draw state ────────────────────────────────────────────────────────
dragging    = false;
drag_sr     = 0;   // start cell row/col
drag_sc     = 0;
drag_cr     = 0;   // current cell row/col
drag_cc     = 0;

// ── Feedback toast ────────────────────────────────────────────────────────────
toast_text  = "";
toast_col   = PH_COL_BLUE;
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
xp_gained        = 0;
coins_bonus      = 0;
win_anim_t       = 0;
win_btn_back_y   = 0;
win_time_str     = "0:00";
session_start_ms = current_time;

// ── Confetti state (mirrors the other puzzles' celebration) ───────────────────
confetti_pieces           = [];
confetti_burst_pending    = false;
confetti_run_frames       = 0;
CONFETTI_TARGET_FALL      = 70;
CONFETTI_DURATION_FRAMES  = 180;

// ── Instance methods ──────────────────────────────────────────────────────────

/// Index of the player rectangle covering cell (r,c), or -1 if none.
sk_rect_at_cell = function(_r, _c) {
    for (var _i = 0; _i < array_length(player_rects); _i++) {
        if (ph_shikaku_rect_has_cell(player_rects[_i], _r, _c)) return _i;
    }
    return -1;
};

/// Persist player rects + which clue hints have been revealed.
sk_save = function() {
    var _idx = [];
    for (var _i = 0; _i < n_clues; _i++) if (hint_shown[_i]) array_push(_idx, _i);
    ph_shikaku_save_state(global.save, global.selected_date_key, player_rects, _idx);
    ph_save_write(global.save);
};

/// Commit a rectangle: remove any existing player rects that overlap it, then
/// add the new one. (r0,c0)=top-left, _w/_h in cells.
sk_commit_rect = function(_r0, _c0, _w, _h) {
    for (var _i = array_length(player_rects) - 1; _i >= 0; _i--) {
        var _p = player_rects[_i];
        var _overlap = !(_c0 + _w <= _p.c || _p.c + _p.w <= _c0
                      || _r0 + _h <= _p.r || _p.r + _p.h <= _r0);
        if (_overlap) array_delete(player_rects, _i, 1);
    }
    array_push(player_rects, { r: _r0, c: _c0, w: _w, h: _h });
    sk_save();
    sk_check_win();
};

/// Win bookkeeping — fires once when the player's rectangles form a valid solve.
sk_check_win = function() {
    if (!ph_shikaku_check_solution(puzzle, player_rects)) return;
    var _fin_s  = floor((current_time - session_start_ms) / 1000);
    var _fin_m  = _fin_s div 60;
    var _fin_ss = _fin_s mod 60;
    win_time_str = string(_fin_m) + ":" + ((_fin_ss < 10) ? "0" : "") + string(_fin_ss);
    global.save[$ "shikaku_time_" + global.selected_date_key] = win_time_str;

    sk_save();
    ph_shikaku_mark_done(global.save, global.selected_date_key);

    // Single +100 XP grant for the whole puzzle. auto_coins=false: level-up
    // coins are deferred to the Level-Up reward screen (rm_win).
    var _lvl_res = ph_grant_xp(global.save, PH_XP_PER_PUZZLE, false);
    xp_gained = PH_XP_PER_PUZZLE;
    if (_lvl_res.levels_gained > 0) {
        global.pending_levelup = { level: _lvl_res.new_level, base_reward: PH_COINS_PER_LEVEL };
    }

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

    dragging               = false;
    win_phase              = 1;
    confetti_burst_pending = true;
};

// ── Hint helpers (used by the shared hint modal) ──────────────────────────────
/// First clue that isn't hinted yet AND isn't already correctly enclosed, or -1.
sk_next_hint_clue = function() {
    for (var _i = 0; _i < n_clues; _i++) {
        if (hint_shown[_i]) continue;
        var _s = puzzle.sol_rects[_i];
        if (ph_shikaku_player_has_rect(player_rects, _s.r, _s.c, _s.w, _s.h)) continue;
        return _i;
    }
    return -1;
};

/// True if a shape-glyph hint is still available.
sk_can_hint = function() {
    return sk_next_hint_clue() >= 0;
};

/// Reveal the shape glyph for the next eligible clue. Returns true on success.
/// Does NOT touch coins.
sk_apply_hint = function() {
    var _target = sk_next_hint_clue();
    if (_target < 0) return false;
    hint_shown[_target] = true;
    sk_save();
    return true;
};

// Shared hint-flow controller (modal + placeholder video). Blue accent.
hint = ph_hint_create(sk_apply_hint, PH_COL_BLUE);

// ── Restore in-progress state (resume) ────────────────────────────────────────
var _saved = ph_shikaku_load_state(global.save, global.selected_date_key);
if (!is_undefined(_saved)) {
    player_rects = _saved.rects;
    for (var _i = 0; _i < array_length(_saved.hints); _i++) {
        var _hi = _saved.hints[_i];
        if (_hi >= 0 && _hi < n_clues) hint_shown[_hi] = true;
    }
}

// ── Enter review/solved mode when re-opening a finished puzzle ─────────────────
var _review = variable_global_exists("shikaku_review_mode") && global.shikaku_review_mode;
if (_review) global.shikaku_review_mode = false;

if (_review || ph_shikaku_is_done(global.save, global.selected_date_key)) {
    // Show the completed solution.
    player_rects = [];
    for (var _i = 0; _i < array_length(puzzle.sol_rects); _i++) {
        var _s = puzzle.sol_rects[_i];
        array_push(player_rects, { r: _s.r, c: _s.c, w: _s.w, h: _s.h });
    }
    var _tk = "shikaku_time_" + global.selected_date_key;
    win_time_str = variable_struct_exists(global.save, _tk) ? global.save[$ _tk] : "--:--";
    xp_gained    = PH_XP_PER_PUZZLE;
    win_phase    = 1;
    win_anim_t   = 1.0;
    confetti_burst_pending = true;
}
