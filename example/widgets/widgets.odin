package widgets

import ui "../../"
import "core:fmt"

// Button [DONE]
// Slider [DONE]
// Checkbox [DONE]
// Switch [DONE]
// Progress bar [DONE]
// Radio button
// Text input
// Multiline text box
// Dropdown
// Tooltip
// Separator
// Scrollable container
// Image widget
// Slider (range)
// Modal / Popup

Element_Colors :: struct {
	default, hovered, active, disabled: ui.Color,
}

Element_Vec4f32 :: struct {
	default, hovered, active, disabled: ui.Vec4f32,
}

Element_Axis_Vec2f32 :: struct {
	default, hovered, active, disabled: [ui.Axis]ui.Vec2f32,
}

Element_Style :: struct {
	default, hovered, active: ui.Style_Index,
}

Theme :: struct {
	label_text_color:           Element_Colors,
	container_border_color:     Element_Colors,
	container_background_color: Element_Colors,
	container_border_radius:    Element_Vec4f32,
	container_padding:          Element_Axis_Vec2f32,
	container_border_thickness: Element_Axis_Vec2f32,
	font:                       rawptr,
	container_child_gap:        f32,
	font_size:                  f32,
	_label_style:               Element_Style,
	_container_style:           Element_Style,
	_container_filled_style:    Element_Style,
}

theme := Theme {
	label_text_color = Element_Colors {
		default  = ui.Color{235, 219, 178, 255}, // fg1
		hovered  = ui.Color{213, 196, 161, 255}, // fg2
		active   = ui.Color{251, 241, 199, 255}, // fg0
		disabled = ui.Color{146, 131, 116, 255}, // gray
	},
	container_border_color = Element_Colors {
		default  = ui.Color{80, 73, 69, 255}, // bg4
		hovered  = ui.Color{215, 153, 33, 255}, // yellow
		active   = ui.Color{69, 133, 136, 255}, // blue
		disabled = ui.Color{50, 48, 47, 255}, // bg2
	},
	container_background_color = Element_Colors {
		default  = ui.Color{29, 32, 33, 255}, // bg0_h
		hovered  = ui.Color{40, 40, 40, 255}, // bg1
		active   = ui.Color{50, 48, 47, 255}, // bg2
		disabled = ui.Color{29, 32, 33, 255}, // bg0_h
	},
	container_border_radius = Element_Vec4f32 {
		default = ui.Vec4f32{8, 8, 8, 8},
		hovered = ui.Vec4f32{8, 8, 8, 8},
		active = ui.Vec4f32{8, 8, 8, 8},
		disabled = ui.Vec4f32{8, 8, 8, 8},
	},
	container_padding = Element_Axis_Vec2f32 {
		default = ui.axis_vec2f32({12, 12}, {10, 10}),
		hovered = ui.axis_vec2f32({12, 12}, {10, 10}),
		active = ui.axis_vec2f32({12, 12}, {10, 10}),
		disabled = ui.axis_vec2f32({12, 12}, {10, 10}),
	},
	container_border_thickness = Element_Axis_Vec2f32 {
		default = ui.axis_vec2f32({2, 2}, {2, 2}),
		hovered = ui.axis_vec2f32({2, 2}, {2, 2}),
		active = ui.axis_vec2f32({2, 2}, {2, 2}),
		disabled = ui.axis_vec2f32({2, 2}, {2, 2}),
	},
}


