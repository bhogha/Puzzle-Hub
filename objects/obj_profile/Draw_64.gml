// ── Event Hub — Draw GUI (weekly Missions screen) ─────────────────────────────
// Input handled in Step_0. Layout from prof_metrics(); geometry constants in Create.
// Penpot "Events" design: cream top-bar band over a teal body; EVENT HUB title;
// description + reset-timer pill; mission tiles (In Progress / Completed / Claimed).

var _save  = global.save;
var _level = ph_level_from_xp(_save.xp);
var _coins = _save.coins;
var M      = prof_metrics();

// Palette (local)
var _teal     = make_color_rgb(173,255,241);     // #adfff1 body
var _cream    = make_color_rgb(254,247,241);     // #fef7f1 top band
var _track    = make_color_rgb(228,221,231);     // progress-bar track
var _rew_col  = make_color_rgb(120,108,122);     // reward number / count ink
var _claim_ink  = make_color_rgb(170,160,172);   // faded claimed title

// ── Background: teal body + cream top-bar band ────────────────────────────────
draw_set_color(_teal);
draw_rectangle(0, 0, PH_W, PH_H, false);
draw_set_color(_cream);
draw_rectangle(0, 0, PH_W, M.band_bot, false);

// ═══ Top bar: level pill · EVENT HUB · coin pill ═════════════════════════════
var _cy = M.topbar_cy;
ph_draw_chip(70, _cy-34, 270, _cy+34, 34, PH_COL_WHITE, PH_COL_TILE_DARK, 5);
// Level star — "embraces" the incoming stream: opens its arms (expands) as the copies
// approach, HOLDS open with a small pop on each arrival, then absorbs + settles.
var _ls = 110/512;
var _lsx = _ls, _lsy = _ls;
if (levelstar_t >= 0) {
    var _win = (STARFLY_N-1) * SF_RELGAP;                            // arrival-stream span
    var _g;
    if (levelstar_t < LEVELSTAR_LEAD) {
        var _a = levelstar_t / LEVELSTAR_LEAD;                       // 0..1 approach
        _g = 1 + LEVELSTAR_EMBRACE * ph_ease_out(_a);               // open arms
    } else if (levelstar_t < LEVELSTAR_LEAD + _win) {
        // Hold open through the stream, with a squash pop on each copy's arrival.
        var _u = (levelstar_t - LEVELSTAR_LEAD) mod SF_RELGAP;       // 0..GAP within each beat
        _g = 1 + LEVELSTAR_EMBRACE + 0.11 * (1 - _u/SF_RELGAP);
    } else {
        var _b = (levelstar_t - LEVELSTAR_LEAD - _win) / LEVELSTAR_TAIL; // 0..1 after last
        _g = 1 + LEVELSTAR_EMBRACE * cos(_b * pi * 1.5) * (1 - _b);  // absorb inward → settle
    }
    _lsx = _ls * _g;
    _lsy = _ls * _g;
}
draw_sprite_ext(global.spr_star3d, 0, 82, _cy, _lsx, _lsy, 0, c_white, 1);
ph_draw_text((127 + 270)/2, _cy, string(_level), global.fnt_pill_num, PH_COL_DARK, fa_center, fa_middle);
ph_draw_text(PH_W/2, _cy, "EVENTS", global.fnt_disp_md, PH_COL_PINK, fa_center, fa_middle);
var _px2 = PH_W - 24, _px1 = _px2 - 310;
ph_draw_chip(_px1, _cy-34, _px2, _cy+34, 34, PH_COL_WHITE, PH_COL_TILE_DARK, 5);
draw_sprite_ext(global.spr_gold_coin, 0, _px1+12, _cy, 110/512, 110/512, 0, c_white, 1);
var _plus_cx = _px2 - 36;
ph_draw_chip(_plus_cx-24, _cy-24, _plus_cx+24, _cy+24, 24, PH_COL_PINK, PH_COL_PINK_DEEP, 4);
ph_draw_text(_plus_cx, _cy-2, "+", global.fnt_disp_xs, PH_COL_WHITE, fa_center, fa_middle);
ph_draw_text(_plus_cx-32, _cy, ph_format_int_thousands(_coins), global.fnt_pill_num, PH_COL_DARK, fa_right, fa_middle);

