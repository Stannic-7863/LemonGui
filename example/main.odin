package example

import "core:fmt"
import "vendor:sdl3/ttf"
import "core:unicode/utf8"
import "core:reflect"

import lui "../"

import widgets "../widgets"

import sdl "vendor:sdl3"
import sdl_backend "../backend/sdl_gpu"

Entity_Type :: enum {
	Player,
	Enemy,
	Npc,
}

Weapon :: enum {
	Axe,
	Sword,
	Lance,
}

Onion :: struct {
	saturation:    f32,
	hunger:        f32,
	smell_factor:  f32,
}

Steak_Stage :: enum {
	Under,
	Rare,
	Medium_Rare,
	Weldone,
	Over,
}

Steak :: struct {
	saturation: f32,
	hunger:     f32,
	stage:      Steak_Stage,
}

Food :: union {
	Steak,
	Onion,
}

Weapons :: bit_set[Weapon]

Vec2f32 :: [2]f32
Vec4f32 :: [4]f32

Entity :: struct {
	name:     string16	  `lui:"textbox"`,
	position: Vec2f32     `lui:"row"`,
	size:     Vec2f32     `lui:"row"`,
	type:     Entity_Type `lui:"radio"`,
	quat:     Vec4f32,
	weapons:  Weapons,
	is_alive: bool        `lui:"toggle"`,
	damage:   f32         `lui:"min=0,max=50"`,
	health:   int,
	food:     Food,
}

