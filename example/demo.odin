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


PRIMARY_COLOR :: cu.Color{120, 113, 108, 255} // warm gray-500 (#78716C)
ON_PRIMARY_COLOR :: cu.Color{255, 255, 255, 255} // white

BACKGROUND_COLOR :: cu.Color{20, 20, 22, 255} // neutral dark gray (#141416)
SURFACE_COLOR :: cu.Color{34, 34, 36, 255} // slightly lighter (#222224)
ELEVATED_SURFACE_COLOR :: cu.Color{58, 58, 60, 255} // soft charcoal (#3A3A3C)

TEXT_PRIMARY_COLOR :: cu.Color{245, 245, 244, 255} // warm gray-100 (#F5F5F4)
TEXT_SECONDARY_COLOR :: cu.Color{168, 162, 158, 255} // warm gray-400 (#A8A29E)
TEXT_DISABLED_COLOR :: cu.Color{120, 113, 108, 255} // warm gray-500 (#78716C)

SUCCESS_COLOR :: cu.Color{77, 124, 15, 255} // olive green (#4D7C0F)
WARNING_COLOR :: cu.Color{202, 138, 4, 255} // golden amber (#CA8A04)
ERROR_COLOR :: cu.Color{153, 27, 27, 255} // dark red (#991B1B)
INFO_COLOR :: cu.Color{115, 115, 115, 255} // neutral gray (#737373)

BORDER_COLOR :: cu.Color{87, 83, 78, 255} // warm gray-700 (#57534E)
DIVIDER_COLOR :: cu.Color{113, 109, 104, 255} // warm gray-600 (#716D68)

jet_brains_mono: rl.Font

