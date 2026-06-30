// ── Drawing helpers ───────────────────────────────────────────────────────────

/// HTML5 ONLY: resize the canvas to an aspect-fit of the browser viewport.
/// This build's HTML5 scaling behaves as "No Scaling" (the game manually owns the
/// application surface at PH_W×PH_H_dyn, which suppresses GameMaker's auto-fit), so
/// the canvas renders at native size and overflows a smaller window — AND mouse
/// input stays mapped 1:1 to that native size, so taps in the lower band miss
/// entirely (the Daily Spin wheel was unclickable). window_set_size shrinks the
/// canvas to fit while keeping aspect; GameMaker then scales the 1080×1920
/// application surface down to it and — critically — maps device-mouse input
/// through that same scale, so taps line up again. No-op on native targets.
function ph_html5_fit_canvas() {
    if (os_browser == browser_not_a_browser) return;
    var _bw = browser_width;
    var _bh = browser_height;
    if (_bw <= 0 || _bh <= 0) return;
    var _scale = min(_bw / PH_W, _bh / global.PH_H_dyn);
    if (_scale <= 0) _scale = 1;
    window_set_size(round(PH_W * _scale), round(global.PH_H_dyn * _scale));
}

/// Format an integer with thousand separators ("1000" → "1,000"). Used so
/// large coin balances stay readable inside the small pill on the hub HUD.
function ph_format_int_thousands(_n) {
    var _neg = (_n < 0);
    var _s   = string(_neg ? -_n : _n);
    var _len = string_length(_s);
    if (_len <= 3) return (_neg ? "-" : "") + _s;
    var _out = "";
    for (var _i = 0; _i < _len; _i++) {
        if (_i > 0 && (_len - _i) mod 3 == 0) _out += ",";
        _out += string_char_at(_s, _i + 1);
    }
    return (_neg ? "-" : "") + _out;
}

/// Filled rounded rectangle
function ph_draw_rounded(_x1,_y1,_x2,_y2,_r,_col) {
    draw_set_color(_col);
    draw_rectangle(_x1+_r, _y1,    _x2-_r, _y2,    false);
    draw_rectangle(_x1,    _y1+_r, _x2,    _y2-_r, false);
    draw_circle(_x1+_r, _y1+_r, _r, false);
    draw_circle(_x2-_r, _y1+_r, _r, false);
    draw_circle(_x1+_r, _y2-_r, _r, false);
    draw_circle(_x2-_r, _y2-_r, _r, false);
}

/// Pill-shaped background sprite (Pill.png), drawn as a horizontal 3-slice so
/// the rounded end-caps keep their shape at any width. The caps are scaled to
/// half the target height (a true capsule) and the flat middle is stretched
/// horizontally only. The sprite is white with a baked soft drop shadow, so
/// _col tints it to any colour and _alpha controls translucency.
function ph_draw_pill(_x1,_y1,_x2,_y2,_col,_alpha) {
    if (_alpha == undefined) _alpha = 1;
    var _s  = global.spr_pill;
    var _sw = sprite_get_width(_s);
    var _sh = sprite_get_height(_s);
    var _h  = _y2 - _y1;
    var _w  = _x2 - _x1;
    var _cap_src = _sh * 0.5;                 // semicircle cap region in the source
    var _cap_dst = min(_h * 0.5, _w * 0.5);   // keep caps a true semicircle (clamp for narrow pills)
    var _sx_cap  = _cap_dst / _cap_src;
    var _sy      = _h / _sh;
    // Left cap
    draw_sprite_part_ext(_s, 0, 0, 0, _cap_src, _sh, _x1, _y1, _sx_cap, _sy, _col, _alpha);
    // Right cap
    draw_sprite_part_ext(_s, 0, _sw - _cap_src, 0, _cap_src, _sh, _x2 - _cap_dst, _y1, _sx_cap, _sy, _col, _alpha);
    // Stretched flat middle (uniform white in the source → no visible seam)
    var _mid_dst_w = _w - 2 * _cap_dst;
    if (_mid_dst_w > 0) {
        var _mid_src_w = _sw - 2 * _cap_src;
        draw_sprite_part_ext(_s, 0, _cap_src, 0, _mid_src_w, _sh,
                             _x1 + _cap_dst, _y1, _mid_dst_w / _mid_src_w, _sy, _col, _alpha);
    }
}

