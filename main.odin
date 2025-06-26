package main

import "base:runtime"
import "core:reflect"

import "core:fmt"
import "core:hash"
import "core:time"

import rl "vendor:raylib"

import cu "core"

WHITE :: cu.Color{255, 255, 255, 255}
BLACK :: cu.Color{0, 0, 0, 255}
GREEN :: cu.Color{0, 255, 0, 255}
BLUE :: cu.Color{0, 0, 255, 255}
RED :: cu.Color{255, 0, 0, 255}
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

		}
		if args == "app" {
			run_app()
		}
	}
}

slider :: proc(ctx: ^cu.Core_Context, value: ^f32, min, max: f32) {

	main_container := cu.create_widget(
		ctx,
		cu.Layout {
			sizing = cu.sizing(cu.grow(100), cu.fixed(100)),
			padding = {0, 15, 0, 15},
			child_gap = 5,
			direction = .X,
			child_alignment = {.Center, .Center},
		},
		style = cu.Style{color = {200, 200, 200, 255}, border_radius = 5},
	)

	cu.push_parent(ctx, main_container)

	cu.create_widget(ctx, cu.Text{style = {font_id = 0, letter_spacing = 1, font_size = 20, line_spacing = 15}, text = fmt.tprint(min)})

	railing := cu.create_widget(
		ctx,
		cu.Layout{sizing = cu.sizing(cu.grow(), cu.fixed(5)), direction = .Y, child_alignment = {.Center, .Center}},
		style = cu.Style{color = {128, 128, 128, 255}, border_radius = 50},
	)

	cu.push_parent(ctx, railing)

	knob_offset := (value^ - min) / (max - min) - 0.5

	knob := cu.create_widget(
		ctx,
		cu.Layout{sizing = cu.sizing(cu.fixed(20), cu.fixed(20))},
		offset = {cu.Offset{value = knob_offset, kind = .Percent}, {}},
		style = cu.Style{color = {0, 0, 0, 255}, border_radius = 50},
	)

	if .Left_Pressed in knob.events {
		cu.animate(ctx, knob.node.index, knob.style.color, cu.Color{0, 0, 255, 255}, 1, "style", "color")
		cu.animate(ctx, knob.node.index, knob.style.border_radius, cu.Vec4f32{10, 0, 10, 0}, 1, "style", "border_radius")
	}
	if .Left_Clicked in knob.events {
		cu.animate(ctx, knob.node.index, knob.style.color, cu.Color{0, 0, 0, 255}, 1, "style", "color")
		cu.animate(ctx, knob.node.index, knob.style.border_radius, cu.Vec4f32{100, 100, 100, 100}, 1, "style", "border_radius")
	}

	if .Left_Down in knob.events {
		rel := ctx.mouse.position.x - railing.position.x
		normalized := clamp(rel / railing.size.x, 0, 1)
		value^ = min + (max - min) * normalized
	}

	t := cu.create_widget(
		ctx,
		cu.Text{text = fmt.tprint(value^), style = {font_id = 0, letter_spacing = 1, font_size = 10, line_spacing = 0}},
		{},
		{cu.Offset{value = knob_offset, kind = .Percent}, {}},
	)
	cu.pop_parent(ctx)

	cu.create_widget(ctx, cu.Text{style = {font_id = 0, letter_spacing = 1, font_size = 20, line_spacing = 15}, text = fmt.tprint(max)})

	cu.pop_parent(ctx)
}

toggle_button :: proc(ctx: ^cu.Core_Context, label: string, toggle: ^bool) {

	main_container := cu.create_widget(
		ctx,
		cu.Layout{sizing = cu.sizing(cu.grow(), cu.fixed(100)), padding = 10, child_gap = 10, child_alignment = {.Center, .Center}},
		style = cu.Style{color = {200, 200, 200, 255}, border_radius = 5},
	)
	cu.push_parent(ctx, main_container)
	color: cu.Color
	if toggle^ {
		color = {100, 255, 200, 255}
	} else {
		color = {255, 200, 100, 255}
	}
	e := cu.create_widget(ctx, cu.Layout{sizing = cu.sizing(cu.fixed(20), cu.fixed(20))}, style = cu.Style{color = color, border_radius = 4})
	if .Left_Clicked in e.events {
		toggle^ = !(toggle^)
	}
	cu.create_widget(ctx, cu.Text{text = label, style = cu.Text_Style{font_id = 0, font_size = 20, line_spacing = 20, letter_spacing = 1}})
	cu.pop_parent(ctx)

}

