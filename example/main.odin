package example

import "core:mem"
import "core:reflect"
import "core:fmt"
import "core:time"

import lui "../"

import widgets "widgets"

import sdl "vendor:sdl3"
import sokol_backend "../backend/sokol"
import sgfx "../backend/sokol/sokol-odin/sokol/gfx"
import sglog "../backend/sokol/sokol-odin/sokol/log"

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
    Npc
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
	Onion
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
	when ODIN_DEBUG {
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
	}

	assert(sdl.Init({.VIDEO}))

	sdl.GL_SetAttribute(.CONTEXT_MAJOR_VERSION, 4)
	sdl.GL_SetAttribute(.CONTEXT_MINOR_VERSION, 3)
	sdl.GL_SetAttribute(.CONTEXT_PROFILE_MASK, i32(sdl.GL_CONTEXT_PROFILE_CORE))

	window := sdl.CreateWindow("lui debug", 1000, 1000, {.RESIZABLE, .OPENGL})
	gl_ctx := sdl.GL_CreateContext(window)

	sdl.GL_MakeCurrent(window, gl_ctx)

	defer sdl.Quit()
	defer sdl.DestroyWindow(window)
	defer sdl.GL_DestroyContext(gl_ctx)

	sgfx.setup({logger = {func = sglog.func}})

	sdl.SetLogPriorities(.VERBOSE)
	assert(sdl.Init({.VIDEO}))

	defer {
		sdl.DestroyWindow(window)
		sdl.Quit()
	}

	backend_ctx := sokol_backend.init(1000, 1000, 10)
	defer sokol_backend.deinit(&backend_ctx)
	backend_ctx.font.fs_ctx.userData = &backend_ctx.font

	ctx := lui.init_context(0, 2048, context.allocator)
	ctp := &ctx
	defer lui.deinit_context(&ctx)

	ctx.text_user_data = &backend_ctx.font

	ctx.measure_text_width = sokol_backend.measure_text_width
	ctx.measure_text_height = sokol_backend.measure_text_height
	ctx.measure_text_hover_index = sokol_backend.measure_text_hover_index

	ctx.mouse.double_click_timeout = time.Millisecond * 300
	ctx.mouse.long_down_timeout = time.Millisecond * 1000
	ctx.mouse.repeat_timeout = time.Millisecond * 200

	font_id := sokol_backend.add_font(&backend_ctx, "Hermit", "./assets/Hermit.otf")

	font := widgets.Font{
    	f_xs = {font_id = font_id, font = &backend_ctx.font, font_size = 10},
    	f_sm = {font_id = font_id, font = &backend_ctx.font, font_size = 16},
    	f_md = {font_id = font_id, font = &backend_ctx.font, font_size = 20},
    	f_xl = {font_id = font_id, font = &backend_ctx.font, font_size = 24},
    	f_lg = {font_id = font_id, font = &backend_ctx.font, font_size = 30},
	}

	widgets.init_state()
	defer widgets.deinit_state()

	selected_palette := widgets.Default_Palette.Gruvbox_Light

	swap_shader := sgfx.make_shader({
		vertex_func = {source = swap_vertex_source},
		fragment_func = {source = swap_frag_source},
		views = { 0 = {texture = { stage = .FRAGMENT, sample_type = .FLOAT, image_type = ._2D, multisampled = false }}},
		samplers = { 0 = {sampler_type = .FILTERING, stage = .FRAGMENT}},
		texture_sampler_pairs = { 0 = {glsl_name = "tex", sampler_slot = 0, view_slot = 0, stage = .FRAGMENT}}
	})

	swap_pipeline := sgfx.make_pipeline({ shader = swap_shader })

	sampler := sgfx.make_sampler({min_filter = .NEAREST, mag_filter = .NEAREST, wrap_u = .CLAMP_TO_EDGE, wrap_v = .CLAMP_TO_EDGE})

	swap_texture_view := sgfx.make_view({texture = {image = backend_ctx.target}})
	swap_binding := sgfx.Bindings{
		samplers = {0 = sampler},
		views = {0 = swap_texture_view}
	}

	for resize in handle_events(ctp, window) {
		defer free_all(context.temp_allocator)
		lui.begin(ctp)
		widgets.build_theme(ctp, widgets.DEFAULT_PALETTES[selected_palette], widgets.DEFAULT_SPACING, font)

		{
			root := lui.reserve_widget(ctp, "__root")
			rootf := lui.Form{}
			rootf.layout.sizing = lui.sizing(lui.fixed(ctp.window_size.x), lui.fixed(ctp.window_size.y))
			rootf.layout.direction = .Y
			lui.submit_widget(ctp, root, rootf)
			lui.push_parent(ctp, root)
		}


		@static slider_val := f32(0.0)
		@static checkbox_bool := false
		if widgets.container(ctp, "__test_container", "Text Container") {

		    widgets.display_struct(ctp, "__theme_editor", "Theme", widgets.DEFAULT_PALETTES[selected_palette])
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

		lui.end(ctp)

		if resize {
			sokol_backend.resize_target(&backend_ctx, i32(ctx.window_size.x), i32(ctx.window_size.y))
			sgfx.uninit_view(swap_texture_view)
			sgfx.init_view(swap_texture_view, {texture = {image = backend_ctx.target}})
		}

		sokol_backend.render(&ctx, &backend_ctx)

		sgfx.begin_pass({ action = backend_ctx.action, swapchain = { width = i32(ctx.window_size.x), height = i32(ctx.window_size.y)}})

		sgfx.apply_pipeline(swap_pipeline)
		sgfx.apply_bindings(swap_binding)
		sgfx.draw(0, 6, 1)

		sgfx.end_pass()

		sgfx.commit()

		assert(sdl.GL_SwapWindow(window))

		free_all(context.temp_allocator)
	}
}

handle_events :: proc(ctx: ^lui.Core_Context, window: ^sdl.Window) -> (bool, bool) {
	event: sdl.Event
	@(static) down: struct {
		l, r, m: bool,
	}

	resized := false
	ctx.mouse.scroll = 0
	ctx.mouse.scroll_v = 0
	for sdl.PollEvent(&event) {
		#partial switch event.type {
		case .KEY_DOWN:
			if event.key.scancode == .ESCAPE {return false, false}
		case .QUIT:
			return false, false
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
		case .WINDOW_RESIZED, .WINDOW_MAXIMIZED, .WINDOW_MINIMIZED, .WINDOW_RESTORED:
			resized = true
		}
	}

	if down.l {ctx.mouse.mapped_events[.Left] += {.Down}}
	if down.r {ctx.mouse.mapped_events[.Right] += {.Down}}
	if down.m {ctx.mouse.mapped_events[.Middle] += {.Down}}

	ctx.mouse.old_position = ctx.mouse.position
	w_w, w_h: i32
	_ = sdl.GetMouseState(&ctx.mouse.position.x, &ctx.mouse.position.y)
	_ = sdl.GetWindowSize(window, &w_w, &w_h)
	ctx.mouse.delta = ctx.mouse.position - ctx.mouse.old_position
	ctx.window_size = {f32(w_w), f32(w_h)}
	return resized, true
}
