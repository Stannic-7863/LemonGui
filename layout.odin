package ui_core

import "core:fmt"
import "core:sort"
import "core:unicode/utf8"

/*
	Layout is totally inspired by CLAY. for better layout shtuff, check out CLAY :)
*/

Axis :: enum u8 {
	X,
	Y,
}

Layout_Kind :: enum u8 {
	Fit, // Fit to content size [Default]
	Grow, // Grow to take up all space inside parent 
	Fixed, // A fixed size provided in pixel value 
	Percent, // Percentage of parent size, provided in range 0.0-1.0
}

Child_Alignment_X :: enum u8 {
	Left,
	Center,
	Right,
}

Child_Alignment_Y :: enum u8 {
	Top,
	Center,
	Bottom,
}

// Used to set position relative to different parts of widget
Anchor :: enum u8 {
	Left_Top,
	Left_Center,
	Left_Bottom,
	Center_Top,
	Center_Center,
	Center_Bottom,
	Right_Top,
	Right_Center,
	Right_Bottom,
}

// Describe where floating is attached
Attachment_To :: enum u8 {
	Parent,
	None,
	Root,
	Id,
}

Offset_Kind :: enum u8 {
	None, // Not affected [Default]
	Fixed, // Set position to value provided in pixels
	Absolute, // Offset position by value provided in pixel relative to parent's position 
	Percent, // Offset position by percent of parent size
	Percent_Self, // Offset position by percentange of own size
}

Expand_Kind :: enum u8 {
	None, // Not affected [Default]
	Absolute, // Exapand size by provided size in pixels
	Percent, // Expand size by percentage of parent size 
	Percent_Self, // Expand size by percentage of own size
}

// I should offload some rendering quirks like putting dashes and dots at wrap site to command emittion stage 
Wrap_Kind :: enum u8 {
	None,
	Words,
	Letters,
	New_Lines,
}

Expand :: struct {
	value: f32,
	kind:  Expand_Kind,
}

Offset :: struct {
	value: f32,
	kind:  Offset_Kind,
}

Child_Alignment :: struct {
	x: Child_Alignment_X,
	y: Child_Alignment_Y,
}

Sizing :: struct {
	min, max: f32,
	kind:     Layout_Kind,
}

@(private = "file")
Measured_Word :: struct {
	word:          string,
	word_start:    int,
	spaces_before: int,
	width:         f32,
}

@(private = "file")
Growable :: struct {
	size:    ^Vec2f32,
	min:     f32,
	max:     f32,
	is_text: bool,
}

_layout_all_sizing_pass :: proc(ctx: ^Core_Context) {

	_sizing_fixed_pass(ctx)

	#reverse for w in ctx.stacks.post_r {
		_fit_into_parent(.X, w)
		switch type in w.type {
		case Layout:
		case Floating:
		case Text:
			w.size += ctx.text_measure_proc(type.text, type.style)
		}
	}

	growables := make([dynamic]Growable, 0, 16, context.temp_allocator)
	for w in ctx.stacks.pre {
		layout: Layout = _get_layout(w) or_continue
		if layout.direction == .X {
			_grow_shrink_children_along_axis(.X, layout, w, &growables)
			clear(&growables)
		} else {
			_grow_children_across_axis(.X, layout, w)
			clear(&growables)
		}
	}

	_sizing_word_wrap(ctx)

	#reverse for w in ctx.stacks.post_r {
		_sizing_apply_aspect_ratio(w)
		_fit_into_parent(.Y, w)
	}

	for w in ctx.stacks.pre {
		_sizing_apply_aspect_ratio(w)
		layout: Layout = _get_layout(w) or_continue
		if layout.direction == .Y {
			_grow_shrink_children_along_axis(.Y, layout, w, &growables)
			clear(&growables)
		} else {
			_grow_children_across_axis(.Y, layout, w)
			clear(&growables)
		}
	}
}

