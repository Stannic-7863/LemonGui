package main

import "core:hash"
import "core:time"

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


// odinfmt: disable 
Vec2f32 :: [2]f32
Vec4f32 :: [4]f32 // for padding : top right bottom left | for corners : top left top right bottom right bottom left
Color   :: [4]u8 // turn this into a union of : solid color, gradient + graident type 
Id		:: distinct i64
// odinfmt: enable

Animation_States :: enum u8 {
	Hot_Progressive, // on detecting a new hot event 
	Hot_Decay, // on detecting previous hot event's death 
	Active_Progressive,
	Active_Decay,
	Active_Overrided,
}

Core_Context :: struct {
	stacks:                      struct {
		post_r: [dynamic]^Widget,
		pre:    [dynamic]^Widget,
		temp:   [dynamic]^Widget,
	},
	mouse:                       Mouse_Context,
	text_lines:                  [dynamic]string,
	widgets:                     [dynamic]Widget,
	render_commands:             [dynamic]Render_Command,
	persistant_data:             map[Id]Persistant_Data, // widgets from last frame. Used to query events. Accessed by widget.id
	hot_widget_id:               Id, //id, widget currently under mouse  
	active_widget_id:            Id, //id, widget currently being interacted with 
	current_parent:              ^Widget,
	text_measure_proc:           proc(text: string, style: Text_Style) -> f32,
	window_height, window_width: f32,
	delta_time:                  f32,
}

Persistant_Data :: struct {
	style, start:    Style,
	size, position:  Vec2f32,
	active_t, hot_t: f32,
	events:          Widget_Events,
	anim_state:      bit_set[Animation_States],
}

Mouse_Context :: struct {
	double_click_timeout: time.Duration,
	long_down_timeout:    time.Duration,
	last_left_click:      time.Time,
	last_right_click:     time.Time,
	left_down_start:      time.Time,
	right_down_start:     time.Time,
	old_position:         Vec2f32,
	position:             Vec2f32,
	delta:                Vec2f32,
	scroll_v:             Vec2f32,
	scroll:               f32,
	events:               bit_set[Mouse_Event],
}

Render_Command :: struct {
	type:    Render_Command_Type,
	z_index: int,
}

Render_Command_Type :: union {
	Command_Rect,
	Command_Text,
}

Command_Rect :: struct {
	border_radius:    Vec4f32,
	border_thickness: Vec4f32,
	size, position:   Vec2f32,
	color:            Color,
}

Command_Text :: struct {
	lines:       []string,
	position:    Vec2f32,
	font_size:   f32,
	spacing:     f32,
	line_height: f32,
	color:       Color,
}

Text_Style :: struct {
	font_id:     int,
	font_size:   f32,
	spacing:     f32,
	line_height: f32,
}

Style :: struct {
	border_radius:    Vec4f32,
	border_thickness: Vec4f32,
	color:            Color,
}

Word_Measure :: struct {
	text:          string,
	start_index:   int,
	spaces_before: i32,
	width:         f32,
}

Node :: struct {
	id:                    Id,
	next:                  ^Widget,
	prev:                  ^Widget,
	parent:                ^Widget,
	last_child:            ^Widget,
	first_child:           ^Widget,
	index, total_children: int,
}

Config :: union {
	Layout,
	Floating,
	Text,
}

Widget :: struct {
	config:               Config,
	node:                 Node,
	style, start, target: Style,
	expand:               [2]Expand,
	offset:               [2]Offset,
	_min:                 Vec2f32,
	size, position:       Vec2f32,
	_z_index:             int,
	active_t, hot_t:      f32,
	events, events_mask:  Widget_Events,
	anim_state:           bit_set[Animation_States],
	anchor:               Anchor,
}

