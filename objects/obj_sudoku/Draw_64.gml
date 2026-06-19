// ── Sudoku — Draw GUI ─────────────────────────────────────────────────────────

// Win screen drawn by the shared controller (scr_economy §Shared Win Screen);
// it owns the frame when complete. Legacy win_phase==1 block below is superseded.
if (win_phase == 1) {
    win.cfg.time_str = win_time_str;
    ph_win_draw(win);
    exit;
}

// Background — dotted, faded (matches Anygram)
draw_set_color(PH_COL_BG);
draw_rectangle(0,0,PH_W,PH_H,false);
draw_set_alpha(0.5);
ph_draw_dot_bg(make_color_rgb(230,215,205));
draw_set_alpha(1);

if (win_phase == 0) {

// ── Top HUD strip: back · SUDOKU · coin balance ───────────────────────────────
var _hud_y = 95 + global.safe_top_gui;
draw_sprite_ext(global.spr_back2, 0, 60, _hud_y, 0.36, 0.36, 0, c_white, 1);
ph_draw_text(PH_W/2, _hud_y, "SUDOKU", global.fnt_disp_md, PH_COL_PURPLE, fa_center, fa_middle);

// Coin balance pill — top-right (no tap action).
var _cp_hud = 1.0;
if (coin_pulse_t < 1) {
    var _p2c = coin_pulse_t;
    _cp_hud = (_p2c < 0.5) ? lerp(1.0, 1.25, _p2c/0.5) : lerp(1.25, 1.0, (_p2c-0.5)/0.5);
}
if (coin_overshoot_t < 1) _cp_hud *= 1 + sin(coin_overshoot_t * pi * 2) * 0.12 * (1 - coin_overshoot_t);
var _cb_r = PH_W - 50;
var _cb_l = _cb_r - 220;
ph_draw_chip(_cb_l, _hud_y-33, _cb_r, _hud_y+33, 33, PH_COL_WHITE, make_color_rgb(190,170,155), 6);
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
ph_draw_game_tip(grid_y, ph_game_tip("sudoku"));

// ── Board background ──────────────────────────────────────────────────────────
// Penpot design: flat cream (#f1eae1) board with a thick black rounded border.
var _bd_pad = 12;                 // cells-to-border gap
var _bd_w   = 13;                 // outer border thickness (1290px design → 17px)
var _bd_r   = 38;                 // corner radius (1290px design → 50px)
ph_draw_rounded(grid_x-_bd_pad-_bd_w, grid_y-_bd_pad-_bd_w,
                grid_x+BOARD+_bd_pad+_bd_w, grid_y+BOARD+_bd_pad+_bd_w, _bd_r+_bd_w, c_black);
ph_draw_rounded(grid_x-_bd_pad, grid_y-_bd_pad,
                grid_x+BOARD+_bd_pad, grid_y+BOARD+_bd_pad, _bd_r, PH_COL_BOARD_BG);

// Selection context (row / column / box of the selected cell)
var _sel_r = (sel_idx >= 0) ? sel_idx div 9 : -1;
var _sel_c = (sel_idx >= 0) ? sel_idx mod 9 : -1;

// ── Cells ─────────────────────────────────────────────────────────────────────
for (var _i = 0; _i < 81; _i++) {
    var _r  = _i div 9;
    var _c  = _i mod 9;
    var _x0 = grid_x + _c * CELL;
    var _y0 = grid_y + _r * CELL;
    var _v  = puzzle.grid[_i];

    // Cell fill — flat cream base (design); only highlights are drawn over it.
    var _fill = -1;
    var _peer = (sel_idx >= 0)
                && (_r == _sel_r || _c == _sel_c
                    || (_r div 3 == _sel_r div 3 && _c div 3 == _sel_c div 3));
    if      (cell_flash[_i] > 0)   _fill = merge_color(PH_COL_BOARD_BG, PH_COL_TEAL_SOFT, min(1, cell_flash[_i]/18));
    else if (_i == sel_idx)        _fill = PH_COL_PURPLE_SOFT;
    else if (puzzle.hinted[_i])    _fill = PH_COL_GREEN_SOFT;                        // positive "revealed" cell
    else if (_peer)                _fill = make_color_rgb(235,228,240);

    if (_fill != -1) {
        draw_set_color(_fill);
        draw_rectangle(_x0+1, _y0+1, _x0+CELL-1, _y0+CELL-1, false);
    }

    // Number — a hint-revealed number hides under the closing iris, then pops in.
    if (_v != 0 && _i != sd_hint_reveal_idx) {
        var _col;
        if      (ph_sudoku_cell_conflicts(puzzle, _i)) _col = PH_COL_PINK_DEEP;     // wrong / clashes
        else if (ph_sudoku_is_given(puzzle, _i))        _col = PH_COL_DARK;          // locked clue
        else if (puzzle.hinted[_i])                     _col = PH_COL_GREEN_DEEP;    // revealed by hint (positive)
        else                                            _col = PH_COL_PURPLE;        // player entry
        if (_i == sd_hint_pop_idx && sd_hint_pop_t < 1) {
            var _ps = ph_ease_out_back(sd_hint_pop_t, 2.4);
            draw_set_font(global.fnt_disp_lg);
            draw_set_color(_col);
            draw_set_halign(fa_center); draw_set_valign(fa_middle);
            draw_text_transformed(_x0 + CELL/2, _y0 + CELL/2, string(_v), _ps, _ps, 0);
        } else {
            ph_draw_text(_x0 + CELL/2, _y0 + CELL/2, string(_v), global.fnt_disp_lg, _col, fa_center, fa_middle);
        }
    }
}

// ── Grid lines ────────────────────────────────────────────────────────────────
// Design: only the black 3×3 box dividers are drawn; thin faint lines mark cells.
for (var _k = 0; _k <= 9; _k++) {
    var _bold = (_k mod 3 == 0);
    if (_k == 0 || _k == 9) continue;     // outer edge handled by the board border
    var _lw   = _bold ? 6 : 2;
    draw_set_color(_bold ? c_black : make_color_rgb(214,203,192));
    var _gx = grid_x + _k * CELL;
    draw_line_width(_gx, grid_y, _gx, grid_y + BOARD, _lw);
    var _gy = grid_y + _k * CELL;
    draw_line_width(grid_x, _gy, grid_x + BOARD, _gy, _lw);
}

// ── Number pad (1..9) ─────────────────────────────────────────────────────────
var _pad_sc = NUM_W / 256;
for (var _n = 0; _n < 9; _n++) {
    var _cx = num_x[_n] + NUM_W/2;
    draw_sprite_ext(global.spr_tile, 0, _cx, NUM_Y, _pad_sc, _pad_sc, 0, PH_COL_PURPLE, 1);
    ph_draw_text(_cx, NUM_Y, string(_n + 1), global.fnt_disp_md, PH_COL_WHITE, fa_center, fa_middle);
}

// ── Delete button ─────────────────────────────────────────────────────────────
ph_draw_chip(DEL_L, DEL_Y, DEL_L + DEL_W, DEL_Y + DEL_H, 28,
             PH_COL_WHITE, make_color_rgb(190,170,155), 6);
ph_draw_icon(global.spr_icon_back, DEL_L + 60, DEL_Y + DEL_H/2, 0.45, PH_COL_PURPLE);
ph_draw_text(DEL_L + DEL_W/2 + 26, DEL_Y + DEL_H/2, "DELETE", global.fnt_body_md, PH_COL_DARK, fa_center, fa_middle);

// ── Bottom toolbar: timer pill (centre) · HINT pill (right) ───────────────────
var _tool_y = PH_H - 110 - global.safe_bottom_gui;

// Timer pill — centre of the strip (moved down from the top HUD).
var _b_e_s  = ph_timer_now(timer_base_secs, session_start_ms);
var _b_time = string(_b_e_s div 60) + ":" + (((_b_e_s mod 60) < 10) ? "0" : "") + string(_b_e_s mod 60);
var _tp_l = PH_W/2 - 105;
var _tp_r = PH_W/2 + 105;
ph_draw_chip(_tp_l, _tool_y-33, _tp_r, _tool_y+33, 33, PH_COL_WHITE, make_color_rgb(190,170,155), 6);
draw_sprite_ext(global.spr_stopwatch, 0, _tp_l+19, _tool_y, 106/512, 106/512, 0, c_white, 1);
ph_draw_text(_tp_l+65, _tool_y, _b_time, global.fnt_body_md, PH_COL_DARK, fa_left, fa_middle);

// HINT pill — bulb · "HINT" (cost chip removed; handled elsewhere)
HINT_PILL_R = PH_W - 50;
HINT_PILL_L = HINT_PILL_R - 210;
HINT_PILL_T = _tool_y - 33;
HINT_PILL_B = _tool_y + 33;
ph_hint_pill_nudge(HINT_PILL_L, HINT_PILL_T, HINT_PILL_R, HINT_PILL_B, PH_COL_PURPLE);   // 5s idle reminder
ph_draw_chip(HINT_PILL_L, HINT_PILL_T, HINT_PILL_R, HINT_PILL_B, 33, PH_COL_WHITE, make_color_rgb(190,170,155), 6);
draw_sprite_ext(global.spr_bulb, 0, HINT_PILL_L+12, _tool_y, 101/512, 101/512, 0, c_white, 1);
ph_draw_text(HINT_PILL_L+51, _tool_y, "HINT", global.fnt_body_md, PH_COL_DARK, fa_left, fa_middle);

// ── Message Prompt — above the game tip, just below the HUD (Penpot design) ────
if (toast_timer > 0) ph_draw_toast(toast_text, toast_col, min(1, toast_timer/15), grid_y);

// ── Post-buy reveal (iris contracts onto the revealed number) ─────────────────
ph_hint_draw_reveal(hint);

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

    // Mini solved board metrics (mirrors Anygram's mini crossword recap).
    var _cell_m = 36;
    var _grid_m = _cell_m * 9;          // 324px square

    var _card_h = 1320;
    var _card_y = lerp(PH_H, 220, ph_ease_back(min(win_anim_t*1.2,1)));
    ph_draw_chip(60, _card_y, PH_W-60, _card_y+_card_h, 40, PH_COL_WHITE, make_color_rgb(20,150,165), 12);

    var _y = _card_y + 70;

    draw_sprite_ext(global.spr_blinky, 0, PH_W/2, _y+105, 0.30, 0.30, 0, c_white, 1);
    _y += 235;

    ph_draw_text(PH_W/2, _y, "WELL DONE!", global.fnt_disp_xl, PH_COL_PURPLE, fa_center, fa_middle);
    _y += 80;

    // ── Mini solved Sudoku board — the completed grid, centred on the card ─────
    var _mini_x = floor((PH_W - _grid_m) / 2);
    var _mini_y = _y;
    // Soft purple backing so the recap reads as a finished puzzle.
    ph_draw_chip(_mini_x-12, _mini_y-12, _mini_x+_grid_m+12, _mini_y+_grid_m+12, 16,
                 PH_COL_PURPLE_SOFT, make_color_rgb(150,120,210), 4);
    // Numbers
    for (var _mi = 0; _mi < 81; _mi++) {
        var _mr  = _mi div 9;
        var _mc  = _mi mod 9;
        var _mcx = _mini_x + _mc * _cell_m + _cell_m/2;
        var _mcy = _mini_y + _mr * _cell_m + _cell_m/2;
        var _mcol;
        if      (ph_sudoku_is_given(puzzle, _mi)) _mcol = PH_COL_DARK;
        else if (puzzle.hinted[_mi])              _mcol = PH_COL_GREEN_DEEP;
        else                                      _mcol = PH_COL_PURPLE_DEEP;
        ph_draw_text(_mcx, _mcy, string(puzzle.solution[_mi]), global.fnt_body_sm, _mcol, fa_center, fa_middle);
    }
    // Grid lines (bold every 3rd)
    for (var _mk = 0; _mk <= 9; _mk++) {
        var _mbold = (_mk mod 3 == 0);
        draw_set_color(_mbold ? PH_COL_DARK : make_color_rgb(180,165,205));
        var _mlw = _mbold ? 3 : 1;
        var _mgx = _mini_x + _mk * _cell_m;
        draw_line_width(_mgx, _mini_y, _mgx, _mini_y + _grid_m, _mlw);
        var _mgy = _mini_y + _mk * _cell_m;
        draw_line_width(_mini_x, _mgy, _mini_x + _grid_m, _mgy, _mlw);
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
    if (_bar_w > 0) ph_draw_rounded(100, _y, 100+_bar_w, _y+32, 16, PH_COL_PURPLE);
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