// ═══ Sound on/off toggle (speaker chip, header bottom-left) ══════════════════
var _spk_cx = 120, _spk_cy = M.timer_cy;
ph_draw_chip(_spk_cx-52, _spk_cy-52, _spk_cx+52, _spk_cy+52, 52, PH_COL_WHITE, PH_COL_TILE_DARK, 5);
var _son = ph_sfx_enabled();
ph_draw_speaker_icon(_spk_cx-4, _spk_cy, 58, _son, _son ? PH_COL_DARK : PH_COL_GRAY);

// ═══ Haptics on/off toggle (vibrate chip, beside the speaker) ═════════════════
// Reads the raw save flag (not ph_haptic_enabled) so the chip reflects the
// player's choice even when probed on a non-iOS build.
var _vib_cx = 244, _vib_cy = M.timer_cy;
ph_draw_chip(_vib_cx-52, _vib_cy-52, _vib_cx+52, _vib_cy+52, 52, PH_COL_WHITE, PH_COL_TILE_DARK, 5);
var _von = (global.save.haptics_on ?? true);
ph_draw_vibrate_icon(_vib_cx, _vib_cy, 58, _von, _von ? PH_COL_DARK : PH_COL_GRAY);

// ═══ Header: active = description + reset-timer pill; finished = "Week Complete" ═
var _wc_finished = (_save.week.status == "finished");
if (_wc_finished) {
    // Finished state hides the countdown entirely — just the celebratory title.
    var _wc_teal = make_color_rgb(20,150,132);
    ph_draw_text(PH_W/2, (M.desc_y + M.timer_cy)/2, "Week Complete",
                 global.fnt_disp_lg, _wc_teal, fa_center, fa_middle);
} else {
    ph_draw_text(PH_W/2, M.desc_y, "Complete missions to win extra rewards",
                 global.fnt_tip, PH_COL_DARK, fa_center, fa_middle);

    // Timer pill — white capsule, stopwatch over the left edge, "Xd Yh" beside it.
    var _tcy = M.timer_cy;
    var _tpl = PH_W/2 - 200, _tpr = PH_W/2 + 200;
    ph_draw_chip(_tpl, _tcy-50, _tpr, _tcy+50, 50, PH_COL_WHITE, PH_COL_TILE_DARK, 5);
    draw_sprite_ext(global.spr_stopwatch, 0, _tpl+4, _tcy, 120/512, 120/512, 0, c_white, 1);
    var _tstr = ph_week_time_left_str(_save);
    ph_draw_text((_tpl+70 + _tpr)/2, _tcy, _tstr, global.fnt_tip, PH_COL_DARK, fa_center, fa_middle);
}

