package main

import "core:fmt"
import "core:reflect"
import "core:time"

import ui "../"
import sdl_backend "backend/sdl_gpu"
import sdl "vendor:sdl3"

BG :: ui.Color{11, 12, 16, 255}
BG_1 :: ui.Color{17, 19, 26, 255}
BG_2 :: ui.Color{25, 28, 38, 255}
BG_3 :: ui.Color{35, 39, 54, 255}
BG_4 :: ui.Color{46, 52, 72, 255}
FG :: ui.Color{218, 222, 240, 255}
FG_DIM :: ui.Color{95, 102, 130, 255}
FG_XDIM :: ui.Color{48, 54, 72, 255}
CYAN :: ui.Color{45, 215, 195, 255}
CYAN_D :: ui.Color{18, 90, 80, 255}
PURPLE :: ui.Color{155, 95, 255, 255}
PURPLE_D :: ui.Color{65, 35, 145, 255}
GREEN :: ui.Color{55, 205, 115, 255}
GREEN_D :: ui.Color{18, 90, 45, 255}
AMBER :: ui.Color{255, 185, 50, 255}
AMBER_D :: ui.Color{130, 85, 8, 255}
RED :: ui.Color{245, 75, 90, 255}
RED_D :: ui.Color{125, 25, 35, 255}
PINK :: ui.Color{255, 95, 175, 255}
PINK_D :: ui.Color{130, 30, 80, 255}
BORDER :: ui.Color{40, 44, 64, 255}

PAD :: f32(14)
PAD_S :: f32(8)
PAD_XS :: f32(4)
R :: f32(10)
GAP_S :: f32(8)


s_root := ui.Style_Index(0)
s_card := ui.Style_Index(0)
s_card_2 := ui.Style_Index(0)
s_card_3 := ui.Style_Index(0)
s_inset := ui.Style_Index(0)
s_inset2 := ui.Style_Index(0)
s_dim := ui.Style_Index(0)
s_xdim := ui.Style_Index(0)
s_tab_on := ui.Style_Index(0)
s_tab_off := ui.Style_Index(0)
s_rect_green := ui.Style_Index(0)
all_anim := ui.Animation_Index(0)
color_anim := ui.Animation_Index(0)
s_colors := []ui.Style_Index{}

Tab :: enum {
	Sizing,
	Borders,
	Text,
	Layout,
	Clips,
	Interaction,
	Animation,
}

container :: proc(ctp: ^ui.Core_Context, id: ui.Key, style: ui.Style_Index, direction := ui.Axis.Y, placement := [2]ui.Placement{.Negative, .Negative}, clip := bit_set[ui.Axis]{}) {
	cont := ui.reserve_widget(ctp, id)
	contf := ui.Form{}
	contf.layout.sizing = ui.sizing(ui.grow(), ui.grow())
	contf.layout.padding = PAD_S
	contf.layout.child_gap = GAP_S
	contf.layout.placement = placement
	contf.layout.direction = direction
	contf.style = style
	x, y := ui.clip_auto(20) if .X in clip else ui.clip_none(), ui.clip_auto(20) if .Y in clip else ui.clip_none()
	contf.clip = ui.create_clip(ctp, ui.clip(x, y, cont.hash))
	contf.animation = all_anim
	ui.submit_widget(ctp, cont, contf)
	ui.push_parent(ctp, cont)
}

row :: proc(ctp: ^ui.Core_Context, id: ui.Key, style: ui.Style_Index, placement := [2]ui.Placement{.Negative, .Negative}, min_height := f32(0)) {
	r := ui.reserve_widget(ctp, id)
	rf := ui.Form{}
	rf.layout.sizing = ui.sizing(ui.grow(), ui.fit(min_height))
	rf.layout.padding = PAD_S
	rf.layout.child_gap = GAP_S
	rf.layout.placement = placement
	rf.style = style
	rf.animation = all_anim
	ui.submit_widget(ctp, r, rf)
	ui.push_parent(ctp, r)
}

column :: proc(ctp: ^ui.Core_Context, id: ui.Key, style: ui.Style_Index, placement := [2]ui.Placement{.Negative, .Negative}, min_width := f32(0)) {
	col := ui.reserve_widget(ctp, id)
	colf := ui.Form{}
	colf.layout.sizing = ui.sizing(ui.fit(min_width), ui.grow())
	colf.layout.padding = PAD_S
	colf.layout.child_gap = GAP_S
	colf.layout.placement = placement
	colf.style = style
	colf.animation = all_anim
	ui.submit_widget(ctp, col, colf)
	ui.push_parent(ctp, col)
}

