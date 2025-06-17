package main

import "core:fmt"
import "core:hash"
import "core:time"

import rl "vendor:raylib"

Vec2f32 :: [2]f32
Vec4f32 :: [4]f32 // for padding : top right bottom left | for corners : top left top right bottom right bottom left
Color :: [4]u8 // turn this into a union of : solid color, gradient + graident type 

WHITE :: Color{255, 255, 255, 255}
BLACK :: Color{0, 0, 0, 255}
GREEN :: Color{0, 255, 0, 255}
BLUE :: Color{0, 0, 255, 255}
RED :: Color{255, 0, 0, 255}
DEFAULT_BACKGROUND :: [4]u8{30, 30, 46, 255} // #1E1E2E
CHILD_BACKGROUND :: [4]u8{42, 42, 64, 255} // #2A2A40
HOVER_COLOR :: [4]u8{58, 58, 90, 255} // #3A3A5A
LONG_PRESS_COLOR :: [4]u8{255, 136, 170, 255} // #FF88AA
PRESS_COLOR :: [4]u8{136, 221, 255, 255} // #88DDFF

/*
during frame : 

create_widget() 
|_ create a widget with specified style and params 
|_ give it persistent data stored last frame
|_ (POSSIBLY, NOT YET HERE) resolve styles based on events

at frame end :

emit_render_commands()
|_ Build the reverse post-order and pre-order stacks for tree traversal of widgets 
|_ Sizing pass 
   |_ fixed_sizing() -> fit_x() -> grow_x() -> text_wrap() -> fit_y() -> grow_y()
|_ Positioning pass 
   |_ Position elements 
   |_ Clamp style variables to maximums or minimums
   |_ Determine element under mouse (ctx.hot_widget) 
   |_ append to ctx.render_commands one or more (box, box + text etc) render commands
|_ Clear out persistent Data 
|_ Store this frames Data 
   |_ Gather events
   |_ Progress (t + deltatime) or decay (t - deltatime) animation timers (hot_t, active_t)
   |_ Resolve_Style + Resolve_animations (resolve style will be moved out to be user's headache, 
      it lags behind two frames here since its using last frame events)
   |_ Place persistent data like animation timers and events into persistent_data hash map keyed by widget.node.id 
render_frame()
*/

// API
// Main Task : Collapse feature flags into Layout, Layout styling, styling  [DONE]
// Keyboard Interface directly from core. Add helpers to map events. Add focus events or focus state  
// Errors for the primitive functions 

// LAYOUT 
// Support clipping rects 
// Support max size constraint [WIP]
// Support for floating elements 
// Support for free elements that are rendered on top of everything else. Position set by user
// Support for justify and related layout styling options 
// Support vertical text 
// Support overgrowing elements 

Core_Context :: struct {
	delta_time:                  f32,
	window_height, window_width: f32,
	hot_widget_id:               uint, //id, widget currently under mouse  
	active_widget_id:            uint, //id, widget currently being interacted with 
	current_parent:              ^Widget,
	last_widget:                 ^Widget,
	mouse:                       Mouse_Context,
	text_lines:                  [dynamic]string,
	widgets:                     [dynamic]Widget,
	render_commands:             [dynamic]Render_Command,
	persistant_data:             map[uint]Persistant_Data, // widgets from last frame. Used to query events. Accessed by widget.id
	stacks:                      struct {
		reverse_post: [dynamic]^Widget,
		pre:          [dynamic]^Widget,
		temp:         [dynamic]^Widget,
	},
	text_measure_proc:           proc(text: string, style: Text_Style) -> f32,
}

Persistant_Data :: struct {
	in_progressive_hot_anim, in_decay_hot_anim:       bool,
	in_progressive_active_anim, in_decay_active_anim: bool,
	active_overrided:                                 bool,
	events:                                           Widget_Events,
	active_t, hot_t:                                  f32,
	style, start:                                     Style,
}

Mouse_Context :: struct {
	scroll:               f32,
	scroll_v:             Vec2f32,
	position:             Vec2f32,
	old_position:         Vec2f32,
	last_left_click:      time.Time,
	last_right_click:     time.Time,
	left_down_start:      time.Time,
	right_down_start:     time.Time,
	long_down_timeout:    time.Duration,
	double_click_timeout: time.Duration,
	events:               bit_set[Mouse_Event],
}

Render_Command :: struct {
	type: Render_Command_Type,
}

Render_Command_Type :: union {
	Command_Rect,
	Command_Text,
}

Command_Rect :: struct {
	size, position:   Vec2f32,
	border_radius:    Vec4f32,
	border_thickness: Vec4f32,
	color:            Color,
}

