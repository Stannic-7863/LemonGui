package core_ui

import "core:fmt"
import "core:container/lru"
import "core:time"
import "core:unicode/utf8"

Axis :: enum {
	X,
	Y,
}

Min_Max :: struct {
	min, max: f32,
}

Value :: struct {
	value: f32,
}

Fit :: distinct Min_Max
Grow :: distinct Min_Max
Fixed :: distinct Value
Percent :: distinct Value
Ratio :: distinct Value

Sizing :: union #no_nil {
	Fit,
	Grow,
	Percent,
	Fixed,
	Ratio,
}

Space :: enum u8 {
	Between, // equal spacing between children excluding the edges
	Around, // equal amount of space on both sides of a child
	Evenly, // space is shared equally around borders and between children
}

Align :: enum u8 {
	Negative, // -y, -x, left, up
	Center, // 0, 0
	Positive, // +x, +y, right, down
}

Placement :: union #no_nil {
	Align,
	Space,
}

Percent_Self :: distinct Value

Override_Transform :: union {
	Fixed,
	Percent,
	Percent_Self,
}

Layout_Flag :: enum u8 {
	No_Positioning,
	No_Clip_Offset,
	No_Size_Propagation,
	No_Positioning_Relative,
}

Layout_Flags :: bit_set[Layout_Flag]

Override :: struct {
	offset: [2]Override_Transform,
	expand: [2]Override_Transform,
}

Layout :: struct {
	padding:          [2]Vec2f32,
	margin:           [2]Vec2f32,
	sizing:           [2]Sizing,
	accumulating_min: [2]f32,
	child_gap:        f32,
	placement:        [2]Placement,
	flags:            [2]Layout_Flags,
	direction:        Axis,
}

Growable :: struct {
	size:     ^f32,
	min, max: f32,
}

Measured_Word :: struct {
	word: string,
	spaces: int,
	start:  int,
	width:  f32,
}

_sizing_pass :: proc(ctx: ^Core_Context) {
	ctx.timers.sizing_fit_start.x = time.now()
	_resolve_fit_sizing(ctx, .X)
	ctx.timers.sizing_fit_time.x = time.diff(ctx.timers.sizing_fit_start.x, time.now())
	ctx.timers.sizing_other_start.x = time.now()
	_resolve_other_sizing(ctx, .X)
	ctx.timers.sizing_other_time.x = time.diff(ctx.timers.sizing_other_start.x, time.now())
	ctx.timers.word_wrap_start = time.now()
	_resolve_word_wrap(ctx)
	ctx.timers.word_wrap_time = time.diff(ctx.timers.word_wrap_start, time.now())
	ctx.timers.sizing_fit_start.y = time.now()
	_resolve_fit_sizing(ctx, .Y)
	ctx.timers.sizing_fit_time.y = time.diff(ctx.timers.sizing_fit_start.y, time.now())
	ctx.timers.sizing_other_start.y = time.now()
	_resolve_other_sizing(ctx, .Y)
	ctx.timers.sizing_other_time.y = time.diff(ctx.timers.sizing_other_start.y, time.now())
	ctx.timers.word_wrap_start = time.now()
}

