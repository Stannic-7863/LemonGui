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
     	button:   Interaction_Style,
    	title_bar: Interaction_Style,
    },

    button: struct {
    	style: [Varient]Interaction_Style,
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
    	check_holder: Interaction_Style,
    },

    toggle: struct {
    	track_on: Interaction_Style,
     	thumb_on: Interaction_Style,
      	track_off: Interaction_Style,
       	thumb_off: Interaction_Style,
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

    container_collapsed_text:   lui.Text_Index,
    container_uncollapsed_text: lui.Text_Index,

    control_animation: lui.Animation_Index,
}

Container_State_Flag :: enum {
	Collapsed,
	Dragged,
}

Container_State :: struct {
	flags: bit_set[Container_State_Flag],
}

Radio_State :: struct {
	selected: lui.Hash,
	counter: int,
}

State :: struct {
	container_state:    map[lui.Hash]Container_State,
	radio_state:        map[lui.Hash]Radio_State,
	active_radio_state: ^Radio_State,
	text_user_data:     rawptr
}

theme := Theme{}
global_state := State{}

fill_spacing :: proc(s: ^Spacing) {
    s.xs = 2
    s.sm = 4
    s.md = 8
    s.lg = 16
    s.xl = 24
}

fill_palette :: proc(p: ^Color_Palette) {
    p.bg_base       = lui.color_from_hex(0xFF_38_35_2D)
    p.bg_elevated   = lui.color_from_hex(0xFF_44_3F_34)
    p.bg_sunken     = lui.color_from_hex(0xFF_2D_2A_23)
    p.fg_primary    = lui.color_from_hex(0xFF_AA_C6_D3)
    p.fg_secondary  = lui.color_from_hex(0xFF_80_C0_A7)
    p.fg_muted      = lui.color_from_hex(0xFF_89_93_85)
    p.accent        = lui.color_from_hex(0xFF_B3_BB_7F)
    p.accent_hover  = lui.color_from_hex(0xFF_92_C0_83)
    p.accent_press  = lui.color_from_hex(0xFF_75_98_E6)
    p.border_subtle = lui.color_from_hex(0xFF_5F_5C_47)
    p.border_strong = lui.color_from_hex(0xFF_89_93_85)
    p.danger        = lui.color_from_hex(0xFF_80_7E_E6)
    p.warning       = lui.color_from_hex(0xFF_7F_BC_DB)
    p.success       = lui.color_from_hex(0xFF_80_C0_A7)
}

