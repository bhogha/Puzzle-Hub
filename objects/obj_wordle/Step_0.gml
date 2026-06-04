// ── obj_wordle — Step ─────────────────────────────────────────────────────────
// Phase 2: keyboard input, reveal animation, win flow. (Hint = Phase 4, loss = Phase 5.)

// ── Win screen owns the frame when complete ───────────────────────────────────
if (win_phase == 1) {
    ph_win_step(win);
    ph_win_input(win);
    exit;
}

if (toast_timer > 0) toast_timer--;

// ── Reveal animation: advance, then commit the row when it finishes ───────────
if (revealing) {
    reveal_t++;
    var _done_at = (COLS - 1) * REVEAL_STAGGER + REVEAL_FLIP;
    if (reveal_t >= _done_at) {
        revealing = false;
        var _status = ph_wordle_add_guess(puzzle, reveal_guess);
        kbd_states  = ph_wordle_keyboard_states(puzzle);
        if (_status == "won") {
            wd_check_win();
        }
        // "lost" is handled by the lost-aversion flow in Phase 5; for now the
        // board simply stops accepting input (status != in_progress).
    }
    exit;
}

if (current_time < global.input_locked_until) exit;
if (!device_mouse_check_button_pressed(0, mb_left)) exit;

var _mx = device_mouse_x_to_gui(0);
var _my = device_mouse_y_to_gui(0);

// Back arrow (top-left) -> hub
if (ph_point_in_rect(_mx, _my, 0, HUD_Y - 60, 160, HUD_Y + 60)) {
    global.input_locked_until = current_time + 200;
    room_goto(rm_hub);
    exit;
}

// No play input once the puzzle is over.
if (puzzle.status != "in_progress") exit;

// ── Keyboard ──────────────────────────────────────────────────────────────────
var _keys = wd_build_keys();
for (var _i = 0; _i < array_length(_keys); _i++) {
    var _k = _keys[_i];
    if (!ph_point_in_rect(_mx, _my, _k.x1, _k.y1, _k.x2, _k.y2)) continue;

    if (_k.type == "letter") {
        if (string_length(cur_guess) < PH_WORDLE_LEN) cur_guess += _k.ch;
    } else if (_k.type == "del") {
        if (string_length(cur_guess) > 0) cur_guess = string_copy(cur_guess, 1, string_length(cur_guess) - 1);
    } else if (_k.type == "send") {
        if (string_length(cur_guess) < PH_WORDLE_LEN) {
            wd_toast("NOT ENOUGH LETTERS", PH_COL_GRAY);
        } else if (!ph_wordle_is_allowed(cur_guess, puzzle.answer)) {
            wd_toast("NOT A WORD", PH_COL_PINK);
        } else {
            // Begin the reveal of this row; it commits in the reveal block above.
            reveal_guess = cur_guess;
            reveal_score = ph_wordle_score_guess(puzzle.answer, cur_guess);
            reveal_row   = array_length(puzzle.guesses);
            reveal_t     = 0;
            revealing    = true;
            cur_guess    = "";
        }
    }
    break;   // one key per press
}
