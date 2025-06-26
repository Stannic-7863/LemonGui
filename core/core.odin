package ui_core

import "core:fmt"
import "core:hash"
import "core:mem/virtual"
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


Vec2f32 :: [2]f32
Vec4f32 :: [4]f32 // for padding : top right bottom left | for corners : top left top right bottom right bottom left
Color :: [4]u8 // turn this into a union of : solid color, gradient + graident type 
Id :: distinct i64

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
	animation_hooks:             map[Id]Animation_Hook,
	hot_widget_id:               Id, //id, widget currently under mouse  
	active_widget_id:            Id, //id, widget currently being interacted with 
	current_parent:              ^Widget,
	text_measure_proc:           proc(text: string, style: Text_Style) -> f32,
	window_height, window_width: f32,
	delta_time:                  f32,
}


Persistant_Data :: struct {
	style:                Style,
	size, position, _min: Vec2f32,
	events:               Widget_Events,
	_anim_state:          bit_set[Animation_States],
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
	start:       int,
	end:         int,
	position:    Vec2f32,
	font_size:   f32,
	spacing:     f32,
	line_height: f32,
	color:       Color,
}

Word_Measure :: struct {
	text:          string,
	start_index:   int,
	spaces_before: i32,
	width:         f32,
}

Text_Style :: struct {
	font_id:        int,
	font_size:      f32,
	letter_spacing: f32,
	line_spacing:   f32,
}

Style :: struct {
	border_radius:    Vec4f32,
	border_thickness: Vec4f32,
	color:            Color,
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
	config:         Config,
	node:           Node,
	style:          Style,
	expand:         [2]Expand,
	offset:         [2]Offset,
	_min:           Vec2f32,
	size, position: Vec2f32,
	_z_index:       int,
	events:         Widget_Events,
}

init_core_context :: proc(widget_arr_backing_length: int) -> Core_Context {
	ctx := Core_Context{}
	ctx.text_lines = make([dynamic]string)
	ctx.widgets = make([dynamic]Widget, 0, widget_arr_backing_length)
	ctx.render_commands = make([dynamic]Render_Command)
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
	delete(ctx.animation_hooks)
}

// Returns false if widget has config type of text. Text widget cannot have children.
push_parent :: proc(ctx: ^Core_Context, widget: ^Widget) -> bool {
	_, ok := widget.config.(Text)
	(!ok) or_return
	ctx.current_parent = widget
	return true
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
	_build_stacks(ctx)
	_layout_sizing_pass(ctx)
	_layout_positioning_pass(ctx)

	clear_map(&ctx.persistant_data)

	_resolve_animation_hooks(ctx)

	for &w in ctx.widgets {
		// _resolve_animations(&w)

		events: Widget_Events
		if w.node.id == ctx.hot_widget_id {
			events += {.Hovered}
		}

		if w.node.id == ctx.hot_widget_id && (w.node.id == ctx.active_widget_id || ctx.active_widget_id == 0) {
			events += _resolve_events(ctx, &w)
		}

		ctx.persistant_data[w.node.id] = Persistant_Data {
			events   = events,
			style    = w.style,
			size     = w.size,
			position = w.position,
			_min     = w._min,
		}
	}

	ctx.mouse.events = {}
	ctx.mouse.old_position = ctx.mouse.position
	clear(&ctx.stacks.post_r)
	clear(&ctx.stacks.pre)
	clear(&ctx.stacks.temp)
}

create_widget :: proc(ctx: ^Core_Context, config: Config = nil, expand: [2]Expand = {}, offset: [2]Offset = {}, style: Style = {}) -> ^Widget {

	append(&ctx.widgets, Widget{})
	w: ^Widget = &ctx.widgets[len(ctx.widgets) - 1]
	w^ = {} // zero out
	w.config = config
	w.offset = offset
	w.expand = expand
	w.node.parent = ctx.current_parent
	w._z_index = len(ctx.widgets) - 1
	w.node.index = len(ctx.widgets) - 1

	_add_widget(ctx, w)
	_generate_widget_hash(w)

	if !_retrieve_persistant_data(ctx.persistant_data, w) {
		w.style = style
	}

	return w
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
	widget.position = val.position
	widget.size = val.size
	widget.events = val.events
	widget.style = val.style

	if _, ok := widget.config.(Text); ok {
		widget._min = val._min
	}

	return true
}
