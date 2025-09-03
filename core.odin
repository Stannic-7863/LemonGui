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
	accumulating_min: [Axis]f32,
	direction:        Axis,
	child_gap:        f32,
	alignment:        [Axis]Alignment,
}

Text_Wrap_Mode :: enum u8 {
	None,
	Words,
}

Text :: struct {
	style:         Text_Style,
	text:          string,
	start, end:    int,
	minimum_width: f32,
	maximum_width: f32,
	preferred_min: f32,
	preferred_max: f32,
	wrap_mode:     Text_Wrap_Mode,
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

Keying_Id :: union {
	string,
	int,
}

Key :: struct {
	keying_id:         Keying_Id,
	hash, parent_hash: u64,
}

Clip :: struct {
	kind:  [Axis]Clip_Kind,
	value: [Axis]f32,
	scale: [Axis]f32,
}

Clip_Kind :: enum u8 {
	None,
	Custom,
	Auto,
}

Resolved :: struct {
	size, content_size, position: Vec2f32,
}

Widget :: struct {
	style:                           Rect_Style,
	kind:                            Widget_Kind,
	override:                        Override,
	key:                             Key,
	resolved:                        Resolved,
	clip:                            Clip,
	rect:                            Rect,
	id:                              u64,
	total_children:                  int,
	image:                           rawptr,
	custom:                          rawptr,
	first, last, prev, next, parent: ^Widget,
	event_flags:                     Event_Flags,
}

Core_Context :: struct {
	active_parent, active_clip: ^Widget,
	temp, post_r, pre, clips:   [dynamic]^Widget,
	growable:                   [dynamic]Growable,
	widgets:                    [dynamic]Widget,
	text_lines:                 [dynamic]string,
	render_commands:            [dynamic]Render_Command,
	persistant_data:            map[u64]Persistant_Data,
	measure_text_proc:          proc(text: string, style: Text_Style) -> f32,
	mouse:                      Mouse_Context,
	keyboard:                   Keyboard_Context,
	window_size:                Vec2f32,
}

Persistant_Data :: struct {
	rect:               Rect,
	content_size:       Vec2f32,
	auto_clip_value:    [Axis]f32,
	text_minimum_width: f32,
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
	id: Keying_Id,
	kind: Widget_Kind = {},
	override: Override = {},
	event_flags: Event_Flags = {},
	clip: Clip = {},
	image: rawptr = nil,
	style: Rect_Style = {},
) -> ^Widget {
	widget := _get_new_widget(ctx)

	widget.kind = kind
	widget.clip = clip
	widget.style = style
	widget.image = image
	widget.override = override
	widget.event_flags = event_flags
	widget.key.keying_id = id
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
		widget.override.z_index += widget.parent.override.z_index
		widget.key.parent_hash = widget.parent.key.hash
	}
}

_generate_widget_hash :: proc(widget: ^Widget) {
	switch key in widget.key.keying_id {
	case string: widget.key.hash = hash.fnv64(transmute([]u8)key)
	case int:
		e := (transmute([size_of(int)]u8)key)
		widget.key.hash = hash.fnv64(e[:])
	}
	widget.key.hash ~= (widget.key.hash >> 2 ~ widget.key.parent_hash << 6)
}

_read_persistant_data :: proc(ctx: ^Core_Context, widget: ^Widget) {
	data := ctx.persistant_data[widget.key.hash]

	widget.resolved.position = data.rect.position
	widget.resolved.size = data.rect.size
	widget.resolved.content_size = data.content_size

	for axis in Axis {
		if widget.clip.kind[axis] == .Auto {
			widget.clip.value[axis] = data.auto_clip_value[axis]
		}
	}

	if text, ok := &widget.kind.(Text); ok {
		text.minimum_width = data.text_minimum_width
	}
}

_write_persistant_data :: proc(ctx: ^Core_Context, widget: ^Widget) {
	text, ok := widget.kind.(Text)
	ctx.persistant_data[widget.key.hash] = Persistant_Data {
		text_minimum_width = text.minimum_width,
		rect               = widget.rect,
		auto_clip_value    = widget.clip.value,
		content_size       = widget.resolved.content_size,
	}
}

push_parent :: proc(ctx: ^Core_Context, widget: ^Widget) -> bool {
	if text, ok := widget.kind.(Text); !ok {
		ctx.active_parent = widget
		return true
	}
	return false
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
}
