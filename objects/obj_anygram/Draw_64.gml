// ── Anygram — Draw GUI ────────────────────────────────────────────────────────

// Win screen is now drawn by the shared controller (scr_economy §Shared Win
// Screen). When complete, it fully owns the frame — draw it and stop here. The
// legacy win_phase==1 block further below is superseded and no longer reached.
if (win_phase == 1) {
    win.cfg.time_str = win_time_str;
    ph_win_draw(win);
    exit;
}

// Background — dots faded to ~50% per design ref
draw_set_color(PH_COL_BG);
draw_rectangle(0,0,PH_W,PH_H,false);
draw_set_alpha(0.5);
ph_draw_dot_bg(make_color_rgb(230,215,205));
draw_set_alpha(1);

// ── Game screen (hidden while win overlay is active) ──────────────────────────
if (win_phase == 0) {

// ── Top bar (HUD strip) ──────────────────────────────────────────────────────
// Layout across the bar: back chevron · ANYGRAM title (centred) · coin balance
// (right). _hud_y is offset by safe_top_gui so the bar clears the Dynamic Island
// / status bar on all devices. The base offset (95) gives a small visual gap
// between the safe area boundary and the pill top edge. The live timer now lives
// in the centre of the bottom strip.
var _hud_y = 95 + global.safe_top_gui;

// Back chevron — new baked-black sprite (drawn with c_white to keep its colour).
draw_sprite_ext(global.spr_back2, 0, 60, _hud_y, 0.36, 0.36, 0, c_white, 1);
ph_draw_text(PH_W/2, _hud_y, "ANYGRAM", global.fnt_disp_md, PH_COL_PINK, fa_center, fa_middle);

// Coin balance pill — top-right (moved up from the bottom toolbar). Keeps the
// pulse/overshoot animation so coin-fly arrivals still feel alive. No tap action.
var _cp_hud = 1.0;
if (coin_pulse_t < 1) {
    var _p2c = coin_pulse_t;
    _cp_hud = (_p2c < 0.5) ? lerp(1.0, 1.25, _p2c/0.5) : lerp(1.25, 1.0, (_p2c-0.5)/0.5);
}
if (coin_overshoot_t < 1) _cp_hud *= 1 + sin(coin_overshoot_t * pi * 2) * 0.12 * (1 - coin_overshoot_t);
var _cb_pill_r = PH_W - 50;
var _cb_pill_l = _cb_pill_r - 220;
ph_draw_chip(_cb_pill_l, _hud_y-33, _cb_pill_r, _hud_y+33, 33,
             PH_COL_WHITE, make_color_rgb(190,170,155), 6);
// Coin icon: oversized, vertically centred on the pill, pinned to the left cap
// so it spills past the left/top/bottom edges (shared HUD-pill icon style).
var _cb_icon_s = (112/512) * _cp_hud;
draw_sprite_ext(global.spr_gold_coin, 0, _cb_pill_l+23, _hud_y, _cb_icon_s, _cb_icon_s, 0, c_white, 1);
ph_draw_text(_cb_pill_l+74, _hud_y, string(global.save.coins),
             global.fnt_body_md, PH_COL_DARK, fa_left, fa_middle);
// Expose the coin pill centre as the coin-fly target so the reward arc lands here.
COIN_BAL_X = (_cb_pill_l + _cb_pill_r) / 2;
COIN_BAL_Y = _hud_y;

// "-100" spend feedback — drawn by the shared hint helper near the coin pill.
hint.coin_x = COIN_BAL_X;
hint.coin_y = COIN_BAL_Y;
ph_hint_draw_feedback(hint);

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
    else                              _tint = make_color_rgb(241,234,225);   // blank placeholder #F1EAE1

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
// Disc background — Wheel_bg.png (yellow fill + dashed ring baked in). Source is
// 750×750 with origin centred; scale so its diameter matches 2×WHEEL_R.
var _wheel_bg_sc = (WHEEL_R * 2) / 750;
draw_sprite_ext(global.spr_wheel_bg, 0, _wcx, WHEEL_CY, _wheel_bg_sc, _wheel_bg_sc, 0, c_white, 1);

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
    // Shares the Message Prompt slot/height (36 half-height, fully-rounded) so the
    // live swipe pill swaps seamlessly into the feedback Message Prompt on release.
    ph_draw_chip(PH_W/2-200,_pill_y-36, PH_W/2+200,_pill_y+36, 36,
                 PH_COL_DARK, make_color_rgb(10,5,20), 6);
    ph_draw_text(PH_W/2, _pill_y, trail_word, global.fnt_disp_md, PH_COL_WHITE, fa_center, fa_middle);
}

// (Live timer now lives in the top HUD strip — see GDD §7.)

// ── Bottom toolbar ────────────────────────────────────────────────────────────
// Layout: BONUS chest+pill (left) · timer pill (centre) · HINT pill (right).
var _tool_y = PH_H - 110 - global.safe_bottom_gui;