Command_Text :: struct {
	position:    Vec2f32,
	font_size:   f32,
	spacing:     f32,
	line_height: f32,
	color:       Color,
	lines:       []string,
}

Layout_Style :: struct {
	padding:   [4]f32,
	child_gap: f32,
}

Text_Style :: struct {
	font_id:     int,
	font_size:   f32,
	spacing:     f32,
	line_height: f32,
}

Style :: struct {
	color:            Color,
	border_radius:    Vec4f32,
	border_thickness: Vec4f32,
	text:             Text_Style,
	layout:           Layout_Style,
}

Word_Measure :: struct {
	text:          string,
	width:         f32,
	spaces_before: i32,
	start_index:   int,
}

Node :: struct {
	next:                  ^Widget,
	prev:                  ^Widget,
	parent:                ^Widget,
	last_child:            ^Widget,
	first_child:           ^Widget,
	index, total_children: int,
	id:                    uint,
}

Widget :: struct {
	in_progressive_hot_anim, in_decay_hot_anim:       bool,
	in_progressive_active_anim, in_decay_active_anim: bool,
	active_overrided:                                 bool,
	active_t, hot_t:                                  f32,
	size, position, text_size, text_position:         Vec2f32,
	text:                                             string,
	lines:                                            []string,
	node:                                             Node,
	layout:                                           Layout,
	style, start, target:                             Style,
	events, events_mask:                              Widget_Events,
}

init_core_context :: proc(widget_arr_backing_length: int) -> Core_Context {
	ctx := Core_Context{}
	ctx.text_lines = make([dynamic]string)
	ctx.widgets = make([dynamic]Widget, widget_arr_backing_length)
	ctx.render_commands = make([dynamic]Render_Command, widget_arr_backing_length)
	ctx.stacks.temp = make([dynamic]^Widget, 0, widget_arr_backing_length)
	ctx.stacks.pre = make([dynamic]^Widget, 0, widget_arr_backing_length)
	ctx.stacks.reverse_post = make([dynamic]^Widget, 0, widget_arr_backing_length)
	ctx.persistant_data = make(map[uint]Persistant_Data)
	return ctx
}

deinit_core_context :: proc(ctx: ^Core_Context) {
	delete(ctx.widgets)
	delete(ctx.render_commands)
	delete(ctx.persistant_data)
	delete(ctx.stacks.temp)
	delete(ctx.stacks.pre)
	delete(ctx.stacks.reverse_post)
	delete(ctx.text_lines)
}

push_parent :: proc(ctx: ^Core_Context, widget: ^Widget) {
	ctx.current_parent = widget
}

pop_parent :: proc(ctx: ^Core_Context) {
	ctx.current_parent = ctx.current_parent.node.parent
}

begin_ui :: proc(ctx: ^Core_Context) {
	clear(&ctx.render_commands)
	clear(&ctx.widgets)
	clear(&ctx.text_lines)
}

end_ui :: proc(ctx: ^Core_Context) {
	ctx.current_parent = nil
	ctx.last_widget = nil

	build_stacks(ctx)
	layout_sizing_pass(ctx)
	layout_positioning_pass(ctx)

	clear_map(&ctx.persistant_data)

	for &w in ctx.widgets {
		events: Widget_Events

		if w.node.id == ctx.hot_widget_id {
			events += {.Hovered}
		}

		if w.node.id == ctx.hot_widget_id && (w.node.id == ctx.active_widget_id || ctx.active_widget_id == 0) {
			events += resolve_events(ctx, &w)
		}

		events -= w.events_mask

		if w.node.id == ctx.hot_widget_id {
			w.hot_t = clamp(w.hot_t + ctx.delta_time, 0, 1)
		} else {
			w.hot_t = clamp(w.hot_t - ctx.delta_time, 0, 1)
		}

		if w.node.id == ctx.active_widget_id {
			if w.events & Active_Widget_Events != events & Active_Widget_Events && events & Active_Widget_Events != {} && w.active_t != 0 {
				w.active_t = 0
				w.active_overrided = true
				w.start = w.style
			}
			w.active_t = clamp(w.active_t + ctx.delta_time, 0, 1)
		} else {
			if w.active_overrided {
				w.start = w.style
				w.active_t = 1
				w.active_overrided = false
			}
			w.active_t = clamp(w.active_t - ctx.delta_time, 0, 1)
		}


		ctx.persistant_data[w.node.id] = Persistant_Data {
			events                     = events,
			start                      = w.start,
			style                      = w.style,
			hot_t                      = w.hot_t,
			active_t                   = w.active_t,
			in_progressive_hot_anim    = w.in_progressive_hot_anim,
			in_decay_hot_anim          = w.in_decay_hot_anim,
			in_progressive_active_anim = w.in_progressive_active_anim,
			in_decay_active_anim       = w.in_decay_active_anim,
			active_overrided           = w.active_overrided,
		}
	}

	ctx.mouse.events = {}
	clear(&ctx.stacks.reverse_post)
	clear(&ctx.stacks.pre)
	clear(&ctx.stacks.temp)
}

