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
