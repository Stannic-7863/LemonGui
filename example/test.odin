package main

import cu "../"
import "core:fmt"
import rl "vendor:raylib"

FIT_X :: cu.Layout {
	sizing = {.X = cu.Sizing{kind = .Fit}, .Y = cu.Sizing{kind = .Fit}},
	direction = .X,
}
FIT_Y :: cu.Layout {
	sizing = {.X = cu.Sizing{kind = .Fit}, .Y = cu.Sizing{kind = .Fit}},
	direction = .Y,
}

GROW_X :: cu.Layout {
	sizing = {.X = cu.Sizing{kind = .Grow}, .Y = cu.Sizing{kind = .Grow}},
	direction = .X,
}
GROW_Y :: cu.Layout {
	sizing = {.X = cu.Sizing{kind = .Grow}, .Y = cu.Sizing{kind = .Grow}},
	direction = .Y,
}

FIXED_X :: cu.Layout {
	sizing = {.X = cu.Sizing{kind = .Fixed, min = 100, max = 100}, .Y = cu.Sizing{kind = .Fixed, min = 100, max = 100}},
	direction = .X,
}

FIXED_Y :: cu.Layout {
	sizing = {.X = cu.Sizing{kind = .Fixed, min = 100}, .Y = cu.Sizing{kind = .Fixed, min = 100}},
	direction = .Y,
}

