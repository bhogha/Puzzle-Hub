// ── Date roll-over (hub left open past midnight) ──────────────────────────────
if (ph_today_key() != today_key) hub_refresh_dates();

// ── Input lock ────────────────────────────────────────────────────────────────
if (current_time < global.input_locked_until) exit;

var _mx = device_mouse_x_to_gui(0);
var _my = device_mouse_y_to_gui(0);

// ── Calendar animation ────────────────────────────────────────────────────────
var _cal_target = cal_open ? 1 : 0;
cal_anim_t = lerp(cal_anim_t, _cal_target, 0.18);

// ── Compute body top (depends on calendar state) ──────────────────────────────
// Strip slot shrinks as the calendar opens (the 7-day strip is faded out
// anyway). Matches the formula in Draw_64 §0 so tap targets line up with what
// is being rendered.
var _cal_h        = lerp(LAYOUT.calbar_h, LAYOUT.calexpand_h, cal_anim_t);
var _eff_strip_h  = LAYOUT.strip_h * lerp(1.0, 0.50, cal_anim_t);
var _body_top     = LAYOUT.calbar_y + _cal_h + _eff_strip_h + LAYOUT.section_h;
var _body_bot     = PH_H - LAYOUT.nav_h;
var _view_h       = _body_bot - _body_top;
var _total_h      = array_length(cards) * (LAYOUT.card_h + LAYOUT.card_gap) - LAYOUT.card_gap;
scroll_max        = max(0, _total_h - _view_h);

// ── Press start ───────────────────────────────────────────────────────────────
if (device_mouse_check_button_pressed(0, mb_left)) {
    drag_start_x = _mx;
    drag_start_y = _my;
    drag_dist    = 0;
    is_dragging  = false;
    mx_prev = _mx;
    my_prev = _my;
    scroll_vel = 0;
}

// ── Held: drag to scroll ──────────────────────────────────────────────────────
if (device_mouse_check_button(0, mb_left)) {
    var _dy = _my - my_prev;
    drag_dist += abs(_mx - mx_prev) + abs(_my - my_prev);
    if (drag_dist > 20) is_dragging = true;
    if (is_dragging) {
        scroll_y -= _dy;
        scroll_vel = _dy;   // fling continues drag direction (scroll_y -= scroll_vel)
    }
    mx_prev = _mx;
    my_prev = _my;
}