spacer :: proc(ctp: ^ui.Core_Context, id: ui.Key, direction: ui.Axis) {
	col := ui.reserve_widget(ctp, id)
	colf := ui.Form{}
	colf.layout.sizing = direction == .X ? ui.sizing(ui.grow(), ui.fixed(0)) : ui.sizing(ui.fixed(0), ui.grow())
	ui.submit_widget(ctp, col, colf)
}

label :: proc(ctp: ^ui.Core_Context, id: ui.Key, text: string, style: ui.Style_Index) {
	l := ui.reserve_widget(ctp, id)
	lf := ui.Form{}
	lf.layout.sizing = ui.sizing()
	lf.layout.padding = PAD_S
	lf.animation = all_anim
	lf.style = style
	lf.text = ui.create_text(ctp, ui.text(text, .None))
	ui.submit_widget(ctp, l, lf)
}

main :: proc() {
	backend_ctx := sdl_backend.init(
		"ui debug",
		"./backend/sdl_gpu/shaders/compiled/main.vert.sprv",
		"./backend/sdl_gpu/shaders/compiled/main.frag.sprv",
		"./backend/sdl_gpu/shaders/compiled/stencil.vert.sprv",
		"./backend/sdl_gpu/shaders/compiled/stencil.frag.sprv",
	)
	defer sdl_backend.de_init(&backend_ctx)

	ctx := ui.init_context(8192)
	ctp := &ctx
	defer ui.deinit_context(&ctx)

	ctx.measure_text_width = sdl_backend.measure_text_width
	ctx.measure_text_height = sdl_backend.measure_text_height
	ctx.mouse.double_click_timeout = time.Millisecond * 300
	ctx.mouse.long_down_timeout = time.Millisecond * 1000

	sdl_backend.init_font(&backend_ctx)
	font_11 := sdl_backend.add_font(&backend_ctx, "./assets/JetBrainsMono-Regular.ttf", 12)
	font_12 := sdl_backend.add_font(&backend_ctx, "./assets/JetBrainsMono-Regular.ttf", 13)
	font_13 := sdl_backend.add_font(&backend_ctx, "./assets/JetBrainsMono-Regular.ttf", 14)
	font_14 := sdl_backend.add_font(&backend_ctx, "./assets/JetBrainsMono-Regular.ttf", 15)
	font_16 := sdl_backend.add_font(&backend_ctx, "./assets/JetBrainsMono-Regular.ttf", 16)
	font_20 := sdl_backend.add_font(&backend_ctx, "./assets/JetBrainsMono-Regular.ttf", 20)
	font_28 := sdl_backend.add_font(&backend_ctx, "./assets/JetBrainsMono-Regular.ttf", 28)
	font_40 := sdl_backend.add_font(&backend_ctx, "./assets/JetBrainsMono-Regular.ttf", 40)
	defer sdl_backend.de_init_font(&backend_ctx)

	selected_tab := Tab.Layout

	anim_conts := [dynamic]struct {
		id:    int,
		conts: [dynamic]int,
	}{}
	gen := int(0)
	gen_2 := int(0)

	for handle_events(ctp, &backend_ctx) {
		defer free_all(context.temp_allocator)
		ui.begin(ctp)

		nb :: proc() -> ui.Border_Style {return {}}
		br :: proc(c: ui.Color, r: f32 = R) -> ui.Border_Style {
			return {color = c, thickness = {{1, 1}, {1, 1}}, radius = {r, r, r, r}}
		}
		br_t :: proc(c: ui.Color, top, right, bottom, left: f32, r: f32 = R) -> ui.Border_Style {
			return {color = c, thickness = {{top, bottom}, {left, right}}, radius = {r, r, r, r}}
		}
		br_asym :: proc(tl, tr, br_c, bl: ui.Color, top, right, bottom, left: f32, r: f32 = 0) -> ui.Border_Style {
			return {color = {tl, tr, br_c, bl}, thickness = {{top, bottom}, {left, right}}, radius = {r, r, r, r}}
		}
		pill :: proc(c: ui.Color, cd: ui.Color) -> ui.Border_Style {
			return {color = {c, cd, cd, c}, thickness = {{1, 2}, {1, 2}}, radius = {99, 99, 99, 99}}
		}

		// ── Common styles ──────────────────────────────────────────────────────
		s_root = ui.create_style(ctp, {color = BG, border = nb(), text = {font = font_13, color = FG, font_size = 13}})
		s_card = ui.create_style(ctp, {color = BG_1, border = br(BORDER), text = {font = font_13, color = FG, font_size = 13}})
		s_card_2 = ui.create_style(ctp, {color = BG_2, border = br(BORDER, 8), text = {font = font_13, color = FG, font_size = 13}})
		s_card_3 = ui.create_style(ctp, {color = BG_3, border = br(BORDER, 8), text = {font = font_13, color = FG, font_size = 13}})
		s_inset = ui.create_style(ctp, {color = BG_2, border = br(BORDER, 6), text = {font = font_12, color = FG_DIM, font_size = 12}})
		s_inset2 = ui.create_style(ctp, {color = BG_3, border = br(BORDER, 4), text = {font = font_12, color = FG_DIM, font_size = 12}})
		s_dim = ui.create_style(ctp, {color = BG_1, border = nb(), text = {font = font_12, color = FG_DIM, font_size = 12}})
		s_xdim = ui.create_style(ctp, {color = BG_1, border = br(BORDER, 12), text = {font = font_11, color = FG_XDIM, font_size = 11}})
		s_tab_on = ui.create_style(ctp, {color = CYAN, border = pill(CYAN_D, CYAN_D), text = {font = font_12, color = BG, font_size = 12}})
		s_tab_off = ui.create_style(ctp, {color = BG_2, border = pill(BORDER, BG_3), text = {font = font_12, color = FG_DIM, font_size = 12}})
		s_rect_green = ui.create_style(ctp, {color = GREEN, border = nb(), text = {}})
		s_colors = []ui.Style_Index {
			ui.create_style(ctp, {color = CYAN, border = nb(), text = {}}),
			ui.create_style(ctp, {color = AMBER, border = nb(), text = {}}),
			ui.create_style(ctp, {color = PURPLE, border = nb(), text = {}}),
			ui.create_style(ctp, {color = GREEN, border = nb(), text = {}}),
			ui.create_style(ctp, {color = PINK, border = nb(), text = {}}),
			ui.create_style(ctp, {color = RED, border = nb(), text = {}}),
		}

		all_anim = ui.create_animation(ctp, ui.ANIM_ALL, time.Millisecond * 300)
		color_anim = ui.create_animation(ctp, ui.ANIM_COLOR, time.Millisecond * 300)

		{
			root := ui.reserve_widget(ctp, "root")
			rootf := ui.Form{}
			rootf.layout.sizing = ui.sizing(ui.fixed(ctp.window_size.x), ui.fixed(ctp.window_size.y))
			rootf.layout.direction = .Y
			rootf.style = s_root
			ui.submit_widget(ctp, root, rootf)
			ui.push_parent(ctp, root)
		}

		row(ctp, "main tab row", s_card, {.Negative, .Center}, 32)
		label(ctp, "main title", "LemonGui", s_inset)
		spacer(ctp, "spacer", .X)
		for t, i in Tab {
			tw := ui.reserve_widget(ctp, i)
			twf := ui.Form{}
			twf.layout.sizing = ui.sizing()
			twf.layout.padding = PAD_S
			twf.animation = all_anim
			twf.layout.placement = {.Center, .Center}
			twf.text = ui.create_text(ctp, ui.text(reflect.enum_string(t), .None))
			twf.style = t == selected_tab ? s_tab_on : s_tab_off
			ui.submit_widget(ctp, tw, twf)
			events := ui.get_widget_mouse_events(ctp, tw, .Left)
			selected_tab = .Clicked in events ? t : selected_tab
		}
		ui.pop_parent(ctp)

		switch selected_tab {
		case .Sizing:
		case .Borders:
		case .Text:
		case .Layout:
		case .Clips:
			row(ctp, "clip row", s_card, min_height = 256)
			container(ctp, "scroll x 1", s_card_2, .X, clip = {.X})
			for s, i in s_colors {
				w := ui.reserve_widget(ctp, i)
				wf := ui.Form{}
				wf.layout.sizing = ui.sizing(ui.fixed(100), ui.grow())
				wf.animation = all_anim
				wf.style = s
				ui.submit_widget(ctp, w, wf)
			}
			ui.pop_parent(ctp)

			container(ctp, "scroll x 2", s_card_2, .X, clip = {.X})
			for s, i in s_colors {
				w := ui.reserve_widget(ctp, i)
				wf := ui.Form{}
				wf.layout.sizing = ui.sizing(ui.fixed(100), ui.grow())
				wf.animation = all_anim
				wf.style = s
				ui.submit_widget(ctp, w, wf)
			}
			ui.pop_parent(ctp)

			ui.pop_parent(ctp)
		case .Interaction:
		case .Animation:
		}

		ui.pop_parent(ctp)
		ui.end(ctp)
		sdl_backend.render(&backend_ctx, &ctx)
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
