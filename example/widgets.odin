package main

import cu "../"
import "core:fmt"
import "core:math"
import "core:reflect"
import "core:strings"
import "core:text/edit"
import "core:time"
import "core:unicode/utf8"
import rl "vendor:raylib"

Image :: struct {
	w, h: f32,
	data: rawptr,
}

build_ui :: proc(ctx: ^cu.Core_Context, tick_image: Image, aaloo_image: Image, state: ^edit.State, buffer: ^strings.Builder) {
	root := cu.create_widget(
		ctx,
		"Root",
		cu.Layout{sizing = cu.sizing(cu.fixed(ctx.window_width), cu.fixed(ctx.window_height)), direction = .X, child_gap = 16},
		style = {padding = 32, color = BACKGROUND_COLOR},
	)

	cu.push_parent(ctx, root)

	if frame(ctx, "Buttons", {24, 12, 12, 12}, 16) {
		e_1 := button(ctx, "Test 1", tick_image, "Flickering is due to Id's not being created with constant data.")
		e_2 := button(ctx, "Test 2", tick_image, "Reading tool tips?")
		e_3 := button(ctx, "Test 3", tick_image, "Well well well")

		@(static) toggle: bool
		@(static) label: string
		toggle_button(ctx, label, &toggle, nil, "Toggle to reveal secrets of universe")

		if toggle {
			label = "Toggled"
			@(static) toggle_2: bool
			toggle_button(ctx, "42", &toggle_2, nil, "Very dynamic eh : )")
			if toggle_2 {
				button(ctx, "Yes.", {}, nil)
			}
		} else {
			label = "Toggle"
		}
		cu.pop_parent(ctx)
	}


	if frame(ctx, "Text_Wrap", {34, 12, 12, 12}, child_gap = 24) {
		if frame(ctx, "Wrap_Words") {
			cu.create_widget(ctx, "Text_1", cu.text("A quick brown fox jumps over the lazy dog", .Words), tags = {"text big secondary"})
			cu.pop_parent(ctx)
		}
		if frame(ctx, "Wrap_New_Lines") {
			cu.create_widget(
				ctx,
				"Text_2",
				cu.text("A quick \nbrown \nfox \njumps over \nthe lazy \ndog", .New_Lines),
				tags = {"text big secondary"},
			)
			cu.pop_parent(ctx)
		}
		if frame(ctx, "Wrap_None") {
			cu.create_widget(ctx, "Text_3", cu.text("A quick brown fox jumps over the lazy dog", .None), tags = {"text big secondary"})
			cu.pop_parent(ctx)
		}
		if frame(ctx, "Wrap_Letters") {
			cu.create_widget(ctx, "Text_4", cu.text("A quick brown fox jumps over the lazy dog", .Letters), tags = {"text big secondary"})
			cu.pop_parent(ctx)
		}
		cu.pop_parent(ctx)
	}


	if frame(ctx, "Text_Input") {
		t := cu.create_widget(
			ctx,
			"Input text",
			cu.text(transmute(string)buffer.buf[:], .Letters, cursor = state.selection),
			tags = {"text small primary"},
		)
		type := t.kind.(cu.Text)
		cu.pop_parent(ctx)
	}

	if frame(ctx, "Aaloo_Voodoo", {32, 12, 12, 12}, 8) {
		@(static) aaloo_tint := cu.Color{255, 255, 255, 255}
		if frame(ctx, "Aaloos") {
			cu.create_widget(
				ctx,
				"Aaloos config",
				cu.layout(cu.sizing(cu.grow())),
				image = cu.Image{data = aaloo_image.data, tint = aaloo_tint},
				aspect_ratio = aaloo_image.w / aaloo_image.h,
			)
			cu.pop_parent(ctx)
		}

		if frame(ctx, "Aaloo_Tint") {
			elem_names := [?]string{"r", "g", "b", "a"}
			for &elem, i in aaloo_tint {
				val := cast(f32)(elem)
				slider(ctx, elem_names[i], &val, 0, 255)
				elem = cast(u8)val
			}
			cu.pop_parent(ctx)
		}
		cu.pop_parent(ctx)
	}
	cu.pop_parent(ctx)
}

