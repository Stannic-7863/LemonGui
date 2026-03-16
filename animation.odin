package core_ui

import "core:math/ease"
import "core:time"

// Return true on change. Return False for no change
Widget_Comparison :: #type proc(curr, prev: Animation_Data) -> bool

// Should return a state from where the animation will start. Inputs are from current frame.
Widget_Created :: #type proc(info: Info, style: Style, text_position: Vec2f32) -> (start: Animation_Data)

// Should return a state at which animation will conclude. Inputs are from last frame.
Widget_Destroy :: #type proc(info: Info, style: Style, text_position: Vec2f32) -> (end: Animation_Data)

// Animation Update mechanism. Returns true on animation completion
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
	style:         Style,
	rect:          Rect,
	text_position: Vec2f32,
}

Animation_State :: struct {
	z_index:    int,
	owner_hash: Hash,
	update:     Animation_Update,
	type:       Animation_Type,
	start:      Animation_Data,
	end:        Animation_Data,
	now:        Animation_Data,
	elapsed:    time.Duration,
	duration:   time.Duration,
}

_resolve_animations :: proc(ctx: ^Core_Context) {
	for owner, &state in ctx.persistant.anim_states {
		if state.type == .Creation || state.type == .Update {
			if lookup, ok := ctx.persistant.curr_lookup[owner]; ok {
				new_rect := lookup.info.rect
				new_text := lookup.text_position
				if new_rect.position != state.end.rect.position || new_rect.size != state.end.rect.size || new_text != state.end.text_position {
					state.start = state.now
					state.elapsed = 0
				}
				state.end.rect = new_rect
				state.end.text_position = new_text
			}
		}
	}

	for owner, &state in ctx.persistant.anim_states {
		ended := state.update(&state, ctx.timers.frame_time)
		if ended {delete_key(&ctx.persistant.anim_states, owner); continue}
		switch state.type {
		case .Destruction:
			border := state.now.style.border
			comp := min(state.now.rect.size.x, state.now.rect.size.y) / 2
			for &r in border.radius {r = min(comp, r)}
			_add_render_command(ctx, owner, Command_Rect{border = border, color = state.now.style.color}, state.now.rect, state.z_index)

		case .Creation, .Update:
			lookup := ctx.persistant.curr_lookup[owner]
			widget := get_widget(ctx, lookup.info.index)
			widget.form.style = create_style(ctx, state.now.style)
			widget.rect = state.now.rect
			widget.text_info.position = state.now.text_position
		}
	}

	for curr_candid in ctx.persistant.curr_candids {
		curr_lookup := ctx.persistant.curr_lookup[curr_candid]
		curr_anim := ctx.anims[curr_lookup.form.animation]
		curr_style := ctx.styles[curr_lookup.form.style]

		if curr_candid not_in ctx.persistant.prev_candids {
			state, ok := ctx.persistant.anim_states[curr_candid]
			start := Animation_Data{}
			if ok {start = state.now} else {start = curr_anim.hooks.on_created(curr_lookup.info, curr_style, curr_lookup.text_position)}
			state = Animation_State {
				owner_hash = curr_candid,
				end = {rect = curr_lookup.info.rect, style = curr_style},
				now = start,
				start = start,
				type = .Creation,
				duration = curr_anim.duration,
				update = curr_anim.hooks.update,
			}
			ctx.persistant.anim_states[curr_candid] = state
			widget := get_widget(ctx, curr_lookup.info.index)
			widget.form.style = create_style(ctx, state.now.style)
			widget.rect = state.now.rect
			widget.text_info.position = state.now.text_position
			continue
		}

		prev_lookup := ctx.persistant.prev_lookup[curr_candid]
		prev_style := ctx.persistant.prev_styles[prev_lookup.form.style]

		prev_data := Animation_Data {
			rect          = prev_lookup.info.rect,
			style         = prev_style,
			text_position = prev_lookup.text_position,
		}
		curr_data := Animation_Data {
			rect          = curr_lookup.info.rect,
			style         = curr_style,
			text_position = curr_lookup.text_position,
		}

		if curr_anim.hooks.compare(prev_data, curr_data) {
			state, ok := ctx.persistant.anim_states[curr_candid]
			if ok {prev_data = state.now}
			state = Animation_State {
				owner_hash = curr_candid,
				start      = prev_data,
				end        = curr_data,
				now        = prev_data,
				type       = .Update,
				duration   = curr_anim.duration,
				update     = curr_anim.hooks.update,
			}
			ctx.persistant.anim_states[curr_candid] = state
			widget := get_widget(ctx, curr_lookup.info.index)
			widget.form.style = create_style(ctx, state.now.style)
			widget.rect = state.now.rect
			widget.text_info.position = state.now.text_position
		}
	}

	for prev_candid in ctx.persistant.prev_candids {
		if prev_candid not_in ctx.persistant.curr_candids {
			prev_lookup := ctx.persistant.prev_lookup[prev_candid]
			prev_anim := ctx.persistant.prev_anims[prev_lookup.form.animation]
			prev_style := ctx.persistant.prev_styles[prev_lookup.form.style]
			state, ok := ctx.persistant.anim_states[prev_candid]
			end := prev_anim.hooks.on_destroyed(prev_lookup.info, prev_style, prev_lookup.text_position)
			start := Animation_Data{}
			r := prev_lookup
			if ok {start = state.now} else {start = {
					rect  = prev_lookup.info.rect,
					style = prev_style,
				}}
			start.rect.position += start.rect.scroll_offset
			state = Animation_State {
				z_index    = prev_lookup.z_index + prev_lookup.form.z_offset,
				owner_hash = prev_candid,
				end        = end,
				start      = start,
				now        = start,
				type       = .Destruction,
				duration   = prev_anim.duration,
				update     = prev_anim.hooks.update,
			}
			ctx.persistant.anim_states[prev_candid] = state
			border := state.now.style.border
			comp := min(state.now.rect.size.x, state.now.rect.size.y) / 2
			for &r in border.radius {r = min(comp, r)}
			_add_render_command(ctx, prev_candid, Command_Rect{border = border, color = state.now.style.color}, state.now.rect, state.z_index)
		}
	}
}

