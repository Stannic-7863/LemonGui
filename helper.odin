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
	w.style.text.spacing = math.lerp(w.start.text.spacing, w.target.text.spacing, ease.cubic_in_out(time))
	w.style.text.font_size = math.lerp(w.start.text.font_size, w.target.text.font_size, ease.cubic_in_out(time))
	w.style.layout.padding = math.lerp(w.start.layout.padding, w.target.layout.padding, ease.cubic_in_out(time))
}

lerp_style_decaying :: proc(w: ^Widget, time: f32) {
	w.style.color = lerp(w.target.color, w.start.color, time)
	w.style.border_radius = lerp(w.target.border_radius, w.start.border_radius, ease.cubic_in_out(time))
	w.style.text.font_size = math.lerp(w.target.text.font_size, w.start.text.font_size, ease.cubic_in_out(time))
	w.style.text.spacing = math.lerp(w.target.text.spacing, w.start.text.spacing, ease.cubic_in_out(time))
	w.style.layout.padding = math.lerp(w.target.layout.padding, w.start.layout.padding, ease.cubic_in_out(time))
}