test :: proc() {
	rl.SetConfigFlags({.WINDOW_RESIZABLE})
	rl.InitWindow(700, 700, "Balls?")
	defer rl.CloseWindow()

	ctx := cu.init_core_context(128)
	defer cu.deinit_core_context(&ctx)
	ctx.text_measure_proc = measure_text

	sdf_shader := rl.LoadShader("", "./rounded_rect_shader.frag")
	img := rl.GenImageColor(1, 1, rl.WHITE)
	render_texture := rl.LoadTextureFromImage(img)
	rl.UnloadImage(img)

	nerd := rl.LoadTexture("./nerd.jpg")

	defer rl.UnloadTexture(nerd)
	defer rl.UnloadTexture(render_texture)
	defer rl.UnloadShader(sdf_shader)

	test_mode: enum {
		Text,
		Pure_Layout,
		Floating_Layout,
		Clip,
	} = .Clip
	rl.SetTargetFPS(60)

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

		if rl.IsKeyPressed(.DOWN) {
			test_mode = cast(type_of(test_mode))((cast(int)test_mode + 1) % (cast(int)max(type_of(test_mode)) + 1))
		}

		if rl.IsKeyPressed(.UP) {
			test_mode = cast(type_of(test_mode))((cast(int)test_mode - 1) %% (cast(int)max(type_of(test_mode)) + 1))
		}

		cu.begin_ui(&ctx)

		style := cu.Style {
			color   = BACKGROUND_COLOR,
			padding = 2,
			border  = cu.border_style(255),
		}

		root := cu.create_widget(
			&ctx,
			cu.Layout{sizing = cu.sizing(cu.fixed(ctx.window_width), cu.fixed(ctx.window_height)), direction = .X, child_gap = 16},
			style = {padding = 32, color = BACKGROUND_COLOR},
		)
		cu.push_parent(&ctx, root)

		switch test_mode {
		case .Pure_Layout:
			// fit_x_1 := cu.create_widget(&ctx, cu.Layout{sizing = cu.sizing(cu.fit(50), cu.fit(50)), child_gap = 16}, style = style)
			// if cu.push_parent(&ctx, fit_x_1) {
			// 	defer cu.pop_parent(&ctx)
			// 	style.padding = 2 //8
			// 	cu.create_widget(&ctx, cu.Layout{sizing = cu.sizing(cu.fixed(50), cu.fixed(50))}, style = style)
			// 	cu.create_widget(&ctx, cu.Layout{sizing = cu.sizing(cu.grow(70), cu.grow(70))}, style = style)
			// 	style.padding = 2 //16
			// 	grow_x_1 := cu.create_widget(&ctx, cu.Layout{sizing = cu.sizing(cu.grow(50), cu.grow(50)), child_gap = 16}, style = style)
			// 	if cu.push_parent(&ctx, grow_x_1) {
			// 		defer cu.pop_parent(&ctx)
			// 		cu.create_widget(&ctx, cu.Layout{sizing = cu.sizing(cu.fixed(50), cu.fixed(50))}, style = style)
			// 		style.padding = 2 //32
			// 		g := cu.create_widget(&ctx, cu.Layout{sizing = cu.sizing(cu.grow(70), cu.grow(70)), child_gap = 16}, style = style)
			// 		if cu.push_parent(&ctx, g) {
			// 			cu.create_widget(&ctx, cu.Layout{sizing = cu.sizing(cu.grow(70), cu.grow(70))}, style = style)
			// 			fit_x_1 := cu.create_widget(&ctx, cu.Layout{sizing = cu.sizing(cu.fit(50), cu.fit(50)), child_gap = 16}, style = style)
			// 			if cu.push_parent(&ctx, fit_x_1) {
			// 				defer cu.pop_parent(&ctx)
			// 				cu.create_widget(&ctx, cu.Layout{sizing = cu.sizing(cu.fixed(50), cu.fixed(50))}, style = style)
			// 				cu.create_widget(&ctx, cu.Layout{sizing = cu.sizing(cu.grow(70), cu.grow(70))}, style = style)
			// 			}
			// 			cu.pop_parent(&ctx)
			// 		}
			// 	}
			// }

			style.padding = 32
			grow_x_1 := cu.create_widget(
				&ctx,
				cu.Layout{sizing = cu.sizing(cu.grow(50), cu.grow(50)), child_gap = 0, child_alignment = {.Center, .Center}, direction = .Y},
				aspect_ratio = 16.0 / 9.0,
				style = style,
			)
			if cu.push_parent(&ctx, grow_x_1) {
				defer cu.pop_parent(&ctx)
				cu.create_widget(&ctx, cu.Layout{sizing = cu.sizing(cu.fixed(50), cu.fixed(50))}, aspect_ratio = 16.0 / 9.0, style = style)
				cu.create_widget(&ctx, cu.Layout{sizing = cu.sizing(cu.fit(50), cu.fit(50))}, aspect_ratio = 16.0 / 9.0, style = style)
				cu.create_widget(
					&ctx,
					cu.Layout{sizing = cu.sizing(cu.fit(50), cu.fit(50))},
					aspect_ratio = 16.0 / 9.0,
					image = cu.Image{&nerd, 255},
					style = style,
				)
			}
			cu.create_widget(&ctx, cu.Layout{sizing = cu.sizing(cu.fixed(50), cu.fixed(50))}, style = style)
		case .Text:
			style.padding = 16
			percent_1 := cu.create_widget(
				&ctx,
				cu.Layout{sizing = cu.sizing(cu.percent(0.5), cu.percent(0.5)), child_gap = 16, direction = .Y},
				style = style,
			)
			style.padding = 2
			if cu.push_parent(&ctx, percent_1) {
				defer cu.pop_parent(&ctx)
				cu.create_widget(
					&ctx,
					cu.Text {
						text = "TEST_TEXT 1. A QUICK BROWN FOX JUMPS OVER THE LAZY DOG. PERCENT",
						style = {font_id = 0, letter_spacing = 1, font_size = 20, color = TEXT_PRIMARY_COLOR},
					},
					style = style,
				)
			}

			grow_1 := cu.create_widget(&ctx, cu.Layout{sizing = cu.sizing(cu.grow(50), cu.grow(50)), child_gap = 16, direction = .Y}, style = style)
			if cu.push_parent(&ctx, grow_1) {
				defer cu.pop_parent(&ctx)
				style.padding = 8 //8
				cu.create_widget(
					&ctx,
					cu.Text {
						text = "TEST_TEXT 1. A QUICK BROWN FOX JUMPS OVER THE LAZY DOG. GROW",
						style = {font_id = 0, letter_spacing = 1, font_size = 20, color = TEXT_PRIMARY_COLOR},
					},
					style = style,
				)
				style.padding = 8 //16
				grow_x_1 := cu.create_widget(&ctx, cu.Layout{sizing = cu.sizing(cu.grow(100), cu.grow(50)), child_gap = 16}, style = style)
				if cu.push_parent(&ctx, grow_x_1) {
					defer cu.pop_parent(&ctx)
					cu.create_widget(
						&ctx,
						cu.Text {
							text = "TEST_TEXT 2. INSIDE GROW",
							style = {font_id = 0, letter_spacing = 1, font_size = 20, color = TEXT_DISABLED_COLOR},
						},
						style = style,
					)
					style.padding = 8 //32
					g := cu.create_widget(&ctx, cu.Layout{sizing = cu.sizing(cu.grow(70), cu.grow(70)), child_gap = 16}, style = style)
					if cu.push_parent(&ctx, g) {
						cu.create_widget(
							&ctx,
							cu.Text {
								text = "TEST_TEXT 3. INSIDE GROW 2",
								style = {font_id = 0, letter_spacing = 1, font_size = 20, color = TEXT_SECONDARY_COLOR},
							},
							style = style,
						)
						cu.create_widget(&ctx, cu.Layout{sizing = cu.sizing(cu.grow(70), cu.grow(70))}, style = style)
						fit_x_1 := cu.create_widget(&ctx, cu.Layout{sizing = cu.sizing(cu.fit(50), cu.fit(50)), child_gap = 16}, style = style)
						if cu.push_parent(&ctx, fit_x_1) {
							defer cu.pop_parent(&ctx)
							cu.create_widget(
								&ctx,
								cu.Text {
									text = "TEST_TEXT 4. INSIDE FIT 1",
									style = {font_id = 0, letter_spacing = 1, font_size = 20, color = TEXT_SECONDARY_COLOR},
								},
								style = style,
							)
						}
						cu.pop_parent(&ctx)
					}
				}
			}
			fit_1 := cu.create_widget(&ctx, cu.Layout{sizing = cu.sizing(cu.fit(50), cu.fit(50)), child_gap = 16, direction = .Y}, style = style)
			if cu.push_parent(&ctx, fit_1) {
				defer cu.pop_parent(&ctx)
				style.padding = 8 //8
				cu.create_widget(
					&ctx,
					cu.Text {
						text = "TEST_TEXT 1. A QUICK BROWN FOX JUMPS OVER THE LAZY DOG. FIT",
						style = {font_id = 0, letter_spacing = 1, font_size = 20, color = TEXT_PRIMARY_COLOR},
					},
					style = style,
				)
			}
		case .Floating_Layout:
			grow_0 := cu.create_widget(&ctx, cu.layout(cu.sizing(cu.grow(), cu.grow())), style = style)
			grow_1 := cu.create_widget(&ctx, cu.layout(cu.sizing(cu.grow(), cu.grow())), style = style)
			grow_2 := cu.create_widget(&ctx, cu.layout(cu.sizing(cu.grow(), cu.grow())), style = style)
			if cu.push_parent(&ctx, grow_0) {
				grow := cu.create_widget(&ctx, cu.floating(cu.layout(cu.sizing(cu.grow(), cu.grow()))), style = style)
				cu.pop_parent(&ctx)
			}
			if cu.push_parent(&ctx, grow_1) {
				grow := cu.create_widget(&ctx, cu.floating(cu.layout(cu.sizing(cu.grow(), cu.grow()))), style = style)
				cu.pop_parent(&ctx)
			}
			if cu.push_parent(&ctx, grow_2) {
				grow := cu.create_widget(&ctx, cu.floating(cu.layout(cu.sizing(cu.grow(), cu.grow()))), style = style)
				cu.pop_parent(&ctx)
			}
		case .Clip:
			style.padding = 16
			@(static) clip_val: f32
			clip_val -= rl.GetMouseWheelMove() * rl.GetFrameTime() * 100
			fmt.println(clip_val)
			grow_0 := cu.create_widget(
				&ctx,
				cu.layout(cu.sizing(cu.grow(), cu.grow())),
				clip = cu.Clip{{.Y, .X}, {.X = clip_val, .Y = clip_val}},
				style = style,
			)
			if cu.push_parent(&ctx, grow_0) {
				grow := cu.create_widget(&ctx, cu.layout(cu.sizing(cu.grow(), cu.grow())), style = style)
				cu.pop_parent(&ctx)
			}
		}

		cu.end_ui(&ctx)

		rl.BeginDrawing()
		rl.ClearBackground(rl.BLANK)
		render(ctx, render_texture, sdf_shader)
		rl.DrawText(rl.TextFormat("%v", test_mode), 0, 0, 20, rl.WHITE)
		rl.EndDrawing()
		free_all(context.temp_allocator)
	}
}
