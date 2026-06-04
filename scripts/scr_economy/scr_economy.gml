function ph_level_from_xp(_xp) {
    return floor(_xp / PH_XP_PER_LEVEL) + 1;
}

function ph_xp_in_level(_xp) {
    return _xp mod PH_XP_PER_LEVEL;
}

/// Grant XP and (optionally) the per-level coin reward.
/// _auto_coins (default true): when false, the level-up coins are NOT added to
/// the wallet here — the caller is responsible for granting them (e.g. via the
/// Level-Up reward screen, which lets the player double them). The returned
/// coins_awarded still reports what a full auto-grant *would* have been.
/// returns { levels_gained, coins_awarded, new_level }
function ph_grant_xp(_save, _amount, _auto_coins = true) {
    var _old = ph_level_from_xp(_save.xp);
    _save.xp += _amount;
    var _new    = ph_level_from_xp(_save.xp);
    var _gained = _new - _old;
    var _coins  = _gained * PH_COINS_PER_LEVEL;
    if (_auto_coins) _save.coins += _coins;
    return { levels_gained:_gained, coins_awarded:_coins, new_level:_new };
}

/// True if a level-up reward is queued (set at puzzle completion, consumed by
/// the Level-Up screen). Used by the win screens to route to rm_win vs rm_hub.
function ph_levelup_pending() {
    return variable_global_exists("pending_levelup") && !is_undefined(global.pending_levelup);
}

function ph_grant_coins(_save, _amount) {
    _save.coins += _amount;
}

/// returns false if not enough coins
function ph_spend_coins(_save, _amount) {
    if (_save.coins < _amount) return false;
    _save.coins -= _amount;
    return true;
}

// ══════════════════════════════════════════════════════════════════════════════
// XP claim tracking
// ──────────────────────────────────────────────────────────────────────────────
// The Win Screen no longer grants XP automatically at puzzle completion — the
// player claims it (and may double it) on the win screen. This per-puzzle flag
// guards against a second grant when an already-completed puzzle is re-entered in
// review mode. Stored as a {key:true} map under save.xp_claimed; json_stringify
// persists nested structs, and ph_save_read tolerates the key being absent in
// older saves.
function ph_xp_claimed(_save, _key) {
    if (!variable_struct_exists(_save, "xp_claimed")) return false;
    return variable_struct_exists(_save.xp_claimed, _key) && _save.xp_claimed[$ _key];
}
function ph_mark_xp_claimed(_save, _key) {
    if (!variable_struct_exists(_save, "xp_claimed")) _save.xp_claimed = {};
    _save.xp_claimed[$ _key] = true;
}

// ══════════════════════════════════════════════════════════════════════════════
// Share
// ──────────────────────────────────────────────────────────────────────────────
/// Open the OS share sheet with the given URL where a native share extension is
/// wired up; otherwise fall back to copying the link to the clipboard and logging
/// it (a placeholder, mirroring the rewarded-video stub). A native iOS/Android
/// share extension can later assign global.ph_native_share = function(url){...}.
/// Returns "native" or "clipboard" so the caller can show the right confirmation.
function ph_share_url(_url) {
    if ((os_type == os_ios || os_type == os_android)
        && variable_global_exists("ph_native_share") && is_method(global.ph_native_share)) {
        global.ph_native_share(_url);
        return "native";
    }
    clipboard_set_text(_url);
    show_debug_message("[share] " + _url);
    return "clipboard";
}

/// Small node-share glyph (left node linked to two right nodes), drawn with
/// primitives so no sprite asset is required. Used on the win-screen SHARE pill.
function ph_draw_share_glyph(_cx, _cy, _s, _col) {
    draw_set_color(_col);
    var _r  = _s * 0.16;
    var _ax = _cx + _s*0.34, _ay = _cy - _s*0.40;   // top-right node
    var _bx = _cx + _s*0.34, _by = _cy + _s*0.40;   // bottom-right node
    var _lx = _cx - _s*0.38, _ly = _cy;             // left node
    draw_line_width(_lx, _ly, _ax, _ay, _s*0.07);
    draw_line_width(_lx, _ly, _bx, _by, _s*0.07);
    draw_circle(_ax, _ay, _r, false);
    draw_circle(_bx, _by, _r, false);
    draw_circle(_lx, _ly, _r, false);
}

