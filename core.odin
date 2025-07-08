package ui_core

import "core:fmt"
import "core:hash"
import "core:image"
import "core:math"
import "core:math/linalg"
import "core:time"

/*
during frame : 

create_widget() 
|_ create a widget with specified style and params 
|_ provide it persistant data 
|_ query events and do stuff

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
|_ Clear out previous frames data and store this frames data 
   |_ Gather events
   |_ Resolve Animations Hooks 
   |_ Store Persistant Data 
render_frame()
*/

/*
TODOS 

API:
	Errors
	Remove the passing of widget pointers. Move to index perhaps? 

LAYOUT: 
	Support Wrap_Children element perhaps. Wrap_Children will overwrite any layout config of children to confine them into a min max contraint ??? 
	Support vertical text. Also Text wrapping flags
	Support clipping rects (Clipping Done) 
	Support max size constraint [WIP] (Almost Done)
	Support for floating elements (Done)
	Support for free elements that are rendered on top of everything else. Position set by user (Funcationality provided by Offset{})
	Support overgrowing elements (Comes naturally with clipping :O)
*/

Vec2f32 :: [2]f32
/*
   Padding order : Top, right, bottom, left (Layout depends on this order)
   border radius order : top left corner, top right corner, bottom right corner, bottom left corner (Layout does not depend on this order)
*/
Vec4f32 :: [4]f32
Color :: [4]u8 // TODO: Turn this into a gradient type 
Id :: distinct i64

// TODO: Error handling 
when ODIN_DEBUG {
	Core_Errors :: enum u8 {
		No_Parent_To_Bind_Primitive,
		Image_Provided_With_No_Aspect_Ratio,
	}
}

Core_Context :: struct {
	stacks:                      struct {
		post_r: [dynamic]^Widget,
		pre:    [dynamic]^Widget,
		temp:   [dynamic]^Widget,
	},
	mouse:                       Mouse_Context,
	widgets:                     [dynamic]Widget,
	text_lines:                  [dynamic]string,
	render_commands:             [dynamic]Render_Command,
	primitives:                  [dynamic]Command_Primitive,
	clips:                       [dynamic]^Widget,
	persistant_data:             map[Id]Persistant_Data, // widgets from last frame. Used to query events. Accessed by widget.id
	hot_widget_id:               Id, // widget currently under mouse  
	active_widget_id:            Id, // widget currently being interacted with 
	active_clipper:              ^Widget,
	active_parent:               ^Widget,
	text_measure_proc:           proc(text: string, style: Text_Style) -> f32,
	window_height, window_width: f32,
	delta_time:                  f32,
}

// Data that persists each frame 
Persistant_Data :: struct {
	size, position, accumulated_min: Vec2f32,
	events:                          Widget_Events,
}

Border_Type :: enum u8 {
	None,
	Single,
	Double,
	Dotted,
	Dashed,
	Grooved,
	Inset,
	Outset,
}

Render_Command :: struct {
	type:    Render_Command_Type,
	z_index: int,
}

Render_Command_Type :: union {
	Command_Rect,
	Command_Text,
	Command_Border,
	Command_Clip_End,
	Command_Clip_Start,
	Command_Primitive,
	Command_Image,
	Command_Custom,
}

Command_Custom :: struct {
	position: Vec2f32,
	data:     rawptr,
}

Command_Image :: struct {
	position:   Vec2f32,
	size:       Vec2f32,
	color:      Color,
	image_data: rawptr,
}

Command_Border :: struct {
	radius:    Vec4f32,
	thickness: Vec4f32,
	position:  Vec2f32,
	size:      Vec2f32,
	color:     [4]Color,
	type:      [4]Border_Type,
}

Command_Rect :: struct {
	border_radius:  Vec4f32,
	size, position: Vec2f32,
	color:          Color,
}

Command_Text :: struct {
	start, end: int, // usage : ctx.lines[start:end] 
	position:   Vec2f32,
	style:      Text_Style,
}

Command_Clip_Start :: struct {
	clip_position: Vec2f32,
	clip_size:     Vec2f32,
}

Command_Clip_End :: struct {}