/// Chunky 3-D chip button.
/// Capsule-proportioned chips (corner radius ≈ half the height — i.e. fully
/// rounded ends) are drawn with the shared Pill.png sprite so every pill in the
/// app shares one look. Lower-radius rounded rectangles (panels, boards, cards)
/// keep the original primitive-based shadow+fill drawing.
function ph_draw_chip(_x1,_y1,_x2,_y2,_r,_fill,_shadow,_drop) {
    if (variable_global_exists("spr_pill") && (_r * 2 >= (_y2 - _y1) - 4)) {
        ph_draw_pill(_x1, _y1, _x2, _y2, _fill, 1);
        return;
    }
    ph_draw_rounded(_x1, _y1+_drop, _x2, _y2+_drop, _r, _shadow);
    ph_draw_rounded(_x1, _y1,       _x2, _y2,       _r, _fill);
}

/// Draw text with alignment
function ph_draw_text(_x,_y,_str,_fnt,_col,_halign,_valign) {
    draw_set_font(_fnt);
    draw_set_color(_col);
    draw_set_halign(_halign);
    draw_set_valign(_valign);
    draw_text(_x, _y, _str);
}

/// Draw text with drop shadow
function ph_draw_text_shadow(_x,_y,_str,_fnt,_col,_shadow_col,_halign,_valign,_ox,_oy) {
    ph_draw_text(_x+_ox, _y+_oy, _str, _fnt, _shadow_col, _halign, _valign);
    ph_draw_text(_x,     _y,     _str, _fnt, _col,        _halign, _valign);
}

/// One-line "game tip" objective hint, centred horizontally above a puzzle grid.
/// Matches the Penpot design: Nunito-regular (fnt_body_reg) in faint ink (black @
/// 60%), sitting in the empty band between the top HUD and the grid. Pass the
/// grid's top y (grid_y) and the tip string (see ph_game_tip in scr_constants).
function ph_draw_game_tip(_grid_top, _str) {
    if (_str == "") return;
    // Auto-wraps to a 2nd line if the tip is wider than the play area, and is
    // bottom-anchored just above the grid so it never grows down into the board.
    draw_set_font(global.fnt_tip);
    draw_set_color(c_black);
    draw_set_halign(fa_center);
    draw_set_valign(fa_bottom);
    draw_set_alpha(0.6);
    draw_text_ext(PH_W/2, _grid_top - 26, _str, 50, PH_W - 140);
    draw_set_alpha(1);
}

/// Shared "Message Prompt" toast — ONE canonical style across every puzzle:
/// capsule chip, ALL-CAPS label in a single consistent font/size/weight
/// (`fnt_body_md`), white text; only the capsule COLOUR varies by semantic state.
/// Auto-fits width to the text. Positioned just ABOVE the game tip (pass the same
/// anchor you give ph_draw_game_tip — the grid/list top). `_alpha` fades it. Pass
/// an explicit `_cy` to override the vertical position (e.g. Wordle draws the
/// prompt over its tip line where vertical room is tight).
function ph_draw_toast(_text, _col, _alpha, _grid_top, _cy = undefined) {
    if (_text == "" || _alpha <= 0) return;
    var _txt = string_upper(string(_text));
    var _y   = is_undefined(_cy) ? (_grid_top - 175) : _cy;
    draw_set_font(global.fnt_body_md);
    var _hw = max(330, string_width(_txt)/2 + 56);
    draw_set_alpha(_alpha);
    ph_draw_chip(PH_W/2 - _hw, _y - 36, PH_W/2 + _hw, _y + 36, 36, _col, make_color_rgb(20,20,20), 5);
    ph_draw_text(PH_W/2, _y, _txt, global.fnt_body_md, PH_COL_WHITE, fa_center, fa_middle);
    draw_set_alpha(1);
}

