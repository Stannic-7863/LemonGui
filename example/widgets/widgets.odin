package widgets

import "core:math/linalg"
import "core:unicode/utf8"
import "core:unicode/utf16"
import "core:strconv"
import "core:strings"
import "base:intrinsics"
import "base:runtime"
import "core:reflect"
import "core:fmt"
import "core:time"
import lui "../../"

Color_Palette :: struct {
    bg_elevated:   lui.Color `lui:"row,labels=rgba,min=0,max=255,color"`,
    bg_base:       lui.Color `lui:"row,labels=rgba,min=0,max=255,color"`,
    bg_sunken:     lui.Color `lui:"row,labels=rgba,min=0,max=255,color"`,
    fg_primary:    lui.Color `lui:"row,labels=rgba,min=0,max=255,color"`,
    fg_secondary:  lui.Color `lui:"row,labels=rgba,min=0,max=255,color"`,
    fg_muted:      lui.Color `lui:"row,labels=rgba,min=0,max=255,color"`,
    accent:        lui.Color `lui:"row,labels=rgba,min=0,max=255,color"`,
    accent_hover:  lui.Color `lui:"row,labels=rgba,min=0,max=255,color"`,
    accent_press:  lui.Color `lui:"row,labels=rgba,min=0,max=255,color"`,
    border_subtle: lui.Color `lui:"row,labels=rgba,min=0,max=255,color"`,
    border_strong: lui.Color `lui:"row,labels=rgba,min=0,max=255,color"`,
    danger:        lui.Color `lui:"row,labels=rgba,min=0,max=255,color"`,
    warning:       lui.Color `lui:"row,labels=rgba,min=0,max=255,color"`,
    success:       lui.Color `lui:"row,labels=rgba,min=0,max=255,color"`,
}

Spacing :: struct {
    xs: f32,
    sm: f32,
    md: f32,
    lg: f32,
    xl: f32,
}

Font_Info :: struct {
	font_size: f32,
	font_id:   int,
	font:      rawptr,
	font_name: string,
}

Font :: struct {
	f_xs: Font_Info,
	f_sm: Font_Info,
	f_md: Font_Info,
	f_lg: Font_Info,
	f_xl: Font_Info,
}

Interaction_State :: enum {
	Normal,
	Hover,
	Press,
}

Varient :: enum {
	Normal,
	Focused,
	Disabled,
}

Interaction_Style :: [Interaction_State]lui.Style_Index

Theme :: struct {
    palette: Color_Palette,
    spacing: Spacing,
    font:    Font,

    container: struct {
    	body:          Interaction_Style,
    	title:         Interaction_Style,
    	button:        Interaction_Style,
    	title_bar:     Interaction_Style,
    	scroll_track:  Interaction_Style,
    	scroll_thumb:  Interaction_Style,
    	inline_body:   Interaction_Style,
        inline_button: Interaction_Style,
        inline_title:  Interaction_Style,
        docked_text:      lui.Text_Index,
        resize_text:      lui.Text_Index,
        undocked_text:    lui.Text_Index,
     	collapsed_text:   lui.Text_Index,
      	uncollapsed_text: lui.Text_Index,
        scroll_thumb_width: f32,
    },

    button: struct {
    	style: Interaction_Style,
     	padding: [2]lui.Vec2f32,
    },

    slider: struct {
    	thumb:      Interaction_Style,
     	track:      Interaction_Style,
       	track_fill: Interaction_Style,
        thumb_size:   lui.Vec2f32,
      	track_height: f32,
    },

    checkbox: struct {
    	size:         lui.Vec2f32,
    	check_on:  	  Interaction_Style,
     	check_off:    Interaction_Style,
    },

    toggle: struct {
     	thumb:     Interaction_Style,
    	track_on:  Interaction_Style,
      	track_off: Interaction_Style,
        size: lui.Vec2f32,
    },

    radio: struct {
    	size: lui.Vec2f32,
    	item_toggle_on:  Interaction_Style,
     	item_toggle_off: Interaction_Style,
     },

    label: struct {
    	md: Interaction_Style,
     	sm: Interaction_Style,
    },

    progress_bar: struct {
   	    track:  Interaction_Style,
        fill:   Interaction_Style,
        track_height: f32
    },

    text_box: struct {
    	style: Interaction_Style,
    },

    tooltip: struct {
    	style: Interaction_Style,
    },

    dropdown: struct {
    	label:    Interaction_Style,
    	item_on:  Interaction_Style,
     	item_off: Interaction_Style,
      	body:     Interaction_Style,
    },

    spinbox: struct {
        dec:    Interaction_Style,
        inc:    Interaction_Style,
        input:  Interaction_Style,
        inc_text: lui.Text_Index,
        dec_text: lui.Text_Index,
    },

    drag: struct {
    	area_size:      lui.Vec2f32,
     	indicator_size: lui.Vec2f32,
     	area:      Interaction_Style,
      	indicator: Interaction_Style,
    },

    control_animation: lui.Animation_Index,
}

Container_State_Flag :: enum {
	Collapsed,
	Docked,
}

Container_State :: struct {
	flags: bit_set[Container_State_Flag],
	size:     lui.Vec2f32,
	position: lui.Vec2f32,
}

Container_Stack_Item :: struct {
	cont: lui.Widget_Info,
	conti: lui.Widget_Info
}

Dropdown_State :: struct {
	selected:  lui.Hash,
	counter:   int,
	is_active: bool,
}

Radio_State :: struct {
	selected: lui.Hash,
	counter: int,
}

State :: struct {
	dropdown_state:     map[lui.Hash]Dropdown_State,
	radio_state:        map[lui.Hash]Radio_State,
	container_state:    map[lui.Hash]Container_State,
	container_stack:    [dynamic]Container_Stack_Item,
	active_radio_state:    ^Radio_State,
	active_dropdown_state: ^Dropdown_State,
}

theme := Theme{}
state := State{}

Default_Palette :: enum {
	Kanagawa,
	Mono_Dark,
	Mono_Light,
	Gruvbox_Dark,
	Gruvbox_Light,
	Everforest_Dark,
	Everforest_Light,
	Everblush,
	Catppuccin_Dark,
	Catppuccin_Light,
	Tokyo_Night,
}

DEFAULT_SPACING :: Spacing {
    xs = 2,
    sm = 4,
    md = 8,
    lg = 16,
    xl = 24,
}

