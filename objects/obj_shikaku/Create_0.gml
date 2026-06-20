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

// Bottom-anchor the board just above the bottom toolbar instead of top-anchoring
// under the HUD (clue glyphs and rects all derive from grid_y at draw time).
var _target_bot = PH_H - global.safe_bottom_gui - 155 - PH_PLAY_BOTTOM_GAP;
grid_y += max(0, _target_bot - (grid_y + grid_h));

// ── Player state ──────────────────────────────────────────────────────────────
// player_rects: array of { r, c, w, h } the player has drawn (top-left + size).
player_rects = [];

// Hint reveal flags — one per clue. A shown hint draws a small shape glyph next
// to that number indicating the dimensions/orientation of the correct rectangle.
n_clues    = array_length(puzzle.clues);
hint_shown = array_create(n_clues, false);

// ── Hint reveal/glyph-pop state (shared iris via ph_hint_draw_reveal) ─────────
// The glyph hides under the closing iris (sk_hint_reveal_idx), then pops in
// (sk_hint_pop_idx/_t) once the reveal lands on the clue cell.
sk_last_hint_idx   = -1;
sk_hint_reveal_idx = -1;
sk_hint_pop_idx    = -1;
sk_hint_pop_t      = 1;     // 0..1 (1 == idle)

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
timer_key        = "shikaku_" + global.selected_date_key;
timer_base_secs  = ph_timer_get(global.save, timer_key);
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
    var _fin_s  = ph_timer_now(timer_base_secs, session_start_ms);
    var _fin_m  = _fin_s div 60;
    var _fin_ss = _fin_s mod 60;
    win_time_str = string(_fin_m) + ":" + ((_fin_ss < 10) ? "0" : "") + string(_fin_ss);
    global.save[$ "shikaku_time_" + global.selected_date_key] = win_time_str;

    sk_save();
    ph_shikaku_mark_done(global.save, global.selected_date_key);

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

    dragging               = false;
    win_phase              = 1;
    win.cfg.time_str = win_time_str;
    ph_win_celebrate(win);
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
    // Aim the iris at the clue cell; the glyph stays hidden until it lands.
    sk_last_hint_idx   = _target;
    sk_hint_reveal_idx = _target;
    var _cl = puzzle.clues[_target];
    return { x: grid_x + _cl.c * CELL + CELL/2, y: grid_y + _cl.r * CELL + CELL/2, r: CELL * 0.62 };
};

// Shared hint-flow controller (modal + placeholder video). Blue accent.
hint = ph_hint_create(sk_apply_hint, PH_COL_BLUE, "This hint will reveal one\ncorrect rectangle", "shikaku_" + global.selected_date_key);

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
var _already_solved = _review || ph_shikaku_is_done(global.save, global.selected_date_key);

// ── Shared win screen (scr_economy §Shared Win Screen) ────────────────────────
// Mini solved Shikaku partition fitted into the recap box.
win_draw_recap = function(_cx, _top, _bw, _bh) {
    var _cell = floor(min(_bw, _bh) / N);
    var _grid = _cell * N;
    var _ox = _cx - _grid/2, _oy = _top + (_bh - _grid)/2;
    ph_draw_chip(_ox-12, _oy-12, _ox+_grid+12, _oy+_grid+12, 16, PH_COL_BLUE_SOFT, make_color_rgb(20,80,190), 4);
    for (var _si = 0; _si < array_length(puzzle.sol_rects); _si++) {
        var _s  = puzzle.sol_rects[_si];
        var _x1 = _ox + _s.c*_cell + 3, _y1 = _oy + _s.r*_cell + 3;
        var _x2 = _ox + (_s.c+_s.w)*_cell - 3, _y2 = _oy + (_s.r+_s.h)*_cell - 3;
        ph_draw_rounded(_x1, _y1, _x2, _y2, 10, PH_COL_TEAL_DEEP);
        ph_draw_rounded(_x1+3, _y1+3, _x2-3, _y2-3, 8, PH_COL_WHITE);
    }
    var _fnt = (_cell >= 44) ? global.fnt_body_md : global.fnt_body_sm;
    for (var _mi = 0; _mi < n_clues; _mi++) {
        var _cl  = puzzle.clues[_mi];
        var _mcx = _ox + _cl.c*_cell + _cell/2, _mcy = _oy + _cl.r*_cell + _cell/2;
        ph_draw_text(_mcx, _mcy, string(_cl.val), _fnt, PH_COL_DARK, fa_center, fa_middle);
    }
};
win = ph_win_create({
    puzzle_name: "SHIKAKU",
    title_col:   PH_COL_BLUE,
    bg_col:      PH_COL_TEAL,
    claim_key:   "shikaku_" + global.selected_date_key,
    already:     _already_solved,
    share_url:   PH_SHARE_URL,
    time_str:    win_time_str,
    draw_recap:  win_draw_recap,
});

if (_already_solved) {
    // Show the completed solution.
    player_rects = [];
    for (var _i = 0; _i < array_length(puzzle.sol_rects); _i++) {
        var _s = puzzle.sol_rects[_i];
        array_push(player_rects, { r: _s.r, c: _s.c, w: _s.w, h: _s.h });
    }
    var _tk = "shikaku_time_" + global.selected_date_key;
    win_time_str = variable_struct_exists(global.save, _tk) ? global.save[$ _tk] : "--:--";
    win.cfg.time_str = win_time_str;
    win_phase = 1;
    ph_win_celebrate(win);
}

// ── First-play onboarding finger tip (soft, no text) ──────────────────────────
// Press-slides the finger corner-to-corner of the LARGEST solution rectangle so a
// new player learns the drag-a-box mechanic. Loops until they draw their first
// rectangle, then the tip is marked seen (a mid-tip quit replays it from step 0).
coach = ph_coach_create(PH_COL_BLUE);
if (!ph_tip_seen("SHIKAKU") && !_already_solved) {
    var _best = -1, _area = 0;
    for (var _i = 0; _i < array_length(puzzle.sol_rects); _i++) {
        var _s = puzzle.sol_rects[_i];
        var _ar = _s.w * _s.h;
        if (_ar > _area) { _area = _ar; _best = _i; }
    }
    if (_best >= 0) {
        var _sr = puzzle.sol_rects[_best];
        var _x1 = grid_x + _sr.c * CELL + CELL/2;
        var _y1 = grid_y + _sr.r * CELL + CELL/2;
        var _x2 = grid_x + (_sr.c + _sr.w - 1) * CELL + CELL/2;
        var _y2 = grid_y + (_sr.r + _sr.h - 1) * CELL + CELL/2;
        ph_coach_set_steps(coach, [ ph_coach_slide([ ph_coach_pt(_x1, _y1), ph_coach_pt(_x2, _y2) ]) ]);
    }
}