demo :: proc() {
	rl.SetConfigFlags({.WINDOW_RESIZABLE, .MSAA_4X_HINT})
	rl.InitWindow(700, 700, "Balls?")
	defer rl.CloseWindow()

	ctx := cu.init_core_context(256)
	defer cu.deinit_core_context(&ctx)

	ctx.mouse.double_click_timeout = time.Millisecond * 300
	ctx.mouse.long_down_timeout = time.Millisecond * 1000
	ctx.text_measure_proc = measure_text

	sdf_shader := rl.LoadShader("", "./assets/rounded_rect_shader.frag")
	img := rl.GenImageColor(1, 1, rl.WHITE)
	render_texture := rl.LoadTextureFromImage(img)
	rl.UnloadImage(img)
	defer rl.UnloadTexture(render_texture)
	tick := rl.LoadTexture("./assets/tick.png")
	defer rl.UnloadTexture(tick)


	jet_brains_mono = rl.LoadFontEx("./assets/JetBrainsMono-Regular.ttf", 64, nil, 0)

	rl.SetTargetFPS(60)

	aaloo := rl.LoadTexture("./assets/DA TRULY BIG AALOO.jpg")
	aaloo_tint := cu.Color{255, 255, 255, 255}

	buffer := strings.Builder{}
	state := edit.State{}
	edit.init(&state, context.allocator, context.allocator)
	edit.setup_once(&state, &buffer)

	buttons_event_log: [dynamic]string

	for !rl.WindowShouldClose() {
		defer clear(&buttons_event_log)
		ctx.window_width = cast(f32)rl.GetScreenWidth()
		ctx.window_height = cast(f32)rl.GetScreenHeight()
		ctx.delta_time = rl.GetFrameTime()
		ctx.mouse.position = rl.GetMousePosition()
		ctx.mouse.scroll = rl.GetMouseWheelMove()
		ctx.mouse.scroll_v = rl.GetMouseWheelMoveV()

		if rl.IsMouseButtonDown(.LEFT) {ctx.mouse.events += {.Left_Down}}
		if rl.IsMouseButtonDown(.RIGHT) {ctx.mouse.events += {.Right_Down}}
		if rl.IsMouseButtonDown(.MIDDLE) {ctx.mouse.events += {.Middle_Down}}
		if rl.IsMouseButtonPressed(.LEFT) {ctx.mouse.events += {.Left_Pressed}}
		if rl.IsMouseButtonPressed(.RIGHT) {ctx.mouse.events += {.Right_Pressed}}
		if rl.IsMouseButtonPressed(.MIDDLE) {ctx.mouse.events += {.Middle_Pressed}}
		if rl.IsMouseButtonReleased(.LEFT) {ctx.mouse.events += {.Left_Released}}
		if rl.IsMouseButtonReleased(.RIGHT) {ctx.mouse.events += {.Right_Released}}
		if rl.IsMouseButtonReleased(.MIDDLE) {ctx.mouse.events += {.Middle_Released}}

		char := rl.GetCharPressed()

		if cast(bool)char {
			edit.input_rune(&state, char)
		}

		if rl.IsKeyPressed(.ENTER) {
			edit.perform_command(&state, .New_Line)
		}

		if rl.IsKeyPressed(.BACKSPACE) {
			edit.perform_command(&state, .Backspace)
		}

		if rl.IsKeyPressed(.DELETE) {
			edit.perform_command(&state, .Delete)
		}

		if rl.IsKeyPressed(.A) && rl.IsKeyDown(.LEFT_CONTROL) {
			edit.perform_command(&state, .Select_All)
		}

		if rl.IsKeyPressed(.LEFT) {
			if rl.IsKeyDown(.LEFT_CONTROL) && rl.IsKeyDown(.LEFT_SHIFT) {
				edit.perform_command(&state, .Select_Word_Left)
			} else if rl.IsKeyDown(.LEFT_SHIFT) {
				edit.perform_command(&state, .Select_Left)
			} else if rl.IsKeyDown(.LEFT_CONTROL) {
				edit.perform_command(&state, .Word_Left)
			} else {
				edit.perform_command(&state, .Left)
			}
		}

		if rl.IsKeyPressed(.RIGHT) {
			if rl.IsKeyDown(.LEFT_CONTROL) && rl.IsKeyDown(.LEFT_SHIFT) {
				edit.perform_command(&state, .Select_Word_Right)
			} else if rl.IsKeyDown(.LEFT_SHIFT) {
				edit.perform_command(&state, .Select_Right)
			} else if rl.IsKeyDown(.LEFT_CONTROL) {
				edit.perform_command(&state, .Word_Right)
			} else {
				edit.perform_command(&state, .Right)
			}
		}

		if rl.IsKeyPressed(.UP) {
			if rl.IsKeyDown(.LEFT_SHIFT) {
				edit.perform_command(&state, .Select_Up)
			} else {
				edit.perform_command(&state, .Up)
			}
		}

		if rl.IsKeyPressed(.DOWN) {
			if rl.IsKeyDown(.LEFT_SHIFT) {
				edit.perform_command(&state, .Select_Down)
			} else {
				edit.perform_command(&state, .Down)
			}
		}

		if rl.IsKeyPressed(.HOME) {
			if rl.IsKeyDown(.LEFT_CONTROL) {
				edit.perform_command(&state, .Start)
			} else {
				edit.perform_command(&state, .Line_Start)
			}
		}

		if rl.IsKeyPressed(.END) {
			if rl.IsKeyDown(.LEFT_CONTROL) {
				edit.perform_command(&state, .End)
			} else {
				edit.perform_command(&state, .Line_End)
			}
		}

		cu.begin_ui(&ctx)

		root := cu.create_widget(
			&ctx,
			cu.Layout{sizing = cu.sizing(cu.fixed(ctx.window_width), cu.fixed(ctx.window_height)), direction = .X, child_gap = 16},
			style = {padding = 32, color = BACKGROUND_COLOR},
		)

		cu.push_parent(&ctx, root)
		@(static) sidebar_clip_val: f32
		sidebar_clip_val += rl.GetMouseWheelMove() * 15

		if frame(&ctx, "Buttons", {24, 12, 12, 12}, 16, clip_value = sidebar_clip_val) {
			e_1 := button(&ctx, "Test 1", &tick, "Flickering is due to Id's not being created with constant data.")
			e_2 := button(&ctx, "Test 2", &tick, "Reading tool tips?")
			e_3 := button(&ctx, "Test 3", &tick, "Well well well")

			for e in e_1 {
				e_string := reflect.enum_string(e)
				append(&buttons_event_log, e_string)
			}
			for e in e_2 {
				e_string := reflect.enum_string(e)
				append(&buttons_event_log, e_string)
			}
			for e in e_3 {
				e_string := reflect.enum_string(e)
				append(&buttons_event_log, e_string)
			}

			@(static) toggle: bool
			@(static) label: string
			toggle_button(&ctx, label, &toggle, nil, "Toggle to reveal secrets of universe")

			if toggle {
				label = "Toggled"
				@(static) toggle_2: bool
				toggle_button(&ctx, "42", &toggle_2, nil, "Very dynamic eh : )")
				if toggle_2 {
					button(&ctx, "Yes.", nil, nil)
				}
			} else {
				label = "Toggle"
			}

			if frame(&ctx, "Button_logs") {

				for log in buttons_event_log {
					cu.create_widget(&ctx, cu.text(log, .None, {color = TEXT_PRIMARY_COLOR, font_size = 20, letter_spacing = 1}))
				}

				cu.pop_parent(&ctx)
			}

			cu.pop_parent(&ctx)
		}

		if frame(&ctx, "Text_Wrap", {34, 12, 12, 12}, child_gap = 24) {
			if frame(&ctx, "Wrap_Words") {
				cu.create_widget(
					&ctx,
					cu.text("A quick brown fox jumps over the lazy dog", style = {font_size = 20, letter_spacing = 2, color = TEXT_PRIMARY_COLOR}),
				)
				cu.pop_parent(&ctx)
			}
			if frame(&ctx, "Wrap_New_Lines") {
				cu.create_widget(
					&ctx,
					cu.text(
						"A quick \nbrown \nfox \njumps over \nthe lazy \ndog",
						.New_Lines,
						style = {font_size = 20, letter_spacing = 2, color = TEXT_PRIMARY_COLOR},
					),
				)
				cu.pop_parent(&ctx)
			}
			if frame(&ctx, "Wrap_None") {
				cu.create_widget(
					&ctx,
					cu.text(
						"A quick brown fox jumps over the lazy dog",
						.None,
						style = {font_size = 20, letter_spacing = 2, color = TEXT_PRIMARY_COLOR},
					),
				)
				cu.pop_parent(&ctx)
			}
			if frame(&ctx, "Wrap_Letters") {
				cu.create_widget(
					&ctx,
					cu.text(
						"A quick brown fox jumps over the lazy dog",
						.Letters,
						style = {font_size = 20, letter_spacing = 2, color = TEXT_PRIMARY_COLOR},
					),
				)
				cu.pop_parent(&ctx)
			}
			cu.pop_parent(&ctx)
		}


		if frame(&ctx, "Text_Input") {
			t := cu.create_widget(
				&ctx,
				cu.text(
					transmute(string)buffer.buf[:],
					.Letters,
					{color = TEXT_PRIMARY_COLOR, font_size = 16, letter_spacing = 1},
					cursor = state.selection,
				),
				string_id = "Text_Input",
			)
			type := t.type.(cu.Text)
		}
		cu.pop_parent(&ctx)

		if frame(&ctx, "Aaloo_Voodoo", {32, 12, 12, 12}, 8) {
			if frame(&ctx, "Aaloos") {
				cu.create_widget(
					&ctx,
					cu.layout(cu.sizing(cu.grow())),
					image = cu.Image{image_data = &aaloo, tint = aaloo_tint},
					aspect_ratio = cast(f32)aaloo.width / cast(f32)aaloo.height,
				)
				cu.pop_parent(&ctx)
			}

			if frame(&ctx, "Aaloo_Tint") {
				elem_names := [?]string{"r", "g", "b", "a"}
				for &elem, i in aaloo_tint {
					val := cast(f32)(elem)
					slider(&ctx, elem_names[i], &val, 0, 255)
					elem = cast(u8)val
				}
				cu.pop_parent(&ctx)
			}

			button(&ctx, "Hm", nil, "hm")

			cu.pop_parent(&ctx)
		}
		cu.pop_parent(&ctx)


		cu.end_ui(&ctx)

		// for command in ctx.render_commands {
		// 	if start, ok := command.type.(cu.Command_Clip_Start); ok {
		// 		fmt.println(command.z_index, start)
		// 	}
		// 	if end, ok := command.type.(cu.Command_Clip_End); ok {
		// 		fmt.println(command.z_index, end)
		// 	}
		// }
		//
		// fmt.println("\n\n\n")

		rl.BeginDrawing()
		rl.ClearBackground(rl.BLANK)
		render(ctx, render_texture, sdf_shader)
		rl.EndDrawing()
		free_all(context.temp_allocator)
	}
}

