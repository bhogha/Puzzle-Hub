// ── obj_wordle — Create ───────────────────────────────────────────────────────
// Phase 2: playable core (6×6 board + custom keyboard + reveal + win).
// Hint (Phase 4) and the loss / lost-aversion flow (Phase 5) are added later.

accent = PH_COL_GREEN;

// ── Puzzle + session ──────────────────────────────────────────────────────────
puzzle           = ph_wordle_for_date(global.selected_date_key);
timer_key        = "wordle_" + global.selected_date_key;
timer_base_secs  = ph_timer_get(global.save, timer_key);
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

// Keyboard press feedback: the last-tapped key darkens for a few frames.
// Tag = the letter char, or the key type ("del"/"send") for the action keys.
key_press_tag = "";
key_press_t   = 0;
KEY_PRESS_DUR = 9;

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

// Bottom-anchor the board + keyboard cluster just above the bottom bar instead of
// top-anchoring under the HUD. KB_TOP (below) derives from grid_y, so the whole
// keyboard follows. Keyboard height = 3 letter rows + 1 space/enter row.
var _kb_h       = 3 * (KEY_H + KEY_ROW_GAP) + KEY_H;
var _cluster_h  = GRID_H + 60 + _kb_h;
var _target_bot = PH_H - global.safe_bottom_gui - 155 - PH_PLAY_BOTTOM_GAP;
grid_y += max(0, _target_bot - (grid_y + _cluster_h));

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
hint = ph_hint_create(wd_apply_hint, PH_COL_GREEN, "This hint will reveal the\nnext correct letter", "wordle_" + global.selected_date_key);

