// ── Hub — Draw GUI ────────────────────────────────────────────────────────────
var _save  = global.save;
var _level = ph_level_from_xp(_save.xp);
var _coins = _save.coins;
var _sel   = global.selected_date_key;

var _cal_h    = lerp(LAYOUT.calbar_h, LAYOUT.calexpand_h, cal_anim_t);
// When the calendar opens the 7-day strip is faded out, so the strip slot
// shrinks too — this pulls the progress tube, "TODAY'S GAMES" header, and the
// card list up close to the calendar grid instead of leaving an empty band.
// Keep this in sync with Step_0 (the tap handler computes _body_top the same way).
var _eff_strip_h = LAYOUT.strip_h * lerp(1.0, 0.50, cal_anim_t);
var _body_top    = LAYOUT.calbar_y + _cal_h + _eff_strip_h + LAYOUT.section_h;
var _body_bot    = PH_H - LAYOUT.nav_h;

// ═══════════════════════════════════════════════════════════
// 1. BACKGROUND — cream + subtle dot grid
// ═══════════════════════════════════════════════════════════
draw_set_color(PH_COL_BG);
draw_rectangle(0, 0, PH_W, PH_H, false);
ph_draw_dot_bg(PH_COL_TILE_DARK);

// ═══════════════════════════════════════════════════════════
// 2. CHIP ROW  — level badge (top-left) | coin pill (top-right)
// ═══════════════════════════════════════════════════════════
var _crow_cy = LAYOUT.chiprow_y + LAYOUT.chiprow_h/2;

// Both pills share the same height so the row reads as a balanced pair.
var _pill_h  = 68;
var _pill_r  = 34;   // matching corner radius

// "LVL" pill — anchored to the top-left corner. The star sprite is positioned
// to overlap the pill's left rounded end so it reads as a "badge on a pill",
// not a separate icon floating to the left.
var _lvl_x1 = 70;
var _lvl_x2 = _lvl_x1 + 200;
ph_draw_chip(_lvl_x1, _crow_cy - _pill_h/2, _lvl_x2, _crow_cy + _pill_h/2,
             _pill_r, PH_COL_WHITE, PH_COL_TILE_DARK, 5);

// — Star level badge (3D star sprite + number overlay) — sits on the pill's
// left curve, with its centre 12px inside the pill edge.
var _star_s  = 110 / 512;   // ~110px drawn
var _star_cx = _lvl_x1 + 12;
draw_sprite_ext(global.spr_star3d, 0, _star_cx, _crow_cy, _star_s, _star_s, 0, c_white, 1);
ph_draw_text(_star_cx, _crow_cy + 2, string(_level), global.fnt_disp_sm, PH_COL_WHITE, fa_center, fa_middle);

// LVL label — left-aligned just to the right of the star sprite.
ph_draw_text(_star_cx + 56, _crow_cy,
             "LVL", global.fnt_num_md, PH_COL_DARK, fa_left, fa_middle);

// — Coin pill — anchored to the top-right corner —
var _pill_x2 = PH_W - 24;          // right margin
var _pill_x1 = _pill_x2 - 310;     // pill width unchanged
ph_draw_chip(_pill_x1, _crow_cy-_pill_h/2, _pill_x2, _crow_cy+_pill_h/2,
             _pill_r, PH_COL_WHITE, PH_COL_TILE_DARK, 5);

// Gold coin sprite — same size as the star badge, overlapping the pill's left curve.
var _coin_s  = 110 / 512;
var _coin_cx = _pill_x1 + 12;
draw_sprite_ext(global.spr_gold_coin, 0, _coin_cx, _crow_cy, _coin_s, _coin_s, 0, c_white, 1);

// Pink "+" button inside pill on right
var _plus_cx = _pill_x2 - 36;
ph_draw_chip(_plus_cx-24, _crow_cy-24, _plus_cx+24, _crow_cy+24,
             24, PH_COL_PINK, PH_COL_PINK_DEEP, 4);