_positioning_pass :: proc(ctx: ^Core_Context) {
	prev_hovered, prev_active := ctx.mouse.hovered, ctx.mouse.active

	ctx.mouse.active_disabled = false
	ctx.mouse.hovered_character_index = -1
	if !ctx.mouse.hover_is_locked {ctx.mouse.hovered = 0}
	if !ctx.mouse.active_is_locked {ctx.mouse.active = 0}

	hovered_widget := (^Widget)(nil)

	positioning_loop: for &widget, i in ctx.widgets {
		_position_layout_widget_children(ctx, &widget)
		_write_widget_persistant_data(ctx, &widget)
		widget_style := get_style(ctx, widget.form.style)
		if is_point_in_rect(widget.rect, ctx.mouse.position, widget_style.border) &&
		   .Disable_Hover not_in widget.form.event_flags &&
		   !ctx.mouse.hover_is_locked {

			if hovered_widget != nil {
				if hovered_widget.form.z_offset > widget.form.z_offset { continue }
			}

			for p := widget.clip_parent; p != -1; {
				clip_parent := get_widget(ctx, p)
				p = clip_parent.parent
				if widget.form.z_offset > clip_parent.form.z_offset { continue }
				if !is_point_in_rect(clip_parent.rect, ctx.mouse.position, get_style(ctx, clip_parent.form.style).border) {
					continue positioning_loop
				}
			}

			hovered_widget = &widget

			widget_clip := ctx.clips[widget.form.clip]
			if widget_clip.info.x.kind != .None || widget_clip.info.y.kind != .None {
				ctx.mouse.hovered_clip = widget_clip.hash
			}
			ctx.mouse.hovered = widget.info.hash
			ctx.mouse.can_lock_active = .Lock_Active in widget.form.event_flags
			ctx.mouse.can_lock_hover = .Lock_Hover in widget.form.event_flags
			ctx.mouse.active_disabled = .Disable_Active in widget.form.event_flags
		}
	}

	if ctx.mouse.active == 0 && ctx.mouse.mapped_events != {} {
		ctx.mouse.active = prev_active
	}

	if hovered_widget == nil { return }
	if hovered_widget.form.text == 0 { return }
	text := get_text(ctx, hovered_widget.form.text)
	style := get_style(ctx, hovered_widget.form.style)
	height := ctx.measure_text_height(style.text)
	spacing := style.text.line_spacing
	lines := ctx.lines[hovered_widget.text_info.lines_range.start:hovered_widget.text_info.lines_range.end]
	for line in lines {
		pos := line.position
		pos += hovered_widget.rect.scroll_offset
		if ctx.mouse.position.y - spacing < pos.y || ctx.mouse.position.y > pos.y + height + spacing { continue }
		_get_measured_words(ctx, line.line, style.text)
		space_width := ctx.measure_text_width(" ", style.text)
		accumulated_width := f32(0)
		for w in ctx.measured_words {
			if ctx.mouse.position.x >= pos.x + accumulated_width && ctx.mouse.position.x <= pos.x + accumulated_width + w.width {
				p := pos.x + accumulated_width
				index, ok := ctx.measure_text_hover_index(w.word, ctx.mouse.position - pos - {accumulated_width, 0}, style.text, text.user_data)
				if ok {
					ctx.mouse.hovered_character, _ = utf8.decode_rune_in_string(w.word[index:])
					ctx.mouse.hovered_character_index = w.start + index + line.start
				} else {
					ctx.mouse.hovered_character = ' '
					ctx.mouse.hovered_character_index = 0
				}
				break
			}
			accumulated_width += w.width + f32(w.spaces) * space_width
	 	}
		clear(&ctx.measured_words)
	}
}

_post_layout_pass :: proc(ctx: ^Core_Context) {
	for &clip in ctx.clips {
		if ctx.mouse.hovered_clip == clip.hash {
			for &info in clip.info {
				if info.kind == .Auto {
					info.value += ctx.mouse.scroll * info.scale
				}
				info.value = max(info.min, info.value)
				info.value = min(info.max, info.value)
			}
		}
		ctx.persistant.clips[clip.hash] = {clip.info.x.value, clip.info.y.value}
	}

	for &selection in ctx.selections {
		selection_persistant, ok := &ctx.persistant.selections[selection.hash]
		if !ok {
			ctx.persistant.selections[selection.hash] = {}
			selection_persistant = &ctx.persistant.selections[selection.hash]
		}
		selection_persistant.cursor = selection.cursor
		selection_persistant.anchor = selection.anchor
	}

	_resolve_events(ctx)
	_resolve_animations(ctx)
	_emit_render_commands(ctx)
	sort_render_commands(ctx.render_commands[:])

	ctx.mouse.hovered_clip = 0
	ctx.mouse.mapped_events = {}
	ctx.keyboard.mapped_events = {}
	ctx.persistant.prev_styles, ctx.styles = ctx.styles, ctx.persistant.prev_styles
	ctx.persistant.prev_lookup, ctx.persistant.curr_lookup = ctx.persistant.curr_lookup, ctx.persistant.prev_lookup
	ctx.persistant.prev_candids, ctx.persistant.curr_candids = ctx.persistant.curr_candids, ctx.persistant.prev_candids
	ctx.persistant.prev_anims, ctx.anims = ctx.anims, ctx.persistant.prev_anims
}