build_theme :: proc(ctx: ^lui.Core_Context) {
    fill_palette(&theme.palette)
    fill_spacing(&theme.spacing)

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
        color  = p.bg_base,
        border = {color = p.border_strong, thickness = 1, radius = 6},
        text   = {color = p.fg_primary, font = f.f_md},
    })

    accent := lui.create_style(ctx, {
        color  = p.accent,
        border = {color = p.accent_hover, thickness = 1, radius = 6},
        text   = {color = p.bg_sunken, font = f.f_md},
    })

    accent_hover := lui.create_style(ctx, {
        color  = p.accent_hover,
        border = {color = p.accent, thickness = 1, radius = 6},
        text   = {color = p.bg_sunken, font = f.f_md},
    })

    accent_press := lui.create_style(ctx, {
        color  = p.accent_press,
        border = {color = p.accent_hover, thickness = 1, radius = 6},
        text   = {color = p.bg_sunken, font = f.f_md},
    })

    danger := lui.create_style(ctx, {
        color  = p.danger,
        border = {color = p.danger, thickness = 1, radius = 6},
        text   = {color = p.bg_sunken, font = f.f_md},
    })

    text_md := lui.create_style(ctx, {
        color  = 0,
        border = {},
        text   = {color = p.fg_primary, font = f.f_md},
    })

    text_sm := lui.create_style(ctx, {
        color  = 0,
        border = {},
        text   = {color = p.fg_secondary, font = f.f_sm},
    })

    track := lui.create_style(ctx, {
        color  = p.bg_sunken,
        border = {color = p.border_subtle, thickness = 1, radius = 999},
        text   = {color = p.fg_primary, font = f.f_md},
    })

    track_fill := lui.create_style(ctx, {
        color  = p.accent,
        border = {color = p.accent, thickness = 1, radius = 999},
        text   = {color = p.bg_sunken, font = f.f_md},
    })

    thumb := lui.create_style(ctx, {
        color  = p.fg_primary,
        border = {color = p.border_strong, thickness = 1, radius = 999},
    })

    thumb_h := lui.create_style(ctx, {color = p.accent_hover, border = {radius = 999}})
    thumb_a := lui.create_style(ctx, {color = p.accent_press, border = {radius = 999}})

    input := lui.create_style(ctx, {
        color  = p.bg_sunken,
        border = {color = p.border_subtle, thickness = 1, radius = 6},
        text   = {color = p.fg_primary, font = f.f_md},
    })

    tooltip := lui.create_style(ctx, {
        color  = p.bg_base,
        border = {color = p.border_strong, thickness = 1, radius = 4},
        text   = {color = p.fg_primary, font = f.f_sm},
    })

    si :: proc(normal, hover, press: lui.Style_Index) -> Interaction_Style {
        return {.Normal = normal, .Hover = hover, .Press = press}
    }

    {
   		body := lui.create_style(ctx, {color = p.bg_base, border = {color = p.border_subtle, thickness = {1, {0, 1}}, radius = {0, 0, 4, 4}}})
     	title_bar := lui.create_style(ctx, {color = p.bg_elevated, border = {color = p.border_subtle, thickness = {1, {1, 0}}, radius = {4, 4, 0, 0}}})
        title    := lui.create_style(ctx, {text = {color = p.fg_primary, font = f.f_md}})
      	button := lui.create_style(ctx, {
       		color = p.bg_elevated,
         	border = {color = p.border_subtle, thickness = {{1, 0}, {1, 0}}, radius = {4, 0, 0, 0}},
          	text = {color = p.fg_primary, font = f.f_md}}
       )
        button_h := lui.create_style(ctx, {color = p.accent_hover, border = {radius = {4, 0, 4, 0}}, text = {color = p.bg_elevated, font = f.f_md}})
        button_p := lui.create_style(ctx, {color = p.accent_press, border = {radius = {4, 0, 4, 0}}, text = {color = p.bg_elevated, font = f.f_md}})

    	theme.container.body      = si(body, body, body)
    	theme.container.title     = si(title, title, title)
    	theme.container.button    = si(button, button_h, button_p)
    	theme.container.title_bar = si(title_bar, title_bar, title_bar)
    }

    theme.button.style[.Normal]   = si(accent, accent_hover, accent_press)
    theme.button.style[.Focused]  = si(surface, surface_hover, accent_press)
    theme.button.style[.Disabled] = si(danger, danger, accent_press)

    theme.button.padding = {
        {s.md, s.sm},
        {s.lg, s.md},
    }

    theme.slider.thumb        = si(thumb, thumb, accent_press)
    theme.slider.track        = si(track, track, track)
    theme.slider.track_fill   = si(track_fill, track_fill, track_fill)
    theme.slider.thumb_size   = {14, 14}
    theme.slider.track_height = 4

    //==============================================================
    // checkbox
    //==============================================================

    theme.checkbox.size         = {18, 18}
    theme.checkbox.check_on     = si(accent, accent_hover, accent_press)
    theme.checkbox.check_off    = si(surface, surface_hover, accent_press)
    theme.checkbox.check_holder = si(surface, surface, surface)

    //==============================================================
    // toggle
    //==============================================================

    theme.toggle.track_on  = si(track_fill, track_fill, track_fill)
    theme.toggle.thumb_on  = si(thumb, thumb, accent_press)
    theme.toggle.track_off = si(track, track, track)
    theme.toggle.thumb_off = si(thumb, thumb, thumb)
    theme.toggle.size      = {18, 18}

    //==============================================================
    // radio
    //==============================================================

    theme.radio.size            = {18, 18}
    theme.radio.item_toggle_on  = si(accent, accent_hover, accent_press)
    theme.radio.item_toggle_off = si(surface, surface, surface)

    //==============================================================
    // label
    //==============================================================

    theme.label.md = si(text_md, text_md, text_md)
    theme.label.sm = si(text_sm, text_sm, text_sm)

    //==============================================================
    // progress bar
    //==============================================================

    theme.progress_bar.track        = si(track, track, track)
    theme.progress_bar.fill         = si(track_fill, track_fill, track_fill)
    theme.progress_bar.track_height = 8

    //==============================================================
    // text box
    //==============================================================

    theme.text_box.style = si(input, surface_hover, accent_press)

    //==============================================================
    // tooltip
    //==============================================================

    theme.tooltip.style = si(tooltip, tooltip, tooltip)    //==============================================================
    // misc
    //==============================================================

    theme.container_collapsed_text   = lui.create_text(ctx, lui.text("▷", .None))
    theme.container_uncollapsed_text = lui.create_text(ctx, lui.text("▽", .None))

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
	cont_state, _ := &global_state.container_state[cont.hash]
	if cont_state == nil {
		global_state.container_state[cont.hash] = {}
		cont_state = &global_state.container_state[cont.hash]
	}
	contf := lui.Form{}
	contf.layout.sizing = {lui.grow(), lui.fit()}
	contf.layout.direction = .Y
	lui.submit_widget(ctx, cont, contf)

	lui.push_parent(ctx, cont)

	cont_bar := lui.reserve_widget(ctx, "__internal_cont_bar")
	cont_barf := lui.Form{}
	cont_barf.layout.sizing = {lui.grow(), lui.fit()}
	cont_barf.style = resolve_style(ctx, cont_bar, theme.container.title_bar)
	lui.submit_widget(ctx, cont_bar, cont_barf)

	lui.push_parent(ctx, cont_bar)

	cont_collapse := lui.reserve_widget(ctx, "__internal_cont_collapse")

	cont_collapse_event := lui.get_widget_mouse_events(ctx, cont_collapse, .Left)
	if .Clicked in cont_collapse_event { cont_state.flags ~= {.Collapsed} }

	cont_collapsef := lui.Form{}
	cont_collapsef.layout.sizing = {lui.fit(), lui.fit()}
	cont_collapsef.layout.padding = {theme.spacing.sm, 0}
	cont_collapsef.text = theme.container_uncollapsed_text if .Collapsed not_in cont_state.flags else theme.container_collapsed_text
	cont_collapsef.style = resolve_style(ctx, cont_collapse, theme.container.button)

	lui.submit_widget(ctx, cont_collapse, cont_collapsef)

	lui.push_parent(ctx, cont_collapse)
	tooltip(ctx, "__internal_cont_collapse_tooltip", cont_collapse, "Collapse Container")
	lui.pop_parent(ctx)


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
	contif.style = resolve_style(ctx, conti, theme.container.body)
	lui.submit_widget(ctx, conti, contif)
	lui.push_parent(ctx, conti)

	return true
}

