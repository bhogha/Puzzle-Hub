// ── Room history tracking ─────────────────────────────────────────────────────
// Detect a room change one frame after it happens (a new room's Create_0 has
// already run by now, so it could still read the OLD room_curr = the room it was
// opened from). Powers the daily-progress FTUE "came from a puzzle" trigger.
if (room != global.room_curr) {
    global.room_prev = global.room_curr;
    global.room_curr = room;
}

// ── Screen transition (iris) — advance cover → swap room → reveal ─────────────
// Owned here (persistent) so it survives the room_goto and keeps drawing in the
// new room. Kicked off by ph_trans_begin (e.g. a hub tile tap).

// Idle anchor: any tap anywhere resets the inactivity clock used by the HINT-pill
// bounce (ph_hint_pill_draw). Tracked here because this object lives in every room.
if (device_mouse_check_button_pressed(0, mb_left)) {
    global.ph_idle_anchor = current_time;
    // Universal soft click for every tap. Specific actions (coin/win/correct/…)
    // layer their own richer sound on top; the debounce stops rapid-tap pileups.
    ph_sfx(snd_tap, 0.45, 1.0, PH_SFX_TAP_GAP);
    // Universal light haptic for every tap — covers buttons, cards, the letter
    // wheel, number pad and keyboards in one place; specific actions layer richer
    // haptics on top. iOS-only + debounced inside ph_haptic_tap.
    ph_haptic_tap();
}

// HTML5: re-fit the canvas when the browser window changes size (rotate / resize /
// dock). Must run BEFORE the no-transition early-out below. No-op on native.
if (os_browser != browser_not_a_browser) {
    if (browser_width != ph_last_bw || browser_height != ph_last_bh) {
        ph_last_bw = browser_width;
        ph_last_bh = browser_height;
        ph_html5_fit_canvas();
        surface_resize(application_surface, PH_W, global.PH_H_dyn);
        display_set_gui_size(PH_W, global.PH_H_dyn);
    }
}

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
