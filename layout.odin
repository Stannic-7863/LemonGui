package ui_core

import "core:fmt"
import "core:math/linalg"
import "core:sort"
import "core:unicode/utf8"

/*
	Layout is totally inspired by CLAY
*/

Axis :: enum u8 {
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

Sizing :: union {
	Fit,
	Grow,
	Fixed,
	Percent,
}

Alignment :: enum u8 {
	Negative, // -y, -x, left, up 
	Center, // 0, 0 
	Positive, // +x, +y, right, down 
}

Percent_Self :: distinct Value

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
	offset: Override_Transform,
	expand: Override_Transform,
	flags:  Override_Flags,
}

Clip_Kind :: enum {
	None,
	Custom,
	Auto,
}

// I should offload some rendering quirks like putting dashes and dots at wrap site to command emittion stage 
Wrap_Kind :: enum u8 {
	None,
	Words,
	Letters,
	New_Lines,
}

Clip :: struct {
	kind:  Clip_Kind,
	value: f32,
	scale: f32,
}

@(private = "file")
Measured_Word :: struct {
	word:          string,
	word_start:    int,
	spaces_before: int,
	width:         f32,
}

Growable :: struct {
	size:       ^f32,
	min:        f32,
	max:        f32,
	is_text:    bool,
	contribute: bool,
}

_layout_apply_sizing_pass :: proc(ctx: ^Core_Context) {
	#reverse for w in ctx.stacks.post_r {
		_sizing_resolve_fit(.X, w)
	}

	for w in ctx.stacks.pre {
		layout: Layout = _get_layout(w) or_continue
		if layout.direction == .X {
			_sizing_resolve_other_along_axis(ctx, .X, w)
		} else {
			_sizing_resolve_other_across_axis(ctx, .X, w)
		}
	}

	_sizing_resolve_word_wrap(ctx)

	#reverse for w in ctx.stacks.post_r {
		_sizing_resolve_aspect_ratio(w)
		_sizing_resolve_fit(.Y, w)
	}

	for w in ctx.stacks.pre {
		_sizing_resolve_aspect_ratio(w)
		layout: Layout = _get_layout(w) or_continue
		if layout.direction == .Y {
			_sizing_resolve_other_along_axis(ctx, .Y, w)
		} else {
			_sizing_resolve_other_across_axis(ctx, .Y, w)
		}
	}
}

_layout_apply_positioning_pass :: proc(ctx: ^Core_Context) {
	z_index_offset := 0
	for widget in ctx.stacks.pre {
		defer {
			if _is_point_in_rect(widget.position, widget.size, ctx.mouse.position, widget.style.border) &&
			   ctx.active_widget_id == 0 &&
			   !widget.event_passthrough {
				ctx.hot_widget_id = widget.id
			}
		}
		switch type in widget.kind {
		case Layout:
			_position_layout_childs(widget, type)
		case Text:
		}

		_position_clip_childs(ctx, widget)
		_emit_render_commands(ctx, widget, &z_index_offset)
	}

	sort.quick_sort_proc(ctx.render_commands[:], proc(a, b: Render_Command) -> int {return a.z_index - b.z_index})
}

_sizing_resolve_fit :: proc(axis: Axis, widget: ^Widget) {
	switch &node_kind in widget.kind {
	case Layout:
		#partial switch kind in node_kind.sizing[axis] {
		case Fit:
			if node_kind.direction == axis {
				node_kind.accumulating_min[axis] += _get_child_gap(widget)
			}
			node_kind.accumulating_min[axis] += _get_axis_padding(axis, widget.style.padding)
			node_kind.accumulating_min[axis] = max(node_kind.accumulating_min[axis], kind.min)
			node_kind.accumulating_min[axis] = min(node_kind.accumulating_min[axis], kind.max)
		case Grow:
			node_kind.accumulating_min[axis] = max(node_kind.accumulating_min[axis], kind.min)
			if node_kind.direction == axis {
				node_kind.accumulating_min[axis] += _get_child_gap(widget)
			}
			node_kind.accumulating_min[axis] += _get_axis_padding(axis, widget.style.padding)
		case Fixed:
			node_kind.accumulating_min[axis] = kind.value
		}
		widget.size[axis] = max(node_kind.accumulating_min[axis], widget.size[axis])
	case Text:
		if axis == .X {
			widget.size[axis] = max(node_kind.preferred_min, node_kind.minimum_width)
		}
		widget.size[axis] += _get_axis_padding(axis, widget.style.padding)
	}

	parent := widget.parent
	if parent == nil {return}

	if .No_Size_Propagation not_in widget.override[axis].flags {
		parent_kind := &parent.kind.(Layout)
		if parent_kind.direction == axis {
			parent_kind.accumulating_min[axis] += widget.size[axis]
		} else {
			parent_kind.accumulating_min[axis] = max(parent_kind.accumulating_min[axis], widget.size[axis])
		}
	}
}