_resolve_fit_sizing :: proc(ctx: ^Core_Context, axis: Axis) #no_bounds_check {
	#reverse for &widget in ctx.widgets {
		layout := &widget.form.layout
		#partial switch kind in layout.sizing[axis] {
		case Fit:
			layout.accumulating_min[axis] += _get_axis_spacing(axis, layout.padding)
			layout.accumulating_min[axis] += layout.direction == axis ? _get_child_gap(&widget, axis) : 0
			layout.accumulating_min[axis] = max(layout.accumulating_min[axis], kind.min)
			layout.accumulating_min[axis] = min(layout.accumulating_min[axis], kind.max)
		case Grow:
			layout.accumulating_min[axis] = max(layout.accumulating_min[axis], kind.min)
			layout.accumulating_min[axis] += layout.direction == axis ? _get_child_gap(&widget, axis) : 0
			layout.accumulating_min[axis] += _get_axis_spacing(axis, layout.padding)
		case Fixed:
			layout.accumulating_min[axis] = kind.value
		case Ratio:
			layout.accumulating_min[axis] = kind.value * widget.info.rect.size[_get_other_axis(axis)]
		}

		#partial switch kind in layout.sizing[axis] {
		case Fit, Grow:
			size := Vec2f32{widget.text_info.min_width, widget.text_info.size.y}
			padding := _get_axis_spacing(axis, layout.padding)
			layout.accumulating_min[axis] = layout.direction == axis ? layout.accumulating_min[axis] + size[axis] : max(layout.accumulating_min[axis], size[axis] + padding)
			if widget.form.text != 0 {
				layout.accumulating_min[axis] += layout.direction == axis ? layout.child_gap : 0
			}
		}

		widget.rect.size[axis] = max(layout.accumulating_min[axis], widget.rect.size[axis])

		if widget.parent == -1 {continue}
		parent := get_widget(ctx, widget.parent)
		parent_clip_kind := get_clip(ctx, parent.form.clip).info[axis].kind

		if .No_Size_Propagation not_in layout.flags[axis] && parent_clip_kind == .None {
			parent_layout := &parent.form.layout
			if parent_layout.direction == axis {
				parent_layout.accumulating_min[axis] += widget.rect.size[axis] + _get_axis_spacing(axis, layout.margin)
			} else {
				parent_layout.accumulating_min[axis] = max(parent_layout.accumulating_min[axis], widget.rect.size[axis] + _get_axis_spacing(axis, layout.margin))
			}
		}
	}
}

