package widgets

import "core:fmt"
import "core:time"
import lui "../../"

Color_Palette :: struct {
    bg_base:      lui.Color,
    bg_elevated:  lui.Color,
    bg_sunken:    lui.Color,

    fg_primary:   lui.Color,
    fg_secondary: lui.Color,
    fg_muted:     lui.Color,

    accent:       lui.Color,
    accent_hover: lui.Color,
    accent_press: lui.Color,

    border_subtle: lui.Color,
    border_strong: lui.Color,

    danger:  lui.Color,
    warning: lui.Color,
    success: lui.Color,
}

Spacing :: struct {
    xs: f32,
    sm: f32,
    md: f32,
    lg: f32,
    xl: f32,
}

Font :: struct {
	f_xs: rawptr,
	f_sm: rawptr,
	f_md: rawptr,
	f_lg: rawptr,
	f_xl: rawptr,
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
    	body:      Interaction_Style,
    	title:     Interaction_Style,
    	button:    Interaction_Style,
    	title_bar: Interaction_Style,
     	collapsed_text:   lui.Text_Index,
      	uncollapsed_text: lui.Text_Index,
        undocked_text:    lui.Text_Index,
       	docked_text:      lui.Text_Index,
        resize_text:      lui.Text_Index,
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

Dropdown_State :: struct {
	selected: lui.Hash,
	counter: int,
}

Radio_State :: struct {
	selected: lui.Hash,
	counter: int,
}

State :: struct {
	radio_state:        map[lui.Hash]Radio_State,
	container_state:    map[lui.Hash]Container_State,
	container_stack:    [dynamic]lui.Widget_Info,
	active_radio_state: ^Radio_State,
	text_user_data:     rawptr
}

theme := Theme{}
state := State{}

DEFAULT_SPACING :: Spacing {
    xs = 2,
    sm = 4,
    md = 8,
    lg = 16,
    xl = 24,
}

PALETTE_KANAGAWA :: Color_Palette {
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
}

PALETTE_MONO_DARK :: Color_Palette {
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
}

PALETTE_MONO_LIGHT :: Color_Palette {
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
}

PALETTE_GRUVBOX_DARK :: Color_Palette {
    bg_base       = {  30,  33,  34, 255 },
    bg_elevated   = {  40,  43,  44, 255 },
    bg_sunken     = {  36,  39,  40, 255 },

    fg_primary    = { 199, 184, 157, 255 },
    fg_secondary  = { 192, 177, 150, 255 },
    fg_muted      = {  87,  90,  91, 255 },

    accent        = { 116, 150, 137, 255 },
    accent_hover  = { 169, 182, 101, 255 },
    accent_press  = { 109, 141, 173, 255 },

    border_subtle = {  50,  53,  54, 255 },
    border_strong = {  87,  90,  91, 255 },

    danger        = { 236, 107, 100, 255 },
    warning       = { 214, 182, 118, 255 },
    success       = { 169, 182, 101, 255 },
}

PALETTE_GRUVBOX_LIGHT :: Color_Palette {
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
}

PALETTE_CATPPUCCIN_DARK :: Color_Palette {
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
}

PALETTE_CATPPUCCIN_LIGHT :: Color_Palette {
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
}

PALETTE_TOKYO_NIGHT :: Color_Palette {
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
}

PALETTE_EVERFOREST_DARK :: Color_Palette {
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
}

PALETTE_EVERBLUSH :: Color_Palette {
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
}

build_theme :: proc(ctx: ^lui.Core_Context, palette: Color_Palette, spacing: Spacing, font: Font) {
	theme.font = font
	theme.palette = palette
	theme.spacing = spacing

    p := &theme.palette
    s := &theme.spacing
    f := &theme.font

    transparent := lui.create_style(ctx, {text   = {color = p.fg_primary, font = f.f_md}})

    surface := lui.create_style(ctx, {
        color  = p.bg_elevated,
        border = {color = p.border_subtle, thickness = 1, radius = 6},
        text   = {color = p.fg_primary, font = f.f_md},
    })

    surface_hover := lui.create_style(ctx, {
        color  = p.bg_elevated,
        border = {color = p.border_strong, thickness = 1, radius = 6},
        text   = {color = p.fg_primary, font = f.f_md},
    })

    accent := lui.create_style(ctx, {
        color  = p.accent,
        border = {color = p.accent, thickness = 1, radius = 6},
        text   = {color = p.bg_sunken, font = f.f_md},
    })

    accent_hover := lui.create_style(ctx, {
        color  = p.accent_hover,
        border = {color = p.accent_hover, thickness = 1, radius = 6},
        text   = {color = p.bg_sunken, font = f.f_md},
    })

    accent_press := lui.create_style(ctx, {
        color  = p.accent_press,
        border = {color = p.accent_press, thickness = 1, radius = 6},
        text   = {color = p.bg_sunken, font = f.f_md},
    })

    danger := lui.create_style(ctx, {
        color  = p.danger,
        border = {color = p.danger, thickness = 1, radius = 6},
        text   = {color = p.bg_sunken, font = f.f_md},
    })

    text_md := lui.create_style(ctx, {color = 0, text = {color = p.fg_primary, font = f.f_md}})
    text_sm := lui.create_style(ctx, {color = 0, text = {color = p.fg_secondary, font = f.f_sm}})

    track := lui.create_style(ctx, {color  = p.bg_sunken, border = {color = p.border_subtle, thickness = 1, radius = 999}})

    track_fill := lui.create_style(ctx, {color  = p.accent, border = {color = p.border_subtle, thickness = 1, radius = 999}})

    thumb := lui.create_style(ctx, {color  = p.bg_base, border = {color = p.border_strong, thickness = 1, radius = 999}})
    thumb_h := lui.create_style(ctx, {color = p.bg_elevated, border = {color = p.border_strong, thickness = 1, radius = 999}})
    thumb_p := lui.create_style(ctx, {color = p.accent, border = {color = p.border_strong, thickness = 1, radius = 999}})

    text_box := lui.create_style(ctx, {
        color  = p.bg_sunken,
        border = {color = p.border_subtle, thickness = 1, radius = 6},
        text   = {color = p.fg_primary, font = f.f_md, selection_background = p.accent, selection_border = {radius = 4}},
    })

    tooltip := lui.create_style(ctx, {
        color  = p.bg_base,
        border = {color = p.border_subtle, thickness = 1, radius = 6},
        text   = {color = p.fg_primary, font = f.f_sm},
    })

    si :: proc(normal, hover, press: lui.Style_Index) -> Interaction_Style {
        return {.Normal = normal, .Hover = hover, .Press = press}
    }

    {
   		body := lui.create_style(ctx, {color = p.bg_base, border = {color = p.border_subtle, thickness = {1, {0, 1}}, radius = {0, 0, 6, 6}}})
     	title_bar := lui.create_style(ctx, {color = p.bg_elevated, border = {color = p.border_subtle, thickness = {1, {1, 0}}, radius = {6, 6, 0, 0}}})
        title    := lui.create_style(ctx, {text = {color = p.fg_primary, font = f.f_md}})
      	button := lui.create_style(ctx, {
       		color = p.bg_elevated,
         	border = {color = p.border_subtle, radius = 4},
          	text = {color = p.fg_primary, font = f.f_md}}
       )
        button_h := lui.create_style(ctx, {color = p.accent_hover, border = {radius = {4, 0, 4, 0}}, text = {color = p.bg_elevated, font = f.f_md}})
        button_p := lui.create_style(ctx, {color = p.accent_press, border = {radius = {4, 0, 4, 0}}, text = {color = p.bg_elevated, font = f.f_md}})

    	theme.container.body = si(body, body, body)
    	theme.container.title = si(title, title, title)
    	theme.container.button = si(button, button_h, button_p)
    	theme.container.title_bar = si(title_bar, title_bar, title_bar)

     	theme.container.collapsed_text   = lui.create_text(ctx, lui.text("▶", .None))
      	theme.container.uncollapsed_text = lui.create_text(ctx, lui.text("▼", .None))
       	theme.container.docked_text      = lui.create_text(ctx, lui.text("■", .None))
       	theme.container.undocked_text    = lui.create_text(ctx, lui.text("□", .None))
       	theme.container.resize_text      = lui.create_text(ctx, lui.text("󰑝", .None))
    }

    theme.button.style = si(accent, accent_hover, accent_press)

    theme.slider.thumb = si(thumb, thumb_h, thumb_p)
    theme.slider.track = si(track, track, track)
    theme.slider.track_fill = si(track_fill, track_fill, track_fill)
    theme.slider.thumb_size = {14, 18}
    theme.slider.track_height = 6

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

    theme.label.md = si(text_md, text_md, text_md)
    theme.label.sm = si(text_sm, text_sm, text_sm)

    theme.progress_bar.track = si(track, track, track)
    theme.progress_bar.fill = si(track_fill, track_fill, track_fill)
    theme.progress_bar.track_height = 6

    theme.text_box.style = si(text_box, text_box, text_box)
    theme.tooltip.style = si(tooltip, tooltip, tooltip)

    anim := lui.ANIM_COLOR
    anim.on_destroyed = proc(info: lui.Widget_Info, style: lui.Style, text_position: lui.Vec2f32) -> (end: lui.Animation_Data) {
        return {}
    }

    theme.control_animation = lui.create_animation(ctx, anim, duration = time.Millisecond * 200)
}

resolve_style :: proc(ctx: ^lui.Core_Context, info: lui.Widget_Info, style: Interaction_Style) -> lui.Style_Index {
	if lui.is_widget_active(ctx, info) { return style[.Press]}
    if lui.is_widget_hovered(ctx, info)  { return style[.Hover]}
    return style[.Normal]
}

container :: proc(ctx: ^lui.Core_Context, key: lui.Key, title_label: string) -> bool {
	cont := lui.reserve_widget(ctx, key)
	cont_state, _ := &state.container_state[cont.hash]
	append(&state.container_stack, cont)

	if cont_state == nil {
		state.container_state[cont.hash] = {flags = {.Docked}}
		cont_state = &state.container_state[cont.hash]
	}

	contf := lui.Form{}
	contf.layout.sizing = {lui.fit(cont_state.size.x), lui.fit(cont_state.size.y)} if .Collapsed not_in cont_state.flags else {lui.fit(), lui.fit()}
	contf.layout.direction = .Y

	if .Docked not_in cont_state.flags {
		if cont_state.position.x == 0 { cont_state.position.x = cont.rect.position.x }
		if cont_state.position.y == 0 { cont_state.position.y = cont.rect.position.y }
		contf.layout.flags = {{.No_Positioning, .No_Size_Propagation}, {.No_Positioning, .No_Size_Propagation}}
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
	cont_barf.layout.padding.x.y = theme.spacing.lg
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
		tooltip(ctx, "__internal_cont_collapse_tooltip", cont_collapse, "Collapse/Uncollapsed Container")
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
		pop(&state.container_stack)
		return false
	}

	conti := lui.reserve_widget(ctx, "__internal_cont_content_holder")
	contif := lui.Form{}
	contif.layout.sizing = {lui.grow(), lui.grow()}
	contif.layout.padding = theme.spacing.md
	contif.layout.direction = .Y
	contif.layout.child_gap = theme.spacing.md
	contif.clip = lui.create_clip(ctx, lui.clip({}, lui.clip_auto(5, -max(conti.rect.content_size.y - conti.rect.size.y, 0), 0), conti.hash))
	contif.style = resolve_style(ctx, conti, theme.container.body)
	lui.submit_widget(ctx, conti, contif)
	lui.push_parent(ctx, conti)
	return true
}

end_container :: proc(ctx: ^lui.Core_Context) {
	cont := pop(&state.container_stack)
	cont_state := &state.container_state[cont.hash]

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

slider :: proc(ctx: ^lui.Core_Context, key: lui.Key, value: ^f32, min: f32 = 0, max: f32 = 1) -> bool {

	cont := lui.reserve_widget(ctx, key)
	contf := lui.Form{}
	contf.layout.sizing = lui.sizing(lui.grow(), lui.fit())
	contf.layout.padding = theme.spacing.md
	contf.layout.child_gap = theme.spacing.sm
	lui.submit_widget(ctx, cont, contf)

	lui.push_parent(ctx, cont)

	changed := false
	{
		t := clamp((value^ - min) / (max - min), 0, 1)

	    track := lui.reserve_widget(ctx, "__internal_slider_track")
	    track_events := lui.get_widget_mouse_events(ctx, track, .Left)

	    usable_w := track.rect.size.x - theme.slider.thumb_size.x

	    if .Pressed in track_events && usable_w > 0 {
	        t = clamp((ctx.mouse.position.x - track.rect.position.x - theme.slider.thumb_size.x * 0.5) / usable_w, 0, 1)
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
	    fillf.layout.sizing = {lui.fixed(usable_w > 0 ? t * usable_w : 0), lui.fixed(theme.slider.track_height)}
	    fillf.layout.placement = {.Negative, .Center}
	    fillf.style = resolve_style(ctx, track, theme.slider.track_fill)
	    fillf.animation = theme.control_animation
	    lui.submit_widget(ctx, fill, fillf)

	    control := lui.reserve_widget(ctx, "__internal_slider_control")

	    if lui.is_widget_active(ctx, control) && usable_w > 0 {
	        t = clamp(t + ctx.mouse.delta.x / usable_w, 0, 1)
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
		tooltip(ctx, "__internal_slider_thumb_tooltip", control, fmt.tprintf("%0.2f", value^))
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
	holderf.layout.padding = theme.spacing.md
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
	holderf.layout.sizing = lui.sizing()
	holderf.layout.child_gap = theme.spacing.sm
	lui.submit_widget(ctx, holder, holderf)
	lui.push_parent(ctx, holder)

	control := lui.reserve_widget(ctx, "__internal_radio_control")

	events := lui.get_widget_mouse_events(ctx, control, .Left)
	if .Clicked in events {
		state.active_radio_state.selected = holder.hash
	}

	active := holder.hash == state.active_radio_state.selected

	controlf := lui.Form{}
	controlf.layout.sizing = {lui.fixed(theme.radio.size.x), lui.fixed(theme.radio.size.y)}
	controlf.style = resolve_style(ctx, control, theme.radio.item_toggle_on if active else theme.radio.item_toggle_off)
	controlf.animation = theme.control_animation
	lui.submit_widget(ctx, control, controlf)

	label(ctx, "__internal_radio_label", item_label)

	lui.pop_parent(ctx)

	return .Clicked in events && active
}

label :: proc(ctx: ^lui.Core_Context, key: lui.Key, text: string) {
	labelw := lui.reserve_widget(ctx, key)
	labelf := lui.Form{}
	labelf.layout.sizing = lui.sizing()
	labelf.text = lui.create_text(ctx, lui.text(text, .None))
	labelf.style = resolve_style(ctx, labelw, theme.label.md)
	lui.submit_widget(ctx, labelw, labelf)
}

progress_bar :: proc(ctx: ^lui.Core_Context, key: lui.Key, value: f32, min: f32 = 0, max: f32 = 1) {
	t := clamp((value - min) / (max - min), 0, 1)

	track := lui.reserve_widget(ctx, key)
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
}

text_box :: proc(ctx: ^lui.Core_Context, key: lui.Key, text: string, wrap: lui.Text_Wrap_Mode = .Words) {
	cont := lui.reserve_widget(ctx, key)
	contf := lui.Form{}
	contf.layout.sizing = lui.sizing(lui.grow(), lui.fit())
	contf.layout.padding = theme.spacing.md
	contf.text = lui.create_text(ctx, lui.text(text, wrap, user_data = state.text_user_data))
	contf.style = resolve_style(ctx, cont, theme.text_box.style)
	contf.selection = lui.create_selection(ctx, lui.selection(cont.hash))
	fmt.println(lui.get_selection(ctx, contf.selection))
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

begin_dropdown :: proc(ctx: ^lui.Core_Context, key: lui.Key, dropdown_label: string) {
	holder := lui.reserve_widget(ctx, key)
	holderf := lui.Form{}
	holderf.layout.sizing = {lui.fit(), lui.fit()}
	holderf.layout.direction = .Y
	holderf.layout.padding = theme.spacing.md
	holderf.layout.child_gap = theme.spacing.sm
	holderf.text = lui.create_text(ctx, lui.text(dropdown_label, .None))
	holderf.style = resolve_style(ctx, holder, theme.label.md)
	lui.submit_widget(ctx, holder, holderf)
	lui.push_parent(ctx, holder)

	item_holder := lui.reserve_widget(ctx, "__internal_dropdown_item_holder")
	item_holderf := lui.Form{}
	item_holderf.layout.sizing = {lui.fit(), lui.fit()}
	item_holderf.layout.flags = {{.No_Size_Propagation, .No_Positioning_Relative}, {.No_Size_Propagation, .No_Positioning_Relative}}
	item_holderf.override = lui.create_override(ctx, {offset = {lui.percent(1), lui.percent(1)}}, {offset = {{}, lui.fixed(theme.spacing.sm)}})
	item_holderf.layout.child_gap = theme.spacing.sm
	lui.submit_widget(ctx, item_holder, item_holderf)
	lui.push_parent(ctx, item_holder)
}

end_dropdown :: proc(ctx: ^lui.Core_Context) {
	lui.pop_parent(ctx)
	lui.pop_parent(ctx)
}

dropdown_item :: proc(ctx: ^lui.Core_Context) {

}
