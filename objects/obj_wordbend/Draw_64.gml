// ── Word Bend — Draw GUI ──────────────────────────────────────────────────────

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
var _shx     = shake_offset_x;

// ── Top HUD strip: back · WORD BEND · coin balance ────────────────────────────
var _hud_y = 95 + global.safe_top_gui;
draw_sprite_ext(global.spr_back2, 0, 60, _hud_y, 0.36, 0.36, 0, c_white, 1);
ph_draw_text(PH_W/2, _hud_y, "WORD BEND", global.fnt_disp_md, ACCENT, fa_center, fa_middle);

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
ph_draw_game_tip(grid_y, ph_game_tip("wordbend"));

// ── Connector helper: thick rounded line through a list of cell centres ────────
// Fills the gaps between consecutive tiles so a word reads as one continuous,
// bending ribbon. Tiles are drawn on top afterwards.
var _draw_ribbon = function(_seq, _col, _w) {
    draw_set_color(_col);
    for (var _i = 0; _i < array_length(_seq); _i++) {
        var _p = wb_center(_seq[_i]);
        var _px = _p.x + shake_offset_x;
        draw_circle(_px, _p.y, _w/2, false);
        if (_i > 0) {
            var _q = wb_center(_seq[_i-1]);
            draw_line_width(_q.x + shake_offset_x, _q.y, _px, _p.y, _w);
        }
    }
};

// Found-word ribbons — each word in its own colour, under the tiles.
for (var _w = 0; _w < NWORDS; _w++) {
    if (!found[_w]) continue;
    var _cs = puzzle.words[_w].cells;
    var _seq = [];
    for (var _k = 0; _k < array_length(_cs); _k++) array_push(_seq, _cs[_k].r * N + _cs[_k].c);
    _draw_ribbon(_seq, word_colors[_w], CELL + GAP * 0.9);
}
// Active trace ribbon (tangerine), under the tiles.
if (array_length(sel_path) >= 2) _draw_ribbon(sel_path, ACCENT, CELL + GAP * 0.9);

// ── Tiles + letters ───────────────────────────────────────────────────────────
for (var _i = 0; _i < NCELLS; _i++) {
    var _r = _i div N, _c = _i mod N;
    var _ctr = wb_center(_i);
    var _cx  = _ctr.x + _shx;
    var _cy  = _ctr.y;
    var _hw  = (CELL/2) * cell_scale[_i];

    var _is_found = (cell_owner[_i] != -1);
    var _in_sel   = (wb_path_index(_i) != -1);

    // Is this the hinted first letter of an unfound word?
    var _is_hint = false;
    for (var _w = 0; _w < NWORDS; _w++) {
        if (hinted[_w] && !found[_w] && wb_first_cell(_w) == _i) { _is_hint = true; break; }
    }

    var _fill = PH_COL_TILE;
    var _lcol = make_color_rgb(95, 85, 80);
    if (_is_found)    { _fill = word_colors[cell_owner[_i]]; _lcol = PH_COL_WHITE; }
    else if (_in_sel) { _fill = ACCENT;                      _lcol = PH_COL_WHITE; }

    ph_draw_rounded(_cx - _hw, _cy - _hw, _cx + _hw, _cy + _hw, TILE_R, _fill);

    // Subtle border on plain tiles for a card feel.
    if (!_is_found && !_in_sel) {
        draw_set_color(make_color_rgb(214, 201, 186));
        draw_set_alpha(0.9);
        draw_rectangle(_cx - _hw, _cy - _hw, _cx + _hw, _cy + _hw, true);
        draw_set_alpha(1);
        // Hinted first letter → tangerine ring + accent letter.
        if (_is_hint) {
            _lcol = ACCENT_DEEP;
            draw_set_color(ACCENT);
            ph_draw_rounded(_cx - _hw, _cy - _hw, _cx + _hw, _cy + _hw, TILE_R, ACCENT);
            ph_draw_rounded(_cx - _hw + 7, _cy - _hw + 7, _cx + _hw - 7, _cy + _hw - 7, max(0,TILE_R-5), PH_COL_TILE);
        }
    }

    ph_draw_text(_cx, _cy, puzzle.grid[_r][_c], global.fnt_disp_md, _lcol, fa_center, fa_middle);
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
ph_draw_chip(HINT_PILL_L, HINT_PILL_T, HINT_PILL_R, HINT_PILL_B, 33, PH_COL_WHITE, _chip_sh, 6);
draw_sprite_ext(global.spr_bulb, 0, HINT_PILL_L+12, _tool_y, 101/512, 101/512, 0, c_white, 1);
ph_draw_text(HINT_PILL_L+51, _tool_y, "HINT", global.fnt_body_md, PH_COL_DARK, fa_left, fa_middle);

// ── Message Prompt — above the game tip, just below the HUD (Penpot design) ────
if (toast_timer > 0) ph_draw_toast(toast_text, toast_col, min(1, toast_timer/15), grid_y);

// ── Hint modal + placeholder rewarded-video (drawn last, cover everything) ─────
ph_hint_draw_modal(hint);
ph_hint_draw_video(hint);