_layout_all_positioning_pass :: proc(ctx: ^Core_Context) {
	z_index_offset := 0
	for widget in ctx.stacks.pre {
		defer {
			if _is_point_in_rect(widget.position, widget.size, ctx.mouse.position, widget.style.border) &&
			   ctx.active_widget_id == 0 &&
			   !widget.event_passthrough {
				ctx.hot_widget_id = widget.node.id
			}
		}
		switch type in widget.type {
		case Floating:
			_position_layout_floating(ctx, widget, type)
			_expand_widget(widget)
			_offset_widget(widget)
			_position_layout_childs(widget, type.layout)
		case Layout:
			_expand_widget(widget)
			_offset_widget(widget)
			_position_layout_childs(widget, type)
		case Text:
			_expand_widget(widget)
			_offset_widget(widget)
		}

		_position_clip_childs(ctx, widget)
		_emit_all(ctx, widget, &z_index_offset)
	}

	sort.quick_sort_proc(ctx.render_commands[:], proc(a, b: Render_Command) -> int {return a.z_index - b.z_index})
}

_fit_into_parent :: proc(axis: Axis, widget: ^Widget) {
	/* 
		This function is called in reverse post order. Childs will be come first, then their parents
		That is why accumalating size into parents and figuring out the min max padding adjustment in the same function works
	*/

	// Accumulate Into Parents size if parent is of .Fit type
	parent := widget.node.parent
	if parent == nil {return}

	parent_layout, parent_is_layout := _get_layout(parent)

	if !parent_is_layout {return}

	if parent_layout.sizing[axis].kind == .Fit {
		if parent.is_floating_descendant == widget.is_floating_descendant { 	// we don't want floating elements contributing into non floating widgets
			if parent_layout.direction == axis {
				parent.size[axis] += widget.size[axis]
			} else {
				parent.size[axis] = max(parent.size[axis], widget.size[axis])
			}
		}
	}

	defer {
		if parent.is_floating_descendant == widget.is_floating_descendant {
			if parent_layout.direction == axis {
				parent.accumulated_min[axis] += max(widget.accumulated_min[axis], widget.size[axis])
			} else {
				parent.accumulated_min[axis] = max(parent.accumulated_min[axis], max(widget.accumulated_min[axis], widget.size[axis]))
			}
		}
	}

	widget_layout, widget_is_layout := _get_layout(widget)
	widget_axis_padding: f32 = _get_axis_padding(axis, widget.style.padding)

	widget.size[axis] += widget_axis_padding // resolve padding 

	if !widget_is_layout {return}

	widget.accumulated_min[axis] += widget_axis_padding

	if widget_layout.direction == axis {
		child_gaps := max(0, f32(widget.node.total_children - 1) * widget_layout.child_gap)
		widget.accumulated_min[axis] += child_gaps
		widget.size[axis] += child_gaps
	}

	if widget_layout.sizing[axis].kind == .Fit {
		widget.accumulated_min[axis] = max(widget.accumulated_min[axis], widget_layout.sizing[axis].min)
		widget.accumulated_min[axis] = min(widget.accumulated_min[axis], widget_layout.sizing[axis].max)
		widget.size[axis] = widget.accumulated_min[axis]
	}
}