/// Draws `highlight.png` (a white capsule, 1305×100 with 50-px round end caps) as
/// a clean marker from point A to point B with thickness `_thick`, tinted `_col`,
/// at `_alpha`. Rendered as a rotated 3-slice (round caps + stretched middle) via
/// draw_sprite_general, so — unlike stacked circle+line primitives — there is no
/// self-overlap / alpha doubling at the tips. `_a`/`_b` are the cell CENTRES.
function ph_draw_highlight(_ax, _ay, _bx, _by, _thick, _col, _alpha) {
    var _ang  = point_direction(_ax, _ay, _bx, _by);
    var _len  = point_distance(_ax, _ay, _bx, _by);
    var _ys   = _thick / 100;            // sprite height 100 → thickness
    var _half = _thick / 2;              // = on-screen cap radius (round caps)
    var _ux   = lengthdir_x(1, _ang), _uy = lengthdir_y(1, _ang);
    // Anchor for a slice whose center-left sits at axis point C: shift C "up" in
    // the rotated local frame (local +y maps to direction _ang-90).
    var _anchor = function(_cx, _cy2, _ang2, _half2) {
        return { x: _cx - lengthdir_x(_half2, _ang2 - 90),
                 y: _cy2 - lengthdir_y(_half2, _ang2 - 90) };
    };
    var _spr = global.spr_highlight;
    // Left cap (source x[0..50]) — center-left at the tip (A shifted back by _half).
    var _c1 = _anchor(_ax - _ux*_half, _ay - _uy*_half, _ang, _half);
    draw_sprite_general(_spr, 0, 0, 0, 50, 100, _c1.x, _c1.y, _ys, _ys, _ang, _col,_col,_col,_col, _alpha);
    // Middle (source x[50..1255], width 1205) — stretched from A to B.
    var _c2 = _anchor(_ax, _ay, _ang, _half);
    draw_sprite_general(_spr, 0, 50, 0, 1205, 100, _c2.x, _c2.y, _len/1205, _ys, _ang, _col,_col,_col,_col, _alpha);
    // Right cap (source x[1255..1305]) — center-left at B.
    var _c3 = _anchor(_bx, _by, _ang, _half);
    draw_sprite_general(_spr, 0, 1255, 0, 50, 100, _c3.x, _c3.y, _ys, _ys, _ang, _col,_col,_col,_col, _alpha);
}

/// Bonus pill — white capsule with the 3D chest spilling off the left cap and a
/// "BONUS" label, plus a small pink count badge on the chest when _count>0.
/// Mirrors the coin / HINT HUD pills (Penpot design, shared by every screen that
/// has bonus words). _l = left edge, _cy = vertical centre. Returns the pill's
/// {l,r,t,b} bounds and the chest centre {icon_x,icon_y} (fly-tile target).
function ph_draw_bonus_pill(_l, _cy, _count) {
    var _r = _l + 290;
    var _t = _cy - 33;
    var _b = _cy + 33;
    ph_draw_chip(_l, _t, _r, _b, 33, PH_COL_WHITE, make_color_rgb(190,170,155), 6);
    var _chest_s = 118 / 512;   // matches the coin icon's visible height
    draw_sprite_ext(global.spr_chest, 0, _l + 27, _cy, _chest_s, _chest_s, 0, c_white, 1);
    ph_draw_text(_l + 82, _cy, "BONUS", global.fnt_pill_num, PH_COL_DARK, fa_left, fa_middle);
    if (_count > 0) {
        draw_set_color(PH_COL_PINK);
        draw_circle(_l + 60, _cy - 30, 20, false);
        ph_draw_text(_l + 60, _cy - 30, string(_count), global.fnt_body_xs, PH_COL_WHITE, fa_center, fa_middle);
    }
    return { l:_l, r:_r, t:_t, b:_b, icon_x:_l + 27, icon_y:_cy };
}

/// "Words to find" tile (Word Wave). Centred on (_cx,_cy), _w×_h, corner _r.
/// Found → solid fill in the word's own grid-highlight colour (_found_col), white
/// text + white strike-through; to-find → tan fill with faint-ink text. Pass
/// _found_col so the list chip matches that word's colour in the grid; omit it to
/// fall back to the shared pink. See PH_COL_WORD_* in scr_constants.
function ph_draw_word_tile(_cx, _cy, _w, _h, _r, _text, _found, _found_col = PH_COL_WORD_FOUND) {
    var _l = _cx - _w/2, _rt = _cx + _w/2, _t = _cy - _h/2, _b = _cy + _h/2;
    if (_found) {
        var _deep = merge_color(_found_col, c_black, 0.28);
        ph_draw_chip(_l, _t, _rt, _b, _r, _found_col, _deep, 6);
        ph_draw_text(_cx, _cy, _text, global.fnt_tip, PH_COL_WHITE, fa_center, fa_middle);
        var _tw = string_width(_text);   // font is fnt_tip (set by ph_draw_text above)
        draw_set_color(PH_COL_WHITE);
        draw_line_width(_cx - _tw/2 - 8, _cy, _cx + _tw/2 + 8, _cy, 5);
    } else {
        ph_draw_chip(_l, _t, _rt, _b, _r, PH_COL_WORD_TODO, PH_COL_WORD_TODO_DEEP, 6);
        draw_set_alpha(0.6);
        ph_draw_text(_cx, _cy, _text, global.fnt_tip, c_black, fa_center, fa_middle);
        draw_set_alpha(1);
    }
}

