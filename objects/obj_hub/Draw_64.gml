// ── Hub — Draw GUI ────────────────────────────────────────────────────────────
var _save  = global.save;
var _level = ph_level_from_xp(_save.xp);
var _coins = _save.coins;
var _sel   = global.selected_date_key;

var _cal_h    = lerp(LAYOUT.calbar_h, LAYOUT.calexpand_h, cal_anim_t);
// When the calendar opens the 7-day strip is faded out, so the strip slot
// shrinks too — this pulls the progress tube, "TODAY'S GAMES" header, and the
// card list up close to the calendar grid instead of leaving an empty band.
var _eff_strip_h = LAYOUT.strip_h * lerp(1.0, 0.50, cal_anim_t);

// _post_cal = y where content below the calendar (TODAY'S GAMES header + cards)
// begins. Closed: just below the 7-day strip slot. Open: just below the last
// date row of the month grid — the strip is faded out and the progress tube is
// hidden, so we no longer reserve their height and the header/cards sit close to
// the numbers. Blended by cal_anim_t and kept in sync with Step_0.
var _grid_rows   = ceil(array_length(month_days) / 7);
var _grid_bottom = LAYOUT.calbar_y + LAYOUT.calbar_h + LAYOUT.cal_grid_off + _grid_rows * LAYOUT.cal_cell_h;
// Open layout reserves room for the month-nav slider bar below the grid (kept in
// sync with Step_0). _mn_top/_mn_bot also drive the slider render in §3b.
var _mn_top      = _grid_bottom + LAYOUT.cal_monthnav_gap;
var _mn_bot      = _mn_top + LAYOUT.cal_monthnav_h;
var _post_cal    = lerp(LAYOUT.calbar_y + _cal_h + _eff_strip_h, _mn_bot + 28, cal_anim_t);
var _body_top    = _post_cal + LAYOUT.section_h;
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

// Level pill — anchored to the top-left corner. The star sprite is positioned
// to overlap the pill's left rounded end so it reads as a "badge on a pill",
// not a separate icon floating to the left.
var _lvl_x1 = 70;
var _lvl_x2 = _lvl_x1 + 200;
ph_draw_chip(_lvl_x1, _crow_cy - _pill_h/2, _lvl_x2, _crow_cy + _pill_h/2,
             _pill_r, PH_COL_WHITE, PH_COL_TILE_DARK, 5);

// — Star badge (plain 3D star, no number overlay per the updated design) — sits
// on the pill's left curve, with its centre 12px inside the pill edge.
var _star_s  = 110 / 512;   // ~110px drawn
var _star_cx = _lvl_x1 + 12;
draw_sprite_ext(global.spr_star3d, 0, _star_cx, _crow_cy, _star_s, _star_s, 0, c_white, 1);

// Level number — replaces the old "LVL" label; centred in the pill to the right
// of the star, matching the coin balance's font (Nunito Black).
ph_draw_text((_star_cx + 45 + _lvl_x2) / 2, _crow_cy, string(_level),
             global.fnt_num_md, PH_COL_DARK, fa_center, fa_middle);

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

// — Game title — centred between the LVL and coin pills at the top of the hub.
ph_draw_text(PH_W/2, _crow_cy, "PUZZLE HUB",
             global.fnt_disp_md, PH_COL_PINK, fa_center, fa_middle);

// ═══════════════════════════════════════════════════════════
// 3. CALENDAR BAR  (tappable — expands to month grid)
// ═══════════════════════════════════════════════════════════
var _cal_y1  = LAYOUT.calbar_y;
var _cal_cy  = _cal_y1 + LAYOUT.calbar_h/2;

// Large teal background. Two states, blended by cal_anim_t:
//  • Closed — must cover the week strip, progress tube and the 3D gift/trophy
//    icons that hang off it (≈ 0.82 × _eff_strip_h + ~88 trophy hang).
//  • Open — the progress tube is hidden, so the teal only needs to reach just
//    below the last row of date numbers (the grid sits ~28px inside _cal_h),
//    leaving a clear gap above the "TODAY'S GAMES" title.
var _teal_bottom = lerp(_cal_y1 + _cal_h + _eff_strip_h * 0.82 + 88, _mn_top, cal_anim_t);

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