_sizing_resolve_other_along_axis :: proc(ctx: ^Core_Context, axis: Axis, widget: ^Widget) {
	if widget.first == nil {return}

	clear(&ctx.growable)
	defer clear(&ctx.growable)

	total_child_gap := _get_child_gap(widget)
	total_padding := _get_axis_padding(axis, widget.style.padding)
	available := widget.size[axis] - (total_child_gap + total_padding)

	for child := widget.first; child != nil; child = child.next {
		switch child_kind in child.kind {
		case Layout:
			#partial switch kind in child_kind.sizing[axis] {
			case Grow:
				contribute := .No_Size_Propagation not_in child.override[axis].flags
				append(&ctx.growable, Growable{&child.size[axis], child.size[axis], kind.max, false, contribute})
			case Percent:
				child.size[axis] = (widget.size[axis] - total_child_gap - total_padding) * kind.value
			}
		case Text:
			if axis == .X {
				contribute := .No_Size_Propagation not_in child.override[axis].flags
				child.size[axis] = ctx.text_measure_proc(child_kind.text, child_kind.style) + _get_axis_padding(axis, child.style.padding)
				child.size[axis] = min(child.size[axis], child_kind.preferred_max)
				append(&ctx.growable, Growable{&child.size[axis], child_kind.minimum_width, child_kind.maximum_width, true, contribute})
			}
		}

		available -= child.size[axis]
	}

	if len(ctx.growable) == 0 {return}

	if available > 0 {
		_sizing_resolve_grow(ctx, available)
	} else {
		_sizing_resolve_shrink(ctx, abs(available))
	}
}

