// ── obj_ladder — Create ───────────────────────────────────────────────────────
// Word Ladder ("Ladder"): one word row + clue + custom letters-only keyboard.
// Tap a tile to select it, type a key to replace that letter; matching the step's
// target word advances the ladder. No loss state. Accent = amber (#ffc04c).

accent = PH_COL_AMBER;

// ── Puzzle + session ──────────────────────────────────────────────────────────
puzzle           = ph_ladder_for_date(global.selected_date_key);
timer_key        = "ladder_" + global.selected_date_key;
timer_base_secs  = ph_timer_get(global.save, timer_key);
session_start_ms = current_time;

// ── Play state ────────────────────────────────────────────────────────────────
step    = 0;                 // words found so far (0..count); progress = step+1
sel     = -1;                // selected tile index (-1 none)
hinted  = -1;                // tile index with an active hint highlight (-1 none)
solved  = false;             // all `count` words found

// Restore in-progress state (resume mid-puzzle).
var _lst = ph_ladder_load_state(global.save, global.selected_date_key);
if (_lst != undefined) {
    step   = clamp(_lst.step, 0, puzzle.count);
    hinted = variable_struct_exists(_lst, "hinted") ? _lst.hinted : -1;
}
if (step >= puzzle.count) solved = true;

// The word currently shown, as a per-letter array (mutable while typing).
ld_load_word = function() {
    var _w = ph_ladder_current_word(puzzle, step);
    letters = array_create(puzzle.length, "");
    for (var _i = 0; _i < puzzle.length; _i++) letters[_i] = string_char_at(_w, _i + 1);
};
letters = array_create(puzzle.length, "");
ld_load_word();

// Feedback flash: "none" | "correct" | "wrong" with a frame timer.
feedback   = "none";
fb_timer   = 0;
FB_DUR     = 32;

// Toast / message prompt (shared style).
toast_text  = "";
toast_col   = PH_COL_GRAY;
toast_timer = 0;
TOAST_DUR   = 90;
ld_toast = function(_text, _col) { toast_text = _text; toast_col = _col; toast_timer = TOAST_DUR; };

// Win flow
win_phase    = 0;
win_time_str = "0:00";
coins_bonus  = 0;

// ── Layout ────────────────────────────────────────────────────────────────────
HUD_Y = 95 + global.safe_top_gui;

// Word row: tiles sized to fit the day's word length within the play width.
N        = puzzle.length;
TILE_GAP = 22;
TILE     = min(190, floor((PH_W - 140 - (N - 1) * TILE_GAP) / N));
ROW_W    = N * TILE + (N - 1) * TILE_GAP;
row_x    = (PH_W - ROW_W) div 2;
TIP_Y    = HUD_Y + 360;              // game-tip / toast line
row_y    = TIP_Y + 200;              // word-row top (upper-middle band)

// Keyboard (letters only — no DEL / SEND).
KEY_W = 94; KEY_H = 120; KEY_GAP = 10; KEY_ROW_GAP = 16;
kb_rows = ["QWERTYUIOP", "ASDFGHJKL", "ZXCVBNM"];
var _kb_h = 3 * KEY_H + 2 * KEY_ROW_GAP;

// Bottom-anchored cluster: keyboard above the bottom bar; clue box above the
// keyboard; progress line above the clue box.
var _bar_y   = PH_H - 110 - global.safe_bottom_gui;
KB_TOP       = _bar_y - 75 - _kb_h;
CLUE_H       = 230;
CLUE_BOT     = KB_TOP - 70;
CLUE_TOP     = CLUE_BOT - CLUE_H;
CLUE_L       = 60;
CLUE_R       = PH_W - 60;
PROG_Y       = CLUE_TOP - 64;        // "N/10" progress line, centred above the clue

/// Build the keyboard key rects (shared by Step + Draw). Letters only.
ld_build_keys = function() {
    var _keys = [];
    for (var _r = 0; _r < 3; _r++) {
        var _row  = kb_rows[_r];
        var _ncol = string_length(_row);
        var _roww = _ncol * KEY_W + (_ncol - 1) * KEY_GAP;
        var _x = (PH_W - _roww) / 2;
        var _y = KB_TOP + _r * (KEY_H + KEY_ROW_GAP);
        for (var _c = 0; _c < _ncol; _c++) {
            var _ch = string_char_at(_row, _c + 1);
            array_push(_keys, { ch:_ch, x1:_x, y1:_y, x2:_x + KEY_W, y2:_y + KEY_H });
            _x += KEY_W + KEY_GAP;
        }
    }
    return _keys;
};

