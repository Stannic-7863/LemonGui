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


Core_Context :: struct {
	stacks:                      struct {
		post_r: [dynamic]^Widget,
		pre:    [dynamic]^Widget,
		temp:   [dynamic]^Widget,
	},
	mouse:                       Mouse_Context,
	keyboard:                    Keyboard_Context,
	widgets:                     [dynamic]Widget,
	text_lines:                  [dynamic]string,
	render_commands:             [dynamic]Render_Command,
	primitives:                  [dynamic]Command_Primitive,
	clips:                       [dynamic]^Widget,
	tag_styles:                  map[string]Tag_Style,
	persistant_data:             map[Id]Persistant_Data, // widgets from last frame. Used to query events. Accessed by widget.id
	hot_widget_id:               Id, // widget currently under mouse  
	active_widget_id:            Id, // widget currently being interacted with 
	active_clipper:              ^Widget,
	active_parent:               ^Widget, // parent set by push parent 
	text_measure_proc:           proc(text: string, style: Text_Style) -> f32,
	window_height, window_width: f32,
	delta_time:                  f32,
}

Core_Error :: enum u8 {
	No_Parent_To_Bind_Primitive,
	Zero_Or_No_Aspect_Ratio,
}

Error_Context :: struct {
	error: Core_Error,
	line:  int,
}

