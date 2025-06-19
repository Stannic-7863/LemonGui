package main

import "core:hash"
import "core:time"

Vec2f32 :: [2]f32
Vec4f32 :: [4]f32 // for padding : top right bottom left | for corners : top left top right bottom right bottom left
Color :: [4]u8 // turn this into a union of : solid color, gradient + graident type 
Id :: distinct i64

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
// Support vertical text 
// Support overgrowing elements 


Core_Context :: struct {
	delta_time:                  f32,
	window_height, window_width: f32,
	hot_widget_id:               Id, //id, widget currently under mouse  
	active_widget_id:            Id, //id, widget currently being interacted with 
	current_parent:              ^Widget,
	mouse:                       Mouse_Context,
	text_lines:                  [dynamic]string,
	widgets:                     [dynamic]Widget,
	render_commands:             [dynamic]Render_Command,
	persistant_data:             map[Id]Persistant_Data, // widgets from last frame. Used to query events. Accessed by widget.id
	stacks:                      struct {
		reverse_post: [dynamic]^Widget,
		pre:          [dynamic]^Widget,
		temp:         [dynamic]^Widget,
	},
	text_measure_proc:           proc(text: string, style: Text_Style) -> f32,
}

Persistant_Data :: struct {
	events:                                           Widget_Events,
	in_progressive_hot_anim, in_decay_hot_anim:       bool,
	in_progressive_active_anim, in_decay_active_anim: bool,
	active_overrided:                                 bool,
	active_t, hot_t:                                  f32,
	size, position, prev_text_size:                   Vec2f32,
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
	z_index: int,
	type:    Render_Command_Type,
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
	padding:          [4]f32,
	child_gap:        f32,
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
	id:                    Id,
}

Widget :: struct {
	// Progressive animations : time var moves from 0 - 1 
	// Decay animations : time var moves from 1 - 0
	in_progressive_hot_anim, in_decay_hot_anim:               bool,
	in_progressive_active_anim, in_decay_active_anim:         bool,
	active_overrided:                                         bool,
	active_t, hot_t:                                          f32,
	size, position, text_size, text_position, prev_text_size: Vec2f32,
	text:                                                     string,
	lines:                                                    []string,
	node:                                                     Node,
	layout:                                                   Layout,
	floating:                                                 Floating,
	style, start, target:                                     Style,
	events, events_mask:                                      Widget_Events,
	z_index:                                                  int,
}

import "core:fmt"

init_core_context :: proc(widget_arr_backing_length: int) -> Core_Context {
	ctx := Core_Context{}
	ctx.text_lines = make([dynamic]string)
	ctx.widgets = make([dynamic]Widget, 0, widget_arr_backing_length)
	ctx.render_commands = make([dynamic]Render_Command, widget_arr_backing_length)
	ctx.stacks.temp = make([dynamic]^Widget, 0, widget_arr_backing_length)
	ctx.stacks.pre = make([dynamic]^Widget, 0, widget_arr_backing_length)
	ctx.stacks.reverse_post = make([dynamic]^Widget, 0, widget_arr_backing_length)
	ctx.persistant_data = make(map[Id]Persistant_Data)
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
	clear(&ctx.widgets)
	clear(&ctx.text_lines)
	clear(&ctx.render_commands)
	ctx.current_parent = nil
}

end_ui :: proc(ctx: ^Core_Context) {
	build_stacks(ctx)
	layout_sizing_pass(ctx)
	layout_positioning_pass(ctx)

	clear_map(&ctx.persistant_data)

	for &w in ctx.widgets {
		resolve_animations(&w)

		events: Widget_Events
		if w.node.id == ctx.hot_widget_id {
			events += {.Hovered}
		}

		if w.node.id == ctx.hot_widget_id && (w.node.id == ctx.active_widget_id || ctx.active_widget_id == 0) {
			events += resolve_events(ctx, &w)
		}

		events -= w.events_mask

		if (.Hovered in events && .Hovered not_in w.events) {
			if w.in_decay_active_anim {
				w.start = w.style
				w.hot_t = 0
				w.in_decay_active_anim = false
			}
		}

		// if detected a new active event or one of two active events was removed
		if w.in_progressive_active_anim && (events & Active_Widget_Events != w.events & Active_Widget_Events) {
			w.active_overrided = true
			w.start = w.style
		}

		if w.node.id == ctx.hot_widget_id {
			w.hot_t = clamp(w.hot_t + ctx.delta_time, 0, 1)
		} else {
			w.hot_t = clamp(w.hot_t - ctx.delta_time, 0, 1)
		}

		if w.node.id == ctx.active_widget_id {
			if w.active_overrided {
				w.start = w.style
				w.active_t = 0
				w.active_overrided = false
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
			size                       = w.size,
			position                   = w.position,
			prev_text_size             = w.prev_text_size,
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

create_widget :: proc(
	ctx: ^Core_Context,
	text: string = "",
	layout: Layout = {},
	floating: Floating = {},
	style: Style = {},
	events_mask: Widget_Events = {},
) -> ^Widget {
	append(&ctx.widgets, Widget{})
	w: ^Widget = &ctx.widgets[len(ctx.widgets) - 1]

	w^ = {} // zero out 

	w.text = text
	w.layout = layout
	w.target = style
	w.events_mask = events_mask
	w.floating = floating
	w.node.index = len(ctx.widgets) - 1
	w.node.parent = ctx.current_parent
	if w.floating != {} {
		w.z_index = cap(ctx.widgets)
	}

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

	w.node.id = cast(Id)hash.fnv64a(buffer[:])

	if val, ok := ctx.persistant_data[w.node.id]; ok {
		w.events = val.events
		w.hot_t = val.hot_t
		w.active_t = val.active_t
		w.prev_text_size = val.prev_text_size
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

resolve_animations :: proc(w: ^Widget) {
	is_interacted_hot: bool = .Hovered in w.events
	is_interacted_active: bool = w.events & Active_Widget_Events != {}
	was_interacted_hot: bool = w.in_progressive_hot_anim
	was_interacted_active: bool = w.in_progressive_active_anim

	// entering hot animation 
	if (is_interacted_hot) && !was_interacted_hot {
		w.in_decay_hot_anim = false
		w.in_progressive_hot_anim = true
		w.start = w.style
		w.hot_t = 0
	}

	// leaving hot animation 
	if was_interacted_hot && !(is_interacted_hot) {

		w.in_decay_hot_anim = true
		w.in_progressive_hot_anim = false
		w.start = w.style
		w.hot_t = 1
	}

	// entring active animation
	if !was_interacted_active && (is_interacted_active) {
		w.in_decay_active_anim = false
		w.in_progressive_active_anim = true
		w.start = w.style
		w.active_t = 0
	}

	// leaving active animation
	if was_interacted_active && !(is_interacted_active) {
		w.in_decay_active_anim = true
		w.in_progressive_active_anim = false
		w.start = w.style
		w.active_t = 1
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
