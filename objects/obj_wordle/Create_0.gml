// ── obj_wordle — Create ───────────────────────────────────────────────────────
// Phase 2: playable core (6×6 board + custom keyboard + reveal + win).
// Hint (Phase 4) and the loss / lost-aversion flow (Phase 5) are added later.

accent = PH_COL_GREEN;

// ── Puzzle + session ──────────────────────────────────────────────────────────
puzzle           = ph_wordle_for_date(global.selected_date_key);
session_start_ms = current_time;

// Input / play state
cur_guess   = "";                 // letters typed into the active row (not yet submitted)
kbd_states  = {};                 // letter -> "green"/"yellow"/"gray" (keyboard tint)

// Reveal animation for a just-submitted row
revealing    = false;
reveal_row   = -1;
reveal_guess = "";
reveal_score = [];
reveal_t     = 0;
REVEAL_STAGGER = 8;               // frames between columns
REVEAL_FLIP    = 10;              // frames for a column to "land"

// Toast / message prompt
toast_text  = "";
toast_col   = PH_COL_GRAY;
toast_timer = 0;
TOAST_DUR   = 90;

// Win flow
win_phase    = 0;
win_time_str = "0:00";
coins_bonus  = 0;

// ── Layout ────────────────────────────────────────────────────────────────────
HUD_Y = 95 + global.safe_top_gui;

COLS = PH_WORDLE_LEN;             // 6
ROWS = PH_WORDLE_GUESSES;         // 6 (the visible grid is always the base 6 rows in Phase 2)
CELL = 138;
GAP  = 14;
GRID_W = COLS * CELL + (COLS - 1) * GAP;
GRID_H = ROWS * CELL + (ROWS - 1) * GAP;
grid_x = (PH_W - GRID_W) div 2;
grid_y = HUD_Y + 175;

// Keyboard
KEY_W = 94; KEY_H = 120; KEY_GAP = 10; KEY_ROW_GAP = 16;
DEL_W = 150; SEND_W = 300; SEND_H = 110;
KB_TOP = grid_y + GRID_H + 60;
kb_rows = ["QWERTYUIOP", "ASDFGHJKL", "ZXCVBNM"];

/// Build the key rects (shared by Step hit-testing and Draw). Returns an array of
/// { type:"letter"|"del"|"send", ch, x1,y1,x2,y2 }.
wd_build_keys = function() {
    var _keys = [];
    for (var _r = 0; _r < 3; _r++) {
        var _row  = kb_rows[_r];
        var _ncol = string_length(_row);
        var _extra = (_r == 2) ? (DEL_W + KEY_GAP) : 0;
        var _roww  = _ncol * KEY_W + (_ncol - 1) * KEY_GAP + _extra;
        var _x = (PH_W - _roww) / 2;
        var _y = KB_TOP + _r * (KEY_H + KEY_ROW_GAP);
        for (var _c = 0; _c < _ncol; _c++) {
            var _ch = string_char_at(_row, _c + 1);
            array_push(_keys, { type:"letter", ch:_ch, x1:_x, y1:_y, x2:_x + KEY_W, y2:_y + KEY_H });
            _x += KEY_W + KEY_GAP;
        }
        if (_r == 2) {
            array_push(_keys, { type:"del", ch:"", x1:_x, y1:_y, x2:_x + DEL_W, y2:_y + KEY_H });
        }
    }
    var _sy = KB_TOP + 3 * (KEY_H + KEY_ROW_GAP);
    array_push(_keys, { type:"send", ch:"", x1:(PH_W - SEND_W)/2, y1:_sy, x2:(PH_W + SEND_W)/2, y2:_sy + SEND_H });
    return _keys;
};

/// Show a toast / message-prompt for TOAST_DUR frames.
wd_toast = function(_text, _col) {
    toast_text  = _text;
    toast_col   = _col;
    toast_timer = TOAST_DUR;
};

