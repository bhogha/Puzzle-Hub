// ── obj_wordle — Draw GUI ─────────────────────────────────────────────────────
// Phase 2: board + custom keyboard + reveal. Win screen drawn last when complete.

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

// ── Top HUD: back · WORDLE · coin balance ─────────────────────────────────────
draw_sprite_ext(global.spr_back2, 0, 60, HUD_Y, 0.36, 0.36, 0, c_white, 1);
ph_draw_text(PH_W/2, HUD_Y, "WORDLE", global.fnt_disp_md, PH_COL_GREEN, fa_center, fa_middle);

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
// Wordle's board sits high, so the prompt and the tip would collide. Show the
// prompt OVER the tip line (just above the board) and hide the tip while it's up.
if (toast_timer > 0) {
    ph_draw_toast(toast_text, toast_col, min(1, toast_timer/15), grid_y, grid_y - 58);
} else {
    ph_draw_game_tip(grid_y, ph_game_tip("wordle"));
}

// ── Guess grid ────────────────────────────────────────────────────────────────
// Rows = puzzle.max_guesses (grows to 9 after an extra-moves purchase). Cells
// shrink to fit the same vertical band, so the keyboard position is unchanged and
// a normal 6-row game renders identically.
var _ncommitted = array_length(puzzle.guesses);
var _input_row  = _ncommitted;   // the row currently being typed
var _rows  = puzzle.max_guesses;
var _cell  = (GRID_H - (_rows - 1) * GAP) / _rows;
var _gx    = (PH_W - (COLS * _cell + (COLS - 1) * GAP)) div 2;
var _gfnt  = (_cell >= 120) ? global.fnt_disp_lg : global.fnt_disp_md;
var _rad   = (_cell >= 120) ? 20 : 14;

var _EMPTY  = make_color_rgb(228,228,228);
var _ABSENT = make_color_rgb(198,198,198);
var _BORDER = make_color_rgb(150,150,150);

for (var _r = 0; _r < _rows; _r++) {

    // Resolve this row's source guess + score (if any).
    var _guess = "";
    var _score = [];
    var _is_committed = (_r < _ncommitted);
    var _is_reveal    = (revealing && _r == reveal_row);
    var _is_input     = (!revealing && _r == _input_row && puzzle.status == "in_progress");
    if (_is_committed) {
        _guess = puzzle.guesses[_r];
        _score = ph_wordle_score_guess(puzzle.answer, _guess);
    } else if (_is_reveal) {
        _guess = reveal_guess;
        _score = reveal_score;
    }

    for (var _c = 0; _c < COLS; _c++) {
        var _x0 = _gx + _c * (_cell + GAP);
        var _y0 = grid_y + _r * (_cell + GAP);
        // The active row reads from the slot arrays; other rows from _guess.
        var _ch = _is_input ? row_slots[_c]
                            : ((string_length(_guess) >= _c + 1) ? string_char_at(_guess, _c + 1) : "");

        // Decide fill + whether the colour has "landed" (reveal stagger).
        var _fill   = _EMPTY;
        var _letter = (_ch != "");
        var _pop    = 1.0;
        var _outline = false;

        if (_is_committed) {
            if      (_score[_c] == "green")  _fill = PH_COL_GREEN;
            else if (_score[_c] == "yellow") _fill = PH_COL_YELLOW;
            else                             _fill = _ABSENT;
        } else if (_is_reveal) {
            var _landed_at = _c * REVEAL_STAGGER + REVEAL_FLIP;
            if (reveal_t >= _landed_at) {
                if      (_score[_c] == "green")  _fill = PH_COL_GREEN;
                else if (_score[_c] == "yellow") _fill = PH_COL_YELLOW;
                else                             _fill = _ABSENT;
                var _since = reveal_t - _landed_at;
                if (_since < 8) _pop = 1.0 + 0.12 * (1 - _since/8);   // little settle pop
            } else {
                _fill = PH_COL_WHITE;       // not yet flipped — show as typed
                _outline = true;
            }
        } else if (_is_input) {
            if (row_lock[_c]) {
                _fill = PH_COL_GREEN;       // hint-revealed, locked correct letter
            } else if (_letter) {
                _fill = PH_COL_WHITE;       // typed
                _outline = true;
            }
        }

        var _hw = (_cell * _pop) / 2;
        var _mx0 = _x0 + _cell/2 - _hw, _my0 = _y0 + _cell/2 - _hw;
        var _mx1 = _x0 + _cell/2 + _hw, _my1 = _y0 + _cell/2 + _hw;
        draw_set_color(_fill);
        draw_roundrect_ext(_mx0, _my0, _mx1, _my1, _rad, _rad, false);
        if (_outline) {
            draw_set_color(_BORDER);
            draw_roundrect_ext(_mx0, _my0, _mx1, _my1, _rad, _rad, true);
        }
        if (_letter) {
            ph_draw_text(_x0 + _cell/2, _y0 + _cell/2, _ch, _gfnt, PH_COL_DARK, fa_center, fa_middle);
        }
    }
}

