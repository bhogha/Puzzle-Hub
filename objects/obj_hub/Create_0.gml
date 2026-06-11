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
    section_h:     120,   // "TODAY'S GAMES" header row — extra height lets the title sit lower, clear of the progress tube
    card_h:        317,   // keeps the Penpot tile's 1430×450 (≈3.18:1) proportions at the 1008px render width, so icon/text/pill scale uniformly
    card_gap:       28,
    card_pad_x:     36,
    nav_h:         190,
    radius:         28,
    cal_grid_off:   62,   // y-offset of month grid below calbar — bigger gap above the SMTWTFS header
    cal_cell_h:     60,   // 6 rows × 60 + grid_off 62 + calbar_h 110 = 532 (fits inside calexpand_h 560)
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

// Rebuilds today_dt/today_key/cur_year/cur_month, then re-centres the strip on
// today and refreshes the month grid. Called from Create_0 and again from Step_0
// if the date rolls over while the hub is left open past midnight.
hub_refresh_dates = function() {
    var _now = date_current_datetime();
    today_dt   = _now;
    today_key  = ph_date_key(_now);
    cur_year   = date_get_year(_now);
    cur_month  = date_get_month(_now);

    // 7-day strip centred on today
    hub_center_strip_on(_now);

    // Month grid for expanded calendar
    month_days = [];
    var _first_dow = ph_day_of_week(date_create_datetime(cur_year,cur_month,1,0,0,0));
    var _dim       = ph_days_in_month(cur_year, cur_month);
    for (var _i = 0; _i < _first_dow; _i++) array_push(month_days, undefined);
    for (var _d = 1; _d <= _dim; _d++) {
        var _dt = date_create_datetime(cur_year,cur_month,_d,0,0,0);
        array_push(month_days, { dt:_dt, key:ph_date_key(_dt), day:_d });
    }
    month_grid_rows = ceil(array_length(month_days) / 7);
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

if (variable_global_exists("coin_flow_amount") && global.coin_flow_amount > 0) {
    coinflow_amount  = global.coin_flow_amount;
    global.coin_flow_amount = 0;          // consume — don't replay on re-entry
    coinflow_active  = true;

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
}