button :: proc(ctx: ^cu.Core_Context, label: string, icon: Image, tooltip: Maybe(string)) -> [cu.Mouse_Button]bit_set[cu.Widget_Key_Event] {
	body := cu.create_widget(
		ctx,
		label,
		cu.layout(cu.sizing(cu.grow(max = 128), cu.fit(16)), 8, .X, {.Center, .Center}),
		tags = {"border"},
		style = cu.Rect_Style{color = SURFACE_COLOR, padding = 4},
	)

	if cu.push_parent(ctx, body) {
		defer cu.pop_parent(ctx)

		label_widget := cu.create_widget(ctx, "body_label_text", cu.text(label), tags = {"text small primary"}, event_passthrough = true)

		if icon.data != nil {
			cu.create_widget(
				ctx,
				"button_icon",
				cu.layout(cu.sizing(cu.fixed(icon.w), cu.fixed(icon.h))),
				aspect_ratio = 1.0,
				image = cu.Image{icon.data, 255},
				style = {color = 0},
				event_passthrough = true,
			)
		}

		if tooltip, ok := tooltip.(string); ok && body.node.id == ctx.hot_widget_id {
			offset_value := ctx.mouse.position - body.position
			fixed_size: [2]f32 = {ctx.window_width - body.position.x, ctx.window_height - body.position.y} - offset_value - 32
			floating_holder := cu.create_widget(
				ctx,
				"button_floating_tooltip_holder",
				cu.Floating {
					layout = cu.layout(cu.sizing(cu.fixed(fixed_size.x), cu.fixed(fixed_size.y))),
					parent = .Left_Top,
					element = .Left_Top,
					attachment_to = .Parent,
				},
				style = {color = 0, padding = 16},
				event_passthrough = true,
			)
			floating_holder.z_index += 5000
			if cu.push_parent(ctx, floating_holder) {
				defer cu.pop_parent(ctx)
				cu.create_widget(
					ctx,
					"button_floating_tooltip",
					cu.text(text = tooltip),
					tags = {"border", "text small primary"},
					offset = [2]cu.Offset{cu.offset_absolute(offset_value.x), cu.offset_absolute(offset_value.y)},
					style = {color = ELEVATED_SURFACE_COLOR, padding = 16},
					event_passthrough = true,
				)
			}
		}
	}

	if body.node.id == ctx.hot_widget_id {
		return ctx.mouse.events
	} else {
		return {}
	}
}

toggle_button :: proc(
	ctx: ^cu.Core_Context,
	label: string,
	toggle: ^bool,
	icon: rawptr,
	tooltip: Maybe(string),
) -> [cu.Mouse_Button]bit_set[cu.Widget_Key_Event] {


	tags: []string = {"border toggle off", "text small disabled"}
	if toggle^ {
		tags = {"border toggle on", "text small primary"}
	}

	body := cu.create_widget(
		ctx,
		label,
		cu.layout(cu.sizing(cu.grow(max = 128), cu.fit(16)), 8, .X, {.Center, .Center}),
		tags = {tags[0]},
		style = cu.Rect_Style{color = SURFACE_COLOR, padding = 4},
	)

	if body.node.id == ctx.hot_widget_id {
		if .Clicked in ctx.mouse.events[.Left] {
			toggle^ = !toggle^
		}
	}

	if cu.push_parent(ctx, body) {
		defer cu.pop_parent(ctx)

		label_widget := cu.create_widget(ctx, "toggle_button_label_text", cu.text(label), tags = {tags[1]}, event_passthrough = true)

		if icon != nil {
			icon := cast(^rl.Texture)icon
			cu.create_widget(
				ctx,
				"toggle_button_icon",
				cu.layout(cu.sizing(cu.fixed(cast(f32)icon.width), cu.fixed(cast(f32)icon.height))),
				aspect_ratio = 1.0,
				image = cu.Image{icon, 255},
				style = {color = 0},
				event_passthrough = true,
			)
		}

		if tooltip, ok := tooltip.(string); ok && body.node.id == ctx.hot_widget_id {
			offset_value := ctx.mouse.position - body.position
			fixed_size: [2]f32 = {ctx.window_width - body.position.x, ctx.window_height - body.position.y} - offset_value - 32
			floating_holder := cu.create_widget(
				ctx,
				"toggle_button_tooltip_floating",
				cu.Floating {
					layout = cu.layout(cu.sizing(cu.fixed(fixed_size.x), cu.fixed(fixed_size.y))),
					parent = .Left_Top,
					element = .Left_Top,
					attachment_to = .Parent,
				},
				style = {color = 0, padding = 16},
				event_passthrough = true,
			)
			floating_holder.z_index += 5000
			if cu.push_parent(ctx, floating_holder) {
				defer cu.pop_parent(ctx)
				cu.create_widget(
					ctx,
					"toggle_button_tooltip_text",
					cu.text(text = tooltip),
					tags = {"text small primary", "border"},
					offset = [2]cu.Offset{cu.offset_absolute(offset_value.x), cu.offset_absolute(offset_value.y)},
					style = {color = ELEVATED_SURFACE_COLOR, padding = 16},
					event_passthrough = true,
				)
			}
		}
	}

	if body.node.id == ctx.hot_widget_id {
		return ctx.mouse.events
	} else {
		return {}
	}
}