create_widget :: proc(ctx: ^Core_Context, text: string, layout: Layout, style: Style, events_mask: Widget_Events = {}) -> ^Widget {
	append(&ctx.widgets, Widget{})
	w: ^Widget = &ctx.widgets[len(ctx.widgets) - 1]

	w^ = {} // zero out 

	w.text = text
	w.layout = layout
	w.target = style
	w.events_mask = events_mask

	w.node.index = len(ctx.widgets) - 1
	w.node.parent = ctx.current_parent

	if ctx.current_parent != nil {
		ctx.current_parent.node.total_children += 1

		if ctx.current_parent.node.first_child == nil {
			ctx.current_parent.node.first_child = w
		}
		w.node.prev = ctx.current_parent.node.last_child

		if ctx.current_parent.node.last_child != nil {
			ctx.current_parent.node.last_child.node.next = w
		}

		ctx.current_parent.node.last_child = w
	}


	buffer: [size_of(int) * 4]byte
	offset: int
	temp: [size_of(int)]u8

	if w.node.prev != nil {
		temp = transmute([size_of(int)]u8)w.node.prev
		copy(buffer[offset:offset + size_of(int)], temp[:])
	}
	offset += size_of(int)

	if w.node.parent != nil {
		temp = transmute([size_of(int)]u8)w.node.parent
		copy(buffer[offset:offset + size_of(int)], temp[:])
	}
	offset += size_of(int)

	temp = transmute([size_of(int)]u8)w.node.total_children
	copy(buffer[offset:offset + size_of(int)], temp[:])
	offset += size_of(int)

	temp = transmute([size_of(int)]u8)w.node.index
	copy(buffer[offset:offset + size_of(int)], temp[:])
	offset += size_of(int)

	w.node.id = cast(uint)hash.fnv64a(buffer[:])

	if val, ok := ctx.persistant_data[w.node.id]; ok {
		w.events = val.events
		w.hot_t = val.hot_t
		w.active_t = val.active_t
		w.start = val.start
		w.style = val.style
		w.in_decay_hot_anim = val.in_decay_hot_anim
		w.in_progressive_hot_anim = val.in_progressive_hot_anim
		w.in_decay_active_anim = val.in_decay_active_anim
		w.in_progressive_active_anim = val.in_progressive_active_anim
		w.active_overrided = val.active_overrided
	} else {
		w.style = style
	}

	return w
}

