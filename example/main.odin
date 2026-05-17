package example

import "core:reflect"
import "core:fmt"
import "core:time"

import ui "../"

import widgets "widgets"

import sdl "vendor:sdl3"
import sdl_backend "../backend/sdl_gpu"

Test_Enum :: enum {
	Foo,
	Bar,
	Baz,
	Foo_Bar_Baz
}

Test_Enum_Bitset :: bit_set[Test_Enum]

Test_Struct :: struct {
	sum_bool: bool,
	field_1: f32,
	field_2: int,
	str:     string,
	e:       ui.Align,
	eb:      Test_Enum_Bitset,
	anon_struct: struct {
		b : f32
	}
}

main :: proc() {
	sdl.SetLogPriorities(.VERBOSE)
	assert(sdl.Init({.VIDEO}))

	window := sdl.CreateWindow("Ui debug", 800, 600, {.RESIZABLE})
	gpu := sdl.CreateGPUDevice({.SPIRV}, false, nil)
	assert(sdl.ClaimWindowForGPUDevice(gpu, window))
	assert(sdl.SetGPUSwapchainParameters(gpu, window, .SDR, .IMMEDIATE))

	defer {
		sdl.ReleaseWindowFromGPUDevice(gpu, window)
		sdl.DestroyGPUDevice(gpu)
		sdl.DestroyWindow(window)
		sdl.Quit()
	}

	backend_ctx := sdl_backend.init(
		window, gpu,
		"./../backend/sdl_gpu/shaders/compiled/main.vert.sprv",
		"./../backend/sdl_gpu/shaders/compiled/main.frag.sprv",
		context.allocator
	)
	defer sdl_backend.de_init(&backend_ctx)

	ctx := ui.init_context(0, 2048, context.allocator)
	ctp := &ctx
	defer ui.deinit_context(&ctx)

	ctx.measure_text_width = sdl_backend.measure_text_width
	ctx.measure_text_height = sdl_backend.measure_text_height
	ctx.measure_text_hover_index = sdl_backend.measure_text_hover_index
	ctx.mouse.double_click_timeout = time.Millisecond * 300
	ctx.mouse.long_down_timeout = time.Millisecond * 1000
	ctx.mouse.repeat_timeout = time.Millisecond * 200

	sdl_backend.init_font(&backend_ctx)
	font_12 := sdl_backend.add_font(&backend_ctx, "./assets/Hermit.otf", 12)
	font_13 := sdl_backend.add_font(&backend_ctx, "./assets/Hermit.otf", 13)
	font_14 := sdl_backend.add_font(&backend_ctx, "./assets/Hermit.otf", 16)
	font_20 := sdl_backend.add_font(&backend_ctx, "./assets/Hermit.otf", 20)
	font_28 := sdl_backend.add_font(&backend_ctx, "./assets/Hermit.otf", 28)
	defer sdl_backend.de_init_font(&backend_ctx)

	font := widgets.Font{
		f_xs = font_12,
		f_sm = font_13,
		f_md = font_14,
		f_xl = font_20,
		f_lg = font_28,
	}

	widgets.state.text_user_data = backend_ctx.font_engine
	selected_palette := widgets.Default_Palette.Mono_Dark

	for handle_events(ctp, &backend_ctx) {
		defer free_all(context.temp_allocator)
		ui.begin(ctp)
		widgets.build_theme(ctp, widgets.DEFAULT_PALETTES[selected_palette], widgets.DEFAULT_SPACING, font)

		{
			root := ui.reserve_widget(ctp, "__root")
			rootf := ui.Form{}
			rootf.layout.sizing = ui.sizing(ui.fixed(ctp.window_size.x), ui.fixed(ctp.window_size.y))
			rootf.layout.direction = .Y
			ui.submit_widget(ctp, root, rootf)
			ui.push_parent(ctp, root)
		}

		@static slider_val := f32(0.0)
		@static checkbox_bool := false
		if widgets.container(ctp, "__test_container", "Text Container") {

		    @static spinbox_value := 0
		    widgets.spinbox(ctp, "__text_spin_box", "Spin Box", &spinbox_value, -10, 10, 1)

		    if widgets.inline_container(ctp, "__test_inline_container", "Inline Contaienr") {
				widgets.button(ctp, "__test_button", "Button! Press Me!")
				widgets.slider(ctp, "__test_slider", "Slideer", &slider_val, -5, 5)

				widgets.begin_radio(ctp, "__test_radio", "Radio Buttons. Only one can be selected at a time")
				widgets.radio_item(ctp, "Item 1")
				widgets.radio_item(ctp, "Item 2")
				widgets.end_radio(ctp)

				widgets.end_inline_container(ctp)
			}

			if widgets.container(ctp, "__test_container_nested", "Nested Container") {
				widgets.button(ctp, "__test_button", "Button! Press Me!")
				widgets.slider(ctp, "__test_slider", "Slider", &slider_val, -5, 5)

				widgets.begin_radio(ctp, "__test_radio", "Radio Buttons. Only one can be selected at a time")
				widgets.radio_item(ctp, "Item 1")
				widgets.radio_item(ctp, "Item 2")
				widgets.end_radio(ctp)

				widgets.begin_dropdown(ctp, "__test_dropdown", "Dropdown item selector")
				for palette in widgets.Default_Palette {
					if widgets.dropdown_item(ctp, reflect.enum_string(palette)) {
						selected_palette = palette
					}
				}
				widgets.end_dropdown(ctp)

				widgets.text_box(ctp, "__test_tex_box", "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.")
				widgets.end_container(ctp)
			}

			widgets.progress_bar(ctp, "__test_progress_bar", "Prgress", slider_val, -5, 5)
			widgets.checkbox(ctp, "__test_checkbox", "checkbox", &checkbox_bool)
			widgets.toggle(ctp, "__test_toggle", "toggle", &checkbox_bool)
			@static t := Test_Struct{}
			t.str = "tset sr"
			widgets.display_struct(ctp, "__test_display_struct", "Test", t)
			widgets.end_container(ctp)
		}

		ui.end(ctp)

		backend_ctx.cmd_buf = sdl.AcquireGPUCommandBuffer(gpu)
		assert(sdl.WaitAndAcquireGPUSwapchainTexture(backend_ctx.cmd_buf, window, &backend_ctx.render_texture, nil, nil))
		sdl_backend.render(&backend_ctx, ctp)
		assert(sdl.SubmitGPUCommandBuffer(backend_ctx.cmd_buf))
	}
}

