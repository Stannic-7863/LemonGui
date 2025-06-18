package main

import "core:fmt"
import "core:hash"
import "core:time"

import rl "vendor:raylib"

WHITE :: Color{255, 255, 255, 255}
BLACK :: Color{0, 0, 0, 255}
GREEN :: Color{0, 255, 0, 255}
BLUE :: Color{0, 0, 255, 255}
RED :: Color{255, 0, 0, 255}
DEFAULT_BACKGROUND :: [4]u8{30, 30, 46, 255} // #1E1E2E
CHILD_BACKGROUND :: [4]u8{42, 42, 64, 255} // #2A2A40
HOVER_COLOR :: [4]u8{58, 58, 90, 255} // #3A3A5A
LONG_PRESS_COLOR :: [4]u8{255, 136, 170, 255} // #FF88AA
PRESS_COLOR :: [4]u8{136, 221, 255, 255} // #88DDFF

main :: proc() {
	rl.SetConfigFlags({.WINDOW_RESIZABLE})
	rl.InitWindow(700, 700, "Balls?")
	defer rl.CloseWindow()

	ctx := init_core_context(32)
	ctx.mouse.double_click_timeout = time.Millisecond * 300
	ctx.mouse.long_down_timeout = time.Millisecond * 1000

	ctx.text_measure_proc = measure_text

	defer delete(ctx.persistant_data)
	defer delete(ctx.render_commands)
	defer delete(ctx.widgets)

	sdf_shader := rl.LoadShader("", "./sdf_rect_shader.frag")

	img := rl.GenImageColor(1, 1, rl.WHITE)
	render_texture := rl.LoadTextureFromImage(img)
	rl.UnloadImage(img)
	defer rl.UnloadTexture(render_texture)

	rl.SetTargetFPS(60)

	x_align: Child_Alignment_X
	y_align: Child_Alignment_Y
	direc: Direction
	for !rl.WindowShouldClose() {
		ctx.window_width = cast(f32)rl.GetScreenWidth()
		ctx.window_height = cast(f32)rl.GetScreenHeight()
		ctx.delta_time = rl.GetFrameTime()

		defer free_all(context.temp_allocator)
		begin_ui(&ctx)

		if rl.IsMouseButtonDown(.LEFT) {ctx.mouse.events += {.Left_Down}}
		if rl.IsMouseButtonDown(.RIGHT) {ctx.mouse.events += {.Right_Down}}
		if rl.IsMouseButtonDown(.MIDDLE) {ctx.mouse.events += {.Middle_Down}}
		if rl.IsMouseButtonPressed(.LEFT) {ctx.mouse.events += {.Left_Pressed}}
		if rl.IsMouseButtonPressed(.RIGHT) {ctx.mouse.events += {.Right_Pressed}}
		if rl.IsMouseButtonPressed(.MIDDLE) {ctx.mouse.events += {.Middle_Pressed}}
		if rl.IsMouseButtonReleased(.LEFT) {ctx.mouse.events += {.Left_Released}}
		if rl.IsMouseButtonReleased(.RIGHT) {ctx.mouse.events += {.Right_Released}}
		if rl.IsMouseButtonReleased(.MIDDLE) {ctx.mouse.events += {.Middle_Released}}

		ctx.mouse.old_position = ctx.mouse.position
		ctx.mouse.position = rl.GetMousePosition()

		style := Style {
			color = DEFAULT_BACKGROUND,
			border_radius = {20, 10, 20, 10},
			text = {font_size = 20, spacing = 2, line_height = 20},
			layout = {padding = 32, child_gap = 16},
		}

		root := create_widget(
			&ctx,
			"",
			{sizing = {fixed(ctx.window_width), fixed(ctx.window_height)}, direction = .Row},
			style = {layout = {child_gap = 16, padding = 16}},
			events_mask = {},
		)
		push_parent(&ctx, root)

		w_1 := create_widget(&ctx, "", {sizing = {fixed(50), fixed(50)}}, style)
		w_2 := create_widget(
			&ctx,
			"A quick brown fox jumps over the lazy dog",
			{sizing = {grow(), grow()}, direction = .Row, child_alignment = {x = .Right}},
			style,
		)
		resolve_styling(w_2)


		{
			push_parent(&ctx, w_2)
			defer pop_parent(&ctx)
			style.color = CHILD_BACKGROUND
			w_21 := create_widget(&ctx, "", {sizing = {fixed(50), fixed(50)}}, style, ~{})
			w_22 := create_widget(&ctx, "", {sizing = {fixed(50), fixed(50)}}, style)
			w_23 := create_widget(&ctx, "", {sizing = {percent(0.5), percent(0.5)}}, style)
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
			direc = .Row
		}
		if rl.IsKeyPressed(.C) {
			direc = .Colom
		}

		w_3 := create_widget(
			&ctx,
			"A quick brown fox does not jump over the lazy dog",
			{sizing = {grow(), grow()}, direction = direc, child_alignment = {x = x_align, y = y_align}},
			style,
		)
		{
			push_parent(&ctx, w_3)
			defer pop_parent(&ctx)
			style.color = CHILD_BACKGROUND
			w_31 := create_widget(&ctx, "", {sizing = {fit(), fit()}, direction = .Row}, style)
			{
				push_parent(&ctx, w_31)
				defer pop_parent(&ctx)
				style.color = DEFAULT_BACKGROUND
				w_31_1 := create_widget(&ctx, "", {sizing = {grow(50, 50), fixed(50)}}, style)
				w_31_2 := create_widget(&ctx, "", {sizing = {grow(50, 50), grow(50, 50)}}, style)
			}
			style.color = CHILD_BACKGROUND
			w_32 := create_widget(&ctx, "", {sizing = {percent(0.5), percent(0.5)}}, style)
		}

		style.color = DEFAULT_BACKGROUND
		w_4 := create_widget(&ctx, "", {sizing = {grow(50, 50), grow(50, 50)}}, style)

		end_ui(&ctx)

		rl.BeginDrawing()
		rl.ClearBackground(rl.BLANK)
		render(ctx, render_texture, sdf_shader)
		rl.EndDrawing()
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
		widget.target.text.font_size = 10
	}

	if .Long_Left_Down in widget.events {
		widget.target.color = LONG_PRESS_COLOR
		widget.target.border_radius = {50, 50, 50, 50}
	}
}

