// scr_haptics — central haptic-feedback manager for Puzzle Hub.
//
// One choke point for every tactile buzz, mirroring scr_audio: the on/off
// toggle, the platform guard and a rapid-fire debounce all live here, and the
// rest of the game calls the SEMANTIC helpers (ph_haptic_tap / _success / …)
// rather than the raw effect. Haptics fire ALONGSIDE the SFX (scr_audio) at the
// same hooks, so the two stay in lockstep.
//
// iOS ONLY for now (Taptic Engine via the native `Haptics` extension, UIKit
// feedback generators). Every entry point is guarded by os_type == os_ios, so
// other platforms compile and run unaffected — the helpers are cheap no-ops.
// To add Android later, add a parallel native module and branch here on
// os_android (mirrors the scr_notify plan).
//
// State is persisted in save.haptics_on (backfilled in ph_save_load, reset in
// ph_save_reset). The debounce window is PH_HAPTIC_MIN_GAP in scr_constants.

// ── Effect kinds (match the native Haptics extension) ────────────────────────
//   impact style:       0 light · 1 medium · 2 heavy · 3 soft · 4 rigid
//   notification type:  0 success · 1 warning · 2 error
//   selection:          single light "tick"

/// True on a platform where haptics are wired up (iOS only for now).
function ph_haptic_supported() {
    return (os_type == os_ios);
}

/// Is haptic feedback currently enabled? Off on unsupported platforms; otherwise
/// follows the player's preference (defaults ON). Safe before the save loads.
function ph_haptic_enabled() {
    if (!ph_haptic_supported()) return false;
    if (!variable_global_exists("save") || !is_struct(global.save)) return true;
    return (global.save.haptics_on ?? true);
}

/// Turn haptics on/off and persist.
function ph_haptic_set_enabled(_on) {
    if (variable_global_exists("save") && is_struct(global.save)) {
        global.save.haptics_on = _on;
        ph_save_write(global.save);
    }
}

/// Flip the haptics preference. Plays a confirmation tap when turning ON. Returns
/// the new state. (Reads the raw flag, not ph_haptic_enabled, so the toggle works
/// even when probed on a non-iOS build during testing.)
function ph_haptic_toggle() {
    var _cur = true;
    if (variable_global_exists("save") && is_struct(global.save)) _cur = (global.save.haptics_on ?? true);
    var _on = !_cur;
    ph_haptic_set_enabled(_on);
    if (_on) ph_haptic_tap();   // a confirming buzz, so ON is felt immediately
    return _on;
}

/// Pre-warm the Taptic Engine so the first real buzz has no latency. Cheap to
/// call on boot and on screen entry.
function ph_haptic_prepare() {
    if (!ph_haptic_supported()) return;
    haptic_prepare();
}

/// Low-level dispatch. Debounce is PER EFFECT (keyed by kind+arg), like scr_audio
/// debounces per sound — so a rich one-shot (success/error) is NEVER swallowed by
/// the universal tap that fired the same frame; only repeats of the SAME effect
/// (fast wheel ticks, coin streams, rapid taps) are throttled.
///   _kind     0 impact · 1 notification · 2 selection
///   _arg      style (impact) or type (notification); ignored for selection
///   _min_gap  ms to suppress a repeat of this same effect (0 = never throttle)
function ph_haptic__fire(_kind, _arg = 0, _min_gap = 0) {
    if (!ph_haptic_enabled()) return;
    if (_min_gap > 0) {
        if (!variable_global_exists("ph_haptic_last") || !is_struct(global.ph_haptic_last)) global.ph_haptic_last = {};
        var _key  = string(_kind) + ":" + string(_arg);
        var _now  = current_time;
        var _last = global.ph_haptic_last[$ _key] ?? -100000;
        if (_now - _last < _min_gap) return;
        global.ph_haptic_last[$ _key] = _now;
    }
    switch (_kind) {
        case 0: haptic_impact(_arg);       break;
        case 1: haptic_notification(_arg); break;
        case 2: haptic_selection();        break;
    }
}

// ── Semantic API (call these from gameplay) ──────────────────────────────────

/// Light tap — buttons, cards, keys, letters added/removed. _strength 0..2 maps
/// to light/medium/heavy for moments that want more weight. Debounced so the
/// universal per-tap call can't pile up on rapid taps.
function ph_haptic_tap(_strength = 0) { ph_haptic__fire(0, clamp(_strength, 0, 2), PH_HAPTIC_MIN_GAP); }

/// Crisp "typewriter" rap — Ladder / Wordle key presses. Falls back to medium on
/// iOS < 13 (handled natively).
function ph_haptic_type() { ph_haptic__fire(0, 4, PH_HAPTIC_MIN_GAP); }

/// Selection tick — spin-wheel slice crossing, drag-trace per cell, swaps.
function ph_haptic_select() { ph_haptic__fire(2, 0, PH_HAPTIC_MIN_GAP); }

/// Success notification — word/rung/flow/cell solved, valid placement, hint land.
function ph_haptic_success() { ph_haptic__fire(1, 0); }

/// Warning notification — soft "careful" cue (reserved; unused for now).
function ph_haptic_warning() { ph_haptic__fire(1, 1); }

/// Error notification — wrong guess, blocked move (+5 s), conflict, Wordle miss.
function ph_haptic_error() { ph_haptic__fire(1, 2); }

/// Heavy thud — a puzzle is solved (under the win celebration).
function ph_haptic_win() { ph_haptic__fire(0, 2); }

/// Success notification for the Level-Up reward moment.
function ph_haptic_levelup() { ph_haptic__fire(1, 0); }

/// Light tick for coins streaming into the wallet — spaced out so a fast stream
/// reads as a few ticks, not a continuous buzz.
function ph_haptic_coin() { ph_haptic__fire(0, 0, PH_HAPTIC_COIN_GAP); }
