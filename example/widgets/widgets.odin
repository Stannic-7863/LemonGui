package widgets

import ui "../../"
import "core:fmt"

// Button [DONE]
// Slider [DONE]
// Checkbox [DONE]
// Switch [DONE]
// Progress bar [DONE]
// Tooltip [DONE]
// Radio button [DONE]
// Dropdown
// Separator
// Text input
// Multiline text box
// Scrollable container
// Image widget
// Slider (range)
// Modal / Popup

Ui_State :: struct {
	radio_buttons: [dynamic]Radio_Button_Info,
}

Radio_Button_Info :: struct {
	widget: ui.Widget_Index,
	toggle: ^bool,
}

Ui_Interaction_State :: enum {
	Default,
	Hovered,
	Active,
	Disabled,
}

Element_Colors :: [Ui_Interaction_State]ui.Color
Element_Vec4f32 :: [Ui_Interaction_State]ui.Vec4f32
Element_Axis_Vec2f32 :: [Ui_Interaction_State][ui.Axis]ui.Vec2f32
Element_Style :: [Ui_Interaction_State]ui.Style_Index

Theme :: struct {
	global_color:            Element_Colors,
	global_border_thickness: Element_Axis_Vec2f32,
	global_border_radius:    Element_Vec4f32,
	label_text_color:        Element_Colors,
	container_color:         Element_Colors,
	container_padding:       Element_Axis_Vec2f32,
	control_size:            ui.Vec2f32,
	font:                    rawptr,
	bar_minimum_width:       f32,
	bar_height:              f32,
	container_child_gap:     f32,
	font_size:               f32,
	_label_style:            Element_Style,
	_container_style:        Element_Style,
	_control_style:          Element_Style,
	_handle_style:           Element_Style,
}

ui_state := Ui_State{}

theme := Theme {
	global_color = Element_Colors {
		.Default = ui.Color{80, 73, 69, 255},
		.Hovered = ui.Color{215, 153, 33, 255},
		.Active = ui.Color{69, 133, 136, 255},
		.Disabled = ui.Color{50, 48, 47, 255},
	},
	global_border_thickness = Element_Axis_Vec2f32 {
		.Default = ui.axis_vec2f32({2, 2}, {2, 2}),
		.Hovered = ui.axis_vec2f32({2, 2}, {2, 2}),
		.Active = ui.axis_vec2f32({2, 2}, {2, 2}),
		.Disabled = ui.axis_vec2f32({2, 2}, {2, 2}),
	},
	global_border_radius = Element_Vec4f32 {
		.Default = ui.Vec4f32{8, 8, 8, 8},
		.Hovered = ui.Vec4f32{8, 8, 8, 8},
		.Active = ui.Vec4f32{8, 8, 8, 8},
		.Disabled = ui.Vec4f32{8, 8, 8, 8},
	},
	label_text_color = Element_Colors {
		.Default = ui.Color{235, 219, 178, 255},
		.Hovered = ui.Color{213, 196, 161, 255},
		.Active = ui.Color{251, 241, 199, 255},
		.Disabled = ui.Color{146, 131, 116, 255},
	},
	container_color = Element_Colors {
		.Default = ui.Color{29, 32, 33, 255},
		.Hovered = ui.Color{40, 40, 40, 255},
		.Active = ui.Color{50, 48, 47, 255},
		.Disabled = ui.Color{29, 32, 33, 255},
	},
	container_padding = Element_Axis_Vec2f32 {
		.Default = ui.axis_vec2f32({12, 12}, {12, 12}),
		.Hovered = ui.axis_vec2f32({12, 12}, {12, 12}),
		.Active = ui.axis_vec2f32({12, 12}, {12, 12}),
		.Disabled = ui.axis_vec2f32({12, 12}, {12, 12}),
	},
	control_size = ui.Vec2f32{16, 16},
	bar_minimum_width = 64,
	bar_height = 8,
	container_child_gap = 12,
	font_size = 14,
	_label_style = Element_Style{},
	_container_style = Element_Style{},
	_control_style = Element_Style{},
	_handle_style = Element_Style{},
}


