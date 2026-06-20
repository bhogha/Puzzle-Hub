// ── Arrows — Draw GUI ─────────────────────────────────────────────────────────

// Win screen drawn by the shared controller (scr_economy §Shared Win Screen).
if (win_phase == 1) {
    win.cfg.time_str = win_time_str;
    ph_win_draw(win);
    exit;
}

// Background — tiled pattern, faded (matches the other puzzles).
draw_set_color(PH_COL_BG);
draw_rectangle(0, 0, PH_W, PH_H, false);
draw_set_alpha(0.5);
ph_draw_dot_bg(make_color_rgb(230,215,205));
draw_set_alpha(1);

var _chip_sh = make_color_rgb(190,170,155);

// ── Top HUD strip: back · ARROWS · coin balance ───────────────────────────────
var _hud_y = 95 + global.safe_top_gui;
draw_sprite_ext(global.spr_back2, 0, 60, _hud_y, 0.36, 0.36, 0, c_white, 1);
ph_draw_text(PH_W/2, _hud_y, "ARROWS", global.fnt_disp_md, ACCENT, fa_center, fa_middle);

var _cp_hud = 1.0;
if (coin_pulse_t < 1) {
    var _p2c = coin_pulse_t;
    _cp_hud = (_p2c < 0.5) ? lerp(1.0, 1.25, _p2c/0.5) : lerp(1.25, 1.0, (_p2c-0.5)/0.5);
}
if (coin_overshoot_t < 1) _cp_hud *= 1 + sin(coin_overshoot_t * pi * 2) * 0.12 * (1 - coin_overshoot_t);
var _cb_r = PH_W - 50;
var _cb_l = _cb_r - 220;
ph_draw_chip(_cb_l, _hud_y-33, _cb_r, _hud_y+33, 33, PH_COL_WHITE, _chip_sh, 6);
var _cb_is = (112/512) * _cp_hud;
draw_sprite_ext(global.spr_gold_coin, 0, _cb_l+23, _hud_y, _cb_is, _cb_is, 0, c_white, 1);
ph_draw_text(_cb_l+74, _hud_y, string(global.save.coins), global.fnt_body_md, PH_COL_DARK, fa_left, fa_middle);
COIN_BAL_X = (_cb_l + _cb_r)/2;
COIN_BAL_Y = _hud_y;

// "-100" spend feedback near the coin pill (shared hint helper).
hint.coin_x = COIN_BAL_X;
hint.coin_y = COIN_BAL_Y;
ph_hint_draw_feedback(hint);

// Game tip — objective hint above the board.
ph_draw_game_tip(grid_y, ph_game_tip("arrows"));

// ── Board: white rounded card + faint dot grid ────────────────────────────────
ph_draw_rounded(grid_x, grid_y, grid_x + BOARD_W, grid_y + BOARD_H, 24, PH_COL_WHITE);
draw_set_color(PH_COL_INK_FAINT);
draw_set_alpha(0.55);
var _dot_r = max(3, CELL * 0.05);
for (var _r = 0; _r < ROWS; _r++) {
    for (var _c = 0; _c < COLS; _c++) {
        draw_circle(grid_x + _c*CELL + CELL/2, grid_y + _r*CELL + CELL/2, _dot_r, false);
    }
}
draw_set_alpha(1);

// ── Arrows (clipped to the board so a launch slides cleanly off the edge) ─────
ph_scissor_gui(grid_x, grid_y, BOARD_W, BOARD_H);

var _block_red = make_color_rgb(232, 72, 60);

for (var _i = 0; _i < NARROWS; _i++) {
    // The bumped arrow is drawn as a snake below (so it follows its path); skip here.
    if (!alive[_i] || _i == launching || _i == bump_idx) continue;

    // Hinted arrows are recoloured GREEN permanently so the safe move is easy to
    // find. A soft static halo behind them makes them read even on a busy board.
    var _ov = -1;
    if (ar_hinted[_i]) {
        _ov = PH_COL_GREEN;
        ar_draw_one(_i, grid_x, grid_y, CELL, RIBBON_W * 1.7, 0, 0, 0.28, PH_COL_GREEN);
    }
    // The blocker flashes red while the blocked arrow glides at it (overrides green).
    if (bump_idx != -1 && _i == blocker_idx) _ov = _block_red;

    ar_draw_one(_i, grid_x, grid_y, CELL, RIBBON_W, 0, 0, 1, _ov);
}

// Launching arrow — 3-phase juice: recoil (wind-up) → accelerate off-board → exit
// flash. `_launch_hs` (head arc-length) is stashed for the unclipped flash below.
var _launch_hs = -1;
if (launching != -1) {
    if (launch_t < LAUNCH_WIND_FRAC) {
        // Anticipation: the arrow recoils into itself, gathering energy before firing.
        var _wp = launch_t / LAUNCH_WIND_FRAC;
        _launch_hs = launch_head_s0 - LAUNCH_COIL*CELL * ph_ease_out(_wp);
    } else {
        // Main action: fire off the board, ACCELERATING the whole way out.
        var _ap = (launch_t - LAUNCH_WIND_FRAC) / (1 - LAUNCH_WIND_FRAC);
        _launch_hs = lerp(launch_head_s0 - LAUNCH_COIL*CELL, launch_head_s1, ph_ease_in_cubic(_ap));
    }
    // Motion smear — thin the ribbon as it speeds up (follow-through energy).
    var _spd = (launch_t < LAUNCH_WIND_FRAC) ? 0 : ph_ease_in_cubic((launch_t - LAUNCH_WIND_FRAC)/(1 - LAUNCH_WIND_FRAC));
    var _lrw = RIBBON_W * (1 - LAUNCH_STRETCH*_spd);
    var _cnt = max(2, ceil(launch_body_len / (CELL * 0.16)));   // dense samples → smooth body
    var _pts = array_create(_cnt + 1);
    for (var _j = 0; _j <= _cnt; _j++) {
        _pts[_j] = ar_path_at(_launch_hs - launch_body_len * (_j / _cnt));   // [0]=head … [cnt]=tail
    }
    draw_set_color(arrow_col[launching]);
    ar_stroke(_pts, _lrw);
    ar_arrowhead(_pts[0].x, _pts[0].y, launch_dir[1], launch_dir[0], CELL);
}

