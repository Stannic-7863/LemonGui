package ui_core

import "base:runtime"
import "core:fmt"
import "core:math"
import "core:math/ease"
import "core:reflect"

// Return Color in rgba format
rgba :: proc(r: u8 = 255, g: u8 = 255, b: u8 = 255, a: u8 = 255) -> Color {
	return {r, g, b, a}
}

// Return Color in rgba format from hex code 
hex :: proc "contextless" (hex: u32 = 0xFFFFFFFF) -> Color {
	return (transmute([4]u8)hex).abgr
}

// Increase size by given percentage of parent size
expand_percent :: proc "contextless" (value: f32) -> Expand {
	return Expand{value = value, kind = .Percent}
}

// Increase size by given percentage of own size
expand_percent_self :: proc "contextless" (value: f32) -> Expand {
	return Expand{value = value, kind = .Percent_Self}
}

// Increase size by given value in pixels
expand_absolute :: proc "contextless" (value: f32) -> Expand {
	return Expand{value = value, kind = .Absolute}
}

// Offset position by given percentage of parent size
offset_percent :: proc "contextless" (value: f32) -> Offset {
	return Offset{value = value, kind = .Percent}
}

// Offset position by given percentage of own size
offset_percent_self :: proc "contextless" (value: f32) -> Offset {
	return Offset{value = value, kind = .Percent_Self}
}

// Offset position by given value in pixels
offset_absolute :: proc "contextless" (value: f32) -> Offset {
	return Offset{value = value, kind = .Absolute}
}

// Set position to given value in pixels
offset_fixed :: proc "contextless" (value: f32) -> Offset {
	return Offset{value = value, kind = .Fixed}
}

// Layout
layout :: proc "contextless" (
	sizing: [Axis]Sizing,
	child_gap: f32 = 0,
	direction: Axis = .X,
	child_alignment: Child_Alignment = {.Left, .Top},
) -> Layout {
	return Layout{sizing = sizing, child_gap = child_gap, direction = direction, child_alignment = child_alignment}
}

// Sizing along axis. Default to Fit
sizing :: proc "contextless" (x: Sizing = {}, y: Sizing = {}) -> [Axis]Sizing {
	return {.X = x, .Y = y}
}

// Fit sizing type
fit :: proc "contextless" (min: f32 = 0, max: f32 = max(f32)) -> Sizing {
	return Sizing{min = min, max = max, kind = .Fit}
}

// Grow sizing type
grow :: proc "contextless" (min: f32 = 0, max: f32 = max(f32)) -> Sizing {
	return Sizing{min = min, max = max, kind = .Grow}
}

// Percent sizing type
percent :: proc "contextless" (value: f32 = 1) -> Sizing {
	return Sizing{min = value, max = value, kind = .Percent}
}

// Fixed sizing type
fixed :: proc "contextless" (size: f32) -> Sizing {
	return Sizing{size, size, .Fixed}
}

// Configure border style 
border :: proc(color: [4]Color, type: [4]Border_Type = Border_Type.Single, radius: Vec4f32 = 0, thickness: Vec4f32 = 1) -> Border_Style {
	return Border_Style{color = color, type = type, radius = radius, thickness = thickness}
}

_get_axis_padding :: proc "contextless" (axis: Axis, padding: Vec4f32) -> f32 {
	switch axis {
	case .X:
		return padding[3] + padding[1]
	case .Y:
		return padding[0] + padding[2]
	}
	unreachable()
}

_get_layout :: proc "contextless" (widget: ^Widget) -> (Layout, bool) {
	switch v in widget.type {
	case Layout:
		return v, true
	case Floating:
		return v.layout, true
	case Text:
		return {}, false
	}
	unreachable()
}

_clamp_border_radius :: proc(widget: ^Widget) {
	if border, ok := &widget.style.border.(Border_Style); ok {
		for &r in border.radius {
			r = clamp(0, min(widget.size.x, widget.size.y) / 2, r)
		}
	}
}

_build_stacks :: proc(ctx: ^Core_Context) {
	append(&ctx.stacks.temp, &ctx.widgets[0]) // append root node 

	// Perhaps I should make this a breathd first tree instead of depth first tree
	// Insight: Widgets are inserted in "pre order traversal" order

	for {
		widget := pop_safe(&ctx.stacks.temp) or_break

		append(&ctx.stacks.post_r, widget)

		for child_widget := widget.node.first_child; child_widget != nil; child_widget = child_widget.node.next {
			append(&ctx.stacks.temp, child_widget)
		}
	}

	clear(&ctx.stacks.temp)
	append(&ctx.stacks.temp, &ctx.widgets[0])

	for {
		widget := pop_safe(&ctx.stacks.temp) or_break

		append(&ctx.stacks.pre, widget)

		for child_widget := widget.node.last_child; child_widget != nil; child_widget = child_widget.node.prev {
			append(&ctx.stacks.temp, child_widget)
		}
	}

	clear(&ctx.stacks.temp)
}
