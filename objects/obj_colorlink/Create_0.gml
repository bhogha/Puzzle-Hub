// ── Color Link (Flow Free) — Create ───────────────────────────────────────────
// 9×7 grid (tall). Connect each pair of matching coloured dots with a continuous
// line so the lines never cross and every cell is filled. No loss state. Lime accent.

puzzle  = ph_colorlink_for_date(global.selected_date_key);
ROWS    = puzzle.rows;                  // 9
COLS    = puzzle.cols;                  // 7
NCELLS  = ROWS * COLS;
NFLOWS  = array_length(puzzle.flows);

// ── Board geometry (non-square; FILLS the portrait play area to the top) ──────
// Square cells; CELL is the largest that fits both the available width and the
// vertical band between the top HUD and the bottom toolbar, then centred — so a
// tall rows>cols grid uses the whole screen (mirrors Arrows).
var _avail_top = 240 + global.safe_top_gui;                               // below HUD + game tip
var _avail_bot = PH_H - global.safe_bottom_gui - 155 - PH_PLAY_BOTTOM_GAP; // above toolbar
var _avail_w   = PH_W - 40;                                               // 20px side margins
var _avail_h   = _avail_bot - _avail_top;
CELL    = floor(min(_avail_w / COLS, _avail_h / ROWS));
BOARD_W = COLS * CELL;
BOARD_H = ROWS * CELL;
grid_x  = floor((PH_W - BOARD_W) / 2);
grid_y  = floor(_avail_top + (_avail_h - BOARD_H) / 2);

ACCENT      = PH_COL_LIME;
ACCENT_DEEP = PH_COL_LIME_DEEP;

// Line / dot sizing (relative to cell).
LINE_W = floor(CELL * 0.40);
DOT_R  = floor(CELL * 0.27);

// ── Live state ────────────────────────────────────────────────────────────────
// route[f] = ordered array of cell indices for flow f (empty until drawn).
// cell_owner[i] = flow index owning cell i, or -1.
route       = array_create(NFLOWS);
for (var _f = 0; _f < NFLOWS; _f++) route[_f] = [];
cell_owner  = array_create(NCELLS, -1);
hint_locked = array_create(NFLOWS, false);

dragging   = false;
drag_color = -1;
drag_mx    = 0;
drag_my    = 0;

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

// ── Helpers ───────────────────────────────────────────────────────────────────
cl_idx        = function(_r, _c) { return _r * COLS + _c; };
cl_cell_row   = function(_i) { return _i div COLS; };
cl_cell_col   = function(_i) { return _i mod COLS; };
cl_manhattan  = function(_a, _b) { return abs(_a div COLS - _b div COLS) + abs(_a mod COLS - _b mod COLS); };

/// Cell index under a GUI point, or -1 if off the board.
cl_cell_at = function(_px, _py) {
    if (_px < grid_x || _py < grid_y || _px >= grid_x + BOARD_W || _py >= grid_y + BOARD_H) return -1;
    var _c = clamp(floor((_px - grid_x) / CELL), 0, COLS - 1);
    var _r = clamp(floor((_py - grid_y) / CELL), 0, ROWS - 1);
    return _r * COLS + _c;
};

/// Centre (GUI x,y) of a cell index.
cl_center = function(_i) {
    return {
        x: grid_x + (_i mod COLS) * CELL + CELL/2,
        y: grid_y + (_i div COLS) * CELL + CELL/2,
    };
};

/// Rebuild cell_owner from the routes (after load / hint).
cl_rebuild_owner = function() {
    for (var _i = 0; _i < NCELLS; _i++) cell_owner[_i] = -1;
    for (var _f = 0; _f < NFLOWS; _f++) {
        var _r = route[_f];
        for (var _i = 0; _i < array_length(_r); _i++) cell_owner[_r[_i]] = _f;
    }
};

/// Head (last) cell of the flow currently being drawn.
cl_head = function() {
    var _r = route[drag_color];
    return _r[array_length(_r) - 1];
};

/// Remove `_cell` and everything after it from flow `_g` (clears ownership).
cl_truncate_at = function(_g, _cell) {
    var _r = route[_g];
    var _idx = -1;
    for (var _i = 0; _i < array_length(_r); _i++) if (_r[_i] == _cell) { _idx = _i; break; }
    if (_idx < 0) return;
    for (var _i = array_length(_r) - 1; _i >= _idx; _i--) { cell_owner[_r[_i]] = -1; array_pop(_r); }
};

