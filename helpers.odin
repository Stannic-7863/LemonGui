package ui_core

import "base:runtime"
import "core:fmt"
import "core:math/linalg"

// Return Color in rgba format.
rgba :: proc(r: u8 = 255, g: u8 = 255, b: u8 = 255, a: u8 = 255) -> Color {
	return {r, g, b, a}
}

// Return Color in rgba format from hex code.
hex :: proc "contextless" (hex: u32 = 0xFFFFFFFF) -> Color {
	return (transmute([4]u8)hex).abgr
}

// No clipping at all. Default behvaiour.
clip_none :: proc "contextless" () -> Clip {
	return {}
}

// Set clip to custom amount provided. Negative values to move children up. Positive values to move children down. Value is multiplied by speed before being added to children position.
clip_custom :: proc "contextless" (value: f32, scale: f32 = 1) -> Clip {
	return Clip{kind = .Custom, value = value, scale = scale}
}

// Set clip to auto. Only handles scroll events.
clip_auto :: proc "contextless" (scale: f32 = 1) -> Clip {
	return Clip{kind = .Auto, scale = scale}
}

// Return clipping structure. Defaults to custom.
clip :: proc "contextless" (x: Clip = {}, y: Clip = {}) -> [2]Clip {
	return {x, y}
}

override :: proc(flags: [Axis]Override_Flags, offset: [Axis]Override_Transform, expand: [Axis]Override_Transform) -> [Axis]Override {
	return {.X = {flags = flags[.X], offset = offset[.X], expand = expand[.X]}, .Y = {flags = flags[.Y], offset = offset[.Y], expand = expand[.Y]}}
}

flags :: proc(x: Override_Flags = {}, y: Override_Flags = {}) -> [Axis]Override_Flags {
	return {.X = x, .Y = y}
}

expand :: proc(x: Override_Transform = nil, y: Override_Transform = nil) -> [Axis]Override_Transform {
	return {.X = x, .Y = y}
}

offset :: proc(x: Override_Transform = nil, y: Override_Transform = nil) -> [Axis]Override_Transform {
	return {.X = x, .Y = y}
}

// Increase size by given percentage of parent size.
expand_percent :: proc "contextless" (value: f32) -> Percent {
	return Percent{value = value}
}

// Increase size by given percentage of own size.
expand_percent_self :: proc "contextless" (value: f32) -> Percent_Self {
	return Percent_Self{value = value}
}

// Increase size by given value in pixels.
expand_Fixed :: proc "contextless" (value: f32) -> Fixed {
	return Fixed{value = value}
}

// Offset position by given percentage of parent size.
offset_percent :: proc "contextless" (value: f32) -> Percent {
	return Percent{value = value}
}

// Offset position by given percentage of own size.
offset_percent_self :: proc "contextless" (value: f32) -> Percent_Self {
	return Percent_Self{value = value}
}

// Set position to given value in pixels.
offset_fixed :: proc "contextless" (value: f32) -> Fixed {
	return Fixed{value = value}
}

contribute :: proc "contextless" (x := true, y := true) -> [Axis]bool {
	return {.X = true, .Y = true}
}

text :: proc "contextless" (text: string, wrap: Wrap_Kind = .Words, style: Text_Style = {}, cursor: Maybe([2]int) = nil) -> Text {
	return Text{text = text, style = style, wrap = wrap, cursor = cursor}
}

layout :: proc(sizing: [Axis]Sizing, alignment: [Axis]Alignment = {}, child_gap: f32 = 0, direction: Axis = .X) -> Layout {
	return {sizing = sizing, alignment = alignment, direction = direction, child_gap = child_gap}
}

sizing :: proc(x: Sizing, y: Sizing) -> [Axis]Sizing {
	return {.X = x, .Y = y}
}

alignment :: proc(x: Alignment = .Negative, y: Alignment = .Negative) -> [Axis]Alignment {
	return {.X = x, .Y = y}
}

// Fit sizing type.
fit :: proc "contextless" (min: f32 = 0, max: f32 = max(f32)) -> Sizing {
	return Fit{min = min, max = max}
}

// Grow sizing type.
grow :: proc "contextless" (min: f32 = 0, max: f32 = max(f32)) -> Sizing {
	return Grow{min = min, max = max}
}

// Percent sizing type.
percent :: proc "contextless" (value: f32 = 1) -> Sizing {
	return Percent{value = value}
}

// Fixed sizing type.
fixed :: proc "contextless" (value: f32) -> Sizing {
	return Fixed{value = value}
}

padding :: proc(padding: Vec4f32) -> [Axis]Vec2f32 {
	return {.X = padding.wy, .Y = padding.xz}
}

// Border style.
border_style :: proc(color: [4]Color, type: [4]Border_Kind = Border_Kind.Single, radius: Vec4f32 = 0, thickness: Vec4f32 = 1) -> Border_Style {
	return Border_Style{color = color, type = type, radius = radius, thickness = thickness}
}

_get_other_axis :: proc(axis: Axis) -> Axis {
	return (Axis(int(axis) ~ int(max(Axis))))
}

_get_axis_padding :: proc "contextless" (axis: Axis, padding: [Axis]Vec2f32) -> f32 {
	return padding[axis][0] + padding[axis][1]
}

// DOES NOT CHECK FOR WIDGET KIND. ONLY PROVIDE LAYOUT KIND WIDGETS
_get_child_gap :: proc "contextless" (widget: ^Widget) -> f32 {
	return max(0, f32(widget.total_children - 1) * widget.kind.(Layout).child_gap)
}

_get_layout :: proc "contextless" (widget: ^Widget) -> (Layout, bool) {
	switch v in widget.kind {
	case Layout:
		return v, true
	case Text:
		return {}, false
	}
	unreachable()
}

_get_layout_pointer :: proc "contextless" (widget: ^Widget) -> (^Layout, bool) {
	switch &v in widget.kind {
	case Layout:
		return &v, true
	case Text:
		return nil, false
	}
	unreachable()
}

_clamp_border_radius :: proc(widget: ^Widget) {
	for &r in widget.style.border.radius {
		r = clamp(0, min(widget.size.x, widget.size.y) / 2, r)
	}
}

_build_stacks :: proc(ctx: ^Core_Context) {
	append(&ctx.stacks.temp, &ctx.widgets[0]) // append root 

	for {
		widget := pop_safe(&ctx.stacks.temp) or_break

		append(&ctx.stacks.post_r, widget)

		for child_widget := widget.first; child_widget != nil; child_widget = child_widget.next {
			append(&ctx.stacks.temp, child_widget)
		}
	}

	clear(&ctx.stacks.temp)

	for &widget in ctx.widgets {
		append(&ctx.stacks.pre, &widget)
	}

	clear(&ctx.stacks.temp)
}

_is_point_in_rect :: proc(rect_pos, rect_size, point: Vec2f32, border_style: Border_Style) -> bool {

	border_radius: Vec4f32

	half_size := rect_size / 2
	rel_pos := point - (rect_pos + half_size)

	// quadrant selection, first select between left or right, then up and down, top left top right bottom right bottom left
	border_radius.xy = rel_pos.x > 0 ? border_radius.yz : border_radius.xw
	border_radius.x = rel_pos.y > 0 ? border_radius.x : border_radius.y

	p := [2]f32{abs(rel_pos.x), abs(rel_pos.y)} - half_size + border_radius.x

	dist := linalg.length(linalg.max(p, 0.0)) + min(max(p.x, p.y), 0.0) - border_radius.x

	if dist < 0 {
		return true
	}
	return false
}
