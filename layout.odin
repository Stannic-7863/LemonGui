package core_ui

import "base:intrinsics"
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

Sizing :: union #no_nil {
	Fit,
	Grow,
	Percent,
	Fixed,
}

Alignment :: enum u8 {
	Negative, // -y, -x, left, up
	Center, // 0, 0
	Positive, // +x, +y, right, down
}

Percent_Self :: distinct Percent

Override_Transform :: union {
	Fixed,
	Percent,
	Percent_Self,
}

Override_Flag :: enum u8 {
	No_Positioning,
	No_Size_Propagation,
}

Override_Flags :: bit_set[Override_Flag]

Override :: struct {
	offset: [Axis]Override_Transform,
	expand: [Axis]Override_Transform,
	flags:  [Axis]Override_Flags,
}

Growable :: struct {
	size:       ^f32,
	min, max:   f32,
	is_text:    bool,
	contribute: bool,
}

Measured_Word :: struct {
	word:          string,
	word_start:    int,
	spaces_before: int,
	width:         f32,
}

_sizing_pass :: proc(ctx: ^Core_Context) {
	#reverse for n in ctx.post_r {
		_resolve_fit_sizing(ctx, n, .X)
	}

	for n in ctx.pre {
		layout, is_layout := _get_layout(n)
		if !is_layout {continue}
		if layout.direction == .X {
			_resolve_other_sizing_along_axis(ctx, n, .X)
		} else {
			_resolve_other_sizing_across_axis(ctx, n, .X)
		}
	}

	_resolve_word_wrap(ctx)

	#reverse for n in ctx.post_r {
		_resolve_fit_sizing(ctx, n, .Y)
	}

	for n in ctx.pre {
		layout, is_layout := _get_layout(n)
		if !is_layout {continue}
		if layout.direction == .Y {
			_resolve_other_sizing_along_axis(ctx, n, .Y)
		} else {
			_resolve_other_sizing_across_axis(ctx, n, .Y)
		}
	}
}

_positioning_pass :: proc(ctx: ^Core_Context) {
	z_index_offset: int
	for n in ctx.pre {
		layout, is_layout := _get_layout(n)
		if is_layout {
			_position_layout_childs(n, layout)
		}
		_emit_render_commands(ctx, n, &z_index_offset)

		if _is_point_in_rect(n.rect, ctx.mouse.position, n.style.border) && .Pointer_Passthrough not_in n.event_flags {
			ctx.mouse.hovered = n.key.hash
			ctx.mouse.hover_is_locker = .Lock_Active in n.event_flags
		}
	}
}

_resolve_fit_sizing :: proc(ctx: ^Core_Context, widget: ^Widget, axis: Axis) {
	switch &widget_kind in widget.kind {
	case Layout:
		#partial switch kind in widget_kind.sizing[axis] {
		case Fit:
			if widget_kind.direction == axis {
				widget_kind.accumulating_min[axis] += _get_child_gap(widget)
			}
			widget_kind.accumulating_min[axis] += _get_axis_padding(axis, widget.style.padding)
			widget_kind.accumulating_min[axis] = max(widget_kind.accumulating_min[axis], kind.min)
			widget_kind.accumulating_min[axis] = min(widget_kind.accumulating_min[axis], kind.max)
		case Grow:
			widget_kind.accumulating_min[axis] = max(widget_kind.accumulating_min[axis], kind.min)
			if widget_kind.direction == axis {
				widget_kind.accumulating_min[axis] += _get_child_gap(widget)
			}
			widget_kind.accumulating_min[axis] += _get_axis_padding(axis, widget.style.padding)
		case Fixed:
			widget_kind.accumulating_min[axis] = kind.value
		}
		widget.rect.size[axis] = max(widget_kind.accumulating_min[axis], widget.rect.size[axis])
	case Text:
		if axis == .X {
			widget_kind.maximum_width = ctx.measure_text_proc(widget_kind.text, widget_kind.style) + _get_axis_padding(axis, widget.style.padding)
			widget.rect.size[axis] = max(min(widget_kind.maximum_width, widget_kind.preferred_min), widget_kind.minimum_width)
		}
		widget.rect.size[axis] += _get_axis_padding(axis, widget.style.padding)
	}

	parent := widget.parent
	if parent == nil {return}

	if .No_Size_Propagation not_in widget.override.flags[axis] {
		parent_kind := &parent.kind.(Layout)
		if parent_kind.direction == axis {
			parent_kind.accumulating_min[axis] += widget.rect.size[axis]
		} else {
			parent_kind.accumulating_min[axis] = max(parent_kind.accumulating_min[axis], widget.rect.size[axis])
		}
	}
}