// Month + year label — reflects the VIEWED month (cal_view_*), which the player
// moves with the month-nav slider; defaults to today's month.
ph_draw_text(PH_W/2, _cal_cy,
             MONTH_NAMES[cal_view_month-1] + " " + string(cal_view_year),
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
        var _is_future_m = (ph_date_compare_keys(_mday.key, today_key) > 0);
        var _solved_m   = ph_solved_count_on(_save, _mday.key);

        // Future days aren't playable yet — fade them so they read as disabled.
        if (_is_future_m) draw_set_alpha(0.30);

        // Only draw a background box for days that have state (selected / today
        // / solved). Plain days show just the number on the teal band. Selected
        // and today use the pink / yellow box sprites; solved keeps the teal pill.
        if (_is_sel_m) {
            draw_sprite_ext(global.spr_cal_day_sel, 0, _mcx, _mcy, 56/106, 52/107, 0, c_white, 1);
        } else if (_is_today_m) {
            draw_sprite_ext(global.spr_cal_day_today, 0, _mcx, _mcy, 56/106, 52/107, 0, c_white, 1);
        } else if (_solved_m > 0) {
            ph_draw_rounded(_mcx-26, _mcy-24, _mcx+26, _mcy+24, 12, PH_COL_TEAL);
        }

        var _mtc = (_is_sel_m || _solved_m > 0) ? PH_COL_WHITE : PH_COL_DARK;
        ph_draw_text(_mcx, _mcy, string(_mday.day), global.fnt_body_sm, _mtc, fa_center, fa_middle);

        if (_is_future_m) draw_set_alpha(1);
    }
}
ph_scissor_reset();

// ═══════════════════════════════════════════════════════════
// 3b. MONTH-NAV SLIDER  — prev / next month, below the date grid (Penpot
//     "Month Slider"). Appears with the expanded grid; drawn after the grid
//     scissor reset so it sits below the last date row, unclipped.
// ═══════════════════════════════════════════════════════════
if (cal_anim_t > 0.05) {
    var _mn_cy = (_mn_top + _mn_bot) * 0.5;
    draw_set_alpha(cal_anim_t);

    // Mint slider bar (Penpot #adfff1).
    draw_set_color(make_color_rgb(173, 255, 241));
    draw_rectangle(0, _mn_top, PH_W, _mn_bot, false);

    // Prev month (left) — always available; past days are playable.
    var _pm_m = cal_view_month - 1; var _pm_y = cal_view_year;
    if (_pm_m < 1) { _pm_m = 12; _pm_y--; }
    ph_draw_text(LAYOUT.card_pad_x + 20, _mn_cy,
                 "< " + MONTH_NAMES[_pm_m-1],
                 global.fnt_body_md, PH_COL_TEAL_DEEP, fa_left, fa_middle);

    // Next month (right) — hidden at today's month (no future-only months).
    if (!(cal_view_year == cur_year && cal_view_month == cur_month)) {
        var _nm_m = cal_view_month + 1; var _nm_y = cal_view_year;
        if (_nm_m > 12) { _nm_m = 1; _nm_y++; }
        ph_draw_text(PH_W - LAYOUT.card_pad_x - 20, _mn_cy,
                     MONTH_NAMES[_nm_m-1] + " >",
                     global.fnt_body_md, PH_COL_TEAL_DEEP, fa_right, fa_middle);
    }
    draw_set_alpha(1);
}

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
        var _is_future = (ph_date_compare_keys(_sd.key, today_key) > 0);
        var _solved   = ph_solved_count_on(_save, _sd.key) > 0;

        // Future days aren't playable yet — fade them so they read as disabled.
        var _day_alpha = _is_future ? _strip_alpha * 0.30 : _strip_alpha;
        draw_set_alpha(_day_alpha);

        // Day of week letter (above)
        var _dtc = (_is_sel || _is_today) ? PH_COL_DARK : PH_COL_GRAY;
        ph_draw_text(_scx, _scy - 44, DOW_LABELS[_sd.dow], global.fnt_body_xs, _dtc, fa_center, fa_middle);

        // Selected/Today highlight — yellow circle sprite behind the number.
        if (_is_sel || _is_today) {
            draw_sprite_ext(global.spr_today_circle, 0, _scx, _scy + 18,
                            80/124, 80/124, 0, c_white, _day_alpha);
        }

        // Number text (always dark)
        ph_draw_text(_scx, _scy + 18, _sd.label, global.fnt_body_md, PH_COL_DARK, fa_center, fa_middle);

        // Solved badge at bottom right — full-colour icon_check sprite (pink disc
        // with a white tick baked in), drawn at ~40px with no tint.
        if (_solved) {
            var _badge_cx = _scx + 24;
            var _badge_cy = _scy + 44;
            draw_sprite_ext(global.spr_check_badge, 0, _badge_cx, _badge_cy,
                            40/38, 40/38, 0, c_white, _day_alpha);
        }
    }
    draw_set_alpha(1);
}