build_themes :: proc(ctx: ^ui.Core_Context) {
	default_border := ui.Border_Style {
		color     = theme.global_color[.Default],
		radius    = theme.global_border_radius[.Default],
		thickness = theme.global_border_thickness[.Default],
	}
	active_border := ui.Border_Style {
		color     = theme.global_color[.Active],
		radius    = theme.global_border_radius[.Active],
		thickness = theme.global_border_thickness[.Active],
	}
	hovered_border := ui.Border_Style {
		color     = theme.global_color[.Hovered],
		radius    = theme.global_border_radius[.Hovered],
		thickness = theme.global_border_thickness[.Hovered],
	}
	disabled_border := ui.Border_Style {
		color     = theme.global_color[.Disabled],
		radius    = theme.global_border_radius[.Disabled],
		thickness = theme.global_border_thickness[.Disabled],
	}

	theme._label_style[.Default] = ui.create_style(
		ctx,
		{
			text = {color = theme.label_text_color[.Default], font = theme.font, font_size = theme.font_size},
			padding = ui.axis_vec2f32({0, 0}, {0, 0}),
		},
	)
	theme._label_style[.Hovered] = ui.create_style(
		ctx,
		{
			text = {color = theme.label_text_color[.Hovered], font = theme.font, font_size = theme.font_size},
			padding = ui.axis_vec2f32({0, 0}, {0, 0}),
		},
	)
	theme._label_style[.Active] = ui.create_style(
		ctx,
		{
			text = {color = theme.label_text_color[.Active], font = theme.font, font_size = theme.font_size},
			padding = ui.axis_vec2f32({0, 0}, {0, 0}),
		},
	)

	theme._container_style[.Default] = ui.create_style(
		ctx,
		{color = theme.container_color[.Default], border = default_border, padding = theme.container_padding[.Default]},
	)
	theme._container_style[.Hovered] = ui.create_style(
		ctx,
		{color = theme.container_color[.Hovered], border = hovered_border, padding = theme.container_padding[.Hovered]},
	)
	theme._container_style[.Active] = ui.create_style(
		ctx,
		{color = theme.container_color[.Active], border = active_border, padding = theme.container_padding[.Active]},
	)

	theme._control_style[.Default] = ui.create_style(
		ctx,
		{color = theme.container_color[.Default], border = default_border, padding = ui.axis_vec2f32({0, 0}, {0, 0})},
	)
	theme._control_style[.Hovered] = ui.create_style(
		ctx,
		{color = theme.container_color[.Hovered], border = hovered_border, padding = ui.axis_vec2f32({0, 0}, {0, 0})},
	)
	theme._control_style[.Active] = ui.create_style(
		ctx,
		{color = theme.container_color[.Active], border = active_border, padding = ui.axis_vec2f32({0, 0}, {0, 0})},
	)

	theme._handle_style[.Default] = ui.create_style(
		ctx,
		{color = theme.global_color[.Default], border = default_border, padding = ui.axis_vec2f32({0, 0}, {0, 0})},
	)
	theme._handle_style[.Hovered] = ui.create_style(
		ctx,
		{color = theme.global_color[.Hovered], border = hovered_border, padding = ui.axis_vec2f32({0, 0}, {0, 0})},
	)
	theme._handle_style[.Active] = ui.create_style(
		ctx,
		{color = theme.global_color[.Active], border = active_border, padding = ui.axis_vec2f32({0, 0}, {0, 0})},
	)
}

control :: proc(
	ctx: ^ui.Core_Context,
	id: ui.Keying_Id,
	on: bool = false,
	flags: ui.Event_Flags = {},
	override: ui.Override = {},
) -> (
	widget_index: ui.Widget_Index,
	events: ui.Mouse_Events,
) {
	control_widget := ui.create_widget(
		ctx,
		id,
		ui.layout(ui.sizing(ui.fixed(theme.control_size.x), ui.fixed(theme.control_size.y))),
		flags,
		override = ui.create_override(ctx, override),
		style = theme._control_style[.Default] if !on else theme._control_style[.Active],
	)
	if ui.is_widget_hovered(ctx, control_widget) {
		control_widget.style = theme._control_style[.Hovered]
	}
	if ui.is_widget_active(ctx, control_widget) {
		control_widget.style = theme._control_style[.Active]
	}

	return control_widget.index, ui.get_widget_mouse_events_all(ctx, control_widget)
}

begin_handle :: proc(
	ctx: ^ui.Core_Context,
	id: ui.Keying_Id,
	flags: ui.Event_Flags,
	direction: ui.Axis = .X,
	alignment: [ui.Axis]ui.Alignment,
	size_override: ui.Vec2f32 = {},
) -> ui.Widget_Index {
	size := size_override if size_override != {} else {theme.bar_minimum_width, theme.bar_height}
	sizing := ui.sizing(ui.grow(size.x), ui.fixed(size.y)) if direction == .X else ui.sizing(ui.fixed(size.y), ui.grow(size.x))
	handle_widget := ui.create_widget(ctx, id, ui.layout(sizing, alignment), flags, style = theme._handle_style[.Default])
	ui.push_parent(ctx, handle_widget)
	return handle_widget.index
}

end_handle :: proc(ctx: ^ui.Core_Context) {
	ui.pop_parent(ctx)
}

