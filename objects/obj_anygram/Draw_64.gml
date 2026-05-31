// ── Anygram — Draw GUI ────────────────────────────────────────────────────────

// Background — dots faded to ~50% per design ref
draw_set_color(PH_COL_BG);
draw_rectangle(0,0,PH_W,PH_H,false);
draw_set_alpha(0.5);
ph_draw_dot_bg(make_color_rgb(230,215,205));
draw_set_alpha(1);

// ── Game screen (hidden while win overlay is active) ──────────────────────────
if (win_phase == 0) {

// ── Top bar (HUD strip) ──────────────────────────────────────────────────────
// Layout across the bar: back arrow · ANYGRAM title (centred) · timer (right).
// _hud_y is offset by safe_top_gui so the bar clears the Dynamic Island /
// status bar on all devices. The base offset (95) gives a small visual gap
// between the safe area boundary and the pill top edge.
var _hud_y = 95 + global.safe_top_gui;

ph_draw_icon(global.spr_icon_back, 65, _hud_y, 0.6, PH_COL_DARK);
ph_draw_text(PH_W/2, _hud_y, "ANYGRAM", global.fnt_disp_md, PH_COL_PINK, fa_center, fa_middle);

// Live timer pill — right side of the HUD
var _hud_e_s   = floor((current_time - session_start_ms) / 1000);
var _hud_e_m   = _hud_e_s div 60;
var _hud_e_ss  = _hud_e_s mod 60;
var _hud_time  = string(_hud_e_m) + ":" + ((_hud_e_ss < 10) ? "0" : "") + string(_hud_e_ss);
var _t_pill_r  = PH_W - 50;
var _t_pill_l  = _t_pill_r - 210;
ph_draw_chip(_t_pill_l, _hud_y-32, _t_pill_r, _hud_y+32, 32,
             PH_COL_WHITE, make_color_rgb(190,170,155), 5);
draw_sprite_ext(global.spr_stopwatch, 0, _t_pill_l+44, _hud_y, 52/512, 52/512, 0, c_white, 1);
ph_draw_text(_t_pill_l+80, _hud_y, _hud_time, global.fnt_body_md, PH_COL_DARK, fa_left, fa_middle);

// (Coin balance pill lives in the bottom toolbar — see further down.)

// ── Crossword grid ────────────────────────────────────────────────────────────
var _base_sc = CELL / 256;   // tile_empty.png is 256×256, origin centred
for (var _i = 0; _i < array_length(puzzle.cells); _i++) {
    var _c   = puzzle.cells[_i];
    var _cx  = grid_x + (_c.c - grid_min_c)*(CELL+GAP) + CELL/2;
    var _cy  = grid_y + (_c.r - grid_min_r)*(CELL+GAP) + CELL/2;
    var _sc  = tile_scales[_i] * _base_sc;

    // Tint: yellow=shared filled, light-pink=hint, pink=filled, cream=empty.
    // (Empty cells — shared or not — are uniform cream per design ref.)
    var _tint;
    if      (_c.shared && _c.filled)  _tint = PH_COL_YELLOW;
    else if (_c.hint)                 _tint = make_color_rgb(255,180,220);   // light pink
    else if (_c.filled)               _tint = PH_COL_PINK;
    else                              _tint = make_color_rgb(234,216,200);   // warm cream

    draw_sprite_ext(global.spr_tile, 0, _cx, _cy, _sc, _sc, 0, _tint, 1);

    if (_c.filled || _c.hint) {
        var _letter_col;
        if (_c.shared && _c.filled)  _letter_col = PH_COL_DARK;
        else if (_c.hint)            _letter_col = PH_COL_DARK;
        else                         _letter_col = PH_COL_WHITE;
        ph_draw_text(_cx, _cy, _c.letter, global.fnt_disp_lg, _letter_col, fa_center, fa_middle);
    }
}

// (Bonus-word slots row removed — found bonus words live only in the
//  toolbar chest icon's modal now.)

// ── Wheel (with shake offset on invalid swipe) ────────────────────────────────
var _wcx = WHEEL_CX + shake_offset_x;
// Disc background
ph_draw_chip(_wcx-WHEEL_R, WHEEL_CY-WHEEL_R,
             _wcx+WHEEL_R, WHEEL_CY+WHEEL_R,
             WHEEL_R, PH_COL_YELLOW_SOFT, make_color_rgb(200,175,120), 10);

// Dashed ring (24 segments alternating)
draw_set_color(PH_COL_YELLOW);
for (var _si = 0; _si < 24; _si++) {
    if (_si mod 2 == 0) continue;
    var _a1     = degtorad(_si*15 - 90);
    var _a2     = degtorad((_si+1)*15 - 90);
    var _ring_r = WHEEL_R - 20;
    draw_primitive_begin(pr_trianglefan);
    draw_vertex(_wcx + cos(_a1)*(_ring_r-8), WHEEL_CY + sin(_a1)*(_ring_r-8));
    draw_vertex(_wcx + cos(_a1)*_ring_r,     WHEEL_CY + sin(_a1)*_ring_r);
    draw_vertex(_wcx + cos(_a2)*_ring_r,     WHEEL_CY + sin(_a2)*_ring_r);
    draw_vertex(_wcx + cos(_a2)*(_ring_r-8), WHEEL_CY + sin(_a2)*(_ring_r-8));
    draw_primitive_end();
}

// Trail lines + dots — bold pink stroke so the path visually unites with the
// pink letter tiles it passes through. Lighter pink inner core gives the line
// a chip-rope feel. Width is 2× the previous teal trail (was 18/8 → now 36/16).
if (array_length(trail) > 0) {
    for (var _ti = 0; _ti < array_length(trail)-1; _ti++) {
        var _wp1 = wheel_positions[trail[_ti]];
        var _wp2 = wheel_positions[trail[_ti+1]];
        draw_set_color(PH_COL_PINK);
        draw_line_width(_wp1.x + shake_offset_x, _wp1.y,
                        _wp2.x + shake_offset_x, _wp2.y, 36);
        draw_set_color(merge_color(PH_COL_PINK, PH_COL_WHITE, 0.45));
        draw_line_width(_wp1.x + shake_offset_x, _wp1.y,
                        _wp2.x + shake_offset_x, _wp2.y, 16);
    }
    // Trail nodes – matching pink ring + lighter centre, scaled to suit the
    // wider stroke so the joints don't look pinched between segments.
    for (var _ti = 0; _ti < array_length(trail); _ti++) {
        var _wp = wheel_positions[trail[_ti]];
        draw_set_color(PH_COL_PINK);
        draw_circle(_wp.x + shake_offset_x, _wp.y, 22, false);
        draw_set_color(merge_color(PH_COL_PINK, PH_COL_WHITE, 0.45));
        draw_circle(_wp.x + shake_offset_x, _wp.y, 14, false);
    }
}

// Letter tiles — pink-filled with white letters by default (matches design ref).
// Selected (in-trail) state pops with a soft glow ring + deeper pink + slight scale-up.
var _tile_sc = 160 / 256;
for (var _i = 0; _i < array_length(puzzle.letters); _i++) {
    var _wp       = wheel_positions[_i];
    var _in_trail = false;
    for (var _ti = 0; _ti < array_length(trail); _ti++) {
        if (trail[_ti] == _i) { _in_trail = true; break; }
    }
    if (_in_trail) {
        // Soft white glow halo behind the selected tile
        draw_set_alpha(0.35);
        draw_set_color(PH_COL_WHITE);
        draw_circle(_wp.x + shake_offset_x, _wp.y, 78, false);
        draw_set_alpha(1);
    }
    var _tint    = _in_trail ? PH_COL_PINK_DEEP : PH_COL_PINK;
    var _sel_scl = _in_trail ? 1.08 : 1.0;
    draw_sprite_ext(global.spr_tile, 0, _wp.x + shake_offset_x, _wp.y,
                    _tile_sc * _sel_scl, _tile_sc * _sel_scl, 0, _tint, 1);
    ph_draw_text(_wp.x + shake_offset_x, _wp.y, puzzle.letters[_i], global.fnt_disp_md,
                 PH_COL_WHITE, fa_center, fa_middle);
}

// Shuffle centre button
ph_draw_chip(_wcx-44,WHEEL_CY-44, _wcx+44,WHEEL_CY+44, 44,
             PH_COL_WHITE, make_color_rgb(190,170,155), 6);
ph_draw_icon(global.spr_icon_shuffle, _wcx, WHEEL_CY, 0.5, PH_COL_GRAY);

// Word preview pill — centred vertically between the bottom of the crossword
// grid and the top of the wheel disc. Same y is reused by the feedback toast
// below so the swipe-end transition stays in place.
var _pill_y = floor((grid_y + grid_h + WHEEL_CY - WHEEL_R) / 2);
if (array_length(trail) >= 1) {
    ph_draw_chip(PH_W/2-200,_pill_y-34, PH_W/2+200,_pill_y+34, 34,
                 PH_COL_DARK, make_color_rgb(10,5,20), 6);
    ph_draw_text(PH_W/2, _pill_y, trail_word, global.fnt_disp_md, PH_COL_WHITE, fa_center, fa_middle);
}

// (Live timer now lives in the top HUD strip — see GDD §7.)

// ── Bottom toolbar ────────────────────────────────────────────────────────────
// Layout: chest (left) · coin balance pill (centre) · HINT pill (right).
var _tool_y = PH_H - 110 - global.safe_bottom_gui;

// Left — bonus-words icon (chest sprite) + count badge; tappable to open modal.
// Drawn larger than the previous design so it reads as a hero icon (still a
// touch smaller than a pink wheel tile, per design ref).
var _bonus_count = 0;
for (var _bi = 0; _bi < array_length(puzzle.bonus_found); _bi++) {
    if (puzzle.bonus_found[_bi]) _bonus_count++;
}
var _chest_s = 140 / 512;
draw_sprite_ext(global.spr_chest, 0, BONUS_ICON_X, _tool_y - 10, _chest_s, _chest_s, 0,
                _bonus_count > 0 ? c_white : make_color_rgb(190,180,180), 1);
// Badge (only visible if at least one bonus found) — pushed up/right so it
// clears the now-larger chest sprite.
if (_bonus_count > 0) {
    draw_set_color(PH_COL_PINK);
    draw_circle(BONUS_ICON_X + 58, _tool_y - 66, 24, false);
    ph_draw_text(BONUS_ICON_X + 58, _tool_y - 66, string(_bonus_count),
                 global.fnt_body_xs, PH_COL_WHITE, fa_center, fa_middle);
}

// Centre — coin balance pill (moved from the top HUD per design ref). Keeps
// the original pulse/overshoot animation so coin-fly arrivals still feel alive.
var _cp_hud = 1.0;
if (coin_pulse_t < 1) {
    var _p2 = coin_pulse_t;
    if (_p2 < 0.5) _cp_hud = lerp(1.0, 1.25, _p2 / 0.5);
    else           _cp_hud = lerp(1.25, 1.0, (_p2 - 0.5) / 0.5);
}
if (coin_overshoot_t < 1) {
    _cp_hud *= 1 + sin(coin_overshoot_t * pi * 2) * 0.12 * (1 - coin_overshoot_t);
}
// Coin pill shifted slightly left of true centre so it doesn't bump into the
// wider HINT pill on the right.
var _cb_pill_w = 220;
var _cb_pill_cx = PH_W/2 - 80;
var _cb_pill_l  = _cb_pill_cx - _cb_pill_w/2;
var _cb_pill_r  = _cb_pill_cx + _cb_pill_w/2;
ph_draw_chip(_cb_pill_l, _tool_y - 38, _cb_pill_r, _tool_y + 38, 38,
             PH_COL_WHITE, make_color_rgb(190,170,155), 6);
var _cb_icon_s = (88 / 512) * _cp_hud;
draw_sprite_ext(global.spr_gold_coin, 0, _cb_pill_l + 44, _tool_y, _cb_icon_s, _cb_icon_s, 0, c_white, 1);
ph_draw_text(_cb_pill_l + 92, _tool_y, string(global.save.coins),
             global.fnt_body_md, PH_COL_DARK, fa_left, fa_middle);

// Expose the coin pill centre as the coin-fly target so the reward arc lands here.
COIN_BAL_X = (_cb_pill_l + _cb_pill_r) / 2;
COIN_BAL_Y = _tool_y;

// Right — HINT pill: bulb · "HINT" · cost-chip [coin · 100].
// Tap target lives in Step_0.gml as HINT_PILL_{L,R,T,B}; keep them in sync.
// Pill is 400 wide so the HINT label has room without bumping into the cost chip.
HINT_PILL_R = PH_W - 50;
HINT_PILL_L = HINT_PILL_R - 400;
HINT_PILL_T = _tool_y - 45;
HINT_PILL_B = _tool_y + 45;
ph_draw_chip(HINT_PILL_L, HINT_PILL_T, HINT_PILL_R, HINT_PILL_B, 45,
             PH_COL_WHITE, make_color_rgb(190,170,155), 6);
var _bulb_s = 78 / 512;
draw_sprite_ext(global.spr_bulb, 0, HINT_PILL_L + 50, _tool_y, _bulb_s, _bulb_s, 0, c_white, 1);
ph_draw_text(HINT_PILL_L + 110, _tool_y, "HINT",
             global.fnt_body_md, PH_COL_DARK, fa_left, fa_middle);
// Cost chip on the right end of the pill. Coin icon goes on the LEFT, number
// right-aligned to the chip's right edge — no overlap.
var _cost_w = 130;
var _cost_l = HINT_PILL_R - 22 - _cost_w;
var _cost_r = HINT_PILL_R - 22;
ph_draw_chip(_cost_l, _tool_y - 32, _cost_r, _tool_y + 32, 32,
             PH_COL_PINK_SOFT, PH_COL_PINK_DEEP, 4);
draw_sprite_ext(global.spr_gold_coin, 0, _cost_l + 28, _tool_y, 56/512, 56/512, 0, c_white, 1);
ph_draw_text(_cost_r - 18, _tool_y, string(PH_HINT_COST),
             global.fnt_body_md, PH_COL_DARK, fa_right, fa_middle);

// ── Toast — drawn at the same y as the word-preview pill so the FOUND/NOT-A-
//           WORD message replaces the live swipe pill seamlessly. Pill is sized
//           to fit the longest authored toast ("BONUS +10 COINS · {WORD}"). ──
if (toast_timer > 0) {
    var _alpha = min(1, toast_timer/15);
    draw_set_alpha(_alpha);
    ph_draw_chip(PH_W/2-380,_pill_y-34, PH_W/2+380,_pill_y+34, 30,
                 toast_col, make_color_rgb(20,20,20), 5);
    ph_draw_text(PH_W/2, _pill_y, toast_text, global.fnt_body_sm, PH_COL_WHITE, fa_center, fa_middle);
    draw_set_alpha(1);
}

// ── Flying tiles (letters for main/bonus, coin for the reward arc) ────────────
if (is_array(global.fly_tiles)) {
    var _coin_fly_s = 56 / 512;
    var _ltile_sc   = 80 / 256;   // smaller than wheel tiles
    for (var _fi = 0; _fi < array_length(global.fly_tiles); _fi++) {
        var _ft = global.fly_tiles[_fi];
        if (_ft.t < 0) continue;   // still in stagger delay
        var _tp = clamp(_ft.t, 0, 1);
        var _ease = 1 - power(1 - _tp, 3);
        var _fx = lerp(_ft.x, _ft.tx, _ease);
        var _fy = lerp(_ft.y, _ft.ty, _ease);
        var _fa = (_tp > 0.85) ? (1 - (_tp - 0.85) / 0.15) : 1;

        if (_ft.kind == "coin") {
            // Parabolic arc with an apex above the straight path
            var _arc = sin(_tp * pi) * 140;
            draw_sprite_ext(global.spr_gold_coin, 0, _fx, _fy - _arc,
                            _coin_fly_s, _coin_fly_s, 0, c_white, _fa);
        } else {
            // Letter tile (white tile + letter). Per GDD §8:
            //   main → settles at 85% of source size; bonus → 40%.
            var _target_scale = (_ft.kind == "bonus") ? 0.4 : 0.85;
            var _scl = lerp(1, _target_scale, _ease) * _ltile_sc;
            var _tint = (_ft.kind == "bonus") ? PH_COL_PURPLE : PH_COL_PINK;
            draw_sprite_ext(global.spr_tile, 0, _fx, _fy, _scl, _scl, 0, _tint, _fa);
            ph_draw_text(_fx, _fy, _ft.letter, global.fnt_disp_md,
                         PH_COL_WHITE, fa_center, fa_middle);
        }
    }
}

// ── Bonus words modal ─────────────────────────────────────────────────────────
if (bonus_modal_open) {
    // Dim
    draw_set_alpha(0.6);
    draw_set_color(c_black);
    draw_rectangle(0, 0, PH_W, PH_H, false);
    draw_set_alpha(1);

    // Panel
    var _px1 = 80;  var _py1 = 360;
    var _px2 = PH_W-80; var _py2 = 1240;
    ph_draw_chip(_px1, _py1, _px2, _py2, 32, PH_COL_WHITE, make_color_rgb(200,180,170), 6);

    // Header
    ph_draw_text((_px1+_px2)/2, _py1+80, "BONUS WORDS",
                 global.fnt_disp_md, PH_COL_DARK, fa_center, fa_middle);

    // Close X
    draw_set_color(make_color_rgb(220,210,205));
    draw_circle(_px2-70, _py1+70, 40, false);
    ph_draw_text(_px2-70, _py1+70, "X", global.fnt_body_md, PH_COL_DARK, fa_center, fa_middle);

    // Chips (only show found)
    var _cx_w = _px1 + 50;
    var _cy_w = _py1 + 200;
    var _chip_h  = 70;
    var _chip_pad = 24;
    var _chip_gap = 14;
    for (var _bi = 0; _bi < array_length(puzzle.bonus); _bi++) {
        if (!puzzle.bonus_found[_bi]) continue;
        var _label = string_upper(puzzle.bonus[_bi]);
        // Width estimate: char count × ~22 px + padding
        var _w = string_length(_label) * 22 + _chip_pad * 2;
        if (_cx_w + _w > _px2 - 50) {
            _cx_w = _px1 + 50;
            _cy_w += _chip_h + _chip_gap;
        }
        ph_draw_chip(_cx_w, _cy_w, _cx_w + _w, _cy_w + _chip_h, 30,
                     PH_COL_TEAL_SOFT, PH_COL_TEAL_DEEP, 4);
        ph_draw_text(_cx_w + _w/2, _cy_w + _chip_h/2, _label,
                     global.fnt_body_md, PH_COL_DARK, fa_center, fa_middle);
        _cx_w += _w + _chip_gap;
    }

    // Empty-state message if nothing yet
    if (_bonus_count == 0) {
        ph_draw_text((_px1+_px2)/2, (_py1+_py2)/2, "No bonus words yet",
                     global.fnt_body_md, PH_COL_GRAY, fa_center, fa_middle);
    }
}

} // end if (win_phase == 0)