// ── Release: fling + tap ──────────────────────────────────────────────────────
if (device_mouse_check_button_released(0, mb_left)) {
    if (!is_dragging) {
        // ── TAP ──────────────────────────────────────────────────────────────
        var _tap_x = drag_start_x;
        var _tap_y = drag_start_y;
        var _third = PH_W / 3;
        var _nav_top = PH_H - LAYOUT.nav_h;

        // Bottom nav takes priority — covered tab regions never fall through to cards.
        // Tab order: Shop | Games (current) | Profile
        if (_tap_y > _nav_top) {
            if (_tap_x < _third) {
                global.input_locked_until = current_time + 200;
                room_goto(rm_shop);
            } else if (_tap_x >= _third*2) {
                global.input_locked_until = current_time + 200;
                room_goto(rm_profile);
            }
            // middle third = Games (current room) — no-op
            exit;
        }

        // Calendar toggle — full teal bar
        if (ph_point_in_rect(_tap_x,_tap_y,
                             0, LAYOUT.calbar_y,
                             PH_W, LAYOUT.calbar_y + LAYOUT.calbar_h)) {
            cal_open = !cal_open;
            exit;
        }

        // Month grid tap (when expanded) — checked BEFORE strip so taps inside the
        // grid window don't fall through to the strip below.
        if (cal_open) {
            var _grid_top  = LAYOUT.calbar_y + LAYOUT.calbar_h + LAYOUT.cal_grid_off;
            var _cell_w    = PH_W / 7;
            var _cell_h    = LAYOUT.cal_cell_h;
            var _matched   = false;   // tracks a *real* cell hit only
            var _stop      = false;   // tracks whether to break out of both loops
            for (var _ri = 0; _ri < month_grid_rows && !_stop; _ri++) {
                for (var _ci = 0; _ci < 7; _ci++) {
                    var _mi = _ri*7 + _ci;
                    // Walked past the end of the month grid → stop iterating but
                    // DO NOT mark _matched (the tap may belong to strip/card below).
                    if (_mi >= array_length(month_days)) { _stop = true; break; }
                    if (month_days[_mi] == undefined) continue;
                    var _cx1 = _ci * _cell_w;
                    var _cy1 = _grid_top + _ri * _cell_h;
                    if (ph_point_in_rect(_tap_x,_tap_y, _cx1,_cy1, _cx1+_cell_w,_cy1+_cell_h)) {
                        global.selected_date_key = month_days[_mi].key;
                        hub_center_strip_on(month_days[_mi].dt);   // re-centre strip on selected day
                        cal_open = false;
                        _matched = true;
                        _stop    = true;
                        break;
                    }
                }
            }
            if (_matched) exit;
        }

        // Strip day tap — only active when calendar is closed. When the calendar
        // is open the strip is faded out (see Draw_64.gml §4), so taps in this
        // region should fall through.
        if (!cal_open) {
            var _strip_top = LAYOUT.calbar_y + _cal_h;
            var _sw        = PH_W / 7;
            if (ph_point_in_rect(_tap_x,_tap_y, 0,_strip_top, PH_W,_strip_top+_eff_strip_h)) {
                var _col = floor(_tap_x / _sw);
                _col = clamp(_col, 0, 6);
                global.selected_date_key = strip_days[_col].key;
                hub_center_strip_on(strip_days[_col].dt);   // re-centre strip on tapped day
            }
        }

        // Card tap
        if (ph_point_in_rect(_tap_x,_tap_y, 0,_body_top, PH_W,_body_bot)) {
            for (var _i = 0; _i < array_length(cards); _i++) {
                var _card = cards[_i];
                var _cy1  = _body_top + _i*(LAYOUT.card_h + LAYOUT.card_gap) - scroll_y;
                var _cy2  = _cy1 + LAYOUT.card_h;
                var _cx1  = LAYOUT.card_pad_x;
                var _cx2  = PH_W - LAYOUT.card_pad_x;
                if (ph_point_in_rect(_tap_x,_tap_y, _cx1,_cy1,_cx2,_cy2)) {
                    // Defensive: ignore the tap unless the card is unlocked AND
                    // has a real room to navigate to. Prevents room_goto(-1) if
                    // a card definition gets the locked/room fields out of sync.
                    if (!_card.locked && _card.room != "") {
                        var _rm_idx = asset_get_index(_card.room);
                        if (_rm_idx >= 0) {
                            global.input_locked_until = current_time + 200;
                            // Flag review mode explicitly so each puzzle's Create_0 can rely on it
                            if (_card.name == "ANYGRAM") {
                                global.anygram_review_mode =
                                    ph_anygram_is_done(global.save, global.selected_date_key);
                            } else {
                                global.anygram_review_mode = false;
                            }
                            if (_card.name == "SUDOKU") {
                                global.sudoku_review_mode =
                                    ph_sudoku_is_done(global.save, global.selected_date_key);
                            } else {
                                global.sudoku_review_mode = false;
                            }
                            if (_card.name == "WORD WAVE") {
                                global.wordwave_review_mode =
                                    ph_wordwave_is_done(global.save, global.selected_date_key);
                            } else {
                                global.wordwave_review_mode = false;
                            }
                            if (_card.name == "SHIKAKU") {
                                global.shikaku_review_mode =
                                    ph_shikaku_is_done(global.save, global.selected_date_key);
                            } else {
                                global.shikaku_review_mode = false;
                            }
                            room_goto(_rm_idx);
                        }
                    }
                    break;
                }
            }
        }
    }
}

// ── Scroll physics ────────────────────────────────────────────────────────────
if (!device_mouse_check_button(0, mb_left)) {
    scroll_vel *= 0.88;
    scroll_y   -= scroll_vel;
}
scroll_y = clamp(scroll_y, 0, scroll_max);
