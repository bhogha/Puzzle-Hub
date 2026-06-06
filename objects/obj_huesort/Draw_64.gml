// ── Hue Sort — Draw GUI ───────────────────────────────────────────────────────

// Win screen drawn by the shared controller (scr_economy §Shared Win Screen).
if (win_phase == 1) {
    win.cfg.time_str = win_time_str;
    ph_win_draw(win);
    exit;
}

// Background — tiled pattern, faded (matches the other puzzles)
draw_set_color(PH_COL_BG);
draw_rectangle(0, 0, PH_W, PH_H, false);
draw_set_alpha(0.5);
ph_draw_dot_bg(make_color_rgb(230,215,205));
draw_set_alpha(1);

var _chip_sh = make_color_rgb(190,170,155);

// ── Top HUD strip: back · HUE SORT · coin balance ─────────────────────────────
var _hud_y = 95 + global.safe_top_gui;
draw_sprite_ext(global.spr_back2, 0, 60, _hud_y, 0.36, 0.36, 0, c_white, 1);
ph_draw_text(PH_W/2, _hud_y, "HUE SORT", global.fnt_disp_md, ACCENT, fa_center, fa_middle);

// Coin balance pill — top-right (no tap action).
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

// Instruction line above the board.
ph_draw_text(PH_W/2, grid_y - 70, "Swap tiles so the colours blend smoothly",
             global.fnt_body_sm, PH_COL_INK_SOFT, fa_center, fa_middle);

// ── Board background ──────────────────────────────────────────────────────────
ph_draw_chip(grid_x-12, grid_y-12, grid_x+BOARD+12, grid_y+BOARD+12, 24,
             PH_COL_WHITE, _chip_sh, 8);

// ── Tiles ─────────────────────────────────────────────────────────────────────
for (var _r = 0; _r < N; _r++) {
    for (var _c = 0; _c < N; _c++) {
        var _i = _r * N + _c;
        if (dragging && _i == drag_from) {
            // Empty slot where the picked-up tile was.
            var _ex0 = grid_x + _c * CELL + TILE_GAP;
            var _ey0 = grid_y + _r * CELL + TILE_GAP;
            var _ex1 = grid_x + (_c + 1) * CELL - TILE_GAP;
            var _ey1 = grid_y + (_r + 1) * CELL - TILE_GAP;
            ph_draw_rounded(_ex0, _ey0, _ex1, _ey1, 16, make_color_rgb(236,226,219));
            continue;
        }
        hs_draw_tile(_r, _c, tiles[_i], (puzzle.locked[_i] || hint_locked[_i]));
    }
}

// ── Dragged tile — follows the finger, slightly enlarged with a halo ──────────
if (dragging && drag_from >= 0) {
    var _sz  = CELL/2 - TILE_GAP + 10;
    var _col = ph_huesort_col(tiles[drag_from]);
    draw_set_alpha(0.25);
    ph_draw_rounded(drag_mx-_sz-6, drag_my-_sz-2, drag_mx+_sz+6, drag_my+_sz+10, 20, make_color_rgb(20,10,30));
    draw_set_alpha(1);
    ph_draw_rounded(drag_mx-_sz-4, drag_my-_sz-4, drag_mx+_sz+4, drag_my+_sz+4, 20, PH_COL_WHITE);
    ph_draw_rounded(drag_mx-_sz,   drag_my-_sz,   drag_mx+_sz,   drag_my+_sz,   16, _col);
}

// ── Bottom toolbar: timer pill (centre) · HINT pill (right) ───────────────────
var _tool_y = PH_H - 110 - global.safe_bottom_gui;

var _b_e_s  = floor((current_time - session_start_ms) / 1000);
var _b_time = string(_b_e_s div 60) + ":" + (((_b_e_s mod 60) < 10) ? "0" : "") + string(_b_e_s mod 60);
var _tp_l = PH_W/2 - 105;
var _tp_r = PH_W/2 + 105;
ph_draw_chip(_tp_l, _tool_y-33, _tp_r, _tool_y+33, 33, PH_COL_WHITE, _chip_sh, 6);
draw_sprite_ext(global.spr_stopwatch, 0, _tp_l+19, _tool_y, 106/512, 106/512, 0, c_white, 1);
ph_draw_text(_tp_l+65, _tool_y, _b_time, global.fnt_body_md, PH_COL_DARK, fa_left, fa_middle);

// HINT pill — bulb · "HINT"
HINT_PILL_R = PH_W - 50;
HINT_PILL_L = HINT_PILL_R - 210;
HINT_PILL_T = _tool_y - 33;
HINT_PILL_B = _tool_y + 33;
ph_draw_chip(HINT_PILL_L, HINT_PILL_T, HINT_PILL_R, HINT_PILL_B, 33, PH_COL_WHITE, _chip_sh, 6);
draw_sprite_ext(global.spr_bulb, 0, HINT_PILL_L+12, _tool_y, 101/512, 101/512, 0, c_white, 1);
ph_draw_text(HINT_PILL_L+51, _tool_y, "HINT", global.fnt_body_md, PH_COL_DARK, fa_left, fa_middle);

// ── Toast — centred below the board ───────────────────────────────────────────
if (toast_timer > 0) {
    var _toast_y = grid_y + BOARD + 95;
    var _alpha = min(1, toast_timer/15);
    draw_set_alpha(_alpha);
    ph_draw_chip(PH_W/2-360, _toast_y-34, PH_W/2+360, _toast_y+34, 30, toast_col, make_color_rgb(20,20,20), 5);
    ph_draw_text(PH_W/2, _toast_y, toast_text, global.fnt_body_sm, PH_COL_WHITE, fa_center, fa_middle);
    draw_set_alpha(1);
}

// ── Hint modal + placeholder rewarded-video (drawn last, cover everything) ─────
ph_hint_draw_modal(hint);
ph_hint_draw_video(hint);
