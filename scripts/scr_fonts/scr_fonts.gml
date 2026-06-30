function ph_load_fonts() {
    if (os_browser != browser_not_a_browser) {
        // ── HTML5 fonts: use the built-in font (id -1). ───────────────────────
        // Two runtime-2026.0.0.23 dead-ends ruled out by testing (2026-06-25):
        //   • font_add(<path>.ttf,…) → Uncaught InvalidCharacterError: btoa
        //     outside Latin1 (base64s the raw font binary) → corrupts render,
        //     hub goes BLACK.
        //   • font_add("Lilita One"/"Nunito" by family name, Google-Fonts-loaded)
        //     → no crash, but glyphs bake BLANK (invisible text) — the web font
        //     isn't reliably ready when GM rasterizes, and re-rasterizing can't be
        //     gated from GML without a JS-bridge extension.
        // So the web build stays on the built-in font (small but VISIBLE). The
        // real fix for design-accurate web text is GameMaker FONT ASSETS (Add ▸
        // Font in the IDE for Lilita One + each Nunito size; baked into the
        // texture page at build, no runtime font_add / btoa / async) — then point
        // these globals at those assets. Native (iOS/Android/desktop) is unaffected
        // and keeps the real font_add path below.
        global.fnt_disp_xxl = -1;
        global.fnt_disp_xl  = -1;
        global.fnt_disp_xlg = -1;
        global.fnt_disp_lg  = -1;
        global.fnt_disp_md  = -1;
        global.fnt_disp_sm  = -1;
        global.fnt_disp_xs  = -1;

        global.fnt_body_reg  = -1;
        global.fnt_body_semi = -1;
        global.fnt_tip       = -1;
        global.fnt_btn       = -1;
        global.fnt_body_lg  = -1;
        global.fnt_body_md  = -1;
        global.fnt_body_sm  = -1;
        global.fnt_body_xs  = -1;
        global.fnt_num_md   = -1;
        global.fnt_num_reg  = -1;
        global.fnt_num_xl   = -1;
        global.fnt_pill_num = -1;
        return;
    }

    var _lilita = PH_ASSETS_PATH + "fonts/Lilita_One/";
    var _nunito = PH_ASSETS_PATH + "fonts/Nunito/static/";

    // Lilita One — display headings
    global.fnt_disp_xxl = font_add(_lilita+"LilitaOne-Regular.ttf", 156, false,false,32,127);
    global.fnt_disp_xl  = font_add(_lilita+"LilitaOne-Regular.ttf",  96, false,false,32,127);
    global.fnt_disp_xlg = font_add(_lilita+"LilitaOne-Regular.ttf",  73, false,false,32,127);
    global.fnt_disp_lg  = font_add(_lilita+"LilitaOne-Regular.ttf",  60, false,false,32,127);
    global.fnt_disp_md  = font_add(_lilita+"LilitaOne-Regular.ttf",  44, false,false,32,127);
    global.fnt_disp_sm  = font_add(_lilita+"LilitaOne-Regular.ttf",  32, false,false,32,127);
    global.fnt_disp_xs  = font_add(_lilita+"LilitaOne-Regular.ttf",  26, false,false,32,127);

    // Nunito — body text
    // Softer weights used for the win/lose/level-up flavour lines ("You solved
    // todays" / "Claim your reward") per the updated Penpot design (Nunito 400/600).
    global.fnt_body_reg  = font_add(_nunito+"Nunito-Regular.ttf",  60, false,false,32,127);
    global.fnt_body_semi = font_add(_nunito+"Nunito-SemiBold.ttf", 60, false,false,32,127);
    // Game-tip objective line — Nunito Regular, sized to the app canvas (the
    // Penpot design's 60px is on a ~1.4× frame, so ~44px is the faithful scale).
    global.fnt_tip       = font_add(_nunito+"Nunito-Regular.ttf",  44, false,false,32,127);
    // Button labels — Nunito Bold (700) per the design (reward + nav buttons).
    global.fnt_btn       = font_add(_nunito+"Nunito-Bold.ttf",     50, false,false,32,127);
    global.fnt_body_lg  = font_add(_nunito+"Nunito-ExtraBold.ttf", 44, false,false,32,127);
    global.fnt_body_md  = font_add(_nunito+"Nunito-ExtraBold.ttf", 36, false,false,32,127);
    global.fnt_body_sm  = font_add(_nunito+"Nunito-Bold.ttf",      28, false,false,32,127);
    global.fnt_body_xs  = font_add(_nunito+"Nunito-Bold.ttf",      22, false,false,32,127);
    global.fnt_num_md   = font_add(_nunito+"Nunito-Black.ttf",     40, false,false,32,127);
    // Lighter (non-bold) number — mission-tile reward amounts ("50 ⭐").
    global.fnt_num_reg  = font_add(_nunito+"Nunito-SemiBold.ttf",  48, false,false,32,127);
    // Big reward-amount number on the win / lose / level-up claim screens
    // ("100 ⭐" / "25 ⭐" / "100 🪙"). Penpot design uses a chunky Nunito ~150px on
    // the ~1.4× board, so ~96px is the faithful scale on the app canvas.
    global.fnt_num_xl   = font_add(_nunito+"Nunito-ExtraBold.ttf", 96, false,false,32,127);
    // CENTRAL non-bold pill font — used app-wide for every Level/Coin pill number
    // AND the tile PLAY buttons (Bora: these should read non-bold). Penpot spec =
    // Nunito SemiBold (600). Change the weight/size here once to restyle all pills.
    global.fnt_pill_num = font_add(_nunito+"Nunito-ExtraBold.ttf",  42, false,false,32,127);
}
