// ── Shikaku — Draw GUI ────────────────────────────────────────────────────────

// Win screen drawn by the shared controller (scr_economy §Shared Win Screen);
// it owns the frame when complete. Legacy win_phase==1 block below is superseded.
if (win_phase == 1) {
    win.cfg.time_str = win_time_str;
    ph_win_draw(win);
    exit;
}

// Background — dotted, faded (matches the other puzzles)
draw_set_color(PH_COL_BG);
draw_rectangle(0,0,PH_W,PH_H,false);
draw_set_alpha(0.5);
ph_draw_dot_bg(make_color_rgb(230,215,205));
draw_set_alpha(1);

// Shadow tone shared by white chips
var _chip_sh = make_color_rgb(190,170,155);

// Draw a player/solution rectangle as a rounded ring + soft fill.
// _correct controls the border colour (teal = correct, pink = not yet).
draw_sk_rect = function(_r0, _c0, _w, _h, _border, _fill, _bw) {
    var _x1 = grid_x + _c0 * CELL + 8;
    var _y1 = grid_y + _r0 * CELL + 8;
    var _x2 = grid_x + (_c0 + _w) * CELL - 8;
    var _y2 = grid_y + (_r0 + _h) * CELL - 8;
    // Single rounded-rect primitives (no stacked corner circles → no overlap
    // seams / alpha-doubled corner arcs under the translucent drag preview).
    draw_set_color(_border);
    draw_roundrect_ext(_x1, _y1, _x2, _y2, 22, 22, false);
    draw_set_color(_fill);
    draw_roundrect_ext(_x1+_bw, _y1+_bw, _x2-_bw, _y2-_bw, 18, 18, false);
};