// ── Progress tube ─────────────────────────────────────────────────────────────
// Hidden while the calendar is open — the expanded month grid is allowed to
// cover this band. Fades out together with the 7-day strip (_strip_alpha).
// The daily goal is "any PH_PUZZLES_PER_DAY solves" out of all available puzzles
// (currently 11 incl. Colordoku). Cap the displayed count at the goal so solving
// more than the goal still reads "10/10" rather than "11/10".
var _solved_today = min(ph_solved_count_on(_save, _sel), PH_PUZZLES_PER_DAY);

if (_strip_alpha > 0.02) {
    var _ptube_top = _strip_top + _eff_strip_h * 0.82;

    // Tube bounds — leave right gap for trophy icon
    var _tx1 = LAYOUT.card_pad_x;
    var _tx2 = PH_W - LAYOUT.card_pad_x - 96;  // gap for trophy
    var _ty1 = _ptube_top;
    var _ty2 = _ptube_top + 46;

    // Segmented bar built from the progress_bar_* sprites: one cell per daily
    // puzzle, the first _solved_today cells purple (filled), the rest grey.
    ph_draw_progress_segments(_tx1, _tx2, (_ty1+_ty2)/2, _ty2-_ty1,
                              PH_PUZZLES_PER_DAY, _solved_today, _strip_alpha);

    // Gift box icon at milestone — sits directly over the thick bar, between 4th and 5th
    var _tube_cy = (_ty1+_ty2)/2;
    var _gift_x  = _tx1 + (_tx2-_tx1)*(4/PH_PUZZLES_PER_DAY);
    var _gift_s  = 110 / 512;
    draw_sprite_ext(global.spr_gift, 0, _gift_x, _tube_cy, _gift_s, _gift_s, 0, c_white, _strip_alpha);

    // Trophy icon — right end of tube
    var _trophy_cx = _tx2 + 56;
    var _trophy_s  = 100 / 512;
    draw_sprite_ext(global.spr_trophy3d, 0, _trophy_cx, _tube_cy + 8, _trophy_s, _trophy_s, 0, c_white, _strip_alpha);

    // "4/10" counter — top-right above trophy
    draw_set_alpha(_strip_alpha);
    ph_draw_text(_trophy_cx, _ty1 - 8,
                 string(_solved_today) + "/" + string(PH_PUZZLES_PER_DAY),
                 global.fnt_body_sm, PH_COL_DARK, fa_center, fa_bottom);
    draw_set_alpha(1);
}

// ═══════════════════════════════════════════════════════════
// 5. SECTION HEADER — "TODAY'S GAMES"
// ═══════════════════════════════════════════════════════════
// Title is anchored to _post_cal. Closed it sits in the lower 70% of the section
// so it clears the progress-tube band above; open it rides higher (40%) so it
// tucks just under the month grid.
var _sec_off = lerp(LAYOUT.section_h * 0.70, LAYOUT.section_h * 0.40, cal_anim_t);
var _sec_cy  = _post_cal + _sec_off;
ph_draw_text(LAYOUT.card_pad_x, _sec_cy,
             "TODAY'S GAMES", global.fnt_disp_sm, PH_COL_DARK, fa_left, fa_middle);