button :: proc(ctx: ^cu.Core_Context, label: string, icon: rawptr, tooltip: Maybe(string)) -> cu.Widget_Events {
	body := cu.create_widget(
		ctx,
		cu.layout(cu.sizing(cu.grow(max = 128), cu.fit(16)), 8, .X, {.Center, .Center}),
		string_id = "buttons",
		style = cu.Style{color = SURFACE_COLOR, padding = 4, border = cu.border_style(BORDER_COLOR, cu.Border_Kind.Single)},
	)

	if cu.push_parent(ctx, body) {
		defer cu.pop_parent(ctx)

		label_widget := cu.create_widget(
			ctx,
			cu.text(label, style = cu.Text_Style{color = TEXT_PRIMARY_COLOR, font_size = 16, letter_spacing = 1}),
			event_passthrough = true,
		)

		if icon != nil {
			icon := cast(^rl.Texture)icon
			cu.create_widget(
				ctx,
				cu.layout(cu.sizing(cu.fixed(cast(f32)icon.width), cu.fixed(cast(f32)icon.height))),
				aspect_ratio = 1.0,
				image = cu.Image{icon, 255},
				style = {color = 0},
				event_passthrough = true,
			)
		}

		if tooltip, ok := tooltip.(string); ok && .Hovered in body.events {
			offset_value := ctx.mouse.position - body.position
			fixed_size: [2]f32 = {ctx.window_width - body.position.x, ctx.window_height - body.position.y} - offset_value - 32
			floating_holder := cu.create_widget(
				ctx,
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
					cu.text(text = tooltip, style = {color = TEXT_SECONDARY_COLOR, letter_spacing = 1, font_size = 16}),
					offset = [2]cu.Offset{cu.offset_absolute(offset_value.x), cu.offset_absolute(offset_value.y)},
					style = {color = ELEVATED_SURFACE_COLOR, padding = 16, border = cu.border_style(BORDER_COLOR, cu.Border_Kind.Single)},
					event_passthrough = true,
				)
			}
		}
	}

	return body.events
}

