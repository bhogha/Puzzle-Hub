// ── Event Hub — Create ────────────────────────────────────────────────────────
// Weekly-missions screen (Penpot "Events" design). The old Profile identity card
// is gone: the page is dedicated to missions. Top bar (level · EVENT HUB · coin)
// → description line + reset-timer pill → scrollable mission list
// (In Progress / Completed-claimable / Claimed). The end-of-week "Week Complete →
// COLLECT" panel here is a minimal placeholder for the (Phase 4) designed screen.

// Make the week current; flip to "finished" if the timer expired while away.
ph_week_check_finish(global.save);

// ── Card geometry (source canvas 1080-wide; Penpot "Events" tile = 1410×390) ──
// The card background is the `card_mission` sprite (cream rect + divider + reward
// column baked in), so CARD_H tracks the sprite's 1410:390 aspect to avoid stretch.
CARD_L    = 36;
CARD_R    = PH_W - 36;
CARD_W    = CARD_R - CARD_L;
CARD_H    = round(CARD_W * 390/1410);   // ≈279, keeps the sprite undistorted
CARD_GAP  = 28;
DIVIDER_X = CARD_L + round(CARD_W * 1110/1410);  // matches the baked-in divider
ICON_SZ   = round(CARD_W * 256/1410);   // ≈183, matches the design icon tile
ICON_CX   = CARD_L + round(CARD_W * 30/1410) + ICON_SZ/2;
MAIN_X1   = CARD_L + round(CARD_W * 320/1410);   // text/CLAIM left edge (right of icon)
MAIN_X2   = DIVIDER_X - 22;
REW_CX    = (DIVIDER_X + CARD_R) / 2;

// ── Scroll state (drag + fling, mirrors obj_hub) ──────────────────────────────
scroll_y   = 0;
scroll_vel = 0;
scroll_max = 0;
drag_start_x = 0; drag_start_y = 0; drag_dist = 0; is_dragging = false;
mx_prev = 0; my_prev = 0;

// ── Claim celebration — ONE sequenced flow, three phases, each animated with a
// classic anticipation → action → reaction beat (Disney-style, exaggerated for a
// casual game). Tapping CLAIM runs the phases back-to-back; the list holds still
// until the reorder phase so each beat reads clearly:
//   phase 1 STARFLY  — the tile's reward ★ winds up (dips + swells), then a burst
//                      of stars arcs up to the top-bar level ★, which squash-
//                      stretches as they land.
//   phase 2 CHECKPOP — the emptied reward column morphs ★ → checkmark with an
//                      overshoot pop that settles back (anticipation dip first).
//   phase 3 REORDER  — only now does the claimed tile drop to the "claimed" group
//                      and the next mission rise, each card easing with an
//                      anticipation-dip + overshoot (easeInOutBack).
claim_phase   = 0;      // 0 = idle, 1 = STARFLY (+collision+checkmark), 2 = REORDER
claim_t       = 0;      // frames elapsed inside the current phase
claim_mi      = -1;     // mission index being claimed (identifies the tile)
levelstar_t   = -1;     // ≥0 = frames since the stars COLLIDED with the level ★

// Beat lengths (frames). Phase 1 = wind-up → flight → COLLISION → checkmark pop,
// where the collision is the sync point: the level ★ reaction and the tile's
// checkmark BOTH fire the instant the stars hit, not before. Phase 2 = the tile
// reorder, which starts the moment the checkmark has taken its place.
// Star flow (Royal-Match-style): the reward ★ DUPLICATES into STARFLY_N copies that
// gather + orbit each other at the spot, then peel off ONE BY ONE, ACCELERATING up
// to the level ★ and vanishing there with a light flash.
STARFLY_N      = 7;     // duplicate stars
SF_GATHER      = 12;    // each copy's spread-out time onto the orbit ring
SF_SPAWNGAP    = 4;     // frames between each copy APPEARING (they pop in one by one)
SF_ORBIT       = 26;    // cluster swirls in place before the first release
SF_RELGAP      = 7;     // frames between each copy's release (they flow one by one)
SF_TRAVEL      = 30;    // per-copy flight time (accelerating)
SF_ORBIT_R     = 46;    // orbit ring radius (px) at the source
SF_ORBIT_SPD   = 0.13;  // orbit angular speed (rad/frame)
SF_FLASH       = 8;     // arrival light-flash frames
CHECK_POP      = 24;    // ★→checkmark pop on the tile (when the last copy leaves)
// Level ★ reaction: EXPANDS to "embrace" as the copies stream in (opening LEAD
// frames before the first arrival), HOLDS open with a pulse per arrival, then
// absorbs + settles over TAIL frames.
LEVELSTAR_LEAD    = 24;   // frames before the FIRST arrival the embrace opens
LEVELSTAR_TAIL    = 14;   // frames after the LAST arrival to absorb + settle
LEVELSTAR_EMBRACE = 0.26; // peak grow (open-arms) amount
REORDER_BOUNCE   = 16;   // claimed tile's in-place anticipation bounce (before it drops)
REORDER_DUR      = 88;   // full reorder (bounce + slide)
BOUNCE_PX        = 32;   // claimed-tile anticipation hop height
REORDER_OVERSHOOT_PX = 20;   // settle overshoot at the end of the slide