DEFAULT_PALETTES := [Default_Palette]Color_Palette {
    .Kanagawa = {
        bg_base       = { 31,  31,  40, 255 },
        bg_elevated   = { 39,  39,  48, 255 },
        bg_sunken     = { 37,  37,  46, 255 },

        fg_primary    = { 220, 215, 186, 255 },
        fg_secondary  = { 200, 195, 166, 255 },
        fg_muted      = {  76,  76,  85, 255 },

        accent        = { 122, 168, 159, 255 },
        accent_hover  = { 152, 187, 108, 255 },
        accent_press  = { 126, 156, 216, 255 },

        border_subtle = {  49,  49,  58, 255 },
        border_strong = {  76,  76,  85, 255 },

        danger        = { 216,  97, 107, 255 },
        warning       = { 220, 165,  97, 255 },
        success       = { 152, 187, 108, 255 },
    },

    .Mono_Dark = {
        bg_base       = {  18,  18,  18, 255 },
        bg_elevated   = {  30,  30,  30, 255 },
        bg_sunken     = {  24,  24,  24, 255 },

        fg_primary    = { 230, 230, 230, 255 },
        fg_secondary  = { 189, 189, 189, 255 },
        fg_muted      = { 122, 122, 122, 255 },

        accent        = { 154, 154, 154, 255 },
        accent_hover  = { 168, 168, 168, 255 },
        accent_press  = { 128, 128, 128, 255 },

        border_subtle = {  47,  47,  47, 255 },
        border_strong = { 122, 122, 122, 255 },

        danger        = { 208, 208, 208, 255 },
        warning       = { 181, 181, 181, 255 },
        success       = { 168, 168, 168, 255 },
    },

    .Mono_Light = {
        bg_base       = { 250, 250, 250, 255 },
        bg_elevated   = { 235, 235, 235, 255 },
        bg_sunken     = { 242, 242, 242, 255 },

        fg_primary    = {  26,  26,  26, 255 },
        fg_secondary  = {  68,  68,  68, 255 },
        fg_muted      = { 122, 122, 122, 255 },

        accent        = { 106, 106, 106, 255 },
        accent_hover  = {  74,  74,  74, 255 },
        accent_press  = { 138, 138, 138, 255 },

        border_subtle = { 207, 207, 207, 255 },
        border_strong = { 122, 122, 122, 255 },

        danger        = {  42,  42,  42, 255 },
        warning       = {  90,  90,  90, 255 },
        success       = { 106, 106, 106, 255 },
    },

   .Gruvbox_Dark = {
    	bg_base       = {  29,  32,  33, 255 },
    	bg_elevated   = {  50,  48,  47, 255 },
    	bg_sunken     = {  40,  40,  40, 255 },

    	fg_primary    = { 235, 219, 178, 255 },
    	fg_secondary  = { 213, 196, 161, 255 },
    	fg_muted      = { 146, 131, 116, 255 },

    	accent        = { 131, 165, 152, 255 },
    	accent_hover  = { 184, 187,  38, 255 },
    	accent_press  = { 131, 165, 152, 255 },

    	border_subtle = {  60,  56,  54, 255 },
    	border_strong = { 102,  92,  84, 255 },

    	danger        = { 251,  73,  52, 255 },
    	warning       = { 250, 189,  47, 255 },
    	success       = { 184, 187,  38, 255 },
   	},

    .Gruvbox_Light = {
        bg_base       = { 242, 229, 188, 255 },
        bg_elevated   = { 229, 216, 175, 255 },
        bg_sunken     = { 227, 214, 173, 255 },

        fg_primary    = {  80,  73,  69, 255 },
        fg_secondary  = { 102,  92,  84, 255 },
        fg_muted      = { 162, 149, 108, 255 },

        accent        = {  66, 123,  88, 255 },
        accent_hover  = { 121, 116,  14, 255 },
        accent_press  = {  69, 133, 136, 255 },

        border_subtle = { 160, 149, 108, 255 },
        border_strong = { 102,  92,  84, 255 },

        danger        = { 157,   0,   6, 255 },
        warning       = { 215, 153,  33, 255 },
        success       = { 121, 116,  14, 255 },
    },

    .Everforest_Dark = {
        bg_base       = {  35,  42,  46, 255 },
        bg_elevated   = {  52,  63,  68, 255 },
        bg_sunken     = {  45,  53,  59, 255 },

        fg_primary    = { 211, 198, 170, 255 },
        fg_secondary  = { 133, 146, 137, 255 },
        fg_muted      = { 122, 132, 120, 255 },

        accent        = { 167, 192, 128, 255 },
        accent_hover  = { 127, 187, 179, 255 },
        accent_press  = { 214, 153, 182, 255 },

        border_subtle = {  79,  88,  94, 255 },
        border_strong = { 133, 146, 137, 255 },

        danger        = { 230, 126, 128, 255 },
        warning       = { 219, 188, 127, 255 },
        success       = { 167, 192, 128, 255 },
    },

    .Everforest_Light = {
        bg_base       = { 239, 235, 212, 255 },
        bg_elevated   = { 244, 240, 217, 255 },
        bg_sunken     = { 253, 246, 227, 255 },

        fg_primary    = {  76,  86,  92, 255 },
        fg_secondary  = { 110, 122, 118, 255 },
        fg_muted      = { 140, 148, 138, 255 },

        accent        = { 114, 138,   0, 255 },
        accent_hover  = {  42, 145, 104, 255 },
        accent_press  = {  46, 120, 168, 255 },

        border_subtle = { 191, 184, 158, 255 },
        border_strong = { 140, 148, 138, 255 },

        danger        = { 214,  69,  65, 255 },
        warning       = { 191, 136,   0, 255 },
        success       = { 114, 138,   0, 255 },
    },

    .Everblush = {
        bg_base       = {  20,  27,  30, 255 },
        bg_elevated   = {  35,  42,  45, 255 },
        bg_sunken     = {  16,  22,  24, 255 },

        fg_primary    = { 218, 218, 218, 255 },
        fg_secondary  = { 179, 185, 184, 255 },
        fg_muted      = { 107, 111, 114, 255 },

        accent        = { 108, 191, 191, 255 },
        accent_hover  = { 103, 176, 232, 255 },
        accent_press  = { 196, 127, 213, 255 },

        border_subtle = {  48,  56,  59, 255 },
        border_strong = { 107, 111, 114, 255 },

        danger        = { 229, 116, 116, 255 },
        warning       = { 229, 199, 107, 255 },
        success       = { 140, 207, 126, 255 },
    },

    .Catppuccin_Dark = {
        bg_base       = {  30,  30,  46, 255 },
        bg_elevated   = {  36,  39,  58, 255 },
        bg_sunken     = {  24,  24,  37, 255 },

        fg_primary    = { 205, 214, 244, 255 },
        fg_secondary  = { 186, 194, 222, 255 },
        fg_muted      = { 108, 112, 134, 255 },

        accent        = { 148, 226, 213, 255 },
        accent_hover  = { 137, 180, 250, 255 },
        accent_press  = { 203, 166, 247, 255 },

        border_subtle = {  59,  63,  90, 255 },
        border_strong = { 108, 112, 134, 255 },

        danger        = { 243, 139, 168, 255 },
        warning       = { 249, 226, 175, 255 },
        success       = { 166, 227, 161, 255 },
    },

    .Catppuccin_Light = {
        bg_base       = { 239, 241, 245, 255 },
        bg_elevated   = { 226, 230, 238, 255 },
        bg_sunken     = { 233, 236, 242, 255 },

        fg_primary    = {  76,  79, 105, 255 },
        fg_secondary  = {  92,  95, 119, 255 },
        fg_muted      = { 156, 160, 176, 255 },

        accent        = {  23, 146, 153, 255 },
        accent_hover  = {  30, 102, 245, 255 },
        accent_press  = { 136,  57, 239, 255 },

        border_subtle = { 191, 198, 212, 255 },
        border_strong = { 156, 160, 176, 255 },

        danger        = { 210,  15,  57, 255 },
        warning       = { 223, 142,  29, 255 },
        success       = {  64, 160,  43, 255 },
    },

    .Tokyo_Night = {
        bg_base       = {  36,  40,  59, 255 },
        bg_elevated   = {  41,  46,  66, 255 },
        bg_sunken     = {  31,  35,  53, 255 },

        fg_primary    = { 192, 202, 245, 255 },
        fg_secondary  = { 169, 177, 214, 255 },
        fg_muted      = {  86,  95, 137, 255 },

        accent        = { 115, 218, 202, 255 },
        accent_hover  = { 122, 162, 247, 255 },
        accent_press  = { 187, 154, 247, 255 },

        border_subtle = {  65,  72, 104, 255 },
        border_strong = {  86,  95, 137, 255 },

        danger        = { 247, 118, 142, 255 },
        warning       = { 224, 175, 104, 255 },
        success       = { 158, 206, 106, 255 },
    },
}

