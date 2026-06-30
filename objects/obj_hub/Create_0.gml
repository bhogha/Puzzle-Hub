// ── Layout constants ──────────────────────────────────────────────────────────
// calexpand_h is 560 so a 6-row month grid + DOW header fits without clipping.
// All field values are plain constants — non-constant expressions inside a
// struct literal generate anonymous C++ constructors that can cause linker
// errors in GameMaker's compiled output. Safe-area offsets are applied AFTER
// construction via simple property assignment below.
LAYOUT = {
    status_h:       40,
    chiprow_y:      30,
    chiprow_h:     130,
    calbar_y:      230,
    calbar_h:      110,
    calexpand_h:   560,
    strip_h:       280,   // taller so the day strip and progress tube have breathing room
    section_h:      40,   // gap between the calendar/progress band and the card list (header text removed 2026-06-29)
    card_h:        317,   // keeps the Penpot tile's 1430×450 (≈3.18:1) proportions at the 1008px render width, so icon/text/pill scale uniformly
    card_gap:      -12,   // card_*.png has ~50px baked transparent padding (≈35px on-screen) so even gap 0 leaves a wide band; a small negative gap overlaps the transparent boxes (NOT the artwork) to tighten the visible spacing

    card_pad_x:     36,
    nav_h:         190,
    radius:         28,
    cal_grid_off:   62,   // y-offset of month grid below calbar — bigger gap above the SMTWTFS header
    cal_cell_h:     60,   // 6 rows × 60 + grid_off 62 + calbar_h 110 = 532 (fits inside calexpand_h 560)
    cal_monthnav_gap: 24, // gap between the last date row and the month-nav slider bar
    cal_monthnav_h:   86, // height of the prev/next month slider bar (Penpot "Month Slider")
};
// Push top-anchored elements below the Dynamic Island / status bar, and extend
// the nav bar to cover the home indicator. Applied after construction to avoid
// anonymous-constructor linker issues.
LAYOUT.chiprow_y += global.safe_top_gui;
LAYOUT.calbar_y  += global.safe_top_gui;
LAYOUT.nav_h     += global.safe_bottom_gui;

DOW_LABELS  = ["S","M","T","W","T","F","S"];
MONTH_NAMES = ["January","February","March","April","May","June",
               "July","August","September","October","November","December"];

cards = ph_game_cards();

// ── Tile press feedback (press-in nudge while held → spring-pop on release) ────
// A tapped card sinks a few px while the finger is down, then springs back past
// rest on release. Drives the tactile "button" feel; the iris transition launches
// from the tap on a valid card open. Knobs:
card_press_idx = -1;   // card index the finger is currently pressing, or -1
card_press_t   = 0;    // 0..1 eased press-in while held
card_pop_idx   = -1;   // card index playing the release spring-pop, or -1
card_pop_t     = 0;    // 0..1 pop progress
CARD_PRESS_DY  = 12;   // press-in depth (px the tile sinks while held)
CARD_PRESS_FR  = 6;    // frames to reach full press-in
CARD_POP_FR    = 14;   // frames of the release spring-pop

// ── Date state ────────────────────────────────────────────────────────────────

// Rebuilds the 7-day strip centred on _center_dt (index 3 = that day).
// Called from hub_refresh_dates (centred on today) and after every date
// selection so the strip follows the selected day.
hub_center_strip_on = function(_center_dt) {
    // Uses explicit property assignment instead of struct literals to avoid
    // generating anonymous C++ constructors that break the GameMaker linker.
    strip_days = array_create(7);
    for (var _i = 0; _i < 7; _i++) {
        var _dt        = ph_date_add_days(_center_dt, _i - 3);
        var _s         = {};
        _s.dt          = _dt;
        _s.key         = ph_date_key(_dt);
        _s.dow         = ph_day_of_week(_dt);
        _s.label       = string(date_get_day(_dt));
        strip_days[_i] = _s;
    }
};

// ── Viewed month (calendar month-selector) ──────────────────────────────────────
// cur_year/cur_month always track TODAY (used for the "no future months" cap and
// the today highlight). cal_view_year/cal_view_month are the month currently
// SHOWN by the expanded calendar — the player moves these with the prev/next
// month slider without changing today or their selected day.
cal_view_year  = date_get_year(date_current_datetime());
cal_view_month = date_get_month(date_current_datetime());