toggle_button :: proc(ctx: ^cu.Core_Context, label: string, toggle: ^bool, icon: rawptr, tooltip: Maybe(string)) -> cu.Widget_Events {

	border_style := cu.border_style({BORDER_COLOR, BORDER_COLOR, BORDER_COLOR, ERROR_COLOR}, cu.Border_Kind.Single, 0, 1)
	text_color := TEXT_DISABLED_COLOR
	if toggle^ {
		border_style = cu.border_style({BORDER_COLOR, BORDER_COLOR, BORDER_COLOR, SUCCESS_COLOR}, cu.Border_Kind.Single, 0, {1, 1, 1, 1})
		text_color = TEXT_PRIMARY_COLOR
	}

	body := cu.create_widget(
		ctx,
		cu.layout(cu.sizing(cu.grow(max = 128), cu.fit(16)), 8, .X, {.Center, .Center}),
		string_id = "buttons",
		style = cu.Style{color = SURFACE_COLOR, padding = 4, border = border_style},
	)

	if .Left_Clicked in body.events {
		toggle^ = !toggle^
	}

	if cu.push_parent(ctx, body) {
		defer cu.pop_parent(ctx)

		label_widget := cu.create_widget(
			ctx,
			cu.text(label, style = cu.Text_Style{color = text_color, font_size = 16, letter_spacing = 1}),
			event_passthrough = true,
		)

		if icon != nil {
			icon := cast(^rl.Texture)icon
			cu.create_widget(
				ctx,
				cu.layout(cu.sizing(cu.fixed(cast(f32)icon.width), cu.fixed(cast(f32)icon.height))),
				aspect_ratio = 1.0,
				image = cu.Image{icon, 255},
				style = {color = 0},
				event_passthrough = true,
			)
		}

		if tooltip, ok := tooltip.(string); ok && .Hovered in body.events {
			offset_value := ctx.mouse.position - body.position
			fixed_size: [2]f32 = {ctx.window_width - body.position.x, ctx.window_height - body.position.y} - offset_value - 32
			floating_holder := cu.create_widget(
				ctx,
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
					cu.text(text = tooltip, style = {color = TEXT_SECONDARY_COLOR, letter_spacing = 1, font_size = 16}),
					offset = [2]cu.Offset{cu.offset_absolute(offset_value.x), cu.offset_absolute(offset_value.y)},
					style = {color = ELEVATED_SURFACE_COLOR, padding = 16, border = cu.border_style(BORDER_COLOR, cu.Border_Kind.Single)},
					event_passthrough = true,
				)
			}
		}
	}

	return body.events
}

