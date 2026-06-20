// ── scr_tutorial — soft finger-pointer hint (no text, no dimming) ─────────────
//
// A minimal, reusable "soft guidance" primitive. Instead of an overlay tour with
// captions/steps/dots (which playtested as confusing — players tried to swipe
// between steps and felt they were "getting it wrong"), guidance is now just a
// gentle bobbing finger that fades in, points at a target, and fades out. There
// is NO dimming, NO caption, and NO input capture — the screen stays fully
// interactive so the player can explore freely.
//
// Used by the hub first-run hint (point at the first tile's PLAY after the tiles
// slide in), and intended for the planned per-puzzle first-play hints (point at
// the first move). The host owns *when* to show/aim/hide it; this just renders.
//
// The finger sprite (global.spr_finger ← datafiles/icons/finger.png) has its tip
// at the top of the art with a centred origin, so the engine offsets the draw
// back along the pointing direction to land the tip exactly on the target.
//
// ── API ───────────────────────────────────────────────────────────────────────
//   ph_finger_create()                → finger struct
//   ph_finger_point_at(f, x, y, ang)  — show & aim (tip at x,y; ang = rotation°,
//                                       0 = pointing straight up from below)
//   ph_finger_hide(f)                  — begin fading out
//   ph_finger_is_visible(f)            — bool (still drawing, incl. the fade-out)
//   ph_finger_tick(f)                  — once per Step: advance fade + bob
//   ph_finger_draw(f)                  — draw it (call late, above the UI)

function ph_finger_create() {
    var _f = {};
    _f.active = false;   // a target is set and the finger should be showing
    _f.x      = 0;
    _f.y      = 0;
    _f.ang    = 0;
    _f.fade   = 0;       // 0..1 current opacity (eased toward active)
    _f.bob    = 0;       // bob phase
    return _f;
}

function ph_finger_point_at(_f, _x, _y, _ang) {
    _f.active = true;
    _f.x   = _x;
    _f.y   = _y;
    _f.ang = _ang;
}

function ph_finger_hide(_f) { _f.active = false; }

function ph_finger_is_visible(_f) { return _f.active || _f.fade > 0.01; }

function ph_finger_tick(_f) {
    var _target = _f.active ? 1 : 0;
    if (_f.fade < _target) _f.fade = min(1, _f.fade + 0.10);
    else                   _f.fade = max(0, _f.fade - 0.12);
    _f.bob += 0.10;
}

function ph_finger_draw(_f) {
    if (_f.fade <= 0.01) return;
    if (!variable_global_exists("spr_finger")) return;

    var _ease = ph_ease_out(_f.fade);
    var _bobd = 16 * (0.5 + 0.5 * sin(_f.bob));       // 0..16 px gentle bob
    var _fsc  = 150 / sprite_get_width(global.spr_finger);   // ~150px finger

    // Offset the draw centre back along the pointing direction so the tip lands
    // on (x,y), then bob it outward a little. ang is the sprite rotation; the tip
    // points along it (ang 0 → tip up, hand below the target).
    var _rad  = degtorad(_f.ang - 90);
    var _half = sprite_get_height(global.spr_finger) * _fsc * 0.5;
    var _push = _half + _bobd;
    var _fcx  = _f.x - cos(_rad) * _push;
    var _fcy  = _f.y - sin(_rad) * _push;

    draw_sprite_ext(global.spr_finger, 0, _fcx, _fcy, _fsc, _fsc, _f.ang, c_white, _ease);
}

