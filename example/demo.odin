package main

import cu "../"
import "core:fmt"

import backend_rl "backend/raylib"

import "core:time"

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

	ctx := cu.init_context(250)
	defer cu.deinit_context(&ctx)
	ctx.mouse.double_click_timeout = time.Millisecond * 300
	ctx.mouse.long_down_timeout = time.Millisecond * 1000
	ctx.measure_text_proc = backend_rl.measure_text

	for !rl.WindowShouldClose() {
		defer free_all(context.temp_allocator)
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

		cu.begin_ui(&ctx)
		build_ui(&ctx, tick, aaloo, f32(rl.GetScreenWidth()), f32(rl.GetScreenHeight()))
		cu.end_ui(&ctx)

		fmt.println(ctx.mouse.hovered, ctx.mouse.active)

		rl.BeginDrawing()
		rl.ClearBackground(rl.BLANK)
		backend_rl.render(ctx)
		rl.EndDrawing()
	}
}