/// Draw a sprite icon tinted to a colour (sprites are white-on-transparent)
function ph_draw_icon(_spr, _x, _y, _scale, _col) {
    draw_sprite_ext(_spr, 0, _x, _y, _scale, _scale, 0, _col, 1);
}

/// Fragmented progress bar matching the Penpot "Daily Progress Bar" design:
/// a white rounded background pill with _total coloured chunks on top, separated
/// by thin white slits. The first _filled chunks are purple (#9d5ff8), the rest
/// grey (#d9d9d9). The two end chunks are rounded to fill the pill caps; interior
/// chunks are square so the slits read as a clean division. Vertically centred on
/// _cy at height _h across [_x1.._x2].
function ph_draw_progress_segments(_x1, _x2, _cy, _h, _total, _filled, _alpha) {
    if (_alpha == undefined) _alpha = 1;
    if (_total <= 0) return;
    draw_set_alpha(_alpha);

    // White rounded background pill (the slits between chunks show this through).
    var _r = _h * 0.5;
    ph_draw_rounded(_x1, _cy - _h/2, _x2, _cy + _h/2, _r, PH_COL_WHITE);

    // Chunk band, inset inside the pill. Thicker vertical inset = clearly visible
    // white lines above/below the coloured chunks (Bora: the old ~5% was too thin).
    var _inset  = max(8, _h * 0.14);
    var _sy1    = _cy - _h/2 + _inset;
    var _sy2    = _cy + _h/2 - _inset;
    var _seg_h  = _sy2 - _sy1;
    var _seg_r  = _seg_h * 0.45;             // every step rounded ("rounded steps")
    var _band_l = _x1 + _inset;
    var _band_r = _x2 - _inset;
    var _cell_w = (_band_r - _band_l) / _total;
    var _gap    = max(4, _cell_w * 0.10);   // thin white slit between chunks

    var _col_fill  = make_color_rgb(157, 95, 248);   // #9d5ff8 purple
    var _col_empty = make_color_rgb(217, 217, 217);  // #d9d9d9 grey

    for (var _i = 0; _i < _total; _i++) {
        var _l   = _band_l + _i * _cell_w + _gap/2;
        var _rr  = _band_l + (_i + 1) * _cell_w - _gap/2;
        var _col = (_i < _filled) ? _col_fill : _col_empty;
        ph_draw_rounded(_l, _sy1, _rr, _sy2, min(_seg_r, (_rr-_l)*0.5), _col);
    }
    draw_set_alpha(1);
}

// ── Safe-area helpers ─────────────────────────────────────────────────────────
/// Top inset PLUS comfort padding (PH_PAD_TOP). Use as the first usable y for
/// full-screen content so nothing crowds the Dynamic Island / status bar.
function ph_safe_top()    { return global.safe_top_gui    + PH_PAD_TOP; }
/// Bottom inset PLUS comfort padding (PH_PAD_BOTTOM). Reserve this much above
/// PH_H so content clears the home indicator with breathing room.
function ph_safe_bottom() { return global.safe_bottom_gui + PH_PAD_BOTTOM; }

// ── Easing ────────────────────────────────────────────────────────────────────
function ph_ease_out(_t)  { return 1 - (1-_t)*(1-_t); }      // quad decel
function ph_ease_in(_t)   { return _t*_t; }                  // quad accel (from rest)
function ph_ease_in_cubic(_t)  { return _t*_t*_t; }              // strong accel
function ph_ease_out_cubic(_t) { return 1 - power(1-_t, 3); }     // snappier decel
function ph_ease_in_out(_t) {                                     // cubic accel → decel
    return (_t < 0.5) ? 4*_t*_t*_t : 1 - power(-2*_t+2, 3)/2;
}
function ph_ease_back(_t) {
    var _c1 = 1.70158; var _c3 = _c1+1;
    return 1 + _c3*power(_t-1,3) + _c1*power(_t-1,2);
}
/// Decelerating overshoot with a tunable strength (_ov; ~1.7 = subtle, ~2.5 = poppy).
function ph_ease_out_back(_t, _ov) {
    var _c1 = _ov; var _c3 = _c1+1;
    return 1 + _c3*power(_t-1,3) + _c1*power(_t-1,2);
}

