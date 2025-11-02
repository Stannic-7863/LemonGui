package core_ui

import "core:fmt"
import "core:math/linalg"

clip :: proc "contextless" (
	x_kind: Clip_Kind,
	x_value, x_scale, x_min, x_max: f32,
	y_kind: Clip_Kind,
	y_value, y_scale, y_min, y_max: f32,
	hash: Hash = 0,
) -> Clip {
	return Clip {
		value = {.X = x_value, .Y = y_value},
		kind = {.X = x_kind, .Y = y_kind},
		scale = {.X = x_scale, .Y = y_scale},
		min = {.X = x_min, .Y = y_min},
		max = {.X = x_max, .Y = y_max},
		hash = hash,
	}
}

clip_none :: proc "contextless" () -> (Clip_Kind, f32, f32, f32, f32) {
	return .None, 0, 0, 0, 0
}

clip_custom :: proc "contextless" (value: f32, scale: f32, min: f32 = min(f32), max: f32 = max(f32)) -> (Clip_Kind, f32, f32, f32, f32) {
	return .Custom, value, scale, min, max
}

clip_auto :: proc "contextless" (scale: f32, min: f32 = min(f32), max: f32 = max(f32)) -> (Clip_Kind, f32, f32, f32, f32) {
	return .Auto, 0, scale, min, max
}

override :: proc "contextless" (flags: [Axis]Override_Flags, offset: [Axis]Override_Transform, expand: [Axis]Override_Transform) -> Override {
	return {flags = flags, offset = offset, expand = expand}
}

flags :: proc "contextless" (x: Override_Flags = {}, y: Override_Flags = {}) -> [Axis]Override_Flags {
	return {.X = x, .Y = y}
}

expand :: proc "contextless" (x: Override_Transform = nil, y: Override_Transform = nil) -> [Axis]Override_Transform {
	return {.X = x, .Y = y}
}

offset :: proc "contextless" (x: Override_Transform = nil, y: Override_Transform = nil) -> [Axis]Override_Transform {
	return {.X = x, .Y = y}
}

text :: proc "contextless" (text: string, wrap_mode: Text_Wrap_Mode = .Words, preferred_min: f32 = 0, preferred_max: f32 = max(f32)) -> Text {
	return Text{text = text, preferred_min = preferred_min, preferred_max = preferred_max, wrap_mode = wrap_mode}
}

layout :: proc "contextless" (sizing: [Axis]Sizing, alignment: [Axis]Alignment = {}, child_gap: f32 = 0, direction: Axis = .X) -> Layout {
	return {sizing = sizing, alignment = alignment, direction = direction, child_gap = child_gap}
}

sizing :: proc "contextless" (x: Sizing = Fit{0, max(f32)}, y: Sizing = Fit{0, max(f32)}) -> [Axis]Sizing {
	return {.X = x, .Y = y}
}

alignment :: proc "contextless" (x: Alignment = .Negative, y: Alignment = .Negative) -> [Axis]Alignment {
	return {.X = x, .Y = y}
}

ratio :: proc "contextless" (value: f32) -> Sizing {
	return Ratio{value = value}
}

fit :: proc "contextless" (min: f32 = 0, max: f32 = max(f32)) -> Fit {
	return Fit{min = min, max = max}
}

grow :: proc "contextless" (min: f32 = 0, max: f32 = max(f32)) -> Grow {
	return Grow{min = min, max = max}
}

percent :: proc "contextless" (value: f32 = 1) -> Percent {
	return Percent{value = value}
}

fixed :: proc "contextless" (value: f32) -> Fixed {
	return Fixed{value = value}
}

text_style :: proc "contextless" (
	color: Color = 0,
	font_size: f32 = 0,
	letter_spacing: f32 = 0,
	line_spacing: f32 = 0,
	font: rawptr = nil,
	font_name: string = "",
	font_id: int = 0,
) -> Text_Style {
	return {
		color = color,
		font_size = font_size,
		letter_spacing = letter_spacing,
		line_spacing = line_spacing,
		font = font,
		font_name = font_name,
		font_id = font_id,
	}
}

