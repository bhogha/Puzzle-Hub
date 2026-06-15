// ── Profile — Step (input + scroll) ───────────────────────────────────────────

// Per-frame timers (tick regardless of input lock).
if (toast_timer > 0) toast_timer--;
if (starfly_active) { starfly_t++; if (starfly_t >= STARFLY_DUR) starfly_active = false; }
if (pending_hub_timer > 0) {
    pending_hub_timer--;
    if (pending_hub_timer == 0) { global.input_locked_until = current_time + 300; room_goto(rm_hub); exit; }
}
if (current_time < global.input_locked_until) exit;
if (pending_hub_timer >= 0)                   exit;   // freeze input during reset toast

var _mx = device_mouse_x_to_gui(0);
var _my = device_mouse_y_to_gui(0);
var M   = prof_metrics();
var _nav_top = PH_H - 190 - global.safe_bottom_gui;
var _third   = PH_W / 3;
var _ms      = global.save.week.missions;
var _finished = (global.save.week.status == "finished");

// ── Scroll bounds ─────────────────────────────────────────────────────────────
var _total_h = _finished ? 0 : (array_length(_ms) * (CARD_H + CARD_GAP) - CARD_GAP);
scroll_max   = max(0, _total_h - (M.list_bot - M.list_top));

// ── Press / drag / release (mirrors obj_hub) ──────────────────────────────────
if (device_mouse_check_button_pressed(0, mb_left)) {
    drag_start_x = _mx; drag_start_y = _my; drag_dist = 0; is_dragging = false;
    mx_prev = _mx; my_prev = _my; scroll_vel = 0;
}
if (device_mouse_check_button(0, mb_left)) {
    var _dy = _my - my_prev;
    drag_dist += abs(_mx - mx_prev) + abs(_my - my_prev);
    if (drag_dist > 20) is_dragging = true;
    if (is_dragging && drag_start_y > M.list_top && drag_start_y < M.list_bot) {
        scroll_y  -= _dy;
        scroll_vel = _dy;
    }
    mx_prev = _mx; my_prev = _my;
}
if (device_mouse_check_button_released(0, mb_left)) {
    if (!is_dragging) {
        var _tx = drag_start_x, _ty = drag_start_y;

        // 1) Level pill — triple-tap to wipe progress (easter egg).
        if (ph_point_in_rect(_tx,_ty, 70, M.topbar_cy-40, 270, M.topbar_cy+40)) {
            if (current_time - level_tap_last > LEVEL_TAP_WINDOW_MS) level_tap_count = 0;
            level_tap_count++; level_tap_last = current_time;
            if (level_tap_count >= LEVEL_TAP_REQUIRED) {
                global.save       = ph_save_reset();
                level_tap_count   = 0;
                toast_text        = "PROGRESSION DELETED";
                toast_col         = PH_COL_PINK_DEEP;
                toast_timer       = TOAST_DUR;
                pending_hub_timer = TOAST_DUR;
            }
            exit;
        }

        // 2) Bottom nav tabs (Shop | Games | Profile=current).
        if (_ty > _nav_top) {
            if      (_tx < _third)      { global.input_locked_until = current_time + 200; room_goto(rm_shop); }
            else if (_tx < _third*2)    { global.input_locked_until = current_time + 200; room_goto(rm_hub); }
            exit;
        }

        // 3) Finished week → COLLECT placeholder.
        if (_finished) {
            var _mid = (M.list_top + M.list_bot)/2;
            if (ph_point_in_rect(_tx,_ty, PH_W/2-220, _mid+70-60, PH_W/2+220, _mid+70+60)) {
                var _cres = ph_week_collect(global.save);
                if (_cres.leveled) { ph_win_route(rm_profile, global.selected_date_key); exit; }
                toast_text = "+" + string(_cres.xp_total) + " XP COLLECTED";
                toast_col  = PH_COL_PURPLE; toast_timer = TOAST_DUR;
            }
            exit;
        }

        // 4) CLAIM on a claimable card (iterate the same sorted order as Draw).
        if (_ty > M.list_top && _ty < M.list_bot) {
            var _order = prof_sorted_indices();
            for (var _p = 0; _p < array_length(_order); _p++) {
                var _t = prof_card_top(_p, M.list_top);
                if (_t > M.list_bot || _t + CARD_H < M.list_top) continue;
                var _m = _ms[_order[_p]];
                if (ph_mission_claimable(global.save, _m)) {
                    var _cr = prof_claim_rect(_t);
                    if (ph_point_in_rect(_tx,_ty, _cr.l, _cr.cy-_cr.bh, _cr.r, _cr.cy+_cr.bh)) {
                        var _r = ph_mission_claim(global.save, _m);
                        if (_r.ok) {
                            if (_r.levels_gained > 0) { ph_win_route(rm_profile, global.selected_date_key); exit; }
                            // Stars fly from this tile's reward ★ up to the level ★.
                            starfly_active = true; starfly_t = 0;
                            starfly_src_x  = REW_CX; starfly_src_y = _t + CARD_H/2;
                        }
                        exit;
                    }
                }
            }
        }
    }
}

// ── Scroll physics (fling decay + clamp) ──────────────────────────────────────
if (!device_mouse_check_button(0, mb_left)) {
    scroll_vel *= 0.88;
    scroll_y   -= scroll_vel;
}
scroll_y = clamp(scroll_y, 0, scroll_max);