end_container :: proc(ctx: ^lui.Core_Context) {
	lui.pop_parent(ctx)
	lui.pop_parent(ctx)
}

button :: proc(ctx: ^lui.Core_Context, key: lui.Key, label: string, varient: Varient = .Normal) -> lui.Mouse_Events {
	button := lui.reserve_widget(ctx, key)
	buttonf := lui.Form{}
	buttonf.layout.sizing = lui.sizing()
	buttonf.layout.placement = {.Center, .Center}
	buttonf.text = lui.create_text(ctx, lui.text(label, .None))
	buttonf.style = resolve_style(ctx, button, theme.button.style[varient])
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
	togglehf.style = resolve_style(ctx, toggleh, theme.toggle.track_on)
	togglehf.layout.placement.x = .Negative if !state^ else .Positive
	lui.submit_widget(ctx, toggleh, togglehf)

	lui.push_parent(ctx, toggleh)

	togglec := lui.reserve_widget(ctx, "__internal_toggle_control")
	togglecf := lui.Form{}
	togglecf.event_flags = {.Disable_Hover}
	togglecf.layout.sizing = lui.sizing(lui.fixed(theme.toggle.size.x), lui.fixed(theme.toggle.size.y))
	togglecf.style = resolve_style(ctx, togglec, theme.toggle.thumb_on if state^ else theme.toggle.thumb_off)
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

	radio_state, ok := &global_state.radio_state[holder.hash]
	if !ok {
		global_state.radio_state[holder.hash] = {}
		radio_state = &global_state.radio_state[holder.hash]
	}
	global_state.active_radio_state = radio_state
}

end_radio :: proc(ctx: ^lui.Core_Context) {
	lui.pop_parent(ctx)
	global_state.active_radio_state.counter = 0
	global_state.active_radio_state = nil
}

radio_item :: proc(ctx: ^lui.Core_Context, item_label: string) -> bool {
	holder := lui.reserve_widget(ctx, global_state.active_radio_state.counter)
	global_state.active_radio_state.counter += 1

	holderf := lui.Form{}
	holderf.layout.sizing = lui.sizing()
	holderf.layout.child_gap = theme.spacing.sm
	lui.submit_widget(ctx, holder, holderf)
	lui.push_parent(ctx, holder)

	control := lui.reserve_widget(ctx, "__internal_radio_control")

	events := lui.get_widget_mouse_events(ctx, control, .Left)
	if .Clicked in events {
		global_state.active_radio_state.selected = holder.hash
	}

	active := holder.hash == global_state.active_radio_state.selected

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
	trackf.layout.sizing = {lui.grow(), lui.fixed(theme.slider.track_height)}
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
	contf.text = lui.create_text(ctx, lui.text(text, wrap, user_data = global_state.text_user_data))
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

    contf.override = \
        lui.create_override(ctx, {offset = {lui.percent(0.5), lui.percent_self(-1)}}, {offset = {lui.percent_self(-0.5), lui.fixed(-theme.spacing.sm)}}) if py - th >= 0 else \
        lui.create_override(ctx, {offset = {lui.percent(0.5), lui.percent(1)}}, {offset = {lui.percent_self(-0.5), lui.fixed( theme.spacing.sm)}}) if py + ph + th <= wh else \
        lui.create_override(ctx, {offset = {lui.percent(1), lui.percent(0.5)}}, {offset = {lui.fixed( theme.spacing.sm), lui.percent_self(-0.5)}}) if px + pw + tw <= ww else \
        lui.create_override(ctx, {offset = {lui.percent_self(-1), lui.percent(0.5)}}, {offset = {lui.fixed(-theme.spacing.sm), lui.percent_self(-0.5)}})

    lui.submit_widget(ctx, cont, contf)
}
