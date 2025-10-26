package main

import "core:crypto/_aes/hw_intel"
import "core:fmt"
import "core:time"

import sdl_backend "backend/sdl_gpu"
import sdl "vendor:sdl3"

import ui "../"

PRIMARY_COLOR :: ui.Color{104, 157, 106, 255} // regular6 (#689d6a)
ON_PRIMARY_COLOR :: ui.Color{235, 219, 178, 255} // foreground (#ebdbb2)

BACKGROUND_COLOR :: ui.Color{30, 33, 34, 255} // background (#1e2122)
SURFACE_COLOR :: ui.Color{40, 40, 40, 255} // regular0 (#282828)
ELEVATED_SURFACE_COLOR :: ui.Color{68, 61, 55, 255} // gruv shadow tone

TEXT_PRIMARY_COLOR :: ui.Color{235, 219, 178, 255} // foreground (#ebdbb2)
TEXT_SECONDARY_COLOR :: ui.Color{168, 153, 132, 255} // regular7 (#a89984)
TEXT_DISABLED_COLOR :: ui.Color{146, 131, 116, 255} // bright0 (#928374)

SUCCESS_COLOR :: ui.Color{152, 151, 26, 255} // regular2 (#98971a)
WARNING_COLOR :: ui.Color{215, 153, 33, 255} // regular3 (#d79921)
ERROR_COLOR :: ui.Color{204, 36, 29, 255} // regular1 (#cc241d)
INFO_COLOR :: ui.Color{69, 133, 136, 255} // regular4 (#458588)

BORDER_COLOR :: ui.Color{168, 153, 132, 255} // regular7 (#a89984)
DIVIDER_COLOR :: ui.Color{235, 219, 178, 255} // foreground (#ebdbb2)

main :: proc() {
	backend_ctx := sdl_backend.init(
		"Window",
		"./backend/sdl_gpu/shaders/compiled/main.vert.sprv",
		"./backend/sdl_gpu/shaders/compiled/main.frag.sprv",
	)

	ctx := ui.init_context(250)
	ctp := &ctx
	defer ui.deinit_context(&ctx)

	ctx.measure_text_proc = sdl_backend.measure_text

	ctx.mouse.double_click_timeout = time.Millisecond * 300
	ctx.mouse.long_down_timeout = time.Millisecond * 1000

	sdl_backend.init_font(&backend_ctx, "./assets/JetBrainsMono-Regular.ttf", 100)

	for handle_events() {

		w_width, w_height: i32
		sdl.GetWindowSize(backend_ctx.window, &w_width, &w_height)

		ctx.window_size.x = f32(w_width)
		ctx.window_size.y = f32(w_height)

		ui.begin_ui(ctp)

		basic_background_style := ui.create_style(
			ctp,
			ui.style(BACKGROUND_COLOR, padding = ui.axis_vec2f32(16, 16), border = ui.border(BORDER_COLOR, 12, ui.axis_vec2f32(2, 2))),
		)
		elevated_background_style := ui.create_style(
			ctp,
			ui.style(ELEVATED_SURFACE_COLOR, padding = ui.axis_vec2f32(16, 16), border = ui.border(BORDER_COLOR, 12, ui.axis_vec2f32(2, 2))),
		)

		root := ui.create_widget(
			ctp,
			"root",
			ui.layout(ui.sizing(ui.fixed(ctx.window_size.x), ui.fixed(ctx.window_size.y)), child_gap = 8),
			style = basic_background_style,
		)

		ui.push_parent(ctp, root)

		ui.push_parent(
			ctp,
			ui.create_widget(ctp, "child 1", ui.layout(ui.sizing(ui.grow(), ui.grow()), child_gap = 8), style = elevated_background_style),
		)
		ui.create_widget(ctp, "child 1", ui.layout(ui.sizing(ui.grow(), ui.grow())), style = basic_background_style)
		ui.create_widget(ctp, "child 2", ui.layout(ui.sizing(ui.grow(), ui.grow())), style = basic_background_style)
		ui.pop_parent(ctp)
		ui.create_widget(ctp, "child 2", ui.layout(ui.sizing(ui.grow(), ui.grow())), style = elevated_background_style)
		ui.create_widget(ctp, "child 3", ui.layout(ui.sizing(ui.grow(), ui.grow())), style = elevated_background_style)
		ui.pop_parent(ctp)

		ui.end_ui(ctp)

		sdl_backend.render(&backend_ctx, &ctx)

	}
}

handle_events :: proc() -> bool {
	event: sdl.Event
	for sdl.PollEvent(&event) {
		#partial switch event.type {
		case .KEY_DOWN:
			if event.key.scancode == .ESCAPE {
				return false
			}
		case .QUIT:
			return false
		}
	}
	return true
}