ph_draw_text(_plus_cx, _crow_cy-2, "+", global.fnt_disp_xs, PH_COL_WHITE, fa_center, fa_middle);

// Coin value — right-aligned, sitting just to the left of the "+" button.
// Uses a thousands separator so 4-digit balances stay readable in the pill.
ph_draw_text(_plus_cx - 32, _crow_cy, ph_format_int_thousands(_coins),
             global.fnt_num_md, PH_COL_DARK, fa_right, fa_middle);

// ═══════════════════════════════════════════════════════════
// 3. CALENDAR BAR  (tappable — expands to month grid)
// ═══════════════════════════════════════════════════════════
var _cal_y1  = LAYOUT.calbar_y;
var _cal_cy  = _cal_y1 + LAYOUT.calbar_h/2;

// Large teal background covering calendar, week view, progress bar AND the
// 3D gift/trophy icons that hang off the progress tube. Formula tracks the
// effective progress-tube y (≈ 0.82 × _eff_strip_h) plus the trophy hang (~78)
// and ~10px of padding, so it stays correct in both the closed and open states.
var _teal_bottom = _cal_y1 + _cal_h + _eff_strip_h * 0.82 + 88;

// The Month Banner block (slightly darker light-teal)
draw_set_color(PH_COL_TEAL_SOFT);
draw_rectangle(0, _cal_y1, PH_W, _cal_y1 + LAYOUT.calbar_h, false);

// The Week View & Progress Bar block (very pale teal)
draw_set_color(merge_color(PH_COL_TEAL_SOFT, PH_COL_WHITE, 0.6));
draw_rectangle(0, _cal_y1 + LAYOUT.calbar_h, PH_W, _teal_bottom, false);

// Expand scissor upwards so the larger calendar icon doesn't get clipped
ph_scissor_gui(0, _cal_y1 - 40, PH_W, _cal_h + 40);

// 3D Calendar icon (left) - enlarged and overlapping top edge
var _cal_icon_s = 130 / 512;
draw_sprite_ext(global.spr_cal, 0,
                LAYOUT.card_pad_x + 58, _cal_y1 + 16,
                _cal_icon_s, _cal_icon_s, 0, c_white, 1);

// Month + year label
ph_draw_text(PH_W/2, _cal_cy,
             MONTH_NAMES[cur_month-1] + " " + string(cur_year),
             global.fnt_body_md, PH_COL_TEAL_DEEP, fa_center, fa_middle);

// Expanded month grid
if (cal_anim_t > 0.05) {
    var _cell_w   = PH_W / 7;
    var _cell_h   = LAYOUT.cal_cell_h;
    var _grid_top = _cal_y1 + LAYOUT.calbar_h + LAYOUT.cal_grid_off;

    // Day-of-week header (SMTWTFS) — sits just above the date grid, stronger
    // colour and font than before so it reads clearly against the teal band.
    for (var _di = 0; _di < 7; _di++) {
        ph_draw_text(_di*_cell_w + _cell_w/2, _grid_top - 22,
                     DOW_LABELS[_di], global.fnt_body_sm, PH_COL_TEAL_DEEP, fa_center, fa_middle);
    }
    for (var _mi = 0; _mi < array_length(month_days); _mi++) {
        var _mday = month_days[_mi];
        if (_mday == undefined) continue;
        var _ri = floor(_mi/7); var _ci = _mi mod 7;
        var _mcx = _ci*_cell_w + _cell_w/2;
        var _mcy = _grid_top + _ri*_cell_h + _cell_h/2;
        var _is_sel_m   = (_mday.key == _sel);
        var _is_today_m = (_mday.key == today_key);
        var _solved_m   = ph_solved_count_on(_save, _mday.key);

        // Only draw a background pill for days that have state (selected /
        // today / solved). Plain days show just the number on the teal band.
        if (_is_sel_m) {
            ph_draw_rounded(_mcx-26, _mcy-24, _mcx+26, _mcy+24, 12, PH_COL_PINK);
        } else if (_is_today_m) {
            ph_draw_rounded(_mcx-26, _mcy-24, _mcx+26, _mcy+24, 12, PH_COL_YELLOW);
        } else if (_solved_m > 0) {
            ph_draw_rounded(_mcx-26, _mcy-24, _mcx+26, _mcy+24, 12, PH_COL_TEAL);
        }

        var _mtc = (_is_sel_m || _solved_m > 0) ? PH_COL_WHITE : PH_COL_DARK;
        ph_draw_text(_mcx, _mcy, string(_mday.day), global.fnt_body_sm, _mtc, fa_center, fa_middle);
    }
}
ph_scissor_reset();

