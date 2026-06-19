// ── obj_ladder — Draw GUI ─────────────────────────────────────────────────────
// HUD · word row · progress · clue box · letters-only keyboard · bottom bar.

// Background
draw_set_color(PH_COL_BG);
draw_rectangle(0, 0, PH_W, PH_H, false);
ph_draw_dot_bg(PH_COL_BG);

// ── Win screen owns the frame when complete ───────────────────────────────────
if (win_phase == 1) {
    win.cfg.time_str = win_time_str;
    ph_win_draw(win);
    exit;
}

// ── Top HUD: back · LADDER · coin balance ─────────────────────────────────────
draw_sprite_ext(global.spr_back2, 0, 60, HUD_Y, 0.36, 0.36, 0, c_white, 1);
ph_draw_text(PH_W/2, HUD_Y, "LADDER", global.fnt_disp_md, PH_COL_AMBER, fa_center, fa_middle);

var _cb_r = PH_W - 50;
var _cb_l = _cb_r - 220;
ph_draw_chip(_cb_l, HUD_Y-33, _cb_r, HUD_Y+33, 33, PH_COL_WHITE, make_color_rgb(190,170,155), 6);
draw_sprite_ext(global.spr_gold_coin, 0, _cb_l+23, HUD_Y, 112/512, 112/512, 0, c_white, 1);
ph_draw_text(_cb_l+74, HUD_Y, string(global.save.coins), global.fnt_body_md, PH_COL_DARK, fa_left, fa_middle);

// "-100" coin-spend feedback near the coin pill (shared hint helper).
hint.coin_x = (_cb_l + _cb_r) / 2;
hint.coin_y = HUD_Y;
ph_hint_draw_feedback(hint);

// ── Message prompt (shared toast) + game tip ──────────────────────────────────
if (toast_timer > 0) {
    ph_draw_toast(toast_text, toast_col, min(1, toast_timer/15), TIP_Y + 40, TIP_Y);
} else {
    ph_draw_game_tip(row_y - 30, ph_game_tip("ladder"));
}

// ── Word row ──────────────────────────────────────────────────────────────────
for (var _i = 0; _i < N; _i++) {
    var _x = row_x + _i * (TILE + TILE_GAP);
    var _fill = PH_COL_BOARD_BG;
    if      (feedback == "correct") _fill = PH_COL_WB_FOUND;
    else if (feedback == "wrong")   _fill = PH_COL_LADDER_BAD;
    else if (_i == sel)             _fill = PH_COL_AMBER;
    else if (_i == hinted)          _fill = PH_COL_AMBER_SOFT;

    draw_set_color(_fill);
    draw_roundrect_ext(_x, row_y, _x + TILE, row_y + TILE, 20, 20, false);
    if (letters[_i] != "") {
        ph_draw_text(_x + TILE/2, row_y + TILE/2, letters[_i],
                     global.fnt_disp_lg, PH_COL_DARK, fa_center, fa_middle);
    }
}

// ── Progress: N / 10 ──────────────────────────────────────────────────────────
var _prog = min(step + 1, puzzle.count);
draw_set_alpha(0.6);
ph_draw_text(PH_W/2, PROG_Y, string(_prog) + " / " + string(puzzle.count),
             global.fnt_body_semi, PH_COL_DARK, fa_center, fa_middle);
draw_set_alpha(1);

// ── Clue box ──────────────────────────────────────────────────────────────────
ph_draw_rounded(CLUE_L, CLUE_TOP, CLUE_R, CLUE_BOT, 36, PH_COL_BOARD_BG);
var _clue = (puzzle.count > 0) ? puzzle.clues[min(step, puzzle.count - 1)] : "";
draw_set_font(global.fnt_body_md);
draw_set_halign(fa_center);
draw_set_valign(fa_middle);
draw_set_color(PH_COL_DARK);
draw_set_alpha(0.65);
draw_text_ext((CLUE_L + CLUE_R)/2, (CLUE_TOP + CLUE_BOT)/2, _clue, 64, CLUE_R - CLUE_L - 70);
draw_set_alpha(1);

// ── Custom keyboard (letters only) ────────────────────────────────────────────
var _keys = ld_build_keys();
for (var _i = 0; _i < array_length(_keys); _i++) {
    var _k = _keys[_i];
    var _kfill = make_color_rgb(228,228,228);
    var _ktext = PH_COL_DARK;
    // 2nd hint highlights the correct letter on the keyboard (amber, dark text).
    if (hint_lvl >= 2 && hint_key != "" && _k.ch == hint_key) {
        _kfill = PH_COL_AMBER;
    }
    // Press feedback: the last-tapped key darkens briefly.
    if (key_press_t > 0 && _k.ch == key_press_ch) {
        _kfill = merge_color(_kfill, c_black, 0.22);
    }
    draw_set_color(_kfill);
    draw_roundrect_ext(_k.x1, _k.y1, _k.x2, _k.y2, 16, 16, false);
    ph_draw_text((_k.x1+_k.x2)/2, (_k.y1+_k.y2)/2, _k.ch, global.fnt_disp_md, _ktext, fa_center, fa_middle);
}

// ── Bottom bar: timer pill (left) · HINT pill (right) ─────────────────────────
var _tool_y = PH_H - 110 - global.safe_bottom_gui;
var _e_s    = ph_timer_now(timer_base_secs, session_start_ms);
var _t_str  = string(_e_s div 60) + ":" + (((_e_s mod 60) < 10) ? "0" : "") + string(_e_s mod 60);
var _tp_l = 60, _tp_r = 60 + 210;
ph_draw_chip(_tp_l, _tool_y-33, _tp_r, _tool_y+33, 33, PH_COL_WHITE, make_color_rgb(190,170,155), 6);
draw_sprite_ext(global.spr_stopwatch, 0, _tp_l+30, _tool_y, 106/512, 106/512, 0, c_white, 1);
// Timer text flashes red right after a wrong-guess penalty.
var _t_col = (pen_t > 0) ? PH_COL_LADDER_BAD : PH_COL_DARK;
ph_draw_text(_tp_l+78, _tool_y, _t_str, global.fnt_body_md, _t_col, fa_left, fa_middle);
// Floating "+5s" rising above the timer pill.
if (pen_t > 0) {
    var _pa = min(1, pen_t / 18);
    var _py = (_tool_y - 50) - (PEN_DUR - pen_t) * 1.1;
    draw_set_alpha(_pa);
    ph_draw_text((_tp_l + _tp_r)/2, _py, "+" + string(PH_LADDER_PENALTY_SECS) + "s",
                 global.fnt_body_md, PH_COL_LADDER_BAD, fa_center, fa_middle);
    draw_set_alpha(1);
}

HINT_PILL_R = PH_W - 50;
HINT_PILL_L = HINT_PILL_R - 210;
HINT_PILL_T = _tool_y - 33;
HINT_PILL_B = _tool_y + 33;
ph_hint_pill_draw(HINT_PILL_L, HINT_PILL_T, HINT_PILL_R, HINT_PILL_B, make_color_rgb(190,170,155));   // bounces after 5s idle

// ── Post-buy reveal (iris contracts onto the hinted tile / keyboard key) ──────
ph_hint_draw_reveal(hint);

// ── Hint modal + placeholder video (drawn last so they cover the board) ───────
ph_hint_draw_modal(hint);
ph_hint_draw_video(hint);
