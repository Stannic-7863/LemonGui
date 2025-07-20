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

/*
   Padding order : Top, right, bottom, left (Layout depends on this order)
   border radius order : top left corner, top right corner, bottom right corner, bottom left corner (Layout does not depend on this order)
*/
Vec4f32 :: [4]f32
Vec2f32 :: [2]f32
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
	last_hot_widget_id:          Id,
	last_active_widget_id:       Id,
	active_clipper:              ^Widget,
	active_parent:               ^Widget, // parent set by push parent 
	text_measure_proc:           proc(text: string, style: Text_Style) -> f32,
	window_height, window_width: f32,
	delta_time:                  f32,
}

// Data that persists each frame 
Persistant_Data :: struct {
	size, position, accumulated_min: Vec2f32,
	events:                          Widget_Event_Context,
	clip:                            Maybe([2]Clip),
}

Border_Kind :: enum u8 {
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
	kind:              Render_Command_Kind,
	z_index:           int,
	emitter_id:        Id,
	emitter_string_id: string,
}

Render_Command_Kind :: union {
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
	position: Vec2f32,
	size:     Vec2f32,
	style:    Border_Style,
}

Command_Rect :: struct {
	border_radius:  Vec4f32,
	size, position: Vec2f32,
	color:          Color,
}

Command_Text :: struct {
	position:   Vec2f32,
	style:      Text_Style,
	cursor:     Maybe([2]int),
	start, end: int, // usage : ctx.lines[start:end]
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
	border:  Border_Style,
	padding: Vec4f32,
	color:   Color,
}

Border_Style :: struct {
	radius:    Vec4f32,
	thickness: Vec4f32,
	color:     [4]Color,
	type:      [4]Border_Kind,
}

Text_Style :: struct {
	font_name:      string,
	color:          Color,
	font:           rawptr,
	font_id:        int,
	font_size:      f32,
	letter_spacing: f32,
	line_spacing:   f32,
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

Floating :: struct {
	layout:          Layout,
	id:              Id,
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
	_start, _end: int,
	wrap:         Wrap_Kind,
	cursor:       Maybe([2]int),
}

Image :: struct {
	image_data: rawptr,
	tint:       Color,
}

Widget_Kind :: union {
	Layout,
	Floating,
	Text,
}

Clip :: struct {
	kind:  Clip_Kind,
	value: f32,
	speed: f32,
}

Clip_Kind :: enum {
	Custom,
	Auto,
}

Widget :: struct {
	style:                  Style,
	kind:                   Widget_Kind,
	node:                   Node,
	expand:                 [2]Expand,
	offset:                 [2]Offset,
	image:                  Maybe(Image),
	primitives:             []Command_Primitive,
	string_id:              string,
	clip:                   Maybe([2]Clip),
	accumulated_min:        Vec2f32,
	size, position:         Vec2f32,
	z_index:                int,
	custom_data:            Maybe(rawptr),
	aspect_ratio:           Maybe(f32),
	is_floating_descendant: bool,
	event_passthrough:      bool,
	events:                 Widget_Event_Context,
}

init_core_context :: proc(total_widgets: int) -> Core_Context {
	ctx := Core_Context{}
	ctx.text_lines = make([dynamic]string)
	ctx.widgets = make([dynamic]Widget, 0, total_widgets)
	ctx.render_commands = make([dynamic]Render_Command)
	ctx.stacks.temp = make([dynamic]^Widget, 0, total_widgets)
	ctx.stacks.pre = make([dynamic]^Widget, 0, total_widgets)
	ctx.stacks.post_r = make([dynamic]^Widget, 0, total_widgets)
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

// Returns false if widget has config kind of text. Text widget cannot have children.
push_parent :: proc(ctx: ^Core_Context, widget: ^Widget) -> bool {
	_, ok := widget.kind.(Text)
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
}

// Layout Pass + Positioning + Render commands
end_ui :: proc(ctx: ^Core_Context) {
	_build_stacks(ctx)
	_layout_all_sizing_pass(ctx)
	_layout_all_positioning_pass(ctx)

	clear_map(&ctx.persistant_data)

	for &w in ctx.widgets {
		event_context: Widget_Event_Context

		if w.node.id == ctx.hot_widget_id && (w.node.id == ctx.active_widget_id || ctx.active_widget_id == 0) {
			event_context = _resolve_events(ctx, &w)
		}

		if w.node.id == ctx.hot_widget_id {
			event_context.is_hovered = true
		}

		ctx.persistant_data[w.node.id] = Persistant_Data {
			events          = event_context,
			size            = w.size,
			position        = w.position,
			accumulated_min = w.accumulated_min,
			clip            = w.clip,
		}
	}

	ctx.mouse.events = {}
	ctx.mouse.old_position = ctx.mouse.position
	ctx.last_hot_widget_id = ctx.hot_widget_id
	ctx.active_parent = nil
	clear(&ctx.primitives)
	clear(&ctx.stacks.post_r)
	clear(&ctx.stacks.pre)
	clear(&ctx.stacks.temp)
}

create_widget :: proc(
	ctx: ^Core_Context,
	widget_kind: Widget_Kind = nil,
	string_id: string = "",
	aspect_ratio: Maybe(f32) = nil,
	image: Maybe(Image) = nil,
	clip: Maybe([2]Clip) = nil,
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
	w.kind = widget_kind
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

	if _, ok := w.kind.(Floating); ok {
		w.z_index += max(int) / 2
		w.is_floating_descendant = true
	}

	if w.is_floating_descendant {
		w.node.parent.node.total_children -= 1
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
		ctx.active_parent.node.total_children += 1

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

	if clip, widget_clip_ok := &widget.clip.([2]Clip); widget_clip_ok {
		val_clip, val_clip_ok := val.clip.([2]Clip)

		if clip.x.kind == .Auto && val_clip_ok {
			clip.x.value = val_clip.x.value
		}

		if clip.y.kind == .Auto && val_clip_ok {
			clip.y.value = val_clip.y.value
		}

	}

	if _, ok := widget.kind.(Text); ok {
		widget.accumulated_min = val.accumulated_min
	}

	return true
}