// ══════════════════════════════════════════════════════════════════════════════
// Shared Win Screen controller
// ──────────────────────────────────────────────────────────────────────────────
// One source of truth for the per-puzzle completion screen, shared by all four
// puzzles. Implements the Penpot "Win Screen" design + flows:
//   choose ──(100 XP)─────────────────────────────────┐
//          └(DOUBLE)→ video →(X)→ after_video ─(200 XP)┤
//   → claiming (stars fly button→bar, number animates) → done (Share + Back in)
//
// Config struct fields:
//   puzzle_name : display string, e.g. "WORDWAVE"
//   title_col   : "WELL DONE!" + accent colour for this puzzle
//   bg_col      : full-screen backdrop colour
//   claim_key   : unique per-puzzle-per-day key for the XP-claimed flag
//   already     : true on review re-entry (puzzle solved before this session)
//   share_url   : URL shared by the SHARE button
//   time_str    : solve time "m:ss" (the puzzle refreshes this each frame)
//   draw_recap  : method(_cx,_top_y,_box_w,_box_h) — draws the puzzle's mini recap
function ph_win_create(_cfg) {
    var _claimed = _cfg.already || ph_xp_claimed(global.save, _cfg.claim_key);
    var _in_lvl  = ph_xp_in_level(global.save.xp);
    var _w = {
        cfg:           _cfg,
        state:         _claimed ? "done" : "choose",
        intro_t:       _claimed ? 1 : 0,
        xp_base:       PH_XP_PER_PUZZLE,
        xp_amount:     PH_XP_PER_PUZZLE,
        doubled:       false,
        granted:       _claimed,            // already-claimed → never grant again
        // XP bar animation (pre-claim snapshot; XP is granted on claim)
        xp_anim_from:  _in_lvl,
        xp_anim_to:    _in_lvl,
        xp_anim_t:     1,
        claim_t:       1,
        // flying stars
        stars:         [],
        // placeholder rewarded video (DOUBLE path)
        vid_open:      false,
        vid_timer:     0,
        VIDEO_X_DELAY: 300,
        // outro (Share + Back) slide-in
        outro_t:       _claimed ? 1 : 0,
        share_msg_t:   0,
        // confetti
        confetti:         [],
        confetti_pending: false,
        confetti_frames:  0,
        // button bounds + targets (written by draw at settled positions)
        XP_L:0, XP_R:0, XP_T:0, XP_B:0,
        DBL_L:0, DBL_R:0, DBL_T:0, DBL_B:0,
        SHARE_L:0, SHARE_R:0, SHARE_T:0, SHARE_B:0,
        BACK_L:0, BACK_R:0, BACK_T:0, BACK_B:0,
        claim_src_x: PH_W/2, claim_src_y: 0,
        bar_star_x:  150,     bar_star_y:  0,
    };
    return _w;
}

/// Fire the celebratory confetti burst (call when win_phase flips to 1).
function ph_win_celebrate(_w) {
    _w.confetti_pending = true;
    _w.confetti_frames  = 0;
}

/// Grant the claimed XP exactly once, route a level-up to the Level-Up screen,
/// and arm the bar fill animation. Coins are NOT granted here — level-up coins
/// stay on the Level-Up reward screen (rm_win).
function ph_win_grant(_w, _amount) {
    if (_w.granted) return;
    _w.granted = true;
    var _before = ph_xp_in_level(global.save.xp);
    var _res    = ph_grant_xp(global.save, _amount, false);
    ph_mark_xp_claimed(global.save, _w.cfg.claim_key);
    if (_res.levels_gained > 0) {
        global.pending_levelup = { level: _res.new_level, base_reward: PH_COINS_PER_LEVEL };
        _w.xp_anim_to = PH_XP_PER_LEVEL;           // fill to full; Level-Up screen continues
    } else {
        _w.xp_anim_to = ph_xp_in_level(global.save.xp);
    }
    _w.xp_anim_from = _before;
    _w.xp_anim_t    = 0;
    ph_save_write(global.save);
}

/// Begin the claim animation: grant XP, spawn the star flight, enter "claiming".
function ph_win_begin_claim(_w, _amount) {
    if (_w.state == "claiming" || _w.state == "done") return;
    ph_win_grant(_w, _amount);
    _w.state   = "claiming";
    _w.claim_t = 0;
    _w.stars   = [];
    for (var _i = 0; _i < 14; _i++) {
        array_push(_w.stars, {
            t:  -_i * 0.05,
            x:  _w.claim_src_x + random_range(-30, 30),
            y:  _w.claim_src_y + random_range(-20, 20),
            tx: _w.bar_star_x,
            ty: _w.bar_star_y,
            sz: 0.10 + random(0.06),
        });
    }
}

