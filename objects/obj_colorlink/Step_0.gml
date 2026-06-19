// ── Color Link — Step ─────────────────────────────────────────────────────────

// Win screen (shared controller) — runs first and exits when complete.
if (win_phase == 1) {
    ph_win_step(win);
    ph_win_input(win);
    exit;
}

if (toast_timer > 0) toast_timer--;
if (coin_pulse_t < 1)     coin_pulse_t     = min(1, coin_pulse_t + 1/18);
if (coin_overshoot_t < 1) coin_overshoot_t = min(1, coin_overshoot_t + 1/10);

ph_hint_tick(hint);
ph_timer_step(global.save, timer_key, timer_base_secs, session_start_ms);

if (current_time < global.input_locked_until) exit;

var _mx = device_mouse_x_to_gui(0);
var _my = device_mouse_y_to_gui(0);
drag_mx = _mx;
drag_my = _my;

// Hint overlay (modal + placeholder video) eats taps while open.
var _hr = ph_hint_input(hint);
if (_hr != "none") {
    if (_hr == "paid" || _hr == "freed") {
        // Snake finished — clear the reveal state, then run the deferred win-check.
        cl_snake_active = false;
        cl_snake_idx    = -1;
        if (_hr == "paid") {
            toast_text = "HINT USED  -" + string(PH_HINT_COST) + " coins";
            toast_col = PH_COL_YELLOW; toast_timer = TOAST_DUR;
        } else {
            toast_text = "LINE REVEALED"; toast_col = ACCENT; toast_timer = TOAST_DUR;
        }
        cl_check_win();
    } else if (_hr == "poor") {
        toast_text = "NOT ENOUGH COINS"; toast_col = PH_COL_PINK; toast_timer = TOAST_DUR;
    }
    exit;
}

// ── Press ─────────────────────────────────────────────────────────────────────
if (device_mouse_check_button_pressed(0, mb_left)) {
    // Back arrow (top-left of HUD strip).
    if (ph_point_in_rect(_mx, _my, 0, 40 + global.safe_top_gui, 130, 150 + global.safe_top_gui)) {
        global.input_locked_until = current_time + 200;
        ph_timer_commit(global.save, timer_key, timer_base_secs, session_start_ms);
        cl_save();
        room_goto(rm_hub);
        exit;
    }

    // HINT pill (bottom-right). Bounds set by Draw.
    if (ph_point_in_rect(_mx, _my, HINT_PILL_L, HINT_PILL_T, HINT_PILL_R, HINT_PILL_B)) {
        if (!cl_can_hint()) {
            toast_text = "NO HINTS LEFT"; toast_col = PH_COL_GRAY; toast_timer = TOAST_DUR;
        } else {
            ph_hint_open(hint);
        }
        exit;
    }

    // Start a draw from a board cell.
    var _ci = cl_cell_at(_mx, _my);
    if (_ci != -1) {
        var _ec = ph_colorlink_endpoint_color(puzzle, _ci div COLS, _ci mod COLS);
        if (_ec != -1 && !hint_locked[_ec]) {
            // Grab an endpoint → redraw that flow from scratch.
            cl_clear_flow(_ec);
            route[_ec] = [_ci];
            cell_owner[_ci] = _ec;
            dragging = true;
            drag_color = _ec;
        } else if (cell_owner[_ci] != -1 && !hint_locked[cell_owner[_ci]]) {
            // Grab a mid-line cell → continue that flow from here (trim the tail).
            drag_color = cell_owner[_ci];
            cl_truncate_after(drag_color, _ci);
            dragging = true;
        }
    }
    exit;
}

// ── Drag: walk the active flow head toward the finger ─────────────────────────
if (dragging && device_mouse_check_button(0, mb_left)) {
    var _fc = cl_cell_at(_mx, _my);
    if (_fc != -1) {
        var _guard = 0;
        while (_fc != cl_head() && _guard < NCELLS) {
            _guard++;
            var _nxt = cl_step_toward(cl_head(), _fc);
            if (_nxt == -1) break;
            if (!cl_try_step(_nxt)) break;
        }
    }
    exit;
}

// ── Release: commit, check win, persist ───────────────────────────────────────
if (dragging && device_mouse_check_button_released(0, mb_left)) {
    dragging = false;
    drag_color = -1;
    cl_check_win();
    if (win_phase == 0) cl_save();
    exit;
}