build_theme :: proc(ctx: ^lui.Core_Context, palette: Color_Palette, spacing: Spacing, font: Font) {

	make_text_style :: proc(color: lui.Color, font: Font_Info) -> lui.Text_Style {
    	return {
        	color = color,
        	font = font.font,
        	font_id = font.font_id,
        	font_name = font.font_name,
        	font_size = font.font_size,
    	}
	}

	theme.font = font
	theme.palette = palette
	theme.spacing = spacing

    p := &theme.palette
    s := &theme.spacing
    f := &theme.font

    accent := lui.create_style(ctx, {
        color  = p.accent,
        border = {color = p.accent, thickness = 1, radius = 6},
        text   = {color = p.bg_sunken, font = f.f_md.font, font_id = f.f_md.font_id, font_name = f.f_md.font_name, font_size = f.f_md.font_size},
    })

    accent_hover := lui.create_style(ctx, {
        color  = p.accent_hover,
        border = {color = p.accent_hover, thickness = 1, radius = 6},
        text   = make_text_style(p.bg_sunken, f.f_md),
    })

    accent_press := lui.create_style(ctx, {
        color  = p.accent_press,
        border = {color = p.accent_press, thickness = 1, radius = 6},
        text   = make_text_style(p.bg_sunken, f.f_md),
    })

    text_md := lui.create_style(ctx, {color = 0, text = make_text_style(p.fg_primary, f.f_md)})
    text_sm := lui.create_style(ctx, {color = 0, text = make_text_style(p.fg_secondary, f.f_sm)})

    track := lui.create_style(ctx, {color  = p.bg_sunken, border = {color = p.border_subtle, thickness = 1, radius = 999}})
    track_fill := lui.create_style(ctx, {color  = p.accent, border = {color = p.border_subtle, thickness = 1, radius = 999}})

    thumb := lui.create_style(ctx, {color  = p.bg_base, border = {color = p.border_strong, thickness = 1, radius = 999}})
    thumb_h := lui.create_style(ctx, {color = p.bg_elevated, border = {color = p.border_strong, thickness = 1, radius = 999}})
    thumb_p := lui.create_style(ctx, {color = p.accent, border = {color = p.border_strong, thickness = 1, radius = 999}})

    text_box := lui.create_style(ctx, {
        color  = p.bg_sunken,
        border = {color = p.border_subtle, thickness = 1, radius = 6},
        text = make_text_style(p.fg_primary, f.f_md)
    })

    tooltip := lui.create_style(ctx, {
        color  = p.bg_base,
        border = {color = p.border_subtle, thickness = 1, radius = 6},
        text   = make_text_style(p.fg_primary, f.f_sm),
    })

    si :: proc(normal, hover, press: lui.Style_Index) -> Interaction_Style {
        return {.Normal = normal, .Hover = hover, .Press = press}
    }

    {
	    body := lui.create_style(ctx, {color = p.bg_base, border = {color = p.border_subtle, thickness = {2, {0, 2}}, radius = {0, 0, 6, 6}}})
	   	title_bar := lui.create_style(ctx, {color = p.bg_elevated, border = {color = p.border_subtle, thickness = {2, {2, 0}}, radius = {6, 6, 0, 0}}})
	    title := lui.create_style(ctx, {text = make_text_style(p.fg_primary, f.f_md)})
	   	button := lui.create_style(ctx, {color = p.bg_elevated, border = {radius = 6}, text = make_text_style(p.fg_primary, f.f_md)})
	    button_h := lui.create_style(ctx, {color = p.accent_hover, border = {radius = 6}, text = make_text_style(p.bg_elevated, f.f_md)})
	    button_p := lui.create_style(ctx, {color = p.accent_press, border = {radius = 6}, text = make_text_style(p.bg_elevated, f.f_md)})

	    inline_button := lui.create_style(ctx, {color = p.bg_base, border = {radius = 4}, text = make_text_style(p.fg_primary, f.f_md)})
	    inline_button_h := lui.create_style(ctx, {color = p.bg_elevated, border = {radius = 4}, text = make_text_style(p.fg_primary, f.f_md)})
		inline_button_p := lui.create_style(ctx, {color = p.accent, border = {radius = 4}, text = make_text_style(p.bg_base, f.f_md)})

	    inline_body := lui.create_style(ctx, {color = p.bg_base, border = {color = p.border_strong, thickness = {{2, 0}, {0, 0}}}})

		scroll_track := lui.create_style(ctx, {color = p.bg_base, border = {color = p.border_subtle, thickness = {{1, 0}, 0}}})
		scroll_thumb := lui.create_style(ctx, {color = p.accent, border = {radius = 999}})

	   	theme.container.body = si(body, body, body)
	   	theme.container.title = si(title, title, title)
	   	theme.container.button = si(button, button_h, button_p)
	   	theme.container.title_bar = si(title_bar, title_bar, title_bar)
		theme.container.scroll_track = si(scroll_track, scroll_track, scroll_track)
		theme.container.scroll_thumb = si(scroll_thumb, scroll_thumb, scroll_thumb)

		theme.container.inline_title = si(title, title, title)
		theme.container.inline_button = si(inline_button, inline_button_h, inline_button_p)
		theme.container.inline_body = si(inline_body, inline_body, inline_body)

	   	theme.container.collapsed_text   = lui.create_text(ctx, lui.text("▶", .None))
	   	theme.container.uncollapsed_text = lui.create_text(ctx, lui.text("▼", .None))
	   	theme.container.docked_text      = lui.create_text(ctx, lui.text("■", .None))
	   	theme.container.undocked_text    = lui.create_text(ctx, lui.text("□", .None))
	   	theme.container.resize_text      = lui.create_text(ctx, lui.text("󰑝", .None))
		theme.container.scroll_thumb_width = 4
    }

    {
        inc_n := lui.create_style(ctx, {color = p.bg_elevated, border = {color = p.border_subtle, radius = {0, 4, 4, 0}, thickness = 1}, text = make_text_style(p.fg_primary, f.f_md)})
	    inc_h := lui.create_style(ctx, {color = p.accent_hover, border = {radius = {0, 4, 4, 0}}, text = make_text_style(p.bg_elevated, f.f_md)})
	    inc_p := lui.create_style(ctx, {color = p.accent_press, border = {radius = {0, 4, 4, 0}}, text = make_text_style(p.bg_elevated, f.f_md)})

        dec_n := lui.create_style(ctx, {color = p.bg_elevated, border = {color = p.border_subtle, radius = {4, 0, 0, 4}, thickness = 1}, text = make_text_style(p.fg_primary, f.f_md)})
	    dec_h := lui.create_style(ctx, {color = p.accent_hover, border = {radius = {4, 0, 0, 4}}, text = make_text_style(p.bg_elevated, f.f_md)})
	    dec_p := lui.create_style(ctx, {color = p.accent_press, border = {radius = {4, 0, 0, 4}}, text = make_text_style(p.bg_elevated, f.f_md)})

        theme.spinbox.inc = si(inc_n, inc_h, inc_p)
        theme.spinbox.dec = si(dec_n, dec_h, dec_p)
        theme.spinbox.input = si(text_box, text_box, text_box)

        theme.spinbox.inc_text = lui.create_text(ctx, lui.text(">", .None))
        theme.spinbox.dec_text = lui.create_text(ctx, lui.text("<", .None))
    }

    theme.button.style = si(accent, accent_hover, accent_press)

    theme.slider.thumb = si(thumb, thumb_h, thumb_p)
    theme.slider.track = si(track, track, track)
    theme.slider.track_fill = si(track_fill, track_fill, track_fill)
    theme.slider.thumb_size = {14, 18}
    theme.slider.track_height = 8

    theme.checkbox.size = {18, 18}
    theme.checkbox.check_off = si(thumb, thumb_h, thumb_p)
    theme.checkbox.check_on = si(thumb_p, thumb_p, thumb_p)

    theme.toggle.track_off = si(track, track, track)
    theme.toggle.track_on = si(track_fill, track_fill, track_fill)
    theme.toggle.thumb = si(thumb, thumb_h, thumb_p)
    theme.toggle.size = {18, 18}

    theme.radio.size = {18, 18}
    theme.radio.item_toggle_on = si(thumb_p, thumb_p, thumb_p)
    theme.radio.item_toggle_off = si(thumb, thumb_h, thumb_p)

    {
        dropdown_label := lui.create_style(ctx, {color = p.bg_base, border = {color = p.border_subtle, thickness = 1, radius = 6}, text = make_text_style(p.fg_primary, f.f_md)})
        dropdown_label_h := lui.create_style(ctx, {color = p.bg_elevated, border = {color = p.border_subtle, thickness = 1, radius = 6}, text = make_text_style(p.fg_primary, f.f_md)})
        dropdown_body := lui.create_style(ctx, {color = p.bg_base, border = {color = p.border_subtle, thickness = 1, radius = 6}})
        dropdown_item := lui.create_style(ctx, {color = p.bg_base, border = {color = p.border_subtle, thickness = 1}, text = make_text_style(p.fg_primary, f.f_md)})
        dropdown_item_h := lui.create_style(ctx, {color = p.bg_elevated, border = {color = p.border_subtle, thickness = 1}, text = make_text_style(p.fg_primary, f.f_md)})
        dropdown_item_p := lui.create_style(ctx, {color = p.accent, border = {color = p.border_subtle, thickness = 1}, text = make_text_style(p.bg_base, f.f_md)})

	    theme.dropdown.label = si(dropdown_label, dropdown_label_h, dropdown_label_h)
	    theme.dropdown.body = si(dropdown_body, dropdown_body, dropdown_body)
	    theme.dropdown.item_on = si(dropdown_item_p, dropdown_item_p, dropdown_item_p)
	    theme.dropdown.item_off = si(dropdown_item, dropdown_item_h, dropdown_item_p)
    }

    {
    	drag_area_n := lui.create_style(ctx, {color = p.bg_elevated, border = {color = p.border_subtle, thickness = 1}})
     	drag_area_p := lui.create_style(ctx, {color = p.accent_press, border = {color = p.border_subtle, thickness = 1}})
      	drag_indicator := lui.create_style(ctx, {color = p.success})

      	theme.drag.area = si(drag_area_n, drag_area_n, drag_area_p)
     	theme.drag.indicator = si(drag_indicator, drag_indicator, drag_indicator)
      	theme.drag.indicator_size = {4, 4}
     	theme.drag.area_size = {48, 48}
    }

    theme.label.md = si(text_md, text_md, text_md)
    theme.label.sm = si(text_sm, text_sm, text_sm)

    theme.progress_bar.track = si(track, track, track)
    theme.progress_bar.fill = si(track_fill, track_fill, track_fill)
    theme.progress_bar.track_height = 8

    theme.text_box.style = si(text_box, text_box, text_box)
    theme.tooltip.style = si(tooltip, tooltip, tooltip)

    anim := lui.ANIM_COLOR
    anim.on_destroyed = proc(info: lui.Widget_Info, style: lui.Style, text_position: lui.Vec2f32) -> (end: lui.Animation_Data) {
        return {}
    }

    theme.control_animation = lui.create_animation(ctx, anim, duration = time.Millisecond * 1)
}

init_state :: proc(allocator := context.allocator) {
	state.container_stack = make([dynamic]Container_Stack_Item, allocator)
	state.container_state = make(map[lui.Hash]Container_State, allocator)
	state.dropdown_state = make(map[lui.Hash]Dropdown_State, allocator)
	state.radio_state = make(map[lui.Hash]Radio_State, allocator)
}

deinit_state :: proc() {
	delete(state.container_stack)
	delete(state.container_state)
	delete(state.dropdown_state)
	delete(state.radio_state)
}

resolve_style :: proc(ctx: ^lui.Core_Context, info: lui.Widget_Info, style: Interaction_Style) -> lui.Style_Index {
	if lui.is_widget_active(ctx, info) { return style[.Press]}
    if lui.is_widget_hovered(ctx, info)  { return style[.Hover]}
    return style[.Normal]
}