resolve_animations :: proc(w: ^Widget) {
	is_interacted_hot: bool = .Hovered in w.events
	is_interacted_active: bool = w.events & Active_Widget_Events != {}
	was_interacted_hot: bool = w.in_progressive_hot_anim
	was_interacted_active: bool = w.in_progressive_active_anim

	// entering hot animation 
	if (is_interacted_hot) && !was_interacted_hot {
		w.in_decay_hot_anim = false
		w.in_progressive_hot_anim = true
		w.start = w.style
		w.hot_t = 0
	}

	// leaving hot animation 
	if was_interacted_hot && !(is_interacted_hot) {
		w.in_decay_hot_anim = true
		w.in_progressive_hot_anim = false
		w.start = w.style
		w.hot_t = 1
	}

	// entring active animation
	if !was_interacted_active && (is_interacted_active) {
		w.in_decay_active_anim = false
		w.in_progressive_active_anim = true
		w.start = w.style
		w.active_t = 0
	}

	// leaving active animation
	if was_interacted_active && !(is_interacted_active) {
		w.in_decay_active_anim = true
		w.in_progressive_active_anim = false
		w.start = w.style
		w.active_t = 1
	}

	if w.in_progressive_active_anim {
		lerp_style_progressive(w, w.active_t)
	} else if w.in_progressive_hot_anim {
		lerp_style_progressive(w, w.hot_t)
	}

	if w.in_decay_hot_anim {
		lerp_style_decaying(w, w.hot_t)
	} else if w.in_decay_active_anim {
		lerp_style_decaying(w, w.active_t)
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

			for l in v.lines {
				rl.DrawTextEx(
					rl.GetFontDefault(),
					fmt.ctprint(l),
					{v.position.x, initial_y},
					v.font_size,
					v.spacing,
					cast(rl.Color)v.color,
				)
				// width := rl.MeasureTextEx(rl.GetFontDefault(), fmt.ctprint(l), v.font_size, v.spacing)
				// rl.DrawRectangleLinesEx({v.position.x, initial_y, width.x, width.y}, 2, rl.WHITE)
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
			advance = f32(glyph.advanceX) * scale + config.spacing
		} else {
			advance = font.recs[glyph_index].width * scale + f32(glyph.offsetX) + config.spacing
		}
		width += advance
	}
	return width
}
