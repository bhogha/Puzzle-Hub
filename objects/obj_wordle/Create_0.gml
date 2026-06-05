// ── obj_wordle — Create ───────────────────────────────────────────────────────
// Phase 2: playable core (6×6 board + custom keyboard + reveal + win).
// Hint (Phase 4) and the loss / lost-aversion flow (Phase 5) are added later.

accent = PH_COL_GREEN;

// ── Puzzle + session ──────────────────────────────────────────────────────────
puzzle           = ph_wordle_for_date(global.selected_date_key);
session_start_ms = current_time;

// Input / play state. The active (unsubmitted) row is slot-based so a hint can
// lock a single position (revealed correct letter) independent of typing order.
row_slots   = array_create(PH_WORDLE_LEN, "");    // letters currently in the active row
row_lock    = array_create(PH_WORDLE_LEN, false); // true where a hint has locked a correct letter
kbd_states  = {};                            // letter -> "green"/"yellow"/"gray" (keyboard tint)

// Restore in-progress / final state (resume mid-puzzle).
var _wst = ph_wordle_load_state(global.save, global.selected_date_key);
if (_wst != undefined) {
    puzzle.guesses      = ph_wordle_guesses_from_str(_wst.guesses);
    puzzle.extra_bought = _wst.extra;
    puzzle.max_guesses  = PH_WORDLE_GUESSES + (_wst.extra ? PH_WORDLE_EXTRA_MOVES : 0);
    puzzle.status       = _wst.status;
    kbd_states          = ph_wordle_keyboard_states(puzzle);
    if (variable_struct_exists(_wst, "hints") && _wst.hints != "") {
        var _hp = string_split(_wst.hints, ";");
        for (var _hi = 0; _hi < array_length(_hp); _hi++) {
            array_push(puzzle.hints, real(_hp[_hi]));
        }
    }
}

// Hint pill bounds (written by Draw each frame; read by Step).
HINT_PILL_L = 0; HINT_PILL_R = 0; HINT_PILL_T = 0; HINT_PILL_B = 0;

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

/// Persist the current play state (guesses, extra-moves, hint positions, status).
wd_save_state = function() {
    var _hs = "";
    for (var _i = 0; _i < array_length(puzzle.hints); _i++) {
        _hs += (_i > 0 ? ";" : "") + string(puzzle.hints[_i]);
    }
    ph_wordle_save_state(global.save, global.selected_date_key,
        ph_wordle_guesses_to_str(puzzle), puzzle.extra_bought, _hs, puzzle.status);
    ph_save_write(global.save);
};

// ── Active-row helpers (slot-based so hints can lock a position) ───────────────
/// Rebuild the active row: empty, then re-apply every revealed hint as a locked
/// correct letter. Called on (re)entry and after each submitted guess.
wd_reset_row = function() {
    row_slots = array_create(COLS, "");
    row_lock  = array_create(COLS, false);
    for (var _i = 0; _i < array_length(puzzle.hints); _i++) {
        var _pos = puzzle.hints[_i];
        row_slots[_pos] = string_char_at(puzzle.answer, _pos + 1);
        row_lock[_pos]  = true;
    }
};
/// True when every slot in the active row is filled.
wd_row_full = function() {
    for (var _i = 0; _i < COLS; _i++) if (row_slots[_i] == "") return false;
    return true;
};
/// The active row as a single uppercase string.
wd_row_string = function() {
    var _s = "";
    for (var _i = 0; _i < COLS; _i++) _s += row_slots[_i];
    return _s;
};

// ── Hint reveal + availability (shared hint flow, scr_hint) ───────────────────
/// Reveal the correct letter at the leftmost not-yet-revealed position, locking
/// it into the active row. Persists. Does NOT touch coins (the modal handles that).
wd_apply_hint = function() {
    for (var _i = 0; _i < COLS; _i++) {
        if (!row_lock[_i]) {
            array_push(puzzle.hints, _i);
            row_slots[_i] = string_char_at(puzzle.answer, _i + 1);
            row_lock[_i]  = true;
            wd_save_state();
            return;
        }
    }
};
/// True if a reveal is still possible (puzzle live and a position is unrevealed).
wd_can_hint = function() {
    if (puzzle.status != "in_progress") return false;
    for (var _i = 0; _i < COLS; _i++) if (!row_lock[_i]) return true;
    return false;
};
hint = ph_hint_create(wd_apply_hint, PH_COL_GREEN);

