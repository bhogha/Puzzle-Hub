function ph_today_key() {
    return ph_date_key(date_current_datetime());
}

function ph_date_key(_dt) {
    var _y = date_get_year(_dt);
    var _m = date_get_month(_dt);
    var _d = date_get_day(_dt);
    var _ms = (_m < 10) ? ("0" + string(_m)) : string(_m);
    var _ds = (_d < 10) ? ("0" + string(_d)) : string(_d);
    return string(_y) + "-" + _ms + "-" + _ds;
}

function ph_seed_from_key(_key) {
    // Returns the day index since GameMaker's datetime epoch. Consecutive days
    // differ by exactly 1, so `_seed mod N` selects a different puzzle every
    // day for any window of size N (no month-boundary collisions).
    var _y = real(string_copy(_key, 1, 4));
    var _m = real(string_copy(_key, 6, 2));
    var _d = real(string_copy(_key, 9, 2));
    return floor(date_create_datetime(_y, _m, _d, 0, 0, 0));
}

function ph_day_of_week(_dt) {
    return date_get_weekday(_dt);   // 0=Sun … 6=Sat
}

function ph_days_in_month(_year, _month) {
    var _y2 = _year;
    var _m2 = _month + 1;
    if (_m2 > 12) { _m2 = 1; _y2++; }
    var _next = date_create_datetime(_y2, _m2, 1, 0, 0, 0);
    return date_get_day(_next - 1);   // subtract 1 day (datetime is a real; 1.0 == 1 day)
}

function ph_date_add_days(_dt, _n) {
    // GameMaker datetime values are real numbers where 1.0 == 1 day
    return _dt + _n;
}

function ph_date_compare_keys(_a, _b) {
    if (_a < _b) return -1;
    if (_a > _b) return  1;
    return 0;
}