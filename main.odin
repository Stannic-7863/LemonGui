package main

import "base:runtime"
import "core:reflect"

import "core:fmt"
import "core:hash"
import "core:time"

import rl "vendor:raylib"

WHITE :: Color{255, 255, 255, 255}
BLACK :: Color{0, 0, 0, 255}
GREEN :: Color{0, 255, 0, 255}
BLUE :: Color{0, 0, 255, 255}
RED :: Color{255, 0, 0, 255}
CHILD_BACKGROUND :: [4]u8{42, 42, 64, 255} // #2A2A40
DEFAULT_BACKGROUND :: [4]u8{30, 30, 46, 255} // #1E1E2E
HOVER_COLOR :: [4]u8{58, 58, 90, 255} // #3A3A5A
PRESS_COLOR :: [4]u8{136, 221, 255, 255} // #88DDFF
LONG_PRESS_COLOR :: [4]u8{255, 136, 170, 255} // #FF88AA

print_types :: proc(type: typeid, depth: int = 1, name: string = "") {
	if depth > 0 {
		type_info := type_info_of(type)
		if reflect.is_struct(type_info) {
			for field_info in reflect.struct_fields_zipped(type) {
				print_types(field_info.type.id, depth - 1, field_info.name)
			}
		}
	}

	fmt.println(type, name, type_info_of(type).size)
}

main :: proc() {
	for args in runtime.args__ {
		if args == "sizes" {
			print_types(Widget)
		}
		if args == "app" {
			run_app()
		}
	}
}

slider :: proc(ctx: ^Core_Context, value: ^f32, min, max: f32) {

	main_container := create_widget(
		ctx,
		Layout {
			sizing = sizing(grow(100), fixed(100)),
			padding = {0, 15, 0, 15},
			child_gap = 5,
			direction = .X,
			child_alignment = {.Center, .Center},
		},
		style = Style{color = {200, 200, 200, 255}, border_radius = 5},
	)

	push_parent(ctx, main_container)

	create_widget(ctx, Text{style = {font_id = 0, letter_spacing = 1, font_size = 20, line_spacing = 15}, text = fmt.tprint(min)})

	railing := create_widget(
		ctx,
		Layout{sizing = sizing(grow(), fixed(5)), direction = .Y, child_alignment = {.Center, .Center}},
		style = Style{color = {128, 128, 128, 255}},
	)

	push_parent(ctx, railing)

	knob_offset := (value^ - min) / (max - min) - 0.5

	knob := create_widget(
		ctx,
		Layout{sizing = sizing(fixed(20), fixed(20))},
		offset = {Offset{value = knob_offset, kind = .Percent}, {}},
		style = Style{color = {0, 0, 0, 255}},
	)
	if .Left_Down in knob.events {
		rel := ctx.mouse.position.x - railing.position.x
		normalized := clamp(rel / railing.size.x, 0, 1)
		value^ = min + (max - min) * normalized
		knob.target.color = {150, 220, 235, 255}
	}

	create_widget(
		ctx,
		Text{text = fmt.tprint(value^), style = {font_id = 0, letter_spacing = 1, font_size = 10, line_spacing = 0}},
		{},
		{Offset{value = knob_offset, kind = .Percent}, {}},
	)

	pop_parent(ctx)

	create_widget(ctx, Text{style = {font_id = 0, letter_spacing = 1, font_size = 20, line_spacing = 15}, text = fmt.tprint(max)})

	pop_parent(ctx)
}

toggle_button :: proc(ctx: ^Core_Context, label: string, toggle: ^bool) {

	main_container := create_widget(
		ctx,
		Layout{sizing = sizing(grow(), fixed(100)), padding = 10, child_gap = 10, child_alignment = {.Center, .Center}},
		style = Style{color = {200, 200, 200, 255}, border_radius = 5},
	)
	push_parent(ctx, main_container)
	color: Color
	if toggle^ {
		color = {100, 255, 200, 255}
	} else {
		color = {255, 200, 100, 255}
	}
	e := create_widget(ctx, Layout{sizing = sizing(fixed(20), fixed(20))}, style = Style{color = color, border_radius = 4})
	if .Left_Clicked in e.events {
		toggle^ = !toggle^
	}
	create_widget(ctx, Text{text = label, style = Text_Style{font_id = 0, font_size = 20, line_spacing = 20, letter_spacing = 1}})
	pop_parent(ctx)

}

