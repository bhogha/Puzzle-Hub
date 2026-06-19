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
// Win-screen navigation shortcuts (Next Game / Yesterday)
// ──────────────────────────────────────────────────────────────────────────────
// Two power-user shortcuts on the win screen let the player keep going without a
// detour through the hub:
//   • NEXT GAME → the next *unsolved* puzzle on the SAME day, in hub-card order,
//     wrapping around; if every puzzle that day is done, the caller falls back to
//     the hub.
//   • YESTERDAY → the SAME puzzle on the most recent earlier day the player has
//     not finished yet.
// Both treat a missed (lost) Wordle as "done" — it can't be replayed that day.

/// True if the puzzle in room `_room_name` (a "rm_*" string) is finished — solved,
/// or for Wordle solved-or-missed — on the given date key.
function ph_puzzle_is_solved(_room_name, _date_key) {
    switch (_room_name) {
        case "rm_anygram":  return ph_anygram_is_done(global.save, _date_key);
        case "rm_sudoku":   return ph_sudoku_is_done(global.save, _date_key);
        case "rm_wordwave": return ph_wordwave_is_done(global.save, _date_key);
        case "rm_shikaku":  return ph_shikaku_is_done(global.save, _date_key);
        case "rm_wordle":   return ph_wordle_is_done(global.save, _date_key)
                                 || ph_wordle_is_missed(global.save, _date_key);
        case "rm_huesort":  return ph_huesort_is_done(global.save, _date_key);
        case "rm_colorlink":return ph_colorlink_is_done(global.save, _date_key);
        case "rm_wordbend": return ph_wordbend_is_done(global.save, _date_key);
        case "rm_arrows":   return ph_arrows_is_done(global.save, _date_key);
        case "rm_ladder":   return ph_ladder_is_done(global.save, _date_key);
        case "rm_colordoku":return ph_colordoku_is_done(global.save, _date_key);
    }
    return false;
}

/// Room name ("rm_*") of the next unsolved puzzle after the current room, in
/// hub-card order, wrapping around. Skips locked / placeholder cards and puzzles
/// already finished on `_date_key`. Returns "" when none remain (all done).
function ph_win_next_unsolved_room(_date_key) {
    var _cards = ph_game_cards();
    var _n     = array_length(_cards);
    var _cur   = room_get_name(room);
    var _ci    = -1;
    for (var _i = 0; _i < _n; _i++) if (_cards[_i].room == _cur) { _ci = _i; break; }
    for (var _k = 1; _k <= _n; _k++) {
        var _c = _cards[(_ci + _k) mod _n];
        if (_c.locked || _c.room == "") continue;
        if (ph_puzzle_is_solved(_c.room, _date_key)) continue;
        return _c.room;
    }
    return "";
}

/// Date key of the most recent day BEFORE `_from_key` on which the puzzle in
/// `_room_name` is still unsolved. Walks back up to ~2 years; returns "" if none.
function ph_win_prev_unsolved_date(_room_name, _from_key) {
    var _y  = real(string_copy(_from_key, 1, 4));
    var _m  = real(string_copy(_from_key, 6, 2));
    var _d  = real(string_copy(_from_key, 9, 2));
    var _dt = date_create_datetime(_y, _m, _d, 0, 0, 0);
    for (var _k = 1; _k <= 750; _k++) {
        var _pk = ph_date_key(ph_date_add_days(_dt, -_k));
        if (!ph_puzzle_is_solved(_room_name, _pk)) return _pk;
    }
    return "";
}

/// Navigate to (room asset, date key). If a level-up is queued, show the Level-Up
/// reward screen first and have it continue to this destination afterwards — coins
/// are still granted there, but the hub coin-flow animation is skipped (we're not
/// landing on the hub). Otherwise go straight to the target room.
function ph_win_route(_room, _date_key) {
    if (ph_levelup_pending()) {
        // Explicit assignment (no non-constant struct literals — YYC linker gotcha).
        var _post  = {};
        _post.kind = "room";
        _post.room = _room;
        _post.date = _date_key;
        global.post_levelup = _post;
        room_goto(rm_win);
    } else {
        global.selected_date_key = _date_key;
        room_goto(_room);
    }
}

