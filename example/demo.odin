package main

import cu "../"
import "core:fmt"
import "core:math"

import "core:time"
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

	ctx := cu.init_core_context(128)
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
	rl.SetTextureFilter(jet_brains_mono.texture, .TRILINEAR)

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

		cu.begin_ui(&ctx)

		root := cu.create_widget(
			&ctx,
			cu.Layout{sizing = cu.sizing(cu.fixed(ctx.window_width), cu.fixed(ctx.window_height)), direction = .X, child_gap = 16},
			style = {padding = 32, color = BACKGROUND_COLOR},
		)

		cu.push_parent(&ctx, root)

		side_bar := cu.create_widget(&ctx, cu.layout(cu.sizing(cu.fit(128), cu.fit()), direction = .Y, child_gap = 8))
		if cu.push_parent(&ctx, side_bar) {
			defer cu.pop_parent(&ctx)
			button(&ctx, "Test 1", &tick, "A VERY BIG TOOL TIP. A VERY BIG TOOL TIP INDEED. A VERY BIG TOOL TIP INDEED.")
			button(&ctx, "Test 2", &tick, "A VERY BIG TOOL TIP. A VERY BIG TOOL TIP INDEED. A VERY BIG TOOL TIP INDEED.")
			button(&ctx, "Test 3", &tick, "A VERY BIG TOOL TIP. A VERY BIG TOOL TIP INDEED. A VERY BIG TOOL TIP INDEED.")
		}

		@(static) sidebar_clip_val: f32
		side_bar_2 := cu.create_widget(
			&ctx,
			cu.layout(cu.sizing(cu.grow(128, 256), cu.fixed(150)), direction = .Y, child_gap = 8),
			clip = cu.clip_y(sidebar_clip_val),
			style = {color = 0, padding = 8, border = cu.border_style(BORDER_COLOR)},
		)
		if .Hovered in side_bar_2.events {
			sidebar_clip_val += rl.GetMouseWheelMove() * 5
			sidebar_clip_val = min(sidebar_clip_val, 0)
		}
		if cu.push_parent(&ctx, side_bar_2) {
			@(static) a: f32 = 10
			slider(&ctx, &a, 0, 10)
			slider(&ctx, &a, 0, 20)
			slider(&ctx, &a, 0, 30)
			slider(&ctx, &a, 0, 40)
			slider(&ctx, &a, 0, 50)
			slider(&ctx, &a, 0, 60)
			slider(&ctx, &a, 0, 70)
			slider(&ctx, &a, 0, 80)
			slider(&ctx, &a, 0, 90)
		}

		cu.end_ui(&ctx)

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
		style = cu.Style{color = SURFACE_COLOR, padding = 4, border = cu.border_style(BORDER_COLOR, cu.Border_Type.Single)},
	)

	if cu.push_parent(ctx, body) {
		defer cu.pop_parent(ctx)

		label_widget := cu.create_widget(
			ctx,
			cu.text(label, cu.Text_Style{color = TEXT_PRIMARY_COLOR, font_size = 16, letter_spacing = 1}),
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
			if cu.push_parent(ctx, floating_holder) {
				defer cu.pop_parent(ctx)
				cu.create_widget(
					ctx,
					cu.text(text = tooltip, style = {color = TEXT_SECONDARY_COLOR, letter_spacing = 1, font_size = 16}),
					offset = [2]cu.Offset{cu.offset_absolute(offset_value.x), cu.offset_absolute(offset_value.y)},
					style = {color = ELEVATED_SURFACE_COLOR, padding = 16, border = cu.border_style(BORDER_COLOR, cu.Border_Type.Single)},
					event_passthrough = true,
				)
			}
		}
	}

	return body.events
}

slider :: proc(ctx: ^cu.Core_Context, value: ^f32, min, max: f32) {
	main_container := cu.create_widget(
		ctx,
		cu.Layout{sizing = cu.sizing(cu.grow(50, 256), cu.fit(16, 32)), child_gap = 16, direction = .X, child_alignment = {.Center, .Center}},
		style = cu.Style{padding = 4},
		event_passthrough = true,
	)
	cu.push_parent(ctx, main_container)

	cu.create_widget(
		ctx,
		cu.text(style = {font_id = 0, letter_spacing = 1, font_size = 16, line_spacing = 0, color = TEXT_PRIMARY_COLOR}, text = fmt.tprint(min)),
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
		style = cu.Style{color = ELEVATED_SURFACE_COLOR, border = cu.border_style(0, radius = 50)},
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
		cu.Text {
			text = fmt.tprint(value^),
			style = {font_id = 0, letter_spacing = 1, font_size = 16, line_spacing = 0, color = TEXT_SECONDARY_COLOR},
		},
		{},
		offset = {cu.offset_percent(knob_offset), cu.offset_absolute(12)},
		event_passthrough = true,
	)
	cu.pop_parent(ctx)

	cu.pop_parent(ctx)

	cu.create_widget(
		ctx,
		cu.Text{style = {font_id = 0, letter_spacing = 1, font_size = 16, line_spacing = 0, color = TEXT_PRIMARY_COLOR}, text = fmt.tprint(max)},
	)

	cu.pop_parent(ctx)
}
