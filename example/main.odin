package main

import "core:time"
import "vendor:sdl3/ttf"

import sdl_backend "backend/sdl_gpu"
import sdl "vendor:sdl3"

import ui "../"
import widgets "widgets"

PRIMARY_COLOR :: ui.Color{110, 197, 190, 255} // #6EC5BE
ON_PRIMARY_COLOR :: ui.Color{235, 219, 178, 255} // #ebdbb2

BACKGROUND_COLOR :: ui.Color{15, 20, 25, 255} // #0f1419
SURFACE_COLOR :: ui.Color{27, 31, 35, 255} // #1b1f23
ELEVATED_SURFACE_COLOR :: ui.Color{35, 40, 45, 255} // #23282d

TEXT_PRIMARY_COLOR :: ui.Color{235, 242, 249, 255} // #ebf2f9
TEXT_SECONDARY_COLOR :: ui.Color{156, 163, 170, 255} // #9ca3aa
TEXT_DISABLED_COLOR :: ui.Color{98, 104, 110, 255} // #62686e

SUCCESS_COLOR :: ui.Color{87, 217, 106, 255} // #57d96a
WARNING_COLOR :: ui.Color{255, 177, 85, 255} // #ffb155
ERROR_COLOR :: ui.Color{255, 92, 92, 255} // #ff5c5c
INFO_COLOR :: ui.Color{117, 203, 253, 255} // #75cbfd

BORDER_COLOR :: ui.Color{68, 74, 80, 255} // #444a50
DIVIDER_COLOR :: ui.Color{35, 40, 45, 255} // #23282d

main :: proc() {
	backend_ctx := sdl_backend.init(
		"Window",
		"./backend/sdl_gpu/shaders/compiled/main.vert.sprv",
		"./backend/sdl_gpu/shaders/compiled/main.frag.sprv",
		"./backend/sdl_gpu/shaders/compiled/stencil.vert.sprv",
		"./backend/sdl_gpu/shaders/compiled/stencil.frag.sprv",
	)

	ctx := ui.init_context(250)
	ctp := &ctx
	defer ui.deinit_context(&ctx)

	ctx.measure_text_width = sdl_backend.measure_text_width
	ctx.measure_text_height = sdl_backend.measure_text_height

	ctx.mouse.double_click_timeout = time.Millisecond * 300
	ctx.mouse.long_down_timeout = time.Millisecond * 1000

	sdl_backend.init_font(&backend_ctx)
	nastaliq := sdl_backend.add_font(&backend_ctx, "./assets/NotoNastaliqUrdu-Regular.ttf", 100)

	widgets.theme.font = nastaliq
	widgets.theme.font_size = 20
	widgets.theme.container_child_gap = 8
	widgets.theme.bar_height = 8
	widgets.theme.bar_minimum_width = 64
	widgets.theme.control_size = 16

	defer sdl_backend.de_init(&backend_ctx)
	defer sdl_backend.de_init_font(&backend_ctx)

	main_container_offset: ui.Vec2f32
	slider_value: f32
	toggle_bool: bool
	switch_bool: bool
	progress: f32

	for handle_events(ctp, &backend_ctx) {
		defer free_all(context.temp_allocator)
		ui.begin_ui(ctp)
		ui.push_parent(ctp, ui.create_widget(ctp, "real root", ui.layout(ui.sizing(ui.fixed(ctx.window_size.x), ui.fixed(ctx.window_size.y)))))
		widgets.build_themes(ctp)

		progress += ctx.frametime / 5

		if progress > 1 do progress = 0

		{
			main_container_index, main_container_events := widgets.begin_container(
				ctp,
				"main container",
				.Y,
				{.Lock_Active, .Lock_Hover},
				no_theme_hover = true,
			)
			main_container := ui.get_widget(ctp, main_container_index)
			main_container.override = ui.create_override(
				ctp,
				ui.override({}, ui.offset(ui.fixed(main_container_offset.x), ui.fixed(main_container_offset.y)), {}),
			)
			if .Down in main_container_events[.Left] {
				main_container_offset += ctx.mouse.delta
			}

			{
				widgets.button(ctp, "Button 1", "Test button")
				widgets.button(ctp, "Button 2", "Test button hmmmm")
				widgets.slider(ctp, "slider", "test slider", &slider_value, 5, 5000, 1, .X)
				widgets.toggle(ctp, "toggle", "Toggle^2", &toggle_bool)
				widgets.ui_switch(ctp, "switch", "Switch", &switch_bool)
				widgets.progress_bar(ctp, "progress bar", "progress", progress)
			}
			widgets.end_container(ctp)
		}

		ui.pop_parent(ctp)
		ui.end_ui(ctp)

		sdl_backend.render(&backend_ctx, &ctx)
	}
}

handle_events :: proc(ctx: ^ui.Core_Context, backend_ctx: ^sdl_backend.Backend_Context) -> bool {
	event: sdl.Event

	@(static) event_ctx: struct {
		is_left_down, is_right_down, is_middle_down: bool,
	}

	ctx.mouse.scroll = 0
	ctx.mouse.scroll_v = 0

	for sdl.PollEvent(&event) {
		#partial switch event.type {
		case .KEY_DOWN:
			if event.key.scancode == .ESCAPE {
				return false
			}
		case .QUIT:
			return false
		case .MOUSE_WHEEL:
			ctx.mouse.scroll_v.x = event.wheel.x
			ctx.mouse.scroll_v.y = event.wheel.y
			ctx.mouse.scroll = ctx.mouse.scroll_v.y
		case .MOUSE_BUTTON_DOWN:
			if event.button.button == sdl.BUTTON_LEFT {
				event_ctx.is_left_down = true
				ctx.mouse.mapped_events[.Left] += {.Pressed}
			}
			if event.button.button == sdl.BUTTON_RIGHT {
				event_ctx.is_right_down = true
				ctx.mouse.mapped_events[.Right] += {.Pressed}
			}
			if event.button.button == sdl.BUTTON_MIDDLE {
				event_ctx.is_middle_down = true
				ctx.mouse.mapped_events[.Middle] += {.Pressed}
			}
		case .MOUSE_BUTTON_UP:
			if event.button.button == sdl.BUTTON_LEFT {
				event_ctx.is_left_down = false
				ctx.mouse.mapped_events[.Left] += {.Released}
			}
			if event.button.button == sdl.BUTTON_RIGHT {
				event_ctx.is_right_down = false
				ctx.mouse.mapped_events[.Right] += {.Released}
			}
			if event.button.button == sdl.BUTTON_MIDDLE {
				event_ctx.is_middle_down = false
				ctx.mouse.mapped_events[.Middle] += {.Released}
			}
		}
	}

	if event_ctx.is_left_down {
		ctx.mouse.mapped_events[.Left] += {.Down}
	}
	if event_ctx.is_right_down {
		ctx.mouse.mapped_events[.Right] += {.Down}
	}
	if event_ctx.is_middle_down {
		ctx.mouse.mapped_events[.Middle] += {.Down}
	}

	ctx.mouse.old_position = ctx.mouse.position
	w_width, w_height: i32

	_ = sdl.GetMouseState(&ctx.mouse.position.x, &ctx.mouse.position.y)
	_ = sdl.GetWindowSize(backend_ctx.window, &w_width, &w_height)

	ctx.mouse.delta = ctx.mouse.position - ctx.mouse.old_position

	ctx.window_size.x = f32(w_width)
	ctx.window_size.y = f32(w_height)

	return true
}