_grow_shrink_children_along_axis :: proc(axis: Axis, parent_layout: Layout, parent: ^Widget, growables: ^[dynamic]Growable) {
	if parent.node.first_child == nil {return}

	parent_axis_padding := _get_axis_padding(axis, parent.style.padding)
	remaining_space: f32 = parent.size[axis] - parent_axis_padding - parent_layout.child_gap * f32(parent.node.total_children - 1)

	for child := parent.node.first_child; child != nil; child = child.node.next {
		switch type in child.type {
		case Floating:
			if type.layout.sizing[axis].kind == .Grow {
				child.size[axis] = parent.size[axis] - parent_axis_padding
			}
			if type.layout.sizing[axis].kind == .Percent {
				child.size[axis] = parent.size[axis] * type.layout.sizing[axis].min - parent_axis_padding
				child.size[axis] = max(child.size[axis], child.accumulated_min[axis])
			}
			continue
		case Layout:
			switch type.sizing[axis].kind {
			case .Grow:
				child.size[axis] = max(child.accumulated_min[axis], type.sizing[axis].min)
				append(growables, Growable{&child.size, child.size[axis], type.sizing[axis].max, false})
			case .Percent:
				child.size[axis] =
					(parent.size[axis] -
						_get_axis_padding(axis, parent.style.padding) -
						f32(parent.node.total_children - 1) * parent_layout.child_gap) *
					type.sizing[axis].min
				child.size[axis] = max(child.accumulated_min[axis], child.size[axis])
			case .Fixed:
			case .Fit:
			}
		case Text:
			if axis != .Y {
				append(growables, Growable{&child.size, child.accumulated_min.x, max(f32), true})
			}
		}
		remaining_space -= child.size[axis]
	}

	if len(growables) == 0 {return}

	if remaining_space >= 0 {
		// as long as there is space, distribute it, 1e-9 for floating point err   
		for remaining_space >= 1e-9 && len(growables) > 0 {
			smallest: f32 = growables[0].size[axis]
			second_smallest: f32 = max(f32)
			to_add: f32 = remaining_space
			// We find the smallest and second smallest along the axis we to expand to. 
			// Once we find the smallest, we grow it until its the size of second smallest and repeat this process until all space is distributed 
			for child, i in growables {
				if child.is_text {
					ordered_remove(growables, i)
					continue
				}
				if child.size[axis] < smallest {
					second_smallest = smallest
					smallest = child.size[axis]
				}
				if child.size[axis] > smallest {
					second_smallest = min(second_smallest, child.size[axis])
					to_add = second_smallest - smallest
				}
			}

			// If all growables are smallest then we distribute remaining space equally, other wise we add space to smallest one only 
			to_add = min(to_add, remaining_space / cast(f32)len(growables))
			#reverse for child, i in growables {
				if child.size[axis] == smallest {
					child.size[axis] += to_add
					remaining_space -= to_add
				}
				if child.size[axis] < child.min {
					size := child.size[axis]
					child.size[axis] = child.min
					remaining_space += size - child.min
					ordered_remove(growables, i)
				}
				if child.size[axis] > child.max {
					size := child.size[axis]
					child.size[axis] = child.max
					remaining_space += size - child.max
					ordered_remove(growables, i)
				}
			}
		}
	} else {
		// if remaining width is negative we need to shrink largest containers to make space 
		remaining_space = abs(remaining_space)

		for remaining_space >= 1e-9 && len(growables) > 0 {
			largest: f32 = growables[0].size[axis]
			second_largest: f32 = min(f32)
			to_subtract: f32 = remaining_space

			for child in growables {
				if child.size[axis] > largest {
					second_largest = largest
					largest = child.size[axis]
				}
				if child.size[axis] < largest {
					second_largest = min(second_largest, child.size[axis])
					to_subtract = largest - second_largest
				}
			}

			to_subtract = min(to_subtract, remaining_space / cast(f32)len(growables))

			#reverse for child, i in growables {
				if child.size[axis] == largest {
					child.size[axis] -= to_subtract
					remaining_space -= to_subtract
				}
				if child.size[axis] < child.min {
					size := child.size[axis]
					child.size[axis] = child.min
					remaining_space += size - child.min
					ordered_remove(growables, i)
				}
				if child.size[axis] > child.max {
					size := child.size[axis]
					child.size[axis] = child.max
					remaining_space += size - child.max
					ordered_remove(growables, i)
				}
			}
		}
	}
}

_grow_children_across_axis :: proc(axis: Axis, layout: Layout, widget: ^Widget) {
	if widget.node.first_child == nil {return}

	axis_padding: f32 = _get_axis_padding(axis, widget.style.padding)

	for child_widget := widget.node.first_child; child_widget != nil; child_widget = child_widget.node.next {
		child_layout, is_layout := _get_layout(child_widget)
		if !is_layout {
			if layout.direction == .Y && axis == .X && child_widget.size.x > widget.size.x - _get_axis_padding(.X, widget.style.padding) {
				child_widget.size.x = widget.size.x - _get_axis_padding(.X, widget.style.padding)
			}
			continue
		}

		if child_layout.sizing[axis].kind == .Percent {
			child_widget.size[axis] =
				(widget.size[axis] - _get_axis_padding(axis, widget.style.padding) - f32(widget.node.total_children - 1) * layout.child_gap) *
				child_layout.sizing[axis].min
			child_widget.size[axis] = max(child_widget.accumulated_min[axis], child_widget.size[axis])
		}
		if child_layout.sizing[axis].kind == .Grow {
			child_min := max(child_widget.accumulated_min[axis], child_layout.sizing[axis].min)
			child_widget.size[axis] = max(widget.size[axis] - axis_padding, child_min)
			child_widget.size[axis] = min(child_widget.size[axis], child_layout.sizing[axis].max)
		}
	}
}