main :: proc() {
	assert(sdl.Init({.VIDEO}))
	defer sdl.Quit()
	sdl.SetLogPriorities(.VERBOSE)

	window := sdl.CreateWindow("lui debug", 1000, 1000, {.RESIZABLE, .VULKAN})
	gpu := sdl.CreateGPUDevice({.SPIRV}, true, nil)
	assert(sdl.ClaimWindowForGPUDevice(gpu, window))

	defer sdl.DestroyWindow(window)
	defer sdl.DestroyGPUDevice(gpu)
	defer sdl.ReleaseWindowFromGPUDevice(gpu, window)


	backend_ctx := sdl_backend.init(window, gpu, context.allocator)
	defer sdl_backend.deinit(&backend_ctx)

	__default_init_parameters := lui.get_default_init_parameters()
	__default_init_parameters.text_parameters = sdl_backend.get_default_text_init_parameters(&backend_ctx)

	ctx := lui.init_context(__default_init_parameters)
	ctp := &ctx
	defer lui.deinit_context(&ctx)

	// sdl_ttf recreates/overwrite the texture atlas if we change font size via ttf.SetFontSize.
	// So instead just load font with desired sizes and pass that into the backend (Until I figure out how to cache the atlases)
	font := widgets.Font{
		f_xs = {font = sdl_backend.add_font(&backend_ctx, "./assets/Hermit.otf", 10)},
		f_sm = {font = sdl_backend.add_font(&backend_ctx, "./assets/Hermit.otf", 12)},
		f_md = {font = sdl_backend.add_font(&backend_ctx, "./assets/Hermit.otf", 16)},
		f_xl = {font = sdl_backend.add_font(&backend_ctx, "./assets/Hermit.otf", 20)},
		f_lg = {font = sdl_backend.add_font(&backend_ctx, "./assets/Hermit.otf", 24)},
	}

	widgets.init_state()
	defer widgets.deinit_state()

	selected_palette := widgets.Default_Palette.Gruvbox_Light

	// handle_events returns (resized, running).
	// resized: true on the frame a window resize event was received.
	// running: false when the user closes the window or presses Escape.
	for resize in handle_events(ctp, window) {

		// Clears per-frame state: resets the widget tree, clears render commands,
		// and resets input event flags that are only valid for one frame (Pressed, Released).
		lui.begin(ctp)

		// Resolves the active theme into concrete colors, spacing, and font styles
		// that widgets read from widgets.state. Must be called before any widget proc.
		widgets.build_theme(ctp, widgets.DEFAULT_PALETTES[selected_palette], widgets.DEFAULT_SPACING, font)

		// The root widget is a transparent, window-sized container.
		// Every other widget must be a descendant of it. Without it, the layout
		// pass has no anchor and widget positions will be undefined.
		{
			root := lui.reserve_widget(ctp, "__root")
			rootf := lui.Form{}
			rootf.layout.sizing = lui.sizing(lui.fixed(ctp.window_size.x), lui.fixed(ctp.window_size.y))
			rootf.layout.direction = .Y
			lui.submit_widget(ctp, root, rootf)
			lui.push_parent(ctp, root)
		}

		// container returns true while it is open. Widgets added inside the block
		// become children of that container. end_container must be called inside
		// the same block — omitting it corrupts the parent stack.
		if widgets.container(ctp, "__test_container", "Text Container") {
			@static slider_val    := f32(0.0)
			@static checkbox_bool := false
			@static spinbox_value := 0
			@static dragval := Vec2f32{10, 10}
			reference := Vec2f32{10, 10}
			bounds := Vec2f32{10, 10}

			// widgets.display_struct(ctp, "__theme_editor", "Theme", widgets.DEFAULT_PALETTES[selected_palette])
			widgets.spinbox(ctp, "__text_spin_box", "Spin Box", &spinbox_value, -10, 10, 1)

			widgets.mouse_indicator(ctp, "__test_mouse_indicator", "Mouse Indicator")
			widgets.track_region(ctp, "__test_drag_region", "Drag", &dragval, reference, bounds)
			// inline_container container has no clip and can't be undocked.
			// end_inline_container must be called inside the same if block.
			if widgets.inline_container(ctp, "__test_inline_container", "Inline Contaienr") {

				mouse_events := widgets.button(ctp, "__test_button1", "Button! Press Me!");
				if .Clicked in mouse_events[.Left] {
					// button clicked
				}
				widgets.button(ctp, "__test_button2", "Button! Press Me!")
				widgets.button(ctp, "__test_button3", "Button! Press Me!")
				widgets.button(ctp, "__test_button4", "Button! Press Me!")
				widgets.button(ctp, "__test_button5", "Button! Press Me!")
				widgets.button(ctp, "__test_button6", "Button! Press Me!")

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

				widgets.end_inline_container(ctp)
			}

			if widgets.container(ctp, "__test_container_nested", "Nested Container") {
				widgets.button(ctp, "__test_button", "Button! Press Me!")

				widgets.slider(ctp, "__test_slider", "Slider", &slider_val, -5, 5)

				widgets.begin_radio(ctp, "__test_radio", "Radio Buttons. Only one can be selected at a time")
				widgets.radio_item(ctp, "Item 1")
				widgets.radio_item(ctp, "Item 2")
				widgets.end_radio(ctp)


				widgets.text_box(ctp, "__test_tex_box", "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, qluis nostrud exercitation ullamco laboris nisi ut aliqluip ex ea commodo consequat. Dluis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qlui officia deserunt mollit anim id est laborum.")
				if gain, lose := widgets.input_box(ctp, "__test_input_box", .Words, context.allocator); true {
					if gain {
						assert(sdl.StartTextInput(window))
					}
					if lose {
						assert(sdl.StopTextInput(window))
					}
				}
				widgets.end_container(ctp)
			}

			widgets.progress_bar(ctp, "__test_progress_bar", "Prgress", slider_val, -5, 5)
			widgets.checkbox(ctp, "__test_checkbox", "checkbox", &checkbox_bool)
			widgets.toggle(ctp, "__test_toggle", "toggle", &checkbox_bool)
			@static t := Entity{}
			t.name = "An Entity"
			widgets.display_struct(ctp, "__test_display_struct", "Entity", t)
			widgets.end_container(ctp)
		}

		lui.pop_parent(ctp)

		// Runs the layout pass over the widget tree built above, computes final
		// positions and sizes, and emits draw commands into ctx.render_commands.
		lui.end(ctp)

		if resize {
			sdl_backend.resize_target(&backend_ctx, u32(ctx.window_size.x), u32(ctx.window_size.y))
		}

		command_buffer := sdl.AcquireGPUCommandBuffer(gpu)
		sdl_backend.render(&backend_ctx, ctp, command_buffer)
		swapchain := (^sdl.GPUTexture)(nil)
		assert(sdl.WaitAndAcquireGPUSwapchainTexture(command_buffer, window, &swapchain, nil, nil))

		fmt.println("Yo")
		sdl.BlitGPUTexture(command_buffer, {
			clear_color = {0, 0, 0, 0},
			source = {
				w = u32(ctx.window_size.x),
				h = u32(ctx.window_size.y),
				texture = backend_ctx.render_texture,
			},
			destination = {
				w = u32(ctx.window_size.x),
				h = u32(ctx.window_size.y),
				texture = swapchain
			},
			load_op = .CLEAR,
			filter = .NEAREST,
		})

		assert(sdl.SubmitGPUCommandBuffer(command_buffer))

		free_all(context.temp_allocator)
	}
}

