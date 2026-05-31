function ph_level_from_xp(_xp) {
    return floor(_xp / PH_XP_PER_LEVEL) + 1;
}

function ph_xp_in_level(_xp) {
    return _xp mod PH_XP_PER_LEVEL;
}

/// returns { levels_gained, coins_awarded, new_level }
function ph_grant_xp(_save, _amount) {
    var _old = ph_level_from_xp(_save.xp);
    _save.xp += _amount;
    var _new    = ph_level_from_xp(_save.xp);
    var _gained = _new - _old;
    var _coins  = _gained * PH_COINS_PER_LEVEL;
    _save.coins += _coins;
    return { levels_gained:_gained, coins_awarded:_coins, new_level:_new };
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