spacing :: proc(ctx: ^ui.Core_Context, id: ui.Keying_Id, direction: ui.Axis) {
	switch direction {
	case .X:
		ui.create_widget(ctx, id, ui.layout(ui.sizing(ui.grow(), ui.fit())))
	case .Y:
		ui.create_widget(ctx, id, ui.layout(ui.sizing(ui.fit(), ui.grow())))
	}
}

bar :: proc(ctx: ^ui.Core_Context, id: ui.Keying_Id, progress: f32, direction: ui.Axis) {
	bar: ^ui.Widget
	flags := ui.flags(x = {.No_Size_Propagation, .No_Positioning_Relative}, y = {.No_Size_Propagation, .No_Positioning_Relative})
	switch direction {
	case .X:
		bar = ui.create_widget(ctx, "progress bar", ui.layout(ui.sizing(ui.fixed(0), ui.fixed(theme.bar_height))), {.Disable_Hover})
		bar.override = ui.create_override(ctx, {expand = ui.expand(x = ui.percent(progress)), flags = flags})
	case .Y:
		bar = ui.create_widget(ctx, "progress bar", ui.layout(ui.sizing(ui.fixed(theme.bar_height), ui.fixed(0))), {.Disable_Hover})
		bar.override = ui.create_override(ctx, {expand = ui.expand(y = ui.percent(progress)), flags = flags})
	}
	bar.style = theme._handle_style[.Active]
}

ui_label :: proc(ctx: ^ui.Core_Context, id: ui.Keying_Id, label: string, wrap: ui.Text_Wrap_Mode = .None, preferred_min: f32 = 0) {
	ui.create_widget(ctx, id, ui.text(label, wrap, preferred_min = preferred_min), {.Disable_Hover}, style = theme._label_style[.Default])
}

begin_container :: proc(
	ctx: ^ui.Core_Context,
	id: ui.Keying_Id,
	direction: ui.Axis = .X,
	flags: ui.Event_Flags = {},
	content_alignment: [ui.Axis]ui.Alignment = {.X = .Negative, .Y = .Negative},
	no_theme_default: bool = false,
	no_theme_hover: bool = false,
	no_theme_active: bool = false,
) -> (
	widget_index: ui.Widget_Index,
	events: ui.Mouse_Events,
	is_hovered: bool,
	is_active: bool,
) {
	container := ui.create_widget(
		ctx,
		id,
		ui.layout(ui.sizing(ui.fit(), ui.fit()), content_alignment, theme.container_child_gap, direction),
		flags,
		style = theme._container_style[.Default] if !no_theme_default else 0,
	)
	widget_index = container.index
	events = ui.get_widget_mouse_events_all(ctx, container)

	if ui.is_widget_hovered(ctx, container) && !no_theme_hover {
		container.style = theme._container_style[.Hovered]
		is_hovered = true
	}

	if ui.is_widget_active(ctx, container) && !no_theme_active {
		container.style = theme._container_style[.Active]
		is_active = true
	}

	ui.push_parent(ctx, container)
	return
}

end_container :: proc(ctx: ^ui.Core_Context) {
	ui.pop_parent(ctx)
}

tooltip :: proc(ctx: ^ui.Core_Context, id: ui.Keying_Id, label: string, widget_index: ui.Widget_Index) {
	attached := ui.get_widget(ctx, widget_index)
	tooltip_position := attached.resolved.position + {attached.resolved.size.x + theme.container_padding[.Default][.X].x, 0}
	holder := ui.create_widget(ctx, id, ui.layout(ui.sizing(ui.fit(), ui.fit())), style = theme._container_style[.Default])
	holder.override = ui.create_override(
		ctx,
		{
			flags = ui.flags(~{.No_Positioning_Relative}, ~{.No_Positioning_Relative}),
			offset = ui.offset(ui.fixed(tooltip_position.x), ui.fixed(tooltip_position.y)),
		},
	)

	ui.push_parent(ctx, holder)
	ui_label(ctx, "tooltip_text", label, .Words, 256)
	ui.pop_parent(ctx)
}

button :: proc(ctx: ^ui.Core_Context, id: ui.Keying_Id, label: string, tooltip_text: string = "") -> (ui.Mouse_Events, ui.Widget_Index) {
	widget_index, events, is_hovered, _ := begin_container(ctx, id, .X, {.Lock_Active, .Lock_Hover})
	ui_label(ctx, "button label", label)
	if is_hovered && tooltip_text != "" {
		tooltip(ctx, "button tooltip", tooltip_text, widget_index)
	}
	end_container(ctx)
	return events, widget_index
}

