// ── Event Hub — Step (input + scroll) ─────────────────────────────────────────
// Hit-tests read prof_metrics() (topbar_cy / list_top / list_bot) + the geometry
// constants in Create, so they stay aligned with the redesigned Draw.

// Per-frame timers (tick regardless of input lock).
if (toast_timer > 0) toast_timer--;

// ── Claim celebration state machine — phases run back-to-back ──────────────────
// Each phase advances claim_t; when it elapses we step to the next phase. The
// level-star "absorb" wobble (levelstar_t) is triggered as the flying stars land.
if (claim_phase == 1) {                                  // STARFLY → collision → checkmark
    claim_t++;
    // The first copy arrives at SF_GATHER+SF_ORBIT+SF_TRAVEL; the level ★ opens its
    // arms LEAD frames before that, then holds through the stream + settles after the
    // last. The tile's checkmark takes the spot when the last copy peels off (Draw).
    if (claim_t == SF_GATHER + SF_ORBIT + SF_TRAVEL - LEVELSTAR_LEAD) levelstar_t = 0;
    // Phase ends after the LAST copy has landed and the ★ has settled → REORDER.
    if (claim_t >= SF_GATHER + SF_ORBIT + (STARFLY_N-1)*SF_RELGAP + SF_TRAVEL + LEVELSTAR_TAIL + 4) { claim_phase = 2; claim_t = 0; }
} else if (claim_phase == 2) {                            // REORDER (bounce + slide)
    claim_t++;
    if (claim_t >= REORDER_DUR) { claim_phase = 0; claim_t = 0; claim_mi = -1; }
} else if (claim_phase == 3) {                            // FINISHED claim / CLAIM ALL (simultaneous)
    claim_t++;
    if (claim_t == SF_GATHER + SF_ORBIT + SF_TRAVEL - LEVELSTAR_LEAD) levelstar_t = 0;
    var _p3_dur = SF_GATHER + SF_ORBIT + (STARFLY_N-1)*SF_RELGAP + SF_TRAVEL + LEVELSTAR_TAIL + 4;
    if (claim_t >= _p3_dur) {
        claim_phase = 0; claim_t = 0; fly_idxs = [];
        if (finalize_after) {
            finalize_after = false;
            ph_week_collect(global.save);   // grants week bonus (if full clear) + rolls over to a fresh week
            scroll_y = 0; scroll_vel = 0;
        }
        // Any mission/bonus claim that crossed a level shows the Level-Up screen now.
        if (ph_levelup_pending()) { ph_win_route(rm_profile, global.selected_date_key); exit; }
    }
}
if (levelstar_t >= 0) { levelstar_t++; if (levelstar_t >= LEVELSTAR_LEAD + (STARFLY_N-1)*SF_RELGAP + LEVELSTAR_TAIL) levelstar_t = -1; }
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

// ── Sound on/off toggle (speaker chip, header bottom-left) ────────────────────
if (device_mouse_check_button_pressed(0, mb_left)
 && point_distance(_mx, _my, 120, M.timer_cy) <= 64) {
    var _now_on = ph_sfx_toggle();
    toast_text  = _now_on ? "SOUND ON" : "SOUND OFF";
    toast_timer = TOAST_DUR;
    exit;
}

// ── Haptics on/off toggle (vibrate chip, beside the speaker) ──────────────────
if (device_mouse_check_button_pressed(0, mb_left)
 && point_distance(_mx, _my, 244, M.timer_cy) <= 64) {
    var _hnow_on = ph_haptic_toggle();   // also fires a confirming buzz when turning ON
    toast_text   = _hnow_on ? "VIBRATION ON" : "VIBRATION OFF";
    toast_timer  = TOAST_DUR;
    exit;
}

// ── Scroll bounds ─────────────────────────────────────────────────────────────
var _total_h;
if (_finished) {
    var _gsb = prof_finished_groups((claim_phase == 3) ? fly_idxs : undefined);
    _total_h = prof_finished_layout(M.list_top, _gsb).content_h;
} else {
    _total_h = array_length(_ms) * (CARD_H + CARD_GAP) - CARD_GAP;
}
scroll_max = max(0, _total_h - (M.list_bot - M.list_top));

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

        // 3) Finished week → Week Complete: in-page individual CLAIM + CLAIM ALL.
        if (_finished) {
            if (claim_phase != 0) exit;                 // ignore taps during the celebration
            var _g  = prof_finished_groups(undefined);
            var _fl = prof_finished_layout(M.list_top, _g);

            // Individual CLAIM on a claimable card.
            var _ca = _g.claimable;
            for (var _i = 0; _i < array_length(_ca); _i++) {
                var _mi = _ca[_i];
                var _t  = _fl.top[_mi];
                if (_t > M.list_bot || _t + CARD_H < M.list_top) continue;
                var _cr = prof_claim_rect(_t);
                if (ph_point_in_rect(_tx,_ty, _cr.l, _cr.cy-_cr.bh, _cr.r, _cr.cy+_cr.bh)) {
                    var _m = _ms[_mi];
                    var _r = ph_mission_claim(global.save, _m);
                    if (_r.ok) {
                        fly_idxs = [_mi];
                        fly_top  = array_create(array_length(_ms), -99999);
                        fly_top[_mi]   = _t;            // freeze the source ★ position
                        finalize_after = !ph_week_has_claimable(global.save); // last one → roll over
                        claim_phase = 3; claim_t = 0; levelstar_t = -1;
                    }
                    exit;
                }
            }

            // CLAIM ALL button — fires every reward ★ at once, then rolls the week over.
            var _br = prof_claimall_rect(_fl.btn_cy);
            if (ph_point_in_rect(_tx,_ty, _br.l, _br.cy-_br.bh, _br.r, _br.cy+_br.bh)) {
                if (_fl.has_claimable) {
                    var _res = ph_week_claim_all(global.save);
                    // Freeze sources: keep the just-claimed tiles in their claimable slots.
                    var _fll = prof_finished_layout(M.list_top, prof_finished_groups(_res.indices));
                    fly_idxs = _res.indices;
                    fly_top  = _fll.top;
                    finalize_after = true;
                    claim_phase = 3; claim_t = 0; levelstar_t = -1;
                } else {
                    // Nothing claimable (all pre-claimed) — just grant the bonus + roll over.
                    ph_week_collect(global.save);
                    scroll_y = 0; scroll_vel = 0;
                    if (ph_levelup_pending()) { ph_win_route(rm_profile, global.selected_date_key); exit; }
                }
                exit;
            }
            exit;
        }

        // 4) CLAIM on a claimable card (iterate the same sorted order as Draw).
        // Ignore taps while a claim celebration is playing so it finishes cleanly.
        if (claim_phase == 0 && _ty > M.list_top && _ty < M.list_bot) {
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
                            // Freeze every card's pre-claim slot so the list holds
                            // still through STARFLY/CHECKPOP; REORDER lerps from here.
                            slot_old = array_create(array_length(_ms), 0);
                            for (var _q = 0; _q < array_length(_order); _q++) slot_old[_order[_q]] = _q;
                            // Kick off the sequenced celebration at phase 1 (STARFLY).
                            ph_sfx(snd_star, 0.95);   // reward stars gather + fly to the level star
                            ph_haptic_success();      // mission reward claimed
                            claim_mi      = _order[_p];
                            claim_phase   = 1;
                            claim_t       = 0;
                            levelstar_t   = -1;
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