_resolve_other_sizing :: proc(ctx: ^Core_Context, axis: Axis) {
	for &widget in ctx.widgets {
		widget.text_info.wrap_width = axis == .X ? min(widget.rect.size.x - _get_axis_spacing(.X, widget.form.layout.padding), widget.text_info.max_width) : 0
		if widget.first == -1 {continue}

		total_child_gap := _get_child_gap(&widget, axis)
		total_padding := _get_axis_spacing(axis, widget.form.layout.padding)

		if widget.form.layout.direction == axis {
			clear(&ctx.growable)
			defer clear(&ctx.growable)

			available := widget.rect.size[axis] - (total_child_gap + total_padding)

			for child_index := widget.first; child_index != -1; {
				child := get_widget(ctx, child_index)
				child_index = child.next
				#partial switch kind in child.form.layout.sizing[axis] {
				case Grow:
					child.rect.size[axis] = min(child.rect.size[axis], kind.max)
					if .No_Size_Propagation not_in child.form.layout.flags[axis] {
						append(&ctx.growable, Growable{&child.rect.size[axis], child.rect.size[axis], kind.max})
					}
				case Percent:
					FLOATING_FLAGS :: Layout_Flags{.No_Positioning, .No_Positioning_Relative}
					if FLOATING_FLAGS & child.form.layout.flags[axis] != {} {
						child.rect.size[axis] = widget.rect.size[axis] * kind.value
					} else {
						child.rect.size[axis] = (widget.rect.size[axis] - total_child_gap - total_padding) * kind.value
					}
				}

				if .No_Size_Propagation not_in child.form.layout.flags[axis] {
					available -= child.rect.size[axis] + _get_axis_spacing(axis, child.form.layout.margin)
				}
			}

			if widget.form.text != 0 {
				available -= widget.form.layout.child_gap
				size := Vec2f32{widget.text_info.min_width, widget.text_info.size.y}
				available -= size[axis]
				if axis == .X {
					widget.text_info.wrap_width = widget.text_info.min_width
					append(&ctx.growable, Growable{&widget.text_info.wrap_width, widget.text_info.min_width, widget.text_info.max_width})
				}
			}

			if len(ctx.growable) == 0 {continue}

			if available > 0 {
				_resolve_grow(ctx, available)
			} else {
				_resolve_shrink(ctx, abs(available))
			}
		} else {
			for child_index := widget.first; child_index != -1; {
				child := get_widget(ctx, child_index)
				child_index = child.next
				child_layout := child.form.layout
				#partial switch kind in child_layout.sizing[axis] {
				case Grow:
					child.rect.size[axis] = widget.rect.size[axis] - total_padding - _get_axis_spacing(axis, child.form.layout.margin)
					child.rect.size[axis] = max(child.rect.size[axis], child_layout.accumulating_min[axis])
					child.rect.size[axis] = min(child.rect.size[axis], kind.max)
				case Percent:
					FLOATING_FLAGS :: Layout_Flags{.No_Positioning, .No_Positioning_Relative}
					if FLOATING_FLAGS & child.form.layout.flags[axis] != {} {
						child.rect.size[axis] = widget.rect.size[axis] * kind.value
					} else {
						child.rect.size[axis] = (widget.rect.size[axis] - total_child_gap - total_padding) * kind.value
					}
				}
			}
		}
	}
}

_resolve_grow :: proc(ctx: ^Core_Context, available: f32) {
	available := available

	for available > 1e-4 && len(ctx.growable) > 0 {
		smallest, second_smallest, to_add: f32 = max(f32), max(f32), 0
		for g, i in ctx.growable {
			if g.size^ < smallest {
				second_smallest = smallest
				smallest = g.size^
			}
			if g.size^ >= smallest {
				second_smallest = min(g.size^, second_smallest)
				to_add = abs(second_smallest - smallest)
			}
		}

		to_add = max(to_add, available / f32(len(ctx.growable)))

		#reverse for g, i in ctx.growable {
			if g.size^ == smallest {
				g.size^ += to_add
				available -= to_add
			}

			if g.size^ >= g.max {
				unordered_remove(&ctx.growable, i)
				difference := abs(g.size^ - g.max)
				available += difference
				g.size^ = g.max
			}
		}
	}
}

_resolve_shrink :: proc(ctx: ^Core_Context, available: f32) {
	available := available

	for available > 1e-2 && len(ctx.growable) > 0 {
		largest, second_largest, to_subtract: f32 = ctx.growable[0].size^, min(f32), 0

		for g in ctx.growable {
			if g.size^ > largest {
				second_largest = largest
				largest = g.size^
			}
			if g.size^ <= largest {
				second_largest = max(g.size^, second_largest)
				to_subtract = largest - second_largest
			}
		}

		to_subtract = max(to_subtract, available / f32(len(ctx.growable)))

		#reverse for g, i in ctx.growable {
			if g.size^ == largest {
				g.size^ -= to_subtract
				available -= to_subtract
			}
			if g.size^ <= g.min {
				difference := abs(g.size^ - g.min)
				available += difference
				g.size^ = g.min
				unordered_remove(&ctx.growable, i)
			}
		}
	}
}

