// ── Color Link — Draw GUI ─────────────────────────────────────────────────────

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

// ── Top HUD strip: back · COLOR LINK · coin balance ───────────────────────────
var _hud_y = 95 + global.safe_top_gui;
draw_sprite_ext(global.spr_back2, 0, 60, _hud_y, 0.36, 0.36, 0, c_white, 1);
ph_draw_text(PH_W/2, _hud_y, "COLOR LINK", global.fnt_disp_md, PH_COL_LIME, fa_center, fa_middle);

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

// Game tip — objective hint above the board (shared style).
ph_draw_game_tip(grid_y, ph_game_tip("colorlink"));

// ── Board: flat #f1eae1 base + thin per-cell borders (1px, black @30%) ────────
ph_draw_rounded(grid_x, grid_y, grid_x + BOARD_W, grid_y + BOARD_H, 8, PH_COL_HUE_TILE_BG);
draw_set_color(c_black);
draw_set_alpha(0.3);
for (var _g = 0; _g <= COLS; _g++) {               // column borders
    var _gx = grid_x + _g * CELL;
    draw_line(_gx, grid_y, _gx, grid_y + BOARD_H);
}
for (var _g = 0; _g <= ROWS; _g++) {               // row borders
    var _gy = grid_y + _g * CELL;
    draw_line(grid_x, _gy, grid_x + BOARD_W, _gy);
}
draw_set_alpha(1);

// ── Flows: lines (rounded) then endpoint dots on top ──────────────────────────
for (var _f = 0; _f < NFLOWS; _f++) {
    var _col = ph_colorlink_color(puzzle.flows[_f].color);
    // The just-hinted flow crawls in as a snake while the reveal plays.
    if (_f == cl_snake_idx && ph_hint_revealing(hint)) {
        cl_draw_snake(route[_f], _col, ph_hint_reveal_p(hint));
        continue;
    }
    var _r   = route[_f];
    var _len = array_length(_r);
    draw_set_color(_col);
    for (var _i = 0; _i < _len; _i++) {
        var _p = cl_center(_r[_i]);
        draw_circle(_p.x, _p.y, LINE_W/2, false);            // rounded joints/caps
        if (_i > 0) {
            var _q = cl_center(_r[_i-1]);
            draw_line_width(_q.x, _q.y, _p.x, _p.y, LINE_W);
        }
    }
}

// Endpoint dots (always visible) — drawn over the lines so they read crisply.
for (var _f = 0; _f < NFLOWS; _f++) {
    var _col = ph_colorlink_color(puzzle.flows[_f].color);
    draw_set_color(_col);
    var _a = cl_idx(puzzle.flows[_f].a.r, puzzle.flows[_f].a.c);
    var _b = cl_idx(puzzle.flows[_f].b.r, puzzle.flows[_f].b.c);
    var _pa = cl_center(_a), _pb = cl_center(_b);
    draw_circle(_pa.x, _pa.y, DOT_R, false);
    draw_circle(_pb.x, _pb.y, DOT_R, false);
}

// Active-head highlight while dragging (white ring on the drawing tip).
if (dragging && drag_color >= 0) {
    var _h = cl_center(cl_head());
    draw_set_color(PH_COL_WHITE);
    draw_circle(_h.x, _h.y, LINE_W*0.34, false);
}

// ── Bottom toolbar: timer pill (centre) · HINT pill (right) ───────────────────
var _tool_y = PH_H - 110 - global.safe_bottom_gui;

var _b_e_s  = ph_timer_now(timer_base_secs, session_start_ms);
var _b_time = string(_b_e_s div 60) + ":" + (((_b_e_s mod 60) < 10) ? "0" : "") + string(_b_e_s mod 60);
var _tp_l = PH_W/2 - 105;
var _tp_r = PH_W/2 + 105;
ph_draw_chip(_tp_l, _tool_y-33, _tp_r, _tool_y+33, 33, PH_COL_WHITE, _chip_sh, 6);
draw_sprite_ext(global.spr_stopwatch, 0, _tp_l+19, _tool_y, 106/512, 106/512, 0, c_white, 1);
ph_draw_text(_tp_l+65, _tool_y, _b_time, global.fnt_body_md, PH_COL_DARK, fa_left, fa_middle);

HINT_PILL_R = PH_W - 50;
HINT_PILL_L = HINT_PILL_R - 210;
HINT_PILL_T = _tool_y - 33;
HINT_PILL_B = _tool_y + 33;
ph_hint_pill_nudge(HINT_PILL_L, HINT_PILL_T, HINT_PILL_R, HINT_PILL_B, ACCENT);   // 5s idle reminder
ph_draw_chip(HINT_PILL_L, HINT_PILL_T, HINT_PILL_R, HINT_PILL_B, 33, PH_COL_WHITE, _chip_sh, 6);
draw_sprite_ext(global.spr_bulb, 0, HINT_PILL_L+12, _tool_y, 101/512, 101/512, 0, c_white, 1);
ph_draw_text(HINT_PILL_L+51, _tool_y, "HINT", global.fnt_body_md, PH_COL_DARK, fa_left, fa_middle);

// ── Toast — centred below the board ───────────────────────────────────────────
if (toast_timer > 0) ph_draw_toast(toast_text, toast_col, min(1, toast_timer/15), grid_y);

// ── Post-buy reveal (no-op iris here; the snake draws in the flow loop above) ──
ph_hint_draw_reveal(hint);

// ── Hint modal + placeholder rewarded-video (drawn last, cover everything) ─────
ph_hint_draw_modal(hint);
ph_hint_draw_video(hint);