button :: proc(ctx: ^cu.Core_Context, label: string) -> cu.Widget_Events {
	main_container := cu.create_widget(
		ctx,
		cu.Layout{sizing = cu.sizing(cu.grow(), cu.fixed(100)), padding = 10, child_gap = 10, child_alignment = {.Center, .Center}},
		style = cu.Style{color = {200, 200, 200, 255}, border_radius = 5},
	)
	cu.push_parent(ctx, main_container)
	cu.create_widget(ctx, cu.Text{text = label, style = cu.Text_Style{font_id = 0, font_size = 20, line_spacing = 20, letter_spacing = 1}})
	cu.pop_parent(ctx)
	return main_container.events
}
import "core:mem"
run_app :: proc() {
	when ODIN_DEBUG {
		track: mem.Tracking_Allocator
		mem.tracking_allocator_init(&track, context.allocator)
		context.allocator = mem.tracking_allocator(&track)

		defer {
			if len(track.allocation_map) > 0 {
				fmt.eprintf("=== %v allocations not freed: ===\n", len(track.allocation_map))
				for _, entry in track.allocation_map {
					fmt.eprintf("- %v bytes @ %v\n", entry.size, entry.location)
				}
			}
			mem.tracking_allocator_destroy(&track)
		}
	}

	rl.SetConfigFlags({.WINDOW_RESIZABLE})
	rl.InitWindow(700, 700, "Balls?")
	defer rl.CloseWindow()

	ctx := cu.init_core_context(32)
	defer cu.deinit_core_context(&ctx)

	ctx.mouse.double_click_timeout = time.Millisecond * 300
	ctx.mouse.long_down_timeout = time.Millisecond * 1000

	ctx.text_measure_proc = measure_text

	sdf_shader := rl.LoadShader("", "./sdf_rect_shader.frag")

	img := rl.GenImageColor(1, 1, rl.WHITE)
	render_texture := rl.LoadTextureFromImage(img)
	rl.UnloadImage(img)
	defer rl.UnloadTexture(render_texture)

	rl.SetTargetFPS(60)

	x_align: cu.Child_Alignment_X
	y_align: cu.Child_Alignment_Y
	direc: cu.Layout_Direction

	slider_val: f32 = 10
	toggle: bool
	toggle_2: bool
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

		cu.begin_ui(&ctx)

		style := cu.Style {
			color         = DEFAULT_BACKGROUND,
			border_radius = {20, 10, 20, 10},
		}

		root := cu.create_widget(
			&ctx,
			cu.Layout{sizing = cu.sizing(cu.fixed(ctx.window_width), cu.fixed(ctx.window_height)), direction = .Y, child_gap = 16, padding = 16},
			style = {},
		)
		cu.push_parent(&ctx, root)

		slider(&ctx, &slider_val, 5, 15)

		toggle_button(&ctx, "Toggle me Uwu", &toggle)

		if .Hovered in button(&ctx, label) {
			label = "Hovered"
		} else {
			label = "Not Hovered"
		}

		// w_1 := cu.create_widget(&ctx, cu.Layout{sizing = cu.sizing(cu.fixed(50), cu.fixed(50))}, style = style)
		// w_2 := cu.create_widget(
		// 	&ctx,
		// 	cu.Layout{sizing = cu.sizing(cu.grow(), cu.grow()), direction = .X, child_alignment = {x = .Left}, child_gap = 16, padding = 16},
		// 	style = style,
		// )
		// resolve_styling(w_2)
		//
		// if cu.push_parent(&ctx, w_2) {
		// 	defer cu.pop_parent(&ctx)
		// 	style.color = CHILD_BACKGROUND
		// 	w_21 := cu.create_widget(&ctx, cu.Layout{sizing = cu.sizing(cu.fixed(50), cu.fixed(50))}, style = style, events_mask = ~{})
		// 	w_22 := cu.create_widget(&ctx, cu.Layout{sizing = cu.sizing(cu.fixed(50), cu.fixed(50))}, style = style)
		// 	w_23 := cu.create_widget(
		// 		&ctx,
		// 		cu.Floating {
		// 			parent = .Center_Center,
		// 			element = .Center_Center,
		// 			attachment_to = .Parent,
		// 			layout = cu.Layout{sizing = cu.sizing(cu.percent(0.5), cu.percent(0.5)), child_gap = 16, padding = 16},
		// 		},
		// 		style = style,
		// 	)
		//
		// 	if cu.push_parent(&ctx, w_23) {
		// 		defer cu.pop_parent(&ctx)
		// 		style.color = DEFAULT_BACKGROUND
		// 		cu.create_widget(
		// 			&ctx,
		// 			cu.Text{text = "Oi, I am A Floating Widget!", style = {font_id = 0, font_size = 20, line_spacing = 20, letter_spacing = 1}},
		// 		)
		// 	}
		//
		// }
		// style.color = DEFAULT_BACKGROUND
		//
		// if rl.IsKeyPressed(.UP) {
		// 	y_align = .Top
		// }
		// if rl.IsKeyPressed(.DOWN) {
		// 	y_align = .Bottom
		// }
		// if rl.IsKeyPressed(.LEFT) {
		// 	x_align = .Left
		// }
		// if rl.IsKeyPressed(.RIGHT) {
		// 	x_align = .Right
		// }
		// if rl.IsKeyPressed(.KP_1) {
		// 	x_align = .Center
		// }
		// if rl.IsKeyPressed(.KP_2) {
		// 	y_align = .Center
		// }
		//
		// if rl.IsKeyPressed(.R) {
		// 	direc = .X
		// }
		// if rl.IsKeyPressed(.C) {
		// 	direc = .Y
		// }
		//
		// w_3 := cu.create_widget(
		// 	&ctx,
		// 	cu.Layout {
		// 		sizing = cu.sizing(cu.grow(), cu.grow()),
		// 		direction = direc,
		// 		child_alignment = {x = x_align, y = y_align},
		// 		child_gap = 16,
		// 		padding = 16,
		// 	},
		// 	style = style,
		// )
		// {
		// 	cu.push_parent(&ctx, w_3)
		// 	defer cu.pop_parent(&ctx)
		// 	style.color = CHILD_BACKGROUND
		// 	cu.create_widget(
		// 		&ctx,
		// 		cu.Text {
		// 			text = "A quick brown fox jumps over the lazy dog",
		// 			style = {font_id = 0, letter_spacing = 1, font_size = 30, line_spacing = 30},
		// 		},
		// 	)
		// 	cu.create_widget(
		// 		&ctx,
		// 		cu.Text {
		// 			text = "Why Does A quick brown Jumps over the lazy Dog?",
		// 			style = {font_id = 0, letter_spacing = 5, font_size = 15, line_spacing = 15},
		// 		},
		// 	)
		// 	cu.create_widget(
		// 		&ctx,
		// 		cu.Text {
		// 			text = "When Does A quick brown Jumps over the lazy Dog?",
		// 			style = {font_id = 0, letter_spacing = 10, font_size = 10, line_spacing = 10},
		// 		},
		// 	)
		// }
		//
		// style.color = DEFAULT_BACKGROUND
		// w_4 := cu.create_widget(&ctx, cu.Layout{sizing = cu.sizing(cu.grow(50, 50), cu.grow(50, 50))}, style = style)
		//
		cu.end_ui(&ctx)

		rl.BeginDrawing()
		rl.ClearBackground(rl.BLANK)
		render(ctx, render_texture, sdf_shader)
		rl.EndDrawing()
		free_all(context.temp_allocator)
	}

}

