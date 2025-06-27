package ui_core

import "core:fmt"
import "core:hash"
import "core:math/ease"

Animation_Data :: union {
	f32,
	Color,
	Vec2f32,
	Vec4f32,
}

Animation_Hook :: struct {
	target, start: Animation_Data,
	selectors:     []string,
	widget_index:  int,
	duration:      f32,
	_timer:        f32,
}

animate :: proc(ctx: ^Core_Context, widget_index: int, start, target: Animation_Data, duration: f32, selectors: ..string) {
	if start == target {
		return
	}

	anim_id: Id
	for n in selectors {
		anim_id ~= cast(Id)hash.fnv64(transmute([]byte)n) + 0x9e3779b9 + (anim_id >> 6) + (anim_id << 2)
	}

	val, exists := &ctx.animation_hooks[anim_id]
	if !exists {
		allocated_selectors := make([]string, len(selectors))
		copy(allocated_selectors, selectors)
		ctx.animation_hooks[anim_id] = Animation_Hook {
			selectors    = allocated_selectors,
			widget_index = widget_index,
			target       = target,
			start        = start,
			duration     = duration,
		}
	} else {
		val.start = start
		val.target = target
		val.duration = duration
		val._timer = 0
	}
}

_resolve_animation_hooks :: proc(ctx: ^Core_Context) {
	for hook_key, &hook_val in ctx.animation_hooks {

		hook_val._timer += clamp(ctx.delta_time / hook_val.duration, 0, 1)

		field_value: any = nil
		if hook_val.widget_index < len(ctx.widgets) {
			field_value = _get_field_value_by_name(ctx.widgets[hook_val.widget_index], ..hook_val.selectors)
		}

		switch type in hook_val.start {
		case f32:
			assert(f32 == field_value.id, fmt.tprintf("Types not matched. Expected f32 got %v", field_value.id))
			typed_ptr: ^f32 = cast(^f32)field_value.data
			typed_ptr^ = _lerp_f32(hook_val.start.(f32), hook_val.target.(f32), hook_val._timer)
		case Color:
			assert(Color == field_value.id, fmt.tprintf("Types not matched. Expected Color got %v", field_value.id))
			typed_ptr: ^Color = cast(^Color)field_value.data
			typed_ptr^ = _lerp_color(hook_val.start.(Color), hook_val.target.(Color), hook_val._timer)
		case Vec2f32:
			assert(Vec2f32 == field_value.id, fmt.tprintf("Types not matched. Expected Vec2f32 got %v", field_value.id))
			typed_ptr: ^Vec2f32 = cast(^Vec2f32)field_value.data
			typed_ptr^ = _lerp_vec2f32(hook_val.start.(Vec2f32), hook_val.target.(Vec2f32), hook_val._timer)
		case Vec4f32:
			assert(Vec4f32 == field_value.id, fmt.tprintf("Types not matched. Expected Vec4f32 got %v", field_value.id))
			typed_ptr: ^Vec4f32 = cast(^Vec4f32)field_value.data
			typed_ptr^ = _lerp_vec4f32(hook_val.start.(Vec4f32), hook_val.target.(Vec4f32), hook_val._timer)
		}

		if hook_val._timer >= 1 || field_value == nil {
			delete(hook_val.selectors)
			delete_key(&ctx.animation_hooks, hook_key)
		}
	}
}


_lerp_f32 :: proc "contextless" (a, b, t: f32) -> f32 {
	return a + (b - a) * t
}

_lerp_color :: proc "contextless" (a, b: Color, t: f32) -> Color {
	return Color {
		cast(u8)(_lerp_f32(cast(f32)a.r, cast(f32)b.r, t)),
		cast(u8)(_lerp_f32(cast(f32)a.g, cast(f32)b.g, t)),
		cast(u8)(_lerp_f32(cast(f32)a.b, cast(f32)b.b, t)),
		cast(u8)(_lerp_f32(cast(f32)a.a, cast(f32)b.a, t)),
	}
}

_lerp_vec2f32 :: proc "contextless" (a, b: Vec2f32, t: f32) -> Vec2f32 {
	return Vec2f32{_lerp_f32(a.x, b.x, t), _lerp_f32(a.y, b.y, t)}
}

_lerp_vec4f32 :: proc "contextless" (a, b: Vec4f32, t: f32) -> Vec4f32 {
	return Vec4f32{_lerp_f32(a.x, b.x, t), _lerp_f32(a.y, b.y, t), _lerp_f32(a.z, b.z, t), _lerp_f32(a.w, b.w, t)}
}
