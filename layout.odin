package core_ui

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
	clear(&ctx.persistant.widget)
	clear(&ctx.persistant.clip)

	prev_hovered, prev_active := ctx.mouse.hovered, ctx.mouse.active

	ctx.mouse.active_disabled = false
	if !ctx.mouse.hover_is_locked {ctx.mouse.hovered = 0}
	if !ctx.mouse.active_is_locked {ctx.mouse.active = 0}

	hovered_z_index: int = -1
	z_index_offset: int

	root := &ctx.widgets[0]
	root_override := &ctx.overrides[root.override]

	root_offset_x := _get_override_transform_value(root_override.offset, root.rect.size, 0, .X)
	root_offset_y := _get_override_transform_value(root_override.offset, root.rect.size, 0, .Y)

	root_expand_x := _get_override_transform_value(root_override.expand, root.rect.size, 0, .X)
	root_expand_y := _get_override_transform_value(root_override.expand, root.rect.size, 0, .Y)

	root_clip_x := _get_clip_value(ctx, root, .X)
	root_clip_y := _get_clip_value(ctx, root, .Y)

	root.rect.position += {root_offset_x + root_clip_x, root_offset_y + root_clip_y}
	root.rect.size += {root_expand_x, root_expand_y}

	for widget in ctx.pre {
		layout, is_layout := widget.kind.(Layout)
		if is_layout {
			_position_layout_widget_children(ctx, widget, layout)
		}

		widget_style := &ctx.styles[widget.style]
		prev_border_radius := widget_style.border.radius
		_clamp_border_radius(widget, widget_style)
		_resolve_widget_animation(ctx, widget)
		_emit_render_commands(ctx, widget, &z_index_offset, widget_style)
		_write_widget_persistant_data(ctx, widget)
		widget_style.border.radius = prev_border_radius

		if is_point_in_rect(widget.rect, ctx.mouse.position, widget_style.border) &&
		   .Disable_Hover not_in widget.event_flags &&
		   !ctx.mouse.hover_is_locked &&
		   widget.z_index >= hovered_z_index {

			hovered_z_index = widget.z_index
			widget_clip := ctx.clips[widget.clip]
			if widget_clip.kind[.X] != .None || widget_clip.kind[.Y] != .None {
				ctx.mouse.hovered_clip = widget_clip.hash
			}

			ctx.mouse.hovered = widget.key.hash
			ctx.mouse.can_lock_active = .Lock_Active in widget.event_flags
			ctx.mouse.can_lock_hover = .Lock_Hover in widget.event_flags
			ctx.mouse.active_disabled = .Disable_Active in widget.event_flags
		}
	}

	for &clip in ctx.clips {
		for axis in Axis {
			if ctx.mouse.hovered_clip == clip.hash {
				if clip.kind[axis] == .Auto {
					clip.value[axis] -= ctx.mouse.scroll * clip.scale[axis]
				}
			}
			clip.value[axis] = max(clip.min[axis], clip.value[axis])
			clip.value[axis] = min(clip.max[axis], clip.value[axis])
		}

		if (clip.kind[.X] == .Auto || clip.kind[.Y] == .Auto) && clip.hash != 0 {
			ctx.persistant.clip[clip.hash] = clip.value
		}
	}

	sort_render_commands(ctx.render_commands[:])
	_resolve_events(ctx)

	if ctx.mouse.active == 0 && ctx.mouse.mapped_events != {} {
		ctx.mouse.active = prev_active
	}

	ctx.mouse.mapped_events = {}
	ctx.keyboard.mapped_events = {}
}

