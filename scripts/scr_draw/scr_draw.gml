// ── Drawing helpers ───────────────────────────────────────────────────────────

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

/// Draw a sprite icon tinted to a colour (sprites are white-on-transparent)
function ph_draw_icon(_spr, _x, _y, _scale, _col) {
    draw_sprite_ext(_spr, 0, _x, _y, _scale, _scale, 0, _col, 1);
}

/// Segmented progress bar built from the progress_bar_* sprites.
/// Draws _total cells evenly across [_x1.._x2], vertically centred on _cy at
/// height _h. The first _filled cells are purple, the rest grey. The two end
/// cells use the rounded cap sprites; internal cells use the flat centre
/// sprites. There is no grey_left.png asset, so an unfilled left cap is produced
/// by mirroring the grey right cap (negative x-scale). Segment sprites are loaded
/// with origin x=0, y=45 so each cell anchors at its own left edge.
function ph_draw_progress_segments(_x1, _x2, _cy, _h, _total, _filled, _alpha) {
    if (_alpha == undefined) _alpha = 1;
    var _seg_src_w = 195;
    var _seg_src_h = 90;
    var _cell_w = (_x2 - _x1) / _total;
    var _sx     = _cell_w / _seg_src_w;
    var _sy     = _h / _seg_src_h;
    for (var _i = 0; _i < _total; _i++) {
        var _cx_left   = _x1 + _i * _cell_w;
        var _is_filled = (_i < _filled);
        if (_i == 0) {
            // Left cap. Purple cap when filled; otherwise mirror the grey right
            // cap into a left cap by anchoring at the cell's right edge and
            // drawing with a negative x-scale.
            if (_is_filled) {
                draw_sprite_ext(global.spr_pb_purple_left, 0, _cx_left, _cy, _sx, _sy, 0, c_white, _alpha);
            } else {
                draw_sprite_ext(global.spr_pb_grey_right, 0, _cx_left + _cell_w, _cy, -_sx, _sy, 0, c_white, _alpha);
            }
        } else if (_i == _total - 1) {
            // Right cap.
            var _spr_r = _is_filled ? global.spr_pb_purple_right : global.spr_pb_grey_right;
            draw_sprite_ext(_spr_r, 0, _cx_left, _cy, _sx, _sy, 0, c_white, _alpha);
        } else {
            // Flat interior cell.
            var _spr_c = _is_filled ? global.spr_pb_purple_center : global.spr_pb_grey_center;
            draw_sprite_ext(_spr_c, 0, _cx_left, _cy, _sx, _sy, 0, c_white, _alpha);
        }
    }
}

// ── Easing ────────────────────────────────────────────────────────────────────
function ph_ease_out(_t)  { return 1 - (1-_t)*(1-_t); }
function ph_ease_back(_t) {
    var _c1 = 1.70158; var _c3 = _c1+1;
    return 1 + _c3*power(_t-1,3) + _c1*power(_t-1,2);
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
    var _labels  = ["Shop", "Games", "Profile"];
    var _sprites = [global.spr_shop3d, global.spr_puzzle, global.spr_position];
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

// ── Cached tiled background pattern ──────────────────────────────────────────
/// Draw the background by tiling BG Pattern.png across the screen (replaces the
/// old dot grid). The tiled result is rendered once into a cached surface, so
/// each frame is a single blit. The _col argument is kept for backward
/// compatibility with existing call sites but is no longer used — the pattern
/// art defines its own colour.
function ph_draw_dot_bg(_col) {
    if (!variable_global_exists("ph_dot_surface") || !surface_exists(global.ph_dot_surface)) {
        global.ph_dot_surface = surface_create(PH_W, PH_H);
        surface_set_target(global.ph_dot_surface);
        draw_clear_alpha(c_black, 0);
        if (variable_global_exists("spr_bg_pattern")) {
            var _pw = sprite_get_width(global.spr_bg_pattern);
            var _ph = sprite_get_height(global.spr_bg_pattern);
            for (var _gx = 0; _gx < PH_W; _gx += _pw) {
                for (var _gy = 0; _gy < PH_H; _gy += _ph) {
                    draw_sprite(global.spr_bg_pattern, 0, _gx, _gy);
                }
            }
        }
        surface_reset_target();
    }
    draw_surface(global.ph_dot_surface, 0, 0);
}
