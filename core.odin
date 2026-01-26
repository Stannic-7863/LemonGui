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
	position:     Vec2f32,
	size:         Vec2f32,
	content_size: Vec2f32,
}

Layout :: struct {
	sizing:           [2]Sizing,
	accumulating_min: [2]f32,
	direction:        Axis,
	child_gap:        f32,
	alignment:        [2]Alignment,
}

Text_Wrap_Mode :: enum u8 {
	None,
	Words,
}

Text :: struct {
	text:          string,
	start, end:    int,
	preferred_min: f32,
	preferred_max: f32,
	wrap_mode:     Text_Wrap_Mode,
}

Style :: struct {
	text:       Text_Style,
	border:     Border_Style,
	color:      Color,
	image_tint: Color,
	padding:    [2]Vec2f32,
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
	thickness: [2]Vec2f32,
	radius:    Vec4f32,
}

Widget_Kind :: union {
	Layout,
	Text,
}

Key :: union {
	string,
	int,
}

Clip :: struct {
	value: Vec2f32,
	scale: Vec2f32,
	min:   Vec2f32,
	max:   Vec2f32,
	kind:  [2]Clip_Kind,
	hash:  Hash,
}

Clip_Kind :: enum u8 {
	None,
	Custom,
	Auto,
}

Widget :: struct {
	kind:                            Widget_Kind,
	info:                            Info,
	rect:                            Rect,
	image:                           rawptr,
	total_children, z_index:         int,
	detached_children:               [Axis]int,
	clip:                            Clip_Index,
	style:                           Style_Index,
	override:                        Override_Index,
	first, last, prev, next, parent: Widget_Index,
	event_flags:                     Event_Flags,
}

Form :: struct {
	kind:        Widget_Kind,
	clip:        Clip_Index,
	image:       rawptr,
	style:       Style_Index,
	override:    Override_Index,
	event_flags: Event_Flags,
}

Info :: struct {
	position:     Vec2f32,
	size:         Vec2f32,
	content_size: Vec2f32,
	text_extent:  Vec2f32,
	index:        Widget_Index,
	key:          Key,
	hash:         Hash,
	parent_hash:  Hash,
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
	measure_text_width:          proc(text: string, style: Text_Style) -> f32,
	measure_text_height:         proc(style: Text_Style) -> f32,
	mouse:                       Mouse_Context,
	keyboard:                    Keyboard_Context,
	window_size:                 Vec2f32,
	frame_start_time:            time.Time,
	frametime:                   f32,
}

Persistant_Data :: struct {
	widget: map[Hash]Widget_Persistant_Data,
	clip:   map[Hash]Vec2f32,
}

Widget_Persistant_Data :: struct {
	rect:        Rect,
	text_extent: Vec2f32,
}

init_context :: proc(size: int) -> Core_Context {
	ctx: Core_Context
	ctx.frame_start_time = time.now()
	return ctx
}

deinit_context :: proc(ctx: ^Core_Context) {
	delete(ctx.pre)
	delete(ctx.temp)
	delete(ctx.lines)
	delete(ctx.clips)
	delete(ctx.styles)
	delete(ctx.post_r)
	delete(ctx.widgets)
	delete(ctx.clippers)
	delete(ctx.growable)
	delete(ctx.overrides)
	delete(ctx.measured_words)
	delete(ctx.render_commands)
	delete(ctx.persistant.clip)
	delete(ctx.persistant.widget)
}

reserve_widget :: proc(ctx: ^Core_Context, key: Key) -> Info {
	widget := _get_new_widget(ctx)

	widget.info.key = key
	_add_widget_to_tree(ctx, widget)
	_generate_widget_hash(&widget.info)
	_read_widget_persistant_data(ctx, widget)

	return widget.info
}

submit_widget :: proc(ctx: ^Core_Context, info: Info, form: Form) {
	widget := get_widget(ctx, info.index)

	widget.clip = form.clip
	widget.kind = form.kind
	widget.image = form.image
	widget.style = form.style
	widget.override = form.override
	widget.event_flags = form.event_flags
}

_get_new_widget :: proc(ctx: ^Core_Context) -> ^Widget {
	widget_index := cast(Widget_Index)len(ctx.widgets)
	append(&ctx.widgets, Widget{})

	widget := &ctx.widgets[widget_index]
	widget^ = {}

	widget.info.index = widget_index
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
			parent.first = widget.info.index
		}

		widget.prev = parent.last

		if parent.last != -1 {
			last := &ctx.widgets[parent.last]
			last.next = widget.info.index
		}

		parent.last = widget.info.index
		widget.z_index += parent.z_index
		widget.info.parent_hash = parent.info.hash
	}
}

_generate_widget_hash :: proc(info: ^Info) {
	switch key in info.key {
	case string:
		info.hash = cast(Hash)hash.fnv64(transmute([]u8)key)
	case int:
		e := (transmute([size_of(int)]u8)key)
		info.hash = cast(Hash)hash.fnv64(e[:])
	}
	info.hash = info.hash ~ (info.parent_hash + 0x9e3779b97f4a7c15 + (info.hash << 6) + (info.hash >> 2))
}

_read_widget_persistant_data :: proc(ctx: ^Core_Context, widget: ^Widget) {
	data := ctx.persistant.widget[widget.info.hash]

	widget.info.position = data.rect.position
	widget.info.size = data.rect.size
	widget.info.content_size = data.rect.content_size
	widget.info.text_extent = data.text_extent
}

_write_widget_persistant_data :: proc(ctx: ^Core_Context, widget: ^Widget) {
	ctx.persistant.widget[widget.info.hash] = Widget_Persistant_Data {
		text_extent = widget.info.text_extent,
		rect        = widget.rect,
	}
}

push_parent :: proc(ctx: ^Core_Context, info: Info) {
	ctx.active_parent = info.index
}

pop_parent :: proc(ctx: ^Core_Context) {
	ctx.active_parent = ctx.widgets[ctx.active_parent].parent
}

begin :: proc(ctx: ^Core_Context) {
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

end :: proc(ctx: ^Core_Context) {
	_build_stacks(ctx)
	_sizing_pass(ctx)
	_positioning_pass(ctx)
}