slider :: proc(ctx: ^cu.Core_Context, label: string, value: ^f32, min, max: f32) {
	main_container := cu.create_widget(
		ctx,
		label,
		cu.Layout{sizing = cu.sizing(cu.grow(50), cu.fit(min = 16, max = 32)), child_gap = 16, direction = .X, child_alignment = {.Center, .Center}},
		style = cu.Rect_Style{padding = 4},
		event_passthrough = true,
	)
	cu.push_parent(ctx, main_container)
	cu.create_widget(ctx, "slider_text_label", cu.text(label), tags = {"border", "text small primary"}, style = {padding = 8})
	cu.create_widget(ctx, "slider_text_min", cu.text(text = fmt.tprint(min)), tags = {"text small primary"})

	railing := cu.create_widget(
		ctx,
		"slider_text_min",
		cu.layout(sizing = cu.sizing(cu.grow(), cu.fixed(4)), direction = .Y, child_alignment = {.Center, .Center}),
		style = cu.Rect_Style{color = SURFACE_COLOR},
	)

	cu.push_parent(ctx, railing)

	knob_offset := clamp((value^ - min) / (max - min) - 0.5, -0.5, 0.5)

	knob := cu.create_widget(
		ctx,
		"slider_knob",
		cu.Layout{sizing = cu.sizing(cu.fixed(20), cu.fixed(20))},
		offset = cu.offset(cu.offset_percent(knob_offset)),
		style = cu.Rect_Style{color = ELEVATED_SURFACE_COLOR, border = cu.border_style(color = 0, radius = 50)},
	)

	if knob.node.id == ctx.hot_widget_id {
		if .Down in ctx.mouse.events[.Left] {
			rel := ctx.mouse.position.x - railing.position.x
			normalized := clamp(rel / railing.size.x, 0, 1)
			value^ = min + (max - min) * normalized
		}
	}

	label_holder := cu.create_widget(
		ctx,
		"slider_knob_current_value_holder",
		cu.floating(cu.layout(cu.sizing(cu.grow(), cu.fit()), child_alignment = cu.child_alignment(.Center, .Center)), .Left_Top, .Left_Top),
		event_passthrough = true,
	)
	label_holder.z_index -= math.max(int) / 2

	cu.push_parent(ctx, label_holder)
	cu.create_widget(
		ctx,
		"slider_knob_current_value_text",
		cu.Text{text = fmt.tprint(value^)},
		tags = {"text small secondary"},
		offset = {cu.offset_percent(knob_offset), cu.offset_absolute(12)},
		event_passthrough = true,
	)
	cu.pop_parent(ctx)
	cu.pop_parent(ctx)
	cu.create_widget(ctx, "slider_min_value", cu.text(fmt.tprint(max)), tags = {"text small primary"})

	cu.pop_parent(ctx)
}