handle_events :: proc(ctx: ^ui.Core_Context, backend_ctx: ^sdl_backend.Backend_Context) -> bool {
	event: sdl.Event
	@(static) down: struct {
		l, r, m: bool,
	}
	ctx.mouse.scroll = 0
	ctx.mouse.scroll_v = 0
	for sdl.PollEvent(&event) {
		#partial switch event.type {
		case .KEY_DOWN:
			if event.key.scancode == .ESCAPE {return false}
		case .QUIT:
			return false
		case .MOUSE_WHEEL:
			ctx.mouse.scroll_v = {event.wheel.x, event.wheel.y}
			ctx.mouse.scroll = event.wheel.y
		case .MOUSE_BUTTON_DOWN:
			switch event.button.button {
			case sdl.BUTTON_LEFT:
				down.l = true; ctx.mouse.mapped_events[.Left] += {.Pressed}
			case sdl.BUTTON_RIGHT:
				down.r = true; ctx.mouse.mapped_events[.Right] += {.Pressed}
			case sdl.BUTTON_MIDDLE:
				down.m = true; ctx.mouse.mapped_events[.Middle] += {.Pressed}
			}
		case .MOUSE_BUTTON_UP:
			switch event.button.button {
			case sdl.BUTTON_LEFT:
				down.l = false; ctx.mouse.mapped_events[.Left] += {.Released}
			case sdl.BUTTON_RIGHT:
				down.r = false; ctx.mouse.mapped_events[.Right] += {.Released}
			case sdl.BUTTON_MIDDLE:
				down.m = false; ctx.mouse.mapped_events[.Middle] += {.Released}
			}
		}
	}
	if down.l {ctx.mouse.mapped_events[.Left] += {.Down}}
	if down.r {ctx.mouse.mapped_events[.Right] += {.Down}}
	if down.m {ctx.mouse.mapped_events[.Middle] += {.Down}}
	ctx.mouse.old_position = ctx.mouse.position
	w_w, w_h: i32
	_ = sdl.GetMouseState(&ctx.mouse.position.x, &ctx.mouse.position.y)
	_ = sdl.GetWindowSize(backend_ctx.window, &w_w, &w_h)
	ctx.mouse.delta = ctx.mouse.position - ctx.mouse.old_position
	ctx.window_size = {f32(w_w), f32(w_h)}
	return true
}