// ── Custom keyboard ───────────────────────────────────────────────────────────
var _keys = wd_build_keys();
for (var _i = 0; _i < array_length(_keys); _i++) {
    var _k = _keys[_i];
    var _kfill = make_color_rgb(228,228,228);
    var _ktext = PH_COL_DARK;
    var _label = "";

    if (_k.type == "letter") {
        _label = _k.ch;
        if (variable_struct_exists(kbd_states, _k.ch)) {
            var _st = variable_struct_get(kbd_states, _k.ch);
            if      (_st == "green")  _kfill = PH_COL_GREEN;
            else if (_st == "yellow") _kfill = PH_COL_YELLOW;
            else if (_st == "gray")   { _kfill = make_color_rgb(150,150,150); _ktext = PH_COL_WHITE; }
        }
    } else if (_k.type == "del") {
        _label = "DEL";
    } else if (_k.type == "send") {
        _label  = "SEND";
        _kfill  = PH_COL_GREEN;
        _ktext  = PH_COL_WHITE;
    }

    draw_set_color(_kfill);
    draw_roundrect_ext(_k.x1, _k.y1, _k.x2, _k.y2, 16, 16, false);
    var _kfnt = (_k.type == "letter") ? global.fnt_disp_md : global.fnt_body_md;
    ph_draw_text((_k.x1+_k.x2)/2, (_k.y1+_k.y2)/2, _label, _kfnt, _ktext, fa_center, fa_middle);
}

// ── Bottom bar: timer pill (left) · HINT pill (right) ─────────────────────────
var _tool_y = PH_H - 110 - global.safe_bottom_gui;
var _e_s    = ph_timer_now(timer_base_secs, session_start_ms);
var _t_str  = string(_e_s div 60) + ":" + (((_e_s mod 60) < 10) ? "0" : "") + string(_e_s mod 60);
var _tp_l = 60, _tp_r = 60 + 210;
ph_draw_chip(_tp_l, _tool_y-33, _tp_r, _tool_y+33, 33, PH_COL_WHITE, make_color_rgb(190,170,155), 6);
draw_sprite_ext(global.spr_stopwatch, 0, _tp_l+30, _tool_y, 106/512, 106/512, 0, c_white, 1);
ph_draw_text(_tp_l+78, _tool_y, _t_str, global.fnt_body_md, PH_COL_DARK, fa_left, fa_middle);

// HINT pill — bulb · "HINT"
HINT_PILL_R = PH_W - 50;
HINT_PILL_L = HINT_PILL_R - 210;
HINT_PILL_T = _tool_y - 33;
HINT_PILL_B = _tool_y + 33;
ph_draw_chip(HINT_PILL_L, HINT_PILL_T, HINT_PILL_R, HINT_PILL_B, 33, PH_COL_WHITE, make_color_rgb(190,170,155), 6);
draw_sprite_ext(global.spr_bulb, 0, HINT_PILL_L+12, _tool_y, 101/512, 101/512, 0, c_white, 1);
ph_draw_text(HINT_PILL_L+51, _tool_y, "HINT", global.fnt_body_md, PH_COL_DARK, fa_left, fa_middle);

// ── Hint modal + placeholder video (drawn last so they cover the board) ───────
ph_hint_draw_modal(hint);
ph_hint_draw_video(hint);

// ── Lose / lost-aversion overlays (drawn on top of everything) ────────────────
if (lose_phase != "none") wd_lose_draw();
