function ph_load_fonts() {
    var _lilita = working_directory + "fonts/Lilita_One/";
    var _nunito = working_directory + "fonts/Nunito/static/";

    // Lilita One — display headings
    global.fnt_disp_xxl = font_add(_lilita+"LilitaOne-Regular.ttf", 156, false,false,32,127);
    global.fnt_disp_xl  = font_add(_lilita+"LilitaOne-Regular.ttf",  96, false,false,32,127);
    global.fnt_disp_lg  = font_add(_lilita+"LilitaOne-Regular.ttf",  60, false,false,32,127);
    global.fnt_disp_md  = font_add(_lilita+"LilitaOne-Regular.ttf",  44, false,false,32,127);
    global.fnt_disp_sm  = font_add(_lilita+"LilitaOne-Regular.ttf",  32, false,false,32,127);
    global.fnt_disp_xs  = font_add(_lilita+"LilitaOne-Regular.ttf",  26, false,false,32,127);

    // Nunito — body text
    global.fnt_body_lg  = font_add(_nunito+"Nunito-ExtraBold.ttf", 44, false,false,32,127);
    global.fnt_body_md  = font_add(_nunito+"Nunito-ExtraBold.ttf", 36, false,false,32,127);
    global.fnt_body_sm  = font_add(_nunito+"Nunito-Bold.ttf",      28, false,false,32,127);
    global.fnt_body_xs  = font_add(_nunito+"Nunito-Bold.ttf",      22, false,false,32,127);
    global.fnt_num_md   = font_add(_nunito+"Nunito-Black.ttf",     40, false,false,32,127);
}
