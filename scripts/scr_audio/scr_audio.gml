// scr_audio — central SFX manager for Puzzle Hub.
//
// One choke point for every feedback sound so volume, the mute toggle and a
// rapid-tap debounce all live in one place. Call ph_sfx(snd_*) from anywhere.
// Master volume + debounce window are #macros in scr_constants (never hardcode).
//
// The mute state is persisted in save.sfx_on (backfilled in ph_save_load,
// reset in ph_save_reset). All sounds are short OGG GMSound resources (snd_*).

/// Is SFX playback currently enabled? Defaults ON; safe before the save loads.
function ph_sfx_enabled() {
    if (!variable_global_exists("save") || !is_struct(global.save)) return true;
    return (global.save.sfx_on ?? true);
}

/// Turn SFX on/off and persist. Stops any in-flight sounds when muting.
function ph_sfx_set_enabled(_on) {
    if (variable_global_exists("save") && is_struct(global.save)) {
        global.save.sfx_on = _on;
        ph_save_write(global.save);
    }
    if (!_on) audio_stop_all();
}

/// Flip the mute state. Plays a confirmation blip when turning ON. Returns new state.
function ph_sfx_toggle() {
    var _on = !ph_sfx_enabled();
    ph_sfx_set_enabled(_on);
    if (_on) ph_sfx(snd_button, 0.9);
    return _on;
}

/// Play a feedback sound.
///   _snd     GMSound resource (snd_*)
///   _gain    per-call gain 0..1, layered on top of PH_SFX_MASTER_VOL (default 1)
///   _pitch   playback pitch multiplier (default 1; vary for subtle variation)
///   _min_gap if > 0, skip if the same sound played within this many ms (debounce)
/// Returns the sound instance id, or -1 if not played.
function ph_sfx(_snd, _gain = 1.0, _pitch = 1.0, _min_gap = 0) {
    if (!ph_sfx_enabled()) return -1;
    if (!audio_exists(_snd)) return -1;   // resource missing → no-op, never crash

    if (_min_gap > 0) {
        if (!variable_global_exists("ph_sfx_last")) global.ph_sfx_last = {};
        var _key  = string(_snd);
        var _now  = current_time;
        var _last = global.ph_sfx_last[$ _key] ?? -100000;
        if (_now - _last < _min_gap) return -1;
        global.ph_sfx_last[$ _key] = _now;
    }

    var _vol = clamp(PH_SFX_MASTER_VOL * _gain, 0, 1);
    return audio_play_sound(_snd, 1, false, _vol, 0, _pitch);
}
