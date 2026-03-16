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

all_anim := ui.Animation_Index(0)
color_anim := ui.Animation_Index(0)

Tab :: enum {
	Sizing,
	Borders,
	Text,
	Layout,
	Clips,
	Interaction,
	Animation,
	Performance,
}

Perf_Info :: struct {
	frame_time:        time.Duration,
	layout_time:       time.Duration,
	sizing_time:       time.Duration,
	word_wrap_time:    time.Duration,
	positioning_time:  time.Duration,
	sizing_fit_time:   [2]time.Duration,
	sizing_other_time: [2]time.Duration,
}

Perf_State :: struct {
	sample_tick: time.Duration,
	samples:     [1000]Perf_Info,
	sample_i:    int,
	tick:        time.Duration,
	record:      [60]Perf_Info,
	record_i:    int,
}

// Styles bundled so perf_chart doesn't need 6 style params every call
Perf_Chart_Styles :: struct {
	bg, bar, bar_hover, tooltip, col_a, col_b: ui.Style_Index,
}

perf_state_update :: proc(ps: ^Perf_State, timers: ui.Timers) {
	ps.tick += timers.frame_time
	ps.sample_tick += timers.frame_time

	if ps.sample_tick > time.Millisecond * 16 {
		ps.sample_tick = 0
		ps.samples[ps.sample_i] = {
			frame_time        = timers.frame_time,
			layout_time       = timers.layout_time,
			sizing_time       = timers.sizing_time,
			word_wrap_time    = timers.word_wrap_time,
			sizing_fit_time   = timers.sizing_fit_time,
			positioning_time  = timers.positioning_time,
			sizing_other_time = timers.sizing_other_time,
		}
		ps.sample_i = (ps.sample_i + 1) % len(ps.samples)
	}

	if ps.tick > time.Millisecond * 500 {
		ps.tick = 0
		n := time.Duration(max(ps.sample_i, 1))
		acc := Perf_Info{}
		for s in ps.samples[:ps.sample_i] {
			acc.frame_time += s.frame_time
			acc.layout_time += s.layout_time
			acc.sizing_time += s.sizing_time
			acc.word_wrap_time += s.word_wrap_time
			acc.sizing_fit_time += s.sizing_fit_time
			acc.positioning_time += s.positioning_time
			acc.sizing_other_time += s.sizing_other_time
		}
		ps.record[ps.record_i] = {
			frame_time        = acc.frame_time / n,
			layout_time       = acc.layout_time / n,
			sizing_time       = acc.sizing_time / n,
			word_wrap_time    = acc.word_wrap_time / n,
			sizing_fit_time   = acc.sizing_fit_time / n,
			positioning_time  = acc.positioning_time / n,
			sizing_other_time = acc.sizing_other_time / n,
		}
		ps.record_i = (ps.record_i + 1) % len(ps.record)
		ps.sample_i = 0
	}
}