// Hint pill bounds (written by Draw, read by Step).
HINT_PILL_L = 0; HINT_PILL_R = 0; HINT_PILL_T = 0; HINT_PILL_B = 0;

// ── Persistence ───────────────────────────────────────────────────────────────
ld_save_state = function() {
    ph_ladder_save_state(global.save, global.selected_date_key, step, hinted);
    ph_save_write(global.save);
};

// ── Hint: highlight the tile that must change (the differing position) ─────────
ld_apply_hint = function() {
    if (solved) return;
    var _target = puzzle.words[step];
    var _cur    = ph_ladder_current_word(puzzle, step);
    hinted = ph_ladder_diff_pos(_cur, _target);
    ld_save_state();
};
ld_can_hint = function() {
    return (!solved && hinted < 0);
};
hint = ph_hint_create(ld_apply_hint, PH_COL_AMBER);

// ── Advance / evaluate ────────────────────────────────────────────────────────
/// The current row letters joined into a word.
ld_row_string = function() {
    var _s = "";
    for (var _i = 0; _i < N; _i++) _s += letters[_i];
    return _s;
};
/// Called after the correct-flash finishes: lock the word in, move to the next
/// rung (or win), reset the row to the new current word.
ld_advance = function() {
    step += 1;
    sel    = -1;
    hinted = -1;
    if (step >= puzzle.count) {
        solved = true;
        ld_save_state();
        ld_check_win();
    } else {
        ld_load_word();
        ld_save_state();
    }
};

// ── Win bookkeeping — fires once when the last word is found ───────────────────
ld_check_win = function() {
    var _fin_s  = ph_timer_now(timer_base_secs, session_start_ms);
    var _fin_m  = _fin_s div 60;
    var _fin_ss = _fin_s mod 60;
    win_time_str = string(_fin_m) + ":" + ((_fin_ss < 10) ? "0" : "") + string(_fin_ss);
    global.save[$ "ladder_time_" + global.selected_date_key] = win_time_str;

    ph_ladder_mark_done(global.save, global.selected_date_key);

    // NOTE: the 100 XP solve reward (and its deferred level-up coins) is granted by
    // the shared Win Screen's CLAIM button via claim_key — NOT here — so it isn't
    // double-counted (mirrors every other puzzle's *_check_win).

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

// ── Win recap: the full solved ladder as a stack of small green tiles ─────────
win_draw_recap = function(_cx, _top, _bw, _bh) {
    var _chain = array_create(puzzle.count + 1);
    _chain[0] = puzzle.start;
    for (var _i = 0; _i < puzzle.count; _i++) _chain[_i + 1] = puzzle.words[_i];
    var _nrows = array_length(_chain);
    var _cell  = floor(min(_bw / puzzle.length, _bh / _nrows));
    var _gw = _cell * puzzle.length, _gh = _cell * _nrows;
    var _ox = _cx - _gw / 2, _oy = _top + (_bh - _gh) / 2;
    for (var _r = 0; _r < _nrows; _r++) {
        var _w = _chain[_r];
        for (var _c = 0; _c < puzzle.length; _c++) {
            var _x = _ox + _c * _cell, _y = _oy + _r * _cell;
            draw_set_color((_r == 0) ? PH_COL_BOARD_BG : PH_COL_WB_FOUND);
            draw_roundrect_ext(_x + 2, _y + 2, _x + _cell - 2, _y + _cell - 2, 6, 6, false);
            ph_draw_text(_x + _cell / 2, _y + _cell / 2, string_char_at(_w, _c + 1),
                         global.fnt_body_md, PH_COL_DARK, fa_center, fa_middle);
        }
    }
};

// ── Review / solved re-entry ──────────────────────────────────────────────────
var _review = variable_global_exists("ladder_review_mode") && global.ladder_review_mode;
if (_review) global.ladder_review_mode = false;
var _already_solved = _review || ph_ladder_is_done(global.save, global.selected_date_key) || solved;

win = ph_win_create({
    puzzle_name: "LADDER",
    title_col:   PH_COL_AMBER,
    bg_col:      PH_COL_AMBER,
    claim_key:   "ladder_" + global.selected_date_key,
    already:     _already_solved,
    share_url:   PH_SHARE_URL,
    time_str:    win_time_str,
    draw_recap:  win_draw_recap,
});

if (_already_solved) {
    solved = true;
    step   = puzzle.count;
    var _tk = "ladder_time_" + global.selected_date_key;
    win_time_str = variable_struct_exists(global.save, _tk) ? global.save[$ _tk] : "--:--";
    win.cfg.time_str = win_time_str;
    win_phase = 1;
    ph_win_celebrate(win);
}