// ── Win / celebration overlay ─────────────────────────────────────────────────
if (win_phase == 1) {
    var _t = ph_ease_out(win_anim_t);

    // Teal full-screen backdrop — fully opaque so no game elements show through
    draw_set_alpha(_t);
    draw_set_color(PH_COL_TEAL);
    draw_rectangle(0,0,PH_W,PH_H,false);
    draw_set_alpha(1);

    // (Star burst decorations removed — celebration is now driven by the
    //  particle confetti system that runs every time the screen is shown.)

    // ── Mini crossword sizing ─────────────────────────────────────────────────
    // Recompute the grid bounding box from the live cells (max row/col aren't
    // cached on the instance). The mini grid scales to fit a fixed box so any
    // puzzle shape — square, wide, tall — settles into the same visual slot.
    var _max_r = grid_min_r;
    var _max_c = grid_min_c;
    for (var _gi = 0; _gi < array_length(puzzle.cells); _gi++) {
        var _gc = puzzle.cells[_gi];
        if (_gc.r > _max_r) _max_r = _gc.r;
        if (_gc.c > _max_c) _max_c = _gc.c;
    }
    var _rows_m = _max_r - grid_min_r + 1;
    var _cols_m = _max_c - grid_min_c + 1;
    var _gap_m  = 8;
    var _box_w  = 380;
    var _box_h  = 320;
    var _cell_m = floor(min((_box_w - (_cols_m-1)*_gap_m) / _cols_m,
                            (_box_h - (_rows_m-1)*_gap_m) / _rows_m));
    _cell_m = clamp(_cell_m, 28, 80);
    var _grid_w_m = _cols_m * _cell_m + (_cols_m - 1) * _gap_m;
    var _grid_h_m = _rows_m * _cell_m + (_rows_m - 1) * _gap_m;

    // Card height grows with the mini crossword so the back-to-hub button
    // always keeps a comfortable bottom margin (the gift banner's vertical
    // budget was already part of the original 900px allowance).
    var _card_h = 900 + _grid_h_m + 50;

    // White card slides up from bottom
    var _card_y = lerp(PH_H, 200, ph_ease_back(min(win_anim_t*1.2,1)));
    ph_draw_chip(60, _card_y, PH_W-60, _card_y+_card_h, 40,
                 PH_COL_WHITE, make_color_rgb(20,150,165), 12);

    // ── Running layout inside card ────────────────────────────────────────────
    var _y = _card_y + 80;

    // Blinky character (origin centred at 332,350; scale 0.38 → ~252×266 px)
    draw_sprite_ext(global.spr_blinky, 0, PH_W/2, _y+133, 0.38, 0.38, 0, c_white, 1);
    _y += 290;

    // "WELL DONE!"
    ph_draw_text(PH_W/2, _y, "WELL DONE!", global.fnt_disp_xl, PH_COL_PINK, fa_center, fa_middle);
    _y += 70;

    // ── Mini crossword — the solved grid, scaled to fit the card ──────────────
    var _mini_x = floor((PH_W - _grid_w_m) / 2);
    var _mini_y = _y;
    var _mini_tile_sc = _cell_m / 256;   // tile sprite is 256×256
    for (var _ci = 0; _ci < array_length(puzzle.cells); _ci++) {
        var _mc = puzzle.cells[_ci];
        var _mcx = _mini_x + (_mc.c - grid_min_c) * (_cell_m + _gap_m) + _cell_m / 2;
        var _mcy = _mini_y + (_mc.r - grid_min_r) * (_cell_m + _gap_m) + _cell_m / 2;

        // Same tint logic as the main board so the recap reads as the puzzle
        // the player just finished. Every cell is filled at this point, so the
        // empty-cream branch is effectively unused on the win screen.
        var _mtint;
        if      (_mc.shared && _mc.filled) _mtint = PH_COL_YELLOW;
        else if (_mc.hint)                 _mtint = make_color_rgb(255,180,220);
        else if (_mc.filled)               _mtint = PH_COL_PINK;
        else                               _mtint = make_color_rgb(234,216,200);

        draw_sprite_ext(global.spr_tile, 0, _mcx, _mcy,
                        _mini_tile_sc, _mini_tile_sc, 0, _mtint, 1);

        if (_mc.filled || _mc.hint) {
            var _mletter_col;
            if      (_mc.shared && _mc.filled) _mletter_col = PH_COL_DARK;
            else if (_mc.hint)                 _mletter_col = PH_COL_DARK;
            else                               _mletter_col = PH_COL_WHITE;
            // Font scales loosely with cell size: small cells get body font, big
            // cells get the display-small face. Keeps the letters legible without
            // looking oversized on a 4×4 grid.
            var _mfnt = (_cell_m >= 60) ? global.fnt_disp_sm : global.fnt_body_md;
            ph_draw_text(_mcx, _mcy, _mc.letter, _mfnt, _mletter_col, fa_center, fa_middle);
        }
    }
    _y += _grid_h_m + 50;

    // XP earned — teal pill
    ph_draw_chip(PH_W/2-180, _y-38, PH_W/2+180, _y+38, 38,
                 PH_COL_TEAL, make_color_rgb(10,140,128), 6);
    ph_draw_text(PH_W/2, _y, "+" + string(xp_gained) + " XP",
                 global.fnt_disp_sm, PH_COL_WHITE, fa_center, fa_middle);
    _y += 80;

    // Level row: star3d icon + "Level N" label + XP fraction
    var _lvl     = ph_level_from_xp(global.save.xp);
    var _xp_in   = ph_xp_in_level(global.save.xp);
    var _xp_frac = _xp_in / PH_XP_PER_LEVEL;
    draw_sprite_ext(global.spr_star3d, 0, 148, _y, 56/512, 56/512, 0, c_white, 1);
    ph_draw_text(205, _y, "Level " + string(_lvl), global.fnt_body_md, PH_COL_DARK, fa_left, fa_middle);
    ph_draw_text(PH_W-100, _y, string(_xp_in) + " / " + string(PH_XP_PER_LEVEL),
                 global.fnt_body_xs, PH_COL_GRAY, fa_right, fa_middle);
    _y += 35;

    // Purple XP progress bar
    ph_draw_rounded(100, _y, PH_W-100, _y+32, 16, make_color_rgb(220,210,205));
    var _bar_w = floor((PH_W-200) * _xp_frac);
    if (_bar_w > 0) ph_draw_rounded(100, _y, 100+_bar_w, _y+32, 16, PH_COL_PURPLE);
    _y += 55;

    // Stat chips — stopwatch (recorded finish time) and boxing glove (streak)
    var _streak = variable_struct_exists(global.save, "streak") ? global.save.streak : 1;

    ph_draw_chip(80, _y, 520, _y+70, 35, PH_COL_TEAL_SOFT, make_color_rgb(13,148,136), 5);
    draw_sprite_ext(global.spr_stopwatch, 0, 232, _y+35, 56/512, 56/512, 0, c_white, 1);
    ph_draw_text(296, _y+35, win_time_str, global.fnt_body_md, PH_COL_DARK, fa_left, fa_middle);

    ph_draw_chip(560, _y, 1000, _y+70, 35, PH_COL_PINK_SOFT, make_color_rgb(180,10,100), 5);
    draw_sprite_ext(global.spr_boxing_glove, 0, 700, _y+35, 56/512, 56/512, 0, c_white, 1);
    ph_draw_text(764, _y+35, string(_streak) + " day streak",
                 global.fnt_body_sm, PH_COL_DARK, fa_left, fa_middle);
    _y += 90;

    // Gift banner (only when a puzzle-pack bonus was awarded)
    if (coins_bonus > 0) {
        ph_draw_chip(PH_W/2-200, _y, PH_W/2+200, _y+60, 30,
                     PH_COL_GOLD, make_color_rgb(200,140,0), 5);
        ph_draw_text(PH_W/2, _y+30, "GIFT  +" + string(coins_bonus) + " COINS",
                     global.fnt_body_sm, PH_COL_WHITE, fa_center, fa_middle);
        _y += 80;
    }

    // "BACK TO HUB" primary button
    ph_draw_chip(80, _y, PH_W-80, _y+90, 28,
                 PH_COL_DARK, make_color_rgb(10,5,20), 6);
    ph_draw_text(PH_W/2, _y+45, "BACK TO HUB",
                 global.fnt_disp_sm, PH_COL_WHITE, fa_center, fa_middle);
    win_btn_back_y = _y;   // expose to Step_0 for tap detection

    // ── Confetti particles — drawn last so they sit on top of the card ────────
    // Three shape variants (rect/triangle/circle) keep the pour visually busy
    // without needing sprite assets. Rectangles + triangles rotate; circles
    // ignore rotation for cheaper draw calls.
    draw_set_alpha(_t);
    for (var _pi = 0; _pi < array_length(confetti_pieces); _pi++) {
        var _p = confetti_pieces[_pi];
        draw_set_color(_p.col);
        if (_p.shape == 2) {
            // Circle — rotation has no effect, so just draw it.
            draw_circle(_p.x, _p.y, _p.size * 0.45, false);
        } else {
            // Rotated quad/tri. cos/sin in degrees so we can keep `rot` in deg.
            var _cs = dcos(_p.rot);
            var _sn = dsin(_p.rot);
            if (_p.shape == 0) {
                // Rectangle (wider than tall, like a paper streamer)
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
                // Triangle confetti — equilateral around the centre.
                var _r = _p.size * 0.5;
                var _tx1 = _p.x + cos(degtorad(_p.rot       )) * _r;
                var _ty1 = _p.y + sin(degtorad(_p.rot       )) * _r;
                var _tx2 = _p.x + cos(degtorad(_p.rot + 120 )) * _r;
                var _ty2 = _p.y + sin(degtorad(_p.rot + 120 )) * _r;
                var _tx3 = _p.x + cos(degtorad(_p.rot + 240 )) * _r;
                var _ty3 = _p.y + sin(degtorad(_p.rot + 240 )) * _r;
                draw_triangle(_tx1,_ty1, _tx2,_ty2, _tx3,_ty3, false);
            }
        }
    }
    draw_set_alpha(1);
}