_resolve_other_sizing_along_axis :: proc(ctx: ^Core_Context, widget: ^Widget, axis: Axis) {
	if widget.first == nil {return}

	clear(&ctx.growable)
	defer clear(&ctx.growable)

	total_child_gap := _get_child_gap(widget)
	total_padding := _get_axis_padding(axis, widget.style.padding)
	available := widget.rect.size[axis] - (total_child_gap + total_padding)

	for child := widget.first; child != nil; child = child.next {
		switch child_kind in child.kind {
		case Layout:
			#partial switch kind in child_kind.sizing[axis] {
			case Grow:
				contribute := .No_Size_Propagation not_in child.override.flags[axis]
				child.rect.size[axis] = min(child.rect.size[axis], kind.max)
				append(&ctx.growable, Growable{&child.rect.size[axis], child.rect.size[axis], kind.max, false, contribute})
			case Percent:
				child.rect.size[axis] = (widget.rect.size[axis] - total_child_gap - total_padding) * kind.value
			}
		case Text:
			if axis == .X {
				contribute := .No_Size_Propagation not_in child.override.flags[axis]
				child.rect.size[axis] = child_kind.maximum_width
				child.rect.size[axis] = min(child.rect.size[axis], child_kind.preferred_max)
				append(&ctx.growable, Growable{&child.rect.size[axis], child_kind.minimum_width, child.rect.size[axis], true, contribute})
			}
		}

		if .No_Size_Propagation not_in child.override.flags[axis] {
			available -= child.rect.size[axis]
		}
	}

	if len(ctx.growable) == 0 {return}

	if available > 0 {
		_resolve_grow(ctx, available)
	} else {
		_resolve_shrink(ctx, abs(available))
	}
}

_resolve_grow :: proc(ctx: ^Core_Context, available: f32) {
	available := available

	for available > 1e-4 && len(ctx.growable) > 0 {
		smallest, second_smallest, to_add: f32 = max(f32), max(f32), 0
		for g, i in ctx.growable {
			if g.is_text {
				ordered_remove(&ctx.growable, i)
				continue
			}
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
				if g.contribute {
					available -= to_add
				}
			}

			if g.size^ >= g.max {
				ordered_remove(&ctx.growable, i)
				difference := abs(g.size^ - g.max)
				if g.contribute {
					available += difference
				}
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
				if g.contribute {
					available -= to_subtract
				}
			}
			if g.size^ <= g.min {
				difference := abs(g.size^ - g.min)
				if g.contribute {
					available += difference
				}
				g.size^ = g.min
				ordered_remove(&ctx.growable, i)
			}
		}
	}
}

_resolve_other_sizing_across_axis :: proc(ctx: ^Core_Context, widget: ^Widget, axis: Axis) {
	if widget.first == nil {return}

	total_padding := _get_axis_padding(axis, widget.style.padding)

	for child := widget.first; child != nil; child = child.next {
		switch child_kind in child.kind {
		case Layout:
			#partial switch kind in child_kind.sizing[axis] {
			case Grow:
				child.rect.size[axis] = widget.rect.size[axis] - total_padding
				child.rect.size[axis] = max(child.rect.size[axis], child_kind.accumulating_min[axis])
				child.rect.size[axis] = min(child.rect.size[axis], kind.max)
			case Percent:
				child.rect.size[axis] = (widget.rect.size[axis] - total_padding) * kind.value
			}
		case Text:
			if axis == .X {
				child.rect.size[axis] = min(child_kind.maximum_width, widget.rect.size[axis] - total_padding)
			}
		}
	}
}