container :: proc(ctx: ^lui.Core_Context, key: lui.Key, title_label: string) -> bool {
	cont := lui.reserve_widget(ctx, key)
	cont_state, ok := &state.container_state[cont.hash]

	if !ok {
		state.container_state[cont.hash] = {flags = {.Docked}, size = {256 * 3, 256 * 2}}
		cont_state = &state.container_state[cont.hash]
	}

	contf := lui.Form{}
	contf.layout.sizing = {lui.fit(cont_state.size.x), lui.fit(cont_state.size.y)} if .Collapsed not_in cont_state.flags else {lui.fit(), lui.fit()}
	contf.layout.direction = .Y

	if .Docked not_in cont_state.flags {
		if cont_state.position.x == 0 { cont_state.position.x = cont.rect.position.x }
		if cont_state.position.y == 0 { cont_state.position.y = cont.rect.position.y }
		contf.layout.flags = {{.No_Positioning_Relative, .No_Size_Propagation}, {.No_Positioning_Relative, .No_Size_Propagation}}
		contf.override = lui.create_override(ctx, {offset = {lui.fixed(cont_state.position.x), lui.fixed(cont_state.position.y)}})
	}

	lui.submit_widget(ctx, cont, contf)

	lui.push_parent(ctx, cont)

	cont_bar := lui.reserve_widget(ctx, "__internal_cont_bar")

	cont_bar_events := lui.get_widget_mouse_events(ctx, cont_bar, .Left)
	if .Down in cont_bar_events && .Docked not_in cont_state.flags {
		cont_state.position += ctx.mouse.delta
	}

	cont_barf := lui.Form{}
	cont_barf.layout.sizing = {lui.grow(), lui.fit()}
	cont_barf.event_flags = {.Lock_Active, .Lock_Hover}
	cont_barf.layout.padding = {2, 2}
	cont_barf.style = resolve_style(ctx, cont_bar, theme.container.title_bar)
	lui.submit_widget(ctx, cont_bar, cont_barf)

	lui.push_parent(ctx, cont_bar)

	{
		cont_collapse := lui.reserve_widget(ctx, "__internal_cont_collapse")
		cont_collapse_event := lui.get_widget_mouse_events(ctx, cont_collapse, .Left)
		if .Clicked in cont_collapse_event { cont_state.flags ~= {.Collapsed} }
		cont_collapsef := lui.Form{}
		cont_collapsef.layout.sizing = {lui.fit(), lui.fit()}
		cont_collapsef.layout.padding = {theme.spacing.sm, 0}
		cont_collapsef.text = theme.container.collapsed_text if .Collapsed in cont_state.flags else theme.container.uncollapsed_text
		cont_collapsef.animation = theme.control_animation
		cont_collapsef.style = resolve_style(ctx, cont_collapse, theme.container.button)
		lui.submit_widget(ctx, cont_collapse, cont_collapsef)
		lui.push_parent(ctx, cont_collapse)
		tooltip(ctx, "__internal_cont_collapse_tooltip", cont_collapse, "Collapse/Uncollapse Container")
		lui.pop_parent(ctx)
	}

	{
		cont_dock := lui.reserve_widget(ctx, "__internal_cont_undock")
		cont_dock_event := lui.get_widget_mouse_events(ctx, cont_dock, .Left)
		if .Clicked in cont_dock_event { cont_state.flags ~= {.Docked} }
		cont_dockf := lui.Form{}
		cont_dockf.layout.sizing = {lui.fit(), lui.fit()}
		cont_dockf.layout.padding = {theme.spacing.sm, 0}
		cont_dockf.text = theme.container.docked_text if .Docked in cont_state.flags else theme.container.undocked_text
		cont_dockf.style = resolve_style(ctx, cont_dock, theme.container.button)
		cont_dockf.animation = theme.control_animation
		lui.submit_widget(ctx, cont_dock, cont_dockf)
		lui.push_parent(ctx, cont_dock)
		tooltip(ctx, "__internal_cont_dock_tooltip", cont_dock, "Dock/Undock Container")
		lui.pop_parent(ctx)
	}

	labelw := lui.reserve_widget(ctx, "__internal_cont_title_label")
	labelf := lui.Form{}
	labelf.layout.sizing = lui.sizing()
	labelf.text = lui.create_text(ctx, lui.text(title_label, .None))
	labelf.style = resolve_style(ctx, labelw, theme.container.title)
	lui.submit_widget(ctx, labelw, labelf)

	lui.pop_parent(ctx)

	if .Collapsed in cont_state.flags {
		lui.pop_parent(ctx)
		return false
	}

	conti := lui.reserve_widget(ctx, "__internal_cont_content_holder")
	contif := lui.Form{}
	contif.layout.sizing = {lui.grow(), lui.grow()}
	contif.layout.padding = theme.spacing.md
	contif.layout.direction = .Y
	contif.layout.child_gap = theme.spacing.md
	contif.clip = lui.create_clip(ctx, lui.clip({}, lui.clip_auto(20, -max(conti.rect.content_size.y - conti.rect.size.y, 0), 0), conti.hash))
	contif.style = resolve_style(ctx, conti, theme.container.body)
	lui.submit_widget(ctx, conti, contif)
	lui.push_parent(ctx, conti)

	append(&state.container_stack, Container_Stack_Item{cont = cont, conti = conti})

	return true
}

end_container :: proc(ctx: ^lui.Core_Context) {
	cont_stack_item := pop(&state.container_stack)
	cont := cont_stack_item.cont
	conti := cont_stack_item.conti
	cont_state := &state.container_state[cont.hash]

	if conti.rect.content_size.y > conti.rect.size.y {
		scroll_track := lui.reserve_widget(ctx, "__internal_cont_scroll_track")
		scroll_trackf := lui.Form{}
		scroll_trackf.layout.sizing = {lui.fit(), lui.percent(1)}
		scroll_trackf.layout.flags = {{.No_Size_Propagation, .No_Positioning_Relative, .No_Clip_Offset}, {.No_Size_Propagation, .No_Positioning_Relative, .No_Clip_Offset}}
		scroll_trackf.override = lui.create_override(ctx, {offset = {lui.percent(1), lui.percent(0)}}, {offset = {lui.percent_self(-1), lui.percent(0)}})
		scroll_trackf.style = resolve_style(ctx, scroll_track, theme.container.scroll_track)
		lui.submit_widget(ctx, scroll_track, scroll_trackf)

		lui.push_parent(ctx, scroll_track)
		scroll_thumb := lui.reserve_widget(ctx, "__internal_cont_scroll_thumb")
		scroll_thumbf := lui.Form{}
		scroll_thumbf.layout.sizing = {lui.fixed(theme.container.scroll_thumb_width), lui.percent(conti.rect.size.y / conti.rect.content_size.y)}
		scroll_thumbf.override = lui.create_override(ctx, {offset = {{}, lui.percent(-conti.rect.clip_offset.y / conti.rect.content_size.y)}})
		scroll_thumbf.style = resolve_style(ctx, scroll_thumb, theme.container.scroll_thumb)
		lui.submit_widget(ctx, scroll_thumb, scroll_thumbf)
		lui.pop_parent(ctx)
	}

	resizew := lui.reserve_widget(ctx, "__internal_cont_resize")
	resizew_events := lui.get_widget_mouse_events(ctx, resizew, .Left)
	if .Down in resizew_events {
		cont_state.size += ctx.mouse.delta
	} else {
		cont_state.size.x = max(cont_state.size.x, cont.rect.size.x)
	 	cont_state.size.y = max(cont_state.size.y, cont.rect.size.y)
	}

	resizewf := lui.Form{}
	resizewf.layout.sizing = {lui.fit(), lui.fit()}
	resizewf.layout.padding.x = theme.spacing.sm
	resizewf.layout.flags = {{.No_Size_Propagation, .No_Positioning_Relative}, {.No_Size_Propagation, .No_Positioning_Relative, .No_Clip_Offset}}
	resizewf.event_flags = {.Lock_Hover, .Lock_Active}
	resizewf.override = lui.create_override(ctx, {offset = {lui.percent(1), lui.percent(1)}}, {offset = {lui.percent_self(-1), lui.percent_self(-1)}})
	resizewf.text = theme.container.resize_text
	resizewf.style = resolve_style(ctx, resizew, theme.container.button)
	lui.submit_widget(ctx, resizew, resizewf)

	lui.push_parent(ctx, resizew)
	tooltip(ctx, "__internal_cont_resize_tooltip", resizew, "Resize Container")
	lui.pop_parent(ctx)

	lui.pop_parent(ctx)
	lui.pop_parent(ctx)
}