// ═══════════════════════════════════════════════════════════
// 4. 7-DAY STRIP — fades out as the calendar opens (the month grid above
//    already shows every day, so the strip would be redundant when expanded).
// ═══════════════════════════════════════════════════════════
var _strip_top   = _cal_y1 + _cal_h;
var _sw          = PH_W / 7;
var _strip_alpha = 1.0 - cal_anim_t;

if (_strip_alpha > 0.02) {
    draw_set_alpha(_strip_alpha);
    for (var _si = 0; _si < 7; _si++) {
        var _sd       = strip_days[_si];
        var _scx      = _si * _sw + _sw/2;
        var _scy      = _strip_top + _eff_strip_h * 0.32;
        var _is_sel   = (_sd.key == _sel);
        var _is_today = (_sd.key == today_key);
        var _solved   = ph_solved_count_on(_save, _sd.key) > 0;

        // Day of week letter (above)
        var _dtc = (_is_sel || _is_today) ? PH_COL_DARK : PH_COL_GRAY;
        ph_draw_text(_scx, _scy - 44, DOW_LABELS[_sd.dow], global.fnt_body_xs, _dtc, fa_center, fa_middle);

        // Selected/Today highlight (solid yellow circle behind number)
        if (_is_sel || _is_today) {
            draw_set_color(PH_COL_YELLOW);
            draw_circle(_scx, _scy + 18, 40, false);
        }

        // Number text (always dark)
        ph_draw_text(_scx, _scy + 18, _sd.label, global.fnt_body_md, PH_COL_DARK, fa_center, fa_middle);

        // Solved badge (pink circle + check sprite) at bottom right.
        // The check icon is white-on-transparent — keep it small enough that the
        // strokes stay inside the pink circle (or the white would bleed onto the
        // cream background and disappear).
        if (_solved) {
            var _badge_cx = _scx + 24;
            var _badge_cy = _scy + 44;
            var _badge_r  = 18;
            draw_set_color(PH_COL_PINK);
            draw_circle(_badge_cx, _badge_cy, _badge_r, false);
            ph_draw_icon(global.spr_icon_check, _badge_cx, _badge_cy, 0.10, c_white);
        }
    }
    draw_set_alpha(1);
}

// ── Progress tube ─────────────────────────────────────────────────────────────
var _ptube_top    = _strip_top + _eff_strip_h * 0.82;
var _solved_today = ph_solved_count_on(_save, _sel);
var _prog         = _solved_today / PH_PUZZLES_PER_DAY;

// Tube bounds — leave right gap for trophy icon
var _tx1 = LAYOUT.card_pad_x;
var _tx2 = PH_W - LAYOUT.card_pad_x - 96;  // gap for trophy
var _ty1 = _ptube_top;
var _ty2 = _ptube_top + 46;
var _tr  = 23;

// Track (beige/dark when not completed)
ph_draw_rounded(_tx1, _ty1, _tx2, _ty2, _tr, PH_COL_TILE_DARK);

// Purple fill (when completed)
if (_prog > 0) {
    ph_draw_rounded(_tx1, _ty1,
                    max(_tx1 + _tr*2, _tx1 + (_tx2-_tx1)*_prog),
                    _ty2, _tr, PH_COL_PURPLE);
}