_resolve_word_wrap :: proc(ctx: ^Core_Context) {
	measured_words := make([dynamic]Measured_Word, context.temp_allocator)
	for widget in ctx.pre {
		switch &type in widget.kind {
		case Layout:
			continue
		case Text:
			_get_measured_words(ctx, type, &measured_words)
			space_width := ctx.measure_text_proc(" ", type.style)
			line_start: int = 0
			largest_width: f32
			x_padding := _get_axis_padding(.X, widget.style.padding)
			widget_lines_start := len(ctx.text_lines)
			additional_height: f32 = 0
			accumulated_width: f32 = 0
			cursor_found: bool

			for w, index in measured_words {
				if w.word == "\n" {
					accumulated_width = 0
					append(&ctx.text_lines, type.text[line_start:w.word_start])
					line_start = w.word_start
					if index == len(measured_words) - 1 {
						additional_height += (type.style.font_size + type.style.line_spacing)
					}
					continue
				}
				largest_width = max(largest_width, w.width)
				accumulated_width += space_width * f32(w.spaces_before)
				if accumulated_width + w.width > widget.rect.size.x - x_padding {
					accumulated_width = 0
					append(&ctx.text_lines, type.text[line_start:w.word_start])
					line_start = w.word_start
				}
				accumulated_width += w.width
			}

			if line_start < len(type.text) {
				append(&ctx.text_lines, type.text[line_start:])
			}

			type.start = widget_lines_start
			type.end = len(ctx.text_lines)
			widget.rect.size.y = f32(type.end - type.start) * (type.style.font_size + type.style.line_spacing) + additional_height
			type.minimum_width = largest_width
			clear(&measured_words)
		}
	}
}

_get_measured_words :: proc(ctx: ^Core_Context, text: Text, measured_words: ^[dynamic]Measured_Word) {
	word_start_byte_index, spaces_before_word, byte_index: int

	for byte_index < len(text.text) {
		r := utf8.rune_at(text.text, byte_index)

		if r == '\n' {
			if byte_index > word_start_byte_index {
				word := text.text[word_start_byte_index:byte_index]
				width := ctx.measure_text_proc(word, text.style)
				append(measured_words, Measured_Word{word = word, width = width, word_start = word_start_byte_index})
			}
			byte_index += 1
			word_start_byte_index = byte_index
			append(measured_words, Measured_Word{word = "\n", spaces_before = spaces_before_word, word_start = word_start_byte_index})
			spaces_before_word = 0
			continue
		}

		if r == ' ' {
			for byte_index < len(text.text) {
				r2 := utf8.rune_at(text.text, byte_index)
				if r2 != ' ' {
					break
				}
				spaces_before_word += 1
				byte_index += 1
			}
			word_start_byte_index = byte_index
			continue
		}

		for byte_index < len(text.text) {
			r2 := utf8.rune_at(text.text, byte_index)
			if r2 == ' ' || r2 == '\n' {
				break
			}
			byte_index += 1
		}

		word := text.text[word_start_byte_index:byte_index]
		width := ctx.measure_text_proc(word, text.style)
		append(measured_words, Measured_Word{word = word, width = width, spaces_before = spaces_before_word, word_start = word_start_byte_index})
		word_start_byte_index = byte_index
		spaces_before_word = 0
	}

	if word_start_byte_index < len(text.text) {
		word := text.text[word_start_byte_index:]
		width := ctx.measure_text_proc(word, text.style)
		append(measured_words, Measured_Word{word = word, width = width, spaces_before = spaces_before_word, word_start = word_start_byte_index})
	}
}