/// Keep `_cell` but drop everything AFTER it from flow `_g`.
cl_truncate_after = function(_g, _cell) {
    var _r = route[_g];
    var _idx = -1;
    for (var _i = 0; _i < array_length(_r); _i++) if (_r[_i] == _cell) { _idx = _i; break; }
    if (_idx < 0) return;
    for (var _i = array_length(_r) - 1; _i > _idx; _i--) { cell_owner[_r[_i]] = -1; array_pop(_r); }
};

/// Wipe a flow's whole route (clears ownership).
cl_clear_flow = function(_f) {
    var _r = route[_f];
    for (var _i = 0; _i < array_length(_r); _i++) cell_owner[_r[_i]] = -1;
    route[_f] = [];
};

/// True if flow _f connects its two endpoints end-to-end.
cl_flow_connected = function(_f) {
    var _r = route[_f];
    var _len = array_length(_r);
    if (_len < 2) return false;
    var _fl = puzzle.flows[_f];
    var _a = _fl.a.r * COLS + _fl.a.c, _b = _fl.b.r * COLS + _fl.b.c;
    return ((_r[0] == _a && _r[_len-1] == _b) || (_r[0] == _b && _r[_len-1] == _a));
};

/// Attempt to move the active flow head onto orthogonally-adjacent cell `_to`,
/// applying Flow Free rules (backtrack / self-trim / override / endpoint block).
/// Returns true if the head moved.
cl_try_step = function(_to) {
    var _f = drag_color;
    var _r = route[_f];
    var _len = array_length(_r);
    var _head = _r[_len - 1];
    if (cl_manhattan(_head, _to) != 1) return false;          // must be adjacent

    // Backtrack onto the previous cell → retract the head.
    if (_len >= 2 && _r[_len - 2] == _to) {
        cell_owner[_head] = -1;
        array_pop(_r);
        return true;
    }
    // Once the line has reached its opposite endpoint, it can only retract (above),
    // not extend past it — matches Flow Free.
    var _fl  = puzzle.flows[_f];
    var _ea  = _fl.a.r * COLS + _fl.a.c;
    var _eb  = _fl.b.r * COLS + _fl.b.c;
    var _far = (_r[0] == _ea) ? _eb : _ea;
    if (_head == _far) return false;

    if (cell_owner[_to] == _f) return false;                  // would loop on itself

    // Another colour's endpoint blocks the path (can't pass through it).
    var _ec = ph_colorlink_endpoint_color(puzzle, _to div COLS, _to mod COLS);
    if (_ec != -1 && _ec != _f) return false;

    // Drawing over another flow cuts it back — unless that flow is hint-locked.
    var _g = cell_owner[_to];
    if (_g != -1 && _g != _f) {
        if (hint_locked[_g]) return false;
        cl_truncate_at(_g, _to);
    }
    array_push(_r, _to);
    cell_owner[_to] = _f;
    return true;
};

/// One orthogonal step from `_from` toward `_to` (prefer the larger-delta axis).
cl_step_toward = function(_from, _to) {
    var _fr = _from div COLS, _fc = _from mod COLS;
    var _tr = _to div COLS,  _tc = _to mod COLS;
    var _dr = _tr - _fr, _dc = _tc - _fc;
    if (_dr == 0 && _dc == 0) return -1;
    if (abs(_dc) >= abs(_dr)) return _fr * COLS + (_fc + sign(_dc));
    return (_fr + sign(_dr)) * COLS + _fc;
};

/// Indices of flows revealed by a hint (for persistence).
cl_hint_indices = function() {
    var _out = [];
    for (var _f = 0; _f < NFLOWS; _f++) if (hint_locked[_f]) array_push(_out, _f);
    return _out;
};

/// Persist routes + hint flags + finish-time bookkeeping.
cl_save = function() {
    ph_colorlink_save_state(global.save, global.selected_date_key, route, cl_hint_indices());
    ph_save_write(global.save);
};

// ── Hint: unravel the longest still-unsolved line ─────────────────────────────
cl_can_hint = function() {
    var _correct = array_create(NFLOWS);
    for (var _f = 0; _f < NFLOWS; _f++) _correct[_f] = cl_flow_connected(_f);
    return ph_colorlink_longest_unsolved(puzzle, _correct) >= 0;
};