/// Per-frame update: intro fade, video timer, claim/star/bar animation, confetti.
function ph_win_step(_w) {
    if (_w.intro_t < 1) _w.intro_t = min(1, _w.intro_t + 0.05);
    if (_w.share_msg_t > 0) _w.share_msg_t--;
    if (_w.vid_open) _w.vid_timer++;

    if (_w.state == "claiming") {
        _w.claim_t = min(1, _w.claim_t + 1/45);
        for (var _i = 0; _i < array_length(_w.stars); _i++) {
            _w.stars[_i].t += 1/18;
        }
        _w.xp_anim_t = clamp((_w.claim_t - 0.30) / 0.70, 0, 1);
        if (_w.claim_t >= 1) { _w.state = "done"; }
    }
    if (_w.state == "done" && _w.outro_t < 1) _w.outro_t = min(1, _w.outro_t + 0.06);

    // ── Confetti (same model as the legacy win overlay) ───────────────────────
    if (_w.confetti_pending) {
        _w.confetti_pending = false;
        _w.confetti_frames  = 0;
        var _pal = [PH_COL_PINK, PH_COL_YELLOW, PH_COL_TEAL, PH_COL_PURPLE, PH_COL_WHITE, PH_COL_ORANGE];
        for (var _bi = 0; _bi < 60; _bi++) {
            var _ang = random(2*pi), _spd = 13 + random(15);
            array_push(_w.confetti, {
                x: PH_W/2 + cos(_ang)*4, y: 620 + sin(_ang)*4,
                vx: cos(_ang)*_spd, vy: sin(_ang)*_spd,
                rot: random(360), vrot: -8 + random(16),
                size: 14 + irandom(10),
                col: _pal[irandom(array_length(_pal)-1)], shape: irandom(2),
            });
        }
    }
    _w.confetti_frames++;
    for (var _pi = array_length(_w.confetti) - 1; _pi >= 0; _pi--) {
        var _p = _w.confetti[_pi];
        _p.vy += 0.35; _p.vx *= 0.985;
        _p.x += _p.vx; _p.y += _p.vy; _p.rot += _p.vrot;
        if (_p.y > PH_H + 60) array_delete(_w.confetti, _pi, 1);
        else _w.confetti[_pi] = _p;
    }
}

/// Handle taps. Navigates (rm_win/rm_hub) on Back, shares on Share.
function ph_win_input(_w) {
    var _mx = device_mouse_x_to_gui(0);
    var _my = device_mouse_y_to_gui(0);

    // Placeholder video overlay — its close X (after the delay) ends the DOUBLE path.
    if (_w.vid_open) {
        if (device_mouse_check_button_pressed(0, mb_left)
            && _w.vid_timer >= _w.VIDEO_X_DELAY
            && ph_point_in_circle(_mx, _my, PH_W - 90, 90 + global.safe_top_gui, 60)) {
            _w.vid_open   = false;
            _w.doubled    = true;
            _w.xp_amount  = _w.xp_base * 2;
            _w.state      = "after_video";
        }
        return;
    }

    if (!device_mouse_check_button_pressed(0, mb_left)) return;

    switch (_w.state) {
        case "choose":
            if (ph_point_in_rect(_mx,_my, _w.XP_L,_w.XP_T,_w.XP_R,_w.XP_B)) {
                ph_win_begin_claim(_w, _w.xp_base);
            } else if (ph_point_in_rect(_mx,_my, _w.DBL_L,_w.DBL_T,_w.DBL_R,_w.DBL_B)) {
                _w.vid_open = true; _w.vid_timer = 0;
            }
            break;
        case "after_video":
            if (ph_point_in_rect(_mx,_my, _w.XP_L,_w.XP_T,_w.XP_R,_w.XP_B)) {
                ph_win_begin_claim(_w, _w.xp_amount);
            }
            break;
        case "done":
            if (ph_point_in_rect(_mx,_my, _w.SHARE_L,_w.SHARE_T,_w.SHARE_R,_w.SHARE_B)) {
                ph_share_url(_w.cfg.share_url);
                _w.share_msg_t = 100;
            } else if (ph_point_in_rect(_mx,_my, _w.BACK_L,_w.BACK_T,_w.BACK_R,_w.BACK_B)) {
                room_goto(ph_levelup_pending() ? rm_win : rm_hub);
            }
            break;
    }
}