// ═══ Finished week → Week Complete list: claimable → CLAIM ALL → claimed → grey ══
if (_wc_finished) {
    var _force = (claim_phase == 3) ? fly_idxs : undefined;
    var _g  = prof_finished_groups(_force);
    var _fl = prof_finished_layout(M.list_top, _g);

    ph_scissor_gui(CARD_L-4, M.list_top, (CARD_R-CARD_L)+8, M.list_bot - M.list_top);

    // Claimable cards (CLAIM button, or the ★→✓ transition while flying).
    for (var _ci = 0; _ci < array_length(_g.claimable); _ci++) {
        var _mi = _g.claimable[_ci];
        var _t  = _fl.top[_mi];
        if (_t <= M.list_bot && _t + CARD_H >= M.list_top) prof_draw_mission_card(_mi, _t);
    }
    // CLAIM ALL button (always shown in the finished state).
    if (_fl.btn_cy - 60 < M.list_bot && _fl.btn_cy + 60 > M.list_top) {
        ph_draw_reward_btn(PH_W/2-240, _fl.btn_cy, PH_W/2+240, 60, "CLAIM ALL", noone, false);
    }
    // Claimed cards (checkmark) — stay visible below the button.
    for (var _ci = 0; _ci < array_length(_g.claimed); _ci++) {
        var _mi = _g.claimed[_ci];
        var _t  = _fl.top[_mi];
        if (_t <= M.list_bot && _t + CARD_H >= M.list_top) prof_draw_mission_card(_mi, _t);
    }
    // Incomplete cards (greyed) — at the bottom.
    for (var _ci = 0; _ci < array_length(_g.incomplete); _ci++) {
        var _mi = _g.incomplete[_ci];
        var _t  = _fl.top[_mi];
        if (_t <= M.list_bot && _t + CARD_H >= M.list_top) prof_draw_mission_card(_mi, _t);
    }
    ph_scissor_reset();
} else {
    // ═══ Scrollable mission list (sorted: claimable → in-progress → claimed) ══
    // Claim celebration: STARFLY (phase 1) holds the list still while the stars fly
    // and the checkmark pops; REORDER (phase 2) starts the instant the checkmark
    // lands — the claimed tile BOUNCES in place (anticipation) then slides down
    // BEHIND the remaining tiles (drawn first) to the claimed group as the next rises.
    var _ms    = _save.week.missions;
    var _order = prof_sorted_indices();
    var _hold  = (claim_phase == 1);                      // list held still during STARFLY
    // Target slot (sorted position) per mission index — independent of draw order.
    var _pos_of = array_create(array_length(_ms), 0);
    for (var _k = 0; _k < array_length(_order); _k++) _pos_of[_order[_k]] = _k;
    // Draw order: usually the sorted order; during REORDER the claimed tile is drawn
    // first so the remaining tiles paint OVER it as it slides down behind them.
    var _draw_order = _order;
    if (claim_phase == 2 && claim_mi >= 0) {
        _draw_order = [claim_mi];
        for (var _k = 0; _k < array_length(_order); _k++)
            if (_order[_k] != claim_mi) array_push(_draw_order, _order[_k]);
    }
    // Reorder = a short in-place BOUNCE (claimed tile only) then a smoothstep SLIDE
    // for everyone, capped overshoot at the end. _in_bounce holds the list during it.
    var _in_bounce = (claim_phase == 2 && claim_t < REORDER_BOUNCE);
    var _slide_p   = (claim_phase == 2) ? clamp((claim_t - REORDER_BOUNCE) / (REORDER_DUR - REORDER_BOUNCE), 0, 1) : 1;
    var _slide_e   = ph_ease_in_out(_slide_p);           // cubic: clear accelerate → decelerate
    ph_scissor_gui(CARD_L-4, M.list_top, (CARD_R-CARD_L)+8, M.list_bot - M.list_top);
    for (var _di = 0; _di < array_length(_draw_order); _di++) {
        var _mi   = _draw_order[_di];
        var _p    = _pos_of[_mi];
        var _slot = _p;
        if (_hold && _mi < array_length(slot_old))                 _slot = slot_old[_mi];
        else if (claim_phase == 2 && _mi < array_length(slot_old)) _slot = lerp(slot_old[_mi], _p, _slide_e);
        var _t = M.list_top + _slot * (CARD_H + CARD_GAP) - scroll_y;
        // Claimed tile: anticipation BOUNCE before it slides down — snaps UP fast
        // (decel to a brief hang at the peak), then ACCELERATES back down.
        if (claim_phase == 2 && _mi == claim_mi && claim_t < REORDER_BOUNCE) {
            var _bp = claim_t / REORDER_BOUNCE;
            var _bh = (_bp < 0.45) ? ph_ease_out(_bp/0.45) : (1 - ph_ease_in((_bp-0.45)/0.55));
            _t -= BOUNCE_PX * _bh;
        }
        // Settle overshoot at the tail of the slide (all moving tiles).
        if (claim_phase == 2 && !_in_bounce && _mi < array_length(slot_old)) {
            var _dir = (_p > slot_old[_mi]) ? 1 : ((_p < slot_old[_mi]) ? -1 : 0);
            if (_dir != 0 && _slide_p > 0.7)
                _t += _dir * REORDER_OVERSHOOT_PX * sin(clamp((_slide_p-0.7)/0.3, 0, 1)*pi);
        }
        if (_t > M.list_bot || _t + CARD_H < M.list_top) continue;   // cull off-screen
        var _m    = _ms[_mi];
        var _val  = ph_mission_value(_save, _m);
        var _comp = (_val >= _m.target);
        var _title = ph_mission_title(_m);
        var _icy  = _t + CARD_H/2;

        // Is THIS the tile mid-celebration (STARFLY/CHECKPOP)? It renders a special
        // transition (reward ★ winding up / flown off → checkmark) instead of the
        // static claimable/claimed states, and stays un-tinted until it reorders.
        var _claiming = (_mi == claim_mi && claim_phase == 1);

        // Card background sprite (cream rect + divider + reward column baked in);
        // claimed cards are tinted slightly cooler/muted (not while still claiming).
        var _ccx = (CARD_L + CARD_R)/2, _ccy = _t + CARD_H/2;
        var _ctint = (_m.claimed && !_claiming) ? make_color_rgb(232,228,224) : c_white;
        draw_sprite_ext(global.spr_card_mission, 0, _ccx, _ccy, CARD_W/1410, CARD_H/390, 0, _ctint, 1);
        // Icon tile (white rounded) + icon — not baked into the card sprite.
        ph_draw_rounded(ICON_CX-ICON_SZ/2, _icy-ICON_SZ/2, ICON_CX+ICON_SZ/2, _icy+ICON_SZ/2, 26, PH_COL_WHITE);
        draw_sprite_ext(prof_icon(_m.icon), 0, ICON_CX, _icy, ICON_SZ/512, ICON_SZ/512, 0, c_white, 1);

        if (_claiming) {
            // ── Transition tile: title centred; right column animates ★ → ✓ ──
            draw_set_font(global.fnt_tip); draw_set_halign(fa_left); draw_set_valign(fa_middle);
            draw_set_color(PH_COL_DARK);
            draw_text_ext(MAIN_X1, _icy, _title, 50, MAIN_X2 - MAIN_X1);
            // Phase-1 transition on the claimed tile (the reward ★ / orbiting cluster
            // is drawn by the flying-star block on top — it duplicates into the copies):
            var _spawn_done = SF_GATHER + SF_ORBIT + (STARFLY_N-1)*SF_RELGAP; // last copy leaves the spot
            if (claim_t < SF_GATHER) {
                // Gather: fade the reward amount out as the star duplicates.
                draw_set_alpha(1 - claim_t / SF_GATHER);
                ph_draw_text(REW_CX+2, _icy, string(_m.reward), global.fnt_num_reg, _rew_col, fa_right, fa_middle);
                draw_set_alpha(1);
            } else if (claim_t >= _spawn_done - 4) {
                // As the LAST copy peels off the spot, the checkmark pops into the SAME
                // place (ease_back overshoot); the last orbiting copy covers it until it
                // flies, so it's revealed seamlessly. Copies keep streaming up on top.
                var _ks = (CARD_W * 190/1410) / 194;
                var _pp = ph_ease_out_back(clamp((claim_t - (_spawn_done - 4)) / CHECK_POP, 0, 1), 2.4);
                draw_sprite_ext(global.spr_checkmark, 0, REW_CX, _icy, _ks*_pp, _ks*_pp, 0, c_white, 1);
            }
        } else if (_m.claimed) {
            // Claimed — faded title (vertically centred); right column = checkmark.
            draw_set_font(global.fnt_tip); draw_set_halign(fa_left); draw_set_valign(fa_middle);
            draw_set_color(_claim_ink);
            draw_text_ext(MAIN_X1, _icy, _title, 50, MAIN_X2 - MAIN_X1);
            // Gold-outlined purple checkmark sprite, centred in the reward column.
            var _ks = (CARD_W * 190/1410) / 194;
            draw_sprite_ext(global.spr_checkmark, 0, REW_CX, _icy, _ks, _ks, 0, c_white, 1);
        } else if (_comp) {
            // Claimable — CLAIM button (top) + description (below) + reward ★.
            var _cr = prof_claim_rect(_t);
            ph_draw_reward_btn(_cr.l, _cr.cy, _cr.r, _cr.bh, "CLAIM", noone, false);
            draw_set_font(global.fnt_tip); draw_set_halign(fa_left); draw_set_valign(fa_top);
            draw_set_color(PH_COL_DARK);
            draw_text_ext(MAIN_X1, _t+165, _title, 50, MAIN_X2 - MAIN_X1);
            draw_sprite_ext(global.spr_star3d, 0, REW_CX+46, _icy, 100/512, 100/512, 0, c_white, 1);
            ph_draw_text(REW_CX+2, _icy, string(_m.reward), global.fnt_num_reg, _rew_col, fa_right, fa_middle);
        } else {
            // In progress — title (top), progress bar, count to the RIGHT of the bar.
            draw_set_font(global.fnt_tip); draw_set_halign(fa_left); draw_set_valign(fa_top);
            draw_set_color(PH_COL_DARK);
            draw_text_ext(MAIN_X1, _t+50, _title, 50, MAIN_X2 - MAIN_X1);
            var _bcy = _t + CARD_H - 66, _bh = 44;
            var _bx2 = MAIN_X2 - 150;                       // leave room for the count
            ph_draw_rounded(MAIN_X1, _bcy-_bh/2, _bx2, _bcy+_bh/2, _bh/2, _track);
            var _fillw = (_bx2-MAIN_X1) * clamp(_val/_m.target, 0, 1);
            if (_fillw > _bh) ph_draw_rounded(MAIN_X1, _bcy-_bh/2, MAIN_X1+_fillw, _bcy+_bh/2, _bh/2, PH_COL_PURPLE);
            ph_draw_text(MAIN_X2, _bcy, string(_val) + " / " + string(_m.target),
                         global.fnt_body_md, _rew_col, fa_right, fa_middle);
            draw_sprite_ext(global.spr_star3d, 0, REW_CX+46, _icy, 100/512, 100/512, 0, c_white, 1);
            ph_draw_text(REW_CX+2, _icy, string(_m.reward), global.fnt_num_reg, _rew_col, fa_right, fa_middle);
        }
    }
    ph_scissor_reset();
}

