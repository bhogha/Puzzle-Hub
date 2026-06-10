// ── Word Wave — Draw GUI ──────────────────────────────────────────────────────

// Win screen drawn by the shared controller (scr_economy §Shared Win Screen);
// it owns the frame when complete. Legacy win_phase==1 block below is superseded.
if (win_phase == 1) {
    win.cfg.time_str = win_time_str;
    ph_win_draw(win);
    exit;
}

// Background — dots faded to ~50% (matches the other puzzle screens).
draw_set_color(PH_COL_BG);
draw_rectangle(0,0,PH_W,PH_H,false);
draw_set_alpha(0.5);
ph_draw_dot_bg(make_color_rgb(230,215,205));
draw_set_alpha(1);

/// Local: draw a rounded capsule highlight along a straight line of cells.
var _draw_capsule = function(_inst, _path, _col, _alpha) {
    if (array_length(_path) == 0) return;
    var _w  = _inst.CELL * 0.78;
    var _a  = _inst.ww_cell_center(_path[0].r, _path[0].c);
    var _b  = _inst.ww_cell_center(_path[array_length(_path)-1].r, _path[array_length(_path)-1].c);
    var _sx = _inst.shake_offset_x;
    // Single capsule sprite (clean round caps, no primitive self-overlap).
    ph_draw_highlight(_a.x + _sx, _a.y, _b.x + _sx, _b.y, _w, _col, _alpha);
};