// Tick dividers (segments the bar)
for (var _ti = 1; _ti < PH_PUZZLES_PER_DAY; _ti++) {
    var _tick_x = _tx1 + (_tx2-_tx1)*(_ti/PH_PUZZLES_PER_DAY);
    draw_set_color(PH_COL_BG);
    draw_line_width(_tick_x, _ty1, _tick_x, _ty2, 4);
}

// Gift box icon at milestone — sits directly over the thick bar, between 4th and 5th
var _tube_cy = (_ty1+_ty2)/2;
var _gift_x  = _tx1 + (_tx2-_tx1)*(4/PH_PUZZLES_PER_DAY);
var _gift_s  = 110 / 512;
draw_sprite_ext(global.spr_gift, 0, _gift_x, _tube_cy, _gift_s, _gift_s, 0, c_white, 1);

// Trophy icon — right end of tube
var _trophy_cx = _tx2 + 56;
var _trophy_s  = 100 / 512;
draw_sprite_ext(global.spr_trophy3d, 0, _trophy_cx, _tube_cy + 8, _trophy_s, _trophy_s, 0, c_white, 1);

// "4/10" counter — top-right above trophy
ph_draw_text(_trophy_cx, _ty1 - 8,
             string(_solved_today) + "/" + string(PH_PUZZLES_PER_DAY),
             global.fnt_body_sm, PH_COL_DARK, fa_center, fa_bottom);

// ═══════════════════════════════════════════════════════════
// 5. SECTION HEADER — "TODAY'S GAMES"
// ═══════════════════════════════════════════════════════════
// Title sits in the lower 70% of the section so it visually separates from
// the progress-tube band above. Anchored to _eff_strip_h so the header pulls
// up when the calendar is open.
var _sec_top = _strip_top + _eff_strip_h;
var _sec_cy  = _sec_top + LAYOUT.section_h * 0.70;
ph_draw_text(LAYOUT.card_pad_x, _sec_cy,
             "TODAY'S GAMES", global.fnt_disp_sm, PH_COL_DARK, fa_left, fa_middle);

// ═══════════════════════════════════════════════════════════
// 6. SCROLLABLE CARD LIST
// ═══════════════════════════════════════════════════════════
ph_scissor_gui(0, _body_top, PH_W, _body_bot - _body_top);

// Precompute card sprite scales (card sprite is 1400×400, origin centred)
var _card_w     = PH_W - 2*LAYOUT.card_pad_x;   // 1008
var _card_sx    = _card_w / 1400;               // ~0.72
var _card_sy    = LAYOUT.card_h / 400;          // ~0.575
// Game icon: drawn at 180px so it fits comfortably inside the white well baked
// into the card sprite (the well is only ~190px tall and the icon sprites have
// content close to their bounding box, so 220 was clipping vertically against
// the well's rounded corners). A scissor box still guards against overflow.
var _icon_sz    = LAYOUT.card_h - 40;           // 190 — layout footprint (for title offset)
var _icon_draw  = 180;                          // visual draw size — fits inside the well with margin
var _icon_s     = _icon_draw / 512;             // game icon scale
var _icon_cx    = LAYOUT.card_pad_x + 14 + _icon_sz/2; // centre of icon well
// Bounds of the white icon well in the card sprite (tuned by eye).
var _icon_clip_x = LAYOUT.card_pad_x + 14;      // ~50
var _icon_clip_w = 220;