/// ── Screen transition (iris cover → reveal) ──────────────────────────────────
/// State lives in globals; obj_persistent advances it (Step) and draws the overlay
/// (Draw GUI) so it spans BOTH the old and new room. Call this to kick it off from
/// a tap: the iris closes over the screen in `_col`, the room swaps under full
/// cover, then the iris opens to reveal the new room. _ox/_oy = origin (tap point).
function ph_trans_begin(_ox, _oy, _col, _room) {
    ph_sfx(snd_transition, 0.7);   // whoosh as the iris closes over the screen
    global.trans_active = true;
    global.trans_phase  = 1;     // 1 = cover (iris in), 2 = reveal (iris out)
    global.trans_t      = 0;
    global.trans_ox     = _ox;
    global.trans_oy     = _oy;
    global.trans_col    = _col;
    global.trans_room   = _room;
}
/// Radius that fully covers the screen from an origin (farthest corner + margin).
function ph_trans_radius_max(_ox, _oy) {
    return max(point_distance(_ox,_oy,0,0),   point_distance(_ox,_oy,PH_W,0),
               point_distance(_ox,_oy,0,PH_H), point_distance(_ox,_oy,PH_W,PH_H)) + 6;
}

/// Set a scissor rectangle in GUI coordinate space.
/// gpu_set_scissor takes WINDOW pixel coords, not GUI coords — this helper converts.
function ph_scissor_gui(_gx, _gy, _gw, _gh) {
    var _ww = window_get_width();
    var _wh = window_get_height();
    gpu_set_scissor(
        floor(_gx * _ww / PH_W),
        floor(_gy * _wh / PH_H),
        ceil( _gw * _ww / PH_W),
        ceil( _gh * _wh / PH_H)
    );
}

/// Remove the scissor (restore full-window drawing)
function ph_scissor_reset() {
    gpu_set_scissor(0, 0, window_get_width(), window_get_height());
}

// ── Hit tests ─────────────────────────────────────────────────────────────────
function ph_point_in_rect(_px,_py,_x1,_y1,_x2,_y2) {
    return (_px>=_x1 && _px<=_x2 && _py>=_y1 && _py<=_y2);
}
function ph_point_in_circle(_px,_py,_cx,_cy,_r) {
    return (point_distance(_px,_py,_cx,_cy) <= _r);
}

// ── Shared bottom nav bar ─────────────────────────────────────────────────────
/// Draw the bottom nav bar. active_tab: 0=Shop  1=Games  2=Profile
/// Uses full-colour 3D icons — active tab gets a pink label and an enlarged
/// icon. Tap regions for each tab are equal thirds of PH_W; the corresponding
/// room navigation is wired in obj_hub / obj_shop / obj_profile Step_0.
function ph_draw_nav(_active_tab) {
    var _nav_h   = 190 + global.safe_bottom_gui;
    var _nav_top = PH_H - _nav_h;

    // White background + subtle top border
    ph_draw_rounded(0, _nav_top, PH_W, PH_H, 0, PH_COL_WHITE);
    draw_set_color(PH_COL_INK_FAINT);
    draw_line_width(0, _nav_top, PH_W, _nav_top, 2);

    // Usable area above the home indicator (safe_bottom_gui pixels at bottom
    // are reserved for the home pill — content must stay above that zone).
    var _usable_h = 190;   // fixed design height, excludes home-indicator padding
    var _tcy_base = _nav_top + _usable_h / 2 - 14;

    // 3D icon sprites (full colour — drawn with c_white to preserve colours)
    var _labels  = ["Shop", "Home", "Events"];
    var _sprites = [global.spr_shop3d, global.spr_home, global.spr_events];
    var _icon_s  = 110 / 512;   // ~110px icon size (bigger than the old 80px)
    var _icon_active_s = 150 / 512;  // selected tab pops bigger
    var _third   = PH_W / 3;

    for (var _ti = 0; _ti < 3; _ti++) {
        var _tcx    = _third*_ti + _third/2;
        var _tcy    = _tcy_base;
        var _active = (_ti == _active_tab);
        var _lbl_col = _active ? PH_COL_PINK : PH_COL_GRAY;

        // Selected tab icon scales up for emphasis
        var _ts = _active ? _icon_active_s : _icon_s;
        draw_sprite_ext(_sprites[_ti], 0, _tcx, _tcy, _ts, _ts, 0, c_white, 1);

        ph_draw_text(_tcx, _tcy + 64, _labels[_ti],
                     global.fnt_body_xs, _lbl_col, fa_center, fa_middle);

        // Missions pull-back badge on the Profile tab when a reward is claimable.
        if (_ti == 2 && variable_global_exists("save") && ph_week_has_claimable(global.save)) {
            var _bx = _tcx + 46, _by = _tcy - 42;
            draw_set_color(c_white);     draw_circle(_bx, _by, 20, false);
            draw_set_color(PH_COL_PINK); draw_circle(_bx, _by, 16, false);
            ph_draw_text(_bx, _by-1, string(ph_week_claimable_count(global.save)),
                         global.fnt_body_xs, c_white, fa_center, fa_middle);
        }

        // Pink underline pill — anchored to the bottom of the usable area
        // (not the bottom of the window, which includes the home-indicator zone).
        if (_active) {
            var _ind_w = 140;
            var _ind_y = _nav_top + _usable_h - 14;
            ph_draw_rounded(_tcx - _ind_w/2, _ind_y - 4,
                            _tcx + _ind_w/2, _ind_y + 4, 4, PH_COL_PINK);
        }
    }
}