inline_container :: proc(ctx: ^lui.Core_Context, key: lui.Key, title_label: string) -> bool {
	cont := lui.reserve_widget(ctx, key)

	cont_state, ok := &state.container_state[cont.hash]
	if !ok {
		state.container_state[cont.hash] = {}
		cont_state = &state.container_state[cont.hash]
	}

	contf := lui.Form{}
	contf.layout.sizing = {lui.grow(), lui.fit()}
	contf.layout.direction = .Y
	lui.submit_widget(ctx, cont, contf)

	lui.push_parent(ctx, cont)

	bar := lui.reserve_widget(ctx, "__internal_inline_cont_title_bar")
	barf := lui.Form{}
	barf.layout.sizing = {lui.grow(), lui.fit()}
	lui.submit_widget(ctx, bar, barf)

	lui.push_parent(ctx, bar)

	collapse := lui.reserve_widget(ctx, "__internal_inline_cont_collapse_button")
	collapsef := lui.Form{}
	collapsef.layout.sizing = {lui.fit(), lui.fit()}
	collapsef.layout.padding = {theme.spacing.sm, 0}
	collapsef.text = theme.container.collapsed_text if .Collapsed in cont_state.flags else theme.container.uncollapsed_text
	collapsef.style = resolve_style(ctx, collapse, theme.container.inline_button)
	lui.submit_widget(ctx, collapse, collapsef)

	collapse_event := lui.get_widget_mouse_events(ctx, collapse, .Left)
	if .Clicked in collapse_event { cont_state.flags ~= {.Collapsed} }

	labelw := lui.reserve_widget(ctx, "__internal_inline_cont_title_label")
	labelf := lui.Form{}
	labelf.layout.sizing = lui.sizing()
	labelf.text = lui.create_text(ctx, lui.text(title_label, .None))
	labelf.style = resolve_style(ctx, labelw, theme.container.inline_title)
	lui.submit_widget(ctx, labelw, labelf)

	lui.pop_parent(ctx)

	if .Collapsed in cont_state.flags {
	    lui.pop_parent(ctx)
	    return false
	}

	conti := lui.reserve_widget(ctx, "__internal_inline_cont_content_holder")
	contif := lui.Form{}
	contif.layout.sizing = {lui.grow(), lui.grow()}
	contif.layout.direction = .Y
	contif.layout.padding = theme.spacing.md
	contif.layout.child_gap = theme.spacing.sm
	contif.style = resolve_style(ctx, conti, theme.container.inline_body)
	lui.submit_widget(ctx, conti, contif)

	lui.push_parent(ctx, conti)

	return true
}

end_inline_container :: proc(ctx: ^lui.Core_Context) {
    lui.pop_parent(ctx)
    lui.pop_parent(ctx)
}

button :: proc(ctx: ^lui.Core_Context, key: lui.Key, label: string) -> lui.Mouse_Events {
	button := lui.reserve_widget(ctx, key)
	buttonf := lui.Form{}
	buttonf.layout.sizing = lui.sizing()
	buttonf.layout.placement = {.Center, .Center}
	buttonf.text = lui.create_text(ctx, lui.text(label, .None))
	buttonf.style = resolve_style(ctx, button, theme.button.style)
	buttonf.layout.padding = theme.spacing.md
	buttonf.animation = theme.control_animation
	lui.submit_widget(ctx, button, buttonf)
	return lui.get_widget_mouse_events_all(ctx, button)
}

slider :: proc(ctx: ^lui.Core_Context, key: lui.Key, slider_label: string, value: ^$T, min: T, max: T, temp_alloc := context.temp_allocator) -> bool where intrinsics.type_is_float(T) {
	cont := lui.reserve_widget(ctx, key)
	contf := lui.Form{}
	contf.layout.sizing = lui.sizing(lui.grow(), lui.fit())
	contf.layout.child_gap = theme.spacing.sm
	contf.layout.placement = {.Center, .Center}
	lui.submit_widget(ctx, cont, contf)

	lui.push_parent(ctx, cont)

	label(ctx, "__internal_slider_label", slider_label)

	changed := false
	{
		t := clamp((value^ - min) / (max - min), 0, 1)

	    track := lui.reserve_widget(ctx, "__internal_slider_track")
	    track_events := lui.get_widget_mouse_events(ctx, track, .Left)

	    usable_w := T(track.rect.size.x - theme.slider.thumb_size.x - 1)

	    if .Pressed in track_events && usable_w > 0 {
	        t = clamp(T(ctx.mouse.position.x - track.rect.position.x - theme.slider.thumb_size.x * 0.5) / usable_w, 0, 1)
	        value^ = min + t * (max - min)
	        changed = true
	    }

	    trackf := lui.Form{}
	    trackf.layout.sizing = {lui.grow(), lui.fixed(theme.slider.track_height)}
	    trackf.layout.placement = {.Negative, .Center}
	    trackf.style = resolve_style(ctx, track, theme.slider.track)
	    lui.submit_widget(ctx, track, trackf)

	    lui.push_parent(ctx, track)

	    fill  := lui.reserve_widget(ctx, "__internal_slider_fill")
	    fillf := lui.Form{}
	    fillf.event_flags = {.Disable_Hover}
	    fillf.layout.sizing = {lui.fixed(f32(usable_w > 0 ? t * usable_w : 0)), lui.fixed(theme.slider.track_height)}
	    fillf.layout.placement = {.Negative, .Center}
	    fillf.style = resolve_style(ctx, track, theme.slider.track_fill)
	    fillf.animation = theme.control_animation
	    lui.submit_widget(ctx, fill, fillf)

	    control := lui.reserve_widget(ctx, "__internal_slider_control")

	    if lui.is_widget_active(ctx, control) && usable_w > 0 {
	        t = clamp(t + T(ctx.mouse.delta.x) / usable_w, 0, 1)
	        value^ = min + t * (max - min)
	        changed = true
	    }

	    controlf := lui.Form{}
	    controlf.event_flags = {.Lock_Active, .Lock_Hover}
	    controlf.layout.sizing = {lui.fixed(theme.slider.thumb_size.x), lui.fixed(theme.slider.thumb_size.y)}
	    controlf.style = resolve_style(ctx, control, theme.slider.thumb)
	    controlf.animation = theme.control_animation
	    lui.submit_widget(ctx, control, controlf)

		lui.push_parent(ctx, control)
		tooltip(ctx, "__internal_slider_thumb_tooltip", control, fmt.aprintf("%0.2f", value^, allocator = temp_alloc))
		lui.pop_parent(ctx)

	    lui.pop_parent(ctx)
	}

	lui.pop_parent(ctx)

    return changed
}

checkbox :: proc(ctx: ^lui.Core_Context, key: lui.Key, checkbox_label: string, state: ^bool) -> bool {
	check := lui.reserve_widget(ctx, key)
	checkf := lui.Form{}
	checkf.layout.sizing = lui.sizing()
	checkf.layout.child_gap = theme.spacing.sm
	checkf.layout.placement = {.Negative, .Center}
	lui.submit_widget(ctx, check, checkf)

	lui.push_parent(ctx, check)

	checkc := lui.reserve_widget(ctx, "__internal_check_control")
	checkcf := lui.Form{}
	checkcf.layout.sizing = {lui.fixed(theme.checkbox.size.x), lui.fixed(theme.checkbox.size.y)}
	checkcf.style = resolve_style(ctx, checkc, theme.checkbox.check_on if state^ else theme.checkbox.check_off)
	checkcf.animation = theme.control_animation
	lui.submit_widget(ctx, checkc, checkcf)

	label(ctx, "__internal_checkbox_label", checkbox_label)

	lui.pop_parent(ctx)

	events := lui.get_widget_mouse_events(ctx, checkc, .Left)
	if .Clicked in events {
		state^ = !state^
	 	return true
	}

	return false
}

toggle :: proc(ctx: ^lui.Core_Context, key: lui.Key, toggle_label: string, state: ^bool) {
	cont := lui.reserve_widget(ctx, key)
	contf := lui.Form{}
	contf.layout.sizing = lui.sizing(lui.fit(), lui.fit())
	contf.layout.child_gap = theme.spacing.sm
	lui.submit_widget(ctx, cont, contf)

	lui.push_parent(ctx, cont)

	toggleh := lui.reserve_widget(ctx, "__internal_toggle_control_holder")
	events := lui.get_widget_mouse_events(ctx, toggleh, .Left)
	if .Clicked in events { state^ = !state^ }

	togglehf := lui.Form{}
	togglehf.layout.sizing = lui.sizing(lui.fit(theme.toggle.size.x * 2 + theme.spacing.xs * 2), lui.fit())
	togglehf.layout.padding = theme.spacing.xs
	togglehf.style = resolve_style(ctx, toggleh, theme.toggle.track_on if state^ else theme.toggle.track_off)
	togglehf.layout.placement.x = .Negative if !state^ else .Positive
	lui.submit_widget(ctx, toggleh, togglehf)

	lui.push_parent(ctx, toggleh)

	togglec := lui.reserve_widget(ctx, "__internal_toggle_control")
	togglecf := lui.Form{}
	togglecf.event_flags = {.Disable_Hover}
	togglecf.layout.sizing = lui.sizing(lui.fixed(theme.toggle.size.x), lui.fixed(theme.toggle.size.y))
	togglecf.style = resolve_style(ctx, togglec, theme.toggle.thumb)
	lui.submit_widget(ctx, togglec, togglecf)

	lui.pop_parent(ctx)

	label(ctx, "__internal_toggle_label", toggle_label)

	lui.pop_parent(ctx)
}

begin_radio :: proc(ctx: ^lui.Core_Context, key: lui.Key, radio_label: string) {
	holder := lui.reserve_widget(ctx, key)
	holderf := lui.Form{}
	holderf.layout.sizing = lui.sizing(lui.grow())
	holderf.layout.direction = .Y
	holderf.layout.child_gap = theme.spacing.sm
	holderf.text = lui.create_text(ctx, lui.text(radio_label, preferred_min = 256))
	holderf.style = resolve_style(ctx, holder, theme.label.md)
	lui.submit_widget(ctx, holder, holderf)
	lui.push_parent(ctx, holder)

	radio_state, ok := &state.radio_state[holder.hash]
	if !ok {
		state.radio_state[holder.hash] = {}
		radio_state = &state.radio_state[holder.hash]
	}
	state.active_radio_state = radio_state
}