// ═══════════════════════════════════════════════════════════
// 6. SCROLLABLE CARD LIST
// ═══════════════════════════════════════════════════════════
ph_scissor_gui(0, _body_top, PH_W, _body_bot - _body_top);

// Precompute card sprite scales. Derive the scale from the sprite's ACTUAL
// source dimensions (1430×450, origin centred) rather than hardcoded numbers,
// so re-exporting the card art at a different size can't desync the scale and
// break card sizing/spacing. All card sprites share one size, so the first
// card's dimensions drive the scale for every card. card_h (317) is set to keep
// the source aspect, so _card_sx ≈ _card_sy and everything scales uniformly.
var _card_w      = PH_W - 2*LAYOUT.card_pad_x;          // 1008 (target render width)
var _card_src_w  = sprite_get_width(cards[0].card_spr); // 1430
var _card_src_h  = sprite_get_height(cards[0].card_spr);// 450
var _card_sx     = _card_w / _card_src_w;
var _card_sy     = LAYOUT.card_h / _card_src_h;
var _card_left   = PH_W/2 - _card_src_w*0.5*_card_sx;   // == card_pad_x; tile's left edge in screen space

// ── Penpot tile layout (source space 1430×450) → screen ─────────────────────
// All metrics below are authored in the 1430×450 source-tile space (the values
// Bora gave from the Penpot "Puzzle Tile") and mapped to screen via _card_sx so
// the rendered card matches the design 1:1. Source x → screen: _card_left + x*_card_sx.
//   • Icon  — 320×320, left edge +50, vertically centred.
//   • Title/Description — left-aligned at icon-right (370) + 50 = 420.
//   • Pill  — right edge +50 from the tile's right side → x = 1430-50 = 1380.
var _icon_src    = 250;                                  // design 320, dialled down a touch (Bora: icons can be smaller)
var _icon_draw   = _icon_src * _card_sx;                 // square, ≈176px
var _icon_s      = _icon_draw / 512;                     // icon sprites are 512px native
var _icon_cx     = _card_left + (50 + _icon_src*0.5) * _card_sx;
var _text_x      = _card_left + (50 + _icon_src + 50) * _card_sx; // icon-right + 50
var _pill_right  = _card_left + 1380 * _card_sx;         // pill right edge
var _pill_w      = 350 * _card_sx;                       // uniform pill width (design = 350)
var _pill_left   = _pill_right - _pill_w;
var _pill_hh     = 50  * _card_sx;                       // half-height (design pill h = 100)
// Icon clip well — guards against any icon art spilling onto the coloured card.
var _icon_clip_x = _icon_cx - _icon_draw*0.5 - 6;
var _icon_clip_w = _icon_draw + 12;