// ── 8-point star burst ────────────────────────────────────────────────────────
/// Draw a filled n-point star burst centred at (_cx,_cy).
/// _r_out = outer radius, _r_in = inner radius, _n = point count.
function ph_draw_burst(_cx, _cy, _r_out, _r_in, _n, _col) {
    draw_set_color(_col);
    var _step = (2*pi) / _n;
    var _half = _step / 2;
    var _pts  = _n * 2;
    // Walk the star perimeter and fan-triangulate from the centre without allocating.
    var _ax = _cx + cos(-pi/2) * _r_out;
    var _ay = _cy + sin(-pi/2) * _r_out;
    for (var _i = 0; _i < _pts; _i++) {
        var _j      = _i + 1;
        var _is_out = ((_j mod 2) == 0);
        var _r      = _is_out ? _r_out : _r_in;
        var _idx    = _j div 2;
        var _ang    = _idx * _step - pi/2 + (_is_out ? 0 : _half);
        var _bx     = _cx + cos(_ang) * _r;
        var _by     = _cy + sin(_ang) * _r;
        draw_triangle(_cx, _cy, _ax, _ay, _bx, _by, false);
        _ax = _bx;
        _ay = _by;
    }
}

// ── Flat background fill ─────────────────────────────────────────────────────
/// Draw the background as a single solid PH_COL_BG fill. (The old tiled
/// BG Pattern.png / dot-grid was removed — the app now uses a flat colour.)
/// The _col argument is kept for backward compatibility with existing call
/// sites but is ignored; the fill is always PH_COL_BG.
function ph_draw_dot_bg(_col) {
    draw_clear(PH_COL_BG);
}

// ══════════════════════════════════════════════════════════════════════════════
// Reward / nav buttons (Penpot "Win Screen" blue 3D button design)
// ──────────────────────────────────────────────────────────────────────────────
// Shared by the win screen, the Level-Up screen, and the Wordle lose screen so the
// "claim" buttons look identical everywhere. Blue body (#1776d5-ish) with a darker
// 3D drop edge, a white centred label, an optional value icon (star / coin) to the
// right of the label, and an optional rewarded-video TV badge in the top-right
// corner (the DOUBLE variant). _cy is the vertical CENTRE; _bh is the half-height.

