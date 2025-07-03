package main

import "core:fmt"
import "core:time"

import rl "vendor:raylib"

import cu "../"

demo :: proc() {
	rl.SetConfigFlags({.WINDOW_RESIZABLE})
	rl.InitWindow(700, 700, "Balls?")
	defer rl.CloseWindow()

	ctx := cu.init_core_context(128)
	defer cu.deinit_core_context(&ctx)

	ctx.mouse.double_click_timeout = time.Millisecond * 300
	ctx.mouse.long_down_timeout = time.Millisecond * 1000
	ctx.text_measure_proc = measure_text

	sdf_shader := rl.LoadShader("", "./rounded_rect_shader.frag")

	img := rl.GenImageColor(1, 1, rl.WHITE)
	render_texture := rl.LoadTextureFromImage(img)
	rl.UnloadImage(img)
	defer rl.UnloadTexture(render_texture)

	rl.SetTargetFPS(60)

	x_align: cu.Child_Alignment_X
	y_align: cu.Child_Alignment_Y
	direc: cu.Axis = .Y

	slider_val: f32 = 10
	toggle: bool
	toggle_2: bool
	label := "Not Hovered"
	toggle_text := "Toggle me uwu"
	ellipse_color: cu.Color = GREEN
	rect_color: cu.Color = BLUE
	line_color: cu.Color = RED
	for !rl.WindowShouldClose() {
		ctx.window_width = cast(f32)rl.GetScreenWidth()
		ctx.window_height = cast(f32)rl.GetScreenHeight()
		ctx.delta_time = rl.GetFrameTime() * 2
		ctx.mouse.position = rl.GetMousePosition()

		if rl.IsMouseButtonDown(.LEFT) {ctx.mouse.events += {.Left_Down}}
		if rl.IsMouseButtonDown(.RIGHT) {ctx.mouse.events += {.Right_Down}}
		if rl.IsMouseButtonDown(.MIDDLE) {ctx.mouse.events += {.Middle_Down}}
		if rl.IsMouseButtonPressed(.LEFT) {ctx.mouse.events += {.Left_Pressed}}
		if rl.IsMouseButtonPressed(.RIGHT) {ctx.mouse.events += {.Right_Pressed}}
		if rl.IsMouseButtonPressed(.MIDDLE) {ctx.mouse.events += {.Middle_Pressed}}
		if rl.IsMouseButtonReleased(.LEFT) {ctx.mouse.events += {.Left_Released}}
		if rl.IsMouseButtonReleased(.RIGHT) {ctx.mouse.events += {.Right_Released}}
		if rl.IsMouseButtonReleased(.MIDDLE) {ctx.mouse.events += {.Middle_Released}}

		cu.begin_ui(&ctx)

		style := cu.Style {
			color   = CHILD_BACKGROUND,
			padding = 16,
			border  = cu.border(255),
		}

		root := cu.create_widget(
			&ctx,
			cu.Layout{sizing = cu.sizing(cu.fixed(ctx.window_width), cu.fixed(ctx.window_height)), direction = .X, child_gap = 10},
			style = {padding = 16, color = DEFAULT_BACKGROUND},
		)
		cu.push_parent(&ctx, root)

		side_bar := cu.create_widget(&ctx, cu.Layout{sizing = cu.sizing(cu.percent(0.3), cu.grow()), child_gap = 16, direction = .Y}, style = style)
		if cu.push_parent(&ctx, side_bar) {
			defer cu.pop_parent(&ctx)
			cu.create_widget(
				&ctx,
				cu.Text{text = "Some composite widgets", style = {font_size = 20, letter_spacing = 1, color = GREEN}},
				style = cu.Style{color = DEFAULT_BACKGROUND},
			)
			slider(&ctx, &slider_val, 5, 15)

			toggle_button(&ctx, toggle_text, &toggle)

			if toggle {
				toggle_text = "Untoggle me Now"
			} else {
				toggle_text = "Toggle me UWU"
			}

			if .Hovered in button(&ctx, label) {
				label = "Hovered"
			} else {
				label = "Not Hovered"
			}
		}

		w_2 := cu.create_widget(
			&ctx,
			cu.Layout{sizing = cu.sizing(cu.grow(), cu.grow()), direction = .X, child_alignment = {x = .Left}, child_gap = 16},
			style = style,
		)
		style.padding = 16
		if cu.push_parent(&ctx, w_2) {
			defer cu.pop_parent(&ctx)
			style.color = DEFAULT_BACKGROUND
			cu.create_widget(
				&ctx,
				cu.Text{text = "Some primitive Shapes", style = {font_id = 0, font_size = 20, line_spacing = 0, letter_spacing = 1, color = WHITE}},
				style = {color = ORANGE, padding = 16, border = cu.border(255)},
			)
			cu.create_primitive(&ctx, cu.Primitive_Ellipse{size = {100, 50}, position = {300, 300}, color = ellipse_color})
			cu.create_primitive(&ctx, cu.Primitive_Rect{size = {100, 100}, position = {100, 100}, color = rect_color, thickness = 2, fill = .Line})
			cu.create_primitive(&ctx, cu.Primitive_Line{start_position = {100, 100}, end_position = {300, 300}, thickness = 5, color = line_color})
			style.padding = {0, 16, 0, 16}
			w_23 := cu.create_widget(
				&ctx,
				cu.Floating {
					parent = .Right_Bottom,
					element = .Right_Bottom,
					attachment_to = .Parent,
					layout = cu.Layout{sizing = cu.sizing(cu.percent(0.5), cu.percent(0.5)), child_gap = 16, direction = .Y},
				},
				style = style,
			)
			if cu.push_parent(&ctx, w_23) {
				defer cu.pop_parent(&ctx)
				style.color = CHILD_BACKGROUND
				cu.create_widget(
					&ctx,
					cu.Text {
						text = "Oi, I am A Floating Widget!",
						style = {font_id = 0, font_size = 20, line_spacing = 0, letter_spacing = 1, color = WHITE},
					},
					style = {color = ORANGE, padding = 16, border = cu.border(255)},
				)

				cont_1 := cu.create_widget(&ctx, cu.Layout{sizing = cu.sizing(cu.grow(), cu.fit()), child_alignment = {.Center, .Center}})
				if cu.push_parent(&ctx, cont_1) {
					defer cu.pop_parent(&ctx)
					cu.create_widget(&ctx, cu.Text{text = "Ellipse", style = {color = 255, font_size = 20, letter_spacing = 1}})
					for &col in ellipse_color {
						col_f32 := cast(f32)col
						slider(&ctx, &col_f32, 0, 255)
						col = cast(u8)col_f32
					}
				}
				cont_2 := cu.create_widget(&ctx, cu.Layout{sizing = cu.sizing(cu.grow(), cu.fit()), child_alignment = {.Center, .Center}})
				if cu.push_parent(&ctx, cont_2) {
					defer cu.pop_parent(&ctx)
					cu.create_widget(&ctx, cu.Text{text = "Rect", style = {color = 255, font_size = 20, letter_spacing = 1}})
					for &col in rect_color {
						col_f32 := cast(f32)col
						slider(&ctx, &col_f32, 0, 255)
						col = cast(u8)col_f32
					}
				}

				cont_3 := cu.create_widget(&ctx, cu.Layout{sizing = cu.sizing(cu.grow(), cu.fit()), child_alignment = {.Center, .Center}})
				if cu.push_parent(&ctx, cont_3) {
					defer cu.pop_parent(&ctx)
					cu.create_widget(&ctx, cu.Text{text = "Line", style = {color = 255, font_size = 20, letter_spacing = 1}})
					for &col in line_color {
						col_f32 := cast(f32)col
						slider(&ctx, &col_f32, 0, 255)
						col = cast(u8)col_f32
					}
				}
			}
		}

		style.color = CHILD_BACKGROUND

		if rl.IsKeyPressed(.UP) {
			y_align = .Top
		}
		if rl.IsKeyPressed(.DOWN) {
			y_align = .Bottom
		}
		if rl.IsKeyPressed(.LEFT) {
			x_align = .Left
		}
		if rl.IsKeyPressed(.RIGHT) {
			x_align = .Right
		}
		if rl.IsKeyPressed(.KP_1) {
			x_align = .Center
		}
		if rl.IsKeyPressed(.KP_2) {
			y_align = .Center
		}

		if rl.IsKeyPressed(.R) {
			direc = .X
		}
		if rl.IsKeyPressed(.C) {
			direc = .Y
		}

		w_3 := cu.create_widget(
			&ctx,
			cu.Layout{sizing = cu.sizing(cu.grow(), cu.grow()), direction = direc, child_alignment = {x = x_align, y = y_align}, child_gap = 16},
			style = style,
		)
		{
			cu.push_parent(&ctx, w_3)
			defer cu.pop_parent(&ctx)
			style.color = DEFAULT_BACKGROUND
			cu.create_widget(
				&ctx,
				cu.Text {
					text = "Text wrapping and padding",
					style = {font_id = 0, letter_spacing = 1, font_size = 20, line_spacing = 0, color = ORANGE},
				},
				style = {color = DEFAULT_BACKGROUND, padding = 16, border = cu.border(255)},
			)
			c := cu.create_widget(
				&ctx,
				cu.Layout{sizing = cu.sizing(cu.grow(), cu.fit()), child_gap = 16},
				style = {color = RED, padding = 16, border = cu.border(255)},
			)
			cu.push_parent(&ctx, c)
			cu.create_widget(
				&ctx,
				cu.Text {
					text = "A quick brown fox jumps over the lazy dog",
					style = {font_id = 0, letter_spacing = 1, font_size = 30, line_spacing = 0, color = ORANGE},
				},
				style = {color = DEFAULT_BACKGROUND, padding = 16, border = cu.border(255)},
			)
			cu.create_widget(
				&ctx,
				cu.Text {
					text = "Why Does A quick brown Jumps over the lazy Dog?",
					style = {font_id = 0, letter_spacing = 5, font_size = 15, line_spacing = 5, color = BLUE},
				},
				style = {color = DEFAULT_BACKGROUND, padding = 16, border = cu.border(255)},
			)
			cu.create_widget(
				&ctx,
				cu.Text {
					text = "When Does A quick brown Jumps over the lazy Dog?",
					style = {font_id = 0, letter_spacing = 10, font_size = 10, line_spacing = 0, color = GREEN},
				},
				style = {color = DEFAULT_BACKGROUND, padding = 16, border = cu.border(255)},
			)
			cu.pop_parent(&ctx)
			e := cu.create_widget(
				&ctx,
				cu.Layout{sizing = cu.sizing(cu.grow(), cu.grow()), child_gap = 16, direction = .Y, child_alignment = {.Center, .Center}},
				style = {color = DEFAULT_BACKGROUND, padding = {16, 0, 16, 0}, border = cu.border(255)},
			)
			cu.push_parent(&ctx, e)
			cu.create_widget(
				&ctx,
				cu.Text{text = "Text Paddings", style = {font_id = 0, line_spacing = 0, font_size = 20, color = GREEN, letter_spacing = 1}},
				style = {color = CHILD_BACKGROUND, padding = 16, border = cu.border(GREEN)},
			)
			cu.create_widget(
				&ctx,
				cu.Text{text = "Left padded", style = {font_id = 0, line_spacing = 0, font_size = 20, color = GREEN, letter_spacing = 1}},
				style = {color = CHILD_BACKGROUND, padding = {0, 0, 0, 16}, border = cu.border(GREEN)},
			)
			cu.create_widget(
				&ctx,
				cu.Text{text = "Right padded", style = {font_id = 0, line_spacing = 0, font_size = 20, color = GREEN, letter_spacing = 1}},
				style = {color = CHILD_BACKGROUND, padding = {0, 16, 0, 0}, border = cu.border(GREEN)},
			)
			cu.create_widget(
				&ctx,
				cu.Text{text = "Top padded", style = {font_id = 0, line_spacing = 0, font_size = 20, color = GREEN, letter_spacing = 1}},
				style = {color = CHILD_BACKGROUND, padding = {16, 0, 0, 0}, border = cu.border(GREEN)},
			)
			cu.create_widget(
				&ctx,
				cu.Text{text = "Bottom padded", style = {font_id = 0, line_spacing = 0, font_size = 20, color = GREEN, letter_spacing = 1}},
				style = {color = CHILD_BACKGROUND, padding = {0, 0, 16, 0}, border = cu.border(GREEN)},
			)
			cu.pop_parent(&ctx)
		}
		style.color = CHILD_BACKGROUND
		w_4 := cu.create_widget(&ctx, cu.Layout{sizing = cu.sizing(cu.grow(50, 50), cu.grow(50, 50))}, style = style)

		cu.end_ui(&ctx)

		rl.BeginDrawing()
		rl.ClearBackground(rl.BLANK)
		render(ctx, render_texture, sdf_shader)
		rl.DrawFPS(10, 10)
		rl.EndDrawing()
		free_all(context.temp_allocator)
	}
}