_position_layout_childs :: proc(widget: ^Widget, layout: Layout) {
	total_size: f32
	axis := layout.direction
	other_axis := _get_other_axis(axis)

	for child := widget.first; child != nil; child = child.next {
		total_size += child.rect.size[axis]
	}
	total_size += max(0, layout.child_gap * f32(widget.total_children - 1))

	increment: Vec2f32

	switch layout.alignment[axis] {
	case .Negative:
		increment[axis] = widget.rect.position[axis] + widget.style.padding[axis][0]
	case .Positive:
		increment[axis] = widget.rect.position[axis] + widget.rect.size[axis] - widget.style.padding[axis][1] - total_size
	case .Center:
		increment[axis] = widget.rect.position[axis] + (widget.rect.size[axis] - total_size) / 2
	}

	switch layout.alignment[other_axis] {
	case .Negative:
		increment[other_axis] = widget.rect.position[other_axis] + widget.style.padding[other_axis][0]
	case .Positive:
		increment[other_axis] = widget.rect.position[other_axis] + widget.rect.size[other_axis] - widget.style.padding[other_axis][1]
	case .Center:
		increment[other_axis] = widget.rect.position[other_axis] + widget.rect.size[other_axis] / 2
	}

	for child := widget.first; child != nil; child = child.next {

		offset_value := _get_override_transform_value(child, axis)
		offset_value_other_axis := _get_override_transform_value(child, other_axis)

		if .No_Positioning not_in child.override.flags[axis] {
			child.rect.position[axis] = increment[axis]
			increment[axis] += child.rect.size[axis] + layout.child_gap + offset_value
		}

		if .No_Positioning not_in child.override.flags[other_axis] {
			switch layout.alignment[other_axis] {
			case .Negative:
				child.rect.position[other_axis] = increment[other_axis]
			case .Positive:
				child.rect.position[other_axis] = increment[other_axis] - child.rect.size[other_axis]
			case .Center:
				child.rect.position[other_axis] = increment[other_axis] - child.rect.size[other_axis] / 2
			}
		}

		child.rect.position[axis] += offset_value
		child.rect.position[other_axis] += offset_value_other_axis
	}
}

_get_override_transform_value :: proc(widget: ^Widget, axis: Axis) -> (offset_value: f32) {
	switch kind in widget.override.offset[axis] {
	case Percent_Self:
		offset_value = widget.rect.size[axis] * kind.value
	case Percent:
		offset_value = widget.rect.size[axis] * kind.value
	case Fixed:
		offset_value = kind.value
	}
	return offset_value
}

_get_other_axis :: proc(axis: Axis) -> Axis {
	return (Axis(int(axis) ~ int(max(Axis))))
}

_get_axis_padding :: proc(axis: Axis, padding: [Axis]Vec2f32) -> f32 {
	return padding[axis].x + padding[axis].y
}

_get_child_gap :: proc(widget: ^Widget) -> f32 {
	return max(0, f32(widget.total_children - 1) * widget.kind.(Layout).child_gap)
}

_get_layout :: proc(widget: ^Widget) -> (Layout, bool) {
	switch kind in widget.kind {
	case Layout:
		return kind, true
	case Text:
		return {}, false
	}
	unreachable()
}

_build_stacks :: proc(ctx: ^Core_Context) {
	append(&ctx.temp, &ctx.widgets[0])

	for {
		widget := pop_safe(&ctx.temp) or_break
		append(&ctx.post_r, widget)
		for child_widget := widget.first; child_widget != nil; child_widget = child_widget.next {
			append(&ctx.temp, child_widget)
		}
	}

	for &widget in ctx.widgets {
		append(&ctx.pre, &widget)
	}

	clear(&ctx.temp)
}