button :: proc(ctx: ^Core_Context, label: string) -> Widget_Events {
	main_container := create_widget(
		ctx,
		Layout{sizing = sizing(grow(), fixed(100)), padding = 10, child_gap = 10, child_alignment = {.Center, .Center}},
		style = Style{color = {200, 200, 200, 255}, border_radius = 5},
	)
	push_parent(ctx, main_container)
	create_widget(ctx, Text{text = label, style = Text_Style{font_id = 0, font_size = 20, line_spacing = 20, letter_spacing = 1}})
	pop_parent(ctx)
	return main_container.events
}

run_app :: proc() {
	rl.SetConfigFlags({.WINDOW_RESIZABLE})
	rl.InitWindow(700, 700, "Balls?")
	defer rl.CloseWindow()

	ctx := init_core_context(32)
	defer deinit_core_context(&ctx)

	ctx.mouse.double_click_timeout = time.Millisecond * 300
	ctx.mouse.long_down_timeout = time.Millisecond * 1000

	ctx.text_measure_proc = measure_text

	sdf_shader := rl.LoadShader("", "./sdf_rect_shader.frag")

	img := rl.GenImageColor(1, 1, rl.WHITE)
	render_texture := rl.LoadTextureFromImage(img)
	rl.UnloadImage(img)
	defer rl.UnloadTexture(render_texture)

	rl.SetTargetFPS(60)

	x_align: Child_Alignment_X
	y_align: Child_Alignment_Y
	direc: Layout_Direction

	slider_val: f32 = 10
	toggle: bool

	label := "Not Hovered"
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

		begin_ui(&ctx)

		style := Style {
			color         = DEFAULT_BACKGROUND,
			border_radius = {20, 10, 20, 10},
		}

		root := create_widget(
			&ctx,
			Layout{sizing = sizing(fixed(ctx.window_width), fixed(ctx.window_height)), direction = .X, child_gap = 16, padding = 16},
			style = {},
			events_mask = {},
		)
		push_parent(&ctx, root)

		slider(&ctx, &slider_val, 5, 15)

		toggle_button(&ctx, "Toggle me Uwu", &toggle)

		if .Hovered in button(&ctx, label) {
			label = "Hovered"
		} else {
			label = "Not Hovered"
		}

		w_1 := create_widget(&ctx, Layout{sizing = sizing(fixed(50), fixed(50))}, style = style)
		w_2 := create_widget(
			&ctx,
			Layout{sizing = sizing(grow(), grow()), direction = .X, child_alignment = {x = .Left}, child_gap = 16, padding = 16},
			style = style,
		)
		resolve_styling(w_2)

		if push_parent(&ctx, w_2) {
			defer pop_parent(&ctx)
			style.color = CHILD_BACKGROUND
			w_21 := create_widget(&ctx, Layout{sizing = sizing(fixed(50), fixed(50))}, style = style, events_mask = ~{})
			w_22 := create_widget(&ctx, Layout{sizing = sizing(fixed(50), fixed(50))}, style = style)
			w_23 := create_widget(
				&ctx,
				Floating {
					parent = .Center_Center,
					element = .Center_Center,
					attachment_to = .Parent,
					layout = Layout{sizing = sizing(percent(0.5), percent(0.5)), child_gap = 16, padding = 16},
				},
				style = style,
			)

			if push_parent(&ctx, w_23) {
				defer pop_parent(&ctx)
				style.color = DEFAULT_BACKGROUND
				create_widget(
					&ctx,
					Text{text = "Oi, I am A Floating Widget!", style = {font_id = 0, font_size = 20, line_spacing = 20, letter_spacing = 1}},
				)
			}

		}
		style.color = DEFAULT_BACKGROUND

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

		w_3 := create_widget(
			&ctx,
			Layout{sizing = sizing(grow(), grow()), direction = direc, child_alignment = {x = x_align, y = y_align}, child_gap = 16, padding = 16},
			style = style,
		)
		{
			push_parent(&ctx, w_3)
			defer pop_parent(&ctx)
			style.color = CHILD_BACKGROUND
			create_widget(
				&ctx,
				Text {
					text = "A quick brown fox jumps over the lazy dog",
					style = {font_id = 0, letter_spacing = 1, font_size = 30, line_spacing = 30},
				},
			)
			create_widget(
				&ctx,
				Text {
					text = "Why Does A quick brown Jumps over the lazy Dog?",
					style = {font_id = 0, letter_spacing = 5, font_size = 15, line_spacing = 15},
				},
			)
			create_widget(
				&ctx,
				Text {
					text = "When Does A quick brown Jumps over the lazy Dog?",
					style = {font_id = 0, letter_spacing = 10, font_size = 10, line_spacing = 10},
				},
			)
		}

		style.color = DEFAULT_BACKGROUND
		w_4 := create_widget(&ctx, Layout{sizing = sizing(grow(50, 50), grow(50, 50))}, style = style)

		end_ui(&ctx)

		rl.BeginDrawing()
		rl.ClearBackground(rl.BLANK)
		render(ctx, render_texture, sdf_shader)
		rl.EndDrawing()
		free_all(context.temp_allocator)
	}

}