// Left — BONUS button: white pill (Pill.png) with the 3D chest on the left and a
// "BONUS" label. Tappable to open the bonus-words modal; bounds are stored in
// BONUS_PILL_{L,R,T,B} and read by Step_0.gml (keep in sync).
var _bonus_count = 0;
for (var _bi = 0; _bi < array_length(puzzle.bonus_found); _bi++) {
    if (puzzle.bonus_found[_bi]) _bonus_count++;
}
BONUS_PILL_L = 50;
BONUS_PILL_R = 340;
BONUS_PILL_T = _tool_y - 33;
BONUS_PILL_B = _tool_y + 33;
ph_draw_chip(BONUS_PILL_L, BONUS_PILL_T, BONUS_PILL_R, BONUS_PILL_B, 33,
             PH_COL_WHITE, make_color_rgb(190,170,155), 6);
// Chest: matches the coin icon's height (numerator differs because each icon's
// transparent padding differs). Vertically centred on the pill, pinned to the
// left cap so it spills past the edges. Always full-colour (never greyed).
var _chest_s = 118 / 512;
draw_sprite_ext(global.spr_chest, 0, BONUS_PILL_L + 27, _tool_y, _chest_s, _chest_s, 0, c_white, 1);
ph_draw_text(BONUS_PILL_L + 82, _tool_y, "BONUS",
             global.fnt_body_md, PH_COL_DARK, fa_left, fa_middle);
// Keep the fly-tile target pointing at the chest centre.
BONUS_ICON_X = BONUS_PILL_L + 27;
BONUS_ICON_Y = _tool_y;
// Count badge (only visible if at least one bonus found) — chest's upper-right.
if (_bonus_count > 0) {
    draw_set_color(PH_COL_PINK);
    draw_circle(BONUS_PILL_L + 60, _tool_y - 30, 20, false);
    ph_draw_text(BONUS_PILL_L + 60, _tool_y - 30, string(_bonus_count),
                 global.fnt_body_xs, PH_COL_WHITE, fa_center, fa_middle);
}

// Centre — live timer pill (moved down from the top HUD per design ref).
var _hud_e_s   = floor((current_time - session_start_ms) / 1000);
var _hud_e_m   = _hud_e_s div 60;
var _hud_e_ss  = _hud_e_s mod 60;
var _hud_time  = string(_hud_e_m) + ":" + ((_hud_e_ss < 10) ? "0" : "") + string(_hud_e_ss);
var _tp_l = PH_W/2 - 105;
var _tp_r = PH_W/2 + 105;
ph_draw_chip(_tp_l, _tool_y - 33, _tp_r, _tool_y + 33, 33,
             PH_COL_WHITE, make_color_rgb(190,170,155), 6);
draw_sprite_ext(global.spr_stopwatch, 0, _tp_l + 19, _tool_y, 106/512, 106/512, 0, c_white, 1);
ph_draw_text(_tp_l + 65, _tool_y, _hud_time, global.fnt_body_md, PH_COL_DARK, fa_left, fa_middle);

// Right — HINT pill: bulb · "HINT" (cost chip removed; handled elsewhere).
// Tap target lives in Step_0.gml as HINT_PILL_{L,R,T,B}; keep them in sync.
HINT_PILL_R = PH_W - 50;
HINT_PILL_L = HINT_PILL_R - 210;
HINT_PILL_T = _tool_y - 33;
HINT_PILL_B = _tool_y + 33;
ph_draw_chip(HINT_PILL_L, HINT_PILL_T, HINT_PILL_R, HINT_PILL_B, 33,
             PH_COL_WHITE, make_color_rgb(190,170,155), 6);
// Bulb: vertically centred, pinned to the left cap so it spills past the edges.
draw_sprite_ext(global.spr_bulb, 0, HINT_PILL_L + 12, _tool_y, 101/512, 101/512, 0, c_white, 1);
ph_draw_text(HINT_PILL_L + 51, _tool_y, "HINT",
             global.fnt_body_md, PH_COL_DARK, fa_left, fa_middle);

// ── Message Prompt — the unified feedback pill for ALL Anygram prompts (FOUND,
//           BONUS, ALREADY FOUND, NOT A KEY/VALID WORD, hint results…). Drawn at
//           the same y as the live word-preview pill so it replaces the swipe
//           pill seamlessly on release. Matches the Penpot "Message Prompt"
//           design: a fully-rounded teal pill (design 900×100 → 648×72 GUI px),
//           bold white display text, centred between the word grid and the wheel.
//           Width adapts to the message, never below the design minimum. ──
if (toast_timer > 0) {
    var _alpha = min(1, toast_timer/15);
    var _mp_hh = 36;                                     // half-height (design 100 → 72)
    draw_set_font(global.fnt_disp_md);
    var _mp_hw = max(324, string_width(toast_text)/2 + 48);   // design min 900 → 648; +pad
    draw_set_alpha(_alpha);
    ph_draw_chip(PH_W/2-_mp_hw,_pill_y-_mp_hh, PH_W/2+_mp_hw,_pill_y+_mp_hh, _mp_hh,
                 toast_col, make_color_rgb(20,20,20), 5);
    ph_draw_text(PH_W/2, _pill_y, toast_text, global.fnt_disp_md, PH_COL_WHITE, fa_center, fa_middle);
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

// ── Hint modal — slide-up bottom sheet (pay coins OR watch a placeholder video).
ph_hint_draw_modal(hint);

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

// ── Placeholder rewarded-video screen — drawn last so it covers every layer.
ph_hint_draw_video(hint);