// Primitives are added to command list as they are. With out any changes
Command_Primitive :: union {
	Primitive_Line,
	Primitive_Rect,
	Primitive_Points,
	Primitive_Ellipse,
	Primitive_Custom,
}

// Thickness fields in primitives used by line mode
Primitive_Fill_Mode :: enum {
	Solid,
	Line,
}

Primitive_Custom :: struct {
	custom_primitive_data: rawptr,
}

Primitive_Ellipse :: struct {
	position:  Vec2f32,
	size:      Vec2f32, // interpretation upto renderer
	color:     Color,
	thickness: f32,
	fill:      Primitive_Fill_Mode,
}

Primitive_Rect :: struct {
	position:  Vec2f32,
	size:      Vec2f32,
	color:     Color,
	thickness: f32,
	fill:      Primitive_Fill_Mode,
}

Primitive_Points :: struct {
	points:    []Vec2f32,
	color:     Color,
	thickness: f32,
	fill:      Primitive_Fill_Mode,
}

Primitive_Line :: struct {
	start_position, end_position: Vec2f32,
	thickness:                    f32,
	color:                        Color,
}

// TODO: Make it consistant. Text style exists in Text while other styles here.
Style :: struct {
	border:  Maybe(Border_Style),
	padding: Vec4f32,
	color:   Color,
}

Border_Style :: struct {
	radius:    Vec4f32,
	thickness: Vec4f32,
	color:     [4]Color,
	type:      [4]Border_Type,
}

Text_Style :: struct {
	color:          Color,
	font_id:        int,
	font_size:      f32,
	letter_spacing: f32,
	line_spacing:   f32,
}

Node :: struct {
	id:                                             Id,
	next:                                           ^Widget,
	prev:                                           ^Widget,
	parent:                                         ^Widget,
	last_child:                                     ^Widget,
	first_child:                                    ^Widget,
	index, total_children, total_floating_children: int,
}

Floating :: struct {
	layout:          Layout,
	id:              Id, // Used if Attachment_To == .Id 
	parent, element: Anchor,
	attachment_to:   Attachment_To,
}

Layout :: struct {
	sizing:          [Axis]Sizing,
	child_gap:       f32,
	child_alignment: Child_Alignment,
	direction:       Axis,
}

Text :: struct {
	style:        Text_Style,
	text:         string,
	_start, _end: int, // index into ctx.text_lines
}

Image :: struct {
	image_data: rawptr,
	tint:       Color,
}

Clip :: struct {
	direction: bit_set[Axis],
	value:     [Axis]f32,
}

Widget_Type :: union {
	Layout,
	Floating,
	Text,
}

Widget :: struct {
	style:                  Style,
	type:                   Widget_Type,
	node:                   Node,
	expand:                 [2]Expand,
	offset:                 [2]Offset,
	image:                  Maybe(Image),
	primitives:             []Command_Primitive,
	string_id:              string,
	clip:                   Maybe(Clip),
	accumulated_min:        Vec2f32,
	size, position:         Vec2f32,
	custom_data:            Maybe(rawptr),
	z_index:                int,
	aspect_ratio:           Maybe(f32),
	is_floating_descendant: bool,
	event_passthrough:      bool,
	events:                 Widget_Events,
}

init_core_context :: proc(widget_arr_backing_length: int) -> Core_Context {
	ctx := Core_Context{}
	ctx.text_lines = make([dynamic]string)
	ctx.widgets = make([dynamic]Widget, 0, widget_arr_backing_length)
	ctx.render_commands = make([dynamic]Render_Command)
	ctx.stacks.temp = make([dynamic]^Widget, 0, widget_arr_backing_length)
	ctx.stacks.pre = make([dynamic]^Widget, 0, widget_arr_backing_length)
	ctx.stacks.post_r = make([dynamic]^Widget, 0, widget_arr_backing_length)
	ctx.primitives = make([dynamic]Command_Primitive)
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
	delete(ctx.primitives)
}

// Returns false if widget has config type of text. Text widget cannot have children.
push_parent :: proc(ctx: ^Core_Context, widget: ^Widget) -> bool {
	_, ok := widget.type.(Text)
	(!ok) or_return
	ctx.active_parent = widget
	return true
}

pop_parent :: proc(ctx: ^Core_Context) {
	if ctx.active_parent.node.parent != nil {
		ctx.active_parent = ctx.active_parent.node.parent
	}
}

