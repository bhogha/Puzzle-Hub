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