main :: proc() {
	rl.SetConfigFlags({.WINDOW_RESIZABLE})
	rl.InitWindow(700, 700, "Balls?")
	defer rl.CloseWindow()

	ctx := init_core_context(32)
	ctx.mouse.double_click_timeout = time.Millisecond * 300
	ctx.mouse.long_down_timeout = time.Millisecond * 1000

	ctx.text_measure_proc = measure_text

	defer delete(ctx.persistant_data)
	defer delete(ctx.render_commands)
	defer delete(ctx.widgets)

	sdf_shader := rl.LoadShader("", "./sdf_rect_shader.frag")

	img := rl.GenImageColor(1, 1, rl.WHITE)
	render_texture := rl.LoadTextureFromImage(img)
	rl.UnloadImage(img)
	defer rl.UnloadTexture(render_texture)

	rl.SetTargetFPS(60)

	x_align: Child_Alignment_X
	y_align: Child_Alignment_Y
	direc: Direction
	for !rl.WindowShouldClose() {
		ctx.window_width = cast(f32)rl.GetScreenWidth()
		ctx.window_height = cast(f32)rl.GetScreenHeight()
		ctx.delta_time = rl.GetFrameTime()

		defer free_all(context.temp_allocator)
		begin_ui(&ctx)

		if rl.IsMouseButtonDown(.LEFT) {ctx.mouse.events += {.Left_Down}}
		if rl.IsMouseButtonDown(.RIGHT) {ctx.mouse.events += {.Right_Down}}
		if rl.IsMouseButtonDown(.MIDDLE) {ctx.mouse.events += {.Middle_Down}}
		if rl.IsMouseButtonPressed(.LEFT) {ctx.mouse.events += {.Left_Pressed}}
		if rl.IsMouseButtonPressed(.RIGHT) {ctx.mouse.events += {.Right_Pressed}}
		if rl.IsMouseButtonPressed(.MIDDLE) {ctx.mouse.events += {.Middle_Pressed}}
		if rl.IsMouseButtonReleased(.LEFT) {ctx.mouse.events += {.Left_Released}}
		if rl.IsMouseButtonReleased(.RIGHT) {ctx.mouse.events += {.Right_Released}}
		if rl.IsMouseButtonReleased(.MIDDLE) {ctx.mouse.events += {.Middle_Released}}

		ctx.mouse.old_position = ctx.mouse.position
		ctx.mouse.position = rl.GetMousePosition()

		style := Style {
			color = DEFAULT_BACKGROUND,
			border_radius = {20, 10, 20, 10},
			text = {font_size = 20, spacing = 2, line_height = 20},
			layout = {padding = 32, child_gap = 16},
		}

		root := create_widget(
			&ctx,
			"",
			{sizing = {fixed(ctx.window_width), fixed(ctx.window_height)}, direction = .Row},
			style = {layout = {child_gap = 16, padding = 16}},
			events_mask = ~{},
		)
		push_parent(&ctx, root)

		w_1 := create_widget(&ctx, "", {sizing = {fixed(50), fixed(50)}}, style)
		w_2 := create_widget(
			&ctx,
			"A quick brown fox jumps over the lazy dog",
			{sizing = {grow(), grow()}, direction = .Row, child_alignment = {x = .Right}},
			style,
		)
		resolve_styling(w_2)
		resolve_animations(w_2)

		{
			push_parent(&ctx, w_2)
			defer pop_parent(&ctx)
			style.color = CHILD_BACKGROUND
			w_21 := create_widget(&ctx, "", {sizing = {fixed(50), fixed(50)}}, style)
			w_22 := create_widget(&ctx, "", {sizing = {fixed(50), fixed(50)}}, style)
			w_23 := create_widget(&ctx, "", {sizing = {percent(0.5), percent(0.5)}}, style)
		}

		style.color = DEFAULT_BACKGROUND


		if rl.IsKeyPressed(.UP) {
			y_align = .Top
		}
		if rl.IsKeyPressed(.DOWN) {
			y_align = .Bottom
		}
		if rl.IsKeyPressed(.LEFT) {
			x_align = .Left
		}
		if rl.IsKeyPressed(.RIGHT) {
			x_align = .Right
		}
		if rl.IsKeyPressed(.KP_1) {
			x_align = .Center
		}
		if rl.IsKeyPressed(.KP_2) {
			y_align = .Center
		}

		if rl.IsKeyPressed(.R) {
			direc = .Row
		}
		if rl.IsKeyPressed(.C) {
			direc = .Colom
		}

		w_3 := create_widget(
			&ctx,
			"A quick brown fox does not jump over the lazy dog",
			{sizing = {grow(), grow()}, direction = direc, child_alignment = {x = x_align, y = y_align}},
			style,
		)
		{
			push_parent(&ctx, w_3)
			defer pop_parent(&ctx)
			style.color = CHILD_BACKGROUND
			w_31 := create_widget(&ctx, "", {sizing = {fit(), fit()}, direction = .Row}, style)
			{
				push_parent(&ctx, w_31)
				defer pop_parent(&ctx)
				style.color = DEFAULT_BACKGROUND
				w_31_1 := create_widget(&ctx, "", {sizing = {grow(50, 50), fixed(50)}}, style)
				w_31_2 := create_widget(&ctx, "", {sizing = {grow(50, 50), grow(50, 50)}}, style)
			}
			style.color = CHILD_BACKGROUND
			w_32 := create_widget(&ctx, "", {sizing = {percent(0.5), percent(0.5)}}, style)
		}

		style.color = DEFAULT_BACKGROUND
		w_4 := create_widget(&ctx, "", {sizing = {grow(50, 50), grow(50, 50)}}, style)

		end_ui(&ctx)

		rl.BeginDrawing()
		rl.ClearBackground(cast(rl.Color)CHILD_BACKGROUND)
		render(ctx, render_texture, sdf_shader)
		rl.EndDrawing()
	}
}

resolve_styling :: proc(widget: ^Widget) {
	if .Hovered in widget.events {
		widget.target.color = HOVER_COLOR
		widget.target.border_radius = {100, 10, 100, 10}
	}

	if .Left_Down in widget.events {
		widget.target.color = PRESS_COLOR
		widget.target.border_radius = {10, 100, 10, 100}
		widget.target.text.font_size = 10
	}

	if .Long_Left_Down in widget.events {
		widget.target.color = LONG_PRESS_COLOR
		widget.target.border_radius = {50, 50, 50, 50}
	}
}