// Blocked arrow — slithers head-first up to its blocker along its own path, then
// eases back, drawn red (the launch-style snake motion, partial + reversible).
if (bump_idx != -1) {
    var _bamt;
    if      (bump_t < 0.45) _bamt = ph_ease_out(bump_t / 0.45);              // glide out
    else if (bump_t < 0.60) _bamt = 1;                                       // hold at blocker
    else                    _bamt = 1 - ph_ease_out((bump_t - 0.60) / 0.40); // ease back
    var _bhs  = bump_head_s0 + bump_reach * _bamt;
    var _bcnt = max(2, ceil(bump_body_len / (CELL * 0.16)));
    var _bpts = array_create(_bcnt + 1);
    for (var _j = 0; _j <= _bcnt; _j++) {
        _bpts[_j] = ar_path_at_on(bump_path, bump_arc, bump_dir, _bhs - bump_body_len * (_j / _bcnt));
    }
    draw_set_color(_block_red);
    ar_stroke(_bpts, RIBBON_W);
    ar_arrowhead(_bpts[0].x, _bpts[0].y, bump_dir[1], bump_dir[0], CELL);
}

ph_scissor_reset();

// Launch exit flash (reaction) — a quick additive glow + bright core punches the
// spot where the tip whooshed off the board edge. Unclipped + on top, fading as the
// arrow clears. Fires the instant the head crosses the edge arc-length.
if (launching != -1 && _launch_hs > launch_edge_s) {
    var _ff = clamp((_launch_hs - launch_edge_s) / (CELL * LAUNCH_FLASH_CELLS), 0, 1);
    var _fa = 1 - _ff;
    gpu_set_blendmode(bm_add);
    draw_set_color(arrow_col[launching]);
    draw_set_alpha(_fa * 0.85);
    draw_circle(launch_exit_x, launch_exit_y, CELL*(0.30 + 0.55*_ff), false);   // coloured glow
    draw_set_color(c_white);
    draw_set_alpha(_fa * 0.60);
    draw_circle(launch_exit_x, launch_exit_y, CELL*(0.12 + 0.30*_ff), false);   // bright core
    draw_set_alpha(1);
    gpu_set_blendmode(bm_normal);
}

// Floating "+5s" penalty label near the blocked tap.
if (float_t > 0) {
    var _fa = min(1, float_t / 18);
    var _fy = float_y - (FLOAT_DUR - float_t) * 1.1;
    draw_set_alpha(_fa);
    ph_draw_text(float_x, _fy, "+" + string(PH_ARROWS_PENALTY_SECS) + "s", global.fnt_body_md, PH_COL_PINK, fa_center, fa_middle);
    draw_set_alpha(1);
}

// ── Bottom toolbar: timer pill (centre) · HINT pill (right) ───────────────────
var _tool_y = PH_H - 110 - global.safe_bottom_gui;

var _e_s  = ph_timer_now(timer_base_secs, session_start_ms);
var _time = string(_e_s div 60) + ":" + (((_e_s mod 60) < 10) ? "0" : "") + string(_e_s mod 60);
var _tp_l = PH_W/2 - 105;
var _tp_r = PH_W/2 + 105;
ph_draw_chip(_tp_l, _tool_y-33, _tp_r, _tool_y+33, 33, PH_COL_WHITE, _chip_sh, 6);
draw_sprite_ext(global.spr_stopwatch, 0, _tp_l+19, _tool_y, 106/512, 106/512, 0, c_white, 1);
ph_draw_text(_tp_l+65, _tool_y, _time, global.fnt_body_md, PH_COL_DARK, fa_left, fa_middle);

HINT_PILL_R = PH_W - 50;
HINT_PILL_L = HINT_PILL_R - 210;
HINT_PILL_T = _tool_y - 33;
HINT_PILL_B = _tool_y + 33;
ph_draw_chip(HINT_PILL_L, HINT_PILL_T, HINT_PILL_R, HINT_PILL_B, 33, PH_COL_WHITE, _chip_sh, 6);
draw_sprite_ext(global.spr_bulb, 0, HINT_PILL_L+12, _tool_y, 101/512, 101/512, 0, c_white, 1);
ph_draw_text(HINT_PILL_L+51, _tool_y, "HINT", global.fnt_body_md, PH_COL_DARK, fa_left, fa_middle);

// ── Message Prompt (shared toast) — just above the game tip ────────────────────
if (toast_timer > 0) ph_draw_toast(toast_text, toast_col, min(1, toast_timer/15), grid_y);

// ── Onboarding finger tip (above the board, below the hint modal) ─────────────
ph_coach_draw(coach);

// ── Hint modal + placeholder rewarded-video (drawn last) ──────────────────────
ph_hint_draw_modal(hint);
ph_hint_draw_video(hint);
