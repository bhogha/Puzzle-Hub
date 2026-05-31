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
    card_h:        230,
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