_sizing_fixed_pass :: proc(ctx: ^Core_Context) {
	#reverse for w in ctx.stacks.post_r {
		layout, is_layout := _get_layout(w)
		if !is_layout {
			w.size = 0
		}
		for &sizing, i in layout.sizing {
			switch sizing.kind {
			case .Fit, .Percent:
				w.size[i] = 0
			case .Fixed, .Grow:
				w.size[i] = sizing.min
			}
		}
	}
}

_sizing_apply_aspect_ratio :: proc(widget: ^Widget) {
	if aspect_ratio, ok := widget.aspect_ratio.(f32); ok {
		switch &type in widget.type {
		case Layout:
			widget.accumulated_min[Axis.Y] = widget.size[Axis.X] / aspect_ratio
			widget.size[Axis.Y] = widget.accumulated_min[Axis.Y]
			type.sizing[Axis.Y].min = widget.accumulated_min[Axis.Y]
			type.sizing[Axis.Y].max = widget.accumulated_min[Axis.Y]
		case Floating:
			widget.accumulated_min[Axis.Y] = widget.size[Axis.X] / aspect_ratio
			widget.size[Axis.Y] = widget.accumulated_min[Axis.Y]
			type.layout.sizing[Axis.Y].min = widget.accumulated_min[Axis.Y]
			type.layout.sizing[Axis.Y].max = widget.accumulated_min[Axis.Y]
		case Text:
			return
		}
	}
}