// Rebuilds month_days for the currently viewed month (cal_view_year/month).
hub_build_month_grid = function() {
    month_days = [];
    var _first_dow = ph_day_of_week(date_create_datetime(cal_view_year,cal_view_month,1,0,0,0));
    var _dim       = ph_days_in_month(cal_view_year, cal_view_month);
    for (var _i = 0; _i < _first_dow; _i++) array_push(month_days, undefined);
    for (var _d = 1; _d <= _dim; _d++) {
        var _dt = date_create_datetime(cal_view_year,cal_view_month,_d,0,0,0);
        array_push(month_days, { dt:_dt, key:ph_date_key(_dt), day:_d });
    }
    month_grid_rows = ceil(array_length(month_days) / 7);
};

// Anchors the viewed month to the currently selected day's month, then rebuilds
// the grid. Called whenever the calendar is toggled so the closed bar label and
// the month it reopens to always match the day the player is on.
hub_view_to_selected = function() {
    var _k = global.selected_date_key;
    cal_view_year  = real(string_copy(_k, 1, 4));
    cal_view_month = real(string_copy(_k, 6, 2));
    hub_build_month_grid();
};

// Steps the viewed month by ±1 (with year rollover). Capped at today's month —
// entirely-future months hold no playable days, so the next arrow stops there.
hub_month_step = function(_delta) {
    var _m = cal_view_month + _delta;
    var _y = cal_view_year;
    while (_m < 1)  { _m += 12; _y--; }
    while (_m > 12) { _m -= 12; _y++; }
    if (_y > cur_year || (_y == cur_year && _m > cur_month)) return;   // no future months
    cal_view_year  = _y;
    cal_view_month = _m;
    hub_build_month_grid();
};

// Rebuilds today_dt/today_key/cur_year/cur_month, then re-centres the strip on
// today and refreshes the month grid. Called from Create_0 and again from Step_0
// if the date rolls over while the hub is left open past midnight.
hub_refresh_dates = function() {
    var _prev_cur_y = variable_instance_exists(id, "cur_year")  ? cur_year  : -1;
    var _prev_cur_m = variable_instance_exists(id, "cur_month") ? cur_month : -1;

    var _now = date_current_datetime();
    today_dt   = _now;
    today_key  = ph_date_key(_now);
    cur_year   = date_get_year(_now);
    cur_month  = date_get_month(_now);

    // 7-day strip centred on today
    hub_center_strip_on(_now);

    // If a midnight rollover advanced today while the player was parked on the
    // old "today" month, follow it forward; otherwise leave the viewed month put.
    if (cal_view_year == _prev_cur_y && cal_view_month == _prev_cur_m) {
        cal_view_year  = cur_year;
        cal_view_month = cur_month;
    }

    hub_build_month_grid();
};
hub_refresh_dates();

// ── Scroll ────────────────────────────────────────────────────────────────────
scroll_y    = 0;
scroll_vel  = 0;
var _total_cards_h = array_length(cards) * (LAYOUT.card_h + LAYOUT.card_gap) - LAYOUT.card_gap;
scroll_max  = max(0, _total_cards_h - (PH_H - LAYOUT.nav_h - LAYOUT.calbar_y - LAYOUT.calbar_h - LAYOUT.strip_h - LAYOUT.section_h - 40));

// ── Calendar animation ────────────────────────────────────────────────────────
cal_open     = false;
cal_anim_t   = 0;

// ── Touch tracking ────────────────────────────────────────────────────────────
mx_prev = 0;
my_prev = 0;
drag_start_x = 0;
drag_start_y = 0;
drag_dist    = 0;
is_dragging  = false;

// ── Coin-flow reward animation ────────────────────────────────────────────────
// Played once when the hub is entered straight after a Level-Up coin claim
// (obj_win.lu_claim stashes the granted amount in global.coin_flow_amount). A
// stream of coins arcs from the lower-centre of the screen into the top-right
// coin pill, and a "+N" label rises and fades just under the pill. The flag is
// consumed here so it only plays the once.
coinflow_active  = false;
coinflow_amount  = 0;
coinflow_coins   = [];     // {sx0,sy0, cx,cy, tx,ty, delay, t, dur, arrived}
coinflow_t       = 0;      // master frame counter
coinflow_label_t = -1;     // <0 = label not started; else 0..1 rise/fade
coinflow_pop     = 0;      // 0..1 pill-coin pulse when a coin lands

