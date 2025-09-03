package core_ui

import "base:intrinsics"
import "core:fmt"
import "core:sort"
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
	No_Clip_Offset,
	No_Size_Propagation,
	No_Positioning_Relative,
}

Override_Flags :: bit_set[Override_Flag]

Override :: struct {
	offset:  [Axis]Override_Transform,
	expand:  [Axis]Override_Transform,
	z_index: int,
	flags:   [Axis]Override_Flags,
}

Growable :: struct {
	size:       ^f32,
	min, max:   f32,
	is_text:    bool,
	contribute: bool,
}

Measured_Word :: struct {
	string: string,
	spaces: int,
	start:  int,
	width:  f32,
}

_sizing_pass :: proc(ctx: ^Core_Context) {
	_resolve_fit_sizing(ctx, .X)
	_resolve_other_sizing(ctx, .X)
	_resolve_word_wrap(ctx)
	_resolve_fit_sizing(ctx, .Y)
	_resolve_other_sizing(ctx, .Y)
}

_positioning_pass :: proc(ctx: ^Core_Context) {
	clear(&ctx.persistant_data)

	if !ctx.mouse.can_lock_hover {ctx.mouse.hovered = 0}
	if !ctx.mouse.active_is_locked {ctx.mouse.active = 0}

	z_index_offset: int

	for child in ctx.pre {
		layout, is_layout := _get_layout(child)
		if is_layout {
			_position_layout_childs(ctx, child, layout)
		}
		_clamp_border_radius(child)
		_emit_render_commands(ctx, child, &z_index_offset)
		_write_persistant_data(ctx, child)
		if is_point_in_rect(child.rect, ctx.mouse.position, child.style.border) &&
		   .Pointer_Passthrough not_in child.event_flags &&
		   !ctx.mouse.hover_is_locked {
			ctx.mouse.hovered = child.key.hash
			ctx.mouse.can_lock_active = .Lock_Active in child.event_flags
			ctx.mouse.can_lock_hover = .Lock_Hover in child.event_flags
		}
	}

	sort.quick_sort_proc(ctx.render_commands[:], proc(a, b: Render_Command) -> int {return a.z_index - b.z_index})

	ctx.mouse.events = {}
	ctx.keyboard.events = {}
	_resolve_events(ctx)
	ctx.mouse.mapped_events = {}
	ctx.keyboard.mapped_events = {}
}

_resolve_fit_sizing :: proc(ctx: ^Core_Context, axis: Axis) #no_bounds_check {
	#reverse for widget in ctx.post_r {
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
			case Fixed: widget_kind.accumulating_min[axis] = kind.value
			case Ratio: widget_kind.accumulating_min[axis] = kind.value * widget.resolved.size[_get_other_axis(axis)]
			}
			widget.rect.size[axis] = max(widget_kind.accumulating_min[axis], widget.rect.size[axis])
		case Text: if axis == .X {
				widget.rect.size[axis] = max(widget_kind.minimum_width, min(widget_kind.maximum_width, widget_kind.preferred_min))
			}
		}

		parent := widget.parent
		if parent == nil {continue}

		if .No_Size_Propagation not_in widget.override.flags[axis] && parent.clip.kind[axis] == .None {
			parent_kind := &parent.kind.(Layout)
			if parent_kind.direction == axis {
				parent_kind.accumulating_min[axis] += widget.rect.size[axis]
			} else {
				parent_kind.accumulating_min[axis] = max(parent_kind.accumulating_min[axis], widget.rect.size[axis])
			}
		}
	}
}