for (var _i = 0; _i < array_length(cards); _i++) {
    var _card = cards[_i];
    var _cy1  = _body_top + _i*(LAYOUT.card_h + LAYOUT.card_gap) - scroll_y;
    var _ccy  = _cy1 + LAYOUT.card_h/2;

    // Tile press feedback — sink while held; spring-pop (overshoot) on release. The
    // whole card composite is built off _cy1/_ccy, so offsetting both shifts it all.
    var _press = 0;
    if      (_i == card_press_idx) _press = CARD_PRESS_DY * ph_ease_out(card_press_t);
    else if (_i == card_pop_idx)   _press = CARD_PRESS_DY * (1 - ph_ease_out_back(card_pop_t, 2.2));
    _cy1 += _press; _ccy += _press;

    if (_cy1 + LAYOUT.card_h < _body_top - 20 || _cy1 > _body_bot + 20) continue;

    // Anygram uses the consolidated DONE flag (with legacy M1/M2 fallback inside
    // the helper); other games use the simple per-name check.
    var _is_solved;
    if (_card.name == "ANYGRAM") {
        _is_solved = ph_anygram_is_done(_save, _sel);
    } else if (_card.name == "WORD WAVE") {
        _is_solved = ph_wordwave_is_done(_save, _sel);
    } else if (_card.name == "WORD BEND") {
        _is_solved = ph_wordbend_is_done(_save, _sel);
    } else if (_card.name == "HUE SORT") {
        _is_solved = ph_huesort_is_done(_save, _sel);
    } else if (_card.name == "COLOR LINK") {
        _is_solved = ph_colorlink_is_done(_save, _sel);
    } else if (_card.name == "ARROWS") {
        _is_solved = ph_arrows_is_done(_save, _sel);
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
    var _icon_clip_h   = _icon_draw + 12;
    var _icon_clip_top = max(_body_top, _ccy - _icon_clip_h/2);
    var _icon_clip_bot = min(_body_bot, _ccy + _icon_clip_h/2);
    if (_icon_clip_bot > _icon_clip_top) {
        ph_scissor_gui(_icon_clip_x, _icon_clip_top, _icon_clip_w, _icon_clip_bot - _icon_clip_top);
        draw_sprite_ext(_card.icon_spr, 0, _icon_cx, _ccy, _icon_s, _icon_s, 0, c_white, 1);
    }
    ph_scissor_gui(0, _body_top, PH_W, _body_bot - _body_top);

    // ── Title + subtitle ────────────────────────────────────
    // Left-aligned at icon-right + 50 (_text_x). Both lines black @ 60% to match
    // the Penpot fills. Title fnt_disp_lg (60), description fnt_body_md (36) —
    // dialled down from the raw design sizes (Bora: text can be smaller), pair
    // centred on _ccy. Clipped on the right so a long title/description can't
    // slide under the white pill (matches the design's truncating text box).
    var _text_clip_r = _pill_left - 16;
    ph_scissor_gui(_text_x, _body_top, max(1, _text_clip_r - _text_x), _body_bot - _body_top);
    // Drawn at 0.9 scale via draw_text_transformed so the effective sizes are ~10%
    // below the font's native px (Bora: text can be even ~10% smaller). Title
    // fnt_disp_lg (60→~54), description fnt_body_md (36→~32), both black @ 60%.
    var _txt_sc = 0.9;
    draw_set_alpha(0.6); draw_set_halign(fa_left); draw_set_valign(fa_middle); draw_set_color(c_black);
    draw_set_font(global.fnt_disp_lg);
    draw_text_transformed(_text_x, _ccy - LAYOUT.card_h*0.12, _card.name,     _txt_sc, _txt_sc, 0);
    draw_set_font(global.fnt_body_md);
    draw_text_transformed(_text_x, _ccy + LAYOUT.card_h*0.11, _card.subtitle, _txt_sc, _txt_sc, 0);
    draw_set_alpha(1);
    ph_scissor_gui(0, _body_top, PH_W, _body_bot - _body_top);

    // ── Right pill (Penpot "Pill") ──────────────────────────
    // Solid #ffffff pill, dark (#000000-ish) text/icons, right edge +50 from the
    // tile's right side and one uniform width (design = 350×100), regardless of
    // variant. All variants share the same white capsule; only the contents
    // change. Replaces the old per-variant translucent / dark-chip pills.
    var _btn_cy   = _ccy;
    var _ink      = PH_COL_DARK;
    // Stopwatch / trophy sit ON the pill's left edge and overhang outward onto the
    // card — same "3D badge on a pill" look as the coin + level pills up top. Big
    // (≈2.9× the pill half-height) and centred just inside the left cap so ~half
    // spills off the left. The value text is then centred in the space to the right.
    var _ic_s     = (_pill_hh * 2.9) / 512;
    var _ic_x     = _pill_left + _pill_hh * 0.10;
    var _txt_cx   = _pill_left + _pill_w * 0.62;      // centre of the value text (right of the icon)
    var _pill_cx  = (_pill_left + _pill_right) * 0.5; // centre for single-label pills

    var _btype = variable_struct_exists(_card, "btn_type") ? _card.btn_type : "play";

    // White capsule (shared by every variant).
    ph_draw_pill(_pill_left, _btn_cy-_pill_hh, _pill_right, _btn_cy+_pill_hh, PH_COL_WHITE, 1);

    if (_card.name == "WORDLE" && ph_wordle_is_missed(_save, _sel)) {
        // MISSED — out of guesses / gave up. Finish time shown in RED (Penpot
        // Pill "Missed" variant), distinct from a solved day's dark time.
        var _mt_key = "wordle_time_" + _sel;
        var _mt     = variable_struct_exists(_save, _mt_key) ? _save[$ _mt_key] : "--:--";
        // Stopwatch is a full-colour 3D sprite — draw c_white (no tint) so it keeps its art.
        ph_draw_text(_txt_cx, _btn_cy, _mt, global.fnt_body_md, make_color_rgb(165,36,36), fa_center, fa_middle);
        draw_sprite_ext(global.spr_stopwatch, 0, _ic_x, _btn_cy, _ic_s, _ic_s, 0, c_white, 1);
    } else if (_is_solved) {
        // Finish-time pill — CENTRALIZED for every solved puzzle (no per-name list).
        // The save key prefix is derived from the card's room: every puzzle stores
        // its time under "<key>_time_<date>" where the room is "rm_<key>", so a new
        // puzzle shows its finish time automatically. Wordle's MISSED case is the
        // only exception (handled above, time shown in red). Dark stopwatch + mm:ss.
        var _pkey     = (string_copy(_card.room, 1, 3) == "rm_")
                        ? string_delete(_card.room, 1, 3) : string_lower(_card.name);
        var _time_key = _pkey + "_time_" + _sel;
        var _ag_time  = variable_struct_exists(_save, _time_key)
                        ? _save[$ _time_key] : "--:--";
        // Time first, then the stopwatch on top so the icon's overhang reads cleanly.
        ph_draw_text(_txt_cx, _btn_cy, _ag_time, global.fnt_body_md, _ink, fa_center, fa_middle);
        // Stopwatch is a full-colour 3D sprite — draw c_white (no tint) so it keeps its art.
        draw_sprite_ext(global.spr_stopwatch, 0, _ic_x, _btn_cy, _ic_s, _ic_s, 0, c_white, 1);
    } else if (_btype == "time_trophy") {
        // Best-time badge — full-colour 3D trophy (drawn c_white to keep its art) + dark time.
        ph_draw_text(_txt_cx, _btn_cy, _card.best_time, global.fnt_body_md, _ink, fa_center, fa_middle);
        draw_sprite_ext(global.spr_trophy3d, 0, _ic_x, _btn_cy, _ic_s, _ic_s, 0, c_white, 1);
    } else if (_btype == "locked") {
        // COMING SOON — text only, centred (matches the Penpot locked pill).
        ph_draw_text(_pill_cx, _btn_cy, "COMING SOON", global.fnt_body_sm, _ink, fa_center, fa_middle);
    } else {
        // Every play variant (play / play_translucent / play_light) → centred dark PLAY.
        ph_draw_text(_pill_cx, _btn_cy, "PLAY", global.fnt_body_lg, _ink, fa_center, fa_middle);
    }
}

ph_scissor_reset();

// ═══════════════════════════════════════════════════════════
// 7. BOTTOM NAV  (order: Shop | Games | Profile — Games is middle)
// ═══════════════════════════════════════════════════════════
ph_draw_nav(1);

// ── DEBUG: safe-area source readout (PH_DEBUG_SAFEAREA) ────────────────────────
// Shows which path set the insets ("extension" = real per-device values from the
// iOS Safe Area extension, "estimate" = aspect-ratio fallback) plus the values.
// Also draws hairlines at the top/bottom safe boundaries. Turn off before ship.
if (PH_DEBUG_SAFEAREA) {
    var _src = variable_global_exists("safe_src") ? global.safe_src : "?";
    var _dbg = "safe: " + _src
             + "  top=" + string(global.safe_top_gui) + " bot=" + string(global.safe_bottom_gui)
             + "  rawpx " + string(global.safe_raw_top) + "/" + string(global.safe_raw_bottom);
    var _dy  = LAYOUT.chiprow_y + LAYOUT.chiprow_h + 6;
    draw_set_alpha(0.85);
    ph_draw_rounded(20, _dy, PH_W-20, _dy+44, 8, make_color_rgb(20,20,20));
    draw_set_alpha(1);
    ph_draw_text(PH_W/2, _dy+22, _dbg, global.fnt_body_xs, PH_COL_YELLOW, fa_center, fa_middle);
    // boundary hairlines: green = top inset, cyan = bottom inset
    draw_set_color(PH_COL_GREEN); draw_line_width(0, global.safe_top_gui, PH_W, global.safe_top_gui, 2);
    draw_set_color(PH_COL_TEAL);  draw_line_width(0, PH_H-global.safe_bottom_gui, PH_W, PH_H-global.safe_bottom_gui, 2);
    draw_set_color(c_white);
}

// ═══════════════════════════════════════════════════════════
// 8. COIN-FLOW REWARD ANIMATION  (after a Level-Up coin claim)
// ═══════════════════════════════════════════════════════════
// Drawn last so the coins and label sit above every other hub element. State is
// set up in Create_0 and advanced in Step_0 (see those for the model).
if (coinflow_active || coinflow_label_t >= 0) {
    // Coin-pill target — must match the coin sprite drawn in §2.
    var _cf_tcx = PH_W - 322;
    var _cf_tcy = LAYOUT.chiprow_y + LAYOUT.chiprow_h/2;

    // Flying coins along an eased quadratic arc into the pill.
    var _cf_base_s = 78 / 512;
    for (var _i = 0; _i < array_length(coinflow_coins); _i++) {
        var _c = coinflow_coins[_i];
        if (coinflow_t < _c.delay) continue;   // not launched yet
        if (_c.t >= 1) continue;               // already delivered
        var _e  = ph_ease_out(_c.t);
        var _om = 1 - _e;
        var _x  = _om*_om*_c.sx0 + 2*_om*_e*_c.cx + _e*_e*_c.tx;
        var _y  = _om*_om*_c.sy0 + 2*_om*_e*_c.cy + _e*_e*_c.ty;
        var _a  = (_c.t < 0.12) ? _c.t/0.12 : 1;          // quick fade-in
        var _sc = _cf_base_s * (1.0 - 0.30*_e);            // shrink toward the pill
        draw_sprite_ext(global.spr_gold_coin, 0, _x, _y, _sc, _sc, 0, c_white, _a);
    }

    // Pill coin "pop" pulse each time a coin lands.
    if (coinflow_pop > 0) {
        var _pop_s = (110/512) * (1 + 0.28*coinflow_pop);
        draw_sprite_ext(global.spr_gold_coin, 0, _cf_tcx, _cf_tcy, _pop_s, _pop_s, 0, c_white, 1);
    }

    // "+N" label rising and fading just under the coin pill.
    if (coinflow_label_t >= 0) {
        var _lt     = coinflow_label_t;
        var _rise   = 24 * ph_ease_out(min(1, _lt*1.6));
        var _lalpha = (_lt < 0.65) ? 1 : max(0, 1 - (_lt-0.65)/0.35);
        var _ly     = _cf_tcy + 54 + _rise;
        draw_set_alpha(_lalpha);
        ph_draw_text_shadow(_cf_tcx + 40, _ly, "+" + string(coinflow_amount),
                            global.fnt_num_md, PH_COL_YELLOW, PH_COL_YELLOW_DEEP,
                            fa_center, fa_middle, 0, 3);
        draw_set_alpha(1);
    }
}

// ── Daily Spin modal (drawn on top of everything) ─────────────────────────────
ph_spin_draw(spin);

// ── First-run soft finger hint (drawn last; no overlay, just the pointer) ─────
ph_finger_draw(finger);
