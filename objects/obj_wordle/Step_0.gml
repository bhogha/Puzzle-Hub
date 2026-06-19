// ── obj_wordle — Step ─────────────────────────────────────────────────────────
// Keyboard input, reveal animation, hint flow, win flow. (Loss = Phase 5.)

// ── Win screen owns the frame when complete ───────────────────────────────────
if (win_phase == 1) {
    ph_win_step(win);
    ph_win_input(win);
    exit;
}

// ── Lose / lost-aversion flow owns the frame while active ─────────────────────
if (lose_phase != "none") {
    if (toast_timer > 0) toast_timer--;
    wd_lose_step();
    wd_lose_input();
    exit;
}

if (toast_timer > 0)  toast_timer--;
if (key_press_t > 0)  key_press_t--;

// Advance the shared hint-flow timers (modal slide / "-100" / video / reveal).
ph_hint_tick(hint);
if (wd_hint_pop_t < 1) wd_hint_pop_t = min(1, wd_hint_pop_t + 1/12);

// Persist the play timer (≤ once/sec) while the puzzle is still live, so leaving
// or an app kill resumes here. Won/lost states freeze the clock.
if (puzzle.status == "in_progress")
    ph_timer_step(global.save, timer_key, timer_base_secs, session_start_ms);

// Hint overlay/reveal — polled EVERY frame (not just on a tap) so the deferred
// paid/freed result, emitted after the reveal animation, is always caught.
var _hr = ph_hint_input(hint);
if (_hr != "none") {
    if (_hr == "paid" || _hr == "freed") {
        // Reveal finished — pop the locked letter in (a Wordle hint can't win).
        wd_hint_pop_pos    = wd_last_hint_pos;
        wd_hint_pop_t      = 0;
        wd_hint_reveal_pos = -1;
        if (_hr == "paid") wd_toast("HINT USED  -" + string(PH_HINT_COST) + " COINS", PH_COL_YELLOW);
        else               wd_toast("HINT REVEALED", PH_COL_GREEN);
    } else if (_hr == "poor") {
        wd_toast("NOT ENOUGH COINS", PH_COL_PINK);
    }
    exit;
}

// ── Reveal animation: advance, then commit the row when it finishes ───────────
if (revealing) {
    reveal_t++;
    var _done_at = (COLS - 1) * REVEAL_STAGGER + REVEAL_FLIP;
    if (reveal_t >= _done_at) {
        revealing = false;
        var _status = ph_wordle_add_guess(puzzle, reveal_guess);
        kbd_states  = ph_wordle_keyboard_states(puzzle);
        wd_reset_row();    // next row starts fresh (re-applies any locked hints)
        wd_save_state();   // persist guesses + status for resume (in_progress / lost / won)
        if (_status == "won") {
            wd_check_win();
        } else if (_status == "lost") {
            wd_enter_lose();   // out of guesses → lost-aversion modal (or finalize)
        }
    }
    exit;
}

if (current_time < global.input_locked_until) exit;
if (!device_mouse_check_button_pressed(0, mb_left)) exit;

var _mx = device_mouse_x_to_gui(0);
var _my = device_mouse_y_to_gui(0);

// (Hint overlay/reveal is handled every frame near the top of Step.)

// Back arrow (top-left) -> hub
if (ph_point_in_rect(_mx, _my, 0, HUD_Y - 60, 160, HUD_Y + 60)) {
    global.input_locked_until = current_time + 200;
    if (puzzle.status == "in_progress") {
        ph_timer_commit(global.save, timer_key, timer_base_secs, session_start_ms);
        ph_save_write(global.save);
    }
    room_goto(rm_hub);
    exit;
}

// No play input once the puzzle is over.
if (puzzle.status != "in_progress") exit;

// HINT pill (bottom-right) — opens the shared hint modal (pay coins OR watch a
// placeholder rewarded video). Bounds set by Draw_64.
if (ph_point_in_rect(_mx, _my, HINT_PILL_L, HINT_PILL_T, HINT_PILL_R, HINT_PILL_B)) {
    if (!wd_can_hint()) {
        wd_toast("NO HINTS LEFT", PH_COL_GRAY);
    } else {
        ph_hint_open(hint);
    }
    exit;
}

// ── Keyboard ──────────────────────────────────────────────────────────────────
var _keys = wd_build_keys();
for (var _i = 0; _i < array_length(_keys); _i++) {
    var _k = _keys[_i];
    if (!ph_point_in_rect(_mx, _my, _k.x1, _k.y1, _k.x2, _k.y2)) continue;

    // Press feedback: this key darkens briefly (drawn in Draw_64).
    key_press_tag = (_k.type == "letter") ? _k.ch : _k.type;
    key_press_t   = KEY_PRESS_DUR;

    if (_k.type == "letter") {
        // Fill the leftmost empty slot.
        for (var _s = 0; _s < COLS; _s++) {
            if (row_slots[_s] == "") { row_slots[_s] = _k.ch; break; }
        }
    } else if (_k.type == "del") {
        // Clear the rightmost filled, non-locked slot.
        for (var _s = COLS - 1; _s >= 0; _s--) {
            if (!row_lock[_s] && row_slots[_s] != "") { row_slots[_s] = ""; break; }
        }
    } else if (_k.type == "send") {
        if (!wd_row_full()) {
            wd_toast("NOT ENOUGH LETTERS", PH_COL_GRAY);
        } else {
            var _guess = wd_row_string();
            if (!ph_wordle_is_allowed(_guess, puzzle.answer)) {
                wd_toast("NOT A WORD", PH_COL_PINK);
            } else {
                // Begin the reveal of this row; it commits in the reveal block above.
                reveal_guess = _guess;
                reveal_score = ph_wordle_score_guess(puzzle.answer, _guess);
                reveal_row   = array_length(puzzle.guesses);
                reveal_t     = 0;
                revealing    = true;
            }
        }
    }
    break;   // one key per press
}