/// Draw the whole win screen for the current state.
function ph_win_draw(_w) {
    var _cfg   = _w.cfg;
    var _intro = ph_ease_out(_w.intro_t);
    var _st    = global.safe_top_gui;
    var _sb    = global.safe_bottom_gui;

    // Full-screen backdrop (fades in). Fixed mint per the Penpot Win Screen design.
    draw_set_alpha(_intro);
    draw_set_color(make_color_rgb(173, 255, 241));   // #ADFFF1
    draw_rectangle(0, 0, PH_W, PH_H, false);
    draw_set_alpha(1);

    // ── Responsive vertical flow ──────────────────────────────────────────────
    // The Penpot board assumes a tall (~2243 px) canvas; real devices/windows
    // vary, so the blocks are laid out as a flow that compresses on shorter
    // screens (recap height + inter-block gaps absorb the slack). Element sizes
    // still track the design where space allows.
    var _avail = PH_H - _st - _sb;
    var _H_TITLE = 150, _H_SOLVED = 165, _H_TIME = 100, _H_BAR = 120, _H_CLAIM = 90, _H_BTN = 150;
    var _GAP0 = 24, _NGAP = 6;
    var _fixed   = _H_TITLE + _H_SOLVED + _H_TIME + _H_BAR + _H_CLAIM + _H_BTN;
    var _recap_h = clamp(_avail - _fixed - _GAP0*_NGAP, 240, 640);
    var _recap_w = min(540, _recap_h);
    var _gap     = _GAP0 + max(0, _avail - _fixed - _recap_h - _GAP0*_NGAP) / _NGAP;

    var _cy = _st;
    var _title_cy  = _cy + _H_TITLE/2;   _cy += _H_TITLE  + _gap;
    var _recap_top = _cy;                _cy += _recap_h  + _gap;
    var _solved_top = _cy;               _cy += _H_SOLVED + _gap;
    var _time_cy   = _cy + _H_TIME/2;    _cy += _H_TIME   + _gap;
    var _bar_cy    = _cy + 80;           _cy += _H_BAR    + _gap;
    var _claim_cy  = _cy + _H_CLAIM/2;   _cy += _H_CLAIM  + _gap;
    var _btn_cy    = _cy + _H_BTN/2;

    // Title.
    ph_draw_text(PH_W/2, _title_cy, "WELL DONE!", global.fnt_disp_xl, _cfg.title_col, fa_center, fa_middle);

    // Puzzle recap (delegated to the puzzle).
    _cfg.draw_recap(PH_W/2, _recap_top, _recap_w, _recap_h);

    // "You solved todays  <PUZZLE>".
    ph_draw_text(PH_W/2, _solved_top + 48,  "You solved todays", global.fnt_disp_xlg, PH_COL_DARK,     fa_center, fa_middle);
    ph_draw_text(PH_W/2, _solved_top + 122, _cfg.puzzle_name,    global.fnt_disp_lg,  _cfg.title_col,  fa_center, fa_middle);

    // "in  [stopwatch] mm:ss".
    ph_draw_text(PH_W/2 - 165, _time_cy, "in", global.fnt_disp_lg, PH_COL_DARK, fa_center, fa_middle);
    var _pl = PH_W/2 - 75, _pr = PH_W/2 + 180;
    ph_draw_chip(_pl, _time_cy-38, _pr, _time_cy+38, 38, PH_COL_WHITE, make_color_rgb(190,170,155), 6);
    draw_sprite_ext(global.spr_stopwatch, 0, _pl+48, _time_cy, 150/512, 150/512, 0, c_white, 1);
    ph_draw_text(_pl+102, _time_cy, _cfg.time_str, global.fnt_body_lg, PH_COL_DARK, fa_left, fa_middle);

    // ── Level progress bar + animated number + level star badge ───────────────
    var _bl = 150, _br = PH_W - 110, _bh = 70;
    var _disp = lerp(_w.xp_anim_from, _w.xp_anim_to, ph_ease_out(_w.xp_anim_t));
    ph_draw_text(_br, _bar_cy - 78, string(round(_disp)) + " / " + string(PH_XP_PER_LEVEL),
                 global.fnt_body_md, PH_COL_GRAY, fa_right, fa_middle);
    ph_draw_rounded(_bl, _bar_cy-_bh/2, _br, _bar_cy+_bh/2, _bh/2, make_color_rgb(220,210,205));
    var _frac = clamp(_disp / PH_XP_PER_LEVEL, 0, 1);
    var _fw   = floor((_br - _bl) * _frac);
    if (_fw > _bh) ph_draw_rounded(_bl, _bar_cy-_bh/2, _bl+_fw, _bar_cy+_bh/2, _bh/2, PH_COL_PURPLE);
    // Level star badge (overlaps the bar's left end; oversized vs the bar).
    var _lvl = ph_level_from_xp(global.save.xp);
    var _badge_x = _bl + 18;
    draw_sprite_ext(global.spr_star, 0, _badge_x, _bar_cy, 200/512, 200/512, 0, c_white, 1);
    ph_draw_text(_badge_x, _bar_cy, string(_lvl), global.fnt_disp_lg, PH_COL_WHITE, fa_center, fa_middle);
    _w.bar_star_x = _badge_x;
    _w.bar_star_y = _bar_cy;

    // ── Action area ───────────────────────────────────────────────────────────
    var _bh3 = 55;   // pill half-height (design 110 px tall)
    if (_w.state == "choose" || _w.state == "after_video") {
        ph_draw_text(PH_W/2, _claim_cy, "Claim your reward", global.fnt_disp_xlg, make_color_rgb(132,59,254), fa_center, fa_middle);
        if (_w.state == "choose") {
            var _xl = 25,  _xr = 400;
            var _dl = 520, _dr = 960;
            // 100 XP + star (oversized icon spills past the pill cap, per design)
            ph_draw_chip(_xl, _btn_cy-_bh3, _xr, _btn_cy+_bh3, _bh3, PH_COL_WHITE, make_color_rgb(190,170,155), 6);
            ph_draw_text(_xl+34, _btn_cy, string(_w.xp_base) + " XP", global.fnt_disp_lg, PH_COL_DARK, fa_left, fa_middle);
            draw_sprite_ext(global.spr_star, 0, _xr-8, _btn_cy, 220/512, 220/512, 0, c_white, 1);
            _w.XP_L=_xl; _w.XP_R=_xr; _w.XP_T=_btn_cy-_bh3; _w.XP_B=_btn_cy+_bh3;
            _w.claim_src_x=(_xl+_xr)/2; _w.claim_src_y=_btn_cy;
            // DOUBLE + TV
            ph_draw_chip(_dl, _btn_cy-_bh3, _dr, _btn_cy+_bh3, _bh3, PH_COL_WHITE, make_color_rgb(190,170,155), 6);
            ph_draw_text(_dl+25, _btn_cy, "DOUBLE", global.fnt_disp_lg, PH_COL_DARK, fa_left, fa_middle);
            draw_sprite_ext(global.spr_tv, 0, _dr-8, _btn_cy, 220/512, 220/512, 0, c_white, 1);
            _w.DBL_L=_dl; _w.DBL_R=_dr; _w.DBL_T=_btn_cy-_bh3; _w.DBL_B=_btn_cy+_bh3;
        } else { // after_video — single centred claim
            var _cxl = PH_W/2 - 235, _cxr = PH_W/2 + 235;
            ph_draw_chip(_cxl, _btn_cy-_bh3, _cxr, _btn_cy+_bh3, _bh3, PH_COL_WHITE, make_color_rgb(190,170,155), 6);
            ph_draw_text(_cxl+45, _btn_cy, string(_w.xp_amount) + " XP", global.fnt_disp_lg, PH_COL_DARK, fa_left, fa_middle);
            draw_sprite_ext(global.spr_star, 0, _cxr-8, _btn_cy, 220/512, 220/512, 0, c_white, 1);
            _w.XP_L=_cxl; _w.XP_R=_cxr; _w.XP_T=_btn_cy-_bh3; _w.XP_B=_btn_cy+_bh3;
            _w.claim_src_x=PH_W/2; _w.claim_src_y=_btn_cy;
        }
    }

    // ── Flying stars (claim animation) ────────────────────────────────────────
    if (_w.state == "claiming") {
        for (var _si = 0; _si < array_length(_w.stars); _si++) {
            var _s = _w.stars[_si];
            if (_s.t < 0) continue;
            var _e  = ph_ease_out(clamp(_s.t, 0, 1));
            var _sx = lerp(_s.x, _s.tx, _e);
            var _syy = lerp(_s.y, _s.ty, _e) - sin(min(_s.t,1) * pi) * 90;   // gentle arc
            var _sa = (_s.t > 0.85) ? (1 - (_s.t - 0.85)/0.15) : 1;
            draw_sprite_ext(global.spr_star, 0, _sx, _syy, _s.sz, _s.sz, 0, c_white, _sa);
        }
    }

    // ── Done state: Share + Back, occupying the claim/button slots ─────────────
    if (_w.state == "done") {
        var _slide = (1 - ph_ease_back(min(_w.outro_t, 1))) * 240;
        // SHARE (pink) — settled bounds for input, slide only the drawing.
        var _sl = PH_W/2 - 235, _sr = PH_W/2 + 235;
        _w.SHARE_L=_sl; _w.SHARE_R=_sr; _w.SHARE_T=_claim_cy-_bh3; _w.SHARE_B=_claim_cy+_bh3;
        var _scy = _claim_cy + _slide;
        ph_draw_chip(_sl, _scy-_bh3, _sr, _scy+_bh3, _bh3, PH_COL_PINK, PH_COL_PINK_DEEP, 6);
        ph_draw_share_glyph(PH_W/2 - 130, _scy, 70, PH_COL_WHITE);
        ph_draw_text(PH_W/2 + 35, _scy, "SHARE", global.fnt_disp_lg, PH_COL_WHITE, fa_center, fa_middle);
        if (_w.share_msg_t > 0) {
            draw_set_alpha(min(1, _w.share_msg_t/20));
            ph_draw_text(PH_W/2, _scy - 95, "LINK COPIED", global.fnt_body_sm, PH_COL_DARK, fa_center, fa_middle);
            draw_set_alpha(1);
        }
        // BACK TO HUB (dark).
        _w.BACK_L=80; _w.BACK_R=PH_W-80; _w.BACK_T=_btn_cy-_bh3; _w.BACK_B=_btn_cy+_bh3;
        var _bcy2 = _btn_cy + _slide;
        ph_draw_chip(80, _bcy2-_bh3, PH_W-80, _bcy2+_bh3, 28, PH_COL_DARK, make_color_rgb(10,5,20), 6);
        ph_draw_text(PH_W/2, _bcy2, "BACK TO HUB", global.fnt_disp_lg, PH_COL_WHITE, fa_center, fa_middle);
    }

    // ── Confetti (top layer) ──────────────────────────────────────────────────
    draw_set_alpha(_intro);
    for (var _ci = 0; _ci < array_length(_w.confetti); _ci++) {
        var _p = _w.confetti[_ci];
        draw_set_color(_p.col);
        if (_p.shape == 2) {
            draw_circle(_p.x, _p.y, _p.size*0.45, false);
        } else if (_p.shape == 0) {
            var _cs = dcos(_p.rot), _sn = dsin(_p.rot);
            var _hw = _p.size*0.5, _hh = _p.size*0.28;
            var _x1=_p.x+(-_hw)*_cs-(-_hh)*_sn, _y1=_p.y+(-_hw)*_sn+(-_hh)*_cs;
            var _x2=_p.x+( _hw)*_cs-(-_hh)*_sn, _y2=_p.y+( _hw)*_sn+(-_hh)*_cs;
            var _x3=_p.x+( _hw)*_cs-( _hh)*_sn, _y3=_p.y+( _hw)*_sn+( _hh)*_cs;
            var _x4=_p.x+(-_hw)*_cs-( _hh)*_sn, _y4=_p.y+(-_hw)*_sn+( _hh)*_cs;
            draw_triangle(_x1,_y1,_x2,_y2,_x3,_y3,false);
            draw_triangle(_x1,_y1,_x3,_y3,_x4,_y4,false);
        } else {
            var _r2 = _p.size*0.5;
            draw_triangle(
                _p.x+cos(degtorad(_p.rot))*_r2,     _p.y+sin(degtorad(_p.rot))*_r2,
                _p.x+cos(degtorad(_p.rot+120))*_r2, _p.y+sin(degtorad(_p.rot+120))*_r2,
                _p.x+cos(degtorad(_p.rot+240))*_r2, _p.y+sin(degtorad(_p.rot+240))*_r2, false);
        }
    }
    draw_set_alpha(1);

    // ── Placeholder rewarded video (DOUBLE path) — drawn last, covers all. ─────
    if (_w.vid_open) ph_video_overlay(_w.vid_timer, _w.VIDEO_X_DELAY, PH_COL_PURPLE);
}