init_core_context :: proc(widget_arr_backing_length: int) -> Core_Context {
	ctx := Core_Context{}
	ctx.text_lines = make([dynamic]string)
	ctx.widgets = make([dynamic]Widget, 0, widget_arr_backing_length)
	ctx.render_commands = make([dynamic]Render_Command, widget_arr_backing_length)
	ctx.stacks.temp = make([dynamic]^Widget, 0, widget_arr_backing_length)
	ctx.stacks.pre = make([dynamic]^Widget, 0, widget_arr_backing_length)
	ctx.stacks.post_r = make([dynamic]^Widget, 0, widget_arr_backing_length)
	ctx.persistant_data = make(map[Id]Persistant_Data)
	return ctx
}

deinit_core_context :: proc(ctx: ^Core_Context) {
	delete(ctx.widgets)
	delete(ctx.render_commands)
	delete(ctx.persistant_data)
	delete(ctx.stacks.temp)
	delete(ctx.stacks.pre)
	delete(ctx.stacks.post_r)
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
			if .Active_Decay in w.anim_state {
				w.start = w.style
				w.hot_t = 0
				w.anim_state -= {.Active_Decay}
			}
		}

		if .Active_Progressive in w.anim_state && (events & Active_Widget_Events != w.events & Active_Widget_Events) {
			w.anim_state += {.Active_Overrided}
			w.start = w.style
		}

		if w.node.id == ctx.hot_widget_id {
			w.hot_t = clamp(w.hot_t + ctx.delta_time, 0, 1)
		} else {
			w.hot_t = clamp(w.hot_t - ctx.delta_time, 0, 1)
		}

		if w.node.id == ctx.active_widget_id {
			if .Active_Overrided in w.anim_state {
				w.start = w.style
				w.active_t = 0
				w.anim_state -= {.Active_Overrided}
			}
			w.active_t = clamp(w.active_t + ctx.delta_time, 0, 1)
		} else {
			if .Active_Overrided in w.anim_state {
				w.start = w.style
				w.active_t = 1
				w.anim_state -= {.Active_Overrided}
			}
			w.active_t = clamp(w.active_t - ctx.delta_time, 0, 1)
		}

		ctx.persistant_data[w.node.id] = Persistant_Data {
			events     = events,
			start      = w.start,
			style      = w.style,
			hot_t      = w.hot_t,
			active_t   = w.active_t,
			size       = w.size,
			position   = w.position,
			anim_state = w.anim_state,
		}
	}

	ctx.mouse.events = {}
	ctx.mouse.old_position = ctx.mouse.position
	clear(&ctx.stacks.post_r)
	clear(&ctx.stacks.pre)
	clear(&ctx.stacks.temp)
}

_add_widget :: proc(ctx: ^Core_Context, widget: ^Widget) {
	if ctx.current_parent != nil {
		ctx.current_parent.node.total_children += 1

		if ctx.current_parent.node.first_child == nil {
			ctx.current_parent.node.first_child = widget
		}
		widget.node.prev = ctx.current_parent.node.last_child

		if ctx.current_parent.node.last_child != nil {
			ctx.current_parent.node.last_child.node.next = widget
		}
		ctx.current_parent.node.last_child = widget
	}
}

_generate_widget_hash :: proc(widget: ^Widget) {
	buffer: [size_of(int) * 4]byte
	offset: int
	temp: [size_of(int)]u8

	if widget.node.prev != nil {
		temp = transmute([size_of(int)]u8)widget.node.prev
		copy(buffer[offset:offset + size_of(int)], temp[:])
	}
	offset += size_of(int)

	if widget.node.parent != nil {
		temp = transmute([size_of(int)]u8)widget.node.parent
		copy(buffer[offset:offset + size_of(int)], temp[:])
	}
	offset += size_of(int)

	temp = transmute([size_of(int)]u8)widget.node.total_children
	copy(buffer[offset:offset + size_of(int)], temp[:])
	offset += size_of(int)

	temp = transmute([size_of(int)]u8)widget.node.index
	copy(buffer[offset:offset + size_of(int)], temp[:])
	offset += size_of(int)

	widget.node.id = cast(Id)hash.fnv64a(buffer[:])
}

