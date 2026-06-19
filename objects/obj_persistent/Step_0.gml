// ── Screen transition (iris) — advance cover → swap room → reveal ─────────────
// Owned here (persistent) so it survives the room_goto and keeps drawing in the
// new room. Kicked off by ph_trans_begin (e.g. a hub tile tap).

// Idle anchor: any tap anywhere resets the inactivity clock used by the HINT-pill
// bounce (ph_hint_pill_draw). Tracked here because this object lives in every room.
if (device_mouse_check_button_pressed(0, mb_left)) global.ph_idle_anchor = current_time;

if (!global.trans_active) exit;

if (global.trans_phase == 1) {                          // COVER (iris closes in)
    global.trans_t += 1;
    if (global.trans_t >= global.TRANS_COVER_FR) {
        // Screen is fully covered now — swap rooms invisibly, then reveal.
        if (global.trans_room >= 0) room_goto(global.trans_room);
        global.trans_phase = 2;
        global.trans_t     = 0;
    }
} else {                                                // REVEAL (iris opens out)
    global.trans_t += 1;
    if (global.trans_t >= global.TRANS_REVEAL_FR) {
        global.trans_active = false;
        global.trans_phase  = 0;
    }
}