frame :: proc(
	ctx: ^cu.Core_Context,
	label: string,
	padding: cu.Vec4f32 = {24, 12, 12, 12},
	child_gap: f32 = 8,
	direction: cu.Axis = .Y,
	clip_value: f32 = 0,
) -> bool {
	frame_w := cu.create_widget(
		ctx,
		label,
		cu.layout(cu.sizing(cu.grow(128, 512), cu.fit()), direction = direction, child_gap = child_gap),
		clip = cu.clip({}, cu.clip_auto(50)),
		tags = {"border"},
		style = {color = 0, padding = padding},
	)
	cu.push_parent(ctx, frame_w)

	title_holder := cu.create_widget(
		ctx,
		"Frame_floating",
		cu.floating(cu.layout(cu.sizing(cu.fit(), cu.fit())), .Left_Top, .Left_Top),
		tags = {"border"},
		offset = cu.offset(cu.offset_absolute(6), cu.offset_percent_self(-0.5)),
		style = {padding = {4, 8, 4, 8}, color = BACKGROUND_COLOR},
	)

	cu.push_parent(ctx, title_holder)
	cu.create_widget(ctx, "frame_floating_text", cu.text(label), tags = {"text big primary"})
	cu.pop_parent(ctx)
	return true
}

update_edit_state :: proc(state: ^edit.State) {
	char := rl.GetCharPressed()

	if cast(bool)char {
		edit.input_rune(state, char)
	}

	if rl.IsKeyPressed(.ENTER) {
		edit.perform_command(state, .New_Line)
	}

	if rl.IsKeyPressed(.BACKSPACE) {
		edit.perform_command(state, .Backspace)
	}

	if rl.IsKeyPressed(.DELETE) {
		edit.perform_command(state, .Delete)
	}

	if rl.IsKeyPressed(.A) && rl.IsKeyDown(.LEFT_CONTROL) {
		edit.perform_command(state, .Select_All)
	}

	if rl.IsKeyPressed(.LEFT) {
		if rl.IsKeyDown(.LEFT_CONTROL) && rl.IsKeyDown(.LEFT_SHIFT) {
			edit.perform_command(state, .Select_Word_Left)
		} else if rl.IsKeyDown(.LEFT_SHIFT) {
			edit.perform_command(state, .Select_Left)
		} else if rl.IsKeyDown(.LEFT_CONTROL) {
			edit.perform_command(state, .Word_Left)
		} else {
			edit.perform_command(state, .Left)
		}
	}

	if rl.IsKeyPressed(.RIGHT) {
		if rl.IsKeyDown(.LEFT_CONTROL) && rl.IsKeyDown(.LEFT_SHIFT) {
			edit.perform_command(state, .Select_Word_Right)
		} else if rl.IsKeyDown(.LEFT_SHIFT) {
			edit.perform_command(state, .Select_Right)
		} else if rl.IsKeyDown(.LEFT_CONTROL) {
			edit.perform_command(state, .Word_Right)
		} else {
			edit.perform_command(state, .Right)
		}
	}

	if rl.IsKeyPressed(.UP) {
		if rl.IsKeyDown(.LEFT_SHIFT) {
			edit.perform_command(state, .Select_Up)
		} else {
			edit.perform_command(state, .Up)
		}
	}

	if rl.IsKeyPressed(.DOWN) {
		if rl.IsKeyDown(.LEFT_SHIFT) {
			edit.perform_command(state, .Select_Down)
		} else {
			edit.perform_command(state, .Down)
		}
	}

	if rl.IsKeyPressed(.HOME) {
		if rl.IsKeyDown(.LEFT_CONTROL) {
			edit.perform_command(state, .Start)
		} else {
			edit.perform_command(state, .Line_Start)
		}
	}

	if rl.IsKeyPressed(.END) {
		if rl.IsKeyDown(.LEFT_CONTROL) {
			edit.perform_command(state, .End)
		} else {
			edit.perform_command(state, .Line_End)
		}
	}
}