// ═══ Nav (Events = rightmost tab; badge handled inside ph_draw_nav) ══════════
ph_draw_nav(2);

// ═══ Claim STARFLY (Royal-Match-style): the reward ★ DUPLICATES into a cluster that ══
// gathers + orbits each other at the spot, then the copies peel off ONE BY ONE,
// ACCELERATING up to the level ★ and vanishing there with a light flash. Source
// position tracks the claimed tile live.
// Source ★ positions: phase 1 = the single claimed tile; phase 3 = every flying
// tile (finished claim / CLAIM ALL), all bursting on the SAME timeline.
var _src_xs = [];
var _src_ys = [];
if (claim_phase == 1 && claim_mi >= 0 && claim_mi < array_length(slot_old)) {
    var _src_top = M.list_top + slot_old[claim_mi]*(CARD_H+CARD_GAP) - scroll_y;
    array_push(_src_xs, REW_CX + 46);
    array_push(_src_ys, _src_top + CARD_H/2);
} else if (claim_phase == 3 && array_length(fly_idxs) > 0) {
    var _fl3 = prof_finished_layout(M.list_top, prof_finished_groups(fly_idxs));
    for (var _fi = 0; _fi < array_length(fly_idxs); _fi++) {
        array_push(_src_xs, REW_CX + 46);
        array_push(_src_ys, _fl3.top[fly_idxs[_fi]] + CARD_H/2);
    }
}
if (array_length(_src_xs) > 0) {
    var _tx  = 82, _ty = M.topbar_cy;                       // level ★ destination
    var _hud_s = 110/512;                                   // arrival size = HUD star's
    var _rew_s = 100/512;                                   // reward ★ rest size

  for (var _src_i = 0; _src_i < array_length(_src_xs); _src_i++) {
    var _cx0 = _src_xs[_src_i];                             // source centre (reward ★ spot)
    var _cy0 = _src_ys[_src_i];

    for (var _s = 0; _s < STARFLY_N; _s++) {
        var _rel  = SF_GATHER + SF_ORBIT + _s*SF_RELGAP;    // this copy's release frame
        var _arr  = _rel + SF_TRAVEL;                       // its arrival frame
        var _spawn = _s * SF_SPAWNGAP;                      // this copy's appear frame
        // Per-copy organic orbit params (deterministic pseudo-random from _s): varied
        // radius / speed / phase + a slow bob, so they mill in a loose CLUSTER instead
        // of sitting on a perfect ring.
        var _ang0 = _s * (2*pi/STARFLY_N);
        var _h1 = frac(sin(_s*12.9898 + 1.3)*43758.5453);
        var _h2 = frac(sin(_s*78.2330 + 2.7)*43758.5453);
        var _h3 = frac(sin(_s*37.7190 + 0.7)*43758.5453);
        var _orad = SF_ORBIT_R * (0.36 + 0.64*_h1);         // some near the centre, some out
        var _oasp = SF_ORBIT_SPD * (0.78 + 0.44*_h2);       // slightly different speeds
        var _aoff = _ang0 + (_h3 - 0.5)*1.5;                // uneven angular spacing
        var _bobA = 5 + 9*_h2;                              // small positional bob (px) …
        var _bobF = 0.09 + 0.10*_h1;                        // … at its own rate

        if (claim_t < _rel) {
            if (claim_t < _spawn) continue;                 // not spawned yet — copies APPEAR one by one
            // ── Gather + orbit: copy #0 is the original ★ (already there); the rest POP
            // IN one by one, spiral out and mill around each other as a loose cluster. ─
            var _age    = claim_t - _spawn;
            var _spread = clamp(_age / SF_GATHER, 0, 1);
            var _ang = _aoff + _oasp * claim_t;
            var _rr  = _orad * ph_ease_out(_spread);
            var _ox  = _cx0 + cos(_ang)*_rr + sin(claim_t*_bobF + _h3*6)*_bobA;
            var _oy  = _cy0 + sin(_ang)*_rr*0.62 + cos(claim_t*_bobF*1.2 + _h1*6)*_bobA*0.6;
            var _depth = 1 + 0.16 * sin(_ang);              // front (lower) reads bigger
            var _apop  = (_s == 0) ? 1 : ph_ease_out_back(clamp(_age/5, 0, 1), 2.2); // pop in on appear
            var _osc = _rew_s * lerp(1.0, 0.82, _spread) * _depth * _apop;
            draw_sprite_ext(global.spr_star3d, 0, _ox, _oy, _osc, _osc, 0, c_white, 1);
        } else if (claim_t < _arr) {
            // ── Flight: from its cluster position (at release) up to the level ★,
            // ACCELERATING the whole way (cubic ease-in), growing to the HUD size. ──
            var _rang = _aoff + _oasp * _rel;               // its angle at release
            var _rx = _cx0 + cos(_rang)*_orad + sin(_rel*_bobF + _h3*6)*_bobA;
            var _ry = _cy0 + sin(_rang)*_orad*0.62 + cos(_rel*_bobF*1.2 + _h1*6)*_bobA*0.6;
            var _ft = (claim_t - _rel) / SF_TRAVEL;         // 0..1
            var _e  = ph_ease_in_cubic(_ft);               // ACCELERATE toward the target
            var _cxp = (_rx + _tx)/2 + (_rx - _cx0)*0.5;    // gentle arc control point …
            var _cyp = (_ry + _ty)/2 - 50;                  // … shallow bow toward the ★
            var _om = 1 - _e;
            var _x = _om*_om*_rx + 2*_om*_e*_cxp + _e*_e*_tx;
            var _y = _om*_om*_ry + 2*_om*_e*_cyp + _e*_e*_ty;
            var _sc = lerp(_rew_s*0.82, _hud_s, _e);
            draw_sprite_ext(global.spr_star3d, 0, _x, _y, _sc, _sc, 0, c_white, 1);
        } else if (claim_t < _arr + SF_FLASH) {
            // ── Arrival light effect: a quick additive glow that expands and fades. ─
            var _ff = (claim_t - _arr) / SF_FLASH;          // 0..1
            var _fs = _hud_s * (1 + 1.7*_ff);
            gpu_set_blendmode(bm_add);
            draw_sprite_ext(global.spr_star3d, 0, _tx, _ty, _fs, _fs, 0, c_white, (1-_ff)*0.85);
            gpu_set_blendmode(bm_normal);
        }
    }
  }
}

// ═══ Toast (reset feedback) ══════════════════════════════════════════════════
if (toast_timer > 0) {
    var _alpha = min(1, toast_timer/15);
    draw_set_alpha(_alpha);
    ph_draw_chip(PH_W/2-360, M.topbar_cy+200-44, PH_W/2+360, M.topbar_cy+200+44, 26,
                 toast_col, make_color_rgb(20,20,20), 5);
    ph_draw_text(PH_W/2, M.topbar_cy+200, toast_text, global.fnt_body_md, PH_COL_WHITE, fa_center, fa_middle);
    draw_set_alpha(1);
}