cl_apply_hint = function() {
    var _correct = array_create(NFLOWS);
    for (var _f = 0; _f < NFLOWS; _f++) _correct[_f] = cl_flow_connected(_f);
    var _idx = ph_colorlink_longest_unsolved(puzzle, _correct);
    if (_idx < 0) return false;

    // Clear the target flow, then lay its full solution path — trimming any other
    // (non-locked) flow that occupies one of those cells.
    cl_clear_flow(_idx);
    var _sol = puzzle.flows[_idx].path;
    var _cells = [];
    for (var _i = 0; _i < array_length(_sol); _i++) {
        var _ci = _sol[_i].r * COLS + _sol[_i].c;
        var _g  = cell_owner[_ci];
        if (_g != -1 && _g != _idx && !hint_locked[_g]) cl_truncate_at(_g, _ci);
        array_push(_cells, _ci);
        cell_owner[_ci] = _idx;
    }
    route[_idx]       = _cells;
    hint_locked[_idx] = true;

    cl_save();

    // Reveal the line as a SNAKE drawing from dot A → B (own animation, not the
    // shared iris). The win-check is deferred to the controller (after the snake).
    cl_snake_idx    = _idx;
    cl_snake_active = true;
    var _fr = clamp(10 + array_length(_cells) * 3, 16, 52);   // longer line → longer crawl
    return { iris: false, frames: _fr };
};

// ── Snake-reveal state (the hint draws its own crawl; shared iris disabled) ────
cl_snake_idx    = -1;      // flow index currently being snake-revealed
cl_snake_active = false;

/// Draw a flow's route as a snake crawling in along its arc length (_p = 0..1).
/// A bright head leads; a coloured flash pops at endpoint B as it lands.
cl_draw_snake = function(_cells, _col, _p) {
    var _n = array_length(_cells);
    if (_n == 0) return;
    var _pts = array_create(_n);
    for (var _i = 0; _i < _n; _i++) _pts[_i] = cl_center(_cells[_i]);

    var _total = 0;
    var _seg   = array_create(max(1, _n - 1), 0);
    for (var _i = 1; _i < _n; _i++) {
        var _d = point_distance(_pts[_i-1].x, _pts[_i-1].y, _pts[_i].x, _pts[_i].y);
        _seg[_i-1] = _d; _total += _d;
    }
    var _reveal = _total * ph_ease_in_out(_p);   // travel accelerates then settles

    draw_set_color(_col);
    draw_circle(_pts[0].x, _pts[0].y, LINE_W/2, false);
    var _acc = 0, _hx = _pts[0].x, _hy = _pts[0].y;
    for (var _i = 1; _i < _n; _i++) {
        var _d = _seg[_i-1];
        if (_acc + _d <= _reveal) {
            draw_line_width(_pts[_i-1].x, _pts[_i-1].y, _pts[_i].x, _pts[_i].y, LINE_W);
            draw_circle(_pts[_i].x, _pts[_i].y, LINE_W/2, false);
            _acc += _d; _hx = _pts[_i].x; _hy = _pts[_i].y;
        } else {
            var _frac = (_reveal - _acc) / max(1, _d);
            _hx = lerp(_pts[_i-1].x, _pts[_i].x, _frac);
            _hy = lerp(_pts[_i-1].y, _pts[_i].y, _frac);
            draw_line_width(_pts[_i-1].x, _pts[_i-1].y, _hx, _hy, LINE_W);
            draw_circle(_hx, _hy, LINE_W/2, false);
            break;
        }
    }
    // Bright crawling head.
    draw_set_color(PH_COL_WHITE);
    draw_circle(_hx, _hy, LINE_W * 0.30, false);
    // Landing flash at endpoint B.
    if (_p > 0.82) {
        var _f = (_p - 0.82) / 0.18;
        var _b = _pts[_n-1];
        gpu_set_blendmode(bm_add);
        draw_set_color(_col);
        draw_set_alpha((1 - _f) * 0.80);
        draw_circle(_b.x, _b.y, DOT_R * (1.2 + 1.6 * _f), false);
        draw_set_alpha(1);
        gpu_set_blendmode(bm_normal);
    }
};

// Shared hint-flow controller (modal + placeholder rewarded video). Lime accent.
hint = ph_hint_create(cl_apply_hint, ACCENT, "This hint will solve the\nlongest remaining line", "colorlink_" + global.selected_date_key);

// ── Win bookkeeping ───────────────────────────────────────────────────────────
win_phase        = 0;
coins_bonus      = 0;
win_time_str     = "0:00";
timer_key        = "colorlink_" + global.selected_date_key;
timer_base_secs  = ph_timer_get(global.save, timer_key);
session_start_ms = current_time;

