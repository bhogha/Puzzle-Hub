// ── Sudoku — Step ─────────────────────────────────────────────────────────────

// Win screen (shared controller) — runs first and exits when complete, so the
// legacy win_phase==1 blocks below are no longer reached.
if (win_phase == 1) {
    ph_win_step(win);
    ph_win_input(win);
    exit;
}

// Cell pop / flash animation
for (var _i = 0; _i < 81; _i++) {
    if (cell_flash[_i] > 0) {
        cell_flash[_i]--;
        cell_scale[_i] = lerp(cell_scale[_i], 1.12, 0.25);
    } else {
        cell_scale[_i] = lerp(cell_scale[_i], 1.0, 0.22);
    }
}

// Toast countdown
if (toast_timer > 0) toast_timer--;

// Coin pulse animation timers
if (coin_pulse_t < 1)     coin_pulse_t     = min(1, coin_pulse_t + 1/18);
if (coin_overshoot_t < 1) coin_overshoot_t = min(1, coin_overshoot_t + 1/10);

// Advance the shared hint-flow timers (modal slide / "-100" / video / reveal).
ph_hint_tick(hint);

// Advance the onboarding finger tip (no-op once solved / already seen).
ph_coach_tick(coach);
if (sd_hint_pop_t < 1) sd_hint_pop_t = min(1, sd_hint_pop_t + 1/12);

// Persist the play timer (≤ once/sec) so leaving or an app kill resumes here.
if (win_phase == 0) ph_timer_step(global.save, timer_key, timer_base_secs, session_start_ms);

// Hint overlay/reveal — polled EVERY frame (not just on a tap) so the deferred
// paid/freed result, emitted after the reveal animation, is always caught.
var _hr = ph_hint_input(hint);
if (_hr != "none") {
    if (_hr == "paid" || _hr == "freed") {
        // Reveal finished — pop the number in, then run the (deferred) win-check.
        sd_hint_pop_idx    = sd_last_hint_idx;
        sd_hint_pop_t      = 0;
        sd_hint_reveal_idx = -1;
        if (_hr == "paid") { toast_text = "HINT USED  -" + string(PH_HINT_COST) + " coins"; toast_col = PH_COL_YELLOW; }
        else               { toast_text = "HINT REVEALED"; toast_col = PH_COL_TEAL; }
        toast_timer = TOAST_DUR;
        sd_check_win();
    } else if (_hr == "poor") {
        toast_text = "NOT ENOUGH COINS"; toast_col = PH_COL_PINK; toast_timer = TOAST_DUR;
    }
    exit;
}

// Win animation + confetti
if (win_phase == 1) {
    win_anim_t = min(win_anim_t + 0.04, 1.0);

    var _conf_palette = [PH_COL_PINK, PH_COL_YELLOW, PH_COL_TEAL,
                         PH_COL_PURPLE, PH_COL_WHITE, PH_COL_ORANGE];
    var _conf_n_pal   = array_length(_conf_palette);

    if (confetti_burst_pending) {
        confetti_burst_pending = false;
        confetti_run_frames    = 0;
        for (var _bi = 0; _bi < 60; _bi++) {
            var _ang   = random(2*pi);
            var _speed = 14 + random(14);
            array_push(confetti_pieces, {
                x: PH_W/2 + cos(_ang)*4, y: 600 + sin(_ang)*4,
                vx: cos(_ang)*_speed,    vy: sin(_ang)*_speed,
                rot: random(360), vrot: -8 + random(16),
                size: 14 + irandom(10),
                col: _conf_palette[irandom(_conf_n_pal-1)], shape: irandom(2),
            });
        }
    }

    var _confetti_active = (confetti_run_frames < CONFETTI_DURATION_FRAMES);
    confetti_run_frames++;
    if (_confetti_active) {
        while (array_length(confetti_pieces) < CONFETTI_TARGET_FALL) {
            array_push(confetti_pieces, {
                x: random(PH_W), y: -40 - random(400),
                vx: -2 + random(4), vy: 3 + random(4),
                rot: random(360), vrot: -6 + random(12),
                size: 14 + irandom(10),
                col: _conf_palette[irandom(_conf_n_pal-1)], shape: irandom(2),
            });
        }
    }
    for (var _pi = array_length(confetti_pieces) - 1; _pi >= 0; _pi--) {
        var _p = confetti_pieces[_pi];
        _p.vy += 0.35;
        _p.vx *= 0.985;
        _p.x  += _p.vx;
        _p.y  += _p.vy;
        _p.rot += _p.vrot;
        if (_p.y > PH_H + 60) array_delete(confetti_pieces, _pi, 1);
        else confetti_pieces[_pi] = _p;
    }
}

