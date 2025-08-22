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

	ctx := cu.init_core_context(256)
	defer cu.deinit_core_context(&ctx)
	ctx.mouse.double_click_timeout = time.Millisecond * 300
	ctx.mouse.long_down_timeout = time.Millisecond * 1000
	ctx.text_measure_proc = backend_rl.measure_text
	ctx.error_handler_proc = error_handler

	buttons_event_log: [dynamic]string

	text_style_20 := cu.Text_Style {
		font           = &font,
		color          = PRIMARY_COLOR,
		font_size      = 20,
		letter_spacing = 1,
	}

	cu.create_tag(
		&ctx,
		"border",
		cu.Tag_Style{border_color = [4]cu.Color{BORDER_COLOR, BORDER_COLOR, BORDER_COLOR, BORDER_COLOR}, border_thickness = 1},
	)
	cu.create_tag(
		&ctx,
		"border toggle on",
		cu.Tag_Style{border_color = [4]cu.Color{SUCCESS_COLOR, BORDER_COLOR, BORDER_COLOR, BORDER_COLOR}, border_thickness = 1},
	)
	cu.create_tag(
		&ctx,
		"border toggle off",
		cu.Tag_Style{border_color = [4]cu.Color{ERROR_COLOR, BORDER_COLOR, BORDER_COLOR, BORDER_COLOR}, border_thickness = 1},
	)

	cu.create_tag(&ctx, "text big primary", {font_color = TEXT_PRIMARY_COLOR, font = &font, font_size = 20, letter_spacing = 1})
	cu.create_tag(&ctx, "text small primary", {font_color = TEXT_PRIMARY_COLOR, font = &font, font_size = 16, letter_spacing = 1})
	cu.create_tag(&ctx, "text big secondary", {font_color = TEXT_SECONDARY_COLOR, font = &font, font_size = 20, letter_spacing = 1})
	cu.create_tag(&ctx, "text small secondary", {font_color = TEXT_SECONDARY_COLOR, font = &font, font_size = 16, letter_spacing = 1})
	cu.create_tag(&ctx, "text big disabled", {font_color = TEXT_DISABLED_COLOR, font = &font, font_size = 20, letter_spacing = 1})
	cu.create_tag(&ctx, "text small disabled", {font_color = TEXT_DISABLED_COLOR, font = &font, font_size = 16, letter_spacing = 1})
	cu.create_tag(&ctx, "pad small", {padding = cu.padding(8)})
	cu.create_tag(&ctx, "pad big", {padding = cu.padding(16)})

	for !rl.WindowShouldClose() {
		defer free_all(context.temp_allocator)
		defer clear(&buttons_event_log)
		ctx.window_width = cast(f32)rl.GetScreenWidth()
		ctx.window_height = cast(f32)rl.GetScreenHeight()
		ctx.delta_time = rl.GetFrameTime()
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
		build_ui(&ctx, tick, aaloo, &state, &buffer)
		cu.end_ui(&ctx)

		rl.BeginDrawing()
		rl.ClearBackground(rl.BLANK)
		backend_rl.render(ctx)
		rl.EndDrawing()
	}
}

demo_nanovg :: proc() {

	window := init_window_glfw()
	defer close_window_glfw(window)

	nvg_ctx := nvg_gl.Create({.ANTI_ALIAS})
	defer nvg_gl.Destroy(nvg_ctx)

	nvg.CreateFont(nvg_ctx, "default", "./assets/OpenSans-Regular.ttf")
	nvg.FontBlur(nvg_ctx, 5)

	aaloo_nvg := nvg.CreateImagePath(nvg_ctx, "./assets/DA TRULY BIG AALOO.jpg", {})
	tick_nvg := nvg.CreateImagePath(nvg_ctx, "./assets/tick.png", {})

	a_w, a_h := nvg.ImageSize(nvg_ctx, aaloo_nvg)
	t_w, t_h := nvg.ImageSize(nvg_ctx, tick_nvg)

	aaloo := Image {
		data = &aaloo_nvg,
		w    = cast(f32)a_w,
		h    = cast(f32)a_h,
	}

	tick := Image {
		data = &tick_nvg,
		w    = cast(f32)t_w,
		h    = cast(f32)t_h,
	}

	buffer := strings.Builder{}
	state := edit.State{}
	edit.init(&state, context.allocator, context.allocator)
	edit.setup_once(&state, &buffer)

	ctx := cu.init_core_context(256)
	defer cu.deinit_core_context(&ctx)
	ctx.mouse.double_click_timeout = time.Millisecond * 300
	ctx.mouse.long_down_timeout = time.Millisecond * 1000
	ctx.text_measure_proc = backend_nvg.measure_text
	ctx.error_handler_proc = error_handler

	buttons_event_log: [dynamic]string

	text_style_20 := cu.Text_Style {
		font           = nvg_ctx,
		color          = PRIMARY_COLOR,
		font_size      = 20,
		letter_spacing = 1,
	}

	for !glfw.WindowShouldClose(window) {
		defer free_all(context.temp_allocator)
		defer clear(&buttons_event_log)
		gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT | gl.STENCIL_BUFFER_BIT)
		gl.ClearColor(0.1, 0.1, 0.1, 1)

		w, h := glfw.GetWindowSize(window)
		ctx.window_width = auto_cast w
		ctx.window_height = auto_cast h

		cu.begin_ui(&ctx)
		build_ui(&ctx, tick, aaloo, &state, &buffer)
		cu.end_ui(&ctx)

		nvg.BeginFrame(nvg_ctx, ctx.window_width, ctx.window_height, 1)
		backend_nvg.render(nvg_ctx, &ctx)
		nvg.EndFrame(nvg_ctx)

		glfw.PollEvents()
		glfw.SwapBuffers(window)
	}
}

error_handler :: proc(error: cu.Core_Error, message: string, args: ..any) {
	fmt.printfln("---\nError : %v\nMessage : %s", error, fmt.tprintf(message, ..args))
}
