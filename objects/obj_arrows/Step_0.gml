// ── Arrows — Step ─────────────────────────────────────────────────────────────

// Win screen (shared controller) — runs first and exits when complete.
if (win_phase == 1) {
    ph_win_step(win);
    ph_win_input(win);
    exit;
}

// Timers / fades.
if (toast_timer > 0)      toast_timer--;
if (float_t > 0)          float_t--;
if (ar_hint_t > 0)        ar_hint_t--;
if (coin_pulse_t < 1)     coin_pulse_t     = min(1, coin_pulse_t + 1/18);
if (coin_overshoot_t < 1) coin_overshoot_t = min(1, coin_overshoot_t + 1/10);

// Blocked-tap lunge ("go to the blocker and back") — pure visual timer.
if (bump_idx != -1) {
    bump_t += 1/bump_frames;
    if (bump_t >= 1) { bump_idx = -1; blocker_idx = -1; }
}

// ── Launch (snake slide-out) animation — locks input until the arrow is gone ──
if (launching != -1) {
    launch_t = min(1, launch_t + 1/launch_frames);
    if (launch_t >= 1) {
        alive[launching] = false;
        launching = -1;
        ar_save();
        ar_check_win();
    }
    exit;
}

ph_hint_tick(hint);
ph_timer_step(global.save, timer_key, timer_base_secs, session_start_ms);

if (current_time < global.input_locked_until) exit;

var _mx = device_mouse_x_to_gui(0);
var _my = device_mouse_y_to_gui(0);

// Hint overlay (modal + placeholder video) eats taps while open.
var _hr = ph_hint_input(hint);
if (_hr != "none") {
    if (_hr == "paid") {
        toast_text = "HINT  •  -" + string(PH_HINT_COST) + " COINS";
        toast_col = PH_COL_YELLOW; toast_timer = TOAST_DUR;
    } else if (_hr == "freed") {
        toast_text = "SAFE MOVE REVEALED"; toast_col = ACCENT; toast_timer = TOAST_DUR;
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
        ar_save();
        room_goto(rm_hub);
        exit;
    }

    // HINT pill (bottom-right). Bounds set in Create.
    if (ph_point_in_rect(_mx, _my, HINT_PILL_L, HINT_PILL_T, HINT_PILL_R, HINT_PILL_B)) {
        if (!ar_can_hint()) {
            toast_text = "NO MOVES TO SHOW"; toast_col = PH_COL_GRAY; toast_timer = TOAST_DUR;
        } else {
            ph_hint_open(hint);
        }
        exit;
    }

    // Tap an arrow → launch if its lane is clear, else blocked (+5 s).
    var _ci = ar_cell_at(_mx, _my);
    if (_ci != -1) {
        var _idx = ph_arrows_at(puzzle, alive, _ci div COLS, _ci mod COLS);
        if (_idx != -1) {
            if (ph_arrows_sweep_clear(puzzle, alive, _idx)) {
                ar_start_launch(_idx);
                if (ar_hint_idx == _idx) { ar_hint_idx = -1; ar_hint_t = 0; }
            } else {
                // Glide the arrow head-first up to whatever blocks it, then back —
                // the same snake path-follow as a launch (built in ar_start_bump,
                // drawn in Draw); both it and the blocker flash red.
                var _bi      = ph_arrows_block_info(puzzle, alive, _idx);
                blocker_idx  = _bi.blocker;                     // arrow that stops it
                ar_start_bump(_idx, max(_bi.gap, 0));
                penalty_secs += PH_ARROWS_PENALTY_SECS;
                timer_base_secs += PH_ARROWS_PENALTY_SECS;   // fold the penalty into the play timer
                float_t      = FLOAT_DUR;
                float_x      = _mx;
                float_y      = _my;
                toast_text   = "BLOCKED  •  +" + string(PH_ARROWS_PENALTY_SECS) + "s";
                toast_col    = PH_COL_PINK;
                toast_timer  = TOAST_DUR;
                ar_save();
            }
        }
    }
}