// handle_events polls the SDL event queue and maps events into lui's input model.
// Returns (resized, running):
//   resized — true on the frame a window resize event arrived; caller should rebuild size-dependent resources.
//   running — false when the user closes the window or presses Escape; caller should exit the loop.
//
// Mouse button state (Down) is tracked across frames with a static struct because SDL only
// sends Pressed/Released events on transitions, not every frame the button is held.
handle_events :: proc(ctx: ^lui.Core_Context, window: ^sdl.Window) -> (bool, bool) {
	event: sdl.Event
	@static mouse_down := bit_set[lui.Mouse_Button]{}
	@static prev_keyboard_down := [lui.Keyboard_Key]bool{}
	@static keyboard_down := [lui.Keyboard_Key]bool{}

	ctx.keyboard.input = {}

	resized := false

	keys := sdl.GetKeyboardState(nil)
	prev_keyboard_down = keyboard_down

	for s in sdl.Scancode.A..=sdl.Scancode.Z {
		k := lui.Keyboard_Key(int(lui.Keyboard_Key.A) + int(s) - int(sdl.Scancode.A))
		keyboard_down[k] = keys[s]
	}

	for s in sdl.Scancode._1 ..=sdl.Scancode._9 {
		k := lui.Keyboard_Key(int(lui.Keyboard_Key.Key_0) + int(s) - int(sdl.Scancode._1))
		keyboard_down[k] = keys[s]
	}

	for s in sdl.Scancode.KP_9 ..=sdl.Scancode.KP_0 {
		k := lui.Keyboard_Key(int(lui.Keyboard_Key.Num_9) + int(s) - int(sdl.Scancode.KP_9))
		keyboard_down[k] = keys[s]
	}


	keyboard_down[.Escape] = keys[sdl.Scancode.ESCAPE]
	keyboard_down[.Left] = keys[sdl.Scancode.LEFT]
	keyboard_down[.Right] = keys[sdl.Scancode.RIGHT]
	keyboard_down[.Up] = keys[sdl.Scancode.UP]
	keyboard_down[.Down] = keys[sdl.Scancode.DOWN]
	keyboard_down[.Backspace] = keys[sdl.Scancode.BACKSPACE]
	keyboard_down[.Delete] = keys[sdl.Scancode.DELETE]
	keyboard_down[.Left_Shift] = keys[sdl.Scancode.LSHIFT]
	keyboard_down[.Right_Shift] = keys[sdl.Scancode.RSHIFT]
	keyboard_down[.Left_Control] = keys[sdl.Scancode.LCTRL]
	keyboard_down[.Right_Control] = keys[sdl.Scancode.RCTRL]
	keyboard_down[.Left_Alt] = keys[sdl.Scancode.LALT]
	keyboard_down[.Right_Alt] = keys[sdl.Scancode.RALT]
	keyboard_down[.Left_Super] = keys[sdl.Scancode.LGUI]
	keyboard_down[.Right_Super] = keys[sdl.Scancode.RGUI]

	for k in lui.Keyboard_Key {
		if keyboard_down[k] && !prev_keyboard_down[k] { ctx.keyboard.mapped_events[k] += {.Pressed, .Down} }
		if !keyboard_down[k] && prev_keyboard_down[k] { ctx.keyboard.mapped_events[k] += {.Released, .Down} }
		if keyboard_down[k] && prev_keyboard_down[k] { ctx.keyboard.mapped_events[k] += {.Down} }
	}

	// Scroll is a per-frame value — reset it so a wheel event from a previous
	// frame does not carry over when no wheel event arrives this frame.
	ctx.mouse.scroll   = 0
	ctx.mouse.scroll_v = 0

	for sdl.PollEvent(&event) {
		#partial switch event.type {
		case .KEY_DOWN:
			#partial switch event.key.scancode {
			case .TAB:
				if .LSHIFT in event.key.mod { lui.focus_prev(ctx) }
				else { lui.focus_next(ctx) }
			}
		case .QUIT:
			return false, false
		case .TEXT_INPUT:
			ctx.keyboard.input = utf8.string_to_runes(string(event.text.text), context.temp_allocator)
		case .MOUSE_WHEEL:
			ctx.mouse.scroll_v = {event.wheel.x, event.wheel.y}
			ctx.mouse.scroll   = event.wheel.y
		case .MOUSE_BUTTON_DOWN:
			switch event.button.button {
			case sdl.BUTTON_LEFT:
				mouse_down += {.Left}; ctx.mouse.mapped_events[.Left] += {.Pressed}
			case sdl.BUTTON_RIGHT:
				mouse_down += {.Right}; ctx.mouse.mapped_events[.Right] += {.Pressed}
			case sdl.BUTTON_MIDDLE:
				mouse_down += {.Middle}; ctx.mouse.mapped_events[.Middle] += {.Pressed}
			}
		case .MOUSE_BUTTON_UP:
			switch event.button.button {
			case sdl.BUTTON_LEFT:
				mouse_down -= {.Left}; ctx.mouse.mapped_events[.Left] += {.Released}
			case sdl.BUTTON_RIGHT:
				mouse_down -= {.Right}; ctx.mouse.mapped_events[.Right] += {.Released}
			case sdl.BUTTON_MIDDLE:
				mouse_down -= {.Middle}; ctx.mouse.mapped_events[.Middle] += {.Released}
			}
		case .WINDOW_RESIZED, .WINDOW_MAXIMIZED, .WINDOW_MINIMIZED, .WINDOW_RESTORED:
			resized = true
		}
	}

	// Inject continuous Down events for any button that is currently held.
	// lui uses Down to distinguish held state from the single-frame Pressed event.
	if .Left in mouse_down {ctx.mouse.mapped_events[.Left]   += {.Down}}
	if .Right in mouse_down {ctx.mouse.mapped_events[.Right]  += {.Down}}
	if .Middle in mouse_down {ctx.mouse.mapped_events[.Middle] += {.Down}}

	ctx.mouse.old_position = ctx.mouse.position
	w_w, w_h: i32
	_ = sdl.GetMouseState(&ctx.mouse.position.x, &ctx.mouse.position.y)
	_ = sdl.GetWindowSize(window, &w_w, &w_h)
	ctx.mouse.delta  = ctx.mouse.position - ctx.mouse.old_position
	ctx.window_size  = {f32(w_w), f32(w_h)}
	return resized, true
}
