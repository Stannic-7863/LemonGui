package core_ui

import "core:fmt"
import "core:math/ease"
import "core:math"
import "core:time"

// Return true on change. Return False for no change
Widget_Comparison :: #type proc(curr, prev: Animation_Data) -> bool

// Should return a state from where the animation will start. Inputs are from current frame.
Widget_Created :: #type proc(info: Info, style: Style) -> (start: Animation_Data)

// Should return a state at which animation will conclude. Inputs are from last frame. 
Widget_Destroy :: #type proc(info: Info, style: Style) -> (end: Animation_Data)

// Animation Update mechanism
Animation_Update :: #type proc(state: ^Animation_State, deltatime: time.Duration) -> bool

Animation_Type :: enum {
	Creation,
	Destruction,
	Update,
}

Animation_Hooks :: struct #all_or_none {
	update:       Animation_Update,
	compare:      Widget_Comparison,
	on_created:   Widget_Created,
	on_destroyed: Widget_Destroy,
}

Animation :: struct {
	hooks:    Animation_Hooks,
	duration: time.Duration,
	delay:    time.Duration,
}

Animation_Data :: struct {
	style: Style,
	rect:  Rect,
}

Animation_State :: struct {
	set:		 bool,
	animation:   Animation,
	type:        Animation_Type,
	target_info: Info,
	start:       Animation_Data,
	end:         Animation_Data,
	now:         Animation_Data,
	elapsed:     time.Duration,
}

DEFAULT_HOOKS :: Animation_Hooks {
	update = proc(state: ^Animation_State, deltatime: time.Duration) -> bool {
		state.elapsed += deltatime

		if state.elapsed >= state.animation.duration {
			return true 
		}

		e_o := (f32(state.elapsed) / f32(state.animation.duration))
		e_rect := ease.ease(.Elastic_In_Out, e_o)
		e_color := ease.ease(.Exponential_In_Out, e_o)

		state.now = state.end

		state.now.rect.position = state.start.rect.position + e_rect * (state.end.rect.position - state.start.rect.position)
		state.now.rect.size = state.start.rect.size + e_color * (state.end.rect.size - state.start.rect.size)
		state.now.style.color = state.start.style.color + e_color * (state.end.style.color - state.start.style.color)
		return false 
	},
	compare = proc(curr, prev: Animation_Data) -> bool {
		if curr.rect.position != prev.rect.position {
			return true 
		}
		if curr.rect.size != prev.rect.size {
			return true 
		}
		if curr.style.color != prev.style.color {
			return true 
		}
		return false 
	},
	on_created = proc(info: Info, style: Style) -> (start: Animation_Data) {
		rect := Rect{}
		rect.position = info.rect.position + info.rect.size / 2
		rect.size = {}
		rect.content_size = {}
		return {rect = rect, style = style}	
	},
	on_destroyed = proc(info: Info, style: Style) -> (end: Animation_Data) {
		return {rect = {}, style = style}
	},
}