// ── Coach — scripted multi-step "how to play" finger gestures ─────────────────
//
// Builds on the soft finger above to teach a puzzle's FIRST move with no text:
// the finger plays a looping TAP or PRESS-SLIDE gesture, with a soft contact
// ripple on each press and a fading trail along a slide. Used for the per-puzzle
// first-play onboarding tips (Anygram slide-through-a-word, Sudoku tap-cell-then-
// number, …). The HOST controller owns the targets + step advancement:
//
//   c = ph_coach_create(accent)              — make a coach (accent colour for ripple/trail)
//   ph_coach_set_steps(c, [ ph_coach_tap(x,y) | ph_coach_slide(pts) , … ])
//                                            — install the step list & start (step 0)
//   ph_coach_active(c)                        — is a tip currently running?
//   ph_coach_next(c)                          — player satisfied the current step → advance
//                                              (slight fade gap, then next step). No-op on last.
//   ph_coach_stop(c)                          — desired first action done → fade the finger out
//   ph_coach_tick(c)                          — once per Step
//   ph_coach_draw(c)                          — draw late, above the board (below/above HUD as you like)
//
// A step LOOPS forever until the host advances or stops it. Quitting the room
// just drops the coach (host rebuilds it from step 0 next open) — half-finished
// progress is never persisted; only completing the action calls ph_tip_mark_seen.
//
// pts for a slide = array of ph_coach_pt(x,y) waypoints (the finger dwells briefly
// at each node — e.g. Anygram pauses on each letter).
//
// Tuning knobs (frame counts assume the 60 fps room; nudge if a beat feels off):
#macro PH_COACH_FINGER_PX     158   // on-screen finger height
#macro PH_COACH_FADE_IN       0.085 // opacity rise / step
#macro PH_COACH_FADE_OUT      0.12  // opacity fall / step
#macro PH_COACH_TAP_WINDUP    16    // tap beat 1: anticipation lift (up)
#macro PH_COACH_TAP_PRESS     12    // tap beat 2: accelerate down to contact
#macro PH_COACH_TAP_LIFT      18    // tap beat 3: ease back up (reaction)
#macro PH_COACH_TAP_HOLD      30    // pause before the tap loops
#macro PH_COACH_SLIDE_PRESS   16    // slide: press down at the first node
#macro PH_COACH_SLIDE_SEG     38    // slide: travel one segment (slow, readable)
#macro PH_COACH_SLIDE_DWELL   13    // slide: pause at each waypoint
#macro PH_COACH_SLIDE_LIFT    18    // slide: lift off at the last node
#macro PH_COACH_SLIDE_HOLD    34    // slide: pause before it loops
#macro PH_COACH_INTER_DELAY   26    // gap between steps once the player advances one
#macro PH_COACH_WINDUP_PX     22    // how far the tip rises during anticipation
#macro PH_COACH_DIP_PX        12    // how far the tip presses past the target (the "press")
#macro PH_COACH_RIPPLE_DUR    36    // contact-ripple lifetime (frames)
#macro PH_COACH_RIPPLE_R0     16    // ripple start radius
#macro PH_COACH_RIPPLE_R1     86    // ripple end radius
#macro PH_COACH_TRAIL_LIFE    14    // slide-trail dot lifetime (frames)
// Fingertip pixel location in the finger.png SOURCE art (the sprite origin is its
// centre, but the pointing tip sits up-left of centre) — used to land the tip
// exactly on the target. finger.png is 306×381, origin (153,190), tip ≈ (36,45).
#macro PH_COACH_TIP_AX        36
#macro PH_COACH_TIP_AY        45

function ph_coach_pt(_x, _y) { var _p = {}; _p.x = _x; _p.y = _y; return _p; }

function ph_coach_tap(_x, _y) {
    var _s = {}; _s.kind = "tap"; _s.pts = [ ph_coach_pt(_x, _y) ]; return _s;
}

function ph_coach_slide(_pts) {
    var _s = {}; _s.kind = "slide"; _s.pts = _pts; return _s;
}

function ph_coach_create(_accent) {
    var _c = {};
    _c.accent  = is_undefined(_accent) ? c_white : _accent;
    _c.steps   = [];
    _c.step    = 0;
    _c.active  = false;   // a tip is running
    _c.fade    = 0;       // overall finger opacity (0..1)
    _c.phase   = 0;       // beat within the current step
    _c.t       = 0;       // frames elapsed in the current beat
    _c.seg     = 0;       // current slide segment
    _c.inter   = 0;       // inter-step delay countdown
    _c.fx      = 0;       // current finger-tip x
    _c.fy      = 0;       // current finger-tip y
    _c.lift    = 0;       // vertical tip offset (− up / + press-down)
    _c.dip     = 0;       // 0..1 press amount (drives scale dip)
    _c.ripples = [];      // [{x,y,t}] contact rings
    _c.trail   = [];      // [{x,y,life}] slide trail
    return _c;
}

function ph_coach_set_steps(_c, _steps) {
    _c.steps  = _steps;
    _c.step   = 0;
    _c.phase  = 0;
    _c.t      = 0;
    _c.seg    = 0;
    _c.inter  = 0;
    _c.active = (array_length(_steps) > 0);
    _c.trail  = [];
}

function ph_coach_next(_c) {
    if (_c.step < array_length(_c.steps) - 1) {
        _c.step  += 1;
        _c.phase  = 0;
        _c.t      = 0;
        _c.seg    = 0;
        _c.inter  = PH_COACH_INTER_DELAY;   // brief fade-out/in gap between steps
        _c.trail  = [];
    }
}

function ph_coach_stop(_c)   { _c.active = false; }
function ph_coach_active(_c) { return _c.active; }

function ph_coach__ripple(_c, _x, _y) {
    var _r = {}; _r.x = _x; _r.y = _y; _r.t = 0; array_push(_c.ripples, _r);
}