slider :: proc(ctx: ^cu.Core_Context, label: string, value: ^f32, min, max: f32) {
	main_container := cu.create_widget(
		ctx,
		cu.Layout{sizing = cu.sizing(cu.grow(50), cu.fit(min = 16, max = 32)), child_gap = 16, direction = .X, child_alignment = {.Center, .Center}},
		string_id = "slider",
		style = cu.Style{padding = 4},
		event_passthrough = true,
	)
	cu.push_parent(ctx, main_container)
	cu.create_widget(
		ctx,
		cu.text(label, style = {color = TEXT_PRIMARY_COLOR, font_size = 20}),
		style = {border = cu.border_style(BORDER_COLOR), padding = 8},
	)

	cu.create_widget(
		ctx,
		cu.text(style = {letter_spacing = 1, font_size = 16, line_spacing = 0, color = TEXT_PRIMARY_COLOR}, text = fmt.tprint(min)),
	)

	railing := cu.create_widget(
		ctx,
		cu.layout(sizing = cu.sizing(cu.grow(), cu.fixed(4)), direction = .Y, child_alignment = {.Center, .Center}),
		style = cu.Style{color = SURFACE_COLOR},
	)

	cu.push_parent(ctx, railing)

	knob_offset := clamp((value^ - min) / (max - min) - 0.5, -0.5, 0.5)

	knob := cu.create_widget(
		ctx,
		cu.Layout{sizing = cu.sizing(cu.fixed(20), cu.fixed(20))},
		offset = cu.offset(cu.offset_percent(knob_offset)),
		style = cu.Style{color = ELEVATED_SURFACE_COLOR, border = cu.border_style(color = 0, radius = 50)},
	)

	if .Left_Down in knob.events {
		rel := ctx.mouse.position.x - railing.position.x
		normalized := clamp(rel / railing.size.x, 0, 1)
		value^ = min + (max - min) * normalized
	}

	label_holder := cu.create_widget(
		ctx,
		cu.floating(cu.layout(cu.sizing(cu.grow(), cu.fit()), child_alignment = cu.child_alignment(.Center, .Center)), .Left_Top, .Left_Top),
		event_passthrough = true,
	)
	label_holder.z_index -= math.max(int) / 2

	cu.push_parent(ctx, label_holder)
	cu.create_widget(
		ctx,
		cu.Text{text = fmt.tprint(value^), style = {letter_spacing = 1, font_size = 16, line_spacing = 0, color = TEXT_SECONDARY_COLOR}},
		{},
		offset = {cu.offset_percent(knob_offset), cu.offset_absolute(12)},
		event_passthrough = true,
	)
	cu.pop_parent(ctx)
	cu.pop_parent(ctx)
	cu.create_widget(
		ctx,
		cu.Text{style = {letter_spacing = 1, font_size = 16, line_spacing = 0, color = TEXT_PRIMARY_COLOR}, text = fmt.tprint(max)},
	)

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
		cu.layout(cu.sizing(cu.grow(128, 512), cu.fit()), direction = direction, child_gap = child_gap),
		string_id = label,
		clip = cu.clip({}, cu.clip_auto(100)),
		style = {color = 0, padding = padding, border = cu.border_style(BORDER_COLOR)},
	)
	cu.push_parent(ctx, frame_w)

	title_holder := cu.create_widget(
		ctx,
		cu.floating(cu.layout(cu.sizing(cu.fit(), cu.fit())), .Left_Top, .Left_Top),
		offset = cu.offset(cu.offset_absolute(6), cu.offset_percent_self(-0.5)),
		style = {padding = {4, 8, 4, 8}, color = BACKGROUND_COLOR, border = cu.border_style(BORDER_COLOR)},
	)

	cu.push_parent(ctx, title_holder)
	cu.create_widget(ctx, cu.text(label, style = {color = TEXT_PRIMARY_COLOR, font_size = 20}))
	cu.pop_parent(ctx)
	return true
}