_sizing_resolve_grow :: proc(ctx: ^Core_Context, available: f32) {
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

			if g.size^ > g.max {
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

_sizing_resolve_shrink :: proc(ctx: ^Core_Context, available: f32) {
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
			if g.size^ < g.min {
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

_sizing_resolve_other_across_axis :: proc(ctx: ^Core_Context, axis: Axis, widget: ^Widget) {
	if widget.first == nil {return}

	total_padding := _get_axis_padding(axis, widget.style.padding)

	for child := widget.first; child != nil; child = child.next {
		switch child_kind in child.kind {
		case Layout:
			#partial switch kind in child_kind.sizing[axis] {
			case Grow:
				child.size[axis] = widget.size[axis] - total_padding
				child.size[axis] = max(child.size[axis], child_kind.accumulating_min[axis])
				child.size[axis] = min(child.size[axis], kind.max)
			case Percent:
				child.size[axis] = (widget.size[axis] - total_padding) * kind.value
			}
		case Text:
			if axis == .X {
				size := ctx.text_measure_proc(child_kind.text, child_kind.style) + _get_axis_padding(axis, child.style.padding)
				child.size[axis] = min(size, widget.size[axis] - total_padding)
			}
		}
	}
}

_sizing_resolve_aspect_ratio :: proc(widget: ^Widget) {
	if widget.aspect_ratio != 0 {
		switch &kind in widget.kind {
		case Layout:
			kind.accumulating_min[Axis.Y] = widget.size[Axis.X] / widget.aspect_ratio
			widget.size[Axis.Y] = kind.accumulating_min[Axis.Y]
		case Text:
			return
		}
	}
}

_sizing_resolve_word_wrap :: proc(ctx: ^Core_Context) {
	measured_words := make([dynamic]Measured_Word, context.temp_allocator)
	for widget in ctx.stacks.pre {
		switch &type in widget.kind {
		case Layout:
			continue
		case Text:
			_sizing_get_measured_words(ctx, type, &measured_words)
			space_width := ctx.text_measure_proc(" ", type.style)
			line_start: int = 0
			largest_width: f32
			x_padding := _get_axis_padding(.X, widget.style.padding)
			widget_lines_start := len(ctx.text_lines)
			additional_height: f32 = 0
			accumulated_width: f32 = 0
			cursor_found: bool

			switch type.wrap {
			case .None:
			case .Words:
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
					if accumulated_width + w.width > widget.size.x - x_padding {
						accumulated_width = 0
						append(&ctx.text_lines, type.text[line_start:w.word_start])
						line_start = w.word_start
					}
					accumulated_width += w.width
				}
			case .Letters:
				for w, index in measured_words {
					if w.word == "\n" {
						append(&ctx.text_lines, type.text[line_start:w.word_start])
						line_start = w.word_start
						if index == len(measured_words) - 1 {
							additional_height += (type.style.font_size + type.style.line_spacing)
						}
						accumulated_width = 0
						continue
					}

					total_width := w.width + space_width * f32(w.spaces_before)
					if accumulated_width + total_width > widget.size.x - x_padding {
						accumulated_width += space_width * f32(w.spaces_before)
						word_index := w.word_start
						i := 0
						for i < len(w.word) {
							r, size := utf8.decode_rune(w.word[i:])
							rune_str := w.word[i:i + size]
							letter_width := ctx.text_measure_proc(rune_str, type.style)
							if accumulated_width + letter_width >= widget.size.x - x_padding {
								accumulated_width = 0
								append(&ctx.text_lines, type.text[line_start:word_index + i])
								line_start = word_index + i
							}
							accumulated_width += letter_width
							i += size
						}
					} else {
						accumulated_width += space_width * f32(w.spaces_before)
						accumulated_width += w.width
					}
				}
			case .New_Lines:
				for w, index in measured_words {
					largest_width = max(largest_width, w.width)
					if w.word == "\n" {
						accumulated_width = 0
						append(&ctx.text_lines, type.text[line_start:w.word_start])
						line_start = w.word_start
						if index == len(measured_words) - 1 {
							additional_height += (type.style.font_size + type.style.line_spacing)
						}
					}
				}
			}

			if line_start < len(type.text) {
				append(&ctx.text_lines, type.text[line_start:])
			}

			type.start = widget_lines_start
			type.end = len(ctx.text_lines)
			widget.size.y = f32(type.end - type.start) * (type.style.font_size + type.style.line_spacing) + additional_height
			type.minimum_width = largest_width + x_padding
			clear(&measured_words)
		}
	}
}

_sizing_get_measured_words :: proc(ctx: ^Core_Context, text: Text, measured_words: ^[dynamic]Measured_Word) {
	word_start_byte_index, spaces_before_word, byte_index: int

	for byte_index < len(text.text) {
		r := utf8.rune_at(text.text, byte_index)

		if r == '\n' {
			if byte_index > word_start_byte_index {
				word := text.text[word_start_byte_index:byte_index]
				width := ctx.text_measure_proc(word, text.style)
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
		width := ctx.text_measure_proc(word, text.style)
		append(measured_words, Measured_Word{word = word, width = width, spaces_before = spaces_before_word, word_start = word_start_byte_index})
		word_start_byte_index = byte_index
		spaces_before_word = 0
	}

	if word_start_byte_index < len(text.text) {
		word := text.text[word_start_byte_index:]
		width := ctx.text_measure_proc(word, text.style)
		append(measured_words, Measured_Word{word = word, width = width, spaces_before = spaces_before_word, word_start = word_start_byte_index})
	}
}

_get_override_transform_value :: proc(widget: ^Widget, axis: Axis) -> (offset_value: f32) {
	switch kind in widget.override[axis].offset {
	case Percent_Self:
		offset_value = widget.size[axis] * kind.value
	case Percent:
		offset_value = widget.size[axis] * kind.value
	case Fixed:
		offset_value = kind.value
	}
	return offset_value
}

_position_layout_childs :: proc(widget: ^Widget, layout: Layout) {
	total_size: f32
	axis := layout.direction
	other_axis := _get_other_axis(axis)

	for child := widget.first; child != nil; child = child.next {
		total_size += child.size[axis]
	}
	total_size += max(0, layout.child_gap * f32(widget.total_children - 1))

	increment: Vec2f32

	switch layout.alignment[axis] {
	case .Negative:
		increment[axis] = widget.position[axis] + widget.style.padding[axis][0]
	case .Positive:
		increment[axis] = widget.position[axis] + widget.size[axis] - widget.style.padding[axis][1] - total_size
	case .Center:
		increment[axis] = widget.position[axis] + (widget.size[axis] - total_size) / 2
	}

	switch layout.alignment[other_axis] {
	case .Negative:
		increment[other_axis] = widget.position[other_axis] + widget.style.padding[other_axis][0]
	case .Positive:
		increment[other_axis] = widget.position[other_axis] + widget.size[other_axis] - widget.style.padding[other_axis][1]
	case .Center:
		increment[other_axis] = widget.position[other_axis] + widget.size[other_axis] / 2
	}

	for child := widget.first; child != nil; child = child.next {
		offset_value := _get_override_transform_value(child, axis)
		offset_value_other_axis := _get_override_transform_value(child, other_axis)

		if .No_Positioning not_in child.override[axis].flags {
			child.position[axis] = increment[axis]
			increment[axis] += child.size[axis] + layout.child_gap + offset_value
		}

		if .No_Positioning not_in child.override[other_axis].flags {
			switch layout.alignment[other_axis] {
			case .Negative:
				child.position[other_axis] = increment[other_axis]
			case .Positive:
				child.position[other_axis] = increment[other_axis] - child.size[other_axis]
			case .Center:
				child.position[other_axis] = increment[other_axis] - child.size[other_axis] / 2
			}
		}

		child.position[axis] += offset_value
		child.position[other_axis] += offset_value_other_axis
	}
}

_position_clip_childs :: proc(ctx: ^Core_Context, parent_widget: ^Widget) {
	for child_widget := parent_widget.first; child_widget != nil; child_widget = child_widget.next {
		if parent_widget.clip[.X].kind != .None {
			child_widget.position.x += parent_widget.clip[.X].value
		}
		if parent_widget.clip[.Y].kind != .None {
			child_widget.position.y += parent_widget.clip[.Y].value
		}
	}
}

_emit_render_commands :: proc(ctx: ^Core_Context, widget: ^Widget, z_index_offset: ^int) {
	if widget.clip[.X].kind != .None || widget.clip[.Y].kind != .None {

		if ctx.active_clipper != nil {
			append(&ctx.clips, ctx.active_clipper)
		}

		ctx.active_clipper = widget
		_emit_clip_start_command(ctx, widget, z_index_offset^ + widget.z_index)
	}

	_emit_rect_command(ctx, widget, z_index_offset)
	_emit_image_command(ctx, widget, z_index_offset)
	_emit_widget_primitive_commands(ctx, widget, z_index_offset)
	_emit_custom_command(ctx, widget, z_index_offset)
	_emit_text_command(ctx, widget, z_index_offset)
	_emit_widget_border_command(ctx, widget, z_index_offset)

	if widget.next == nil && widget.first == nil {
		for parent := widget.parent; parent != nil; parent = parent.parent {
			if parent == ctx.active_clipper {
				_emit_clip_end_command(ctx, ctx.active_clipper, ctx.active_clipper.z_index + z_index_offset^)
				z_index_offset^ += 1
				ctx.active_clipper = nil
				ctx.active_clipper, _ = pop_safe(&ctx.clips)
				break
			}
			if parent.next != nil {
				break
			}
		}
	}
}

_emit_clip_end_command :: proc(ctx: ^Core_Context, widget: ^Widget, z_index: int) {
	append(&ctx.render_commands, Render_Command{kind = Command_Clip_End{}, z_index = z_index})
}

_emit_clip_start_command :: proc(ctx: ^Core_Context, widget: ^Widget, z_index: int) {
	clip_size := linalg.round(widget.size)
	clip_position := linalg.round(widget.position)

	border := widget.style.border
	append(&ctx.render_commands, Render_Command{kind = Command_Clip_Start{clip_size = clip_size, clip_position = clip_position}, z_index = z_index})
}

_emit_widget_border_command :: proc(ctx: ^Core_Context, widget: ^Widget, z_index: ^int) {
	if widget.style.border != {} {
		command_border: Command_Border
		command_border.position = linalg.round(widget.position)
		command_border.size = linalg.round(widget.size)
		command_border.style = widget.style.border
		_add_render_command(ctx, widget, command_border, z_index)
	}
}

_emit_text_command :: proc(ctx: ^Core_Context, widget: ^Widget, z_index: ^int) {
	if text, ok := widget.kind.(Text); ok {
		command_text: Command_Text
		position := widget.position
		position.x += widget.style.padding[.X][0]
		position.y += widget.style.padding[.Y][0]
		command_text.cursor = text.cursor
		command_text.position = position
		command_text.style = text.style
		command_text.end = text.end
		command_text.start = text.start
		_add_render_command(ctx, widget, command_text, z_index)
	}
}

_emit_rect_command :: proc(ctx: ^Core_Context, widget: ^Widget, z_index: ^int) {
	_clamp_border_radius(widget)
	command_rect: Command_Rect = {widget.style.border.radius, widget.size, widget.position, widget.style.color}
	_add_render_command(ctx, widget, command_rect, z_index)
}

_emit_image_command :: proc(ctx: ^Core_Context, widget: ^Widget, z_index: ^int) {
	if widget.image.data != nil {
		_add_render_command(ctx, widget, Command_Image{widget.position, widget.size, widget.image.tint, widget.image.data}, z_index)
	}
}

_emit_widget_primitive_commands :: proc(ctx: ^Core_Context, widget: ^Widget, z_index: ^int) {
	if len(widget.primitives) > 0 {
		for &p, i in widget.primitives {
			_add_render_command(ctx, widget, p, z_index)
		}
	}
}

_emit_custom_command :: proc(ctx: ^Core_Context, widget: ^Widget, z_index: ^int) {
	if widget.custom_data != nil {
		_add_render_command(ctx, widget, Command_Custom{widget.position, widget.custom_data}, z_index)
	}
}

_add_render_command :: proc(ctx: ^Core_Context, widget: ^Widget, kind: Render_Command_Kind, z_index: ^int) {
	append(
		&ctx.render_commands,
		Render_Command{kind = kind, z_index = z_index^ + widget.z_index, emitter_id = widget.id, emitter_string_id = widget.key.string_id},
	)
	z_index^ += 1
}