function ph_coach__trail(_c, _x, _y) {
    var _p = {}; _p.x = _x; _p.y = _y; _p.life = PH_COACH_TRAIL_LIFE; array_push(_c.trail, _p);
}

function ph_coach_tick(_c) {
    // Age transient effects every frame (so they finish even after stop()).
    for (var _i = array_length(_c.ripples) - 1; _i >= 0; _i--) {
        _c.ripples[_i].t += 1;
        if (_c.ripples[_i].t >= PH_COACH_RIPPLE_DUR) array_delete(_c.ripples, _i, 1);
    }
    for (var _j = array_length(_c.trail) - 1; _j >= 0; _j--) {
        _c.trail[_j].life -= 1;
        if (_c.trail[_j].life <= 0) array_delete(_c.trail, _j, 1);
    }

    if (_c.inter > 0) _c.inter -= 1;

    // Finger is visible only while active AND not in an inter-step gap.
    var _want = (_c.active && _c.inter == 0) ? 1 : 0;
    if (_c.fade < _want) _c.fade = min(1, _c.fade + PH_COACH_FADE_IN);
    else                 _c.fade = max(0, _c.fade - PH_COACH_FADE_OUT);

    if (_want == 0 || _c.fade <= 0.001) return;
    if (array_length(_c.steps) == 0) return;

    var _st = _c.steps[_c.step];
    _c.t += 1;
    if (_st.kind == "tap") ph_coach__tick_tap(_c, _st);
    else                   ph_coach__tick_slide(_c, _st);
}

function ph_coach__tick_tap(_c, _st) {
    var _p = _st.pts[0];
    _c.fx = _p.x; _c.fy = _p.y;
    var _t = _c.t;
    switch (_c.phase) {
        case 0: { // wind-up: tip rises (anticipation)
            var _k = ph_ease_out(min(1, _t / PH_COACH_TAP_WINDUP));
            _c.lift = -PH_COACH_WINDUP_PX * _k;  _c.dip = 0;
            if (_t >= PH_COACH_TAP_WINDUP) { _c.phase = 1; _c.t = 0; }
        } break;
        case 1: { // press: accelerate down to (and a touch past) the target
            var _k = ph_ease_in_cubic(min(1, _t / PH_COACH_TAP_PRESS));
            _c.lift = lerp(-PH_COACH_WINDUP_PX, PH_COACH_DIP_PX, _k);  _c.dip = _k;
            if (_t >= PH_COACH_TAP_PRESS) { ph_coach__ripple(_c, _p.x, _p.y); _c.phase = 2; _c.t = 0; }
        } break;
        case 2: { // reaction: ease back up
            var _k = ph_ease_out(min(1, _t / PH_COACH_TAP_LIFT));
            _c.lift = lerp(PH_COACH_DIP_PX, 0, _k);  _c.dip = 1 - _k;
            if (_t >= PH_COACH_TAP_LIFT) { _c.phase = 3; _c.t = 0; }
        } break;
        default: { // hold, then loop
            _c.lift = 0; _c.dip = 0;
            if (_t >= PH_COACH_TAP_HOLD) { _c.phase = 0; _c.t = 0; }
        } break;
    }
}