/// NEXT GAME shortcut: next unsolved puzzle on the same day (wrap); else the hub.
function ph_win_go_next() {
    var _rn = ph_win_next_unsolved_room(global.selected_date_key);
    if (_rn == "") { room_goto(ph_levelup_pending() ? rm_win : rm_hub); return; }
    ph_win_route(asset_get_index(_rn), global.selected_date_key);
}

/// YESTERDAY shortcut: same puzzle, most recent earlier day still unsolved.
function ph_win_go_yesterday() {
    var _cur  = room_get_name(room);
    var _date = ph_win_prev_unsolved_date(_cur, global.selected_date_key);
    if (_date == "") { room_goto(ph_levelup_pending() ? rm_win : rm_hub); return; }
    ph_win_route(asset_get_index(_cur), _date);
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
        SHARE_L:0, SHARE_R:0, SHARE_T:0, SHARE_B:0,   // done-state row 1 (left)
        HOME_L:0, HOME_R:0, HOME_T:0, HOME_B:0,       // done-state row 1 (right)
        NEXT_L:0, NEXT_R:0, NEXT_T:0, NEXT_B:0,       // done-state row 2
        YEST_L:0, YEST_R:0, YEST_T:0, YEST_B:0,       // done-state row 3
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
    // Missions: record this genuine solve into the current week's counters.
    // Runs once per solve (guarded above by _w.granted) and never in review mode.
    ph_week_record_solve(global.save, _w.cfg.claim_key);
    if (_res.levels_gained > 0) {
        global.pending_levelup = { level: _res.new_level, base_reward: PH_COINS_PER_LEVEL };
        _w.xp_anim_to = PH_XP_PER_LEVEL;           // fill to full; Level-Up screen continues
    } else {
        _w.xp_anim_to = ph_xp_in_level(global.save.xp);
    }
    _w.xp_anim_from = _before;
    _w.xp_anim_t    = 0;
    ph_save_write(global.save);
    // First genuine solve → ask for notification permission + schedule the daily
    // reminder (iOS only; runs once, guarded inside). Never fires in review mode.
    ph_notify_request_after_first_solve();
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
            } else if (ph_point_in_rect(_mx,_my, _w.HOME_L,_w.HOME_T,_w.HOME_R,_w.HOME_B)) {
                room_goto(ph_levelup_pending() ? rm_win : rm_hub);   // HOME (level-up first → coin flow on hub)
            } else if (ph_point_in_rect(_mx,_my, _w.NEXT_L,_w.NEXT_T,_w.NEXT_R,_w.NEXT_B)) {
                ph_win_go_next();
            } else if (ph_point_in_rect(_mx,_my, _w.YEST_L,_w.YEST_T,_w.YEST_R,_w.YEST_B)) {
                ph_win_go_yesterday();
            }
            break;
    }
}

