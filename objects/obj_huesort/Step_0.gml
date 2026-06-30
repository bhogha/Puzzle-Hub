// ── Hue Sort — Step ───────────────────────────────────────────────────────────

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
if (hs_hint_pop_t < 1) hs_hint_pop_t = min(1, hs_hint_pop_t + 1/12);

// Advance the onboarding finger tip (no-op once solved / already seen).
ph_coach_tick(coach);

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
        // Reveal finished — pop the pin in, then run the (deferred) win-check.
        hs_hint_pop_idx    = hs_last_hint_idx;
        hs_hint_pop_t      = 0;
        hs_hint_reveal_idx = -1;
        if (_hr == "paid") {
            toast_text = "HINT USED  -" + string(PH_HINT_COST) + " coins";
            toast_col = PH_COL_YELLOW; toast_timer = TOAST_DUR;
        } else {
            toast_text = "TILE REVEALED"; toast_col = ACCENT; toast_timer = TOAST_DUR;
        }
        hs_check_win();
    } else if (_hr == "poor") {
        toast_text = "NOT ENOUGH COINS"; toast_col = PH_COL_PINK; toast_timer = TOAST_DUR;
    }
    exit;
}

// Track the pointer for the dragged-tile draw.
drag_mx = _mx;
drag_my = _my;

// Map a GUI point to a grid cell + index (only meaningful when over the board).
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
        if (!hs_can_hint()) {
            toast_text = "NO HINTS LEFT"; toast_col = PH_COL_GRAY; toast_timer = TOAST_DUR;
        } else {
            ph_hint_open(hint);
        }
        exit;
    }

    // Pick up a movable tile to begin a drag.
    if (_in_grid && !puzzle.locked[_cur_idx] && !hint_locked[_cur_idx]) {
        dragging  = true;
        drag_from = _cur_idx;
    }
    exit;
}

// ── Release: drop onto another cell → swap ────────────────────────────────────
if (dragging && device_mouse_check_button_released(0, mb_left)) {
    dragging = false;
    if (_in_grid) {
        var _to = _cur_idx;
        if (_to != drag_from && !puzzle.locked[_to] && !hint_locked[_to]) {
            hs_swap(drag_from, _to);
            ph_haptic_select();   // tiles swap into place
        }
    }
    drag_from = -1;
    exit;
}