end_radio :: proc(ctx: ^lui.Core_Context) {
	lui.pop_parent(ctx)
	state.active_radio_state.counter = 0
	state.active_radio_state = nil
}

radio_item :: proc(ctx: ^lui.Core_Context, item_label: string) -> bool {
	holder := lui.reserve_widget(ctx, state.active_radio_state.counter)
	state.active_radio_state.counter += 1

	holderf := lui.Form{}
	holderf.layout.sizing = {lui.fit(), lui.fit()}
	holderf.layout.child_gap = theme.spacing.sm
	lui.submit_widget(ctx, holder, holderf)
	lui.push_parent(ctx, holder)

	active := holder.hash == state.active_radio_state.selected

	control := lui.reserve_widget(ctx, "__internal_radio_control")
	controlf := lui.Form{}
	controlf.layout.sizing = {lui.fixed(theme.radio.size.x), lui.fixed(theme.radio.size.y)}
	controlf.style = resolve_style(ctx, control, theme.radio.item_toggle_on if active else theme.radio.item_toggle_off)
	controlf.animation = theme.control_animation
	lui.submit_widget(ctx, control, controlf)

	label(ctx, "__internal_radio_label", item_label)

	lui.pop_parent(ctx)

	events := lui.get_widget_mouse_events(ctx, control, .Left)
	if .Clicked in events {
		state.active_radio_state.selected = holder.hash
		return true
	}
	return false
}

label :: proc(ctx: ^lui.Core_Context, key: lui.Key, text: string) {
	labelw := lui.reserve_widget(ctx, key)
	labelf := lui.Form{}
	labelf.layout.sizing = lui.sizing()
	labelf.text = lui.create_text(ctx, lui.text(text, .None))
	labelf.style = resolve_style(ctx, labelw, theme.label.md)
	lui.submit_widget(ctx, labelw, labelf)
}

progress_bar :: proc(ctx: ^lui.Core_Context, key: lui.Key, progress_label: string, value: f32, min: f32 = 0, max: f32 = 1) {
	cont := lui.reserve_widget(ctx, key)
	contf := lui.Form{}
	contf.layout.sizing = lui.sizing(lui.grow(), lui.fit())
	contf.layout.padding = theme.spacing.md
	contf.layout.child_gap = theme.spacing.sm
	contf.layout.placement = {.Center, .Center}
	lui.submit_widget(ctx, cont, contf)

	lui.push_parent(ctx, cont)

	label(ctx, "__internal_progress_label", progress_label)

	t := clamp((value - min) / (max - min), 0, 1)

	track := lui.reserve_widget(ctx, "__internal_progress_track")
	trackf := lui.Form{}
	trackf.event_flags = {.Disable_Hover}
	trackf.layout.sizing = {lui.grow(), lui.fixed(theme.progress_bar.track_height)}
	trackf.layout.placement = {.Negative, .Center}
	trackf.style = resolve_style(ctx, track, theme.progress_bar.track)
	lui.submit_widget(ctx, track, trackf)

	lui.push_parent(ctx, track)

	fill := lui.reserve_widget(ctx, "__internal_progress_fill")
	fillf := lui.Form{}
	fillf.event_flags = {.Disable_Hover}
	fillf.layout.sizing = {lui.fixed(t * track.rect.size.x), lui.grow()}
	fillf.style = resolve_style(ctx, track, theme.progress_bar.fill)
	lui.submit_widget(ctx, fill, fillf)

	lui.pop_parent(ctx)

	lui.pop_parent(ctx)
}

text_box :: proc(ctx: ^lui.Core_Context, key: lui.Key, text: string, wrap: lui.Text_Wrap_Mode = .Words) {
	cont := lui.reserve_widget(ctx, key)
	contf := lui.Form{}
	contf.layout.sizing = lui.sizing(lui.grow(), lui.fit())
	contf.layout.padding = theme.spacing.md
	contf.text = lui.create_text(ctx, lui.text(text, wrap))
	contf.style = resolve_style(ctx, cont, theme.text_box.style)
	contf.selection = lui.create_selection(ctx, lui.selection(cont.hash))
	events := lui.get_widget_mouse_events(ctx, cont, .Left)

	if .Pressed in events {
		lui.set_selection_anchor(ctx, contf.selection, ctx.mouse.hovered_character_index)
	}
	if .Down in events {
		lui.set_selection_cursor(ctx, contf.selection, ctx.mouse.hovered_character_index)
	}

	lui.submit_widget(ctx, cont, contf)
}

tooltip :: proc(ctx: ^lui.Core_Context, key: lui.Key, parent: lui.Widget_Info, tooltip_text: string) {
    if !lui.is_widget_hovered(ctx, parent) do return
    cont := lui.reserve_widget(ctx, key)
    contf := lui.Form{}
    contf.layout.sizing = {lui.fit(), lui.fit()}
    contf.layout.placement = {.Center, .Center}
    contf.layout.padding = theme.spacing.md
    contf.layout.flags = {{.No_Positioning_Relative, .No_Size_Propagation}, {.No_Positioning_Relative, .No_Size_Propagation}}
    contf.event_flags = {.Disable_Hover}
    contf.text = lui.create_text(ctx, lui.text(tooltip_text, .None))
    contf.style = resolve_style(ctx, cont, theme.tooltip.style)
    contf.animation = theme.control_animation
    contf.z_offset = 5000

    tw := cont.rect.size.x
    th := cont.rect.size.y
    px := parent.rect.position.x
    py := parent.rect.position.y
    pw := parent.rect.size.x
    ph := parent.rect.size.y
    ww := ctx.window_size.x
    wh := ctx.window_size.y

	m  := theme.spacing.sm
	x_off := clamp(px + pw*0.5 - tw*0.5, m, ww - tw - m) - (px + pw*0.5)
	y_off := clamp(py + ph*0.5 - th*0.5, m, wh - th - m) - (py + ph*0.5)

	contf.override = \
		lui.create_override(ctx, {offset = {lui.percent(0.5),      lui.percent_self(-1)}}, {offset = {lui.fixed(x_off), lui.fixed(-m)}}) if py - th >= m else \
		lui.create_override(ctx, {offset = {lui.percent(0.5),      lui.percent(1)}},       {offset = {lui.fixed(x_off), lui.fixed( m)}}) if py + ph + th <= wh - m else \
		lui.create_override(ctx, {offset = {lui.percent(1),        lui.percent(0.5)}},     {offset = {lui.fixed( m),    lui.fixed(y_off)}}) if px + pw + tw <= ww - m else \
		lui.create_override(ctx, {offset = {lui.percent_self(-1),  lui.percent(0.5)}},     {offset = {lui.fixed(-m),    lui.fixed(y_off)}})

		lui.submit_widget(ctx, cont, contf)
}

begin_dropdown :: proc(ctx: ^lui.Core_Context, key: lui.Key, dropdown_label: string) -> bool {
	holder := lui.reserve_widget(ctx, key)
	holderf := lui.Form{}
	holderf.layout.sizing = {lui.fit(), lui.fit()}
	holderf.layout.padding = theme.spacing.md
	holderf.layout.child_gap = theme.spacing.sm
	holderf.text = lui.create_text(ctx, lui.text(dropdown_label, .None))
	holderf.style = resolve_style(ctx, holder, theme.dropdown.label)
	lui.submit_widget(ctx, holder, holderf)

	ok := false
	state.active_dropdown_state, ok = &state.dropdown_state[holder.hash]
	if !ok {
		state.dropdown_state[holder.hash] = {}
		state.active_dropdown_state = &state.dropdown_state[holder.hash]
	}

	state.active_dropdown_state.counter = 0

	events := lui.get_widget_mouse_events(ctx, holder, .Left)
	if .Clicked in events {
		state.active_dropdown_state.is_active = !state.active_dropdown_state.is_active
	}

	if !state.active_dropdown_state.is_active {
		return false
	}

	lui.push_parent(ctx, holder)
	item_holder := lui.reserve_widget(ctx, "__internal_dropdown_item_holder")
	item_holderf := lui.Form{}
	item_holderf.layout.direction = .Y
	item_holderf.layout.sizing = {lui.fit(164), lui.fit(256)}
	item_holderf.layout.flags = {{.No_Size_Propagation, .No_Positioning_Relative}, {.No_Size_Propagation, .No_Positioning_Relative}}
	item_holderf.override = lui.create_override(ctx, {offset = {lui.percent(0), lui.percent(1)}}, {offset = {{}, lui.fixed(theme.spacing.sm)}})
	item_holderf.layout.child_gap = theme.spacing.sm
	item_holderf.layout.padding = {theme.spacing.sm, theme.spacing.sm}
	item_holderf.style = resolve_style(ctx, item_holder, theme.dropdown.body)
	item_holderf.clip = lui.create_clip(ctx, lui.clip({}, lui.clip_auto(5, -max(item_holder.rect.content_size.y - item_holder.rect.size.y, 0), 0), item_holder.hash))
	item_holderf.z_offset = 100
	lui.submit_widget(ctx, item_holder, item_holderf)
	lui.push_parent(ctx, item_holder)
	return true
}