/// Draw the whole win screen for the current state.
function ph_win_draw(_w) {
    var _cfg   = _w.cfg;
    var _intro = ph_ease_out(_w.intro_t);
    // Inset + comfort padding so "WELL DONE!" clears the Dynamic Island and the
    // reward buttons (with their oversized star/TV icons) clear the home indicator.
    var _st    = ph_safe_top();
    var _sb    = ph_safe_bottom();

    // Full-screen backdrop (fades in). Fixed mint per the Penpot Win Screen design.
    draw_set_alpha(_intro);
    draw_set_color(make_color_rgb(173, 255, 241));   // #ADFFF1
    draw_rectangle(0, 0, PH_W, PH_H, false);
    draw_set_alpha(1);

    // ── Responsive vertical flow ──────────────────────────────────────────────
    // The Penpot board assumes a tall canvas; real devices/windows vary, so the
    // blocks are laid out as a flow that compresses on shorter screens (recap
    // height + inter-block gaps absorb the slack). Element sizes still track the
    // design where space allows. New Penpot flow (top→bottom):
    //   TITLE · RECAP · "Completed in [time]" · "Claim your reward!" ·
    //   reward amount ("100 ⭐") · XP bar · CLAIM | DOUBLE buttons.
    var _avail = PH_H - _st - _sb;
    var _H_TITLE = 180, _H_COMPLETED = 100, _H_CLAIM = 90, _H_AMT = 120, _H_BAR = 120, _H_BTN = 150;
    var _GAP0 = 24, _NGAP = 6;
    var _fixed   = _H_TITLE + _H_COMPLETED + _H_CLAIM + _H_AMT + _H_BAR + _H_BTN;
    var _recap_h = clamp(_avail - _fixed - _GAP0*_NGAP, 240, 640);
    var _recap_w = min(540, _recap_h);
    var _gap     = _GAP0 + max(0, _avail - _fixed - _recap_h - _GAP0*_NGAP) / _NGAP;

    var _cy = _st;
    var _title_cy     = _cy + _H_TITLE/2;     _cy += _H_TITLE     + _gap;
    var _recap_top    = _cy;                  _cy += _recap_h     + _gap;
    var _completed_cy = _cy + _H_COMPLETED/2; _cy += _H_COMPLETED + _gap;
    var _claim_cy     = _cy + _H_CLAIM/2;     _cy += _H_CLAIM     + _gap;
    var _amt_cy       = _cy + _H_AMT/2;       _cy += _H_AMT       + _gap;
    var _bar_cy       = _cy + 60;             _cy += _H_BAR       + _gap;
    var _btn_cy       = _cy + _H_BTN/2;

    // Title (large Lilita display per the Win Screen design).
    ph_draw_text(PH_W/2, _title_cy, "WELL DONE!", global.fnt_disp_xxl, _cfg.title_col, fa_center, fa_middle);

    // Puzzle recap (delegated to the puzzle).
    _cfg.draw_recap(PH_W/2, _recap_top, _recap_w, _recap_h);

    // "Completed in  [stopwatch] mm:ss" — single centred line (replaces the old
    // "You solved todays <PUZZLE> / in ..." block).
    draw_set_font(global.fnt_body_reg);
    var _clbl  = "Completed in";
    var _clw   = string_width(_clbl);
    var _pillw = 250, _lpgap = 28;
    var _grpw  = _clw + _lpgap + _pillw;
    var _grpx  = PH_W/2 - _grpw/2;
    ph_draw_text(_grpx, _completed_cy, _clbl, global.fnt_body_reg, PH_COL_DARK, fa_left, fa_middle);
    var _pl = _grpx + _clw + _lpgap, _pr = _pl + _pillw;
    ph_draw_chip(_pl, _completed_cy-38, _pr, _completed_cy+38, 38, PH_COL_WHITE, make_color_rgb(190,170,155), 6);
    draw_sprite_ext(global.spr_stopwatch, 0, _pl+48, _completed_cy, 150/512, 150/512, 0, c_white, 1);
    ph_draw_text(_pl+96, _completed_cy, _cfg.time_str, global.fnt_body_lg, PH_COL_DARK, fa_left, fa_middle);

    // ── Level progress bar + animated number + level star badge ───────────────
    // Hidden once we reach the "done" state — that lower band becomes the
    // SHARE / HOME / NEXT GAME / YESTERDAY button stack instead (per the design).
    var _bh3 = 55;   // reward/nav button half-height (design ~110 px tall)
    if (_w.state != "done") {
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
    }

    // ── Action area: "Claim your reward!" + amount + CLAIM/DOUBLE buttons ──────
    if (_w.state == "choose" || _w.state == "after_video") {
        ph_draw_text(PH_W/2, _claim_cy, "Claim your reward!", global.fnt_body_semi, PH_COL_DARK, fa_center, fa_middle);

        // Reward amount: "<amount>  ⭐"  (large Nunito number + 3D star icon).
        var _amt_str = string(_w.xp_amount);
        draw_set_font(global.fnt_num_xl);
        var _anw   = string_width(_amt_str);
        var _astar = 130, _agap = 24;
        var _agrp  = _anw + _agap + _astar;
        var _ax0   = PH_W/2 - _agrp/2;
        ph_draw_text(_ax0 + _anw/2, _amt_cy, _amt_str, global.fnt_num_xl, PH_COL_DARK, fa_center, fa_middle);
        draw_sprite_ext(global.spr_star3d, 0, _ax0 + _anw + _agap + _astar/2, _amt_cy, _astar/256, _astar/256, 0, c_white, 1);

        if (_w.state == "choose") {
            var _xl = 70,            _xr = PH_W/2 - 15;
            var _dl = PH_W/2 + 15,   _dr = PH_W - 70;
            ph_draw_reward_btn(_xl, _btn_cy, _xr, _bh3, "CLAIM",  noone, false);
            _w.XP_L=_xl; _w.XP_R=_xr; _w.XP_T=_btn_cy-_bh3; _w.XP_B=_btn_cy+_bh3;
            _w.claim_src_x=(_xl+_xr)/2; _w.claim_src_y=_btn_cy;
            // DOUBLE via rewarded video (TV badge).
            ph_draw_reward_btn(_dl, _btn_cy, _dr, _bh3, "DOUBLE", noone, true);
            _w.DBL_L=_dl; _w.DBL_R=_dr; _w.DBL_T=_btn_cy-_bh3; _w.DBL_B=_btn_cy+_bh3;
        } else { // after_video — single centred CLAIM of the doubled amount
            var _cxl = PH_W/2 - 235, _cxr = PH_W/2 + 235;
            ph_draw_reward_btn(_cxl, _btn_cy, _cxr, _bh3, "CLAIM", noone, false);
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

    // ── Done state: SHARE | HOME, then NEXT GAME, then YESTERDAY ───────────────
    // Three rows of buttons fill the band that held the bar + claim controls. The
    // two shortcuts (NEXT GAME / YESTERDAY) skip the hub; HOME returns to it.
    if (_w.state == "done") {
        var _slide   = (1 - ph_ease_back(min(_w.outro_t, 1))) * 240;
        var _row_h   = 132;                         // spacing between row centres
        // Bottom-anchored stack (YESTERDAY just above the home indicator), so it's
        // independent of the claim/amount blocks that only show pre-claim.
        var _r3cy    = PH_H - _sb - 90;             // YESTERDAY (bottom row)
        var _r2cy    = _r3cy - _row_h;              // NEXT GAME
        var _r1cy    = _r3cy - _row_h * 2;          // SHARE | HOME
        var _half    = PH_W/2;

        // Row 1 — SHARE (pink, left half)
        var _sl = 70, _sr = _half - 15;
        _w.SHARE_L=_sl; _w.SHARE_R=_sr; _w.SHARE_T=_r1cy-_bh3; _w.SHARE_B=_r1cy+_bh3;
        ph_draw_nav_btn(_sl, _r1cy + _slide, _sr, _bh3, "SHARE", noone, PH_COL_PINK, PH_COL_PINK_DEEP);
        if (variable_global_exists("spr_share_icon") && global.spr_share_icon >= 0)
            draw_sprite_ext(global.spr_share_icon, 0, _sl + 92, _r1cy + _slide, 0.9, 0.9, 0, PH_COL_WHITE, 1);
        else
            ph_draw_share_glyph(_sl + 92, _r1cy + _slide, 44, PH_COL_WHITE);
        if (_w.share_msg_t > 0) {
            draw_set_alpha(min(1, _w.share_msg_t/20));
            ph_draw_text((_sl+_sr)/2, _r1cy + _slide - 88, "LINK COPIED", global.fnt_body_sm, PH_COL_DARK, fa_center, fa_middle);
            draw_set_alpha(1);
        }
        // Row 1 — HOME (blue, right half)
        var _hl = _half + 15, _hr = PH_W - 70;
        _w.HOME_L=_hl; _w.HOME_R=_hr; _w.HOME_T=_r1cy-_bh3; _w.HOME_B=_r1cy+_bh3;
        ph_draw_nav_btn(_hl, _r1cy + _slide, _hr, _bh3, "HOME", global.spr_home, noone, noone);

        // Row 2 — NEXT GAME (blue, full width)
        _w.NEXT_L=70; _w.NEXT_R=PH_W-70; _w.NEXT_T=_r2cy-_bh3; _w.NEXT_B=_r2cy+_bh3;
        ph_draw_nav_btn(70, _r2cy + _slide, PH_W-70, _bh3, "NEXT GAME", global.spr_puzzle, noone, noone);

        // Row 3 — YESTERDAY (blue, full width)
        _w.YEST_L=70; _w.YEST_R=PH_W-70; _w.YEST_T=_r3cy-_bh3; _w.YEST_B=_r3cy+_bh3;
        ph_draw_nav_btn(70, _r3cy + _slide, PH_W-70, _bh3, "YESTERDAY", global.spr_cal, noone, noone);
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
