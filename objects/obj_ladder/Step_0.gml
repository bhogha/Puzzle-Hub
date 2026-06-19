// ── obj_ladder — Step ─────────────────────────────────────────────────────────
// Tile selection, keyboard input, correct/wrong feedback, hint, win flow.

// ── Win screen owns the frame when complete ───────────────────────────────────
if (win_phase == 1) {
    ph_win_step(win);
    ph_win_input(win);
    exit;
}

if (toast_timer > 0)   toast_timer--;
if (pen_t > 0)         pen_t--;
if (key_press_t > 0)   key_press_t--;

// Advance the shared hint-flow timers (modal slide / "-100" / video).
ph_hint_tick(hint);

// Persist the play timer (≤ once/sec) while the puzzle is still live.
if (!solved)
    ph_timer_step(global.save, timer_key, timer_base_secs, session_start_ms);

// ── Feedback flash: hold input, then resolve ──────────────────────────────────
if (feedback != "none") {
    fb_timer--;
    if (fb_timer <= 0) {
        if (feedback == "correct") {
            feedback = "none";
            ld_advance();              // lock word in, move to next rung (or win)
        } else {
            // wrong → revert the row to the current word, clear selection
            feedback = "none";
            ld_load_word();
            sel = -1;
        }
    }
    exit;
}

if (current_time < global.input_locked_until) exit;
if (!device_mouse_check_button_pressed(0, mb_left)) exit;

var _mx = device_mouse_x_to_gui(0);
var _my = device_mouse_y_to_gui(0);

// Hint overlay (modal + placeholder video) eats taps while open.
var _hr = ph_hint_input(hint);
if (_hr != "none") {
    if      (_hr == "paid")  ld_toast("HINT USED  -" + string(PH_HINT_COST) + " COINS", PH_COL_AMBER);
    else if (_hr == "freed") ld_toast("HINT REVEALED", PH_COL_WB_FOUND);
    else if (_hr == "poor")  ld_toast("NOT ENOUGH COINS", PH_COL_PINK);
    exit;
}

// Back arrow (top-left) -> hub
if (ph_point_in_rect(_mx, _my, 0, HUD_Y - 60, 160, HUD_Y + 60)) {
    global.input_locked_until = current_time + 200;
    if (!solved) {
        ph_timer_commit(global.save, timer_key, timer_base_secs, session_start_ms);
        ph_save_write(global.save);
    }
    room_goto(rm_hub);
    exit;
}

// No play input once solved.
if (solved) exit;

// HINT pill (bottom-right) — opens the shared hint modal. Bounds set by Draw_64.
if (ph_point_in_rect(_mx, _my, HINT_PILL_L, HINT_PILL_T, HINT_PILL_R, HINT_PILL_B)) {
    if (!ld_can_hint()) {
        ld_toast("HINT ALREADY SHOWN", PH_COL_GRAY);
    } else {
        hint.subtitle = ld_hint_subtitle();   // tile (1st) vs keyboard-letter (2nd)
        ph_hint_open(hint);
    }
    exit;
}

// ── Tile selection: tap a letter tile in the word row ─────────────────────────
for (var _i = 0; _i < N; _i++) {
    var _tx = row_x + _i * (TILE + TILE_GAP);
    if (ph_point_in_rect(_mx, _my, _tx, row_y, _tx + TILE, row_y + TILE)) {
        sel = _i;
        exit;
    }
}

// ── Keyboard: type into the selected tile, then evaluate the word ─────────────
var _keys = ld_build_keys();
for (var _i = 0; _i < array_length(_keys); _i++) {
    var _k = _keys[_i];
    if (!ph_point_in_rect(_mx, _my, _k.x1, _k.y1, _k.x2, _k.y2)) continue;

    // Press feedback: the tapped key darkens briefly (drawn in Draw_64).
    key_press_ch = _k.ch;
    key_press_t  = KEY_PRESS_DUR;

    if (sel < 0) {
        ld_toast("TAP A LETTER FIRST", PH_COL_GRAY);
        exit;
    }

    // Replace the selected letter and check the whole word against the target.
    letters[sel] = _k.ch;
    var _target  = puzzle.words[step];
    if (ld_row_string() == _target) {
        feedback = "correct"; fb_timer = FB_DUR;   // green flash → advance in feedback block
    } else {
        feedback = "wrong";   fb_timer = FB_DUR;   // red flash → revert in feedback block
        // Wrong guess → +5 s time penalty (folded into the play timer, like Arrows),
        // with a floating "+5s" + red timer flash so the cost is clear.
        timer_base_secs += PH_LADDER_PENALTY_SECS;
        pen_t = PEN_DUR;
        ph_timer_commit(global.save, timer_key, timer_base_secs, session_start_ms);
        ph_save_write(global.save);
    }
    exit;
}