/// Image-button background (blue / green / pink / red bg sprites) drawn as a
/// horizontal 3-slice so the baked rounded corners + drop shadow keep their shape
/// at any width. (_x1,_y1)-(_x2,_y2) is the desired BODY rectangle (the coloured
/// area); the baked drop shadow extends a few px below it for the 3-D look.
/// All button-bg sprites share one source frame (loaded origin top-left, 230px
/// tall): a 20px transparent margin, a 149px-tall body, then a ~10px drop shadow.
function ph_draw_btn_bg(_spr, _x1, _y1, _x2, _y2) {
    var _sw  = sprite_get_width(_spr);
    var _sh  = sprite_get_height(_spr);
    var _pad     = 20;     // transparent margin (top / left / right) in source px
    var _body_h  = 149;    // coloured body height in source px
    var _cap_src = 95;     // source cap width — must fully cover the rounded corner
    var _h   = _y2 - _y1;
    var _sy  = _h / _body_h;          // uniform scale → round caps stay circular
    var _dy  = _y1 - _pad * _sy;      // sprite top so the body-top lands on _y1
    var _dl  = _x1 - _pad * _sy;      // sprite left edge (body-left maps to _x1)
    var _dr  = _x2 + _pad * _sy;      // sprite right edge (body-right maps to _x2)
    var _cap_dst = _cap_src * _sy;
    var _maxcap  = (_dr - _dl) / 2;
    if (_cap_dst > _maxcap) _cap_dst = _maxcap;   // clamp for very narrow buttons
    var _cap_xs  = _cap_dst / _cap_src;
    // Left cap
    draw_sprite_part_ext(_spr, 0, 0, 0, _cap_src, _sh, _dl, _dy, _cap_xs, _sy, c_white, 1);
    // Right cap
    draw_sprite_part_ext(_spr, 0, _sw - _cap_src, 0, _cap_src, _sh, _dr - _cap_dst, _dy, _cap_xs, _sy, c_white, 1);
    // Stretched flat middle
    var _mid_dst_w = (_dr - _dl) - 2 * _cap_dst;
    if (_mid_dst_w > 0) {
        var _mid_src_w = _sw - 2 * _cap_src;
        draw_sprite_part_ext(_spr, 0, _cap_src, 0, _mid_src_w, _sh,
                             _dl + _cap_dst, _dy, _mid_dst_w / _mid_src_w, _sy, c_white, 1);
    }
}

/// Map a button BODY colour to its image-background sprite (loaded in
/// obj_persistent). Returns noone when no art matches (caller falls back to the
/// primitive chip) — keeps every existing call site working unchanged while
/// routing the standard blue / green / share-pink / give-up-red buttons to art.
function ph_btn_sprite_for(_body) {
    if (!variable_global_exists("spr_btn_blue") || global.spr_btn_blue < 0) return noone;
    if (_body == PH_COL_GREEN)             return global.spr_btn_green;
    if (_body == PH_COL_PINK)              return global.spr_btn_pink;
    if (_body == make_color_rgb(235,90,90)) return global.spr_btn_red;   // GIVE UP
    if (_body == PH_COL_BLUE)              return global.spr_btn_blue;
    return noone;                          // unknown colour → primitive chip
}

/// Reward button: label + value icon (+ optional TV badge). _icon_spr may be
/// noone for a label-only button. _body/_edge override the colour (default blue);
/// pass PH_COL_GREEN / PH_COL_GREEN_DEEP for the green hint / lost-aversion buttons.
function ph_draw_reward_btn(_l, _cy, _r, _bh, _label, _icon_spr, _tv, _body, _edge) {
    if (is_undefined(_body)) _body = PH_COL_BLUE;
    if (is_undefined(_edge)) _edge = PH_COL_BLUE_DEEP;
    var _spr = ph_btn_sprite_for(_body);
    if (_spr != noone) ph_draw_btn_bg(_spr, _l, _cy - _bh, _r, _cy + _bh);
    else ph_draw_chip(_l, _cy - _bh, _r, _cy + _bh, 30, _body, _edge, 8);
    var _has = (_icon_spr != noone && _icon_spr >= 0);
    var _cx  = (_l + _r) / 2;
    draw_set_font(global.fnt_btn);
    var _lw  = string_width(_label);
    var _isz = _bh * 1.55;                       // icon target px (source sprites are 512)
    var _gap = _has ? 18 : 0;
    var _iw  = _has ? _isz : 0;
    var _x0  = _cx - (_lw + _gap + _iw) / 2;      // left edge of the label+icon group
    ph_draw_text(_x0 + _lw/2, _cy, _label, global.fnt_btn, PH_COL_WHITE, fa_center, fa_middle);
    if (_has) draw_sprite_ext(_icon_spr, 0, _x0 + _lw + _gap + _iw/2, _cy, _isz/512, _isz/512, 0, c_white, 1);
    if (_tv)  draw_sprite_ext(global.spr_tv, 0, _r - _bh*0.40, _cy - _bh + _bh*0.10, (_bh*1.5)/512, (_bh*1.5)/512, 0, c_white, 1);
}