resolve_styling :: proc(widget: ^Widget) {
	if .Hovered in widget.events {
		widget.target.color = HOVER_COLOR
		widget.target.border_radius = {20, 20, 20, 20}
	}

	if .Left_Down in widget.events {
		widget.target.color = PRESS_COLOR
		widget.target.border_radius = {30, 30, 30, 30}
	}

	if .Long_Left_Down in widget.events {
		widget.target.color = LONG_PRESS_COLOR
		widget.target.border_radius = {50, 50, 50, 50}
	}
}


render :: proc(ctx: Core_Context, texture: rl.Texture, shader: rl.Shader) {
	rect_center_loc := rl.GetShaderLocation(shader, "rect_center")
	rect_size_loc := rl.GetShaderLocation(shader, "rect_size")
	border_radius_loc := rl.GetShaderLocation(shader, "border_radius")
	color_loc := rl.GetShaderLocation(shader, "color")

	for cmd in ctx.render_commands {
		switch v in cmd.type {
		case Command_Rect:
			size := v.size / 2
			pos := v.position + size
			rad := v.border_radius
			color: [4]f32
			for c, i in v.color {
				color[i] = f32(c) / 255
			}

			rl.BeginShaderMode(shader)
			rl.SetShaderValue(shader, rect_center_loc, &pos, .VEC2)
			rl.SetShaderValue(shader, rect_size_loc, &size, .VEC2)
			rl.SetShaderValue(shader, border_radius_loc, &rad, .VEC4)
			rl.SetShaderValue(shader, color_loc, &color, .VEC4)

			src := rl.Rectangle{0, 0, 1, 1}
			dst := rl.Rectangle{v.position.x, v.position.y, v.size.x, v.size.y}

			rl.DrawTexturePro(texture, src, dst, {}, 0.0, rl.WHITE)
			rl.EndShaderMode()
		case Command_Text:
			initial_y := v.position.y

			for l in ctx.text_lines[v.start:v.end] {
				rl.DrawRectangleV({v.position.x, initial_y}, rl.MeasureTextEx(rl.GetFontDefault(), fmt.ctprintf(l), v.font_size, v.spacing), rl.GRAY)
				rl.DrawTextEx(rl.GetFontDefault(), fmt.ctprint(l), {v.position.x, initial_y}, v.font_size, v.spacing, cast(rl.Color)v.color)
				initial_y += v.line_height
			}

		}
	}

	// for cmd in ctx.render_commands {
	// 	switch v in cmd.type {
	// 	case Command_Rect:
	// 		rl.DrawRectangleV(v.position, v.size, cast(rl.Color)v.color)
	// 	}
	// }
}

measure_text :: proc(text: string, config: Text_Style) -> f32 {
	width: f32
	font := rl.GetFontDefault()
	scale := config.font_size / f32(font.baseSize)
	for r in text {
		advance: f32
		glyph_index := rl.GetGlyphIndex(font, r)
		glyph := font.glyphs[glyph_index]

		if glyph.advanceX != 0 {
			advance = f32(glyph.advanceX) * scale + config.letter_spacing
		} else {
			advance = font.recs[glyph_index].width * scale + f32(glyph.offsetX) + config.letter_spacing
		}
		width += advance
	}
	return width
}