end_dropdown :: proc(ctx: ^lui.Core_Context) {
	if state.active_dropdown_state.is_active {
		lui.pop_parent(ctx)
		lui.pop_parent(ctx)
	}
	state.active_dropdown_state = nil
}

dropdown_item :: proc(ctx: ^lui.Core_Context, item_label: string) -> bool {
	if !state.active_dropdown_state.is_active { return false }
	itemh := lui.reserve_widget(ctx, state.active_dropdown_state.counter)
	state.active_dropdown_state.counter += 1
	active := state.active_dropdown_state.selected == itemh.hash

	itemhf := lui.Form{}
	itemhf.layout.sizing = {lui.grow(20), lui.fit(20)}
	itemhf.layout.child_gap = theme.spacing.sm
	itemhf.layout.padding = theme.spacing.md
	itemhf.text = lui.create_text(ctx, lui.text(item_label, .None))
	itemhf.style = resolve_style(ctx, itemh, theme.dropdown.item_on if active else theme.dropdown.item_off)
	itemhf.animation = theme.control_animation
	lui.submit_widget(ctx, itemh, itemhf)

	events := lui.get_widget_mouse_events(ctx, itemh, .Left)
	if .Clicked in events {
		state.active_dropdown_state.selected = itemh.hash
		return true
	}

	return false
}

spinbox :: proc(ctx: ^lui.Core_Context, key: lui.Key, spinbox_label: string, value: ^$T, min, max: T, step: T, temp_alloc := context.temp_allocator) -> bool where intrinsics.type_is_integer(T) {
    cont := lui.reserve_widget(ctx, key)
    contf := lui.Form{}
    contf.layout.sizing = lui.sizing(lui.grow(), lui.fit())
    contf.layout.child_gap = theme.spacing.sm
    contf.layout.placement = {.Negative, .Center}
    lui.submit_widget(ctx, cont, contf)

    lui.push_parent(ctx, cont)

    label(ctx, "__internal_spinbox_label", spinbox_label)

    changed := false

    button_dec := lui.reserve_widget(ctx, "__internal_spinbox_decrement")
    button_decf := lui.Form{}
    button_decf.layout.sizing = {lui.fit(), lui.fit()}
    button_decf.layout.padding = theme.spacing.sm
    button_decf.text = theme.spinbox.dec_text
    button_decf.style = resolve_style(ctx, button_dec, theme.spinbox.dec)
    lui.submit_widget(ctx, button_dec, button_decf)

    input := lui.reserve_widget(ctx, "__internal_spinbox_val")
    inputf := lui.Form{}
    inputf.layout.sizing = {lui.fit(), lui.fit()}
    inputf.layout.placement = {.Center, .Center}
    inputf.layout.padding = {theme.spacing.lg, theme.spacing.sm}
    inputf.text = lui.create_text(ctx, lui.text(fmt.aprintf("%v", value^, allocator = temp_alloc), .None))
    inputf.style = resolve_style(ctx, input, theme.spinbox.input)
    lui.submit_widget(ctx, input, inputf)

    button_inc := lui.reserve_widget(ctx, "__internal_spinbox_increment")
    button_incf := lui.Form{}
    button_incf.layout.sizing = {lui.fit(), lui.fit()}
    button_incf.layout.padding = theme.spacing.sm
    button_incf.text = theme.spinbox.inc_text
    button_incf.style = resolve_style(ctx, button_inc, theme.spinbox.inc)
    lui.submit_widget(ctx, button_inc, button_incf)

    event_dec := lui.get_widget_mouse_events(ctx, button_dec, .Left)
    event_inc := lui.get_widget_mouse_events(ctx, button_inc, .Left)

    if .Clicked in event_dec || (.Long_Down in event_dec && .Repeat in event_dec) { value^ -= step }
    if .Clicked in event_inc || (.Long_Down in event_inc && .Repeat in event_inc) { value^ += step }

    value^ = clamp(value^, min, max)

    lui.pop_parent(ctx)

    return changed
}

stack :: proc(ctx: ^lui.Core_Context, key: lui.Key, stack_label: string, direction := lui.Axis.X) {
    cont := lui.reserve_widget(ctx, key)
    contf := lui.Form{}
    contf.layout.sizing = {lui.grow(), lui.grow()}
    contf.layout.direction = direction
    contf.layout.child_gap = theme.spacing.sm
    lui.submit_widget(ctx, cont, contf)
    lui.push_parent(ctx, cont)

    label(ctx, "__internal_stack_label", stack_label)
}

end_stack :: proc(ctx: ^lui.Core_Context) {
    lui.pop_parent(ctx)
}

mouse_indicator :: proc(ctx: ^lui.Core_Context, key: lui.Key, drag_label: string, temp_alloc := context.temp_allocator) -> (distance_from_center: lui.Vec2f32, draging: bool) {
	area := lui.reserve_widget(ctx, key)
	areaf := lui.Form{}
	areaf.event_flags = {.Lock_Active, .Lock_Hover}
	areaf.layout.sizing = {lui.Fixed{theme.drag.area_size.x}, lui.Fixed{theme.drag.area_size.y}}
	areaf.style = resolve_style(ctx, area, theme.drag.area)
	lui.submit_widget(ctx, area, areaf)

	events := lui.get_widget_mouse_events(ctx, area, .Left)
	distance_from_center = ctx.mouse.position - (area.rect.position + area.rect.size / 2)
	uv := linalg.max(linalg.min(ctx.mouse.position / ctx.window_size, 1), 0)
	draging = .Down in events

	lui.push_parent(ctx, area)

	indicator := lui.reserve_widget(ctx, "__internal_drag_area_mouse_rel_window_indicator")
	indicatorf := lui.Form{}
	indicatorf.layout.sizing = {lui.Fixed{theme.drag.indicator_size.x}, lui.Fixed{theme.drag.indicator_size.y}}
	indicatorf.layout.flags = {{.No_Size_Propagation, .No_Positioning_Relative}, {.No_Size_Propagation, .No_Positioning_Relative}}
	indicatorf.style = resolve_style(ctx, indicator, theme.drag.indicator)
	indicatorf.override = lui.create_override(ctx, {offset = {lui.Percent{uv.x}, lui.Percent{uv.y}}}, {offset = {lui.Percent_Self{-0.5}, lui.Percent_Self{-0.5}}})
	lui.submit_widget(ctx, indicator, indicatorf)

	tooltip(ctx, "__internal_drag_tooltip", area, fmt.aprintf("%s delta: [%.2f, %.2f] [%.2f, %.2f]", drag_label, ctx.mouse.delta.x, ctx.mouse.delta.y, distance_from_center.x, distance_from_center.y))
	lui.pop_parent(ctx)

	return distance_from_center, .Down in events
}

track_region :: proc(ctx: ^lui.Core_Context, key: lui.Key, drag_label: string, value: ^lui.Vec2f32, reference: lui.Vec2f32, bounds: lui.Vec2f32, temp_alloc := context.temp_allocator) -> (dragging: bool) {
	area := lui.reserve_widget(ctx, key)
	areaf := lui.Form{}
	areaf.event_flags = {.Lock_Active, .Lock_Hover}
	areaf.layout.sizing = {lui.Fixed{theme.drag.area_size.x}, lui.Fixed{theme.drag.area_size.y}}
	areaf.style = resolve_style(ctx, area, theme.drag.area)
	lui.submit_widget(ctx, area, areaf)

	events := lui.get_widget_mouse_events(ctx, area, .Left)
	dragging = .Down in events

	local := (value^ - reference + bounds)

	uv := linalg.max(linalg.min(local / (bounds * 2) , 1), 0)
	step := ctx.mouse.delta * (bounds * 2) / ctx.window_size

	if dragging { value^ += step }

	value^ = linalg.max(linalg.min(value^, reference + bounds), reference - bounds)

	lui.push_parent(ctx, area)

	indicator := lui.reserve_widget(ctx, "__internal_drag_area_mouse_rel_window_indicator")
	indicatorf := lui.Form{}
	indicatorf.layout.sizing = {lui.Fixed{theme.drag.indicator_size.x}, lui.Fixed{theme.drag.indicator_size.y}}
	indicatorf.layout.flags = {{.No_Size_Propagation, .No_Positioning_Relative}, {.No_Size_Propagation, .No_Positioning_Relative}}
	indicatorf.style = resolve_style(ctx, indicator, theme.drag.indicator)
	indicatorf.override = lui.create_override(ctx, {offset = {lui.Percent{uv.x}, lui.Percent{uv.y}}}, {offset = {lui.Percent_Self{-0.5}, lui.Percent_Self{-0.5}}})
	lui.submit_widget(ctx, indicator, indicatorf)

	tooltip(ctx, "__internal_drag_tooltip", area, fmt.aprintf("%s delta: [%.2f, %.2f] [%.2f, %.2f]", drag_label, value.x, value.y, local.x, local.y))
	lui.pop_parent(ctx)

	return dragging
}