resolve_animations :: proc(w: ^Widget) {
	is_interacted_hot: bool = .Hovered in w.events
	is_interacted_active: bool = w.events & Active_Widget_Events != {}

	if !w.in_progressive_hot_anim && (is_interacted_hot) {
		w.in_decay_hot_anim = false
		w.in_progressive_hot_anim = true
		w.start = w.style
	}
	if w.in_progressive_hot_anim && !(is_interacted_hot) {
		w.in_decay_hot_anim = true
		w.in_progressive_hot_anim = false
		w.start = w.style
	}

	if !w.in_progressive_active_anim && (is_interacted_active) {
		w.in_decay_active_anim = false
		w.in_progressive_active_anim = true
		w.start = w.style
	}
	if w.in_progressive_active_anim && !(is_interacted_active) {
		w.in_decay_active_anim = true
		w.in_progressive_active_anim = false
		w.start = w.style
	}

	if w.hot_t < 0.001 {
		w.in_decay_hot_anim = false
		w.in_progressive_hot_anim = false
	}
	if w.active_t < 0.001 {
		w.in_decay_active_anim = false
		w.in_progressive_active_anim = false
		w.active_overrided = false
	}

	if w.in_progressive_active_anim {
		lerp_style_progressive(w, w.active_t)
	} else if w.in_progressive_hot_anim {
		lerp_style_progressive(w, w.hot_t)
	}

	if w.in_decay_hot_anim {
		lerp_style_decaying(w, w.hot_t)
	} else if w.in_decay_active_anim {
		lerp_style_decaying(w, w.active_t)
	}
}

render :: proc(ctx: Core_Context, texture: rl.Texture, shader: rl.Shader) {
	rect_center_loc := rl.GetShaderLocation(shader, "rect_center")
	rect_size_loc := rl.GetShaderLocation(shader, "rect_size")
	border_radius_loc := rl.GetShaderLocation(shader, "border_radius")
	color_loc := rl.GetShaderLocation(shader, "color")

	for cmd in ctx.render_commands {
		switch v in cmd.type {
		case Command_Rect:
			size := v.size / 2
			pos := v.position + size
			rad := v.border_radius
			color: [4]f32
			for c, i in v.color {
				color[i] = f32(c) / 255
			}

			rl.BeginShaderMode(shader)
			rl.SetShaderValue(shader, rect_center_loc, &pos, .VEC2)
			rl.SetShaderValue(shader, rect_size_loc, &size, .VEC2)
			rl.SetShaderValue(shader, border_radius_loc, &rad, .VEC4)
			rl.SetShaderValue(shader, color_loc, &color, .VEC4)

			src := rl.Rectangle{0, 0, 1, 1}
			dst := rl.Rectangle{v.position.x, v.position.y, v.size.x, v.size.y}

			rl.DrawTexturePro(texture, src, dst, {}, 0.0, rl.WHITE)
			rl.EndShaderMode()
		case Command_Text:
			initial_y := v.position.y

			for l in v.lines {
				rl.DrawTextEx(
					rl.GetFontDefault(),
					fmt.ctprint(l),
					{v.position.x, initial_y},
					v.font_size,
					v.spacing,
					cast(rl.Color)v.color,
				)
				// width := rl.MeasureTextEx(rl.GetFontDefault(), fmt.ctprint(l), v.font_size, v.spacing)
				// rl.DrawRectangleLinesEx({v.position.x, initial_y, width.x, width.y}, 2, rl.WHITE)
				initial_y += v.line_height
			}

		}
	}

	// for cmd in ctx.render_commands {
	// 	switch v in cmd.type {
	// 	case Command_Rect:
	// 		rl.DrawRectangleV(v.position, v.size, cast(rl.Color)v.color)
	// 	}
	// }
}

measure_text :: proc(text: string, config: Text_Style) -> f32 {
	width: f32
	font := rl.GetFontDefault()
	scale := config.font_size / f32(font.baseSize)
	for r in text {
		advance: f32
		glyph_index := rl.GetGlyphIndex(font, r)
		glyph := font.glyphs[glyph_index]

		if glyph.advanceX != 0 {
			advance = f32(glyph.advanceX) * scale + config.spacing
		} else {
			advance = font.recs[glyph_index].width * scale + f32(glyph.offsetX) + config.spacing
		}
		width += advance
	}
	return width
}