function ph_coach__tick_slide(_c, _st) {
    var _pts = _st.pts;
    var _n = array_length(_pts);
    if (_n < 2) { ph_coach__tick_tap(_c, _st); return; }   // degenerate → behave as a tap
    var _t = _c.t;
    switch (_c.phase) {
        case 0: { // press down at the first node
            _c.fx = _pts[0].x; _c.fy = _pts[0].y;
            var _k = ph_ease_in_cubic(min(1, _t / PH_COACH_SLIDE_PRESS));
            _c.lift = lerp(-PH_COACH_WINDUP_PX, PH_COACH_DIP_PX, _k);  _c.dip = _k;
            if (_t >= PH_COACH_SLIDE_PRESS) {
                ph_coach__ripple(_c, _pts[0].x, _pts[0].y);
                _c.lift = 0; _c.dip = 1; _c.seg = 0; _c.phase = 1; _c.t = 0;
            }
        } break;
        case 1: { // travel the current segment (accel → decel)
            _c.dip = 1; _c.lift = 0;
            var _a = _pts[_c.seg], _b = _pts[_c.seg + 1];
            var _k = ph_ease_in_out(min(1, _t / PH_COACH_SLIDE_SEG));
            _c.fx = lerp(_a.x, _b.x, _k);  _c.fy = lerp(_a.y, _b.y, _k);
            ph_coach__trail(_c, _c.fx, _c.fy);
            if (_t >= PH_COACH_SLIDE_SEG) {
                // Arriving at the FINAL node → lift straight off (no dwell — a stop+
                // press at the destination reads as a stray tap). Intermediate nodes
                // get a brief dwell so a bent path's corners are legible.
                if (_c.seg + 1 >= _n - 1) { _c.phase = 3; _c.t = 0; }
                else                      { _c.phase = 2; _c.t = 0; }
            }
        } break;
        case 2: { // dwell at an INTERMEDIATE waypoint (pause on a corner), then continue
            var _b = _pts[_c.seg + 1];  _c.fx = _b.x; _c.fy = _b.y;  _c.dip = 1; _c.lift = 0;
            if (_t >= PH_COACH_SLIDE_DWELL) { _c.seg += 1; _c.phase = 1; _c.t = 0; }
        } break;
        case 3: { // lift off at the last node (continues smoothly from the slide; the
                  // finger is still gliding, so lift rises from 0 — no stationary press)
            var _last = _pts[_n - 1];  _c.fx = _last.x; _c.fy = _last.y;
            var _k = ph_ease_out(min(1, _t / PH_COACH_SLIDE_LIFT));
            _c.lift = lerp(0, -PH_COACH_WINDUP_PX, _k);  _c.dip = 1 - _k;
            if (_t >= PH_COACH_SLIDE_LIFT) { _c.phase = 4; _c.t = 0; }
        } break;
        default: { // brief hold (finger stays raised — no downward snap), then a
                   // fade-out gap so the restart press at node 0 doesn't read as a
                   // stray tap tacked onto the end of the slide.
            _c.dip = 0; _c.lift = -PH_COACH_WINDUP_PX;
            if (_t >= PH_COACH_SLIDE_HOLD) {
                _c.phase = 0; _c.t = 0; _c.seg = 0; _c.trail = [];
                _c.inter = PH_COACH_INTER_DELAY;
            }
        } break;
    }
}

function ph_coach_draw(_c) {
    if (!variable_global_exists("spr_finger")) return;
    var _ease = ph_ease_out(_c.fade);

    // Slide trail (soft additive accent dots under the finger).
    if (array_length(_c.trail) > 0) {
        gpu_set_blendmode(bm_add);
        draw_set_color(_c.accent);
        for (var _i = 0; _i < array_length(_c.trail); _i++) {
            var _p = _c.trail[_i];
            var _a = (_p.life / PH_COACH_TRAIL_LIFE);
            draw_set_alpha(_a * 0.30 * _ease);
            draw_circle(_p.x, _p.y, 12 + 10 * (1 - _a), false);
        }
        gpu_set_blendmode(bm_normal);
    }

    // Contact ripples (expanding additive rings at each press).
    if (array_length(_c.ripples) > 0) {
        gpu_set_blendmode(bm_add);
        draw_set_color(_c.accent);
        for (var _r = 0; _r < array_length(_c.ripples); _r++) {
            var _rp = _c.ripples[_r];
            var _rt = _rp.t / PH_COACH_RIPPLE_DUR;
            var _rr = lerp(PH_COACH_RIPPLE_R0, PH_COACH_RIPPLE_R1, ph_ease_out(_rt));
            var _ra = (1 - _rt) * 0.55;
            draw_set_alpha(_ra);
            // ~6px ring (three concentric outlines).
            draw_circle(_rp.x, _rp.y, _rr,     true);
            draw_circle(_rp.x, _rp.y, _rr - 3, true);
            draw_circle(_rp.x, _rp.y, _rr + 3, true);
        }
        gpu_set_blendmode(bm_normal);
    }
    draw_set_alpha(1);
    draw_set_color(c_white);

    if (_c.fade <= 0.01) return;

    // The finger: land the actual fingertip pixel exactly on (fx, fy + lift),
    // pointing straight up (hand below), scaled down slightly while pressed.
    // The sprite origin is its centre; the tip pixel (PH_COACH_TIP_AX/AY in source
    // art) sits up-left of centre, so offset the draw so that pixel maps to target.
    var _fsc = (PH_COACH_FINGER_PX / sprite_get_height(global.spr_finger)) * (1 - 0.10 * _c.dip);
    var _ox  = sprite_get_xoffset(global.spr_finger);
    var _oy  = sprite_get_yoffset(global.spr_finger);
    var _cx  = _c.fx           + (_ox - PH_COACH_TIP_AX) * _fsc;
    var _cy  = _c.fy + _c.lift + (_oy - PH_COACH_TIP_AY) * _fsc;
    draw_sprite_ext(global.spr_finger, 0, _cx, _cy, _fsc, _fsc, 0, c_white, _ease);
}