if (win_phase == 0) {

// ── Top HUD strip: back · WORD WAVE · coin balance ────────────────────────────
var _hud_y = 95 + global.safe_top_gui;
draw_sprite_ext(global.spr_back2, 0, 60, _hud_y, 0.36, 0.36, 0, c_white, 1);
ph_draw_text(PH_W/2, _hud_y, "WORD WAVE", global.fnt_disp_md, PH_COL_TEAL, fa_center, fa_middle);

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

// Game tip — objective hint above the words-to-find list (which sits above grid).
ph_draw_game_tip(WL_Y0, ph_game_tip("wordwave"));

// ── Found-word highlights (behind letters) ────────────────────────────────────
for (var _wi = 0; _wi < array_length(puzzle.words); _wi++) {
    // (Found-word highlights are drawn AFTER the tiles below, so they read as a
    //  translucent highlighter swipe over the letters rather than a fill behind.)
}

// ── Grid : tiles → highlighter capsules → letters ─────────────────────────────
// Pass 1 — cream tiles (always full, so the highlight floats over the tile face).
var _base_sc = CELL / 256;   // spr_tile is 256×256, origin centred
for (var _r = 0; _r < GRID_N; _r++) {
    for (var _c = 0; _c < GRID_N; _c++) {
        var _idx = _r * GRID_N + _c;
        var _ctr = ww_cell_center(_r, _c);
        var _sc  = cell_scales[_idx] * _base_sc;
        draw_sprite_ext(global.spr_tile, 0, _ctr.x + shake_offset_x, _ctr.y, _sc, _sc, 0,
                        make_color_rgb(234,216,200), 1);
    }
}

// Pass 2 — highlighter capsules over the tiles (semi-transparent, like a marker).
for (var _wi = 0; _wi < array_length(puzzle.words); _wi++) {
    if (puzzle.words[_wi].found) {
        _draw_capsule(self, puzzle.words[_wi].cells, word_colors[_wi], 0.45);
    }
}
if (array_length(sel_path) >= 2) {
    _draw_capsule(self, sel_path, PH_COL_TEAL, 0.32);
}

// Pass 3 — hint rings + letters (dark-grey so they stay readable through the ink).
for (var _r = 0; _r < GRID_N; _r++) {
    for (var _c = 0; _c < GRID_N; _c++) {
        var _ctr = ww_cell_center(_r, _c);
        var _cx  = _ctr.x + shake_offset_x;
        var _cy  = _ctr.y;
        var _found_col = ww_cell_found_color(_r, _c);

        var _hkey = string(_r) + "," + string(_c);
        var _is_hint = (variable_struct_exists(hint_cells, _hkey) && _found_col == undefined);
        if (_is_hint) {
            // Full filled disc so the hint reads clearly (was a faint thin ring).
            draw_set_color(PH_COL_PURPLE);
            draw_circle(_cx, _cy, CELL*0.44, false);
        }

        // Dark slate-grey letters everywhere — visible over both cream and ink;
        // white on a filled hint disc.
        var _lcol = (_found_col != undefined) ? make_color_rgb(58,46,66)
                  : (_is_hint ? PH_COL_WHITE : PH_COL_DARK);
        ph_draw_text(_cx, _cy, puzzle.grid[_r][_c], global.fnt_disp_md, _lcol, fa_center, fa_middle);
    }
}

// ── "Words to find" list (ABOVE the grid) ─────────────────────────────────────
// Two columns of pill tiles (shared ph_draw_word_tile). Found = solid fill in the
// word's own grid-highlight colour (matches the capsule in the grid) with a white
// strike-through; to-find = tan with faint-ink text.
for (var _wi = 0; _wi < array_length(puzzle.words); _wi++) {
    var _col = _wi mod WL_COLS;
    var _row = _wi div WL_COLS;
    var _cx  = WL_X0 + _col * (WL_TILE_W + WL_GAP_X) + WL_TILE_W/2;
    var _cy  = WL_Y0 + _row * (WL_TILE_H + WL_GAP_Y) + WL_TILE_H/2;
    ph_draw_word_tile(_cx, _cy, WL_TILE_W, WL_TILE_H, WL_RADIUS,
                      puzzle.words[_wi].text, puzzle.words[_wi].found, word_colors[_wi]);
}

// ── Bottom toolbar : bonus · timer · hint ─────────────────────────────────────
var _tool_y = PH_H - 110 - global.safe_bottom_gui;

// Shared bonus pill (white capsule · chest · "BONUS" · count badge). Bounds are
// read by Step_0.gml as BONUS_PILL_{L,R,T,B}; chest centre is the fly target.
var _bonus_count = 0;
for (var _bi = 0; _bi < array_length(puzzle.bonus_found); _bi++) {
    if (puzzle.bonus_found[_bi]) _bonus_count++;
}
var _bp = ph_draw_bonus_pill(50, _tool_y, _bonus_count);
BONUS_PILL_L = _bp.l;  BONUS_PILL_R = _bp.r;
BONUS_PILL_T = _bp.t;  BONUS_PILL_B = _bp.b;
BONUS_ICON_X = _bp.icon_x;  BONUS_ICON_Y = _bp.icon_y;

// Timer pill (centre, moved down from the top HUD)
var _b_e_s  = ph_timer_now(timer_base_secs, session_start_ms);
var _b_time = string(_b_e_s div 60) + ":" + (((_b_e_s mod 60) < 10) ? "0" : "") + string(_b_e_s mod 60);
var _tp_l = PH_W/2 - 105;
var _tp_r = PH_W/2 + 105;
ph_draw_chip(_tp_l, _tool_y - 33, _tp_r, _tool_y + 33, 33,
             PH_COL_WHITE, make_color_rgb(190,170,155), 6);
draw_sprite_ext(global.spr_stopwatch, 0, _tp_l + 19, _tool_y, 106/512, 106/512, 0, c_white, 1);
ph_draw_text(_tp_l + 65, _tool_y, _b_time, global.fnt_body_md, PH_COL_DARK, fa_left, fa_middle);

// Hint pill (right) — bulb · "HINT" (cost chip removed; handled elsewhere)
HINT_PILL_R = PH_W - 50;
HINT_PILL_L = HINT_PILL_R - 210;
HINT_PILL_T = _tool_y - 33;
HINT_PILL_B = _tool_y + 33;
ph_draw_chip(HINT_PILL_L, HINT_PILL_T, HINT_PILL_R, HINT_PILL_B, 33,
             PH_COL_WHITE, make_color_rgb(190,170,155), 6);
draw_sprite_ext(global.spr_bulb, 0, HINT_PILL_L + 12, _tool_y, 101/512, 101/512, 0, c_white, 1);
ph_draw_text(HINT_PILL_L + 51, _tool_y, "HINT", global.fnt_body_md, PH_COL_DARK, fa_left, fa_middle);

// ── Message Prompt (shared toast) — just above the game tip ────────────────────
if (toast_timer > 0) ph_draw_toast(toast_text, toast_col, min(1, toast_timer/15), WL_Y0);

// ── Flying coins ──────────────────────────────────────────────────────────────
if (is_array(global.fly_tiles)) {
    var _coin_fly_s = 56 / 512;
    for (var _fi = 0; _fi < array_length(global.fly_tiles); _fi++) {
        var _ft = global.fly_tiles[_fi];
        var _tp = clamp(_ft.t, 0, 1);
        var _ease = 1 - power(1 - _tp, 3);
        var _fx = lerp(_ft.x, _ft.tx, _ease);
        var _fy = lerp(_ft.y, _ft.ty, _ease);
        var _arc = sin(_tp * pi) * 140;
        var _fa  = (_tp > 0.85) ? (1 - (_tp - 0.85) / 0.15) : 1;
        draw_sprite_ext(global.spr_gold_coin, 0, _fx, _fy - _arc, _coin_fly_s, _coin_fly_s, 0, c_white, _fa);
    }
}

// ── Bonus words modal ─────────────────────────────────────────────────────────
if (bonus_modal_open) {
    draw_set_alpha(0.6); draw_set_color(c_black); draw_rectangle(0,0,PH_W,PH_H,false); draw_set_alpha(1);
    var _px1 = 80; var _py1 = 360; var _px2 = PH_W-80; var _py2 = 1240;
    ph_draw_chip(_px1, _py1, _px2, _py2, 32, PH_COL_WHITE, make_color_rgb(200,180,170), 6);
    ph_draw_text((_px1+_px2)/2, _py1+80, "BONUS WORDS", global.fnt_disp_md, PH_COL_DARK, fa_center, fa_middle);
    draw_set_color(make_color_rgb(220,210,205));
    draw_circle(_px2-70, _py1+70, 40, false);
    ph_draw_text(_px2-70, _py1+70, "X", global.fnt_body_md, PH_COL_DARK, fa_center, fa_middle);
    var _cx_w = _px1 + 50; var _cy_w = _py1 + 200; var _chip_h = 70; var _chip_pad = 24; var _chip_gap = 14;
    for (var _bi = 0; _bi < array_length(puzzle.bonus_pool); _bi++) {
        if (!puzzle.bonus_found[_bi]) continue;
        var _label = puzzle.bonus_pool[_bi];
        var _w2 = string_length(_label) * 22 + _chip_pad * 2;
        if (_cx_w + _w2 > _px2 - 50) { _cx_w = _px1 + 50; _cy_w += _chip_h + _chip_gap; }
        ph_draw_chip(_cx_w, _cy_w, _cx_w + _w2, _cy_w + _chip_h, 30, PH_COL_PURPLE_SOFT, PH_COL_PURPLE_DEEP, 4);
        ph_draw_text(_cx_w + _w2/2, _cy_w + _chip_h/2, _label, global.fnt_body_md, PH_COL_DARK, fa_center, fa_middle);
        _cx_w += _w2 + _chip_gap;
    }
    if (_bonus_count == 0) {
        ph_draw_text((_px1+_px2)/2, (_py1+_py2)/2, "No bonus words yet", global.fnt_body_md, PH_COL_GRAY, fa_center, fa_middle);
    }
}

// ── Hint modal — slide-up bottom sheet (pay coins OR watch a placeholder video).
ph_hint_draw_modal(hint);

} // end if (win_phase == 0)

