// ── Shikaku — Step ────────────────────────────────────────────────────────────

// Toast countdown
if (toast_timer > 0) toast_timer--;

// Coin pulse animation timers
if (coin_pulse_t < 1)     coin_pulse_t     = min(1, coin_pulse_t + 1/18);
if (coin_overshoot_t < 1) coin_overshoot_t = min(1, coin_overshoot_t + 1/10);

// Win animation + confetti (mirrors Sudoku/Anygram)
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
            room_goto(rm_hub);
        }
    }
    exit;
}

// ── Gameplay input ────────────────────────────────────────────────────────────
if (current_time < global.input_locked_until) exit;

var _mx = device_mouse_x_to_gui(0);
var _my = device_mouse_y_to_gui(0);

// Map a GUI point to a grid cell (clamped to the board).
var _cur_col = clamp(floor((_mx - grid_x) / CELL), 0, N - 1);
var _cur_row = clamp(floor((_my - grid_y) / CELL), 0, N - 1);

// ── Press ─────────────────────────────────────────────────────────────────────
if (device_mouse_check_button_pressed(0, mb_left)) {
    // Back arrow (top-left of HUD strip)
    if (ph_point_in_rect(_mx, _my, 0, 40, 130, 150)) {
        global.input_locked_until = current_time + 200;
        room_goto(rm_hub);
        exit;
    }

    // Hint pill (bottom-right) — bounds set by Draw_64
    if (ph_point_in_rect(_mx, _my, HINT_PILL_L, HINT_PILL_T, HINT_PILL_R, HINT_PILL_B)) {
        // Pick the first clue that isn't hinted yet AND isn't already correctly
        // solved by the player (so the hint always teaches something new).
        var _target = -1;
        for (var _i = 0; _i < n_clues; _i++) {
            if (hint_shown[_i]) continue;
            var _s = puzzle.sol_rects[_i];
            if (ph_shikaku_player_has_rect(player_rects, _s.r, _s.c, _s.w, _s.h)) continue;
            _target = _i; break;
        }
        if (_target < 0) {
            toast_text = "NO HINTS LEFT"; toast_col = PH_COL_GRAY; toast_timer = TOAST_DUR;
        } else if (ph_spend_coins(global.save, PH_HINT_COST)) {
            hint_shown[_target] = true;
            sk_save();
            toast_text = "HINT USED  -" + string(PH_HINT_COST) + " coins";
            toast_col = PH_COL_YELLOW; toast_timer = TOAST_DUR;
        } else {
            toast_text = "NOT ENOUGH COINS"; toast_col = PH_COL_PINK; toast_timer = TOAST_DUR;
        }
        exit;
    }

    // Grid press → begin a drag selection.
    if (ph_point_in_rect(_mx, _my, grid_x, grid_y, grid_x + BOARD, grid_y + BOARD)) {
        dragging = true;
        drag_sr  = _cur_row;
        drag_sc  = _cur_col;
        drag_cr  = _cur_row;
        drag_cc  = _cur_col;
        exit;
    }
    exit;
}

// ── Held: extend the drag selection ───────────────────────────────────────────
if (dragging && device_mouse_check_button(0, mb_left)) {
    drag_cr = _cur_row;
    drag_cc = _cur_col;
}

// ── Release: commit rectangle, or tap-to-delete ───────────────────────────────
if (dragging && device_mouse_check_button_released(0, mb_left)) {
    dragging = false;
    var _r0 = min(drag_sr, drag_cr);
    var _c0 = min(drag_sc, drag_cc);
    var _w  = abs(drag_cc - drag_sc) + 1;
    var _h  = abs(drag_cr - drag_sr) + 1;

    // Single-cell tap on an existing rectangle removes it (delete gesture).
    if (_w == 1 && _h == 1) {
        var _hit = sk_rect_at_cell(_r0, _c0);
        if (_hit != -1) {
            array_delete(player_rects, _hit, 1);
            sk_save();
            exit;
        }
    }
    sk_commit_rect(_r0, _c0, _w, _h);
    exit;
}