container :: proc(
	ctp: ^ui.Core_Context,
	id: ui.Key,
	style: ui.Style_Index,
	direction := ui.Axis.Y,
	placement := [2]ui.Placement{.Negative, .Negative},
	clip := bit_set[ui.Axis]{},
) {
	cont := ui.reserve_widget(ctp, id)
	contf := ui.Form{}
	contf.layout.sizing = ui.sizing(ui.grow(), ui.grow())
	contf.layout.padding = PAD_S
	contf.layout.child_gap = GAP_S
	contf.layout.placement = placement
	contf.layout.direction = direction
	contf.style = style
	x := ui.clip_auto(50) if .X in clip else ui.clip_none()
	y := ui.clip_auto(50) if .Y in clip else ui.clip_none()
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
	colf.layout.direction = .Y
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

stat_label :: proc(ctp: ^ui.Core_Context, id: ui.Key, text: string, style: ui.Style_Index) {
	w := ui.reserve_widget(ctp, id)
	f := ui.Form{}
	f.layout.sizing = ui.sizing(ui.fit(), ui.fit())
	f.layout.padding = PAD_S
	f.style = style
	f.text = ui.create_text(ctp, ui.text(text, .None))
	ui.submit_widget(ctp, w, f)
}

bar_widget :: proc(ctp: ^ui.Core_Context, id: ui.Key, sty: Perf_Chart_Styles, rec, m: time.Duration, label: string) {
	b := ui.reserve_widget(ctp, id)
	bf := ui.Form{}
	bf.layout.sizing = ui.sizing(ui.grow(), ui.percent(f32(rec) / f32(m)))
	bf.style = ui.is_widget_hovered(ctp, b) ? sty.bar_hover : sty.bar
	bf.animation = all_anim
	ui.submit_widget(ctp, b, bf)

	if ui.is_widget_hovered(ctp, b) {
		t := ui.reserve_widget(ctp, "tooltip")
		tf := ui.Form{}
		tf.z_offset = 1000
		tf.layout.sizing = ui.sizing(ui.fit(), ui.fit())
		tf.layout.padding = PAD
		tf.layout.flags = ui.Layout_Flags{.No_Positioning, .No_Size_Propagation, .No_Clip_Offset}
		tf.style = sty.tooltip
		tf.animation = all_anim
		tf.text = ui.create_text(ctp, ui.text(fmt.tprint(label, ": ", rec), .None))
		ofs := [2]ui.Override_Transform{ui.fixed(b.rect.position.x + b.rect.size.x * 0.5 - t.rect.size.x * 0.5 + b.rect.scroll_offset.x), ui.fixed(b.rect.position.y + b.rect.size.y + 20 + b.rect.scroll_offset.y)}
		tf.override = ui.create_override(ctp, {offset = ofs})
		ui.submit_widget(ctp, t, tf)
	}
}

perf_chart :: proc(ctp: ^ui.Core_Context, sty: Perf_Chart_Styles, record: []Perf_Info, record_i: int, label: string, id: string, get: proc(p: Perf_Info) -> time.Duration) {
	min_v := get(record[0])
	max_v := get(record[0])
	sum := time.Duration(0)
	for i in 0 ..< len(record) {
		v := get(record[(record_i + i) % len(record)])
		min_v = min(min_v, v)
		max_v = max(max_v, v)
		sum += v
	}
	avg := sum / time.Duration(len(record))

	// outer row: stats column + chart side by side
	row(ctp, id, sty.bg, {.Negative, .Positive}, 256)

	column(ctp, fmt.tprint(id, "stats col"), sty.bg)
	stat_label(ctp, fmt.tprint(id, "title"), label, sty.tooltip)
	stat_label(ctp, fmt.tprint(id, "min"), fmt.tprint("min: ", min_v), sty.tooltip)
	stat_label(ctp, fmt.tprint(id, "max"), fmt.tprint("max: ", max_v), sty.tooltip)
	stat_label(ctp, fmt.tprint(id, "avg"), fmt.tprint("avg: ", avg), sty.tooltip)
	ui.pop_parent(ctp)

	row(ctp, fmt.tprint(id, "bars"), sty.bg, {.Negative, .Positive}, 256)
	for i in 0 ..< len(record) {
		key := (record_i + i) % len(record)
		bar_widget(ctp, i, sty, get(record[key]), max_v, label)
	}
	ui.pop_parent(ctp)

	ui.pop_parent(ctp)
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

	ctx := ui.init_context(0)
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

	selected_tab := Tab.Performance
	perf := Perf_State{}

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

		s_root := ui.create_style(ctp, {color = BG, border = nb(), text = {font = font_13, color = FG, font_size = 13}})
		s_card := ui.create_style(ctp, {color = BG_1, border = br(BORDER), text = {font = font_13, color = FG, font_size = 13}})
		s_card_2 := ui.create_style(ctp, {color = BG_2, border = br(BORDER, 8), text = {font = font_13, color = FG, font_size = 13}})
		s_card_3 := ui.create_style(ctp, {color = BG_3, border = br(BORDER, 8), text = {font = font_13, color = FG, font_size = 13}})
		s_inset := ui.create_style(ctp, {color = BG_2, border = br(BORDER, 6), text = {font = font_12, color = FG_DIM, font_size = 12}})
		s_inset2 := ui.create_style(ctp, {color = BG_3, border = br(BORDER, 4), text = {font = font_12, color = FG_DIM, font_size = 12}})
		s_dim := ui.create_style(ctp, {color = BG_1, border = nb(), text = {font = font_12, color = FG_DIM, font_size = 12}})
		s_xdim := ui.create_style(ctp, {color = BG_1, border = br(BORDER, 12), text = {font = font_11, color = FG_XDIM, font_size = 11}})
		s_tab_on := ui.create_style(ctp, {color = CYAN, border = pill(CYAN_D, CYAN_D), text = {font = font_12, color = BG, font_size = 12}})
		s_tab_off := ui.create_style(ctp, {color = BG_2, border = pill(BORDER, BG_3), text = {font = font_12, color = FG_DIM, font_size = 12}})
		s_colors := []ui.Style_Index {
			ui.create_style(ctp, {color = CYAN, border = nb(), text = {font = font_12, color = BG, font_size = 12}}),
			ui.create_style(ctp, {color = AMBER, border = nb(), text = {font = font_12, color = BG, font_size = 12}}),
			ui.create_style(ctp, {color = PURPLE, border = nb(), text = {font = font_12, color = BG, font_size = 12}}),
			ui.create_style(ctp, {color = GREEN, border = nb(), text = {font = font_12, color = BG, font_size = 12}}),
			ui.create_style(ctp, {color = PINK, border = nb(), text = {font = font_12, color = BG, font_size = 12}}),
			ui.create_style(ctp, {color = RED, border = nb(), text = {font = font_12, color = BG, font_size = 12}}),
		}

		all_anim = ui.create_animation(ctp, ui.ANIM_ALL, time.Millisecond * 250)
		color_anim = ui.create_animation(ctp, ui.ANIM_COLOR, time.Millisecond * 250)

		perf_sty := Perf_Chart_Styles {
			bg        = s_card_2,
			bar       = s_colors[1],
			bar_hover = s_colors[0],
			tooltip   = s_card_3,
			col_a     = s_colors[0],
			col_b     = s_colors[1],
		}

		// root
		{
			root := ui.reserve_widget(ctp, "root")
			rootf := ui.Form{}
			rootf.layout.sizing = ui.sizing(ui.fixed(ctp.window_size.x), ui.fixed(ctp.window_size.y))
			rootf.layout.direction = .Y
			rootf.style = s_root
			ui.submit_widget(ctp, root, rootf)
			ui.push_parent(ctp, root)
		}

		// tab bar
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
			if .Clicked in ui.get_widget_mouse_events(ctp, tw, .Left) {
				selected_tab = t
			}
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
		case .Performance:
			container(ctp, "perf container", s_card, .Y, clip = {.Y})
			pc :: proc(ctp: ^ui.Core_Context, sty: Perf_Chart_Styles, ps: ^Perf_State, label, id: string, get: proc(_: Perf_Info) -> time.Duration) {
				perf_chart(ctp, sty, ps.record[:], ps.record_i, label, id, get)
			}
			pc(ctp, perf_sty, &perf, "Frame time", "frame_time", proc(p: Perf_Info) -> time.Duration {return p.frame_time})
			pc(ctp, perf_sty, &perf, "Layout time", "layout_time", proc(p: Perf_Info) -> time.Duration {return p.layout_time})
			pc(ctp, perf_sty, &perf, "Sizing time", "sizing_time", proc(p: Perf_Info) -> time.Duration {return p.sizing_time})
			pc(ctp, perf_sty, &perf, "Sizing fit X", "sizing_fit_x", proc(p: Perf_Info) -> time.Duration {return p.sizing_fit_time.x})
			pc(ctp, perf_sty, &perf, "Sizing fit Y", "sizing_fit_y", proc(p: Perf_Info) -> time.Duration {return p.sizing_fit_time.y})
			pc(ctp, perf_sty, &perf, "Word wrap time", "word_wrap_time", proc(p: Perf_Info) -> time.Duration {return p.word_wrap_time})
			pc(ctp, perf_sty, &perf, "Sizing other X", "sizing_other_x", proc(p: Perf_Info) -> time.Duration {return p.sizing_other_time.x})
			pc(ctp, perf_sty, &perf, "Sizing other Y", "sizing_other_y", proc(p: Perf_Info) -> time.Duration {return p.sizing_other_time.y})
			pc(ctp, perf_sty, &perf, "Positioning time", "positioning_time", proc(p: Perf_Info) -> time.Duration {return p.positioning_time})
			ui.pop_parent(ctp)
		}

		ui.pop_parent(ctp)
		ui.end(ctp)

		perf_state_update(&perf, ctp.timers)
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
