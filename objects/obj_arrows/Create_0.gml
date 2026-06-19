// ── Arrows — Create ───────────────────────────────────────────────────────────
// 8×8 board packed with bent multi-cell arrows. Tap an arrow to launch it in its
// head direction; it flies off iff the lane it sweeps is clear. Blocked tap →
// +5 s time penalty (no loss state). Silver accent. See ARROWS_PLAN.md.

puzzle  = ph_arrows_for_date(global.selected_date_key);
ROWS    = puzzle.rows;                   // 16
COLS    = puzzle.cols;                   // 12
NARROWS = array_length(puzzle.arrows);

// ── Board geometry (non-square white card that FILLS the portrait play area) ──
// Square cells; CELL is the largest that fits both the available width and the
// vertical band between the game-tip and the bottom toolbar. The board is then
// centred in that band, so a tall rows>cols grid uses the whole screen.
var _avail_top = 240 + global.safe_top_gui;                               // below HUD + game tip
var _avail_bot = PH_H - global.safe_bottom_gui - 155 - PH_PLAY_BOTTOM_GAP; // above toolbar
var _avail_w   = PH_W - 40;                                               // 20px side margins
var _avail_h   = _avail_bot - _avail_top;
CELL    = floor(min(_avail_w / COLS, _avail_h / ROWS));
BOARD_W = COLS * CELL;
BOARD_H = ROWS * CELL;
grid_x  = floor((PH_W - BOARD_W) / 2);
grid_y  = floor(_avail_top + (_avail_h - BOARD_H) / 2);

ACCENT      = PH_COL_SILVER;
ACCENT_DEEP = PH_COL_SILVER_DEEP;

RIBBON_W  = floor(CELL * 0.24);         // arrow body thickness (thinner — board is denser now)
AR_CORNER = 0.42;                       // corner-rounding radius as a fraction of a cell

// ── Arrow colour: single ink (mono = must trace paths; harder, like the
// reference game) or per-arrow vibrant palette (reuse Color Link's) ──────────
arrow_col = array_create(NARROWS);
for (var _i = 0; _i < NARROWS; _i++) {
    arrow_col[_i] = PH_ARROWS_MONO ? PH_ARROWS_INK : ph_colorlink_color(puzzle.arrows[_i].color_idx);
}

// ── Live state ────────────────────────────────────────────────────────────────
alive        = array_create(NARROWS, true);  // true = still on the board
penalty_secs = 0;                             // accumulated blocked-tap penalty (record only; folded into timer)

// Launch (snake slide-out) animation — body slithers along a smoothed path.
launching       = -1;     // index of the arrow currently flying off, or -1
launch_t        = 0;      // 0..1 progress
launch_frames   = 16;     // frames for this launch (scales with travel distance)
launch_dir      = [0, 0]; // head [dr,dc]
launch_path     = [];     // smoothed (Catmull-Rom) polyline the body follows
launch_arc      = [];     // cumulative arc-length per launch_path point
launch_body_len = 0;      // snake body length along the path (px)
launch_head_s0  = 0;      // head arc-length at launch start
launch_head_s1  = 1;      // head arc-length when fully off-board
launch_exit_x   = 0;      // board-edge point the tip crosses (exit-flash anchor)
launch_exit_y   = 0;
launch_edge_s   = 0;      // head arc-length when the tip reaches the board edge
// Launch animation tuning — 3-phase juice (recoil wind-up → accelerate off → exit flash):
LAUNCH_WIND_FRAC   = 0.26; // fraction of the launch spent on the recoil wind-up
LAUNCH_COIL        = 0.5;  // recoil distance before firing (cells)
LAUNCH_STRETCH     = 0.22; // ribbon thinning at top speed (motion smear)
LAUNCH_FLASH_CELLS = 1.2;  // distance past the edge the exit flash expands/fades over (cells)

// Blocked-tap feedback: the tapped arrow glides head-first ALONG ITS OWN SNAKE
// PATH (same motion as a launch) up to the arrow that blocks it, then eases back
// to its slot — flashing red with the blocker so the cause is obvious. Pure
// visual — input isn't locked. Path data mirrors the launch_* set.
bump_idx      = -1;        // arrow being bumped, or -1
bump_t        = 0;         // 0..1 (out → hold → back)
bump_frames   = 26;        // total frames (~0.43s @60fps)
bump_dir      = [0, 0];    // head [dr,dc]
blocker_idx   = -1;        // the arrow that blocks it (flashes red alongside)
bump_path     = [];        // smoothed centreline (body + short exit lane to blocker)
bump_arc      = [];        // cumulative arc-length per bump_path point
bump_body_len = 0;         // snake body length along the path (px)
bump_head_s0  = 0;         // head arc-length at rest (= body length)
bump_reach    = 0;         // extra arc-length the head advances toward the blocker