if (win_phase == 0) {

// ── Top HUD strip: back · SHIKAKU · coin balance ──────────────────────────────
var _hud_y = 95 + global.safe_top_gui;
draw_sprite_ext(global.spr_back2, 0, 60, _hud_y, 0.36, 0.36, 0, c_white, 1);
ph_draw_text(PH_W/2, _hud_y, "SHIKAKU", global.fnt_disp_md, PH_COL_BLUE, fa_center, fa_middle);

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

// Game tip — objective hint above the board (shared style).
ph_draw_game_tip(grid_y, ph_game_tip("shikaku"));

// ── Board background ──────────────────────────────────────────────────────────
// Penpot design: a flat cream (#f1eae1) panel with sharp corners and no border.
draw_set_color(PH_COL_BOARD_BG);
draw_rectangle(grid_x-12, grid_y-12, grid_x+BOARD+12, grid_y+BOARD+12, false);

// ── Player rectangles ─────────────────────────────────────────────────────────
// Blue soft fill for all; border signals correctness (teal = valid, pink = not).
for (var _i = 0; _i < array_length(player_rects); _i++) {
    var _p  = player_rects[_i];
    var _ok = ph_shikaku_rect_is_correct(puzzle, _p);
    var _bd = _ok ? PH_COL_TEAL_DEEP : PH_COL_PINK_DEEP;
    var _fl = _ok ? PH_COL_TEAL_SOFT : PH_COL_BLUE_SOFT;
    draw_sk_rect(_p.r, _p.c, _p.w, _p.h, _bd, _fl, 6);
}

// ── Grid lines (light, over fills) ────────────────────────────────────────────
for (var _k = 0; _k <= N; _k++) {
    draw_set_color(make_color_rgb(210,198,205));
    var _gx = grid_x + _k * CELL;
    draw_line_width(_gx, grid_y, _gx, grid_y + BOARD, 2);
    var _gy = grid_y + _k * CELL;
    draw_line_width(grid_x, _gy, grid_x + BOARD, _gy, 2);
}

// ── In-progress drag selection (translucent blue capsule) ─────────────────────
if (dragging) {
    var _dr0 = min(drag_sr, drag_cr);
    var _dc0 = min(drag_sc, drag_cc);
    var _dw  = abs(drag_cc - drag_sc) + 1;
    var _dh  = abs(drag_cr - drag_sr) + 1;
    draw_set_alpha(0.45);
    draw_sk_rect(_dr0, _dc0, _dw, _dh, PH_COL_BLUE_DEEP, PH_COL_BLUE_SOFT, 6);
    draw_set_alpha(1);
}

// ── Clue numbers + hint glyphs ────────────────────────────────────────────────
for (var _i = 0; _i < n_clues; _i++) {
    var _cl  = puzzle.clues[_i];
    var _x0  = grid_x + _cl.c * CELL;
    var _y0  = grid_y + _cl.r * CELL;
    var _ccx = _x0 + CELL/2;
    var _ccy = _y0 + CELL/2;

    // Clue number drawn directly on the cream board (no white backing disc), in
    // black @ 70% to match the Penpot design.
    draw_set_alpha(0.7);
    ph_draw_text(_ccx, _ccy, string(_cl.val), global.fnt_disp_md, c_black, fa_center, fa_middle);
    draw_set_alpha(1);

    // Hint glyph — a small rounded rectangle in the cell's top-right corner whose
    // proportions match the correct rectangle's w×h (orientation cue, kept small).
    if (hint_shown[_i]) {
        var _s   = puzzle.sol_rects[_i];
        var _mx  = max(_s.w, _s.h);
        var _u   = 36 / _mx;            // longest side ≈ 36px (~20% larger)
        var _gw  = _s.w * _u;
        var _gh  = _s.h * _u;
        var _gx  = _x0 + CELL - 38;
        var _gy  = _y0 + 38;
        ph_draw_rounded(_gx-_gw/2-3, _gy-_gh/2-3, _gx+_gw/2+3, _gy+_gh/2+3, 3, PH_COL_BLUE_DEEP);
        ph_draw_rounded(_gx-_gw/2,   _gy-_gh/2,   _gx+_gw/2,   _gy+_gh/2,   2, PH_COL_BLUE_SOFT);
    }
}

// ── Bottom toolbar: timer pill (centre) · HINT pill (right) ───────────────────
var _tool_y = PH_H - 110 - global.safe_bottom_gui;

// Timer pill — centre of the strip (moved down from the top HUD).
var _b_e_s  = ph_timer_now(timer_base_secs, session_start_ms);
var _b_time = string(_b_e_s div 60) + ":" + (((_b_e_s mod 60) < 10) ? "0" : "") + string(_b_e_s mod 60);
var _tp_l = PH_W/2 - 105;
var _tp_r = PH_W/2 + 105;
ph_draw_chip(_tp_l, _tool_y-33, _tp_r, _tool_y+33, 33, PH_COL_WHITE, _chip_sh, 6);
draw_sprite_ext(global.spr_stopwatch, 0, _tp_l+19, _tool_y, 106/512, 106/512, 0, c_white, 1);
ph_draw_text(_tp_l+65, _tool_y, _b_time, global.fnt_body_md, PH_COL_DARK, fa_left, fa_middle);

// HINT pill — bulb · "HINT" (cost chip removed; handled elsewhere)
HINT_PILL_R = PH_W - 50;
HINT_PILL_L = HINT_PILL_R - 210;
HINT_PILL_T = _tool_y - 33;
HINT_PILL_B = _tool_y + 33;
ph_draw_chip(HINT_PILL_L, HINT_PILL_T, HINT_PILL_R, HINT_PILL_B, 33, PH_COL_WHITE, _chip_sh, 6);
draw_sprite_ext(global.spr_bulb, 0, HINT_PILL_L+12, _tool_y, 101/512, 101/512, 0, c_white, 1);
ph_draw_text(HINT_PILL_L+51, _tool_y, "HINT", global.fnt_body_md, PH_COL_DARK, fa_left, fa_middle);

// ── Toast — centred below the board ───────────────────────────────────────────
if (toast_timer > 0) ph_draw_toast(toast_text, toast_col, min(1, toast_timer/15), grid_y);

// ── Hint modal — slide-up bottom sheet (pay coins OR watch a placeholder video).
ph_hint_draw_modal(hint);

} // end if (win_phase == 0)