// ── Win bookkeeping — fires once when the answer is guessed ────────────────────
wd_check_win = function() {
    var _fin_s  = floor((current_time - session_start_ms) / 1000);
    var _fin_m  = _fin_s div 60;
    var _fin_ss = _fin_s mod 60;
    win_time_str = string(_fin_m) + ":" + ((_fin_ss < 10) ? "0" : "") + string(_fin_ss);
    global.save[$ "wordle_time_" + global.selected_date_key] = win_time_str;

    // Mark solved via the generic helper (counts toward gift/streak automatically).
    // The dedicated ph_wordle_is_done/mark + resume state come in Phase 3.
    ph_mark_solved(global.save, global.selected_date_key, "WORDLE");

    // Gift box for the 4th solved puzzle of the day.
    var _count = ph_solved_count_on(global.save, global.selected_date_key);
    coins_bonus = 0;
    if (_count >= PH_GIFT_PUZZLE_INDEX + 1 && !ph_has_gift_been_claimed(global.save, global.selected_date_key)) {
        ph_claim_gift(global.save, global.selected_date_key);
        ph_grant_coins(global.save, PH_COINS_FOR_4TH);
        coins_bonus = PH_COINS_FOR_4TH;
    }
    ph_update_streak(global.save);
    ph_save_write(global.save);

    win_phase = 1;
    win.cfg.time_str = win_time_str;
    ph_win_celebrate(win);
};

// ── Shared win screen (scr_economy §Shared Win Screen) ────────────────────────
// Mini guess-grid recap fitted into the box.
win_draw_recap = function(_cx, _top, _bw, _bh) {
    var _cell = floor(min(_bw / COLS, _bh / ROWS));
    var _gw = _cell * COLS, _gh = _cell * ROWS;
    var _ox = _cx - _gw/2, _oy = _top + (_bh - _gh)/2;
    // Prefer the player's actual guesses; on a bare review fall back to one green answer row.
    var _rows = puzzle.guesses;
    if (array_length(_rows) == 0) _rows = [ puzzle.answer ];
    for (var _r = 0; _r < ROWS; _r++) {
        var _has   = (_r < array_length(_rows));
        var _guess = _has ? _rows[_r] : "";
        var _score = _has ? ph_wordle_score_guess(puzzle.answer, _guess) : [];
        for (var _c = 0; _c < COLS; _c++) {
            var _x = _ox + _c*_cell, _y = _oy + _r*_cell;
            var _fill = make_color_rgb(214,214,214);
            if (_has) {
                if      (_score[_c] == "green")  _fill = PH_COL_GREEN;
                else if (_score[_c] == "yellow") _fill = PH_COL_YELLOW;
            }
            draw_set_color(_fill);
            draw_roundrect_ext(_x+2, _y+2, _x+_cell-2, _y+_cell-2, 8, 8, false);
            if (_has) {
                ph_draw_text(_x+_cell/2, _y+_cell/2, string_char_at(_guess, _c+1),
                             global.fnt_body_md, PH_COL_DARK, fa_center, fa_middle);
            }
        }
    }
};

// ── Review / solved re-entry ──────────────────────────────────────────────────
var _review = variable_global_exists("wordle_review_mode") && global.wordle_review_mode;
if (_review) global.wordle_review_mode = false;
var _already_solved = _review || ph_is_solved(global.save, global.selected_date_key, "WORDLE");

win = ph_win_create({
    puzzle_name: "WORDLE",
    title_col:   PH_COL_GREEN,
    bg_col:      PH_COL_TEAL,
    claim_key:   "wordle_" + global.selected_date_key,
    already:     _already_solved,
    share_url:   PH_SHARE_URL,
    time_str:    win_time_str,
    draw_recap:  win_draw_recap,
});

if (_already_solved) {
    var _tk = "wordle_time_" + global.selected_date_key;
    win_time_str = variable_struct_exists(global.save, _tk) ? global.save[$ _tk] : "--:--";
    win.cfg.time_str = win_time_str;
    win_phase = 1;
    ph_win_celebrate(win);
}