_resolve_word_wrap :: proc(ctx: ^Core_Context) {
	for &widget in ctx.widgets {
		if widget.form.text == 0 {continue}
		text := get_text(ctx, widget.form.text)
		switch text.wrap_mode {
		case .Words:
			style := ctx.styles[widget.form.style]
			_get_measured_words(ctx, text.text, style.text)
			defer clear(&ctx.measured_words)

			size: Vec2f32
			acc_size: Vec2f32
			maximum_width: f32
			minimum_width: f32
			new_line_index: int
			text_height := ctx.measure_text_height(style.text)

			space_width := ctx.measure_text_width(" ", style.text)
			start := len(ctx.lines)

			padding := _get_axis_spacing(.X, widget.form.layout.padding)

			for word, index in ctx.measured_words {
				maximum_width += word.width + f32(word.spaces) * space_width
				if word.word == "\n" {
					size.x = max(acc_size.x, size.x)
					append(&ctx.lines, Text_Line{line = text.text[new_line_index:word.start], start = new_line_index, end = word.start, width = acc_size.x})
					acc_size.x = 0
					new_line_index = word.start
					if index == len(ctx.measured_words) - 1 {
						acc_size.y += (text_height + style.text.line_spacing)
					}
					continue
				}
				minimum_width = max(minimum_width, word.width)
				acc_size.x += space_width * f32(word.spaces)
				if acc_size.x + word.width > widget.text_info.wrap_width {
					size.x = max(acc_size.x, size.x)
					append(&ctx.lines, Text_Line{line = text.text[new_line_index:word.start], start = new_line_index, end = word.start, width = acc_size.x})
					acc_size.x = 0
					new_line_index = word.start
				}
				acc_size.x += word.width
			}

			size.x = max(acc_size.x, size.x)
			if new_line_index < len(text.text) {
				append(&ctx.lines, Text_Line{line = text.text[new_line_index:], start = new_line_index, end = len(text.text), width = acc_size.x})
			}

			widget.text_info.lines_range.start = i32(start)
			widget.text_info.lines_range.end = i32(len(ctx.lines))
			size.y = f32(i32(len(ctx.lines)) - i32(start)) * (text_height + style.text.line_spacing) + acc_size.y
			widget.text_info.size = size
			widget.text_info.max_width = min(text.preferred_max, maximum_width)
			widget.text_info.min_width = max(text.preferred_min, minimum_width)
		case .None:
			style := ctx.styles[widget.form.style]
			append(&ctx.lines, Text_Line{line = text.text, start = 0, end = len(text.text), width = widget.text_info.min_width})
			widget.text_info.lines_range.start = i32(len(ctx.lines) - 1)
			widget.text_info.lines_range.end = i32(len(ctx.lines))
			y := ctx.measure_text_height(style.text)
			widget.text_info.min_width = _measure_text_width_cached(ctx, text.text, style.text)
			widget.text_info.size = {widget.text_info.min_width, y}
			widget.text_info.max_width = widget.text_info.min_width
		}
	}
}

_get_measured_words :: proc(ctx: ^Core_Context, text: string, style: Text_Style) {
	word_start := 0
	spaces_before := 0
	data := transmute([]u8)text
	byte_index := 0

	for byte_index < len(data) {
		r, size := utf8.decode_rune_in_bytes(data[byte_index:])

		if r == '\n' {
			if byte_index > word_start {
				word := text[word_start:byte_index]
				width := _measure_text_width_cached(ctx, word, style)
				append(&ctx.measured_words, Measured_Word{word = word, width = width, start = word_start})
			}
			byte_index += size
			word_start = byte_index
			append(&ctx.measured_words, Measured_Word{word = "\n", spaces = spaces_before, start = word_start})
			spaces_before = 0
			continue
		}

		if r == ' ' {
			for byte_index < len(data) {
				r2, size2 := utf8.decode_rune_in_bytes(data[byte_index:])
				if r2 != ' ' {break}
				spaces_before += 1
				byte_index += size2
			}
			word_start = byte_index
			continue
		}

		start := byte_index
		for byte_index < len(data) {
			r2, size2 := utf8.decode_rune_in_bytes(data[byte_index:])
			if r2 == ' ' || r2 == '\n' {break}
			byte_index += size2
		}

		word := text[start:byte_index]
		width := _measure_text_width_cached(ctx, word, style)
		append(&ctx.measured_words, Measured_Word{word = word, width = width, spaces = spaces_before, start = start})
		word_start = byte_index
		spaces_before = 0
	}

	if word_start < len(data) {
		word := text[word_start:]
		width := _measure_text_width_cached(ctx, word, style)
		append(&ctx.measured_words, Measured_Word{word = word, width = width, spaces = spaces_before, start = word_start})
	}
}