// ── Win-screen input ──────────────────────────────────────────────────────────
if (win_phase == 1) {
    if (device_mouse_check_button_pressed(0, mb_left)) {
        var _wmx = device_mouse_x_to_gui(0);
        var _wmy = device_mouse_y_to_gui(0);
        if (win_btn_back_y > 0
            && ph_point_in_rect(_wmx,_wmy, 80, win_btn_back_y, PH_W-80, win_btn_back_y+90)) {
            // A pending level-up shows the reward screen (rm_win) before the hub.
            room_goto(ph_levelup_pending() ? rm_win : rm_hub);
        }
    }
    exit;
}

// ── Gameplay input ────────────────────────────────────────────────────────────
if (current_time < global.input_locked_until) exit;
if (!device_mouse_check_button_pressed(0, mb_left)) exit;

var _mx = device_mouse_x_to_gui(0);
var _my = device_mouse_y_to_gui(0);

// (Hint overlay/reveal is handled every frame near the top of Step.)

// Back arrow (top-left of HUD strip)
if (ph_point_in_rect(_mx, _my, 0, 40 + global.safe_top_gui, 130, 150 + global.safe_top_gui)) {
    global.input_locked_until = current_time + 200;
    ph_timer_commit(global.save, timer_key, timer_base_secs, session_start_ms);
    ph_save_write(global.save);
    room_goto(rm_hub);
    exit;
}

// Hint pill (bottom-right) — opens the shared hint modal (pay coins OR watch a
// placeholder rewarded video). Bounds set by Draw_64.
if (ph_point_in_rect(_mx, _my, HINT_PILL_L, HINT_PILL_T, HINT_PILL_R, HINT_PILL_B)) {
    if (!sd_can_hint()) {
        toast_text = "NO CELLS TO REVEAL"; toast_col = PH_COL_GRAY; toast_timer = TOAST_DUR;
    } else {
        ph_hint_open(hint);
    }
    exit;
}

// Grid cell tap
if (ph_point_in_rect(_mx, _my, grid_x, grid_y, grid_x + BOARD, grid_y + BOARD)) {
    var _c = clamp(floor((_mx - grid_x) / CELL), 0, 8);
    var _r = clamp(floor((_my - grid_y) / CELL), 0, 8);
    var _idx = _r * 9 + _c;
    // Givens can't be selected for editing — tapping one just clears selection.
    sel_idx = ph_sudoku_is_given(puzzle, _idx) ? -1 : _idx;
    // Onboarding tip: tapping the highlighted cell advances to the "tap number" step.
    if (ph_coach_active(coach) && coach.step == 0 && sel_idx == tip_cell) ph_coach_next(coach);
    exit;
}

// Number pad tap (1..9)
if (_my >= NUM_Y - NUM_H/2 && _my <= NUM_Y + NUM_H/2) {
    for (var _n = 0; _n < 9; _n++) {
        if (_mx >= num_x[_n] && _mx <= num_x[_n] + NUM_W) {
            if (sel_idx >= 0 && !ph_sudoku_is_given(puzzle, sel_idx)) {
                puzzle.grid[sel_idx]   = _n + 1;
                puzzle.hinted[sel_idx] = false;
                cell_scale[sel_idx]    = 1.18;
                // NOTE: no "correct digit" haptic on purpose — like the SFX design
                // (GDD §2.13), it would let the player feel out the solution. Sudoku
                // uses only the universal tap + the win buzz.
                sd_check_units();
                ph_sudoku_save_grid(global.save, global.selected_date_key, ph_sudoku_grid_to_str(puzzle));
                ph_save_write(global.save);
                // First correct number placed → retire the onboarding finger tip.
                if (ph_coach_active(coach) && puzzle.grid[sel_idx] == puzzle.solution[sel_idx]) {
                    ph_coach_stop(coach); ph_tip_mark_seen("SUDOKU");
                }
                sd_check_win();
            }
            exit;
        }
    }
}

// Delete button tap
if (ph_point_in_rect(_mx, _my, DEL_L, DEL_Y, DEL_L + DEL_W, DEL_Y + DEL_H)) {
    if (sel_idx >= 0 && !ph_sudoku_is_given(puzzle, sel_idx)) {
        puzzle.grid[sel_idx]   = 0;
        puzzle.hinted[sel_idx] = false;
        sd_check_units();
        ph_sudoku_save_grid(global.save, global.selected_date_key, ph_sudoku_grid_to_str(puzzle));
        ph_save_write(global.save);
    }
    exit;
}
