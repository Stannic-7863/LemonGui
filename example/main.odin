package main

import "base:runtime"
import "core:fmt"
import "core:prof/spall"
import "core:reflect"
import "core:time"

import rl "vendor:raylib"

import cu "../"
import backend_rl "backend/raylib"

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

// spall_ctx: spall.Context
// @(thread_local)
// spall_buffer: spall.Buffer

main :: proc() {
	// spall_buffer_backing := make([]u8, spall.BUFFER_DEFAULT_SIZE)
	// spall_ctx = spall.context_create_with_sleep("./spall.spall")
	// spall_buffer = spall.buffer_create(spall_buffer_backing)
	// spall.context_destroy(&spall_ctx)

	rl.SetConfigFlags({.WINDOW_RESIZABLE})
	rl.InitWindow(0, 0, "Window")
	defer rl.CloseWindow()

	font := rl.GetFontDefault() //rl.LoadFontEx("./assets/OpenSans-Regular.ttf", 64, nil, 0)
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
		build_ui(&ctx, tick, aaloo, &font, f32(rl.GetScreenWidth()), f32(rl.GetScreenHeight()))
		cu.end_ui(&ctx)

		rl.BeginDrawing()
		rl.ClearBackground(rl.BLANK)
		backend_rl.render(ctx)
		rl.DrawFPS(10, 10)
		rl.EndDrawing()
	}

}
//
// @(instrumentation_enter)
// spall_enter :: proc "contextless" (proc_address, call_site_return_address: rawptr, loc: runtime.Source_Code_Location) {
// 	spall._buffer_begin(&spall_ctx, &spall_buffer, "", "", loc)
// }
//
// @(instrumentation_exit)
// spall_exit :: proc "contextless" (proc_address, call_site_return_address: rawptr, loc: runtime.Source_Code_Location) {
// 	spall._buffer_end(&spall_ctx, &spall_buffer)
// }