// ── Win bookkeeping — fires once when the answer is guessed ────────────────────
wd_check_win = function() {
    var _fin_s  = floor((current_time - session_start_ms) / 1000);
    var _fin_m  = _fin_s div 60;
    var _fin_ss = _fin_s mod 60;
    win_time_str = string(_fin_m) + ":" + ((_fin_ss < 10) ? "0" : "") + string(_fin_ss);
    global.save[$ "wordle_time_" + global.selected_date_key] = win_time_str;

    // Mark won (counts toward gift/streak automatically) + persist final state.
    ph_wordle_mark_done(global.save, global.selected_date_key);
    wd_save_state();

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
    // Prefer the player's actual guesses; on a bare review fall back to one green answer row.
    var _rows = puzzle.guesses;
    if (array_length(_rows) == 0) _rows = [ puzzle.answer ];
    var _nrows = max(array_length(_rows), 1);
    var _cell = floor(min(_bw / COLS, _bh / _nrows));
    var _gw = _cell * COLS, _gh = _cell * _nrows;
    var _ox = _cx - _gw/2, _oy = _top + (_bh - _gh)/2;
    for (var _r = 0; _r < _nrows; _r++) {
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

// ── Lose / lost-aversion flow (Phase 5) ───────────────────────────────────────
lose_phase     = "none";   // "none" | "aversion" | "confirm" | "screen"
lose_anim_t    = 0;
lose_time_str  = "0:00";
lose_claimed   = false;
lose_granted   = false;
emv_open       = false;     // extra-moves rewarded-video placeholder open
emv_timer      = 0;
lose_vid_open  = false;     // DOUBLE rewarded-video on the lose screen
lose_vid_timer = 0;
LOSE_VIDEO_X_DELAY = 300;
LOSE_RED  = make_color_rgb(229,100,90);
LOSE_DARK = make_color_rgb(150,40,35);
// button hit bounds (written by wd_lose_draw, read by wd_lose_input)
lb_buy={l:0,t:0,r:0,b:0}; lb_free={l:0,t:0,r:0,b:0}; lb_giveup={l:0,t:0,r:0,b:0}; lb_x={l:0,t:0,r:0,b:0};
lc_giveup={l:0,t:0,r:0,b:0}; lc_cancel={l:0,t:0,r:0,b:0};
ls_claim={l:0,t:0,r:0,b:0}; ls_double={l:0,t:0,r:0,b:0}; ls_back={l:0,t:0,r:0,b:0};

/// Record the miss (time + WORDLE_MISSED flag) and open the red lose screen.
wd_finalize_loss = function() {
    var _s = floor((current_time - session_start_ms) / 1000);
    lose_time_str = string(_s div 60) + ":" + (((_s mod 60) < 10) ? "0" : "") + string(_s mod 60);
    global.save[$ "wordle_time_" + global.selected_date_key] = lose_time_str;
    ph_wordle_mark_missed(global.save, global.selected_date_key);
    wd_save_state();
    lose_phase = "screen"; lose_anim_t = 0;
};
/// Out of guesses: offer the one-time lost-aversion modal, or finalize if the
/// extra-moves purchase was already used.
wd_enter_lose = function() {
    if (!puzzle.extra_bought) { lose_phase = "aversion"; lose_anim_t = 0; }
    else                      { wd_finalize_loss(); }
};
wd_buy_moves = function() {
    if (ph_spend_coins(global.save, PH_WORDLE_EXTRA_COST)) {
        ph_wordle_grant_extra_moves(puzzle);
        wd_reset_row(); wd_save_state();
        lose_phase = "none";
    } else {
        wd_toast("NOT ENOUGH COINS", PH_COL_PINK);
    }
};
wd_grant_free_moves = function() {
    ph_wordle_grant_extra_moves(puzzle);
    wd_reset_row(); wd_save_state();
    emv_open = false; lose_phase = "none";
};
/// Grant the consolation XP once (25, or 50 if doubled), routing any level-up to
/// the Level-Up reward screen (same deferral as the win claim).
wd_lose_claim = function(_amount) {
    if (lose_granted) { lose_claimed = true; return; }
    lose_granted = true;
    var _key = "wordle_" + global.selected_date_key;
    if (!ph_xp_claimed(global.save, _key)) {
        var _res = ph_grant_xp(global.save, _amount, false);
        ph_mark_xp_claimed(global.save, _key);
        if (_res.levels_gained > 0) {
            global.pending_levelup = { level: _res.new_level, base_reward: PH_COINS_PER_LEVEL };
        }
    }
    ph_save_write(global.save);
    lose_claimed = true;
};

wd_lose_step = function() {
    if (lose_anim_t < 1) lose_anim_t = min(1, lose_anim_t + 0.08);
    if (emv_open)      emv_timer++;
    if (lose_vid_open) lose_vid_timer++;
};

wd_lose_input = function() {
    if (!device_mouse_check_button_pressed(0, mb_left)) return;
    var _mx = device_mouse_x_to_gui(0);
    var _my = device_mouse_y_to_gui(0);
    var _xcx = PH_W - 90, _xcy = 90 + global.safe_top_gui, _xr = 46;

    // Rewarded-video placeholders consume taps while open.
    if (emv_open) {
        if (emv_timer >= LOSE_VIDEO_X_DELAY && ph_point_in_circle(_mx, _my, _xcx, _xcy, _xr)) wd_grant_free_moves();
        return;
    }
    if (lose_vid_open) {
        if (lose_vid_timer >= LOSE_VIDEO_X_DELAY && ph_point_in_circle(_mx, _my, _xcx, _xcy, _xr)) {
            lose_vid_open = false;
            wd_lose_claim(PH_WORDLE_GIVEUP_XP * 2);
        }
        return;
    }

    if (lose_phase == "aversion") {
        if (ph_point_in_rect(_mx,_my, lb_buy.l,lb_buy.t,lb_buy.r,lb_buy.b))       { wd_buy_moves(); return; }
        if (ph_point_in_rect(_mx,_my, lb_free.l,lb_free.t,lb_free.r,lb_free.b))    { emv_open = true; emv_timer = 0; return; }
        if (ph_point_in_rect(_mx,_my, lb_giveup.l,lb_giveup.t,lb_giveup.r,lb_giveup.b)
         || ph_point_in_rect(_mx,_my, lb_x.l,lb_x.t,lb_x.r,lb_x.b))               { lose_phase = "confirm"; lose_anim_t = 0; return; }
        return;
    }
    if (lose_phase == "confirm") {
        if (ph_point_in_rect(_mx,_my, lc_giveup.l,lc_giveup.t,lc_giveup.r,lc_giveup.b)) { wd_finalize_loss(); return; }
        if (ph_point_in_rect(_mx,_my, lc_cancel.l,lc_cancel.t,lc_cancel.r,lc_cancel.b)) { lose_phase = "aversion"; lose_anim_t = 0; return; }
        return;
    }
    if (lose_phase == "screen") {
        if (!lose_claimed) {
            if (ph_point_in_rect(_mx,_my, ls_claim.l,ls_claim.t,ls_claim.r,ls_claim.b))    { wd_lose_claim(PH_WORDLE_GIVEUP_XP); return; }
            if (ph_point_in_rect(_mx,_my, ls_double.l,ls_double.t,ls_double.r,ls_double.b)) { lose_vid_open = true; lose_vid_timer = 0; return; }
        } else {
            if (ph_point_in_rect(_mx,_my, ls_back.l,ls_back.t,ls_back.r,ls_back.b)) {
                global.input_locked_until = current_time + 200;
                room_goto(ph_levelup_pending() ? rm_win : rm_hub);
            }
        }
        return;
    }
};

wd_lose_draw = function() {
    var _st = global.safe_top_gui, _sb = global.safe_bottom_gui;

    if (lose_phase == "screen") {
        draw_set_color(LOSE_RED); draw_rectangle(0, 0, PH_W, PH_H, false);
        ph_draw_text(PH_W/2, 200 + _st, "UNLUCKY!", global.fnt_disp_lg, LOSE_DARK, fa_center, fa_middle);
        win_draw_recap(PH_W/2, 300 + _st, 520, 520);                       // mini guess grid
        ph_draw_text(PH_W/2, 980 + _st, "You finished todays", global.fnt_body_md, PH_COL_DARK, fa_center, fa_middle);
        ph_draw_text(PH_W/2, 1042 + _st, "WORDLE",            global.fnt_disp_md, c_white,     fa_center, fa_middle);
        var _ty = 1140 + _st;
        ph_draw_chip(PH_W/2-150, _ty-40, PH_W/2+150, _ty+40, 40, PH_COL_WHITE, LOSE_DARK, 6);
        draw_sprite_ext(global.spr_stopwatch, 0, PH_W/2-95, _ty, 120/512, 120/512, 0, c_white, 1);
        ph_draw_text(PH_W/2-30, _ty, lose_time_str, global.fnt_body_md, PH_COL_DARK, fa_left, fa_middle);
        // level progress bar
        var _by = 1300 + _st, _bl = 140, _br = PH_W - 140;
        var _frac = ph_xp_in_level(global.save.xp) / PH_XP_PER_LEVEL;
        draw_set_color(make_color_rgb(206,184,180)); draw_roundrect_ext(_bl, _by-26, _br, _by+26, 26, 26, false);
        draw_set_color(PH_COL_PURPLE);               draw_roundrect_ext(_bl, _by-26, _bl + (_br-_bl)*_frac, _by+26, 26, 26, false);
        // reward area
        var _ay = PH_H - 240 - _sb;
        if (!lose_claimed) {
            ph_draw_text(PH_W/2, _ay-92, "Claim your reward", global.fnt_disp_md, LOSE_DARK, fa_center, fa_middle);
            ls_claim = {l:120, t:_ay-50, r:PH_W/2-25, b:_ay+50};
            ph_draw_chip(ls_claim.l, ls_claim.t, ls_claim.r, ls_claim.b, 50, PH_COL_WHITE, LOSE_DARK, 6);
            ph_draw_text((ls_claim.l+ls_claim.r)/2-24, _ay, string(PH_WORDLE_GIVEUP_XP), global.fnt_disp_md, PH_COL_DARK, fa_center, fa_middle);
            draw_sprite_ext(global.spr_star3d, 0, (ls_claim.l+ls_claim.r)/2+56, _ay, 110/512, 110/512, 0, c_white, 1);
            ls_double = {l:PH_W/2+25, t:_ay-50, r:PH_W-120, b:_ay+50};
            ph_draw_chip(ls_double.l, ls_double.t, ls_double.r, ls_double.b, 50, PH_COL_WHITE, LOSE_DARK, 6);
            ph_draw_text((ls_double.l+ls_double.r)/2-30, _ay, "DOUBLE", global.fnt_body_md, PH_COL_DARK, fa_center, fa_middle);
            draw_sprite_ext(global.spr_tv, 0, (ls_double.l+ls_double.r)/2+78, _ay, 104/512, 104/512, 0, c_white, 1);
        } else {
            ls_back = {l:PH_W/2-280, t:_ay-50, r:PH_W/2+280, b:_ay+50};
            ph_draw_chip(ls_back.l, ls_back.t, ls_back.r, ls_back.b, 50, PH_COL_DARK, make_color_rgb(20,20,20), 6);
            ph_draw_text(PH_W/2, _ay, "BACK TO HUB", global.fnt_disp_md, PH_COL_WHITE, fa_center, fa_middle);
        }
        if (lose_vid_open) ph_video_overlay(lose_vid_timer, LOSE_VIDEO_X_DELAY, PH_COL_GREEN);
        return;
    }

    // aversion / confirm: dim backdrop + bottom sheet over the (lost) board
    draw_set_alpha(0.55); draw_set_color(c_black); draw_rectangle(0, 0, PH_W, PH_H, false); draw_set_alpha(1);
    var _sb_top = PH_H - 790 - _sb;
    var _sb_bot = PH_H - 30  - _sb;
    var _slide  = lerp(PH_H, _sb_top, ph_ease_out(lose_anim_t));
    var _dy     = _slide - _sb_top;
    var _sheet_col = (lose_phase == "aversion") ? PH_COL_YELLOW_SOFT : make_color_rgb(255,243,205);
    ph_draw_rounded(40, _sb_top + _dy, PH_W-40, _sb_bot + _dy + 40, 48, _sheet_col);

    if (lose_phase == "aversion") {
        // close X (top-right of sheet)
        var _xc = PH_W - 100, _xy = _sb_top + 70 + _dy;
        lb_x = {l:_xc-46, t:_xy-46, r:_xc+46, b:_xy+46};
        draw_set_color(PH_COL_PINK); draw_circle(_xc, _xy, 46, false);
        ph_draw_text(_xc, _xy, "X", global.fnt_body_md, PH_COL_WHITE, fa_center, fa_middle);

        ph_draw_text(PH_W/2, _sb_top + 230 + _dy, "You can still win!", global.fnt_disp_lg, PH_COL_DARK, fa_center, fa_middle);
        ph_draw_text(PH_W/2, _sb_top + 320 + _dy, "Get " + string(PH_WORDLE_EXTRA_MOVES) + " more moves to solve the puzzle",
                     global.fnt_body_md, PH_COL_INK_SOFT, fa_center, fa_middle);

        var _by = _sb_top + 480 + _dy;
        lb_buy  = {l:90,        t:_by-58, r:PH_W/2-20, b:_by+58};
        lb_free = {l:PH_W/2+20, t:_by-58, r:PH_W-90,   b:_by+58};
        ph_draw_chip(lb_buy.l, lb_buy.t, lb_buy.r, lb_buy.b, 58, PH_COL_WHITE, make_color_rgb(190,170,120), 6);
        ph_draw_text((lb_buy.l+lb_buy.r)/2-30, _by, string(PH_WORDLE_EXTRA_COST), global.fnt_disp_md, PH_COL_DARK, fa_center, fa_middle);
        draw_sprite_ext(global.spr_gold_coin, 0, (lb_buy.l+lb_buy.r)/2+60, _by, 120/512, 120/512, 0, c_white, 1);
        ph_draw_chip(lb_free.l, lb_free.t, lb_free.r, lb_free.b, 58, PH_COL_WHITE, make_color_rgb(190,170,120), 6);
        ph_draw_text((lb_free.l+lb_free.r)/2-30, _by, "FREE", global.fnt_body_md, PH_COL_DARK, fa_center, fa_middle);
        draw_sprite_ext(global.spr_tv, 0, (lb_free.l+lb_free.r)/2+70, _by, 104/512, 104/512, 0, c_white, 1);

        var _gy = _sb_bot + _dy - 40;
        lb_giveup = {l:PH_W/2-130, t:_gy-40, r:PH_W/2+130, b:_gy+40};
        ph_draw_text(PH_W/2, _gy, "Give up", global.fnt_body_md, PH_COL_INK_SOFT, fa_center, fa_middle);

        if (emv_open) ph_video_overlay(emv_timer, LOSE_VIDEO_X_DELAY, PH_COL_GREEN);

    } else { // confirm
        ph_draw_text(PH_W/2, _sb_top + 250 + _dy, "Giving up?", global.fnt_disp_lg, PH_COL_DARK, fa_center, fa_middle);
        ph_draw_text(PH_W/2, _sb_top + 340 + _dy, "Are you sure you want to give up this time?",
                     global.fnt_body_md, PH_COL_INK_SOFT, fa_center, fa_middle);
        var _by = _sb_top + 520 + _dy;
        lc_giveup = {l:90,        t:_by-58, r:PH_W/2-20, b:_by+58};
        lc_cancel = {l:PH_W/2+20, t:_by-58, r:PH_W-90,   b:_by+58};
        ph_draw_chip(lc_giveup.l, lc_giveup.t, lc_giveup.r, lc_giveup.b, 58, PH_COL_PINK,  PH_COL_PINK_DEEP, 6);
        ph_draw_text((lc_giveup.l+lc_giveup.r)/2, _by, "Give up", global.fnt_disp_md, PH_COL_WHITE, fa_center, fa_middle);
        ph_draw_chip(lc_cancel.l, lc_cancel.t, lc_cancel.r, lc_cancel.b, 58, PH_COL_GREEN, PH_COL_GREEN_DEEP, 6);
        ph_draw_text((lc_cancel.l+lc_cancel.r)/2, _by, "Cancel", global.fnt_disp_md, PH_COL_WHITE, fa_center, fa_middle);
    }
};

// ── Review / solved re-entry ──────────────────────────────────────────────────
var _review = variable_global_exists("wordle_review_mode") && global.wordle_review_mode;
if (_review) global.wordle_review_mode = false;
var _already_solved = _review || ph_wordle_is_done(global.save, global.selected_date_key) || puzzle.status == "won";

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

// Build the active row from any restored hint positions (must run after methods
// are defined and the puzzle/hints are restored).
wd_reset_row();

// Resume into the correct lose state if the restored game was already lost.
if (!_already_solved && puzzle.status == "lost") {
    if (ph_wordle_is_missed(global.save, global.selected_date_key)) {
        // Already gave up / finalized — reopen the red lose screen.
        var _ltk = "wordle_time_" + global.selected_date_key;
        lose_time_str = variable_struct_exists(global.save, _ltk) ? global.save[$ _ltk] : "--:--";
        lose_phase = "screen"; lose_anim_t = 1;
        if (ph_xp_claimed(global.save, "wordle_" + global.selected_date_key)) {
            lose_granted = true; lose_claimed = true;
        }
    } else {
        // Ran out of guesses but hadn't decided yet — reopen the aversion modal.
        wd_enter_lose(); lose_anim_t = 1;
    }
}