slider :: proc(ctx: ^cu.Core_Context, value: ^f32, min, max: f32) {
	main_container := cu.create_widget(
		ctx,
		cu.Layout{sizing = cu.sizing(cu.grow(100), cu.grow(50, 100)), child_gap = 5, direction = .X, child_alignment = {.Center, .Center}},
		style = cu.Style{color = DEFAULT_BACKGROUND, border = cu.border(255), padding = 16},
	)
	cu.push_parent(ctx, main_container)

	cu.create_widget(
		ctx,
		cu.Text{style = {font_id = 0, letter_spacing = 1, font_size = 20, line_spacing = 0, color = {255, 255, 255, 255}}, text = fmt.tprint(min)},
	)

	railing := cu.create_widget(
		ctx,
		cu.Layout{sizing = cu.sizing(cu.grow(), cu.fixed(10)), direction = .Y, child_alignment = {.Center, .Center}},
		style = cu.Style{color = CHILD_BACKGROUND},
	)

	cu.push_parent(ctx, railing)

	knob_offset := (value^ - min) / (max - min) - 0.5

	knob := cu.create_widget(
		ctx,
		cu.Layout{sizing = cu.sizing(cu.fixed(20), cu.fixed(20))},
		offset = {cu.Offset{value = knob_offset, kind = .Percent}, cu.offset_percent_self(0.25)},
		style = cu.Style{color = BLUE, border = cu.Border_Style{}},
	)

	if .Left_Down in knob.events {
		rel := ctx.mouse.position.x - railing.position.x
		normalized := clamp(rel / railing.size.x, 0, 1)
		value^ = min + (max - min) * normalized
	}

	t := cu.create_widget(
		ctx,
		cu.Text {
			text = fmt.tprint(value^),
			style = {font_id = 0, letter_spacing = 1, font_size = 10, line_spacing = 0, color = {255, 255, 255, 255}},
		},
		{},
		offset = {cu.Offset{value = knob_offset, kind = .Percent}, cu.offset_absolute(5)},
	)

	cu.pop_parent(ctx)

	cu.create_widget(
		ctx,
		cu.Text{style = {font_id = 0, letter_spacing = 1, font_size = 20, line_spacing = 0, color = {255, 255, 255, 255}}, text = fmt.tprint(max)},
	)

	cu.pop_parent(ctx)
}

