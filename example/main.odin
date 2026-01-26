package main

import "core:time"
import "vendor:sdl3/ttf"

import sdl_backend "backend/sdl_gpu"
import sdl "vendor:sdl3"

import ui "../"

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
	jetbrainsmono := sdl_backend.add_font(&backend_ctx, "./assets/JetBrainsMono-Regular.ttf", 100)

	// widgets.theme.font = jetbrainsmono

	defer sdl_backend.de_init(&backend_ctx)
	defer sdl_backend.de_init_font(&backend_ctx)

	main_container_offset: ui.Vec2f32
	slider_value: f32
	toggle_bool: bool
	switch_bool: bool
	progress: f32

	selected_radio_item: int = -1
	selected_dropdown_item: int = -1
	radio_labels: []string = {"Radio 1", "Radio 2", "Radio 3"}
	dropdown_labels: []string = {"Dropdown item 1 long", "Dropdown item 2", "Dropdown item 3", "Dropdown item 4"}

	for handle_events(ctp, &backend_ctx) {
		defer free_all(context.temp_allocator)
		ui.begin(ctp)

		style_root := ui.create_style(ctp, {color = SURFACE_COLOR, padding = {16, 8}})
		style_base := ui.create_style(ctp, {color = SURFACE_COLOR, padding = {8, 16}, border = {color = BORDER_COLOR, radius = 12, thickness = 2}})
		style_elevated := ui.create_style(ctp, {color = ELEVATED_SURFACE_COLOR, border = {color = BORDER_COLOR, radius = 12, thickness = 2}})

		root_info := ui.reserve_widget(ctp, "root")
		root_form := ui.Form{kind = ui.Layout{sizing = {ui.fixed(ctx.window_size.x), ui.fixed(ctx.window_size.y)}, child_gap = 16}, style = style_root}
		ui.submit_widget(ctp, root_info, root_form)

		ui.push_parent(ctp, root_info)

		container1 := ui.reserve_widget(ctp, "container 1")
		container2 := ui.reserve_widget(ctp, "container 2")

		container_form := ui.Form {
			kind = ui.Layout{sizing = {ui.grow(), ui.grow()}, child_gap = 16, alignment = {.Center, .Center}},
			style = style_base,
		}

		ui.submit_widget(ctp, container1, container_form)
		ui.submit_widget(ctp, container2, container_form)

		ui.push_parent(ctp, container1)
		
		c_1 := ui.reserve_widget(ctp, "child container 1")
		c_2 := ui.reserve_widget(ctp, "child container 2")

		ui.submit_widget(ctp, c_1, container_form)
		ui.submit_widget(ctp, c_2, container_form)

		ui.pop_parent(ctp)

		ui.pop_parent(ctp)
		ui.end(ctp)

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
