package main

import "base:intrinsics"
import "core:math"
import "core:math/ease"

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

lerp :: proc "contextless" (a, b: $T, t: $E) -> (x: T) {
	when intrinsics.type_is_numeric(T) && intrinsics.type_is_array(T) {
		for i in 0 ..< len(a) {
			x[i] = intrinsics.type_elem_type(T)(cast(E)a[i] * (1 - t) + cast(E)b[i] * t)
		}
		return x
	}
}

lerp_style_progressive :: proc(w: ^Widget, time: f32) {
	w.style.color = lerp(w.start.color, w.target.color, time)
	w.style.border_radius = lerp(w.start.border_radius, w.target.border_radius, ease.cubic_in_out(time))
}

lerp_style_decaying :: proc(w: ^Widget, time: f32) {
	w.style.color = lerp(w.target.color, w.start.color, time)
	w.style.border_radius = lerp(w.target.border_radius, w.start.border_radius, ease.cubic_in_out(time))
}