// Floating "+5s" penalty label.
float_t   = 0;
FLOAT_DUR = 50;
float_x   = 0;
float_y   = 0;

// ── Feedback toast ────────────────────────────────────────────────────────────
toast_text  = "";
toast_col   = ACCENT;
toast_timer = 0;
TOAST_DUR   = 90;

coin_pulse_t     = 1.0;
coin_overshoot_t = 1.0;
COIN_BAL_X = PH_W - 160;
COIN_BAL_Y = 95 + global.safe_top_gui;

HINT_PILL_L = PH_W - 260;
HINT_PILL_R = PH_W - 50;
HINT_PILL_T = PH_H - 143 - global.safe_bottom_gui;
HINT_PILL_B = PH_H - 77  - global.safe_bottom_gui;

// Hint highlight: hinted arrows are recoloured GREEN permanently (until played),
// so the player can always find the safe move. One bool per arrow; persisted.
ar_hinted = array_create(NARROWS, false);

// ── Helpers ───────────────────────────────────────────────────────────────────
/// Cell index under a GUI point, or -1 if off the board.
ar_cell_at = function(_px, _py) {
    if (_px < grid_x || _py < grid_y || _px >= grid_x + BOARD_W || _py >= grid_y + BOARD_H) return -1;
    var _c = clamp(floor((_px - grid_x) / CELL), 0, COLS - 1);
    var _r = clamp(floor((_py - grid_y) / CELL), 0, ROWS - 1);
    return _r * COLS + _c;
};

/// Round only the CORNERS of a node polyline: straight segments stay straight,
/// each bend becomes a soft quadratic fillet of radius _r (px). Straight-through
/// (collinear) vertices are left straight, so long runs don't wave.
ar_round = function(_nodes, _r) {
    var _m = array_length(_nodes);
    if (_m < 3) return _nodes;
    var _out = [];
    array_push(_out, _nodes[0]);
    for (var _i = 1; _i < _m - 1; _i++) {
        var _a = _nodes[_i-1], _v = _nodes[_i], _b = _nodes[_i+1];
        var _l1 = point_distance(_a.x, _a.y, _v.x, _v.y);
        var _l2 = point_distance(_v.x, _v.y, _b.x, _b.y);
        if (_l1 == 0 || _l2 == 0) { array_push(_out, _v); continue; }
        var _r1 = min(_r, _l1 * 0.5);
        var _r2 = min(_r, _l2 * 0.5);
        var _ent = { x: _v.x - (_v.x-_a.x)/_l1*_r1, y: _v.y - (_v.y-_a.y)/_l1*_r1 };
        var _ext = { x: _v.x + (_b.x-_v.x)/_l2*_r2, y: _v.y + (_b.y-_v.y)/_l2*_r2 };
        array_push(_out, _ent);
        var _steps = 6;
        for (var _s = 1; _s < _steps; _s++) {
            var _t = _s/_steps, _u = 1-_t;
            array_push(_out, { x: _u*_u*_ent.x + 2*_u*_t*_v.x + _t*_t*_ext.x,
                               y: _u*_u*_ent.y + 2*_u*_t*_v.y + _t*_t*_ext.y });
        }
        array_push(_out, _ext);
    }
    array_push(_out, _nodes[_m-1]);
    return _out;
};

/// Total length of a polyline point list.
ar_pathlen = function(_pts) {
    var _n = array_length(_pts), _len = 0;
    for (var _i = 1; _i < _n; _i++) _len += point_distance(_pts[_i-1].x, _pts[_i-1].y, _pts[_i].x, _pts[_i].y);
    return _len;
};

/// Draw a thick, round-capped/jointed stroke through a dense point list (current colour).
ar_stroke = function(_pts, _w) {
    var _n = array_length(_pts);
    for (var _i = 0; _i < _n; _i++) {
        draw_circle(_pts[_i].x, _pts[_i].y, _w/2, false);
        if (_i > 0) draw_line_width(_pts[_i-1].x, _pts[_i-1].y, _pts[_i].x, _pts[_i].y, _w);
    }
};

