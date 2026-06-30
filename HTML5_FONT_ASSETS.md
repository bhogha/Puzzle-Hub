# HTML5 Font Assets — creation checklist

Why: on the HTML5 runtime, runtime `font_add` is unusable (TTF path crashes with a
`btoa` error → black screen; by-family-name bakes blank/invisible glyphs). The fix is
**GameMaker Font assets** — glyphs baked into the texture page at build time. These work
on every platform with no async/btoa issues. Native (iOS/Android/desktop) keeps its
existing runtime `font_add` path; only the HTML5 branch of `ph_load_fonts` will point at
these assets.

## Step 0 — install the fonts on macOS (one time)
The GameMaker font editor builds from **installed** system fonts. Install from the TTFs
already in the project:
- `Puzzle Hub/datafiles/fonts/Lilita_One/LilitaOne-Regular.ttf`
- `Puzzle Hub/datafiles/fonts/Nunito/static/Nunito-Regular.ttf`
- `…/Nunito-SemiBold.ttf`, `…/Nunito-Bold.ttf`, `…/Nunito-ExtraBold.ttf`, `…/Nunito-Black.ttf`

Double-click each in Finder → **Install Font** (or add them in Font Book).

## Step 1 — create the Font assets in the IDE
Right-click the **Fonts** folder → **Create → Font**. For each row below: set the **Name**
exactly as listed, pick the **Font + Style**, set the **Size**, leave **Anti-aliasing on**,
and use the default character range (32–127 / ASCII).

Tip: create one, then **right-click → Duplicate** and just change the name + size for the
rest of the same family/style — much faster than 18 fresh creates.

### Lilita One — "Lilita One", Regular
| Asset name        | Size |
|-------------------|------|
| `fa_lilita_156`   | 156  |
| `fa_lilita_96`    | 96   |
| `fa_lilita_73`    | 73   |
| `fa_lilita_60`    | 60   |
| `fa_lilita_44`    | 44   |
| `fa_lilita_32`    | 32   |
| `fa_lilita_26`    | 26   |

### Nunito — "Nunito", with the listed style
| Asset name           | Style      | Size |
|----------------------|------------|------|
| `fa_nunito_reg_60`   | Regular    | 60   |
| `fa_nunito_reg_48`   | Regular    | 48   |
| `fa_nunito_reg_44`   | Regular    | 44   |
| `fa_nunito_semi_60`  | SemiBold   | 60   |
| `fa_nunito_bold_50`  | Bold       | 50   |
| `fa_nunito_bold_28`  | Bold       | 28   |
| `fa_nunito_bold_22`  | Bold       | 22   |
| `fa_nunito_xbold_96` | ExtraBold  | 96   |
| `fa_nunito_xbold_44` | ExtraBold  | 44   |
| `fa_nunito_xbold_36` | ExtraBold  | 36   |
| `fa_nunito_black_40` | Black      | 40   |

(18 assets total. If a weight isn't available as a separate style in the picker, choose the
closest installed weight — I can remap in code.)

## Step 2 — tell me when done
Once these exist (exact names matter), I'll wire `scr_fonts`' HTML5 branch to map each
`global.fnt_*` to the matching asset. Until then `scr_fonts` stays on the built-in font so
the project keeps compiling.

## Step 3 — build
Adding resources triggers the YYC link issue, so after wiring: **quit GameMaker → reopen →
YYC Clean rebuild** (clean rebuild, not just a run). Then check the web build text.

## Reference — which asset each global maps to
```
fnt_disp_xxl  → fa_lilita_156      fnt_body_reg  → fa_nunito_reg_60
fnt_disp_xl   → fa_lilita_96       fnt_body_semi → fa_nunito_semi_60
fnt_disp_xlg  → fa_lilita_73       fnt_tip       → fa_nunito_reg_44
fnt_disp_lg   → fa_lilita_60       fnt_btn       → fa_nunito_bold_50
fnt_disp_md   → fa_lilita_44       fnt_body_lg   → fa_nunito_xbold_44
fnt_disp_sm   → fa_lilita_32       fnt_body_md   → fa_nunito_xbold_36
fnt_disp_xs   → fa_lilita_26       fnt_body_sm   → fa_nunito_bold_28
                                   fnt_body_xs   → fa_nunito_bold_22
                                   fnt_num_md    → fa_nunito_black_40
                                   fnt_num_reg   → fa_nunito_reg_48
                                   fnt_num_xl    → fa_nunito_xbold_96
```
