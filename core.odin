package core_ui

import "core:hash"

Vec2f32 :: [2]f32
Vec4f32 :: [4]f32
Color :: [4]f32

Rect :: struct {
	position, size: Vec2f32,
}

Layout :: struct {
	sizing:           [Axis]Sizing,
	alignment:        [Axis]Alignment,
	accumulating_min: [Axis]f32,
	direction:        Axis,
	child_gap:        f32,
}

Text :: struct {
	text:          string,
	minimum_width: f32,
	maximum_width: f32,
	preferred_min: f32,
	preferred_max: f32,
	style:         Text_Style,
	start, end:    int,
}

Text_Style :: struct {
	color:          Color,
	font_name:      string,
	font:           rawptr,
	font_id:        int,
	font_size:      f32,
	letter_spacing: f32,
	line_spacing:   f32,
}

Rect_Style :: struct {
	color:   Vec4f32,
	padding: [Axis]Vec2f32,
	border:  Border_Style,
}

Border_Style :: struct {
	thickness: [Axis]Vec2f32,
	color:     [4]Color,
	radius:    Vec4f32,
}

Widget_Kind :: union {
	Layout,
	Text,
}

Hash :: struct {
	hash, parent_hash: u64,
	string_id:         string,
}

Widget :: struct {
	first, last, prev, next, parent: ^Widget,
	total_children, z_index:         int,
	id:                              u64,
	kind:                            Widget_Kind,
	override:                        Override,
	style:                           Rect_Style,
	rect:                            Rect,
	resolved_rect:                   Rect,
	key:                             Hash,
	event_flags:                     Event_Flags,
}

Core_Context :: struct {
	active_parent:     ^Widget,
	temp, post_r, pre: [dynamic]^Widget,
	growable:          [dynamic]Growable,
	widgets:           [dynamic]Widget,
	text_lines:        [dynamic]string,
	render_commands:   [dynamic]Render_Command,
	persistant_data:   map[u64]Persistant_Data,
	measure_text_proc: proc(text: string, style: Text_Style) -> f32,
	mouse:             Mouse_Context,
	keyboard:          Keyboard_Context,
}

Persistant_Data :: struct {
	text_minimum_width: f32,
	rect:               Rect,
}

init_context :: proc(size: int) -> Core_Context {
	ctx: Core_Context
	ctx.widgets = make([dynamic]Widget, 0, size)
	ctx.persistant_data = make(map[u64]Persistant_Data)
	return ctx
}

deinit_context :: proc(ctx: ^Core_Context) {
	delete(ctx.widgets)
}

create_widget :: proc(
	ctx: ^Core_Context,
	id: string,
	kind: Widget_Kind = {},
	override: Override = {},
	event_flags: Event_Flags = {},
	style: Rect_Style = {},
) -> ^Widget {
	widget := _get_new_widget(ctx)

	widget.kind = kind
	widget.style = style
	widget.override = override
	widget.event_flags = event_flags
	widget.key.string_id = id
	widget.parent = ctx.active_parent

	_add_widget_to_tree(widget)
	_generate_widget_hash(widget)
	_read_persistant_data(ctx, widget)

	return widget
}

_get_new_widget :: proc(ctx: ^Core_Context) -> ^Widget {
	append(&ctx.widgets, Widget{})
	widget := &ctx.widgets[len(ctx.widgets) - 1]
	widget^ = {}
	return widget
}

_add_widget_to_tree :: proc(widget: ^Widget) {
	if widget.parent != nil {
		widget.parent.total_children += 1
		if widget.parent.first == nil {
			widget.parent.first = widget
		}

		widget.prev = widget.parent.last

		if widget.parent.last != nil {
			widget.parent.last.next = widget
		}

		widget.parent.last = widget
		widget.z_index = widget.parent.z_index
		widget.key.parent_hash = widget.parent.key.hash
	}
}

_generate_widget_hash :: proc(widget: ^Widget) {
	widget.key.hash = hash.fnv64(transmute([]u8)widget.key.string_id)
	widget.key.hash ~= (widget.key.hash >> 2 ~ widget.key.parent_hash << 6)
}

_read_persistant_data :: proc(ctx: ^Core_Context, widget: ^Widget) {
	data := ctx.persistant_data[widget.key.hash]

	widget.resolved_rect = data.rect

	if text, ok := &widget.kind.(Text); ok {
		text.minimum_width = data.text_minimum_width
	}
}

_write_persistant_data :: proc(ctx: ^Core_Context, widget: ^Widget) {
	text, ok := widget.kind.(Text)
	ctx.persistant_data[widget.key.hash] = Persistant_Data {
		text_minimum_width = text.minimum_width,
		rect               = widget.rect,
	}
}

push_parent :: proc(ctx: ^Core_Context, widget: ^Widget) -> bool {
	if text, ok := widget.kind.(Text); !ok {
		ctx.active_parent = widget
		return true
	}
	return false
}

@(deferred_in = _pop_parent_scoped)
push_parent_scoped :: proc(ctx: ^Core_Context, widget: ^Widget) -> bool {
	return push_parent(ctx, widget)
}

_pop_parent_scoped :: proc(ctx: ^Core_Context, widget: ^Widget) {
	pop_parent(ctx)
}

pop_parent :: proc(ctx: ^Core_Context) {
	if ctx.active_parent.parent != nil {
		ctx.active_parent = ctx.active_parent.parent
	}
}

begin_ui :: proc(ctx: ^Core_Context) {
	ctx.active_parent = nil
	clear(&ctx.text_lines)
	clear(&ctx.widgets)
	clear(&ctx.render_commands)
	clear(&ctx.temp)
	clear(&ctx.pre)
	clear(&ctx.post_r)
}

end_ui :: proc(ctx: ^Core_Context) {
	_build_stacks(ctx)
	_sizing_pass(ctx)
	_positioning_pass(ctx)

	clear(&ctx.persistant_data)
	for n in ctx.pre {
		_resolve_events(ctx)
		_write_persistant_data(ctx, n)
	}

	ctx.mouse.mapped_events = {}
}