// Data that persists each frame 
Persistant_Data :: struct {
	size, position, accumulated_min: Vec2f32,
	clip:                            [2]Clip,
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

Rect_Style :: struct {
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

Tag_Style :: struct {
	padding:          Maybe(Vec4f32),
	color:            Maybe(Color),
	border_radius:    Maybe(Vec4f32),
	border_thickness: Maybe(Vec4f32),
	border_color:     Maybe([4]Color),
	border_type:      Maybe([4]Border_Kind),
	text_color:       Maybe(Color),
	font_name:        Maybe(string),
	font:             Maybe(rawptr),
	font_id:          Maybe(int),
	font_size:        Maybe(f32),
	letter_spacing:   Maybe(f32),
	line_spacing:     Maybe(f32),
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
	cursor:       Maybe([2]int),
	wrap:         Wrap_Kind,
}

Image :: struct {
	data: rawptr,
	tint: Color,
}

Widget_Kind :: union {
	Layout,
	Floating,
	Text,
}

Key :: struct {
	string_id: string,
	parent_id: Id,
}

Widget :: struct {
	rect_style:             Rect_Style,
	kind:                   Widget_Kind,
	node:                   Node,
	primitives:             []Command_Primitive,
	tags:                   []string,
	expand:                 [2]Expand,
	offset:                 [2]Offset,
	clip:                   [2]Clip,
	image:                  Image,
	aspect_ratio:           f32,
	custom_data:            rawptr,
	key:                    Key,
	accumulated_min:        Vec2f32,
	size, position:         Vec2f32,
	z_index:                int,
	is_floating_descendant: bool,
	event_passthrough:      bool,
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
	ctx.tag_styles = make(map[string]Tag_Style)
	return ctx
}

deinit_core_context :: proc(ctx: ^Core_Context) {
	delete(ctx.tag_styles)
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
	_apply_tag_styles(ctx)
	_layout_all_sizing_pass(ctx)
	_layout_all_positioning_pass(ctx)

	clear_map(&ctx.persistant_data)
	ctx.mouse.events = {}
	_resolve_events(ctx)

	for &w in ctx.widgets {
		ctx.persistant_data[w.node.id] = Persistant_Data {
			size            = w.size,
			position        = w.position,
			accumulated_min = w.accumulated_min,
			clip            = w.clip,
		}
	}

	hot_widget_pd, ok := &ctx.persistant_data[ctx.hot_widget_id]

	if ok {
		if hot_widget_pd.clip.x.kind == .Auto {
			hot_widget_pd.clip.x.value += ctx.mouse.scroll * ctx.delta_time * hot_widget_pd.clip.x.scale
		}
		if hot_widget_pd.clip.y.kind == .Auto {
			hot_widget_pd.clip.y.value += ctx.mouse.scroll * ctx.delta_time * hot_widget_pd.clip.y.scale
		}
	}

	ctx.mouse.mapped_events = {}
	ctx.mouse.old_position = ctx.mouse.position
	ctx.active_parent = nil
	clear(&ctx.primitives)
	clear(&ctx.stacks.post_r)
	clear(&ctx.stacks.pre)
	clear(&ctx.stacks.temp)
}

create_widget :: proc(
	ctx: ^Core_Context,
	string_id: string,
	widget_kind: Widget_Kind = nil,
	aspect_ratio: f32 = {},
	image: Image = {},
	clip: [2]Clip = {},
	expand: [2]Expand = {},
	offset: [2]Offset = {},
	tags: []string = {},
	style: Rect_Style = {},
	event_passthrough: bool = false,
) -> ^Widget {

	append(&ctx.widgets, Widget{})
	w: ^Widget = &ctx.widgets[len(ctx.widgets) - 1]
	w^ = {}
	w.clip = clip
	w.kind = widget_kind
	w.image = image
	w.aspect_ratio = aspect_ratio
	w.offset = offset
	w.expand = expand
	w.node.parent = ctx.active_parent
	w.node.index = len(ctx.widgets) - 1
	w.event_passthrough = event_passthrough
	w.tags = tags

	if w.image.data != nil {
		if aspect_ratio == 0 {
			// IMPL: Error 
		}
	}

	_add_widget(ctx, w)
	w.key.string_id = string_id
	_generate_widget_id(w)

	if _, ok := w.kind.(Floating); ok {
		w.z_index += max(int) / 2
		w.is_floating_descendant = true
	}

	if w.is_floating_descendant {
		w.node.parent.node.total_children -= 1
	}

	_retrieve_persistant_data(ctx.persistant_data, w)
	w.rect_style = style

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
		widget.key.parent_id = ctx.active_parent.node.id
	}
}

_generate_widget_id :: proc(widget: ^Widget) {
	id := cast(Id)hash.fnv64(transmute([]u8)widget.key.string_id)
	widget.node.id = widget.key.parent_id * 9 + id
}

_retrieve_persistant_data :: proc(persistant_data: map[Id]Persistant_Data, widget: ^Widget) -> bool {
	val := persistant_data[widget.node.id] or_return
	widget.position = val.position
	widget.size = val.size

	if widget.clip.x.kind == .Auto {
		widget.clip.x.value = val.clip.x.value
	}

	if widget.clip.y.kind == .Auto {
		widget.clip.y.value = val.clip.y.value
	}

	if _, ok := widget.kind.(Text); ok {
		widget.accumulated_min = val.accumulated_min
	}

	return true
}

_apply_tag_styles :: proc(ctx: ^Core_Context) {
	for &w in ctx.widgets {
		for tag in w.tags {
			tag_style, tag_not_exists := ctx.tag_styles[tag]

			if tag_not_exists {
				continue
			}

			if padding, ok := tag_style.padding.(Vec4f32); ok {
				w.rect_style.padding = padding
			}
			if color, ok := tag_style.color.(Color); ok {
				w.rect_style.color = color
			}
			if border_radius, ok := tag_style.border_radius.(Vec4f32); ok {
				w.rect_style.border.radius = border_radius
			}
			if border_thickness, ok := tag_style.border_thickness.(Vec4f32); ok {
				w.rect_style.border.thickness = border_thickness
			}
			if border_color, ok := tag_style.border_color.([4]Color); ok {
				w.rect_style.border.color = border_color
			}
			if border_type, ok := tag_style.border_type.([4]Border_Kind); ok {
				w.rect_style.border.type = border_type
			}

			if text, ok := &w.kind.(Text); ok {
				if text_color, ok := tag_style.text_color.(Color); ok {
					text.style.color = text_color
				}
				if font_name, ok := tag_style.font_name.(string); ok {
					text.style.font_name = font_name
				}
				if font, ok := tag_style.font.(rawptr); ok {
					text.style.font = font
				}
				if font_id, ok := tag_style.font_id.(int); ok {
					text.style.font_id = font_id
				}
				if font_size, ok := tag_style.font_size.(f32); ok {
					text.style.font_size = font_size
				}
				if letter_spacing, ok := tag_style.letter_spacing.(f32); ok {
					text.style.letter_spacing = letter_spacing
				}
				if line_spacing, ok := tag_style.line_spacing.(f32); ok {
					text.style.line_spacing = line_spacing
				}
			}
		}
	}
}
