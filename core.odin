package core_ui

import "core:hash"
import "core:time"

Widget_Index :: distinct i32
Style_Index :: distinct i32
Clip_Index :: distinct i32
Override_Index :: distinct i32

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
	text:          string,
	start, end:    int,
	minimum_width: f32,
	maximum_width: f32,
	preferred_min: f32,
	preferred_max: f32,
	wrap_mode:     Text_Wrap_Mode,
}

Style :: struct {
	text:       Text_Style,
	border:     Border_Style,
	color:      Color,
	image_tint: Color,
	padding:    [Axis]Vec2f32,
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
	min:   [Axis]f32,
	max:   [Axis]f32,
	kind:  [Axis]Clip_Kind,
	hash:  Hash,
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
	kind:                                   Widget_Kind,
	key:                                    Key,
	resolved:                               Resolved,
	rect:                                   Rect,
	image:                                  rawptr,
	custom_data:                            rawptr,
	total_children, z_index:                int,
	clip:                                   Clip_Index,
	style:                                  Style_Index,
	override:                               Override_Index,
	first, last, prev, next, parent, index: Widget_Index,
	event_flags:                            Event_Flags,
	animate_props:                          Animate_Props,
}

Core_Context :: struct {
	active_parent:               Widget_Index,
	active_clip:                 ^Widget,
	overrides:                   [dynamic]Override,
	clips:                       [dynamic]Clip,
	styles:                      [dynamic]Style,
	temp, post_r, pre, clippers: [dynamic]^Widget,
	growable:                    [dynamic]Growable,
	widgets:                     [dynamic]Widget,
	lines:                       [dynamic]string,
	render_commands:             [dynamic]Render_Command,
	measured_words:              [dynamic]Measured_Word,
	persistant:                  Persistant_Data,
	measure_text_proc:           proc(text: string, style: Text_Style) -> f32,
	mouse:                       Mouse_Context,
	keyboard:                    Keyboard_Context,
	window_size:                 Vec2f32,
	frame_start_time:            time.Time,
	frametime:                   f32,
}

Persistant_Data :: struct {
	widget:  map[Hash]Widget_Persistant_Data,
	animate: map[Hash]Animate_Persistant_Data,
	clip:    map[Hash][Axis]f32,
}

Widget_Persistant_Data :: struct {
	rect:               Rect,
	content_size:       Vec2f32,
	text_minimum_width: f32,
	text_maximum_width: f32,
}

init_context :: proc(size: int) -> Core_Context {
	ctx: Core_Context
	ctx.frame_start_time = time.now()
	return ctx
}

deinit_context :: proc(ctx: ^Core_Context) {
}

create_widget :: proc(
	ctx: ^Core_Context,
	id: Keying_Id,
	kind: Widget_Kind = {},
	event_flags: Event_Flags = {},
	animate_props: Animate_Props = {},
	image: rawptr = nil,
	override: Override_Index = 0,
	clip: Clip_Index = 0,
	style: Style_Index = 0,
) -> ^Widget {
	widget := _get_new_widget(ctx)

	widget.clip = clip
	widget.kind = kind
	widget.image = image
	widget.style = style
	widget.override = override

	widget.key.keying_id = id
	widget.event_flags = event_flags
	widget.animate_props = animate_props

	_add_widget_to_tree(ctx, widget)
	_generate_widget_hash(widget)
	_read_widget_persistant_data(ctx, widget)
	return widget
}

_get_new_widget :: proc(ctx: ^Core_Context) -> ^Widget {
	widget_index := cast(Widget_Index)len(ctx.widgets)
	append(&ctx.widgets, Widget{})

	widget := &ctx.widgets[widget_index]
	widget^ = {}

	widget.index = widget_index
	widget.parent = ctx.active_parent
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
	case string:
		widget.key.hash = cast(Hash)hash.fnv64(transmute([]u8)key)
	case int:
		e := (transmute([size_of(int)]u8)key)
		widget.key.hash = cast(Hash)hash.fnv64(e[:])
	}
	widget.key.hash ~= (widget.key.hash >> 2 ~ widget.key.parent_hash << 6)
}

_read_widget_persistant_data :: proc(ctx: ^Core_Context, widget: ^Widget) {
	data := ctx.persistant.widget[widget.key.hash]

	widget.resolved.position = data.rect.position
	widget.resolved.size = data.rect.size
	widget.resolved.content_size = data.content_size

	if text, ok := &widget.kind.(Text); ok {
		text.minimum_width = data.text_minimum_width
		text.maximum_width = data.text_maximum_width
	}
}

_write_widget_persistant_data :: proc(ctx: ^Core_Context, widget: ^Widget) {
	text, ok := widget.kind.(Text)
	ctx.persistant.widget[widget.key.hash] = Widget_Persistant_Data {
		text_minimum_width = text.minimum_width,
		text_maximum_width = text.maximum_width,
		rect               = widget.rect,
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

	clear(&ctx.clips)
	clear(&ctx.styles)
	clear(&ctx.overrides)

	append(&ctx.clips, Clip{})
	append(&ctx.styles, Style{})
	append(&ctx.overrides, Override{})

	clear(&ctx.temp)
	clear(&ctx.pre)
	clear(&ctx.post_r)
	ctx.frametime = f32(time.diff(ctx.frame_start_time, time.now())) / f32(time.Second)
	ctx.frame_start_time = time.now()
}

end_ui :: proc(ctx: ^Core_Context) {
	_build_stacks(ctx)
	_sizing_pass(ctx)
	_positioning_pass(ctx)
}
