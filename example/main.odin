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

	containers := make([dynamic]int) 

	for handle_events(ctp, &backend_ctx) {
		defer free_all(context.temp_allocator)
		ui.begin(ctp)

		style_base := ui.create_style(
			ctp,
			{
				color = SURFACE_COLOR,
				padding = {8, 8},
				border = {color = BORDER_COLOR, radius = 12, thickness = 2},
				text = {font = jetbrainsmono, color = TEXT_PRIMARY_COLOR, font_size = 20},
			},
		)
		style_elevated := ui.create_style(
			ctp,
			{
				color = ELEVATED_SURFACE_COLOR,
				padding = {8, 8},
				border = {color = BORDER_COLOR, radius = 12, thickness = 2},
				text = {font = jetbrainsmono, color = TEXT_PRIMARY_COLOR, font_size = 20},
			},
		)

		style_green := ui.create_style(
			ctp,
			{
				color = SUCCESS_COLOR,
				padding = {8, 8},
				border = {color = BORDER_COLOR, radius = 12, thickness = 2},
				text = {font = jetbrainsmono, color = TEXT_PRIMARY_COLOR, font_size = 20},
			},
		)

		style_red := ui.create_style(
			ctp,
			{
				color = ERROR_COLOR,
				padding = {8, 8},
				border = {color = BORDER_COLOR, radius = 12, thickness = 2},
				text = {font = jetbrainsmono, color = TEXT_PRIMARY_COLOR, font_size = 20},
			},
		)

		anim := ui.create_animation(ctp)
		
		root_form := ui.Form {
			kind = ui.Layout{sizing = {ui.fixed(ctx.window_size.x), ui.fixed(ctx.window_size.y)}, alignment = {.Center, .Negative}, child_gap = 16, direction = .Y},
			style = style_base,
			animation = anim
		}


		root_info := ui.reserve_widget(ctp, "root")
		ui.submit_widget(ctp, root_info, root_form)
		ui.push_parent(ctp, root_info)
	
		test_form := ui.Form{kind = ui.Layout{sizing = {ui.fixed(90), ui.fixed(90)}, alignment = {.Center, .Center}}, style = style_elevated, animation = anim}
		container_form := ui.Form{kind = ui.Layout{sizing = {ui.grow(min = 200), ui.fixed(100)}, alignment = {.Center, .Center}, child_gap = 16}, style = style_base, animation = anim}
		add_form := ui.Form{kind = ui.text("Add", .None), style = style_green, animation = anim}
		remove_form := ui.Form{kind = ui.text("Remove", .None), style = style_red, animation = anim}
		
		add_info := ui.reserve_widget(ctp, "add button")
		ui.submit_widget(ctp, add_info, add_form)
		if .Clicked in ui.get_widget_mouse_events(ctp, add_info, .Left) {append(&containers, 5)}

		#reverse for c, i in containers {
			container_info := ui.reserve_widget(ctp, i)

			ui.push_parent(ctp, container_info)

			add_info := ui.reserve_widget(ctp, i)
			
			for j in 0..<c {
				test_container := ui.reserve_widget(ctp, (100 + i + j))
				if ui.is_widget_hovered(ctp, test_container) {
					test_form.style = style_green
				}
				if .Clicked in ui.get_widget_mouse_events(ctp, test_container, .Left) {containers[i] -= 1}
				ui.submit_widget(ctp, test_container, test_form)
				test_form.style = style_elevated
			}

			remove_info := ui.reserve_widget(ctp, i + 500)

			ui.pop_parent(ctp)

			ui.submit_widget(ctp, container_info, container_form)
			ui.submit_widget(ctp, add_info, add_form)
			ui.submit_widget(ctp, remove_info, remove_form)

			if .Clicked in ui.get_widget_mouse_events(ctp, remove_info, .Left) {ordered_remove(&containers, i)}
			if .Clicked in ui.get_widget_mouse_events(ctp, add_info, .Left) {containers[i] += 1}
		}

		ui.pop_parent(ctp)
		ui.end(ctp)

		// if len(ctp.new) > 0 {
		// 	fmt.println(ctp.new)
		// }
		
		// if len(ctp.dead) > 0 {
		// 	fmt.println(ctp.dead)
		// }

			
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
