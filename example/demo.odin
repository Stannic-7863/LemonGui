package main

import cu "../"
import "core:fmt"

import backend_nvg "backend/nanovg"
import backend_rl "backend/raylib"

import "core:strings"
import "core:text/edit"
import "core:time"

import gl "vendor:OpenGL"
import glfw "vendor:glfw"
import nvg "vendor:nanovg"
import nvg_gl "vendor:nanovg/gl"
import rl "vendor:raylib"

demo_rl :: proc() {
	init_window_raylib(config = rl.ConfigFlags{.WINDOW_RESIZABLE})
	defer close_window_raylib()
	rl.SetTargetFPS(60)

	font := rl.LoadFontEx("./assets/OpenSans-Regular.ttf", 64, nil, 0)
	tick_rl := rl.LoadTexture("./assets/tick.png")
	aaloo_rl := rl.LoadTexture("./assets/DA TRULY BIG AALOO.jpg")
	defer rl.UnloadFont(font)
	defer rl.UnloadTexture(tick_rl)
	defer rl.UnloadTexture(aaloo_rl)

	tick := Image {
		data = &tick_rl,
		w    = auto_cast tick_rl.width,
		h    = auto_cast tick_rl.height,
	}

	aaloo := Image {
		data = &aaloo_rl,
		w    = auto_cast aaloo_rl.width,
		h    = auto_cast aaloo_rl.height,
	}

	buffer := strings.Builder{}
	state := edit.State{}
	edit.init(&state, context.allocator, context.allocator)
	edit.setup_once(&state, &buffer)

	ctx := cu.init_context(250)
	defer cu.deinit_context(&ctx)
	ctx.mouse.double_click_timeout = time.Millisecond * 300
	ctx.mouse.long_down_timeout = time.Millisecond * 1000
	ctx.measure_text_proc = backend_rl.measure_text

	buttons_event_log: [dynamic]string

	text_style_20 := cu.Text_Style {
		font           = &font,
		color          = PRIMARY_COLOR,
		font_size      = 20,
		letter_spacing = 1,
	}

	for !rl.WindowShouldClose() {
		defer free_all(context.temp_allocator)
		defer clear(&buttons_event_log)
		ctx.mouse.position = rl.GetMousePosition()
		ctx.mouse.scroll = rl.GetMouseWheelMove()
		ctx.mouse.scroll_v = rl.GetMouseWheelMoveV()

		if rl.IsMouseButtonDown(.LEFT) {ctx.mouse.mapped_events[.Left] += {.Down}}
		if rl.IsMouseButtonDown(.RIGHT) {ctx.mouse.mapped_events[.Right] += {.Down}}
		if rl.IsMouseButtonDown(.MIDDLE) {ctx.mouse.mapped_events[.Middle] += {.Down}}
		if rl.IsMouseButtonPressed(.LEFT) {ctx.mouse.mapped_events[.Left] += {.Pressed}}
		if rl.IsMouseButtonPressed(.RIGHT) {ctx.mouse.mapped_events[.Right] += {.Pressed}}
		if rl.IsMouseButtonPressed(.MIDDLE) {ctx.mouse.mapped_events[.Middle] += {.Pressed}}
		if rl.IsMouseButtonReleased(.LEFT) {ctx.mouse.mapped_events[.Left] += {.Released}}
		if rl.IsMouseButtonReleased(.RIGHT) {ctx.mouse.mapped_events[.Right] += {.Released}}
		if rl.IsMouseButtonReleased(.MIDDLE) {ctx.mouse.mapped_events[.Middle] += {.Released}}

		update_edit_state(&state)

		cu.begin_ui(&ctx)
		build_ui(&ctx, tick, aaloo, &state, &buffer, f32(rl.GetScreenWidth()), f32(rl.GetScreenHeight()))
		cu.end_ui(&ctx)

		rl.BeginDrawing()
		rl.ClearBackground(rl.BLANK)
		backend_rl.render(ctx)
		rl.EndDrawing()
	}
}