/// Tail→head node list for arrow `_i` mapped into a board at (_ox,_oy), cell size
/// _cell, offset (_offx,_offy).
ar_body_nodes = function(_i, _ox, _oy, _cell, _offx, _offy) {
    var _cs = puzzle.arrows[_i].cells;
    var _L  = array_length(_cs);
    var _nodes = array_create(_L);
    for (var _k = 0; _k < _L; _k++) {
        var _src = _cs[_L-1-_k];
        _nodes[_k] = { x: _ox + _src.c*_cell + _cell/2 + _offx,
                       y: _oy + _src.r*_cell + _cell/2 + _offy };
    }
    return _nodes;
};

/// Draw one arrow (smooth curved body + arrowhead) into a board at (_ox,_oy) with
/// cell size _cell and ribbon width _rw, offset by (_offx,_offy), at _alpha.
/// _col_override != -1 forces a colour (used for the hint glow).
ar_draw_one = function(_i, _ox, _oy, _cell, _rw, _offx, _offy, _alpha, _col_override) {
    var _a   = puzzle.arrows[_i];
    var _col = (_col_override == -1) ? arrow_col[_i] : _col_override;
    var _nodes = ar_body_nodes(_i, _ox, _oy, _cell, _offx, _offy);
    draw_set_alpha(_alpha);
    draw_set_color(_col);
    ar_stroke(ar_round(_nodes, _cell * AR_CORNER), _rw);
    // Arrowhead at the head node (cells[0]). ph_arrows_delta is [dr,dc]; screen x
    // uses dc, screen y uses dr.
    var _d  = ph_arrows_delta(_a.head);
    var _hd = _nodes[array_length(_nodes)-1];
    ar_arrowhead(_hd.x, _hd.y, _d[1], _d[0], _cell);
    draw_set_alpha(1);
};

/// Draw a triangular arrowhead at (_hx,_hy) pointing along screen dir (_dx,_dy),
/// sized to _cell. Uses the current draw colour/alpha.
ar_arrowhead = function(_hx, _hy, _dx, _dy, _cell) {
    var _perpx = -_dy, _perpy = _dx;
    var _b    = _cell * 0.40;
    var _back = _cell * 0.06;
    draw_triangle(
        _hx + _dx*_cell*0.50,        _hy + _dy*_cell*0.50,
        _hx - _dx*_back + _perpx*_b, _hy - _dy*_back + _perpy*_b,
        _hx - _dx*_back - _perpx*_b, _hy - _dy*_back - _perpy*_b,
        false);
};

/// Point at arc-length `_s` along an arbitrary snake path (point list + cumulative
/// arc-lengths + head dir); interpolated, extrapolated straight past the end along
/// the head direction. Shared by the launch and the blocked-tap bump.
ar_path_at_on = function(_path, _arc, _dir, _s) {
    var _n = array_length(_path);
    if (_s <= 0) return _path[0];
    var _end = _arc[_n-1];
    if (_s >= _end) {
        var _p = _path[_n-1];
        var _o = _s - _end;
        return { x: _p.x + _dir[1]*_o, y: _p.y + _dir[0]*_o };
    }
    var _i = 0;
    while (_i < _n-1 && _arc[_i+1] < _s) _i++;
    var _seg = _arc[_i+1] - _arc[_i];
    var _f   = (_seg > 0) ? (_s - _arc[_i]) / _seg : 0;
    var _a = _path[_i], _b = _path[_i+1];
    return { x: lerp(_a.x,_b.x,_f), y: lerp(_a.y,_b.y,_f) };
};

/// Point along the active LAUNCH path (wrapper over ar_path_at_on).
ar_path_at = function(_arc) {
    return ar_path_at_on(launch_path, launch_arc, launch_dir, _arc);
};