ANIM_ALL :: Animation_Hooks {
	update = proc(state: ^Animation_State, frame_time: time.Duration) -> bool {
		state.elapsed += frame_time

		if state.elapsed >= state.duration {
			return true
		}

		e_o := (f32(state.elapsed) / f32(state.duration))
		e_rect := ease.ease(.Cubic_In_Out, e_o)
		e_color := ease.ease(.Cubic_In_Out, e_o)

		state.now = state.end

		state.now.text_position = state.start.text_position + e_rect * (state.end.text_position - state.start.text_position)
		state.now.rect.position = state.start.rect.position + e_rect * (state.end.rect.position - state.start.rect.position)
		state.now.rect.size = state.start.rect.size + e_color * (state.end.rect.size - state.start.rect.size)
		state.now.style.color = state.start.style.color + e_color * (state.end.style.color - state.start.style.color)
		state.now.style.border.color = state.start.style.border.color + e_color * (state.end.style.border.color - state.start.style.border.color)
		state.now.style.border.radius = state.start.style.border.radius + e_color * (state.end.style.border.radius - state.start.style.border.radius)
		state.now.style.text.color = state.start.style.text.color + e_color * (state.end.style.text.color - state.start.style.text.color)
		return false
	},
	compare = proc(prev, curr: Animation_Data) -> bool {
		if curr.rect.position != prev.rect.position {return true}
		if curr.rect.size != prev.rect.size {return true}
		if curr.style.color != prev.style.color {return true}
		return false
	},
	on_created = proc(info: Info, style: Style, text_position: Vec2f32) -> (start: Animation_Data) {
		rect := Rect{}
		rect.position = info.rect.position + info.rect.size / 2 + info.rect.scroll_offset
		rect.size = {}
		return {rect = rect, style = style, text_position = text_position}
	},
	on_destroyed = proc(info: Info, style: Style, text_position: Vec2f32) -> (end: Animation_Data) {
		return {rect = {position = info.rect.position + info.rect.size / 2 + info.rect.scroll_offset}, style = style, text_position = text_position + info.rect.scroll_offset}
	},
}

ANIM_COLOR :: Animation_Hooks {
	update = proc(state: ^Animation_State, frame_time: time.Duration) -> bool {
		state.elapsed += frame_time

		if state.elapsed >= state.duration {
			return true
		}

		e_o := (f32(state.elapsed) / f32(state.duration))
		e_color := ease.ease(.Cubic_In_Out, e_o)

		state.now.rect = state.end.rect
		state.now.text_position = state.end.text_position

		state.now.style.color = state.start.style.color + e_color * (state.end.style.color - state.start.style.color)
		state.now.style.text.color = state.start.style.text.color + e_color * (state.end.style.text.color - state.start.style.text.color)
		state.now.style.border.color = state.start.style.border.color + e_color * (state.end.style.border.color - state.start.style.border.color)
		return false
	},
	compare = proc(prev, curr: Animation_Data) -> bool {
		if curr.style.color != prev.style.color {return true}
		if curr.style.text.color != prev.style.text.color {return true}
		if curr.style.border.color != prev.style.border.color {return true}
		return false
	},
	on_created = proc(info: Info, style: Style, text_position: Vec2f32) -> (start: Animation_Data) {
		s := style
		s.color = {}
		s.text.color = {}
		s.border.color = {}
		return {rect = info.rect, style = s, text_position = text_position}
	},
	on_destroyed = proc(info: Info, style: Style, text_position: Vec2f32) -> (end: Animation_Data) {
		s := style
		s.color = {}
		s.text.color = {}
		s.border.color = {}
		return {rect = info.rect, style = s, text_position = text_position}
	},
}