style :: proc "contextless" (
	color: Color = 0,
	image_tint: Color = 255,
	padding: [Axis]Vec2f32 = {},
	border: Border_Style = {},
	text: Text_Style = {},
) -> Style {
	return {color = color, border = border, padding = padding, text = text}
}

border :: proc "contextless" (color: [4]Color = 0, radius: Vec4f32 = 0, thickness: [Axis]Vec2f32 = {}) -> Border_Style {
	return {color = color, radius = radius, thickness = thickness}
}

axis_vec2f32 :: proc "contextless" (x: Vec2f32 = 0, y: Vec2f32 = 0) -> [Axis]Vec2f32 {
	return {.X = x, .Y = y}
}

axis_vec4f32 :: proc "contextless" (vec4: Vec4f32) -> [Axis]Vec2f32 {
	return {.X = {vec4[3], vec4[1]}, .Y = {vec4[0], vec4[2]}}
}

// EVENTS

is_mouse_pressed :: proc(ctx: ^Core_Context, button: Mouse_Button) -> bool {
	return .Pressed in ctx.mouse.mapped_events[button]
}

is_mouse_down :: proc(ctx: ^Core_Context, button: Mouse_Button) -> bool {
	return .Down in ctx.mouse.mapped_events[button]
}

is_mouse_released :: proc(ctx: ^Core_Context, button: Mouse_Button) -> bool {
	return .Released in ctx.mouse.mapped_events[button]
}

is_widget_hovered :: proc(ctx: ^Core_Context, widget: ^Widget) -> bool {
	return widget.key.hash == ctx.mouse.hovered
}

is_widget_active :: proc(ctx: ^Core_Context, widget: ^Widget) -> bool {
	return widget.key.hash == ctx.mouse.active
}

get_widget_mouse_events_all :: proc(ctx: ^Core_Context, widget: ^Widget) -> Mouse_Events {
	if is_widget_active(ctx, widget) {
		return ctx.mouse.events
	}
	return {}
}

get_widget_mouse_events :: proc(ctx: ^Core_Context, widget: ^Widget, button: Mouse_Button) -> bit_set[Widget_Key_Event] {
	return get_widget_mouse_events_all(ctx, widget)[button]
}

is_point_in_rect :: proc(rect: Rect, point: Vec2f32, border_style: Border_Style) -> bool {
	border_radius := border_style.radius.zywx

	half_size := rect.size / 2
	rel_pos := point - (rect.position + half_size)

	border_radius.xy = rel_pos.x > 0 ? border_radius.xy : border_radius.zw
	border_radius.x = rel_pos.y > 0 ? border_radius.x : border_radius.y

	p := [2]f32{abs(rel_pos.x), abs(rel_pos.y)} - half_size + border_radius.x

	dist := linalg.length(linalg.max(p, 0.0)) + min(max(p.x, p.y), 0.0) - border_radius.x

	if dist < 0 {
		return true
	}
	return false
}

create_clip :: proc(ctx: ^Core_Context, clip: Clip) -> Clip_Index {
	clip_index := Clip_Index(len(ctx.clips))
	clip := clip

	if clip.hash != 0 {
		persistant_clip := ctx.persistant.clip[clip.hash]
		for clip_kind, axis in clip.kind {
			if clip_kind == .Auto {
				clip.value[axis] = persistant_clip[axis]
			}
		}
	}

	append(&ctx.clips, clip)
	return clip_index
}

create_style :: proc(ctx: ^Core_Context, style: Style) -> Style_Index {
	append(&ctx.styles, style)
	return Style_Index(len(ctx.styles) - 1)
}

create_override :: proc(ctx: ^Core_Context, override: Override) -> Override_Index {
	override_index := Override_Index(len(ctx.overrides))
	append(&ctx.overrides, override)
	return override_index
}

get_clip :: #force_inline proc(ctx: ^Core_Context, index: Clip_Index) -> ^Clip #no_bounds_check {
	return &ctx.clips[index]
}

get_style :: #force_inline proc(ctx: ^Core_Context, index: Style_Index) -> ^Style #no_bounds_check {
	return &ctx.styles[index]
}