/// Begin a snake-style launch of arrow `_idx`: build the smoothed path the body
/// follows (its own curved centreline tail→head, then the straight exit lane past
/// the tip, extended off-board) with cumulative arc-length, and size the
/// animation to the travel distance. The body then glides along it head-first.
ar_start_launch = function(_idx) {
    launching = _idx;
    launch_t  = 0;
    var _a  = puzzle.arrows[_idx];
    var _cs = _a.cells;
    var _L  = array_length(_cs);
    var _d  = ph_arrows_delta(_a.head);
    var _dr = _d[0], _dc = _d[1];
    launch_dir = _d;

    var _bn = ar_body_nodes(_idx, grid_x, grid_y, CELL, 0, 0);   // tail … head
    var _hr = _cs[0].r, _hc = _cs[0].c;
    var _dist;                                  // cells for the tip to leave the board
    if      (_dr < 0) _dist = _hr + 1;          // U
    else if (_dr > 0) _dist = ROWS - _hr;       // D
    else if (_dc < 0) _dist = _hc + 1;          // L
    else              _dist = COLS - _hc;       // R

    // Full node polyline = body (tail→head) + straight exit lane past the tip.
    var _nodes = [];
    for (var _i = 0; _i < array_length(_bn); _i++) array_push(_nodes, _bn[_i]);
    for (var _n = 1; _n <= _dist + _L + 2; _n++) {
        array_push(_nodes, { x: grid_x + (_hc + _dc*_n)*CELL + CELL/2,
                             y: grid_y + (_hr + _dr*_n)*CELL + CELL/2 });
    }

    var _r = CELL * AR_CORNER;
    launch_path = ar_round(_nodes, _r);
    var _np = array_length(launch_path);
    launch_arc = array_create(_np, 0);
    for (var _i = 1; _i < _np; _i++) {
        launch_arc[_i] = launch_arc[_i-1] + point_distance(launch_path[_i-1].x, launch_path[_i-1].y, launch_path[_i].x, launch_path[_i].y);
    }
    // Body length = rounded length of the body-only polyline (tail→head). The
    // head node is a straight-through point (body end-dir == lane dir), so this
    // equals the full path's arc-length at the head.
    launch_body_len = ar_pathlen(ar_round(_bn, _r));
    launch_head_s0  = launch_body_len;
    launch_head_s1  = launch_arc[_np-1] + launch_body_len;   // tail reaches the path end
    // A touch longer than before to fit the recoil wind-up without slowing the exit.
    launch_frames   = round(clamp((launch_head_s1 - launch_head_s0)/CELL * 1.6, 18, 34));

    // Exit-edge point (where the tip crosses the board boundary) + the head
    // arc-length at that moment — drives the reaction flash.
    var _edge_dist;
    if      (_dr < 0) { _edge_dist = _hr*CELL + CELL/2;     launch_exit_x = grid_x + _hc*CELL + CELL/2; launch_exit_y = grid_y; }
    else if (_dr > 0) { _edge_dist = (ROWS-_hr-0.5)*CELL;   launch_exit_x = grid_x + _hc*CELL + CELL/2; launch_exit_y = grid_y + BOARD_H; }
    else if (_dc < 0) { _edge_dist = _hc*CELL + CELL/2;     launch_exit_x = grid_x;                     launch_exit_y = grid_y + _hr*CELL + CELL/2; }
    else              { _edge_dist = (COLS-_hc-0.5)*CELL;   launch_exit_x = grid_x + BOARD_W;           launch_exit_y = grid_y + _hr*CELL + CELL/2; }
    launch_edge_s = launch_head_s0 + _edge_dist;
};

/// Begin a BLOCKED-tap bump: build the same head-first snake path as a launch but
/// only as far as the blocker, and arm a there-and-back glide along it. `_gap` =
/// clear cells between the tip and the blocking arrow (0 = adjacent).
ar_start_bump = function(_idx, _gap) {
    var _a  = puzzle.arrows[_idx];
    var _cs = _a.cells;
    var _d  = ph_arrows_delta(_a.head);
    var _dr = _d[0], _dc = _d[1];
    bump_dir = _d;

    var _bn = ar_body_nodes(_idx, grid_x, grid_y, CELL, 0, 0);   // tail … head
    var _hr = _cs[0].r, _hc = _cs[0].c;

    // Body nodes + a short straight exit lane (only as far as the blocker + 1 cell).
    var _reach_cells = max(_gap, 1) + 1;
    var _nodes = [];
    for (var _i = 0; _i < array_length(_bn); _i++) array_push(_nodes, _bn[_i]);
    for (var _n = 1; _n <= _reach_cells; _n++) {
        array_push(_nodes, { x: grid_x + (_hc + _dc*_n)*CELL + CELL/2,
                             y: grid_y + (_hr + _dr*_n)*CELL + CELL/2 });
    }
    var _r = CELL * AR_CORNER;
    bump_path = ar_round(_nodes, _r);
    var _np = array_length(bump_path);
    bump_arc = array_create(_np, 0);
    for (var _i = 1; _i < _np; _i++) {
        bump_arc[_i] = bump_arc[_i-1] + point_distance(bump_path[_i-1].x, bump_path[_i-1].y, bump_path[_i].x, bump_path[_i].y);
    }
    bump_body_len = ar_pathlen(ar_round(_bn, _r));
    bump_head_s0  = bump_body_len;
    bump_reach    = max(_gap, 0.35) * CELL;   // tip advances `gap` cells (tiny nudge if adjacent)
    bump_idx      = _idx;
    bump_t        = 0;
    bump_frames   = round(clamp(18 + _gap * 4, 18, 40));
};