_resolve_fit_sizing :: proc(ctx: ^Core_Context, axis: Axis) #no_bounds_check {
	#reverse for widget in ctx.post_r {
		widget_style := &ctx.styles[widget.style]
		switch &widget_kind in widget.kind {
		case Layout:
			#partial switch kind in widget_kind.sizing[axis] {
			case Fit:
				widget_kind.accumulating_min[axis] += widget_style.padding[axis].x + widget_style.padding[axis].y
				if widget_kind.direction == axis {
					widget_kind.accumulating_min[axis] +=
						max(0, f32(widget.total_children - 1 - widget.detached_children[axis])) * widget_kind.child_gap
				}
				widget_kind.accumulating_min[axis] = max(widget_kind.accumulating_min[axis], kind.min)
				widget_kind.accumulating_min[axis] = min(widget_kind.accumulating_min[axis], kind.max)
			case Grow:
				widget_kind.accumulating_min[axis] = max(widget_kind.accumulating_min[axis], kind.min)
				if widget_kind.direction == axis {
					widget_kind.accumulating_min[axis] +=
						max(0, f32(widget.total_children - 1 - widget.detached_children[axis])) * widget_kind.child_gap
				}
				widget_kind.accumulating_min[axis] += widget_style.padding[axis].x + widget_style.padding[axis].y
			case Fixed:
				widget_kind.accumulating_min[axis] = kind.value
			case Ratio:
				widget_kind.accumulating_min[axis] = kind.value * widget.resolved.size[_get_other_axis(axis)]
			}
			widget.rect.size[axis] = max(widget_kind.accumulating_min[axis], widget.rect.size[axis])
		case Text:
			if axis == .X {
				if widget_kind.minimum_width == 0 {
					_get_measured_words(ctx, widget_kind, ctx.styles[widget.style].text)
					for words in ctx.measured_words {
						widget_kind.minimum_width = max(words.width, widget_kind.minimum_width)
					}
					clear(&ctx.measured_words)
					widget_kind.maximum_width = ctx.measure_text_width(widget_kind.text, widget_style.text)
				}
				widget.rect.size[axis] = max(widget_kind.minimum_width, min(widget_kind.maximum_width, widget_kind.preferred_min))
			}
		}

		if widget.parent == -1 {continue}
		parent := &ctx.widgets[widget.parent]
		parent_clip_kind := ctx.clips[parent.clip].kind[axis]
		widget_override_flag := ctx.overrides[widget.override].flags[axis]

		if .No_Size_Propagation not_in widget_override_flag && parent_clip_kind == .None {
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
		layout, is_layout := widget.kind.(Layout)
		if !is_layout {continue}
		if widget.first == -1 {continue}

		widget_style := ctx.styles[widget.style]

		total_child_gap := max(0, f32(widget.total_children - 1 - widget.detached_children[axis])) * widget.kind.(Layout).child_gap
		total_padding := widget_style.padding[axis].x + widget_style.padding[axis].y

		if layout.direction == axis {
			clear(&ctx.growable)
			defer clear(&ctx.growable)

			available := widget.rect.size[axis] - (total_child_gap + total_padding)

			for child_index := widget.first; child_index != -1; {
				child := &ctx.widgets[child_index]
				child_index = child.next
				child_override_flag := ctx.overrides[child.override].flags[axis]
				switch child_kind in child.kind {
				case Layout:
					#partial switch kind in child_kind.sizing[axis] {
					case Grow:
						contribute := .No_Size_Propagation not_in child_override_flag
						child.rect.size[axis] = min(child.rect.size[axis], kind.max)
						append(&ctx.growable, Growable{&child.rect.size[axis], child.rect.size[axis], kind.max, false, contribute})
					case Percent:
						child.rect.size[axis] = (widget.rect.size[axis] - total_child_gap - total_padding) * kind.value
					}
				case Text:
					if axis == .X {
						contribute := .No_Size_Propagation not_in child_override_flag
						child.rect.size[axis] = min(child_kind.maximum_width, child_kind.preferred_max)
						append(&ctx.growable, Growable{&child.rect.size[axis], child_kind.minimum_width, child.rect.size[axis], true, contribute})
					}
				}

				if .No_Size_Propagation not_in child_override_flag {
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
			for child_index := widget.first; child_index != -1; {
				child := &ctx.widgets[child_index]
				child_index = child.next
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
	for widget in ctx.pre {
		switch &type in widget.kind {
		case Layout:
			continue
		case Text:
			switch type.wrap_mode {
			case .Words:
				style := ctx.styles[widget.style]
				_get_measured_words(ctx, type, style.text)
				defer clear(&ctx.measured_words)

				maximum_width: f32
				minimum_width: f32
				new_line_index: int
				accumulated_width: f32
				accumulated_height: f32
				text_height := ctx.measure_text_height(style.text)

				space_width := ctx.measure_text_width(" ", style.text)
				padding := style.padding[.X].x + style.padding[.X].y
				start := len(ctx.lines)

				for word, index in ctx.measured_words {
					maximum_width += space_width * f32(word.spaces) + word.width
					if word.string == "\n" {
						accumulated_width = 0
						append(&ctx.lines, type.text[new_line_index:word.start])
						new_line_index = word.start
						if index == len(ctx.measured_words) - 1 {
							accumulated_height += (text_height + style.text.line_spacing)
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
					f32(type.end - type.start) * (text_height + style.text.line_spacing) +
					accumulated_height +
					style.padding[.Y].x +
					style.padding[.Y].y
				type.minimum_width = minimum_width + padding
				type.maximum_width = maximum_width + padding
			case .None:
				style := ctx.styles[widget.style]
				append(&ctx.lines, type.text)
				type.start = len(ctx.lines) - 1
				type.end = len(ctx.lines)
				padding_x := style.padding[.X].x + style.padding[.X].y
				padding_y := style.padding[.Y].x + style.padding[.Y].y
				widget.rect.size.y = ctx.measure_text_height(style.text) + padding_y
				type.maximum_width = ctx.measure_text_width(type.text, style.text) + padding_x
				type.minimum_width = type.maximum_width
			}
		}
	}
}

_get_measured_words :: proc(ctx: ^Core_Context, text: Text, style: Text_Style) {
	word_start := 0
	spaces_before := 0
	data := transmute([]u8)text.text
	byte_index := 0

	for byte_index < len(data) {
		r, size := utf8.decode_rune_in_bytes(data[byte_index:])

		if r == '\n' {
			if byte_index > word_start {
				word := text.text[word_start:byte_index]
				width := ctx.measure_text_width(word, style)
				append(&ctx.measured_words, Measured_Word{string = word, width = width, start = word_start})
			}
			byte_index += size
			word_start = byte_index
			append(&ctx.measured_words, Measured_Word{string = "\n", spaces = spaces_before, start = word_start})
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

		word := text.text[start:byte_index]
		width := ctx.measure_text_width(word, style)
		append(&ctx.measured_words, Measured_Word{string = word, width = width, spaces = spaces_before, start = start})
		word_start = byte_index
		spaces_before = 0
	}

	if word_start < len(data) {
		word := text.text[word_start:]
		width := ctx.measure_text_width(word, style)
		append(&ctx.measured_words, Measured_Word{string = word, width = width, spaces = spaces_before, start = word_start})
	}
}

_position_layout_widget_children :: proc(ctx: ^Core_Context, widget: ^Widget, layout: Layout) #no_bounds_check {
	total_size: [Axis]f32
	axis := layout.direction
	other_axis := _get_other_axis(axis)

	widget_style := ctx.styles[widget.style]

	for child_index := widget.first; child_index != -1; {
		child := &ctx.widgets[child_index]
		child_index = child.next

		child_override := &ctx.overrides[child.override]

		expand_axis := _get_override_transform_value(child_override.expand, child.rect.size, widget.rect.size, axis)
		expand_other_axis := _get_override_transform_value(child_override.expand, child.rect.size, widget.rect.size, other_axis)

		child.rect.size[axis] += expand_axis
		child.rect.size[other_axis] += expand_other_axis

		ignore_flags := Override_Flags{.No_Positioning, .No_Clip_Offset, .No_Positioning_Relative}

		if ignore_flags & child_override.flags[axis] == {} {
			total_size[axis] += child.rect.size[axis]
		} else {
			total_size[axis] -= layout.child_gap
		}
		if ignore_flags & child_override.flags[other_axis] == {} {
			total_size[other_axis] = max(total_size[other_axis], child.rect.size[other_axis])
		}
	}

	total_size[axis] += max(0, f32(widget.total_children - 1)) * layout.child_gap
	widget.resolved.content_size[axis] = total_size[axis] + widget_style.padding[axis].x + widget_style.padding[axis].y
	widget.resolved.content_size[other_axis] = total_size[other_axis] + widget_style.padding[other_axis].x + widget_style.padding[other_axis].y

	increment: Vec2f32

	switch layout.alignment[axis] {
	case .Negative:
		increment[axis] = widget.rect.position[axis] + widget_style.padding[axis][0]
	case .Positive:
		increment[axis] = widget.rect.position[axis] + widget.rect.size[axis] - widget_style.padding[axis][1] - total_size[axis]
	case .Center:
		increment[axis] = widget.rect.position[axis] + (widget.rect.size[axis] - total_size[axis]) / 2
	}

	switch layout.alignment[other_axis] {
	case .Negative:
		increment[other_axis] = widget.rect.position[other_axis] + widget_style.padding[other_axis][0]
	case .Positive:
		increment[other_axis] = widget.rect.position[other_axis] + widget.rect.size[other_axis] - widget_style.padding[other_axis][1]
	case .Center:
		increment[other_axis] = widget.rect.position[other_axis] + widget.rect.size[other_axis] / 2
	}

	clip_axis := _get_clip_value(ctx, widget, axis)
	clip_other_axis := _get_clip_value(ctx, widget, other_axis)

	for child_index := widget.first; child_index != -1; {
		child := &ctx.widgets[child_index]
		child_index = child.next

		child_override := &ctx.overrides[child.override]

		offset_axis := _get_override_transform_value(child_override.offset, child.rect.size, widget.rect.size, axis)
		offset_other_axis := _get_override_transform_value(child_override.offset, child.rect.size, widget.rect.size, other_axis)

		ignore_flags := Override_Flags{.No_Positioning, .No_Positioning_Relative}

		if ignore_flags & child_override.flags[axis] == {} {
			child.rect.position[axis] = increment[axis]
			increment[axis] += child.rect.size[axis] + layout.child_gap + offset_axis
		} else {
			child.rect.position[axis] = 0
			if .No_Positioning_Relative in child_override.flags[axis] {
				child.rect.position[axis] = widget.rect.position[axis]
			}
		}

		if ignore_flags & child_override.flags[other_axis] == {} {
			switch layout.alignment[other_axis] {
			case .Negative:
				child.rect.position[other_axis] = increment[other_axis]
			case .Positive:
				child.rect.position[other_axis] = increment[other_axis] - child.rect.size[other_axis]
			case .Center:
				child.rect.position[other_axis] = increment[other_axis] - child.rect.size[other_axis] / 2
			}
		} else {
			child.rect.position[other_axis] = 0
			if .No_Positioning_Relative in child_override.flags[other_axis] {
				child.rect.position[other_axis] = widget.rect.position[other_axis]
			}
		}

		child.rect.position[axis] += offset_axis
		child.rect.position[other_axis] += offset_other_axis

		if .No_Clip_Offset not_in child_override.flags[axis] {
			child.rect.position[axis] -= clip_axis
		}

		if .No_Clip_Offset not_in child_override.flags[other_axis] {
			child.rect.position[other_axis] -= clip_other_axis
		}
	}
}