render :: proc(ctx: cu.Core_Context, texture: rl.Texture, shader: rl.Shader) {
	rect_center_loc := rl.GetShaderLocation(shader, "rect_center")
	rect_size_loc := rl.GetShaderLocation(shader, "rect_size")
	border_radius_loc := rl.GetShaderLocation(shader, "border_radius")
	color_loc := rl.GetShaderLocation(shader, "color")

	for cmd in ctx.render_commands {
		switch v in cmd.type {
		case cu.Command_Rect:
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
		case cu.Command_Text:
			initial_y := v.position.y

			for l in ctx.text_lines[v.start:v.end] {
				// rl.DrawRectangleV({v.position.x, initial_y}, rl.MeasureTextEx(rl.GetFontDefault(), fmt.ctprintf(l), v.font_size, v.spacing), rl.GRAY)
				rl.DrawTextEx(rl.GetFontDefault(), fmt.ctprint(l), {v.position.x, initial_y}, v.font_size, v.spacing, cast(rl.Color)v.color)
				initial_y += v.line_height
			}

		}
	}

	// for cmd in ctx.render_commands {
	// 	switch v in cmd.type {
	// 	case Command_Rect:
	// 		rl.DrawRectangleV(v.position, v.size, cast(rl.cu.Color)v.color)
	// 	}
	// }
}

measure_text :: proc(text: string, config: cu.Text_Style) -> f32 {
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