slider :: proc(ctx: ^ui.Core_Context, id: ui.Keying_Id, label: string, value: ^$T, minimum, maximum, step: T, direction: ui.Axis = .X) {
	begin_container(ctx, id, direction, {.Disable_Active}, ui.alignment(.Center, .Center), no_theme_hover = true)
	{
		ui_label(ctx, "slider label", label)
		begin_container(ctx, id, direction, {.Disable_Hover}, ui.alignment(.Center, .Center), no_theme_default = true)
		{
			ui_label(ctx, "slider min label", fmt.tprintf("%v", minimum))

			handle_index := begin_handle(ctx, "slider handle", {.Disable_Hover}, direction, ui.alignment(.Center, .Center))
			offset_value := f32(value^ - minimum) / f32(maximum - minimum)
			bar(ctx, "slider progress", offset_value, direction)
			offset_value -= 0.5
			knob_offset := ui.offset(ui.percent(offset_value)) if direction == .X else ui.offset(y = ui.percent(offset_value))
			knob_index, _ := control(ctx, "slider knob", false, {.Lock_Active, .Lock_Hover}, {offset = knob_offset})

			end_handle(ctx)

			if ui.is_widget_active(ctx, ui.get_widget(ctx, knob_index)) {
				handle_widget := ui.get_widget(ctx, handle_index)
				pos_rel, pos_min := ctx.mouse.position[direction], handle_widget.resolved.position[direction]
				control_parameter := (pos_rel - pos_min) / (handle_widget.resolved.size[direction])
				control_parameter -= 1

				value^ = T(f32(maximum - minimum) * control_parameter + f32(maximum))
			}

			value^ = min(value^, maximum)
			value^ = max(value^, minimum)

			ui_label(ctx, "slider max label", fmt.tprintf("%v", maximum))
		}
		end_container(ctx)
	}
	end_container(ctx)
}

toggle :: proc(ctx: ^ui.Core_Context, id: ui.Keying_Id, label: string, toggle_bool: ^bool) {
	_, events, _, _ := begin_container(ctx, id, .X, {}, ui.alignment(.Center, .Center), no_theme_active = true)
	control(ctx, "toggle control", toggle_bool^, {.Disable_Hover})
	ui_label(ctx, "toggle label", label)
	if .Clicked in events[.Left] {
		toggle_bool^ = !toggle_bool^
	}
	end_container(ctx)
}

begin_radio :: proc(ctx: ^ui.Core_Context, id: ui.Keying_Id) {
	begin_container(ctx, id, .Y, {.Disable_Active}, ui.alignment(.Center, .Center), no_theme_hover = true)

}

end_radio :: proc(ctx: ^ui.Core_Context) {
	toggled_index: int = -1

	for radio_info, index in ui_state.radio_buttons {
		if radio_info.toggle^ {
			toggled_index = index
			break
		}
	}

	for radio_info in ui_state.radio_buttons {
		radio_widget := ui.get_widget(ctx, radio_info.widget)
		events := ui.get_widget_mouse_events(ctx, radio_widget, .Left)
		if .Clicked in events {
			radio_info.toggle^ = !radio_info.toggle^
			if toggled_index != -1 {
				ui_state.radio_buttons[toggled_index].toggle^ = false
			}
		}
	}

	clear(&ui_state.radio_buttons)

	end_container(ctx)
}

radio :: proc(ctx: ^ui.Core_Context, label: string, toggle: ^bool) {
	begin_container(ctx, len(ui_state.radio_buttons), .X, {.Disable_Hover}, no_theme_default = true)
	control_index, _ := control(ctx, "radio control", toggle^)
	append(&ui_state.radio_buttons, Radio_Button_Info{widget = control_index, toggle = toggle})
	ui_label(ctx, "radio label", label)
	end_container(ctx)
}

ui_switch :: proc(ctx: ^ui.Core_Context, id: ui.Keying_Id, label: string, switch_bool: ^bool) {
	_, events, _, _ := begin_container(ctx, id, .X, {}, ui.alignment(.Center, .Center), no_theme_active = true)

	ui_label(ctx, "switch label", label)

	alignment := ui.alignment(.Positive, .Center) if switch_bool^ else ui.alignment(.Negative, .Center)

	begin_handle(ctx, "switch handle", {.Disable_Hover}, .X, alignment, {28, 8})

	control(ctx, "switch control", switch_bool^, {.Disable_Hover})

	end_handle(ctx)

	if .Clicked in events[.Left] {
		switch_bool^ = !switch_bool^
	}

	end_container(ctx)
}

progress_bar :: proc(ctx: ^ui.Core_Context, id: ui.Keying_Id, label: string, progress: f32, direction: ui.Axis = .X) {
	begin_container(ctx, id, .Y, {}, ui.alignment(.Center, .Center), no_theme_hover = true, no_theme_active = true)

	ui_label(ctx, "progress label", fmt.tprintf("%s [%5.2f%s]", label, progress * 100, "%"))

	begin_handle(ctx, "progress handle", {.Disable_Hover}, direction, ui.alignment(.Center, .Center))

	bar(ctx, "progress", progress, direction)

	end_handle(ctx)

	end_container(ctx)
}