// Clear up context for new frame
begin_ui :: proc(ctx: ^Core_Context) {
	clear(&ctx.widgets)
	clear(&ctx.text_lines)
	clear(&ctx.render_commands)
	ctx.active_parent = nil
}

// Layout Pass + Positioning + Render commands
end_ui :: proc(ctx: ^Core_Context) {
	_build_stacks(ctx)
	_layout_all_sizing_pass(ctx)
	_layout_all_positioning_pass(ctx)

	clear_map(&ctx.persistant_data)

	for &w in ctx.widgets {
		events: Widget_Events
		if w.node.id == ctx.hot_widget_id {
			events += {.Hovered}
		}

		if w.node.id == ctx.hot_widget_id && (w.node.id == ctx.active_widget_id || ctx.active_widget_id == 0) {
			events += _resolve_events(ctx, &w)
		}

		ctx.persistant_data[w.node.id] = Persistant_Data {
			events          = events,
			size            = w.size,
			position        = w.position,
			accumulated_min = w.accumulated_min,
		}
	}

	ctx.mouse.events = {}
	ctx.mouse.old_position = ctx.mouse.position
	ctx.active_clipper = nil // Technically it should not remain but it does?
	clear(&ctx.primitives)
	clear(&ctx.stacks.post_r)
	clear(&ctx.stacks.pre)
	clear(&ctx.stacks.temp)
}

create_widget :: proc(
	ctx: ^Core_Context,
	widget_type: Widget_Type = nil,
	string_id: string = "",
	aspect_ratio: Maybe(f32) = nil,
	image: Maybe(Image) = nil,
	clip: Maybe(Clip) = nil,
	expand: [2]Expand = {},
	offset: [2]Offset = {},
	style: Style = {},
	event_passthrough: bool = false,
) -> ^Widget {

	append(&ctx.widgets, Widget{})
	w: ^Widget = &ctx.widgets[len(ctx.widgets) - 1]
	w^ = {}
	w.string_id = string_id
	w.clip = clip
	w.type = widget_type
	w.image = image
	w.aspect_ratio = aspect_ratio
	w.offset = offset
	w.expand = expand
	w.node.parent = ctx.active_parent
	w.node.index = len(ctx.widgets) - 1
	w.event_passthrough = event_passthrough

	if image, ok := w.image.(Image); ok {
		if aspect_ratio, ok := w.aspect_ratio.(f32); !ok {
			// IMPL: Error 
		}
	}

	_add_widget(ctx, w)
	_generate_widget_id(w)

	if _, ok := w.type.(Floating); ok {
		w.z_index += max(int) / 2
		w.is_floating_descendant = true
	}

	_retrieve_persistant_data(ctx.persistant_data, w)
	w.style = style

	return w
}

// Adds a primitive shape to current parent set in Core_Context
create_primitive :: proc(ctx: ^Core_Context, primitive: Command_Primitive) {
	if ctx.active_parent != nil { 	// IMPL: Error
		append(&ctx.primitives, primitive)
		ctx.active_parent.primitives = ctx.primitives[len(ctx.primitives) - 1 - len(ctx.active_parent.primitives):len(ctx.primitives)]
	}
}

_add_widget :: proc(ctx: ^Core_Context, widget: ^Widget) {
	if ctx.active_parent != nil {
		if _, ok := widget.type.(Floating); !ok {
			ctx.active_parent.node.total_children += 1
		} else {
			ctx.active_parent.node.total_floating_children += 1
		}

		if ctx.active_parent.node.first_child == nil {
			ctx.active_parent.node.first_child = widget
		}

		widget.node.prev = ctx.active_parent.node.last_child

		if ctx.active_parent.node.last_child != nil {
			ctx.active_parent.node.last_child.node.next = widget
		}
		ctx.active_parent.node.last_child = widget

		widget.z_index = ctx.active_parent.z_index
		widget.is_floating_descendant = ctx.active_parent.is_floating_descendant
	}
}

_generate_widget_id :: proc(widget: ^Widget) {
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

	if _, ok := widget.type.(Text); ok {
		widget.accumulated_min = val.accumulated_min
	}

	return true
}