color_rect :: proc(ctx: ^lui.Core_Context, key: lui.Key, color: lui.Color, temp_alloc := context.temp_allocator) {
    cont := lui.reserve_widget(ctx, key)
    contf := lui.Form{}
    contf.layout.sizing = {lui.fixed(theme.spacing.lg), lui.fixed(theme.spacing.lg)}
    contf.style = lui.create_style(ctx, {color = color})
    lui.submit_widget(ctx, cont, contf)
    lui.push_parent(ctx, cont)
    color_label := fmt.aprintf("Hex:#%X%X%X%X RGBA:%i %i %i %i", u8(color.r), u8(color.g), u8(color.b), u8(color.a), u8(color.r), u8(color.g), u8(color.b), u8(color.a), allocator = temp_alloc)
    tooltip(ctx, "__internal_color_rect_tooltip", cont, color_label)
    lui.pop_parent(ctx)
}

display_struct :: proc(ctx: ^lui.Core_Context, key: lui.Key, title_label: string, value: any, temp_alloc := context.temp_allocator) {
    display_others :: proc(ctx: ^lui.Core_Context, type: string, info: ^runtime.Type_Info, field: reflect.Struct_Field, value: any, temp_alloc := context.temp_allocator) {
    	tag_value := reflect.struct_tag_get(field.tag, "lui")

     	#partial switch v in info.variant {
		case runtime.Type_Info_Named:
		    display_others(ctx, v.name, v.base, field, value, temp_alloc)
		case runtime.Type_Info_Struct:
		    name := fmt.aprintf("Struct|%s|%s", type, field.name, allocator = temp_alloc)
			display_struct(ctx, name, name, value)
		case runtime.Type_Info_Enum:
		    name := fmt.aprintf("Enum|%s|%s", type, field.name, allocator = temp_alloc)
			ok := false
			for attr in strings.split_iterator(&tag_value, ",") {
				if attr == "dropdown" {
					begin_dropdown(ctx, name, name)
					for name, i in v.names {
						if dropdown_item(ctx, name) { (^runtime.Type_Info_Enum_Value)(value.data)^ = v.values[i] }
					}
					end_dropdown(ctx)
					ok = true
				}
				if attr == "radio" {
					begin_radio(ctx, name, name)
					for name, i in v.names {
						if radio_item(ctx, name) { (^runtime.Type_Info_Enum_Value)(value.data)^ = v.values[i] }
					}
					end_radio(ctx)
					ok = true
				}
			}
			if !ok {
				begin_dropdown(ctx, name, name)
				for name, i in v.names {
					if dropdown_item(ctx, name) { (^runtime.Type_Info_Enum_Value)(value.data)^ = v.values[i] }
				}
				end_dropdown(ctx)
			}
		case runtime.Type_Info_Array:
			if v.count <= 4 && v.elem.id == f32 {
			    labels := [4]string{"x", "y", "z", "w"}
				direction := lui.Axis.X
				min := f32(0)
				max := f32(100)
				add_color_rect := false
 				for attr in strings.split_iterator(&tag_value, ",") {
					if attr == "row" { direction = .X }
					if attr == "column" { direction = .Y }
					if attr == "color" { add_color_rect = true }
					if strings.starts_with(attr, "labels=") { for i in 0..<len(attr[7:]) { labels[i] = attr[7:][i:i+1] } }
					if strings.starts_with(attr, "max=") { max, _ = strconv.parse_f32(attr[4:]) }
					if strings.starts_with(attr, "min=") { min, _ = strconv.parse_f32(attr[4:])}
				}

				name := fmt.aprintf("[%i]f32|%s|%s ", v.count, type, field.name, allocator = temp_alloc)
				stack(ctx, name, name, direction)
 			    for i in 0..<v.count {
   					slider(ctx, fmt.aprint(name, labels[i], allocator = temp_alloc), labels[i], (&([^]f32)(value.data)[i]), min, max)
				}
				if add_color_rect {
					color := lui.Color{}
					copy(color[:v.count], ([^]f32)(value.data)[:v.count])
					color_rect(ctx, "color_rect", color)
				}
				end_stack(ctx)
			}
		case runtime.Type_Info_Union:
			name := fmt.aprintf("Union|%s|%s", type, field.name, allocator = temp_alloc)
			if inline_container(ctx, name, name) {

				begin_dropdown(ctx, name, name)
				for varient_info in v.variants {
					varient_name := fmt.aprint(varient_info, allocator = temp_alloc)
					if dropdown_item(ctx, varient_name) {
						reflect.set_union_variant_type_info(value, varient_info)
					}
				}
				end_dropdown(ctx)
				display_others(ctx, "Union_Varient", reflect.union_variant_type_info(value), field, reflect.get_union_variant(value), temp_alloc)
				end_inline_container(ctx)
			}
		case runtime.Type_Info_String:
			str := string{}
			switch v.encoding {
			case .UTF_8: str, _ = reflect.as_string(value)
			case .UTF_16:
				str16, _ := reflect.as_string16(value)
				str = transmute(string)make([]u8, len(str16), allocator = temp_alloc)
				utf16.decode_to_utf8(transmute([]u8)str, transmute([]u16)str16)
			}

			ok := false
			for attr in strings.split_iterator(&tag_value, ",") {
				if attr == "label" { label(ctx, str, str); ok = true }
				if attr == "input" {  }
				if attr == "textbox" { text_box(ctx, str, str, .Words); ok = true }
			}
			if !ok { label(ctx, str, str) }
		case runtime.Type_Info_Float:
			min := -100.0
			max := 100.0

			for attr in strings.split_iterator(&tag_value, ",") {
				if strings.starts_with(attr, "min=") { min, _ = strconv.parse_f64(attr[4:]) }
				if strings.starts_with(attr, "max=") { max, _ = strconv.parse_f64(attr[4:]) }
			}
			switch field.type.size {
			case 2: // f16
				valf16 := f16(0)
				switch value.id {
				case f16: valf16 = (^f16)(value.data)^
				case f16le: valf16 = (f16)((^f16le)(value.data)^)
				case f16be: valf16 = (f16)((^f16be)(value.data)^)
				}
				slider(ctx, field.name, field.name, &valf16, f16(min), f16(max), temp_alloc)
				switch value.id {
				case f16: (^f16)(value.data)^ = valf16
				case f16le: (^f16le)(value.data)^ = f16le(valf16)
				case f16be: (^f16be)(value.data)^ = f16be(valf16)
				}
			case 4: // f32
				valf32 := f32(0)
				switch value.id {
				case f32: valf32 = (^f32)(value.data)^
				case f32le: valf32 = (f32)((^f32le)(value.data)^)
				case f32be: valf32 = (f32)((^f32be)(value.data)^)
				}
				slider(ctx, field.name, field.name, &valf32, f32(min), f32(max), temp_alloc)
				switch value.id {
				case f32: (^f32)(value.data)^ = valf32
				case f32le: (^f32le)(value.data)^ = f32le(valf32)
				case f32be: (^f32be)(value.data)^ = f32be(valf32)
				}
			case 8: // f64
				valf64 := f64(0)
				switch value.id {
				case f64: valf64 = (^f64)(value.data)^
				case f64le: valf64 = (f64)((^f64le)(value.data)^)
				case f64be: valf64 = (f64)((^f64be)(value.data)^)
				}
				slider(ctx, field.name, field.name, &valf64, min, max, temp_alloc)
				switch value.id {
				case f64: (^f64)(value.data)^ = valf64
				case f64le: (^f64le)(value.data)^ = f64le(valf64)
				case f64be: (^f64be)(value.data)^ = f64be(valf64)
				}
			}
		case runtime.Type_Info_Boolean:
			val := false
			switch value.id {
			case bool: val = (^bool)(value.data)^
			case b8: val = bool((^b8)(value.data)^)
			case b16: val = bool((^b16)(value.data)^)
			case b32: val = bool((^b32)(value.data)^)
			case b64: val = bool((^b64)(value.data)^)
			}

			ok := false
			for attr in strings.split_iterator(&tag_value, ",") {
				if attr == "toggle" { toggle(ctx, field.name, field.name, &val); ok = true }
				if attr == "checkbox" { checkbox(ctx, field.name, field.name, &val); ok = true }
			}

			if !ok { toggle(ctx, field.name, field.name, &val) }

			switch value.id {
			case bool: (^bool)(value.data)^ = (bool)(val)
			case b8:   (^b8) (value.data)^ = (b8)(val)
			case b16:  (^b16)(value.data)^ = (b16)(val)
			case b32:  (^b32)(value.data)^ = (b32)(val)
			case b64:  (^b64)(value.data)^ = (b64)(val)
			}
		case runtime.Type_Info_Integer:
			if v.signed {
				switch field.type.size {
				case 1:
				case 2:
				case 4:
				case 8:
				case 16:
				}
			} else {

			}
		}
	}

	if !reflect.is_struct(type_info_of(value.id)) { return }
	if inline_container(ctx, key, title_label) {
		for field in reflect.struct_fields_zipped(value.id) {
			field_any := reflect.struct_field_value(value, field)
			info := type_info_of(field_any.id)
			#partial switch v in info.variant {
			case runtime.Type_Info_Named: display_others(ctx, v.name, info, field, field_any, temp_alloc)
			case:                         display_others(ctx, "Anon", info, field, field_any, temp_alloc)
			}
		}
		end_inline_container(ctx)
	}
}