_retrieve_persistant_data :: proc(persistant_data: map[Id]Persistant_Data, widget: ^Widget) -> bool {
	val := persistant_data[widget.node.id] or_return
	widget.events = val.events
	widget.hot_t = val.hot_t
	widget.active_t = val.active_t
	widget.start = val.start
	widget.style = val.style
	widget.anim_state = val.anim_state
	return true
}

create_widget :: proc(
	ctx: ^Core_Context,
	config: Config = nil,
	expand: [2]Expand = {},
	offset: [2]Offset = {},
	style: Style = {},
	events_mask: Widget_Events = {},
) -> ^Widget {

	if e, ok := config.(Text); (ok || config == nil) {
		return nil
	}

	append(&ctx.widgets, Widget{})
	w: ^Widget = &ctx.widgets[len(ctx.widgets) - 1]
	w^ = {} // zero out 

	w.config = config
	w.target = style
	w.offset = offset
	w.expand = expand
	w.events_mask = events_mask
	w.node.index = len(ctx.widgets) - 1
	w.node.parent = ctx.current_parent

	_add_widget(ctx, w)
	_generate_widget_hash(w)

	if !_retrieve_persistant_data(ctx.persistant_data, w) {
		w.style = style
	}

	return w
}

create_text :: proc(
	ctx: ^Core_Context,
	text: Text,
	expand: [2]Expand = {},
	offset: [2]Offset = {},
	style: Style = {},
	events_mask: Widget_Events = {},
) {
	append(&ctx.widgets, Widget{})
	w: ^Widget = &ctx.widgets[len(ctx.widgets) - 1]
	w^ = {} // zero out 

	w.config = text
	w.target = style
	w.offset = offset
	w.expand = expand
	w.events_mask = events_mask
	w.node.index = len(ctx.widgets) - 1
	w.node.parent = ctx.current_parent

	_add_widget(ctx, w)
	_generate_widget_hash(w)

	if !_retrieve_persistant_data(ctx.persistant_data, w) {
		w.style = style
	}
}

resolve_animations :: proc(w: ^Widget) {
	is_interacted_hot: bool = .Hovered in w.events
	is_interacted_active: bool = w.events & Active_Widget_Events != {}
	was_interacted_hot: bool = .Hot_Progressive in w.anim_state
	was_interacted_active: bool = .Active_Progressive in w.anim_state

	// entering hot animation 
	if (is_interacted_hot) && !was_interacted_hot {
		w.anim_state -= {.Hot_Decay}
		w.anim_state += {.Hot_Progressive}
		w.start = w.style
		w.hot_t = 0
	}

	// leaving hot animation 
	if was_interacted_hot && !(is_interacted_hot) {
		w.anim_state += {.Hot_Decay}
		w.anim_state -= {.Hot_Progressive}
		w.start = w.style
		w.hot_t = 1
	}

	// entring active animation
	if !was_interacted_active && (is_interacted_active) {
		w.anim_state -= {.Active_Decay}
		w.anim_state += {.Active_Progressive}
		w.start = w.style
		w.active_t = 0
	}

	// leaving active animation
	if was_interacted_active && !(is_interacted_active) {
		w.anim_state += {.Active_Decay}
		w.anim_state -= {.Active_Progressive}
		w.start = w.style
		w.active_t = 1
	}

	if .Active_Progressive in w.anim_state {
		lerp_style_progressive(w, w.active_t)
	} else if .Hot_Progressive in w.anim_state {
		lerp_style_progressive(w, w.hot_t)
	}

	if .Hot_Decay in w.anim_state {
		lerp_style_decaying(w, w.hot_t)
	} else if .Active_Decay in w.anim_state {
		lerp_style_decaying(w, w.active_t)
	}
}
