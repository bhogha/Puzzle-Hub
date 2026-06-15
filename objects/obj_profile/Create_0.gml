// ── Profile — Create ──────────────────────────────────────────────────────────
// Missions screen (weekly personal-window set) per the Penpot "Profile Screen"
// design. Top bar (level · PROFILE · coin) → identity card → MISSIONS header +
// "Reset in N Days" pill → scrollable mission list (In Progress / Completed-
// claimable / Claimed). The end-of-week "Week Complete → COLLECT" panel here is
// a minimal placeholder for the (Phase 4) designed screen.

// Make the week current; flip to "finished" if the timer expired while away.
ph_week_check_finish(global.save);

// ── Card geometry (source canvas 1080-wide) ──────────────────────────────────
CARD_L    = 50;
CARD_R    = PH_W - 50;
CARD_H    = 250;
CARD_GAP  = 28;
DIVIDER_X = CARD_R - 270;          // reward column starts here
MAIN_X1   = 270;                   // text/CLAIM left edge (right of the icon tile)
MAIN_X2   = DIVIDER_X - 30;
REW_CX    = (DIVIDER_X + CARD_R) / 2;

// ── Scroll state (drag + fling, mirrors obj_hub) ──────────────────────────────
scroll_y   = 0;
scroll_vel = 0;
scroll_max = 0;
drag_start_x = 0; drag_start_y = 0; drag_dist = 0; is_dragging = false;
mx_prev = 0; my_prev = 0;

// ── Claim feedback: stars fly from the tile reward ★ to the top-bar level ★ ───
starfly_active = false;
starfly_t      = 0;
starfly_src_x  = 0;
starfly_src_y  = 0;
STARFLY_DUR    = 44;     // frames
STARFLY_N      = 6;      // stars per burst

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
prof_metrics = function() {
    var _m = {};
    _m.topbar_cy = ph_safe_top() + 46;
    _m.id_top    = _m.topbar_cy + 78;
    _m.id_h      = 330;
    _m.hdr_y     = _m.id_top + _m.id_h + 64;     // MISSIONS header baseline
    _m.list_top  = _m.hdr_y + 78;
    _m.list_bot  = PH_H - (190 + global.safe_bottom_gui) - 8;
    return _m;
};

// Card top (screen y) for mission index _i, given the list-top anchor.
prof_card_top = function(_i, _list_top) {
    return _list_top + _i * (CARD_H + CARD_GAP) - scroll_y;
};

// CLAIM button rect for a card whose top is _t. Mirrored in Step + Draw.
prof_claim_rect = function(_t) {
    var _r = {};
    _r.l  = MAIN_X1;
    _r.r  = MAIN_X1 + 300;
    _r.cy = _t + 80;
    _r.bh = 52;
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
