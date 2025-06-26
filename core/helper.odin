package ui_core

import "base:runtime"
import "core:fmt"
import "core:math"
import "core:math/ease"
import "core:reflect"

rgba :: proc(r, g, b, a: u8) -> Color {
	return {r, g, b, a}
}

hex :: proc "contextless" (hex: u32) -> Color {
	return (transmute([4]u8)hex).abgr
}

expand_percent :: proc "contextless" (value: f32) -> Expand {
	return Expand{value = value, kind = .Percent}
}

expand_absolute :: proc "contextless" (value: f32) -> Expand {
	return Expand{value = value, kind = .Absolute}
}

offset_percent :: proc "contextless" (value: f32) -> Offset {
	return Offset{value = value, kind = .Percent}
}

offset_relative :: proc "contextless" (value: f32) -> Offset {
	return Offset{value = value, kind = .Relative}
}

sizing :: proc "contextless" (x, y: Sizing) -> [Axis]Sizing {
	return {.X = x, .Y = y}
}

offset_fixed :: proc "contextless" (value: f32) -> Offset {
	return Offset{value = value, kind = .Fixed}
}

fit :: proc "contextless" (min: f32 = 0, max: f32 = max(f32)) -> Sizing {
	return Sizing{min = min, max = max, kind = .Fit}
}

grow :: proc "contextless" (min: f32 = 0, max: f32 = max(f32)) -> Sizing {
	return Sizing{min = min, max = max, kind = .Grow}
}

percent :: proc "contextless" (value: f32 = 1) -> Sizing {
	return Sizing{min = value, max = value, kind = .Percent}
}

fixed :: proc "contextless" (size: f32) -> Sizing {
	return Sizing{size, size, .Fixed}
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
	switch v in widget.config {
	case Layout:
		return v, true
	case Floating:
		return v.layout, true
	case Text:
		return {}, false
	}
	unreachable()
}

_get_field_value_by_name :: proc(a: any, names: ..string) -> any {
	a := a
	for name in names {
		ti := runtime.type_info_base(type_info_of(a.id))
		if ts, ok := ti.variant.(runtime.Type_Info_Struct); ok {
			for n, i in ts.names[:ts.field_count] {
				if n == name {
					a.id = ts.types[i].id
					a.data = rawptr(uintptr(a.data) + ts.offsets[i])
				}
			}
		} else if ts, ok := ti.variant.(runtime.Type_Info_Union); ok {
			a = reflect.get_union_variant(a)
			ti := runtime.type_info_base(type_info_of(a.id))
			if ts, ok := ti.variant.(runtime.Type_Info_Struct); ok {
				for n, i in ts.names[:ts.field_count] {
					if n == name {
						a.id = ts.types[i].id
						a.data = rawptr(uintptr(a.data) + ts.offsets[i])
					}
				}
			}
		}
	}
	return a
}