_measure_text_width_cached :: proc(ctx: ^Core_Context, word: string, style: Text_Style) -> f32 {
	k := Text_Cache_Key {
		font           = style.font,
		font_size      = style.font_size,
		letter_spacing = style.letter_spacing,
		word           = word,
	}

	w, ok := lru.get(&ctx.persistant.cached_words, k)

	if ok {return w} else {
		w := ctx.measure_text_width(word, style)
		lru.set(&ctx.persistant.cached_words, k, w)
		return w
	}
	return 0
}

_position_layout_widget_children :: proc(ctx: ^Core_Context, widget: ^Widget) #no_bounds_check {
	total_size: [Axis]f32
	layout := widget.form.layout
	axis := layout.direction
	other_axis := _get_other_axis(axis)

	for child_index := widget.first; child_index != -1; {
		child := get_widget(ctx, child_index)
		child_index = child.next

		IGNORE_FLAGS :: Layout_Flags{.No_Positioning, .No_Clip_Offset, .No_Positioning_Relative}

		if IGNORE_FLAGS & child.form.layout.flags[axis] == {} {
			total_size[axis] += child.rect.size[axis] + _get_axis_spacing(axis, child.form.layout.margin)
		}

		if IGNORE_FLAGS & child.form.layout.flags[other_axis] == {} {
			total_size[other_axis] = max(total_size[other_axis], child.rect.size[other_axis] + _get_axis_spacing(other_axis, child.form.layout.margin))
		}
	}

	total_size[axis] += _get_child_gap(widget, axis) + widget.text_info.size[axis]
	available_size := widget.rect.size[axis] - _get_axis_spacing(axis, widget.form.layout.padding) - total_size[axis] + _get_child_gap(widget, axis)
	widget.rect.content_size[axis] = total_size[axis] + _get_axis_spacing(axis, widget.form.layout.padding)
	widget.rect.content_size[other_axis] = total_size[other_axis] + _get_axis_spacing(other_axis, widget.form.layout.padding)

	increment: Vec2f32
	computed_child_gap := layout.child_gap

	switch layout.placement[axis] {
	case .Negative:
		increment[axis] = widget.rect.position[axis] + widget.form.layout.padding[axis][0]
	case .Positive:
		increment[axis] = widget.rect.position[axis] + widget.rect.size[axis] - widget.form.layout.padding[axis][1] - total_size[axis]
	case .Center:
		increment[axis] = widget.rect.position[axis] + (widget.rect.size[axis] - total_size[axis]) / 2
	case .Around:
		computed_child_gap = available_size / f32(max(1, widget.total_children - widget.detached_children[axis]))
		increment[axis] = widget.rect.position[axis] + widget.form.layout.padding[axis].x + computed_child_gap / 2
	case .Evenly:
		computed_child_gap = available_size / f32(max(1, widget.total_children + 1 - widget.detached_children[axis]))
		increment[axis] = widget.rect.position[axis] + widget.form.layout.padding[axis].x + computed_child_gap
	case .Between:
		computed_child_gap = available_size / f32(max(1, widget.total_children - 1 - widget.detached_children[axis]))
		increment[axis] = widget.rect.position[axis] + widget.form.layout.padding[axis].x
	}

	switch layout.placement[other_axis] {
	case .Negative:
		increment[other_axis] = widget.rect.position[other_axis] + widget.form.layout.padding[other_axis].x
	case .Positive:
		increment[other_axis] = widget.rect.position[other_axis] + widget.rect.size[other_axis] - widget.form.layout.padding[other_axis].y
	case .Center, .Between, .Around, .Evenly:
		increment[other_axis] = widget.rect.position[other_axis] + widget.rect.size[other_axis] / 2
	}

	widget.text_info.position = increment
	increment[axis] += widget.text_info.size[axis]

	if widget.form.text != 0 {
		increment[axis] += computed_child_gap
		switch layout.placement[other_axis] {
		case .Negative:
			widget.text_info.position[other_axis] += widget.form.layout.margin[other_axis].x
		case .Positive:
			widget.text_info.position[other_axis] -= widget.text_info.size[other_axis] + widget.form.layout.margin[other_axis].y
		case .Center, .Between, .Around, .Evenly:
			widget.text_info.position[other_axis] -= widget.text_info.size[other_axis] / 2
		}
	}

	{
		lines := ctx.lines[widget.text_info.lines_range.start:widget.text_info.lines_range.end]
		t := get_style(ctx, widget.form.style)
		h := ctx.measure_text_height(t.text)
		p := widget.text_info.position
		for &l in lines {
			l.position = p
			p.y += h + t.text.line_spacing
		}
	}

	clip_axis := get_clip_value(ctx, widget.form.clip, axis)
	clip_other_axis := get_clip_value(ctx, widget.form.clip, other_axis)

	for child_index := widget.first; child_index != -1; {
		child := get_widget(ctx, child_index)
		child_index = child.next

		IGNORE_FLAGS :: Layout_Flags{.No_Positioning, .No_Positioning_Relative}

		if IGNORE_FLAGS & child.form.layout.flags[axis] == {} {
			increment[axis] += child.form.layout.margin[axis].x
			child.rect.position[axis] = increment[axis]
			increment[axis] += child.rect.size[axis] + computed_child_gap + child.form.layout.margin[axis].y
		} else {
			child.rect.position[axis] = 0
			if .No_Positioning_Relative in child.form.layout.flags[axis] {
				child.rect.position[axis] = widget.rect.position[axis]
			}
		}

		if IGNORE_FLAGS & child.form.layout.flags[other_axis] == {} {
			switch layout.placement[other_axis] {
			case .Negative:
				child.rect.position[other_axis] = increment[other_axis] + child.form.layout.margin[other_axis].x
			case .Positive:
				child.rect.position[other_axis] = increment[other_axis] - child.rect.size[other_axis] - child.form.layout.margin[other_axis].y
			case .Center, .Between, .Around, .Evenly:
				child.rect.position[other_axis] = increment[other_axis] - child.rect.size[other_axis] / 2
			}
		} else {
			child.rect.position[other_axis] = 0
			if .No_Positioning_Relative in child.form.layout.flags[other_axis] {
				child.rect.position[other_axis] = widget.rect.position[other_axis]
			}
		}

		NO_CLIP :: Layout_Flags{.No_Clip_Offset}

		if NO_CLIP & child.form.layout.flags[axis] == {} {
			child.rect.scroll_offset[axis] = clip_axis + widget.rect.scroll_offset[axis]
		} else {
			child.rect.scroll_offset[axis] = widget.rect.scroll_offset[axis]
		}

		if NO_CLIP & child.form.layout.flags[other_axis] == {} {
			child.rect.scroll_offset[other_axis] = clip_other_axis + widget.rect.scroll_offset[other_axis]
		} else {
			child.rect.scroll_offset[other_axis] = widget.rect.scroll_offset[other_axis]
		}

		child_overrides := get_override(ctx, child.form.override)
		offset_axis, offset_other_axis := f32(0), f32(0)
		expand_axis, expand_other_axis := f32(0), f32(0)

		for child_override in child_overrides {
			expand_axis += _get_override_transform_value(child_override.expand, child.rect.size, widget.rect.size, axis)
			expand_other_axis += _get_override_transform_value(child_override.expand, child.rect.size, widget.rect.size, other_axis)
			offset_axis += _get_override_transform_value(child_override.offset, child.rect.size, widget.rect.size, axis)
			offset_other_axis += _get_override_transform_value(child_override.offset, child.rect.size, widget.rect.size, other_axis)
		}

		child.rect.position[axis] += offset_axis
		child.rect.position[other_axis] += offset_other_axis
		child.rect.size[axis] += expand_axis
		child.rect.size[other_axis] += expand_other_axis
		child.rect.clip_offset[axis] = get_clip_value(ctx, child.form.clip, axis)
		child.rect.clip_offset[other_axis] = get_clip_value(ctx, child.form.clip, other_axis)
	}
}