_resolve_other_sizing :: proc(ctx: ^Core_Context, axis: Axis) {
	for widget in ctx.pre {
		layout, is_layout := _get_layout(widget)
		if !is_layout {continue}
		if widget.first == nil {continue}

		total_child_gap := _get_child_gap(widget)
		total_padding := _get_axis_padding(axis, widget.style.padding)

		if layout.direction == axis {
			clear(&ctx.growable)
			defer clear(&ctx.growable)

			available := widget.rect.size[axis] - (total_child_gap + total_padding)

			for child := widget.first; child != nil; child = child.next {
				switch child_kind in child.kind {
				case Layout: #partial switch kind in child_kind.sizing[axis] {
					case Grow:
						contribute := .No_Size_Propagation not_in child.override.flags[axis]
						child.rect.size[axis] = min(child.rect.size[axis], kind.max)
						append(&ctx.growable, Growable{&child.rect.size[axis], child.rect.size[axis], kind.max, false, contribute})
					case Percent: child.rect.size[axis] = (widget.rect.size[axis] - total_child_gap - total_padding) * kind.value
					}
				case Text: if axis == .X {
						contribute := .No_Size_Propagation not_in child.override.flags[axis]
						child.rect.size[axis] = min(child_kind.maximum_width, child_kind.preferred_max)
						append(&ctx.growable, Growable{&child.rect.size[axis], child_kind.minimum_width, child.rect.size[axis], true, contribute})
					}
				}

				if .No_Size_Propagation not_in child.override.flags[axis] {
					available -= child.rect.size[axis]
				}
			}

			if len(ctx.growable) == 0 {continue}

			if available > 0 {
				_resolve_grow(ctx, available)
			} else {
				_resolve_shrink(ctx, abs(available))
			}
		} else {
			for child := widget.first; child != nil; child = child.next {
				switch child_kind in child.kind {
				case Layout: #partial switch kind in child_kind.sizing[axis] {
					case Grow:
						child.rect.size[axis] = widget.rect.size[axis] - total_padding
						child.rect.size[axis] = max(child.rect.size[axis], child_kind.accumulating_min[axis])
						child.rect.size[axis] = min(child.rect.size[axis], kind.max)
					case Percent: child.rect.size[axis] = (widget.rect.size[axis] - total_padding) * kind.value
					}
				case Text: if axis == .X {
						child.rect.size[axis] = min(child_kind.maximum_width, widget.rect.size[axis] - total_padding)
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

_resolve_word_wrap :: proc(ctx: ^Core_Context) {
	measured_words := make([dynamic]Measured_Word, context.temp_allocator)
	for widget in ctx.pre {
		switch &type in widget.kind {
		case Layout: continue
		case Text: switch type.wrap_mode {
			case .Words:
				_get_measured_words(ctx, type, &measured_words)
				defer clear(&measured_words)

				maximum_width: f32
				minimum_width: f32
				new_line_index: int
				accumulated_width: f32
				accumulated_height: f32

				space_width := ctx.measure_text_proc(" ", type.style)
				padding := _get_axis_padding(.X, widget.style.padding)
				start := len(ctx.lines)

				for word, index in measured_words {
					maximum_width += space_width * f32(word.spaces) + word.width
					if word.string == "\n" {
						accumulated_width = 0
						append(&ctx.lines, type.text[new_line_index:word.start])
						new_line_index = word.start
						if index == len(measured_words) - 1 {
							accumulated_height += (type.style.font_size + type.style.line_spacing)
						}
						continue
					}
					minimum_width = max(minimum_width, word.width)
					accumulated_width += space_width * f32(word.spaces)
					if accumulated_width + word.width > widget.rect.size.x - padding {
						accumulated_width = 0
						append(&ctx.lines, type.text[new_line_index:word.start])
						new_line_index = word.start
					}
					accumulated_width += word.width
				}

				if new_line_index < len(type.text) {
					append(&ctx.lines, type.text[new_line_index:])
				}

				type.start = start
				type.end = len(ctx.lines)
				widget.rect.size.y =
					f32(type.end - type.start) * (type.style.font_size + type.style.line_spacing) +
					accumulated_height +
					_get_axis_padding(.Y, widget.style.padding)
				type.minimum_width = minimum_width + padding
				type.maximum_width = maximum_width + padding
			case .None:
				append(&ctx.lines, type.text)
				type.start = len(ctx.lines) - 1
				type.end = len(ctx.lines)
				widget.rect.size.y = type.style.font_size
				type.maximum_width = ctx.measure_text_proc(type.text, type.style)
				type.minimum_width = type.maximum_width
			}
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
				append(measured_words, Measured_Word{string = word, width = width, start = word_start_byte_index})
			}
			byte_index += 1
			word_start_byte_index = byte_index
			append(measured_words, Measured_Word{string = "\n", spaces = spaces_before_word, start = word_start_byte_index})
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
		append(measured_words, Measured_Word{string = word, width = width, spaces = spaces_before_word, start = word_start_byte_index})
		word_start_byte_index = byte_index
		spaces_before_word = 0
	}

	if word_start_byte_index < len(text.text) {
		word := text.text[word_start_byte_index:]
		width := ctx.measure_text_proc(word, text.style)
		append(measured_words, Measured_Word{string = word, width = width, spaces = spaces_before_word, start = word_start_byte_index})
	}
}

_position_layout_childs :: proc(ctx: ^Core_Context, widget: ^Widget, layout: Layout) #no_bounds_check {
	total_size: [Axis]f32
	axis := layout.direction
	other_axis := _get_other_axis(axis)

	for child := widget.first; child != nil; child = child.next {
		expand_axis := _get_override_transform_value(child.override.expand, child.rect.size, widget.rect.size, axis)
		expand_other_axis := _get_override_transform_value(child.override.expand, child.rect.size, widget.rect.size, other_axis)

		child.rect.size[axis] += expand_axis
		child.rect.size[other_axis] += expand_other_axis

		ignore_flags := Override_Flags{.No_Positioning, .No_Clip_Offset, .No_Positioning_Relative}

		if ignore_flags & child.override.flags[axis] == {} {
			total_size[axis] += child.rect.size[axis]
		} else {
			total_size[axis] -= layout.child_gap
		}
		if ignore_flags & child.override.flags[other_axis] == {} {
			total_size[other_axis] = max(total_size[other_axis], child.rect.size[other_axis])
		}
	}

	total_size[axis] += _get_child_gap(widget)

	widget.resolved.content_size[axis] = total_size[axis] + _get_axis_padding(axis, widget.style.padding)
	widget.resolved.content_size[other_axis] = total_size[other_axis] + _get_axis_padding(other_axis, widget.style.padding)

	increment: Vec2f32

	switch layout.alignment[axis] {
	case .Negative: increment[axis] = widget.rect.position[axis] + widget.style.padding[axis][0]
	case .Positive: increment[axis] = widget.rect.position[axis] + widget.rect.size[axis] - widget.style.padding[axis][1] - total_size[axis]
	case .Center: increment[axis] = widget.rect.position[axis] + (widget.rect.size[axis] - total_size[axis]) / 2
	}

	switch layout.alignment[other_axis] {
	case .Negative: increment[other_axis] = widget.rect.position[other_axis] + widget.style.padding[other_axis][0]
	case .Positive: increment[other_axis] = widget.rect.position[other_axis] + widget.rect.size[other_axis] - widget.style.padding[other_axis][1]
	case .Center: increment[other_axis] = widget.rect.position[other_axis] + widget.rect.size[other_axis] / 2
	}

	clip_axis := _get_clip_value(ctx, widget, axis)
	clip_other_axis := _get_clip_value(ctx, widget, other_axis)

	for child := widget.first; child != nil; child = child.next {
		offset_axis := _get_override_transform_value(child.override.offset, child.rect.size, widget.rect.size, axis)
		offset_other_axis := _get_override_transform_value(child.override.offset, child.rect.size, widget.rect.size, other_axis)

		ignore_flags := Override_Flags{.No_Positioning, .No_Positioning_Relative}

		if ignore_flags & child.override.flags[axis] == {} {
			child.rect.position[axis] = increment[axis]
			increment[axis] += child.rect.size[axis] + layout.child_gap + offset_axis
		} else {
			if .No_Positioning_Relative in child.override.flags[axis] {
				child.rect.position[axis] = widget.rect.position[axis]
			}
		}

		if ignore_flags & child.override.flags[other_axis] == {} {
			switch layout.alignment[other_axis] {
			case .Negative: child.rect.position[other_axis] = increment[other_axis]
			case .Positive: child.rect.position[other_axis] = increment[other_axis] - child.rect.size[other_axis]
			case .Center: child.rect.position[other_axis] = increment[other_axis] - child.rect.size[other_axis] / 2
			}
		} else {
			if .No_Positioning_Relative in child.override.flags[other_axis] {
				child.rect.position[other_axis] = widget.rect.position[other_axis]
			}
		}

		child.rect.position[axis] += offset_axis
		child.rect.position[other_axis] += offset_other_axis

		if .No_Clip_Offset not_in child.override.flags[axis] {
			child.rect.position[axis] += clip_axis
		}

		if .No_Clip_Offset not_in child.override.flags[other_axis] {
			child.rect.position[other_axis] += clip_other_axis
		}
	}
}