get_widget :: #force_inline proc(ctx: ^Core_Context, index: Widget_Index) -> ^Widget #no_bounds_check {
	return &ctx.widgets[index]
}

get_override :: #force_inline proc(ctx: ^Core_Context, index: Override_Index) -> ^Override #no_bounds_check {
	return &ctx.overrides[index]
}

copy_style :: proc(ctx: ^Core_Context, style: Style_Index) -> Style_Index {
	append(&ctx.styles, ctx.styles[style])
	return Style_Index(len(ctx.styles) - 1)
}

sort_render_commands :: proc(commands: []Render_Command) #no_bounds_check {
	commands := commands
	length := len(commands)
	if length < 2 {
		return
	}

	p := commands[length / 2]
	i, j := 0, length - 1

	loop: for {
		for (commands[i].z_index - p.z_index) < 0 {i += 1}
		for (p.z_index - commands[j].z_index) < 0 {j -= 1}

		if i >= j {
			break loop
		}

		commands[i], commands[j] = commands[j], commands[i]
		i += 1
		j -= 1
	}

	sort_render_commands(commands[0:i])
	sort_render_commands(commands[i:length])
}

// INTERNALS

_get_override_transform_value :: proc(
	transform: [Axis]Override_Transform,
	widget_size: Vec2f32,
	parent_size: Vec2f32,
	axis: Axis,
) -> (
	offset_value: f32,
) #no_bounds_check {
	switch kind in transform[axis] {
	case Percent_Self:
		offset_value = widget_size[axis] * kind.value
	case Percent:
		offset_value = parent_size[axis] * kind.value
	case Fixed:
		offset_value = kind.value
	}
	return offset_value
}

_get_clip_value :: proc(ctx: ^Core_Context, widget: ^Widget, axis: Axis) -> f32 #no_bounds_check {
	if widget.rect.size[axis] > widget.resolved.content_size[axis] || widget.clip == 0 {
		return 0
	}
	clip := &ctx.clips[widget.clip]
	return clip.value[axis]
}

_get_other_axis :: proc(axis: Axis) -> Axis {
	return .X if axis == .Y else .Y
}

_get_axis_padding :: proc(axis: Axis, padding: [Axis]Vec2f32) -> f32 #no_bounds_check {
	return padding[axis].x + padding[axis].y
}

_get_child_gap :: proc(widget: ^Widget) -> f32 {
	return max(0, f32(widget.total_children - 1)) * widget.kind.(Layout).child_gap
}

_clamp_border_radius :: proc(widget: ^Widget, style: ^Style) {
	comp := min(widget.rect.size.x, widget.rect.size.y)
	for &r in style.border.radius {
		r = min(comp / 2, r)
	}
}

_build_stacks :: proc(ctx: ^Core_Context) #no_bounds_check {
	required_length := len(ctx.widgets)
	resize(&ctx.pre, required_length)
	resize(&ctx.temp, required_length)
	resize(&ctx.post_r, required_length)

	ctx.temp[0] = &ctx.widgets[0]

	temp_cursor: int
	buffer_cursor: int

	for temp_cursor >= 0 {
		widget := ctx.temp[temp_cursor]
		temp_cursor -= 1

		ctx.post_r[buffer_cursor] = widget
		buffer_cursor += 1

		for child_index := widget.first; child_index != -1; {
			child := &ctx.widgets[child_index]
			child_index = child.next
			temp_cursor += 1
			ctx.temp[temp_cursor] = child
		}
	}

	temp_cursor = 0
	buffer_cursor = 0
	ctx.temp[0] = &ctx.widgets[0]

	for temp_cursor >= 0 {
		widget := ctx.temp[temp_cursor]
		temp_cursor -= 1

		ctx.pre[buffer_cursor] = widget
		buffer_cursor += 1

		for child_index := widget.last; child_index != -1; {
			child := &ctx.widgets[child_index]
			child_index = child.prev
			temp_cursor += 1
			ctx.temp[temp_cursor] = child
		}
	}
}