// Starts the coins-into-the-pill animation for _amount coins. Reused by the
// Level-Up entry path (global.coin_flow_amount, below) and the Daily Spin claim.
hub_start_coinflow = function(_amount) {
    if (_amount <= 0) return;
    ph_sfx(snd_coin, 1.0);   // coins streaming into the wallet pill
    ph_haptic_coin();        // light tick as the coins land
    coinflow_amount  = _amount;
    coinflow_active  = true;
    coinflow_t       = 0;
    coinflow_label_t = -1;
    coinflow_pop     = 0;
    coinflow_coins   = [];

    // Target = the gold-coin sprite inside the top-right coin pill. Mirrors the
    // geometry in Draw_64 §2 (_coin_cx = (PH_W-24-310)+12 ; _crow_cy).
    var _tcx = PH_W - 322;
    var _tcy = LAYOUT.chiprow_y + LAYOUT.chiprow_h/2;

    var _n = 14;                          // number of flying coins
    for (var _i = 0; _i < _n; _i++) {
        var _c = {};
        _c.sx0     = PH_W/2 + random_range(-170, 170);   // launch spread
        _c.sy0     = PH_H * 0.60 + random_range(-70, 70);
        _c.tx      = _tcx;
        _c.ty      = _tcy;
        _c.delay   = _i * 4;                              // staggered stream
        _c.t       = 0;                                   // 0..1 progress
        _c.dur     = 24 + irandom(10);                    // frames to arrive
        _c.arrived = false;
        // Control point for a gentle upward arc.
        _c.cx = (_c.sx0 + _tcx) / 2 + random_range(-90, 90);
        _c.cy = min(_c.sy0, _tcy) - random_range(60, 160);
        coinflow_coins[_i] = _c;
    }
};

// Level-Up entry: a queued coin reward plays its flow once on hub entry.
if (variable_global_exists("coin_flow_amount") && global.coin_flow_amount > 0) {
    var _amt = global.coin_flow_amount;
    global.coin_flow_amount = 0;          // consume — don't replay on re-entry
    hub_start_coinflow(_amt);
}

// ── First-run soft onboarding (no overlay / text / dimming) ──────────────────
// Playtest feedback: the old caption+dots coachmark tour confused players (they
// tried to swipe between steps, felt they "got it wrong"). Replaced with pure
// soft guidance that never blocks the screen: on the very first app open (or
// after a progress reset; ph_save_reset clears save.tutorial_done) the card list
// AUTO-SCROLLS from the last game (bottom) up to the first game (top) — as if the
// player flicked up through the whole list — then ~1s after it settles a finger
// (scr_tutorial) fades in pointing at the TOP tile's PLAY button. The hub stays
// fully interactive throughout — the player can scroll/tap/explore at will. The
// hint clears for good the first time the player opens any puzzle.
finger = ph_finger_create();

intro_active   = !global.save.tutorial_done;   // run the auto-scroll + finger once
intro_t        = 0;                             // 0..1 auto-scroll progress
intro_settle_t = -1;                            // frames since the scroll settled (-1 = not yet)
INTRO_SLIDE_FR        = 96;                      // ~1.6s auto-scroll sweep
INTRO_FINGER_DELAY_FR = 60;                      // ~1s pause after settle before the finger appears
// Start parked at the bottom of the list (showing the LAST game) so the intro
// sweep climbs up to the first. (scroll_max was computed just above.)
if (intro_active) scroll_y = scroll_max;

// ── Daily-progress FTUE coach (first RETURN from a puzzle) ────────────────────
// The FIRST time the player returns to the hub from a puzzle AFTER solving their
// first puzzle, run the one-time 2-step daily-progress tutorial (see scr_tutorial
// ph_dailytut_*). "From a puzzle" = obj_persistent tracks the room we came from in
// global.room_curr (still the source room at Create time); "after first solve" =
// ph_has_any_solve. Shown once ever (save.daily_progress_tut_done); never during
// the first-run intro; completing it persists the flag AND triggers the
// notification-permission prompt.
dailytut = ph_dailytut_create();
var _from_room = variable_global_exists("room_curr") ? global.room_curr : -1;
if (!global.save.daily_progress_tut_done
 && !intro_active
 && ph_room_is_puzzle(_from_room)
 && ph_has_any_solve(global.save)) {
    ph_dailytut_begin(dailytut);
}

// ── Daily Spin ────────────────────────────────────────────────────────────────
// Free once-per-day prize wheel (see scr_spin). Opens immediately if the player
// has reached the unlock session and hasn't claimed today's spin yet — but never
// during the first-run intro (a brand-new / just-reset player gets the soft
// finger hint instead; the spin can appear on a later session anyway), and never
// while the daily-progress FTUE coach is showing (it takes priority this entry).
spin = ph_spin_create();
if (!intro_active && !ph_dailytut_is_open(dailytut) && ph_spin_eligible(global.save))
    ph_spin_open(spin);