// ── Win bookkeeping — fires once when the answer is guessed ────────────────────
wd_check_win = function() {
    var _fin_s  = ph_timer_now(timer_base_secs, session_start_ms);
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
// Boxing-glove rotation (deg). The aversion→confirm switch keeps the sheet in
// place and just spins the glove 180° while the text/buttons swap; cancel spins
// it back. Animated from _from→_to over _t (0..1).
glove_rot      = 0;
glove_rot_from = 0;
glove_rot_to   = 0;
glove_rot_t    = 1;        // 1 = settled
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

// Claim star-flight animation (mirrors the win screen): on claim, stars fly from
// the reward button up to the bar's star badge while the bar fills, then the HOME
// button appears.
lose_claiming    = false;
lose_claim_t     = 1;                            // 0..1 during the flight
lose_stars       = [];
lose_xp_from     = ph_xp_in_level(global.save.xp);
lose_xp_to       = ph_xp_in_level(global.save.xp);
lose_xp_anim_t   = 1;
lose_bar_star_x  = 168;  lose_bar_star_y  = 0;   // fly target (set by draw)
lose_claim_src_x = PH_W/2; lose_claim_src_y = 0; // fly origin (set by draw)

/// Record the miss (time + WORDLE_MISSED flag) and open the red lose screen.
wd_finalize_loss = function() {
    var _s = ph_timer_now(timer_base_secs, session_start_ms);
    lose_time_str = string(_s div 60) + ":" + (((_s mod 60) < 10) ? "0" : "") + string(_s mod 60);
    global.save[$ "wordle_time_" + global.selected_date_key] = lose_time_str;
    ph_wordle_mark_missed(global.save, global.selected_date_key); ph_week_record_wordle_miss(global.save);
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
    lose_xp_from = ph_xp_in_level(global.save.xp);
    var _key = "wordle_" + global.selected_date_key;
    if (!ph_xp_claimed(global.save, _key)) {
        var _res = ph_grant_xp(global.save, _amount, false);
        ph_mark_xp_claimed(global.save, _key);
        if (_res.levels_gained > 0) {
            global.pending_levelup = { level: _res.new_level, base_reward: PH_COINS_PER_LEVEL };
            lose_xp_to = PH_XP_PER_LEVEL;                    // fill to full; Level-Up screen continues
        } else {
            lose_xp_to = ph_xp_in_level(global.save.xp);
        }
    } else {
        lose_xp_to = ph_xp_in_level(global.save.xp);
    }
    ph_save_write(global.save);

    // Start the star flight → the HOME button appears when it completes.
    lose_claiming  = true;
    lose_claim_t   = 0;
    lose_xp_anim_t = 0;
    lose_stars     = [];
    for (var _i = 0; _i < 14; _i++) {
        array_push(lose_stars, {
            t:  -_i * 0.05,
            x:  lose_claim_src_x + random_range(-30, 30),
            y:  lose_claim_src_y + random_range(-20, 20),
            tx: lose_bar_star_x,
            ty: lose_bar_star_y,
            sz: 0.10 + random(0.06),
        });
    }
};

/// Begin spinning the glove toward _deg (0 = upright, 180 = upside-down).
wd_glove_spin_to = function(_deg) {
    glove_rot_from = glove_rot;
    glove_rot_to   = _deg;
    glove_rot_t    = 0;
};

wd_lose_step = function() {
    if (lose_anim_t < 1) lose_anim_t = min(1, lose_anim_t + 0.08);
    if (emv_open)      emv_timer++;
    if (lose_vid_open) lose_vid_timer++;

    if (glove_rot_t < 1) {
        glove_rot_t = min(1, glove_rot_t + 1/16);
        glove_rot   = lerp(glove_rot_from, glove_rot_to, ph_ease_out(glove_rot_t));
    }

    if (lose_claiming) {
        lose_claim_t = min(1, lose_claim_t + 1/45);
        for (var _i = 0; _i < array_length(lose_stars); _i++) lose_stars[_i].t += 1/18;
        lose_xp_anim_t = clamp((lose_claim_t - 0.30) / 0.70, 0, 1);
        if (lose_claim_t >= 1) { lose_claiming = false; lose_claimed = true; }
    }
};

wd_lose_input = function() {
    if (lose_claiming) return;                       // taps are inert during the star flight
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
         || ph_point_in_rect(_mx,_my, lb_x.l,lb_x.t,lb_x.r,lb_x.b))               { lose_phase = "confirm"; wd_glove_spin_to(180); return; }   // sheet stays; spin the glove
        return;
    }
    if (lose_phase == "confirm") {
        if (ph_point_in_rect(_mx,_my, lc_giveup.l,lc_giveup.t,lc_giveup.r,lc_giveup.b)) { wd_finalize_loss(); return; }
        if (ph_point_in_rect(_mx,_my, lc_cancel.l,lc_cancel.t,lc_cancel.r,lc_cancel.b)) { lose_phase = "aversion"; wd_glove_spin_to(0); return; }     // spin back upright
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

        // Responsive vertical flow (mirrors the shared win screen):
        //   TITLE · RECAP · "Completed in [time]" · "Claim your reward!" ·
        //   amount ("25 ⭐") · XP bar · CLAIM | DOUBLE (or HOME once claimed).
        var _avail = PH_H - _st - _sb;
        var _H_TITLE = 180, _H_COMPLETED = 100, _H_CLAIM = 90, _H_AMT = 120, _H_BAR = 120, _H_BTN = 150;
        var _GAP0 = 20, _NGAP = 6;
        var _fixed   = _H_TITLE + _H_COMPLETED + _H_CLAIM + _H_AMT + _H_BAR + _H_BTN;
        var _recap_h = clamp(_avail - _fixed - _GAP0*_NGAP, 220, 560);
        var _recap_w = min(520, _recap_h);
        var _gap     = _GAP0 + max(0, _avail - _fixed - _recap_h - _GAP0*_NGAP) / _NGAP;

        var _fy = _st;
        var _title_cy     = _fy + _H_TITLE/2;     _fy += _H_TITLE     + _gap;
        var _recap_top    = _fy;                  _fy += _recap_h     + _gap;
        var _completed_cy = _fy + _H_COMPLETED/2; _fy += _H_COMPLETED + _gap;
        var _claim_cy     = _fy + _H_CLAIM/2;     _fy += _H_CLAIM     + _gap;
        var _amt_cy       = _fy + _H_AMT/2;       _fy += _H_AMT       + _gap;
        var _by           = _fy + 60;             _fy += _H_BAR       + _gap;
        var _ay           = _fy + _H_BTN/2;

        ph_draw_text(PH_W/2, _title_cy, "UNLUCKY!", global.fnt_disp_xxl, LOSE_DARK, fa_center, fa_middle);
        win_draw_recap(PH_W/2, _recap_top, _recap_w, _recap_h);            // mini guess grid

        // "Completed in  [stopwatch] mm:ss" — single centred line.
        draw_set_font(global.fnt_body_reg);
        var _clbl = "Completed in", _clw = string_width(_clbl);
        var _pillw = 250, _lpgap = 28;
        var _grpx = PH_W/2 - (_clw + _lpgap + _pillw)/2;
        ph_draw_text(_grpx, _completed_cy, _clbl, global.fnt_body_reg, PH_COL_DARK, fa_left, fa_middle);
        var _pl = _grpx + _clw + _lpgap, _pr = _pl + _pillw;
        ph_draw_chip(_pl, _completed_cy-38, _pr, _completed_cy+38, 38, PH_COL_WHITE, make_color_rgb(190,170,155), 6);
        draw_sprite_ext(global.spr_stopwatch, 0, _pl+48, _completed_cy, 150/512, 150/512, 0, c_white, 1);
        ph_draw_text(_pl+96, _completed_cy, lose_time_str, global.fnt_body_lg, PH_COL_DARK, fa_left, fa_middle);

        // Level progress bar — grey track, purple fill, "xp / 500" count above-right,
        // oversized star level badge. The fill animates from the pre-claim snapshot.
        var _bl = 150, _br = PH_W - 140, _bh = 70;
        var _disp;
        if      (lose_claiming) _disp = lerp(lose_xp_from, lose_xp_to, ph_ease_out(lose_xp_anim_t));
        else if (lose_claimed)  _disp = lose_xp_to;
        else                    _disp = ph_xp_in_level(global.save.xp);
        ph_draw_text(_br, _by - 78, string(round(_disp)) + " / " + string(PH_XP_PER_LEVEL),
                     global.fnt_body_md, PH_COL_GRAY, fa_right, fa_middle);
        ph_draw_rounded(_bl, _by-_bh/2, _br, _by+_bh/2, _bh/2, make_color_rgb(220,210,205));
        var _frac = clamp(_disp / PH_XP_PER_LEVEL, 0, 1);
        var _fw   = floor((_br - _bl) * _frac);
        if (_fw > _bh) ph_draw_rounded(_bl, _by-_bh/2, _bl+_fw, _by+_bh/2, _bh/2, PH_COL_PURPLE);
        var _lvl     = ph_level_from_xp(global.save.xp);
        var _badge_x = _bl + 18;
        draw_sprite_ext(global.spr_star, 0, _badge_x, _by, 200/512, 200/512, 0, c_white, 1);
        ph_draw_text(_badge_x, _by, string(_lvl), global.fnt_disp_lg, PH_COL_WHITE, fa_center, fa_middle);
        lose_bar_star_x = _badge_x;  lose_bar_star_y = _by;   // star-flight target

        // ── Reward area ────────────────────────────────────────────────────────
        lose_claim_src_x = PH_W/2;  lose_claim_src_y = _ay;   // star-flight origin
        if (!lose_claimed && !lose_claiming) {
            ph_draw_text(PH_W/2, _claim_cy, "Claim your reward!", global.fnt_body_semi, LOSE_DARK, fa_center, fa_middle);
            // Reward amount: "<amount>  ⭐"  (large Nunito number + 3D star icon).
            var _amt_str = string(PH_WORDLE_GIVEUP_XP);
            draw_set_font(global.fnt_num_xl);
            var _anw = string_width(_amt_str);
            var _astar = 130, _agap = 24;
            var _ax0 = PH_W/2 - (_anw + _agap + _astar)/2;
            ph_draw_text(_ax0 + _anw/2, _amt_cy, _amt_str, global.fnt_num_xl, PH_COL_DARK, fa_center, fa_middle);
            draw_sprite_ext(global.spr_star3d, 0, _ax0 + _anw + _agap + _astar/2, _amt_cy, _astar/256, _astar/256, 0, c_white, 1);
            // CLAIM | DOUBLE (rewarded video → doubles the consolation XP).
            ls_claim  = {l:70,        t:_ay-55, r:PH_W/2-15, b:_ay+55};
            ph_draw_reward_btn(ls_claim.l, _ay, ls_claim.r, 55, "CLAIM",  noone, false);
            ls_double = {l:PH_W/2+15,  t:_ay-55, r:PH_W-70,   b:_ay+55};
            ph_draw_reward_btn(ls_double.l, _ay, ls_double.r, 55, "DOUBLE", noone, true);
        } else if (lose_claiming) {
            // Flying stars from the reward button up to the bar's star badge.
            for (var _si = 0; _si < array_length(lose_stars); _si++) {
                var _s = lose_stars[_si];
                if (_s.t < 0) continue;
                var _e  = ph_ease_out(clamp(_s.t, 0, 1));
                var _sx = lerp(_s.x, _s.tx, _e);
                var _sy = lerp(_s.y, _s.ty, _e) - sin(min(_s.t,1) * pi) * 90;
                var _sa = (_s.t > 0.85) ? (1 - (_s.t - 0.85)/0.15) : 1;
                draw_sprite_ext(global.spr_star, 0, _sx, _sy, _s.sz, _s.sz, 0, c_white, _sa);
            }
        } else {
            // Claimed → blue HOME button (matches the win screen).
            ls_back = {l:PH_W/2-280, t:_ay-55, r:PH_W/2+280, b:_ay+55};
            ph_draw_nav_btn(ls_back.l, _ay, ls_back.r, 55, "HOME", global.spr_home, noone, noone);
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

    // Boxing-glove mascot above the title (overflows the sheet top, like the hint
    // bulb). Spins 180° on the aversion↔confirm switch (glove_rot, animated in Step)
    // so "Giving up?" shows it upside-down without re-sliding the sheet.
    draw_sprite_ext(global.spr_boxing_glove, 0, PH_W/2, _sb_top + 95 + _dy, 0.60, 0.60, glove_rot, c_white, 1);

    if (lose_phase == "aversion") {
        // close X (top-right of sheet)
        var _xc = PH_W - 100, _xy = _sb_top + 70 + _dy;
        lb_x = {l:_xc-46, t:_xy-46, r:_xc+46, b:_xy+46};
        draw_set_color(PH_COL_PINK); draw_circle(_xc, _xy, 46, false);
        ph_draw_text(_xc, _xy, "X", global.fnt_body_md, PH_COL_WHITE, fa_center, fa_middle);

        ph_draw_text(PH_W/2, _sb_top + 225 + _dy, "You can still win!", global.fnt_disp_lg, PH_COL_DARK, fa_center, fa_middle);
        ph_draw_text(PH_W/2, _sb_top + 315 + _dy, "Get " + string(PH_WORDLE_EXTRA_MOVES) + " more moves to solve the puzzle",
                     global.fnt_body_md, PH_COL_INK_SOFT, fa_center, fa_middle);

        // Cost amount: "<cost>  🪙" (large Nunito number + gold coin) above the buttons.
        var _amt_cy = _sb_top + 430 + _dy;
        var _amt    = string(PH_WORDLE_EXTRA_COST);
        draw_set_font(global.fnt_num_xl);
        var _anw    = string_width(_amt);
        var _acoin  = 110, _agap = 22;
        var _ax0    = PH_W/2 - (_anw + _agap + _acoin)/2;
        ph_draw_text(_ax0 + _anw/2, _amt_cy, _amt, global.fnt_num_xl, PH_COL_DARK, fa_center, fa_middle);
        draw_sprite_ext(global.spr_gold_coin, 0, _ax0 + _anw + _agap + _acoin/2, _amt_cy, _acoin/256, _acoin/256, 0, c_white, 1);

        var _by = _sb_top + 560 + _dy;
        lb_buy  = {l:90,        t:_by-58, r:PH_W/2-20, b:_by+58};
        lb_free = {l:PH_W/2+20, t:_by-58, r:PH_W-90,   b:_by+58};
        // Green reward buttons (uniform with the blue claim buttons), per the design —
        // bare BUY label (price moved to its own row) | FREE + retro TV.
        ph_draw_reward_btn(lb_buy.l,  _by, lb_buy.r,  58, "BUY",  noone,         false, PH_COL_GREEN, PH_COL_GREEN_DEEP);
        ph_draw_reward_btn(lb_free.l, _by, lb_free.r, 58, "FREE", global.spr_tv, false, PH_COL_GREEN, PH_COL_GREEN_DEEP);

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
        // GIVE UP (red) + CANCEL (blue) — uniform nav buttons, Nunito Bold, per design.
        ph_draw_nav_btn(lc_giveup.l, _by, lc_giveup.r, 58, "GIVE UP", noone, make_color_rgb(235,90,90), make_color_rgb(190,55,55));
        ph_draw_nav_btn(lc_cancel.l, _by, lc_cancel.r, 58, "CANCEL", noone, noone, noone);
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
