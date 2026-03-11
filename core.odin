package core_ui

import "core:hash"
import "core:time"

import "core:container/lru"

Range :: struct {
	start, end: i32,
}

Text_Index :: distinct i32
Clip_Index :: distinct i32
Style_Index :: distinct i32
Widget_Index :: distinct i32
Override_Range :: distinct Range
Animation_Index :: distinct i32

Vec2f32 :: [2]f32
Vec4f32 :: [4]f32
Color :: Vec4f32

Hash :: distinct u64

Rect :: struct {
	position:     Vec2f32,
	size:         Vec2f32,
	content_size: Vec2f32,
}

Text_Wrap_Mode :: enum u8 {
	None,
	Words,
}

Text :: struct {
	text:          string,
	start, end:    int, // Use to slice Core_Context.lines
	preferred_min: f32,
	preferred_max: f32,
	wrap_mode:     Text_Wrap_Mode,
}

Style :: struct {
	text:       Text_Style,
	border:     Border_Style,
	color:      Color,
	image_tint: Color,
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
	info:                            Info, // This will contain a Rect from previous frame.
	form:                            Form,
	rect:                            Rect, // Info about current frame processed rect
	total_children, z_index:         int,
	detached_children:               [2]int,
	first, last, prev, next, parent: Widget_Index,
}

Form :: struct {
	image:       rawptr,
	layout:      Layout,
	event_flags: Event_Flags,
	text:        Text_Index,
	clip:        Clip_Index,
	style:       Style_Index,
	override:    Override_Range,
	animation:   Animation_Index,
}

Info :: struct {
	rect:        Rect,
	text_extent: Vec2f32,
	index:       Widget_Index,
	key:         Key,
	hash:        Hash,
	parent_hash: Hash,
}

Core_Context :: struct {
	active_parent:       Widget_Index,
	overrides:           [dynamic]Override,
	clips:               [dynamic]Clip,
	text:                [dynamic]Text,
	animations:          [dynamic]Animation,
	styles:              [dynamic]Style,
	temp:                [dynamic]^Widget,
	growable:            [dynamic]Growable,
	widgets:             [dynamic]Widget,
	lines:               [dynamic]string,
	render_commands:     [dynamic]Render_Command,
	measured_words:      [dynamic]Measured_Word,
	animation_states:    map[Hash]Animation_State,
	new, dead:           map[Hash]Info,
	persistant:          Persistant_Data,
	measure_text_width:  proc(text: string, style: Text_Style) -> f32,
	measure_text_height: proc(style: Text_Style) -> f32,
	mouse:               Mouse_Context,
	keyboard:            Keyboard_Context,
	window_size:         Vec2f32,
	frame_start:         time.Time,
	layout_start:        time.Time,
	frame_time:          time.Duration,
	layout_time:         time.Duration,
}

Lookup_Data :: struct {
	form: Form,
	info: Info,
}

Persistant_Data :: struct {
	prev_animations: [dynamic]Animation,
	prev_styles:     [dynamic]Style,
	prev_lookup:     map[Hash]Lookup_Data, // Swapped with curr_lookup at frame end
	curr_lookup:     map[Hash]Lookup_Data, // Cleared at frame start
	clip:            map[Hash]Vec2f32,
}

init_context :: proc(size: int) -> Core_Context {
	ctx: Core_Context
	ctx.frame_start = time.now()
	return ctx
}

deinit_context :: proc(ctx: ^Core_Context) {
	delete(ctx.temp)
	delete(ctx.lines)
	delete(ctx.clips)
	delete(ctx.styles)
	delete(ctx.widgets)
	delete(ctx.growable)
	delete(ctx.overrides)
	delete(ctx.measured_words)
	delete(ctx.render_commands)
	delete(ctx.animation_states)
	delete(ctx.animations)

	delete(ctx.new)
	delete(ctx.dead)

	delete(ctx.persistant.curr_lookup)
	delete(ctx.persistant.prev_lookup)
	delete(ctx.persistant.prev_styles)
	delete(ctx.persistant.prev_animations)
	delete(ctx.persistant.clip)
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

	ctx.persistant.curr_lookup[info.hash] = {
		info = info,
		form = form,
	}

	widget.form = form
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
	info.hash = info.hash ~ (info.parent_hash + 0x9e3779b97f4a7c15 + (info.hash << 6) + (info.hash >> 2)) // Boost / split-max hash combine
}

_read_widget_persistant_data :: proc(ctx: ^Core_Context, widget: ^Widget) {
	data, ok := ctx.persistant.prev_lookup[widget.info.hash]

	if !ok {return}

	widget.info.rect = data.info.rect
	widget.info.text_extent = data.info.text_extent
}

_write_widget_persistant_data :: proc(ctx: ^Core_Context, widget: ^Widget) {
	data := &ctx.persistant.curr_lookup[widget.info.hash]
	data.info.rect = widget.rect
	data.info.text_extent = widget.info.text_extent
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

	clear(&ctx.text)
	clear(&ctx.clips)
	clear(&ctx.styles)
	clear(&ctx.overrides)
	clear(&ctx.animations)

	// Valid 0 states
	append(&ctx.text, Text{})
	append(&ctx.clips, Clip{})
	append(&ctx.styles, Style{})
	append(&ctx.overrides, Override{})
	append(&ctx.animations, Animation{})
	append(&ctx.persistant.prev_styles, Style{})
	append(&ctx.persistant.prev_animations, Animation{})

	clear(&ctx.temp)

	clear(&ctx.persistant.curr_lookup)

	ctx.frame_time = time.diff(ctx.frame_start, time.now())
	ctx.frame_start = time.now()
	ctx.layout_start = time.now()
}

end :: proc(ctx: ^Core_Context) {
	_sizing_pass(ctx)
	_positioning_pass(ctx)
	_post_layout_pass(ctx)
}