build_themes :: proc(ctx: ^ui.Core_Context) {
	theme._label_style.default = ui.create_style(
		ctx,
		{text = {color = theme.label_text_color.default, font = theme.font, font_size = theme.font_size}, padding = ui.axis_vec2f32({4, 4}, {2, 2})},
	)
	theme._label_style.hovered = ui.create_style(
		ctx,
		{text = {color = theme.label_text_color.hovered, font = theme.font, font_size = theme.font_size}, padding = ui.axis_vec2f32({4, 4}, {2, 2})},
	)
	theme._label_style.active = ui.create_style(
		ctx,
		{text = {color = theme.label_text_color.active, font = theme.font, font_size = theme.font_size}, padding = ui.axis_vec2f32({4, 4}, {2, 2})},
	)

	theme._container_style.hovered = ui.create_style(
		ctx,
		{
			color = theme.container_background_color.hovered,
			border = {
				color = theme.container_border_color.hovered,
				radius = theme.container_border_radius.hovered,
				thickness = theme.container_border_thickness.hovered,
			},
			padding = theme.container_padding.hovered,
		},
	)
	theme._container_style.active = ui.create_style(
		ctx,
		{
			color = theme.container_background_color.active,
			border = {
				color = theme.container_border_color.active,
				radius = theme.container_border_radius.active,
				thickness = theme.container_border_thickness.active,
			},
			padding = theme.container_padding.active,
		},
	)
	theme._container_style.default = ui.create_style(
		ctx,
		{
			color = theme.container_background_color.default,
			border = {
				color = theme.container_border_color.default,
				radius = theme.container_border_radius.default,
				thickness = theme.container_border_thickness.default,
			},
			padding = theme.container_padding.default,
		},
	)

	theme._container_filled_style.default = ui.create_style(
		ctx,
		{
			color = theme.container_border_color.default,
			border = {
				color = theme.container_border_color.default,
				radius = theme.container_border_radius.default,
				thickness = theme.container_border_thickness.default,
			},
			padding = theme.container_padding.default,
		},
	)
	theme._container_filled_style.hovered = ui.create_style(
		ctx,
		{
			color = theme.container_border_color.hovered,
			border = {
				color = theme.container_border_color.hovered,
				radius = theme.container_border_radius.hovered,
				thickness = theme.container_border_thickness.hovered,
			},
			padding = theme.container_padding.hovered,
		},
	)
	theme._container_filled_style.active = ui.create_style(
		ctx,
		{
			color = theme.container_border_color.active,
			border = {
				color = theme.container_border_color.active,
				radius = theme.container_border_radius.active,
				thickness = theme.container_border_thickness.active,
			},
			padding = theme.container_padding.active,
		},
	)
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
		bar = ui.create_widget(ctx, "progress bar", ui.layout(ui.sizing(ui.fixed(0), ui.fixed(8))), {.Disable_Hover})
		bar.override = ui.create_override(ctx, {expand = ui.expand(x = ui.percent(progress)), flags = flags})
	case .Y:
		bar = ui.create_widget(ctx, "progress bar", ui.layout(ui.sizing(ui.fixed(8), ui.fixed(0))), {.Disable_Hover})
		bar.override = ui.create_override(ctx, {expand = ui.expand(y = ui.percent(progress)), flags = flags})
	}
	bar.style = theme._container_filled_style.active
}

ui_label :: proc(ctx: ^ui.Core_Context, id: ui.Keying_Id, label: string) {
	ui.create_widget(ctx, id, ui.text(label, .None), {.Disable_Hover}, style = theme._label_style.default)
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
	ui.Widget_Index,
	ui.Mouse_Events,
) {
	container := ui.create_widget(
		ctx,
		id,
		ui.layout(ui.sizing(ui.fit(), ui.fit()), content_alignment, theme.container_child_gap, direction),
		flags,
		style = theme._container_style.default if !no_theme_default else 0,
	)
	events := ui.get_widget_mouse_events_all(ctx, container)

	if ui.is_widget_hovered(ctx, container) && !no_theme_hover {
		container.style = theme._container_style.hovered
	}

	if ui.is_widget_active(ctx, container) && !no_theme_active {
		container.style = theme._container_style.active
	}

	ui.push_parent(ctx, container)
	return container.index, events
}

end_container :: proc(ctx: ^ui.Core_Context) {
	ui.pop_parent(ctx)
}

button :: proc(ctx: ^ui.Core_Context, id: ui.Keying_Id, label: string) {
	begin_container(ctx, id, .X, {.Lock_Active, .Lock_Hover})
	ui_label(ctx, "button label", label)
	end_container(ctx)
}

