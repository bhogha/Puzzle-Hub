// ── Colordoku — Step ──────────────────────────────────────────────────────────

// Win screen (shared controller) — runs first and exits when complete.
if (win_phase == 1) {
    ph_win_step(win);
    ph_win_input(win);
    exit;
}

// Toast countdown
if (toast_timer > 0) toast_timer--;

// Coin pulse animation timers
if (coin_pulse_t < 1)     coin_pulse_t     = min(1, coin_pulse_t + 1/18);
if (coin_overshoot_t < 1) coin_overshoot_t = min(1, coin_overshoot_t + 1/10);

// Advance the shared hint-flow timers (modal slide / "-100" / video / reveal).
ph_hint_tick(hint);
ph_coach_tick(coach);   // onboarding finger tip (no-op once solved / already seen)
if (cd_pop_f >= 0) {
    var _pop_end = array_length(cd_hint_cells) * CD_POP_STAG + CD_POP_DUR + 2;
    cd_pop_f = min(cd_pop_f + 1, _pop_end);
}

// Persist the play timer (≤ once/sec) so leaving or an app kill resumes here.
ph_timer_step(global.save, timer_key, timer_base_secs, session_start_ms);

// ── Gameplay input ────────────────────────────────────────────────────────────
if (current_time < global.input_locked_until) exit;

var _mx = device_mouse_x_to_gui(0);
var _my = device_mouse_y_to_gui(0);

// Hint overlay (modal + placeholder video) eats taps while open.
var _hr = ph_hint_input(hint);
if (_hr != "none") {
    if (_hr == "paid" || _hr == "freed") {
        // Reveal finished — pop the locked X's in (no win possible from an X hint).
        cd_hint_reveal = false;
        cd_pop_f       = 0;
        if (_hr == "paid") {
            toast_text = "HINT USED  -" + string(PH_HINT_COST) + " coins";
            toast_col = PH_COL_YELLOW_DEEP; toast_timer = TOAST_DUR;
        } else {
            toast_text = "CELLS RULED OUT"; toast_col = ACCENT_DEEP; toast_timer = TOAST_DUR;
        }
    } else if (_hr == "poor") {
        toast_text = "NOT ENOUGH COINS"; toast_col = PH_COL_PINK; toast_timer = TOAST_DUR;
    }
    exit;
}

// Map a GUI point to a grid cell + index.
var _in_grid = ph_point_in_rect(_mx, _my, grid_x, grid_y, grid_x + BOARD, grid_y + BOARD);
var _cur_col = clamp(floor((_mx - grid_x) / CELL), 0, N - 1);
var _cur_row = clamp(floor((_my - grid_y) / CELL), 0, N - 1);
var _cur_idx = _cur_row * N + _cur_col;

// ── Press ─────────────────────────────────────────────────────────────────────
if (device_mouse_check_button_pressed(0, mb_left)) {
    // Back arrow (top-left of HUD strip)
    if (ph_point_in_rect(_mx, _my, 0, 40 + global.safe_top_gui, 130, 150 + global.safe_top_gui)) {
        global.input_locked_until = current_time + 200;
        ph_timer_commit(global.save, timer_key, timer_base_secs, session_start_ms);
        ph_save_write(global.save);
        room_goto(rm_hub);
        exit;
    }

    // Hint pill (bottom-right) — opens the shared hint modal. Bounds set by Draw.
    if (ph_point_in_rect(_mx, _my, HINT_PILL_L, HINT_PILL_T, HINT_PILL_R, HINT_PILL_B)) {
        if (!cd_can_hint()) {
            toast_text = "PLACE A QUEEN FIRST"; toast_col = PH_COL_GRAY; toast_timer = TOAST_DUR;
        } else {
            ph_hint_open(hint);
        }
        exit;
    }

    // Board tap: each tap advances the cell through a 3-state cycle —
    // empty → X (rule out) → queen gem → empty. No timing involved.
    // Hint-placed locked X's are permanent and ignore taps.
    if (_in_grid && !hint_x_locked[_cur_idx]) {
        var _i = _cur_idx;
        state[_i] = (state[_i] + 1) mod 3;   // 0 empty → 1 X → 2 queen → 0
        // Two distinct feels: a firm "mark" tap for an X, a positive success for
        // the queen gem (empty/clear keeps just the universal light tap).
        if (state[_i] == 1) {
            ph_haptic_tap(1);                            // X ruled out → firm medium tap
        } else if (state[_i] == 2) {
            ph_sfx(snd_correct, 0.55);                   // queen placed
            ph_haptic_success();                         // queen gem placed → positive buzz
        }
        // First queen placed → retire the onboarding finger tip.
        if (ph_coach_active(coach) && state[_i] == 2) { ph_coach_stop(coach); ph_tip_mark_seen("COLORDOKU"); }
        cd_save();
        cd_check_win();
    }
    exit;
}