_sizing_word_wrap :: proc(ctx: ^Core_Context) {
	measured_words := make([dynamic]Measured_Word, context.temp_allocator)
	for widget in ctx.stacks.pre {
		switch &type in widget.type {
		case Layout, Floating:
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

			type._start = widget_lines_start
			type._end = len(ctx.text_lines)
			widget.size.y = f32(type._end - type._start) * (type.style.font_size + type.style.line_spacing) + additional_height
			widget.accumulated_min = {largest_width + x_padding, widget.size.y}
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

_offset_widget :: proc(widget: ^Widget) {
	for offset, i in widget.offset {
		switch offset.kind {
		case .None:
		case .Fixed:
			widget.position[i] = offset.value
		case .Absolute:
			widget.position[i] += offset.value
		case .Percent:
			if widget.node.parent != nil {
				widget.position[i] += offset.value * widget.node.parent.size[i]
			}
		case .Percent_Self:
			widget.position[i] += offset.value * widget.size[i]
		}
	}
}

_expand_widget :: proc(widget: ^Widget) {
	for expand, i in widget.expand {
		switch expand.kind {
		case .None:
		case .Absolute:
			widget.size[i] += expand.value
		case .Percent:
			if widget.node.parent != nil {
				widget.size[i] += expand.value * widget.node.parent.size[i]
			}
		case .Percent_Self:
			widget.size[i] += expand.value * widget.size[i]
		}
	}
}

_position_layout_floating :: proc(ctx: ^Core_Context, widget: ^Widget, floating: Floating) {
	layout := floating.layout
	anchor_pos: Vec2f32
	anchor_size: Vec2f32

	switch floating.attachment_to {
	case .Id:
		val, ok := ctx.persistant_data[floating.id]
		if ok {
			anchor_pos = val.position
			anchor_size = val.size
		}
	case .Root:
		w := ctx.widgets[0]
		anchor_pos = w.position
		anchor_size = w.size
	case .Parent:
		anchor_pos = widget.node.parent.position
		anchor_size = widget.node.parent.size
	case .None:
	}

	offset: Vec2f32
	switch floating.parent {
	case .Left_Top:
		offset = anchor_pos
	case .Right_Top:
		offset.x = anchor_pos.x + anchor_size.x
		offset.y = anchor_pos.y
	case .Center_Top:
		offset.x = anchor_pos.x + anchor_size.x / 2
		offset.y = anchor_pos.y
	case .Left_Center:
		offset.x = anchor_pos.x
		offset.y = anchor_pos.y + anchor_size.y / 2
	case .Center_Center:
		offset = anchor_pos + anchor_size / 2
	case .Right_Center:
		offset.x = anchor_pos.x + anchor_size.x
		offset.y = anchor_pos.y + anchor_size.y / 2
	case .Left_Bottom:
		offset.x = anchor_pos.x
		offset.y = anchor_pos.y + anchor_size.y
	case .Right_Bottom:
		offset = anchor_pos + anchor_size
	case .Center_Bottom:
		offset.x = anchor_pos.x + anchor_size.x / 2
		offset.y = anchor_pos.y + anchor_size.y
	}
	switch floating.element {
	case .Left_Top: // there by default 
	case .Right_Top:
		offset.x -= widget.size.x
	case .Center_Top:
		offset.x -= widget.size.x / 2
	case .Left_Center:
		offset.y -= widget.size.y / 2
	case .Center_Center:
		offset -= widget.size / 2
	case .Right_Center:
		offset.x -= widget.size.x
		offset.y -= widget.size.y / 2
	case .Left_Bottom:
		offset.y -= widget.size.y
	case .Right_Bottom:
		offset -= widget.size
	case .Center_Bottom:
		offset.x -= widget.size.x / 2
		offset.y -= widget.size.y
	}
	widget.position = offset
}

_position_layout_childs :: proc(widget: ^Widget, layout: Layout) {
	total_size: Vec2f32
	for child := widget.node.first_child; child != nil; child = child.node.next {
		if _, ok := child.type.(Floating); ok {continue}
		total_size += child.size + layout.child_gap
	}

	padding := widget.style.padding
	increment: Vec2f32

	switch layout.direction {
	case .X:
		switch layout.child_alignment.x {
		case .Left:
			increment.x = widget.position.x + padding[3]
			for child := widget.node.first_child; child != nil; child = child.node.next {
				if _, ok := child.type.(Floating); ok {continue}
				child.position.x = increment.x
				increment.x += child.size.x + layout.child_gap
			}
		case .Right:
			increment.x = widget.position.x + widget.size.x + layout.child_gap - padding[1]
			for child := widget.node.last_child; child != nil; child = child.node.prev {
				if _, ok := child.type.(Floating); ok {continue}
				increment.x -= child.size.x + layout.child_gap
				child.position.x = increment.x
			}
		case .Center:
			increment.x = widget.position.x + widget.size.x / 2 - total_size.x / 2 + layout.child_gap / 2
			for child := widget.node.first_child; child != nil; child = child.node.next {
				if _, ok := child.type.(Floating); ok {continue}
				child.position.x = increment.x
				increment.x += child.size.x + layout.child_gap
			}
		}
		switch layout.child_alignment.y {
		case .Top:
			increment.y = widget.position.y + padding[0]
			for child := widget.node.first_child; child != nil; child = child.node.next {
				if _, ok := child.type.(Floating); ok {continue}
				child.position.y = increment.y
			}
		case .Bottom:
			increment.y = widget.position.y + widget.size.y - padding[2]
			for child := widget.node.first_child; child != nil; child = child.node.next {
				if _, ok := child.type.(Floating); ok {continue}
				child.position.y = increment.y - child.size.y
			}
		case .Center:
			center := widget.position.y + widget.size.y / 2
			for child := widget.node.first_child; child != nil; child = child.node.next {
				if _, ok := child.type.(Floating); ok {continue}
				child.position.y = center - child.size.y / 2
			}
		}
	case .Y:
		switch layout.child_alignment.x {
		case .Left:
			increment.x = widget.position.x + padding[3]
			for child := widget.node.first_child; child != nil; child = child.node.next {
				if _, ok := child.type.(Floating); ok {continue}
				child.position.x = increment.x
			}
		case .Right:
			increment.x = widget.position.x + widget.size.x - padding[1]
			for child := widget.node.first_child; child != nil; child = child.node.next {
				if _, ok := child.type.(Floating); ok {continue}
				child.position.x = increment.x - child.size.x
			}
		case .Center:
			center := widget.position.x + widget.size.x / 2
			for child := widget.node.first_child; child != nil; child = child.node.next {
				if _, ok := child.type.(Floating); ok {continue}
				child.position.x = center - child.size.x / 2
			}
		}
		switch layout.child_alignment.y {
		case .Center:
			increment.y = widget.position.y + widget.size.y / 2 - total_size.y / 2 + layout.child_gap / 2
			for child := widget.node.first_child; child != nil; child = child.node.next {
				if _, ok := child.type.(Floating); ok {continue}
				child.position.y = increment.y
				increment.y += child.size.y + layout.child_gap
			}
		case .Top:
			increment.y = widget.position.y + padding[0]
			for child := widget.node.first_child; child != nil; child = child.node.next {
				if _, ok := child.type.(Floating); ok {continue}
				child.position.y = increment.y
				increment.y += child.size.y + layout.child_gap
			}
		case .Bottom:
			increment.y = widget.position.y + widget.size.y + layout.child_gap - padding[2]
			for child := widget.node.last_child; child != nil; child = child.node.prev {
				if _, ok := child.type.(Floating); ok {continue}
				increment.y -= child.size.y + layout.child_gap
				child.position.y = increment.y
			}
		}
	}
}

_position_clip_childs :: proc(ctx: ^Core_Context, widget: ^Widget) {
	if clip, ok := &widget.clip.([2]Clip); ok {
		if widget.node.id == ctx.last_hot_widget_id {
			if clip.x.type == .Auto {
				clip.x.value += ctx.mouse.scroll * ctx.delta_time * clip.x.speed
			}
			if clip.y.type == .Auto {
				clip.y.value += ctx.mouse.scroll * ctx.delta_time * clip.y.speed
			}
		}

		for child := widget.node.first_child; child != nil; child = child.node.next {
			if _, ok := child.type.(Floating); ok {continue}
			child.position.x += clip.x.value
			child.position.y += clip.y.value
		}
	}
}

_emit_all :: proc(ctx: ^Core_Context, widget: ^Widget, z_index_offset: ^int) {
	if clip, ok := widget.clip.([2]Clip); ok {
		if ctx.active_clipper != nil {
			if ctx.active_clipper == widget.node.prev {
				_emit_clip_end_command(ctx, ctx.active_clipper, ctx.active_clipper.z_index + z_index_offset^)
				z_index_offset^ += 1
				ctx.active_clipper = nil
			} else if ctx.active_clipper != widget {
				_emit_clip_end_command(ctx, ctx.active_clipper, ctx.active_clipper.z_index + z_index_offset^)
				z_index_offset^ += 1
				append(&ctx.clips, ctx.active_clipper)
			}
		}

		ctx.active_clipper = widget
		_emit_clip_start_command(ctx, widget, widget.z_index + z_index_offset^)
		z_index_offset^ += 1
	}

	_emit_rect_command(ctx, widget, z_index_offset)
	_emit_widget_border_command(ctx, widget, z_index_offset)
	_emit_image_command(ctx, widget, z_index_offset)
	_emit_widget_primitive_commands(ctx, widget, z_index_offset)
	_emit_custom_command(ctx, widget, z_index_offset)
	_emit_text_command(ctx, widget, z_index_offset)

	if widget.node.next == nil && widget.node.first_child == nil {
		for parent := widget.node.parent; parent != nil; parent = parent.node.parent {
			if parent == ctx.active_clipper {
				_emit_clip_end_command(ctx, ctx.active_clipper, ctx.active_clipper.z_index + z_index_offset^)
				z_index_offset^ += 1
				ctx.active_clipper = nil

				if len(ctx.clips) > 0 {
					ctx.active_clipper = pop(&ctx.clips)
					_emit_clip_start_command(ctx, ctx.active_clipper, ctx.active_clipper.z_index + z_index_offset^)
					z_index_offset^ += 1
				}
				break
			}
			if parent.node.next != nil {
				break
			}
		}
	}
}


_emit_clip_end_command :: proc(ctx: ^Core_Context, widget: ^Widget, z_index: int) {
	append(&ctx.render_commands, Render_Command{type = Command_Clip_End{}, z_index = z_index})
}

_emit_clip_start_command :: proc(ctx: ^Core_Context, widget: ^Widget, z_index: int) {
	clip_size := widget.size
	clip_position := widget.position

	if border, ok := widget.style.border.(Border_Style); ok {
		clip_position.x -= border.thickness[3]
		clip_position.y -= border.thickness[0]
		clip_size.x += border.thickness[1] + border.thickness[3]
		clip_size.y += border.thickness[2] + border.thickness[0]
	}

	append(&ctx.render_commands, Render_Command{type = Command_Clip_Start{clip_size = clip_size, clip_position = clip_position}, z_index = z_index})
}

_emit_widget_border_command :: proc(ctx: ^Core_Context, widget: ^Widget, z_index: ^int) {
	if border, ok := widget.style.border.(Border_Style); ok {
		command_border: Command_Border
		command_border.position = widget.position
		command_border.size = widget.size
		command_border.style = border
		append(&ctx.render_commands, Render_Command{type = command_border, z_index = z_index^ + widget.z_index})
		z_index^ += 1
	}
}

_emit_text_command :: proc(ctx: ^Core_Context, widget: ^Widget, z_index: ^int) {
	if text, ok := widget.type.(Text); ok {
		command_text: Command_Text
		widget.position.x += widget.style.padding[3]
		widget.position.y += widget.style.padding[0]
		command_text.cursor = text.cursor
		command_text.position = widget.position
		command_text.style = text.style
		command_text.end = text._end
		command_text.start = text._start
		append(&ctx.render_commands, Render_Command{z_index = z_index^ + widget.z_index, type = command_text})
		z_index^ += 1
	}
}

_emit_rect_command :: proc(ctx: ^Core_Context, widget: ^Widget, z_index: ^int) {
	command_rect: Command_Rect
	command_rect.size = widget.size
	command_rect.position = widget.position
	command_rect.color = widget.style.color
	_clamp_border_radius(widget)
	if style, ok := widget.style.border.(Border_Style); ok {
		command_rect.border_radius = style.radius
	}
	append(&ctx.render_commands, Render_Command{z_index = z_index^ + widget.z_index, type = command_rect})
	z_index^ += 1
}

_emit_image_command :: proc(ctx: ^Core_Context, widget: ^Widget, z_index: ^int) {
	image, ok := widget.image.(Image)
	if ok {
		append(
			&ctx.render_commands,
			Render_Command {
				type = Command_Image{position = widget.position, size = widget.size, image_data = image.image_data, color = image.tint},
				z_index = z_index^ + widget.z_index,
			},
		)
		z_index^ += 1
	}
}

_emit_widget_primitive_commands :: proc(ctx: ^Core_Context, widget: ^Widget, z_index: ^int) {
	if len(widget.primitives) > 0 {
		for &p, i in widget.primitives {
			switch &v in p {
			case Primitive_Rect:
				v.position += widget.position
			case Primitive_Ellipse:
				v.position += widget.position
			case Primitive_Line:
				v.end_position += widget.position
				v.start_position += widget.position
			case Primitive_Points:
				for &point in v.points {
					point += widget.position
				}
			case Primitive_Custom:
			}

			append(&ctx.render_commands, Render_Command{z_index = z_index^ + i + widget.z_index, type = p})
		}
		z_index^ += len(widget.primitives)
	}
}

_emit_custom_command :: proc(ctx: ^Core_Context, widget: ^Widget, z_index: ^int) {
	if custom_data, ok := widget.custom_data.(rawptr); ok {
		append(
			&ctx.render_commands,
			Render_Command{type = Command_Custom{position = widget.position, data = custom_data}, z_index = z_index^ + widget.z_index},
		)
		z_index^ += 1
	}
}