slider :: proc(ctx: ^ui.Core_Context, id: ui.Keying_Id, label: string, value: ^$T, minimum, maximum, step: T, direction: ui.Axis = .X) {
	begin_container(ctx, id, direction, {.Disable_Active}, ui.alignment(.Center, .Center))
	{
		ui_label(ctx, "slider label", label)
		begin_container(ctx, id, direction, {.Disable_Hover}, ui.alignment(.Center, .Center), no_theme_default = true)
		{
			ui_label(ctx, "slider min label", fmt.tprintf("%v", minimum))

			railing_sizing := ui.sizing(ui.grow(min = 64), ui.fixed(8)) if direction == .X else ui.sizing(ui.fixed(8), ui.grow(min = 64))

			railing := ui.create_widget(
				ctx,
				"slider railing",
				ui.layout(railing_sizing, ui.alignment(.Center, .Center)),
				{.Disable_Hover},
				style = theme._container_style.default,
			)

			ui.push_parent(ctx, railing)

			offset_value := f32(value^ - minimum) / f32(maximum - minimum)

			bar(ctx, "slider progress", offset_value, direction)

			offset_value -= 0.5

			knob_offset := ui.offset(ui.percent(offset_value)) if direction == .X else ui.offset(y = ui.percent(offset_value))
			knob := ui.create_widget(
				ctx,
				"slider knob",
				ui.layout(ui.sizing(ui.fixed(16), ui.fixed(16))),
				{.Lock_Active, .Lock_Hover},
				override = ui.create_override(ctx, {offset = knob_offset}),
				style = theme._container_style.default,
			)

			if ui.is_widget_hovered(ctx, knob) {
				knob.style = theme._container_style.hovered
			}
			if ui.is_widget_active(ctx, knob) {
				knob.style = theme._container_style.active
				control_parameter :=
					(ctx.mouse.position[direction] - railing.resolved.position[direction]) /
					(railing.resolved.position[direction] + railing.resolved.size[direction] - railing.resolved.position[direction])
				control_parameter -= 1


				value^ = T(f32(maximum - minimum) * control_parameter + f32(maximum))
			}

			value^ = min(value^, maximum)
			value^ = max(value^, minimum)

			ui.pop_parent(ctx)
			ui_label(ctx, "slider max label", fmt.tprintf("%v", maximum))

		}
		end_container(ctx)
	}
	end_container(ctx)
}

toggle :: proc(ctx: ^ui.Core_Context, id: ui.Keying_Id, label: string, toggle_bool: ^bool) {
	_, events := begin_container(ctx, id, .X, {}, ui.alignment(.Center, .Center), no_theme_active = true)

	ui_label(ctx, "toggle label", label)
	t := ui.create_widget(ctx, "toggle toggle", ui.layout(ui.sizing(ui.fixed(16), ui.fixed(16))), {.Disable_Hover})
	t.style = theme._container_style.default if !toggle_bool^ else theme._container_filled_style.active

	if .Clicked in events[.Left] {
		toggle_bool^ = !toggle_bool^
	}

	end_container(ctx)
}

ui_switch :: proc(ctx: ^ui.Core_Context, id: ui.Keying_Id, label: string, switch_bool: ^bool) {
	_, events := begin_container(ctx, id, .X, {}, ui.alignment(.Center, .Center), no_theme_active = true)

	ui_label(ctx, "switch label", label)

	s_holder := ui.create_widget(
		ctx,
		"switch holder",
		ui.layout(ui.sizing(ui.fixed(28), ui.fixed(16)), ui.alignment(.Positive, .Center)),
		{.Disable_Hover},
		style = theme._container_style.default,
	)
	ui.push_parent(ctx, s_holder)
	s := ui.create_widget(ctx, "toggle toggle", ui.layout(ui.sizing(ui.fixed(16), ui.fixed(16))), {.Disable_Hover})
	s.style = theme._container_style.default if !switch_bool^ else theme._container_style.active

	if switch_bool^ {
		layout := &s_holder.kind.(ui.Layout)
		layout.alignment = ui.alignment(.Negative, .Center)
		s_holder.style = theme._container_filled_style.active
	}

	ui.pop_parent(ctx)

	if .Clicked in events[.Left] {
		switch_bool^ = !switch_bool^
	}

	end_container(ctx)
}

progress_bar :: proc(ctx: ^ui.Core_Context, id: ui.Keying_Id, label: string, progress: f32, direction: ui.Axis = .X) {
	begin_container(ctx, id, .Y, {.Disable_Active}, ui.alignment(.Center, .Center))

	ui_label(ctx, "progress label", label)

	railing_style := ui.copy_style(ctx, theme._container_style.default)
	railing_style_ptr := ui.get_style(ctx, railing_style)
	railing_style_ptr.padding = {}

	railing_sizing := ui.sizing(ui.grow(64), ui.fixed(8)) if direction == .X else ui.sizing(ui.fixed(8), ui.grow(64))

	ui.push_parent(
		ctx,
		ui.create_widget(
			ctx,
			"progress railing",
			ui.layout(railing_sizing, ui.alignment(.Negative, .Center)),
			{.Disable_Hover},
			style = railing_style,
		),
	)

	bar(ctx, "progress bar", progress, direction)

	ui.pop_parent(ctx)
	end_container(ctx)
}
