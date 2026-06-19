// ── Screen transition (iris) — advance cover → swap room → reveal ─────────────
// Owned here (persistent) so it survives the room_goto and keeps drawing in the
// new room. Kicked off by ph_trans_begin (e.g. a hub tile tap).
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