toggle_button :: proc(ctx: ^cu.Core_Context, label: string, toggle: ^bool) {
	main_container := cu.create_widget(
		ctx,
		cu.Layout{sizing = cu.sizing(cu.grow(), cu.grow(50, 100)), child_gap = 8, child_alignment = {.Center, .Center}},
		style = cu.Style{color = DEFAULT_BACKGROUND, border = cu.border(255), padding = 16},
	)
	cu.push_parent(ctx, main_container)

	e := cu.create_widget(ctx, cu.Layout{sizing = cu.sizing(cu.fixed(20), cu.fixed(20))}, style = cu.Style{color = RED, border = cu.Border_Style{}})

	if .Left_Clicked in e.events {
		toggle^ = !(toggle^)
	}

	cu.create_widget(
		ctx,
		cu.Text {
			text = label,
			style = cu.Text_Style{font_id = 0, font_size = 20, line_spacing = 0, letter_spacing = 1, color = {255, 255, 255, 255}},
		},
		style = cu.Style{color = GREEN},
	)
	cu.pop_parent(ctx)
}

button :: proc(ctx: ^cu.Core_Context, label: string) -> cu.Widget_Events {
	main_container := cu.create_widget(
		ctx,
		cu.Layout{sizing = cu.sizing(cu.grow(), cu.grow(50, 100)), child_gap = 10, child_alignment = {.Center, .Center}},
		style = cu.Style{color = DEFAULT_BACKGROUND, border = cu.border(255)},
	)
	cu.push_parent(ctx, main_container)
	cu.create_widget(
		ctx,
		cu.Text {
			text = label,
			style = cu.Text_Style{font_id = 0, font_size = 20, line_spacing = 0, letter_spacing = 1, color = {255, 255, 255, 255}},
		},
	)
	cu.pop_parent(ctx)
	return main_container.events
}