// ── Win / celebration overlay (result grid CENTRED) ──────────────────────────
if (win_phase == 1) {
    var _t = ph_ease_out(win_anim_t);

    draw_set_alpha(_t); draw_set_color(PH_COL_TEAL); draw_rectangle(0,0,PH_W,PH_H,false); draw_set_alpha(1);

    // Mini-grid sizing — fit the full 8×8 into a fixed box.
    var _gap_m = 6;
    var _box   = 560;
    var _cell_m = floor((_box - (GRID_N-1)*_gap_m) / GRID_N);
    var _grid_w_m = GRID_N * _cell_m + (GRID_N-1) * _gap_m;
    var _grid_h_m = _grid_w_m;

    // Card sized to content, vertically centred so the grid sits in the middle.
    var _card_h = 1000 + _grid_h_m;
    var _card_y = lerp(PH_H, max(120, (PH_H - _card_h)/2), ph_ease_back(min(win_anim_t*1.2,1)));
    ph_draw_chip(60, _card_y, PH_W-60, _card_y+_card_h, 40, PH_COL_WHITE, make_color_rgb(20,150,165), 12);

    var _y = _card_y + 80;
    draw_sprite_ext(global.spr_blinky, 0, PH_W/2, _y+133, 0.38, 0.38, 0, c_white, 1);
    _y += 290;
    ph_draw_text(PH_W/2, _y, "WELL DONE!", global.fnt_disp_xl, PH_COL_TEAL_DEEP, fa_center, fa_middle);
    _y += 80;

    // ── Centred result grid with the found-word highlights preserved ──────────
    var _mini_x = floor((PH_W - _grid_w_m) / 2);
    var _mini_y = _y;
    var _mini_center = function(_mx0, _my0, _cm, _gm, _r, _c) {
        return { x: _mx0 + _c*(_cm+_gm) + _cm/2, y: _my0 + _r*(_cm+_gm) + _cm/2 };
    };
    // Cream tiles first (so the highlight reads as ink over the tile face).
    var _mtile_sc = _cell_m / 256;
    for (var _r = 0; _r < GRID_N; _r++) {
        for (var _c = 0; _c < GRID_N; _c++) {
            var _ctr = _mini_center(_mini_x, _mini_y, _cell_m, _gap_m, _r, _c);
            draw_sprite_ext(global.spr_tile, 0, _ctr.x, _ctr.y, _mtile_sc, _mtile_sc, 0,
                            make_color_rgb(234,216,200), 1);
        }
    }
    // Highlighter capsules (semi-transparent, matching the live board).
    for (var _wi = 0; _wi < array_length(puzzle.words); _wi++) {
        var _cells = puzzle.words[_wi].cells;
        var _a = _mini_center(_mini_x, _mini_y, _cell_m, _gap_m, _cells[0].r, _cells[0].c);
        var _b = _mini_center(_mini_x, _mini_y, _cell_m, _gap_m, _cells[array_length(_cells)-1].r, _cells[array_length(_cells)-1].c);
        ph_draw_highlight(_a.x, _a.y, _b.x, _b.y, _cell_m*0.78, word_colors[_wi], 0.45);
    }
    // Letters on top — dark slate-grey so they stay readable through the ink.
    var _mfnt = (_cell_m >= 56) ? global.fnt_disp_sm : global.fnt_body_md;
    for (var _r = 0; _r < GRID_N; _r++) {
        for (var _c = 0; _c < GRID_N; _c++) {
            var _ctr = _mini_center(_mini_x, _mini_y, _cell_m, _gap_m, _r, _c);
            var _fc  = ww_cell_found_color(_r, _c);
            var _lc  = (_fc != undefined) ? make_color_rgb(58,46,66) : PH_COL_INK_SOFT;
            ph_draw_text(_ctr.x, _ctr.y, puzzle.grid[_r][_c], _mfnt, _lc, fa_center, fa_middle);
        }
    }
    _y += _grid_h_m + 60;

    // +XP pill
    ph_draw_chip(PH_W/2-180, _y-38, PH_W/2+180, _y+38, 38, PH_COL_TEAL, make_color_rgb(10,140,128), 6);
    ph_draw_text(PH_W/2, _y, "+" + string(xp_gained) + " XP", global.fnt_disp_sm, PH_COL_WHITE, fa_center, fa_middle);
    _y += 80;

    // Level row + progress bar
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
    _y += 55;

    // Stat chips
    var _streak = variable_struct_exists(global.save, "streak") ? global.save.streak : 1;
    ph_draw_chip(80, _y, 520, _y+70, 35, PH_COL_TEAL_SOFT, make_color_rgb(13,148,136), 5);
    draw_sprite_ext(global.spr_stopwatch, 0, 232, _y+35, 56/512, 56/512, 0, c_white, 1);
    ph_draw_text(296, _y+35, win_time_str, global.fnt_body_md, PH_COL_DARK, fa_left, fa_middle);
    ph_draw_chip(560, _y, 1000, _y+70, 35, PH_COL_PINK_SOFT, make_color_rgb(180,10,100), 5);
    draw_sprite_ext(global.spr_boxing_glove, 0, 700, _y+35, 56/512, 56/512, 0, c_white, 1);
    ph_draw_text(764, _y+35, string(_streak) + " day streak", global.fnt_body_sm, PH_COL_DARK, fa_left, fa_middle);
    _y += 90;

    if (coins_bonus > 0) {
        ph_draw_chip(PH_W/2-200, _y, PH_W/2+200, _y+60, 30, PH_COL_GOLD, make_color_rgb(200,140,0), 5);
        ph_draw_text(PH_W/2, _y+30, "GIFT  +" + string(coins_bonus) + " COINS", global.fnt_body_sm, PH_COL_WHITE, fa_center, fa_middle);
        _y += 80;
    }

    ph_draw_chip(80, _y, PH_W-80, _y+90, 28, PH_COL_DARK, make_color_rgb(10,5,20), 6);
    ph_draw_text(PH_W/2, _y+45, "BACK TO HUB", global.fnt_disp_sm, PH_COL_WHITE, fa_center, fa_middle);
    win_btn_back_y = _y;

    // Confetti (top layer)
    draw_set_alpha(_t);
    for (var _pi = 0; _pi < array_length(confetti_pieces); _pi++) {
        var _p = confetti_pieces[_pi];
        draw_set_color(_p.col);
        if (_p.shape == 2) {
            draw_circle(_p.x, _p.y, _p.size * 0.45, false);
        } else {
            var _cs = dcos(_p.rot); var _sn = dsin(_p.rot);
            if (_p.shape == 0) {
                var _hw = _p.size*0.5; var _hh = _p.size*0.28;
                var _x1=_p.x+(-_hw)*_cs-(-_hh)*_sn; var _y1=_p.y+(-_hw)*_sn+(-_hh)*_cs;
                var _x2=_p.x+( _hw)*_cs-(-_hh)*_sn; var _y2=_p.y+( _hw)*_sn+(-_hh)*_cs;
                var _x3=_p.x+( _hw)*_cs-( _hh)*_sn; var _y3=_p.y+( _hw)*_sn+( _hh)*_cs;
                var _x4=_p.x+(-_hw)*_cs-( _hh)*_sn; var _y4=_p.y+(-_hw)*_sn+( _hh)*_cs;
                draw_triangle(_x1,_y1,_x2,_y2,_x3,_y3,false);
                draw_triangle(_x1,_y1,_x3,_y3,_x4,_y4,false);
            } else {
                var _rr = _p.size*0.5;
                var _tx1=_p.x+cos(degtorad(_p.rot))*_rr;     var _ty1=_p.y+sin(degtorad(_p.rot))*_rr;
                var _tx2=_p.x+cos(degtorad(_p.rot+120))*_rr; var _ty2=_p.y+sin(degtorad(_p.rot+120))*_rr;
                var _tx3=_p.x+cos(degtorad(_p.rot+240))*_rr; var _ty3=_p.y+sin(degtorad(_p.rot+240))*_rr;
                draw_triangle(_tx1,_ty1,_tx2,_ty2,_tx3,_ty3,false);
            }
        }
    }
    draw_set_alpha(1);
}

// ── Placeholder rewarded-video screen — drawn last so it covers every layer.
ph_hint_draw_video(hint);