// ── Persistence ───────────────────────────────────────────────────────────────
ar_save = function() {
    ph_arrows_save_state(global.save, global.selected_date_key, alive, penalty_secs, ar_hinted);
    ph_save_write(global.save);
};

// ── Hint: recolour a guaranteed-safe arrow green (permanent until played) ──────
// Pick the longest currently-clear arrow that hasn't already been hinted, so each
// paid hint reveals a NEW safe move and the pill greys out once they're all shown.
ar_hint_pick = function() {
    var _best = -1, _best_len = -1;
    for (var _i = 0; _i < NARROWS; _i++) {
        if (!alive[_i] || ar_hinted[_i]) continue;
        if (ph_arrows_sweep_clear(puzzle, alive, _i)) {
            if (puzzle.arrows[_i].len > _best_len) { _best_len = puzzle.arrows[_i].len; _best = _i; }
        }
    }
    return _best;
};

ar_can_hint = function() {
    return ar_hint_pick() >= 0;
};

ar_apply_hint = function() {
    var _i = ar_hint_pick();
    if (_i < 0) return false;
    ar_hinted[_i] = true;     // stays green until the arrow is cleared
    ar_save();
    return true;
};

hint = ph_hint_create(ar_apply_hint, ACCENT, "This hint will highlight an\narrow that's safe to slide", "arrows_" + global.selected_date_key);

// ── Win bookkeeping ───────────────────────────────────────────────────────────
win_phase        = 0;
coins_bonus      = 0;
win_time_str     = "0:00";
timer_key        = "arrows_" + global.selected_date_key;
timer_base_secs  = ph_timer_get(global.save, timer_key);
session_start_ms = current_time;

ar_check_win = function() {
    if (!ph_arrows_is_solved(alive)) return;
    var _fin_s  = ph_timer_now(timer_base_secs, session_start_ms);
    var _fin_m  = _fin_s div 60;
    var _fin_ss = _fin_s mod 60;
    win_time_str = string(_fin_m) + ":" + ((_fin_ss < 10) ? "0" : "") + string(_fin_ss);
    global.save[$ "arrows_time_" + global.selected_date_key] = win_time_str;

    ph_arrows_mark_done(global.save, global.selected_date_key);

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

// Win recap = the INITIAL full board (all arrows as first presented).
win_draw_recap = function(_cx, _top, _bw, _bh) {
    var _cell = min(_bw / COLS, _bh / ROWS);
    var _w    = COLS * _cell;
    var _h    = ROWS * _cell;
    var _ox   = _cx - _w/2;
    var _oy   = _top + (_bh - _h)/2;
    ph_draw_rounded(_ox, _oy, _ox + _w, _oy + _h, 12, PH_COL_WHITE);
    var _rw = _cell * 0.34;
    for (var _i = 0; _i < NARROWS; _i++) ar_draw_one(_i, _ox, _oy, _cell, _rw, 0, 0, 1, -1);
};

// Review re-entry: hub sets global.arrows_review_mode before navigating.
var _review = variable_global_exists("arrows_review_mode") && global.arrows_review_mode;
if (_review) global.arrows_review_mode = false;

// Restore in-progress state (resume).
var _st = ph_arrows_load_state(global.save, global.selected_date_key, NARROWS);
if (_st != undefined) {
    alive        = _st.alive;
    penalty_secs = _st.penalty;
    if (variable_struct_exists(_st, "hinted")) ar_hinted = _st.hinted;
}

var _already_solved = _review || ph_arrows_is_done(global.save, global.selected_date_key);

win = ph_win_create({
    puzzle_name: "ARROWS",
    title_col:   ACCENT_DEEP,
    bg_col:      ACCENT,
    claim_key:   "arrows_" + global.selected_date_key,
    already:     _already_solved,
    share_url:   PH_SHARE_URL,
    time_str:    win_time_str,
    draw_recap:  win_draw_recap,
});

if (_already_solved) {
    var _time_key = "arrows_time_" + global.selected_date_key;
    win_time_str  = variable_struct_exists(global.save, _time_key) ? global.save[$ _time_key] : "--:--";
    win.cfg.time_str = win_time_str;
    win_phase = 1;
    ph_win_celebrate(win);
}