/// Navigation button: icon on the left, label centred next to it. _accent lets the
/// caller override the body colour (e.g. PH_COL_PINK for SHARE); pass noone for the
/// default blue. _icon_spr may be noone to draw a label-only button.
function ph_draw_nav_btn(_l, _cy, _r, _bh, _label, _icon_spr, _accent, _accent_deep) {
    var _body = (_accent == noone)      ? PH_COL_BLUE      : _accent;
    var _edge = (_accent_deep == noone) ? PH_COL_BLUE_DEEP : _accent_deep;
    var _spr = ph_btn_sprite_for(_body);
    if (_spr != noone) ph_draw_btn_bg(_spr, _l, _cy - _bh, _r, _cy + _bh);
    else ph_draw_chip(_l, _cy - _bh, _r, _cy + _bh, 30, _body, _edge, 8);
    var _has = (_icon_spr != noone && _icon_spr >= 0);
    draw_set_font(global.fnt_btn);
    var _lw  = string_width(_label);
    var _isz = _bh * 1.5;
    var _gap = _has ? 22 : 0;
    var _iw  = _has ? _isz : 0;
    var _cx  = (_l + _r) / 2;
    var _x0  = _cx - (_iw + _gap + _lw) / 2;
    if (_has) draw_sprite_ext(_icon_spr, 0, _x0 + _iw/2, _cy, _isz/512, _isz/512, 0, c_white, 1);
    ph_draw_text(_x0 + _iw + _gap + _lw/2, _cy, _label, global.fnt_btn, PH_COL_WHITE, fa_center, fa_middle);
}

/// Draw a speaker glyph in code (no sprite). Centred at (_cx,_cy); _s = scale px.
/// _on=true draws two sound-wave chevrons; _on=false draws a mute slash instead.
/// Used by the Events-screen sound toggle (obj_profile) so it needs no new asset.
function ph_draw_speaker_icon(_cx, _cy, _s, _on, _col) {
    draw_set_color(_col);
    // Driver box + horn (narrow at the box, widening to the right).
    draw_rectangle(_cx - 0.58*_s, _cy - 0.22*_s, _cx - 0.24*_s, _cy + 0.22*_s, false);
    draw_triangle(_cx - 0.24*_s, _cy - 0.02*_s,
                  _cx + 0.16*_s, _cy - 0.46*_s,
                  _cx + 0.16*_s, _cy + 0.46*_s, false);
    if (_on) {
        // Two ">" chevrons as sound waves.
        var _ks = [0.34, 0.56];
        for (var _i = 0; _i < 2; _i++) {
            var _k = _ks[_i];
            draw_line_width(_cx + _k*_s,        _cy - 0.30*_s, _cx + (_k+0.10)*_s, _cy, max(2, 0.07*_s));
            draw_line_width(_cx + (_k+0.10)*_s, _cy,           _cx + _k*_s,        _cy + 0.30*_s, max(2, 0.07*_s));
        }
    } else {
        // Mute slash across the glyph.
        draw_line_width(_cx - 0.52*_s, _cy - 0.50*_s, _cx + 0.62*_s, _cy + 0.50*_s, max(3, 0.09*_s));
    }
    draw_set_color(c_white);
}

/// Vibrate / haptics glyph (mirrors ph_draw_speaker_icon): a phone with motion
/// waves either side when on, or a mute slash when off. _s ≈ icon size.
function ph_draw_vibrate_icon(_cx, _cy, _s, _on, _col) {
    draw_set_color(_col);
    // Phone body — slim rounded rectangle, centred.
    var _pw = 0.22*_s, _phh = 0.50*_s, _r = 0.07*_s;
    draw_roundrect_ext(_cx - _pw, _cy - _phh, _cx + _pw, _cy + _phh, _r, _r, false);
    if (_on) {
        // Two short motion bars on each side, the outer pair longer (waves).
        var _ks = [0.40, 0.60];
        var _hs = [0.20, 0.32];
        for (var _i = 0; _i < 2; _i++) {
            var _k = _ks[_i]; var _h = _hs[_i]; var _w = max(2, 0.07*_s);
            draw_line_width(_cx - _k*_s, _cy - _h*_s, _cx - _k*_s, _cy + _h*_s, _w);
            draw_line_width(_cx + _k*_s, _cy - _h*_s, _cx + _k*_s, _cy + _h*_s, _w);
        }
    } else {
        // Mute slash across the glyph.
        draw_line_width(_cx - 0.52*_s, _cy - 0.50*_s, _cx + 0.52*_s, _cy + 0.50*_s, max(3, 0.09*_s));
    }
    draw_set_color(c_white);
}
