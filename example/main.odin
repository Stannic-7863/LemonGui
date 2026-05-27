package example

import "core:mem"
import "core:fmt"
import "core:reflect"
import "core:time"

import lui "../"

import widgets "widgets"

import sdl "vendor:sdl3"
import sokol_backend "../backend/sokol"
import sgfx "../backend/sokol/sokol-odin/sokol/gfx"
import sglog "../backend/sokol/sokol-odin/sokol/log"

// Fullscreen quad that covers NDC space [-1, 1].
// Used to blit the UI render target onto the swapchain.
swap_vertex_source : cstring = `
	#version 430

    const vec2 positions[6] = vec2[](vec2(1.0, 1.0), vec2(-1.0, 1.0), vec2(-1.0,  -1.0), vec2(1.0, 1.0), vec2(-1.0, -1.0), vec2(1.0, -1.0));
    const vec2 uvs[6] = vec2[](vec2(1.0, 1.0), vec2(0.0, 1.0), vec2(0.0, 0.0), vec2(1.0, 1.0), vec2(0.0, 0.0), vec2(1.0, 0.0));

    out vec2 uv;

	void main() {
		gl_Position = vec4(positions[gl_VertexID], 0, 1.0);
		uv = uvs[gl_VertexID];
	}

`

// Samples the UI render target and writes it to the swapchain framebuffer.
// Alpha blending is handled by the pipeline state, not here.
swap_frag_source : cstring = `
	#version 430

	in vec2 uv;
	out vec4 color;

	uniform sampler2D tex;

	void main() {
		color = texture(tex, uv);
	}
`

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
	track: mem.Tracking_Allocator
	mem.tracking_allocator_init(&track, context.allocator)
	context.allocator = mem.tracking_allocator(&track)

	defer {
		if len(track.allocation_map) > 0 {
			fmt.eprintf("=== %v allocations not freed: ===\n", len(track.allocation_map))
			for _, entry in track.allocation_map {
				fmt.eprintf("- %v bytes @ %v\n", entry.size, entry.location)
			}
		}
		mem.tracking_allocator_destroy(&track)
	}

	// SDL is used purely for windowing and input. We deliberately avoid sokol_app
	// because it forces an init/frame/shutdown callback structure. The loop below
	// gives us a straightforward sequential flow instead.
	assert(sdl.Init({.VIDEO}))
	sdl.SetLogPriorities(.VERBOSE)

	// Request a Core OpenGL 4.3 context. Sokol gfx detects the active GL context
	// automatically after sdl.GL_MakeCurrent — no extra wiring needed.
	sdl.GL_SetAttribute(.CONTEXT_MAJOR_VERSION, 4)
	sdl.GL_SetAttribute(.CONTEXT_MINOR_VERSION, 3)
	sdl.GL_SetAttribute(.CONTEXT_PROFILE_MASK, i32(sdl.GL_CONTEXT_PROFILE_CORE))

	window := sdl.CreateWindow("lui debug", 1000, 1000, {.RESIZABLE, .OPENGL})
	gl_ctx := sdl.GL_CreateContext(window)

	sdl.GL_MakeCurrent(window, gl_ctx)

	defer sdl.Quit()
	defer sdl.DestroyWindow(window)
	defer sdl.GL_DestroyContext(gl_ctx)

	// Sokol gfx setup must happen after GL context is current.
	// It inspects the active context to determine the backend and feature set.
	sgfx.setup({logger = {func = sglog.func}})

	// The sokol backend owns all GPU resources used by the UI:
	//   - An offscreen RGBA8 render target (backend_ctx.target) sized to the window.
	//   - Pipelines, shaders, and storage buffers for rect and text rendering.
	//   - A fontstash atlas texture for glyph rasterization.
	// init() allocates these at the given initial size; resize_target() handles window resizes.
	backend_ctx := sokol_backend.init(1000, 1000, 10)
	defer sokol_backend.deinit(&backend_ctx)

	// Fontstash callbacks (fs_render_resize, fs_render_update) receive a rawptr userData.
	// We point it at backend_ctx.font so the callbacks can reach the GPU atlas image.
	// This must be set after init() returns because init() copies font_ctx by value
	// into backend_ctx — setting it inside init() would capture a stack address.
	backend_ctx.font.fs_ctx.userData = &backend_ctx.font

	// The lui context drives layout, input handling, and render command emission.
	// It does not own any GPU resources itself — that is the backend's job.
	ctx := lui.init_context(0, 2048, context.allocator)
	ctp := &ctx
	defer lui.deinit_context(&ctx)

	// text_user_data is forwarded as the last argument to every measure_text_* callback.
	// We pass the font context so the callbacks can call into fontstash for metrics
	// without needing a global or a closure.
	ctx.text_user_data = &backend_ctx.font

	// Text measurement callbacks. lui calls these during layout to determine how much
	// space a text string occupies. They must be consistent with how the backend
	// renders text — both use fontstash with the same FontContext, so they agree.
	ctx.measure_text_width       = sokol_backend.measure_text_width
	ctx.measure_text_height      = sokol_backend.measure_text_height
	ctx.measure_text_hover_index = sokol_backend.measure_text_hover_index

	// double_click_timeout: maximum gap between two clicks to count as a double-click.
	// long_down_timeout: how long a button must be held before a long-press fires.
	// repeat_timeout: interval at which repeated events fire during a long-press (used by spinbox).
	ctx.mouse.double_click_timeout = time.Millisecond * 300
	ctx.mouse.long_down_timeout    = time.Millisecond * 1000
	ctx.mouse.repeat_timeout       = time.Millisecond * 200

	// AddFontPath loads the TTF/OTF file into fontstash and returns an integer ID.
	// Fontstash deduplicates by name, so loading the same name twice returns the same ID.
	// The ID is just an index into fontstash's internal font array.
	// Size is not baked into the ID — it is set per draw call via SetSize.
	font_id := sokol_backend.add_font(&backend_ctx, "Hermit", "./assets/Hermit.otf")

	// widgets.Font holds one Text_Style per size tier. Each style carries:
	//   font_id   — the fontstash font index used by the backend and measure callbacks.
	//   font      — rawptr to Font_Context, cast inside measure/render procs to reach the atlas.
	//   font_size — passed to fontstash.SetSize before measuring or rasterizing glyphs.
	font := widgets.Font{
    	f_xs = {font_id = font_id, font = &backend_ctx.font, font_size = 10},
    	f_sm = {font_id = font_id, font = &backend_ctx.font, font_size = 16},
    	f_md = {font_id = font_id, font = &backend_ctx.font, font_size = 20},
    	f_xl = {font_id = font_id, font = &backend_ctx.font, font_size = 24},
    	f_lg = {font_id = font_id, font = &backend_ctx.font, font_size = 30},
	}

	// widgets.state holds shared widget state (hover, focus, open dropdowns, etc.).
	// It is global within the widgets package and must be initialized before any
	// widget procedure is called.
	widgets.init_state()
	defer widgets.deinit_state()

	selected_palette := widgets.Default_Palette.Gruvbox_Light

	// The UI is rendered offscreen into backend_ctx.target (an RGBA8 sokol image).
	// To display it, we blit that texture onto the swapchain using a fullscreen quad.
	// The swap pipeline samples backend_ctx.target and writes it to the default framebuffer.
	// Alpha blending is enabled so transparent UI regions show whatever is drawn before the blit.
	swap_shader := sgfx.make_shader({
		vertex_func = {source = swap_vertex_source},
		fragment_func = {source = swap_frag_source},
		views = { 0 = {texture = { stage = .FRAGMENT, sample_type = .FLOAT, image_type = ._2D, multisampled = false }}},
		samplers = { 0 = {sampler_type = .FILTERING, stage = .FRAGMENT}},
		texture_sampler_pairs = { 0 = {glsl_name = "tex", sampler_slot = 0, view_slot = 0, stage = .FRAGMENT}},
	})

	// No depth test needed — this is a 2D fullscreen blit.
	// Blend state is set on the pipeline so premultiplied alpha from the UI target
	// composites correctly over whatever was drawn earlier in the same pass.
	swap_pipeline := sgfx.make_pipeline({
		shader = swap_shader,
		colors = {0 = {
			blend = {
				enabled          = true,
				dst_factor_rgb   = .ONE_MINUS_SRC_ALPHA,
				src_factor_rgb   = .ONE,
				dst_factor_alpha = .ONE_MINUS_SRC_ALPHA,
				src_factor_alpha = .ONE,
			},
		}},
	})

	// Nearest filtering keeps pixel-perfect UI text sharp.
	// Clamp prevents edge bleeding when the texture exactly fills NDC space.
	sampler := sgfx.make_sampler({min_filter = .NEAREST, mag_filter = .NEAREST, wrap_u = .CLAMP_TO_EDGE, wrap_v = .CLAMP_TO_EDGE})

	// swap_texture_view wraps backend_ctx.target so the swap pipeline can sample it.
	// It must be rebuilt whenever the target image is recreated on window resize.
	swap_texture_view := sgfx.make_view({texture = {image = backend_ctx.target}})
	swap_binding := sgfx.Bindings{
		samplers = {0 = sampler},
		views    = {0 = swap_texture_view},
	}

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

		    widgets.display_struct(ctp, "__theme_editor", "Theme", widgets.DEFAULT_PALETTES[selected_palette])
		    widgets.spinbox(ctp, "__text_spin_box", "Spin Box", &spinbox_value, -10, 10, 1)

			widgets.mouse_indicator(ctp, "__test_mouse_indicator", "Mouse Indicator")
			widgets.track_region(ctp, "__test_drag_region", "Drag", &dragval, reference, bounds)
			// inline_container container has no clip and can't be undocked.
		    // end_inline_container must be called inside the same if block.
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

				widgets.text_box(ctp, "__test_tex_box", "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, qluis nostrud exercitation ullamco laboris nisi ut aliqluip ex ea commodo consequat. Dluis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qlui officia deserunt mollit anim id est laborum.")
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

		// Rebuild the offscreen target and its view when the window size changes.
		// The view must be recreated because it holds a reference to the old image descriptor.
		if resize {
			sokol_backend.resize_target(&backend_ctx, i32(ctx.window_size.x), i32(ctx.window_size.y))
			sgfx.uninit_view(swap_texture_view)
			sgfx.init_view(swap_texture_view, {texture = {image = backend_ctx.target}})
		}

		// Consumes ctx.render_commands and draws them into backend_ctx.target.
		// Also uploads the fontstash atlas to the GPU if any new glyphs were rasterized this frame.
		sokol_backend.render(&ctx, &backend_ctx)

		// Open the swapchain pass and blit the UI target onto the screen.
		// load_action is LOAD so anything drawn before this pass (e.g. a 3D scene)
		// is preserved and the UI composites on top via alpha blending.
		sgfx.begin_pass({ action = {colors = {0 = {load_action = .CLEAR}}}, swapchain = { width = i32(ctx.window_size.x), height = i32(ctx.window_size.y)}})

		sgfx.apply_pipeline(swap_pipeline)
		sgfx.apply_bindings(swap_binding)
		sgfx.draw(0, 6, 1)

		sgfx.end_pass()

		// Submits all recorded sokol commands to the GPU for this frame.
		sgfx.commit()

		assert(sdl.GL_SwapWindow(window))
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
	@(static) down: struct {
		l, r, m: bool,
	}

	resized := false

	// Scroll is a per-frame value — reset it so a wheel event from a previous
	// frame does not carry over when no wheel event arrives this frame.
	ctx.mouse.scroll   = 0
	ctx.mouse.scroll_v = 0

	for sdl.PollEvent(&event) {
		#partial switch event.type {
		case .KEY_DOWN:
			if event.key.scancode == .ESCAPE {return false, false}
		case .QUIT:
			return false, false
		case .MOUSE_WHEEL:
			ctx.mouse.scroll_v = {event.wheel.x, event.wheel.y}
			ctx.mouse.scroll   = event.wheel.y
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
		case .WINDOW_RESIZED, .WINDOW_MAXIMIZED, .WINDOW_MINIMIZED, .WINDOW_RESTORED:
			resized = true
		}
	}

	// Inject continuous Down events for any button that is currently held.
	// lui uses Down to distinguish held state from the single-frame Pressed event.
	if down.l {ctx.mouse.mapped_events[.Left]   += {.Down}}
	if down.r {ctx.mouse.mapped_events[.Right]  += {.Down}}
	if down.m {ctx.mouse.mapped_events[.Middle] += {.Down}}

	ctx.mouse.old_position = ctx.mouse.position
	w_w, w_h: i32
	_ = sdl.GetMouseState(&ctx.mouse.position.x, &ctx.mouse.position.y)
	_ = sdl.GetWindowSize(window, &w_w, &w_h)
	ctx.mouse.delta  = ctx.mouse.position - ctx.mouse.old_position
	ctx.window_size  = {f32(w_w), f32(w_h)}
	return resized, true
}