// ── Win / celebration overlay ─────────────────────────────────────────────────
if (win_phase == 1) {
    var _t = ph_ease_out(win_anim_t);

    draw_set_alpha(_t);
    draw_set_color(PH_COL_TEAL);
    draw_rectangle(0,0,PH_W,PH_H,false);
    draw_set_alpha(1);

    // Mini solved board metrics.
    var _cell_m = 46;
    var _grid_m = _cell_m * N;          // 276px square

    var _card_h = 1300;
    var _card_y = lerp(PH_H, 230, ph_ease_back(min(win_anim_t*1.2,1)));
    ph_draw_chip(60, _card_y, PH_W-60, _card_y+_card_h, 40, PH_COL_WHITE, make_color_rgb(20,150,165), 12);

    var _y = _card_y + 70;

    draw_sprite_ext(global.spr_blinky, 0, PH_W/2, _y+105, 0.30, 0.30, 0, c_white, 1);
    _y += 235;

    ph_draw_text(PH_W/2, _y, "WELL DONE!", global.fnt_disp_xl, PH_COL_BLUE, fa_center, fa_middle);
    _y += 80;

    // ── Mini solved Shikaku board — the completed partition, centred ──────────
    var _mini_x = floor((PH_W - _grid_m) / 2);
    var _mini_y = _y;
    // Soft blue backing.
    ph_draw_chip(_mini_x-12, _mini_y-12, _mini_x+_grid_m+12, _mini_y+_grid_m+12, 16,
                 PH_COL_BLUE_SOFT, make_color_rgb(20,80,190), 4);
    // Solution rectangles (teal rings on white).
    for (var _si = 0; _si < array_length(puzzle.sol_rects); _si++) {
        var _s  = puzzle.sol_rects[_si];
        var _x1 = _mini_x + _s.c * _cell_m + 3;
        var _y1 = _mini_y + _s.r * _cell_m + 3;
        var _x2 = _mini_x + (_s.c + _s.w) * _cell_m - 3;
        var _y2 = _mini_y + (_s.r + _s.h) * _cell_m - 3;
        ph_draw_rounded(_x1, _y1, _x2, _y2, 10, PH_COL_TEAL_DEEP);
        ph_draw_rounded(_x1+3, _y1+3, _x2-3, _y2-3, 8, PH_COL_WHITE);
    }
    // Clue numbers.
    for (var _mi = 0; _mi < n_clues; _mi++) {
        var _cl  = puzzle.clues[_mi];
        var _mcx = _mini_x + _cl.c * _cell_m + _cell_m/2;
        var _mcy = _mini_y + _cl.r * _cell_m + _cell_m/2;
        ph_draw_text(_mcx, _mcy, string(_cl.val), global.fnt_body_sm, PH_COL_DARK, fa_center, fa_middle);
    }
    _y += _grid_m + 45;

    // XP pill
    ph_draw_chip(PH_W/2-180, _y-38, PH_W/2+180, _y+38, 38, PH_COL_TEAL, make_color_rgb(10,140,128), 6);
    ph_draw_text(PH_W/2, _y, "+" + string(xp_gained) + " XP", global.fnt_disp_sm, PH_COL_WHITE, fa_center, fa_middle);
    _y += 100;

    // Level row + XP bar
    var _lvl     = ph_level_from_xp(global.save.xp);
    var _xp_in   = ph_xp_in_level(global.save.xp);
    var _xp_frac = _xp_in / PH_XP_PER_LEVEL;
    draw_sprite_ext(global.spr_star3d, 0, 148, _y, 56/512, 56/512, 0, c_white, 1);
    ph_draw_text(205, _y, "Level " + string(_lvl), global.fnt_body_md, PH_COL_DARK, fa_left, fa_middle);
    ph_draw_text(PH_W-100, _y, string(_xp_in) + " / " + string(PH_XP_PER_LEVEL), global.fnt_body_xs, PH_COL_GRAY, fa_right, fa_middle);
    _y += 35;
    ph_draw_rounded(100, _y, PH_W-100, _y+32, 16, make_color_rgb(220,210,205));
    var _bar_w = floor((PH_W-200) * _xp_frac);
    if (_bar_w > 0) ph_draw_rounded(100, _y, 100+_bar_w, _y+32, 16, PH_COL_BLUE);
    _y += 60;

    // Time + streak chips
    var _streak = variable_struct_exists(global.save, "streak") ? global.save.streak : 1;
    ph_draw_chip(80, _y, 520, _y+70, 35, PH_COL_TEAL_SOFT, make_color_rgb(13,148,136), 5);
    draw_sprite_ext(global.spr_stopwatch, 0, 232, _y+35, 56/512, 56/512, 0, c_white, 1);
    ph_draw_text(296, _y+35, win_time_str, global.fnt_body_md, PH_COL_DARK, fa_left, fa_middle);
    ph_draw_chip(560, _y, 1000, _y+70, 35, PH_COL_PINK_SOFT, make_color_rgb(180,10,100), 5);
    draw_sprite_ext(global.spr_boxing_glove, 0, 700, _y+35, 56/512, 56/512, 0, c_white, 1);
    ph_draw_text(764, _y+35, string(_streak) + " day streak", global.fnt_body_sm, PH_COL_DARK, fa_left, fa_middle);
    _y += 90;

    // Gift banner
    if (coins_bonus > 0) {
        ph_draw_chip(PH_W/2-200, _y, PH_W/2+200, _y+60, 30, PH_COL_GOLD, make_color_rgb(200,140,0), 5);
        ph_draw_text(PH_W/2, _y+30, "GIFT  +" + string(coins_bonus) + " COINS", global.fnt_body_sm, PH_COL_WHITE, fa_center, fa_middle);
        _y += 80;
    }

    // BACK TO HUB button
    ph_draw_chip(80, _y, PH_W-80, _y+90, 28, PH_COL_DARK, make_color_rgb(10,5,20), 6);
    ph_draw_text(PH_W/2, _y+45, "BACK TO HUB", global.fnt_disp_sm, PH_COL_WHITE, fa_center, fa_middle);
    win_btn_back_y = _y;

    // Confetti (drawn on top)
    draw_set_alpha(_t);
    for (var _pi = 0; _pi < array_length(confetti_pieces); _pi++) {
        var _p = confetti_pieces[_pi];
        draw_set_color(_p.col);
        if (_p.shape == 2) {
            draw_circle(_p.x, _p.y, _p.size * 0.45, false);
        } else {
            var _cs = dcos(_p.rot);
            var _sn = dsin(_p.rot);
            if (_p.shape == 0) {
                var _hw = _p.size * 0.5;
                var _hh = _p.size * 0.28;
                var _x1 = _p.x + (-_hw)*_cs - (-_hh)*_sn;
                var _y1 = _p.y + (-_hw)*_sn + (-_hh)*_cs;
                var _x2 = _p.x + ( _hw)*_cs - (-_hh)*_sn;
                var _y2 = _p.y + ( _hw)*_sn + (-_hh)*_cs;
                var _x3 = _p.x + ( _hw)*_cs - ( _hh)*_sn;
                var _y3 = _p.y + ( _hw)*_sn + ( _hh)*_cs;
                var _x4 = _p.x + (-_hw)*_cs - ( _hh)*_sn;
                var _y4 = _p.y + (-_hw)*_sn + ( _hh)*_cs;
                draw_triangle(_x1,_y1, _x2,_y2, _x3,_y3, false);
                draw_triangle(_x1,_y1, _x3,_y3, _x4,_y4, false);
            } else {
                var _rr = _p.size * 0.5;
                draw_triangle(
                    _p.x + cos(degtorad(_p.rot))*_rr,       _p.y + sin(degtorad(_p.rot))*_rr,
                    _p.x + cos(degtorad(_p.rot+120))*_rr,   _p.y + sin(degtorad(_p.rot+120))*_rr,
                    _p.x + cos(degtorad(_p.rot+240))*_rr,   _p.y + sin(degtorad(_p.rot+240))*_rr, false);
            }
        }
    }
    draw_set_alpha(1);
}

// ── Placeholder rewarded-video screen — drawn last so it covers every layer.
ph_hint_draw_video(hint);
