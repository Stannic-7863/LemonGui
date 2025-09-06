package core_ui

import "core:hash"

Vec2f32 :: [2]f32
Vec4f32 :: [4]f32
Color :: Vec4f32

Hash :: distinct u64

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

Widget_Style :: struct {
	border:     Border_Style,
	color:      Color,
	image_tint: Color,
	padding:    [Axis]Vec2f32,
}

Border_Style :: struct {
	color:     [4]Color,
	thickness: [Axis]Vec2f32,
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
	hash, parent_hash: Hash,
}

Clip :: struct {
	value: [Axis]f32,
	scale: [Axis]f32,
	kind:  [Axis]Clip_Kind,
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
	kind:                            Widget_Kind,
	key:                             Key,
	resolved:                        Resolved,
	rect:                            Rect,
	image:                           rawptr,
	custom_data:                     rawptr,
	z_index:                         int,
	override:                        i32,
	clip:                            i32,
	style:                           i32,
	total_children, index:           i32,
	first, last, prev, next, parent: i32,
	event_flags:                     Event_Flags,
}

Core_Context :: struct {
	active_parent:               i32,
	active_clip:                 ^Widget,
	overrides:                   [dynamic]Override,
	clips:                       [dynamic]Clip,
	styles:                      [dynamic]Widget_Style,
	temp, post_r, pre, clippers: [dynamic]^Widget,
	growable:                    [dynamic]Growable,
	widgets:                     [dynamic]Widget,
	lines:                       [dynamic]string,
	render_commands:             [dynamic]Render_Command,
	measured_words:              [dynamic]Measured_Word,
	persistant_data:             map[Hash]Persistant_Data,
	measure_text_proc:           proc(text: string, style: Text_Style) -> f32,
	mouse:                       Mouse_Context,
	keyboard:                    Keyboard_Context,
	window_size:                 Vec2f32,
}

Persistant_Data :: struct {
	rect:               Rect,
	content_size:       Vec2f32,
	auto_clip_value:    [Axis]f32,
	text_minimum_width: f32,
	text_maximum_width: f32,
}

init_context :: proc(size: int) -> Core_Context {
	ctx: Core_Context
	ctx.widgets = make([dynamic]Widget, 0, size)
	ctx.persistant_data = make(map[Hash]Persistant_Data)
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
	style: Widget_Style = {},
) -> ^Widget {
	widget := _get_new_widget(ctx, style, clip, override)

	widget.kind = kind
	widget.image = image

	widget.event_flags = event_flags
	widget.key.keying_id = id
	widget.parent = ctx.active_parent

	_add_widget_to_tree(ctx, widget)
	_generate_widget_hash(widget)
	_read_persistant_data(ctx, widget)
	return widget
}

_get_new_widget :: proc(ctx: ^Core_Context, style: Widget_Style, clip: Clip, override: Override) -> ^Widget {

	clip_index: i32
	style_index: i32
	override_index: i32

	if clip != {} {
		clip_index = cast(i32)len(ctx.clips)
		append(&ctx.clips, clip)
	}
	if style != {} {
		style_index = cast(i32)len(ctx.styles)
		append(&ctx.styles, style)
	}
	if override != {} {
		override_index = cast(i32)len(ctx.overrides)
		append(&ctx.overrides, override)
	}

	widget_index := cast(i32)len(ctx.widgets)
	append(&ctx.widgets, Widget{})

	widget := &ctx.widgets[widget_index]
	widget^ = {}

	widget.clip = clip_index
	widget.style = style_index
	widget.override = override_index
	widget.index = widget_index
	widget.parent = -1
	widget.first = -1
	widget.last = -1
	widget.next = -1
	widget.prev = -1
	return widget
}

_add_widget_to_tree :: proc(ctx: ^Core_Context, widget: ^Widget) {
	if widget.parent != -1 {
		parent := &ctx.widgets[widget.parent]
		parent.total_children += 1
		if parent.first == -1 {
			parent.first = widget.index
		}

		widget.prev = parent.last

		if parent.last != -1 {
			last := &ctx.widgets[parent.last]
			last.next = widget.index
		}

		parent.last = widget.index
		widget.z_index += parent.z_index
		widget.key.parent_hash = parent.key.hash
	}
}

_generate_widget_hash :: proc(widget: ^Widget) {
	switch key in widget.key.keying_id {
	case string: widget.key.hash = cast(Hash)hash.fnv64(transmute([]u8)key)
	case int:
		e := (transmute([size_of(int)]u8)key)
		widget.key.hash = cast(Hash)hash.fnv64(e[:])
	}
	widget.key.hash ~= (widget.key.hash >> 2 ~ widget.key.parent_hash << 6)
}

_read_persistant_data :: proc(ctx: ^Core_Context, widget: ^Widget) {
	data := ctx.persistant_data[widget.key.hash]

	widget.resolved.position = data.rect.position
	widget.resolved.size = data.rect.size
	widget.resolved.content_size = data.content_size

	for axis in Axis {
		widget_clip := &ctx.clips[widget.clip]
		if widget_clip.kind[axis] == .Auto {
			widget_clip.value[axis] = data.auto_clip_value[axis]
		}
	}

	if text, ok := &widget.kind.(Text); ok {
		text.minimum_width = data.text_minimum_width
		text.maximum_width = data.text_maximum_width
	}
}

_write_persistant_data :: proc(ctx: ^Core_Context, widget: ^Widget) {
	text, ok := widget.kind.(Text)
	widget_clip_value := ctx.clips[widget.clip].value
	ctx.persistant_data[widget.key.hash] = Persistant_Data {
		text_minimum_width = text.minimum_width,
		text_maximum_width = text.maximum_width,
		rect               = widget.rect,
		auto_clip_value    = widget_clip_value,
		content_size       = widget.resolved.content_size,
	}
}

push_parent :: proc(ctx: ^Core_Context, widget: ^Widget) -> bool {
	if text, ok := widget.kind.(Text); !ok {
		ctx.active_parent = widget.index
		return true
	}
	return false
}

pop_parent :: proc(ctx: ^Core_Context) {
	ctx.active_parent = ctx.widgets[ctx.active_parent].parent
}

begin_ui :: proc(ctx: ^Core_Context) {
	ctx.active_parent = -1
	clear(&ctx.lines)
	clear(&ctx.widgets)
	clear(&ctx.render_commands)

	clear(&ctx.styles)
	clear(&ctx.clips)
	clear(&ctx.overrides)

	append(&ctx.styles, Widget_Style{})
	append(&ctx.clips, Clip{})
	append(&ctx.overrides, Override{})

	clear(&ctx.temp)
	clear(&ctx.pre)
	clear(&ctx.post_r)
}

end_ui :: proc(ctx: ^Core_Context) {
	_build_stacks(ctx)
	_sizing_pass(ctx)
	_positioning_pass(ctx)
}