cl_check_win = function() {
    if (!ph_colorlink_is_solved(puzzle, route)) return;
    var _fin_s  = ph_timer_now(timer_base_secs, session_start_ms);
    var _fin_m  = _fin_s div 60;
    var _fin_ss = _fin_s mod 60;
    win_time_str = string(_fin_m) + ":" + ((_fin_ss < 10) ? "0" : "") + string(_fin_ss);
    global.save[$ "colorlink_time_" + global.selected_date_key] = win_time_str;

    ph_colorlink_mark_done(global.save, global.selected_date_key);

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

// Mini result board for the shared win screen (draws the solved flows).
win_draw_recap = function(_cx, _top, _bw, _bh) {
    var _cell = min(_bw / COLS, _bh / ROWS);
    var _rw   = COLS * _cell;
    var _rh   = ROWS * _cell;
    var _ox   = _cx - _rw/2;
    var _oy   = _top + (_bh - _rh)/2;
    draw_set_color(make_color_rgb(236,229,217));
    ph_draw_rounded(_ox, _oy, _ox + _rw, _oy + _rh, 12, make_color_rgb(236,229,217));
    var _lw = _cell * 0.36;
    for (var _f = 0; _f < NFLOWS; _f++) {
        var _col = ph_colorlink_color(puzzle.flows[_f].color);
        var _p   = puzzle.flows[_f].path;
        draw_set_color(_col);
        for (var _i = 0; _i < array_length(_p); _i++) {
            var _x = _ox + _p[_i].c * _cell + _cell/2;
            var _y = _oy + _p[_i].r * _cell + _cell/2;
            draw_circle(_x, _y, _lw/2, false);
            if (_i > 0) {
                var _px = _ox + _p[_i-1].c * _cell + _cell/2;
                var _py = _oy + _p[_i-1].r * _cell + _cell/2;
                draw_line_width(_px, _py, _x, _y, _lw);
            }
        }
        // endpoint dots
        var _fa = puzzle.flows[_f].a, _fb = puzzle.flows[_f].b;
        draw_circle(_ox + _fa.c*_cell + _cell/2, _oy + _fa.r*_cell + _cell/2, _cell*0.30, false);
        draw_circle(_ox + _fb.c*_cell + _cell/2, _oy + _fb.r*_cell + _cell/2, _cell*0.30, false);
    }
};

// Review re-entry: hub sets global.colorlink_review_mode before navigating.
var _review = variable_global_exists("colorlink_review_mode") && global.colorlink_review_mode;
if (_review) global.colorlink_review_mode = false;

// Restore in-progress routes (resume).
var _st = ph_colorlink_load_state(global.save, global.selected_date_key, NFLOWS);
if (_st != undefined) {
    route = _st.routes;
    for (var _i = 0; _i < array_length(_st.hints); _i++) {
        var _h = _st.hints[_i];
        if (_h >= 0 && _h < NFLOWS) hint_locked[_h] = true;
    }
    cl_rebuild_owner();
}

var _already_solved = _review || ph_colorlink_is_done(global.save, global.selected_date_key);

win = ph_win_create({
    puzzle_name: "DOTS",
    title_col:   ACCENT_DEEP,
    bg_col:      ACCENT,
    claim_key:   "colorlink_" + global.selected_date_key,
    already:     _already_solved,
    share_url:   PH_SHARE_URL,
    time_str:    win_time_str,
    draw_recap:  win_draw_recap,
});

if (_already_solved) {
    var _time_key = "colorlink_time_" + global.selected_date_key;
    win_time_str  = variable_struct_exists(global.save, _time_key) ? global.save[$ _time_key] : "--:--";
    win.cfg.time_str = win_time_str;
    win_phase = 1;
    ph_win_celebrate(win);
}

// ── First-play onboarding finger tip (soft, no text) ──────────────────────────
// Press-slides the finger along the SHORTEST unsolved flow's solution path, from
// one coloured dot to its match, teaching the connect-the-dots drag. Loops until
// the player connects their first line, then the tip is marked seen.
coach = ph_coach_create(ACCENT);
if (!ph_tip_seen("COLORLINK") && !_already_solved) {
    var _best = -1, _blen = 1000000;
    for (var _f = 0; _f < NFLOWS; _f++) {
        if (cl_flow_connected(_f)) continue;
        var _pl = array_length(puzzle.flows[_f].path);
        if (_pl >= 2 && _pl < _blen) { _blen = _pl; _best = _f; }
    }
    if (_best >= 0) {
        var _path = puzzle.flows[_best].path;
        var _pts  = [];
        for (var _i = 0; _i < array_length(_path); _i++) {
            var _cc = cl_center(_path[_i].r * COLS + _path[_i].c);
            array_push(_pts, ph_coach_pt(_cc.x, _cc.y));
        }
        if (array_length(_pts) >= 2) ph_coach_set_steps(coach, [ ph_coach_slide(_pts) ]);
    }
}
