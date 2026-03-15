package core_ui

import "core:hash"
import "core:time"

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
	scroll_offset: Vec2f32,
}

Text_Wrap_Mode :: enum u8 {
	None,
	Words,
}

Text :: struct {
	text:          string,
	preferred_min: f32,
	preferred_max: f32,
	wrap_mode:     Text_Wrap_Mode,
}

Text_Info :: struct {
	size:        Vec2f32, // We use previous frame x size, and current frame y size during sizing passes
	position:    Vec2f32,
	min_width:   f32,
	max_width:   f32,
	wrap_width:  f32,
	lines_range: Range,
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

Clip_Info :: struct {
	value: f32,
	scale: f32,
	min:   f32,
	max:   f32,
	kind:  Clip_Kind,
}

Clip :: struct {
	info:  [2]Clip_Info,
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
	text_info:                       Text_Info,
	rect:                            Rect, // Info about current frame processed rect
	total_children, z_index:         int,
	detached_children:               [2]int, // [TODO]: Impl this
	first, last, prev, next, parent: Widget_Index,
}

Form :: struct {
	image:       rawptr,
	z_offset:    int,
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
	anims:               [dynamic]Animation,
	styles:              [dynamic]Style,
	temp:                [dynamic]^Widget,
	growable:            [dynamic]Growable,
	widgets:             [dynamic]Widget,
	lines:               [dynamic]string,
	render_commands:     [dynamic]Render_Command,
	measured_words:      [dynamic]Measured_Word,
	persistant:          Persistant_Data,
	measure_text_width:  proc(text: string, style: Text_Style) -> f32,
	measure_text_height: proc(style: Text_Style) -> f32,
	mouse:               Mouse_Context,
	keyboard:            Keyboard_Context,
	window_size:         Vec2f32,
	timers:              Timers,
	z_offset_increment:  int,
}

Timers :: struct {
	frame_start:  time.Time,
	layout_start: time.Time,
	frame_time:   time.Duration,
	layout_time:  time.Duration,
}

Lookup_Data :: struct {
	form:           Form,
	info:           Info,
	z_index:        int,
	text_size:      Vec2f32,
	text_position:  Vec2f32,
	text_min_width: f32,
	text_max_width: f32,
}

Persistant_Data :: struct {
	prev_styles:  [dynamic]Style,
	prev_anims:   [dynamic]Animation,
	anim_states:  map[Hash]Animation_State,
	prev_candids: map[Hash]struct{},
	curr_candids: map[Hash]struct{},
	prev_lookup:  map[Hash]Lookup_Data, // Swapped with curr_lookup at frame end
	curr_lookup:  map[Hash]Lookup_Data, // Cleared at frame start
	clip:         map[Hash]Vec2f32,
}

init_context :: proc(size: int) -> Core_Context {
	ctx: Core_Context
	ctx.timers.frame_start = time.now()
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
	delete(ctx.anims)
	delete(ctx.text)

	delete(ctx.persistant.anim_states)
	delete(ctx.persistant.curr_lookup)
	delete(ctx.persistant.prev_lookup)
	delete(ctx.persistant.prev_styles)
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

	widget.z_index += ctx.z_offset_increment
	ctx.z_offset_increment += 5 // a widget can atmost emit 5 commands

	ctx.persistant.curr_lookup[info.hash] = {
		info = info,
		form = form,
	}

	if form.animation != 0 {ctx.persistant.curr_candids[widget.info.hash] = {}}

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
		widget.z_index += parent.form.z_offset
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
	widget.info.rect = data.info.rect
	widget.text_info.size = data.text_size
	widget.text_info.min_width = data.text_min_width
	widget.text_info.max_width = data.text_max_width
}

_write_widget_persistant_data :: proc(ctx: ^Core_Context, widget: ^Widget) {
	data := &ctx.persistant.curr_lookup[widget.info.hash]
	data.info.rect = widget.rect
	data.text_size = widget.text_info.size
	data.text_position = widget.text_info.position
	data.text_min_width = widget.text_info.min_width
	data.text_max_width = widget.text_info.max_width
	data.z_index = widget.z_index
}

push_parent :: proc(ctx: ^Core_Context, info: Info) {
	ctx.active_parent = info.index
}

pop_parent :: proc(ctx: ^Core_Context) {
	ctx.active_parent = ctx.widgets[ctx.active_parent].parent
}

begin :: proc(ctx: ^Core_Context) {
	ctx.active_parent = -1
	ctx.z_offset_increment = 0
	clear(&ctx.lines)
	clear(&ctx.widgets)
	clear(&ctx.render_commands)

	clear(&ctx.text)
	clear(&ctx.clips)
	clear(&ctx.styles)
	clear(&ctx.overrides)
	clear(&ctx.anims)

	// Valid 0 states
	append(&ctx.text, Text{})
	append(&ctx.clips, Clip{})
	append(&ctx.styles, Style{})
	append(&ctx.overrides, Override{})
	append(&ctx.anims, Animation{})

	clear(&ctx.temp)
	clear(&ctx.persistant.curr_lookup)
	clear(&ctx.persistant.curr_candids)

	ctx.timers.frame_time = time.diff(ctx.timers.frame_start, time.now())
	ctx.timers.frame_start = time.now()
	ctx.timers.layout_start = time.now()
}

end :: proc(ctx: ^Core_Context) {
	_sizing_pass(ctx)
	_positioning_pass(ctx)
	_post_layout_pass(ctx)
}