// Pre-claim slot per mission index, frozen at claim time. During STARFLY/CHECKPOP
// the whole list renders at these slots (held still); REORDER lerps each card from
// here to its new sorted slot, so the claimed tile slides down to the claimed group.
slot_old      = [];

// ── Toast (reset confirmation + claim messages) ───────────────────────────────
toast_text  = "";
toast_col   = PH_COL_PINK_DEEP;
toast_timer = 0;
TOAST_DUR   = 120;

// ── Easter egg: triple-tap the level pill to wipe progress ────────────────────
level_tap_count     = 0;
level_tap_last      = 0;
LEVEL_TAP_WINDOW_MS = 2000;
LEVEL_TAP_REQUIRED  = 3;
pending_hub_timer   = -1;

// ── Per-frame layout (depends on dynamic PH_H / safe areas) ───────────────────
// Header is now just a description line + reset-timer pill (no identity card / no
// MISSIONS panel). `band_bot` = bottom of the cream top-bar band; below it is teal.
prof_metrics = function() {
    var _m = {};
    _m.topbar_cy = ph_safe_top() + 46;
    _m.band_bot  = _m.topbar_cy + 92;            // cream top-bar band ends here
    _m.desc_y    = _m.band_bot + 96;             // description line baseline
    _m.timer_cy  = _m.desc_y + 104;              // reset-timer pill centre
    _m.list_top  = _m.timer_cy + 96;             // mission list starts here
    _m.list_bot  = PH_H - (190 + global.safe_bottom_gui) - 8;
    return _m;
};

// Card top (screen y) for mission index _i, given the list-top anchor.
prof_card_top = function(_i, _list_top) {
    return _list_top + _i * (CARD_H + CARD_GAP) - scroll_y;
};

// CLAIM button rect for a card whose top is _t (Penpot button 450×150 → ~324×108
// scaled to the 1080 canvas). Mirrored in Step + Draw.
prof_claim_rect = function(_t) {
    var _r = {};
    _r.l  = MAIN_X1;
    _r.r  = MAIN_X1 + 324;
    _r.cy = _t + 78;
    _r.bh = 54;
    return _r;
};

// Resolve a mission icon key to a loaded sprite (sprites live on globals, not
// named resources, so this maps explicitly).
prof_icon = function(_k) {
    if (string_pos("game_", _k) == 1) return variable_global_get("spr_" + _k);
    switch (_k) {
        case "icon_trophy3d":  return global.spr_trophy3d;
        case "icon_puzzle":    return global.spr_puzzle;
        case "icon_gift":      return global.spr_gift;
        case "icon_calendar":  return global.spr_cal;
        case "icon_chest":     return global.spr_chest;
        case "icon_stopwatch": return global.spr_stopwatch;
        case "icon_bulb":      return global.spr_bulb;
    }
    return global.spr_star3d;
};

// Display order: claimable first, then in-progress, then claimed (stable within
// each group). Returns an array of mission indices. Used by Draw + Step so the
// rendered order and hit-tests always agree.
prof_sorted_indices = function() {
    var _ms = global.save.week.missions;
    var _claimable = [], _prog = [], _claimed = [];
    for (var _i = 0; _i < array_length(_ms); _i++) {
        var _m = _ms[_i];
        if (_m.claimed) array_push(_claimed, _i);
        else if (ph_mission_value(global.save, _m) >= _m.target) array_push(_claimable, _i);
        else array_push(_prog, _i);
    }
    return array_concat(_claimable, _prog, _claimed);
};
