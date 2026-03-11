package main

import "core:fmt"
import "core:prof/spall"
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

import "base:runtime"
import "core:sync"

when ODIN_DEBUG {
	spall_ctx: spall.Context
	@(thread_local) spall_buffer: spall.Buffer
	@(instrumentation_enter)
	spall_enter :: proc "contextless" (proc_address, call_site_return_address: rawptr, loc: runtime.Source_Code_Location) {
		spall._buffer_begin(&spall_ctx, &spall_buffer, "", "", loc)
	}

	@(instrumentation_exit)
	spall_exit :: proc "contextless" (proc_address, call_site_return_address: rawptr, loc: runtime.Source_Code_Location) {
		spall._buffer_end(&spall_ctx, &spall_buffer)
	}
}

main :: proc() {

	when ODIN_DEBUG {
		spall_ctx = spall.context_create("trace_test.spall")
		defer spall.context_destroy(&spall_ctx)

		buffer_backing := make([]u8, spall.BUFFER_DEFAULT_SIZE)
		defer delete(buffer_backing)

		spall_buffer = spall.buffer_create(buffer_backing, u32(sync.current_thread_id()))
		defer spall.buffer_destroy(&spall_ctx, &spall_buffer)
	}

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

	Container :: struct {
		id: int,
		count: int,
	}

	containers_id := int(0)
	containers := make([dynamic]Container)
	defer delete(containers)

	for i in 0..<100 {
		append(&containers, Container{id=i, count=8})
	}

	for handle_events(ctp, &backend_ctx) {
		defer free_all(context.temp_allocator)
		ui.begin(ctp)

		style_base := ui.create_style(
			ctp,
			{
				color = SURFACE_COLOR,
				border = {color = BORDER_COLOR, radius = 12, thickness = 2},
				text = {font = jetbrainsmono, color = TEXT_PRIMARY_COLOR, font_size = 20},
			},
		)
		style_elevated := ui.create_style(
			ctp,
			{
				color = ELEVATED_SURFACE_COLOR,
				border = {color = BORDER_COLOR, radius = 12, thickness = 2},
				text = {font = jetbrainsmono, color = TEXT_PRIMARY_COLOR, font_size = 20},
			},
		)

		style_green := ui.create_style(
			ctp,
			{
				color = SUCCESS_COLOR,
				border = {color = BORDER_COLOR, radius = 12, thickness = 2},
				text = {font = jetbrainsmono, color = TEXT_PRIMARY_COLOR, font_size = 20},
			},
		)

		style_red := ui.create_style(
			ctp,
			{
				color = ERROR_COLOR,
				border = {color = BORDER_COLOR, radius = 12, thickness = 2},
				text = {font = jetbrainsmono, color = TEXT_PRIMARY_COLOR, font_size = 20},
			},
		)

		anim := ui.create_animation(ctp)

		root_form := ui.Form {
			layout = ui.Layout{sizing = {ui.fixed(ctx.window_size.x), ui.fixed(ctx.window_size.y)}, placement = {.Center, .Negative}, child_gap = 16, direction = .Y},
			style = style_base,
			animation = anim
		}


		root_info := ui.reserve_widget(ctp, "root")
		ui.submit_widget(ctp, root_info, root_form)
		ui.push_parent(ctp, root_info)

		text_add := ui.create_text(ctp, ui.text("Add", .None))
		text_remove := ui.create_text(ctp, ui.text("Remove", .None))

		test_form := ui.Form{layout = ui.Layout{sizing = {ui.fixed(90), ui.fixed(90)}, placement = {.Center, .Center}}, style = style_elevated, animation = anim}
		container_form := ui.Form{layout = ui.Layout{sizing = {ui.grow(min = 200), ui.fit(100)}, placement = {.Evenly, .Center}, child_gap = 16, padding = 16}, style = style_base, animation = anim}
		add_form := ui.Form{text = text_add, style = style_green, animation = anim}
		remove_form := ui.Form{text = text_remove, style = style_red, animation = anim}

		text_perf := ui.create_text(ctp, ui.text(fmt.tprint(ctp.layout_time), .None))
		timer_container_form := ui.Form{layout = {padding = 16}, text = text_perf, style = style_red}
		timer_contianer := ui.reserve_widget(ctp, "timer container")
		ui.submit_widget(ctp, timer_contianer, timer_container_form)

		add_info := ui.reserve_widget(ctp, "add button")
		ui.submit_widget(ctp, add_info, add_form)
		if .Clicked in ui.get_widget_mouse_events(ctp, add_info, .Left) {append(&containers, Container{id = containers_id, count = 5}); containers_id += 1}

		#reverse for c, i in containers {
			container_info := ui.reserve_widget(ctp, c.id)

			ui.push_parent(ctp, container_info)

			add_info := ui.reserve_widget(ctp, c.id)

			for j in 0..<c.count {
				test_container := ui.reserve_widget(ctp, (100 + c.id + j))
				if ui.is_widget_hovered(ctp, test_container) {
					test_form.layout.margin = 24
					test_form.style = style_green
				}
				if .Clicked in ui.get_widget_mouse_events(ctp, test_container, .Left) {containers[i].count -= 1}
				ui.submit_widget(ctp, test_container, test_form)
				test_form.style = style_elevated
				test_form.layout.margin = 0
			}

			remove_info := ui.reserve_widget(ctp, c.id + 500)

			ui.pop_parent(ctp)

			ui.submit_widget(ctp, container_info, container_form)
			ui.submit_widget(ctp, add_info, add_form)
			ui.submit_widget(ctp, remove_info, remove_form)

			if .Clicked in ui.get_widget_mouse_events(ctp, remove_info, .Left) {ordered_remove(&containers, i)}
			if .Clicked in ui.get_widget_mouse_events(ctp, add_info, .Left) {containers[i].count += 1}
		}

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