for (var _i = 0; _i < array_length(cards); _i++) {
    var _card = cards[_i];
    var _cy1  = _body_top + _i*(LAYOUT.card_h + LAYOUT.card_gap) - scroll_y;
    var _ccy  = _cy1 + LAYOUT.card_h/2;

    if (_cy1 + LAYOUT.card_h < _body_top - 20 || _cy1 > _body_bot + 20) continue;

    // Anygram uses the consolidated DONE flag (with legacy M1/M2 fallback inside
    // the helper); other games use the simple per-name check.
    var _is_solved;
    if (_card.name == "ANYGRAM") {
        _is_solved = ph_anygram_is_done(_save, _sel);
    } else if (_card.name == "WORD WAVE") {
        _is_solved = ph_wordwave_is_done(_save, _sel);
    } else {
        _is_solved = ph_is_solved(_save, _sel, _card.name);
    }

    // ── Card background sprite ──────────────────────────────
    draw_sprite_ext(_card.card_spr, 0, PH_W/2, _ccy, _card_sx, _card_sy, 0, c_white, 1);

    // ── Game icon (left side) ───────────────────────────────
    // Nested scissor matches the white icon well in the card sprite (~190px
    // square). 200px clip with a 180px-wide icon leaves a 10px safety margin
    // on every side and ensures the icon never spills onto the coloured card.
    // We restore the outer body scissor immediately so the title/button draw
    // unclipped.
    // Clamp the icon clip to the body region [_body_top, _body_bot]. gpu_set_scissor
    // REPLACES (not intersects) the outer body scissor, so without this clamp an
    // icon on a card scrolled partly above the list would draw over the
    // "TODAY'S GAMES" header / progress tube.
    var _icon_clip_h   = 200;
    var _icon_clip_top = max(_body_top, _ccy - _icon_clip_h/2);
    var _icon_clip_bot = min(_body_bot, _ccy + _icon_clip_h/2);
    if (_icon_clip_bot > _icon_clip_top) {
        ph_scissor_gui(_icon_clip_x, _icon_clip_top, _icon_clip_w, _icon_clip_bot - _icon_clip_top);
        draw_sprite_ext(_card.icon_spr, 0, _icon_cx, _ccy, _icon_s, _icon_s, 0, c_white, 1);
    }
    ph_scissor_gui(0, _body_top, PH_W, _body_bot - _body_top);

    // ── Title + subtitle ────────────────────────────────────
    var _tx = _icon_cx + _icon_sz/2 + 22;
    ph_draw_text(_tx, _ccy - 26, _card.name,     global.fnt_disp_sm, _card.text_col, fa_left, fa_middle);
    draw_set_alpha(0.7);
    ph_draw_text(_tx, _ccy + 28, _card.subtitle, global.fnt_body_xs, _card.text_col, fa_left, fa_middle);
    draw_set_alpha(1);

    // ── Right badge ─────────────────────────────────────────
    var _btn_right = PH_W - LAYOUT.card_pad_x - 18; // 1026
    var _btn_cy    = _ccy;
    var _btn_hh    = 34;  // half-height

    var _btype = variable_struct_exists(_card, "btn_type") ? _card.btn_type : "play";

    if (_is_solved && (_card.name == "ANYGRAM" || _card.name == "SUDOKU" || _card.name == "WORD WAVE" || _card.name == "SHIKAKU")) {
        // Stopwatch + finish time — translucent pill matching the "COMING SOON"
        // style (white @ 30% alpha) so the underlying card colour shows through.
        // Stopwatch icon is sized slightly larger than the time text per design ref.
        var _time_prefix = "anygram_time_";
        if (_card.name == "SUDOKU")    _time_prefix = "sudoku_time_";
        if (_card.name == "WORD WAVE") _time_prefix = "wordwave_time_";
        if (_card.name == "SHIKAKU")   _time_prefix = "shikaku_time_";
        var _time_key = _time_prefix + _sel;
        var _ag_time  = variable_struct_exists(_save, _time_key)
                        ? _save[$ _time_key] : "--:--";
        var _btn_hw = 140;
        ph_draw_pill(_btn_right-_btn_hw*2, _btn_cy-_btn_hh,
                     _btn_right,            _btn_cy+_btn_hh, PH_COL_WHITE, 0.30);
        draw_sprite_ext(global.spr_stopwatch, 0,
                        _btn_right-_btn_hw*2+50, _btn_cy,
                        72/512, 72/512, 0, c_white, 1);
        ph_draw_text(_btn_right-_btn_hw*2+102, _btn_cy,
                     _ag_time, global.fnt_body_md, PH_COL_WHITE, fa_left, fa_middle);
    } else if (_is_solved) {
        // Solved badge for non-Anygram puzzles — translucent pill + check sprite.
        var _btn_hw = 120;
        ph_draw_pill(_btn_right-_btn_hw*2, _btn_cy-_btn_hh,
                     _btn_right,           _btn_cy+_btn_hh, PH_COL_WHITE, 0.30);
        ph_draw_icon(global.spr_icon_check, _btn_right-_btn_hw*2+44, _btn_cy, 0.12, c_white);
        ph_draw_text(_btn_right-_btn_hw*2+82, _btn_cy, "SOLVED",
                     global.fnt_body_sm, PH_COL_WHITE, fa_left, fa_middle);
    } else if (_btype == "time_trophy") {
        var _btn_hw = 120;
        ph_draw_pill(_btn_right-_btn_hw*2, _btn_cy-_btn_hh,
                     _btn_right,           _btn_cy+_btn_hh, PH_COL_WHITE, 0.20);
        draw_sprite_ext(global.spr_trophy3d, 0,
                        _btn_right-_btn_hw*2+46, _btn_cy,
                        52/512, 52/512, 0, c_white, 1);
        ph_draw_text(_btn_right-_btn_hw*2+86, _btn_cy,
                     _card.best_time, global.fnt_body_sm, PH_COL_WHITE, fa_left, fa_middle);
    } else if (_btype == "locked") {
        // Wider pill so "COMING SOON" fits without clipping.
        var _btn_hw = 155;
        ph_draw_pill(_btn_right-_btn_hw*2, _btn_cy-_btn_hh,
                     _btn_right,           _btn_cy+_btn_hh, PH_COL_WHITE, 0.20);
        // Use the 3D lock sprite (icon_lock3d.png) — the flat spr_icon_lock.png
        // asset does not exist, so referencing it returned sprite -1 and crashed
        // the Draw event. Matches the colour-3D badge style used by time_trophy.
        draw_sprite_ext(global.spr_lock3d, 0, _btn_right-_btn_hw*2+40, _btn_cy,
                        52/512, 52/512, 0, c_white, 1);
        ph_draw_text(_btn_right-_btn_hw*2+74, _btn_cy, "COMING SOON",
                     global.fnt_body_xs, PH_COL_WHITE, fa_left, fa_middle);
    } else if (_btype == "play_translucent") {
        var _btn_hw = 90;
        ph_draw_pill(_btn_right-_btn_hw*2, _btn_cy-_btn_hh,
                     _btn_right,           _btn_cy+_btn_hh, PH_COL_WHITE, 0.30);
        ph_draw_text(_btn_right-_btn_hw, _btn_cy, "PLAY",
                     global.fnt_body_sm, PH_COL_WHITE, fa_center, fa_middle);
    } else if (_btype == "play_light") {
        var _btn_hw = 90;
        ph_draw_pill(_btn_right-_btn_hw*2, _btn_cy-_btn_hh,
                     _btn_right,           _btn_cy+_btn_hh, make_color_rgb(255, 245, 200), 1);
        ph_draw_text(_btn_right-_btn_hw, _btn_cy, "PLAY",
                     global.fnt_body_sm, _card.text_col, fa_center, fa_middle);
    } else {
        var _btn_hw = 90;
        ph_draw_chip(_btn_right-_btn_hw*2, _btn_cy-_btn_hh,
                     _btn_right,           _btn_cy+_btn_hh,
                     _btn_hh, PH_COL_DARK, make_color_rgb(10,5,20), 5);
        ph_draw_text(_btn_right-_btn_hw, _btn_cy, "PLAY",
                     global.fnt_body_sm, PH_COL_WHITE, fa_center, fa_middle);
    }
}

ph_scissor_reset();

// ═══════════════════════════════════════════════════════════
// 7. BOTTOM NAV  (order: Shop | Games | Profile — Games is middle)
// ═══════════════════════════════════════════════════════════
ph_draw_nav(1);
