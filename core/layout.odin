package ui_core

import "core:container/small_array"
import "core:fmt"
import "core:os"
import "core:sort"

Axis :: enum u8 {
	X,
	Y,
}

Layout_Direction :: Axis

Layout_Kind :: enum u8 {
	Fit,
	Grow,
	Fixed,
	Percent,
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

Attachment_To :: enum u8 {
	Parent,
	None,
	Root,
	Id,
}

Offset_Kind :: enum u8 {
	None,
	Fixed, // Set position to what was provided
	Relative, // Offset Relative to Parent position 
	Percent, // percent of parent size 
}

Expand_Kind :: enum u8 {
	None,
	Percent,
	Absolute,
}

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
Word_Measure :: struct {
	text:          string,
	start_index:   int,
	spaces_before: i32,
	width:         f32,
}

@(private = "file")
Growable :: struct {
	size:    ^Vec2f32,
	min:     f32,
	max:     f32,
	is_text: bool,
}

_fit_into_parent :: proc(axis: Axis, widget: ^Widget) {
	parent := widget.node.parent

	if parent == nil {return}

	parent_layout, parent_is_layout := _get_layout(parent)

	if !parent_is_layout {
		return
	}

	if parent_layout.sizing[axis].kind == .Fit {
		if parent_layout.direction == axis {
			parent.size[axis] += widget.size[axis]
		} else {
			parent.size[axis] = max(parent.size[axis], widget.size[axis])
		}
	}

	widget_layout, widget_is_layout := _get_layout(widget)
	if !widget_is_layout {
		if parent_layout.direction == axis {
			parent._min[axis] += widget._min[axis]
		} else {
			parent._min[axis] = max(parent._min[axis], widget._min[axis])
		}
		return
	}

	padding: f32 = _get_axis_padding(axis, widget_layout.padding)

	if widget_layout.direction == axis {
		if widget_layout.sizing[axis].kind == .Fit {
			widget.size[axis] += max(0, f32(widget.node.total_children - 1) * widget_layout.child_gap)
		}
		widget._min[axis] += max(0, f32(widget.node.total_children - 1) * widget_layout.child_gap)
	}

	widget._min[axis] += padding
	widget.size[axis] += padding
	widget.size[axis] = max(widget.size[axis], widget_layout.sizing[axis].min)
	widget.size[axis] = min(widget.size[axis], widget_layout.sizing[axis].max)

	if parent_layout.direction == axis {
		parent._min[axis] += widget.size[axis]
	} else {
		parent._min[axis] = max(parent._min[axis], widget.size[axis])
	}

	return
}

_grow_shrink_children_along_axis :: proc(axis: Axis, layout: Layout, widget: ^Widget, growables: ^[dynamic]Growable) {
	if widget.node.first_child == nil {return}

	remaining: f32 = widget.size[axis] - _get_axis_padding(axis, layout.padding)

	remaining -= layout.child_gap * f32(widget.node.total_children - 1)

	for child_widget := widget.node.first_child; child_widget != nil; child_widget = child_widget.node.next {
		switch type in child_widget.config {
		case Floating:
			if type.layout.sizing[axis].kind == .Grow {
				child_widget.size[axis] = child_widget.node.parent.size[axis]
			}
			if type.layout.sizing[axis].kind == .Percent {
				child_widget.size[axis] = max(child_widget._min[axis], widget.size[axis] * type.layout.sizing[axis].min)
			}
			continue
		case Layout:
			switch type.sizing[axis].kind {
			case .Grow:
				child_widget.size[axis] = max(child_widget._min[axis], type.sizing[axis].min)
				append(growables, Growable{&child_widget.size, child_widget.size[axis], type.sizing[axis].max, false})
			case .Percent:
				s :=
					(widget.size[axis] - _get_axis_padding(axis, layout.padding) - f32(widget.node.total_children - 1) * layout.child_gap) *
					type.sizing[axis].min
				child_widget.size[axis] = max(child_widget._min[axis], s)
			case .Fixed:
			case .Fit:
			}
		case Text:
			if axis != .Y {
				append(growables, Growable{&child_widget.size, child_widget._min.x, max(f32), true})
			}
		}
		remaining -= child_widget.size[axis]
	}

	if len(growables) == 0 {return}

	if remaining >= 0 {
		// as long as there is space, distribute it, 1e-9 for floating point err   
		for remaining >= 1e-9 && len(growables) > 0 {
			smallest: f32 = growables[0].size[axis]
			second_smallest: f32 = max(f32)
			to_add: f32 = remaining
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
			to_add = min(to_add, remaining / cast(f32)len(growables))
			#reverse for child, i in growables {
				if child.size[axis] == smallest {
					child.size[axis] += to_add
					remaining -= to_add
				}
				if child.size[axis] > child.max {
					size := child.size[axis]
					child.size[axis] = child.max
					remaining += size - child.max
					ordered_remove(growables, i)
				}
			}
		}
	} else {
		// if remaining width is negative we need to shrink largest containers to make space 
		remaining = abs(remaining)
		for remaining >= 1e-9 && len(growables) > 0 {
			largest: f32 = growables[0].size[axis]
			second_largest: f32 = min(f32)
			to_subtract: f32 = remaining

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

			to_subtract = min(to_subtract, remaining / cast(f32)len(growables))

			#reverse for child, i in growables {
				if child.size[axis] == largest {
					child.size[axis] -= to_subtract
					remaining -= to_subtract
				}
				if child.size[axis] < child.min {
					remaining += child.min - child.size[axis]
					child.size[axis] = child.min
					ordered_remove(growables, i)
				}
			}
		}
	}
}

_grow_children_across_axis :: proc(axis: Axis, layout: Layout, widget: ^Widget) {
	if widget.node.first_child == nil {return}

	axis_padding: f32 = _get_axis_padding(axis, layout.padding)

	for child_widget := widget.node.first_child; child_widget != nil; child_widget = child_widget.node.next {
		layout, is_text := _get_layout(child_widget)
		if !is_text {
			parent_layout, _ := _get_layout(widget)
			if parent_layout.direction == .Y && axis == .X && child_widget.size.x > widget.size.x {
				child_widget.size.x = widget.size.x - _get_axis_padding(.X, parent_layout.padding)
			}
			continue
		}

		if layout.sizing[axis].kind == .Percent {
			child_widget.size[axis] =
				(widget.size[axis] - _get_axis_padding(axis, layout.padding) - f32(widget.node.total_children - 1) * layout.child_gap) *
				layout.sizing[axis].min
			child_widget.size[axis] = max(child_widget._min[axis], child_widget.size[axis])
		}
		if layout.sizing[axis].kind == .Grow {
			child_min := max(child_widget._min[axis], layout.sizing[axis].min)
			child_widget.size[axis] = max(widget.size[axis] - axis_padding, child_min)
			child_widget.size[axis] = min(child_widget.size[axis], layout.sizing[axis].max)
		}
	}
}

_layout_sizing_pass :: proc(ctx: ^Core_Context) {
	#reverse for w in ctx.stacks.post_r {

		layout: Layout = _get_layout(w) or_continue

		for sizing, i in layout.sizing {
			w.size[i] = sizing.min
		}
	}

	#reverse for w in ctx.stacks.post_r {
		_fit_into_parent(.X, w)
		switch type in w.config {
		case Layout:
		case Floating:
		case Text:
			w.size = ctx.text_measure_proc(type.text, type.style)
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

	measured_words := make([dynamic]Word_Measure, context.temp_allocator)
	for widget in ctx.stacks.pre {
		switch &type in widget.config {
		case Layout:
			continue
		case Floating:
			continue
		case Text:
			if len(type.text) == 0 {
				continue
			}

			word_start: int
			in_word: bool
			largest_width: f32
			for r, i in type.text {
				if r == ' ' {
					if in_word {
						w := type.text[word_start:i]

						spaces_before: i32 = 0
						for r_w in w {
							if r_w != ' ' {
								break
							}
							spaces_before += 1
							word_start += 1
						}
						word := type.text[word_start:i]
						width := ctx.text_measure_proc(word, type.style)
						largest_width = max(width, largest_width)
						append(&measured_words, Word_Measure{text = word, width = width, spaces_before = spaces_before, start_index = word_start})

						word_start = i
						in_word = false
					}
				} else {
					if !in_word {
						in_word = true
					}
				}
			}

			if in_word && word_start < len(type.text) {
				word := type.text[word_start:]
				space_count: i32 = 0

				for wr, _ in word {
					if wr != ' ' {
						break
					}
					space_count += 1
					word_start += 1
				}
				word = type.text[word_start:]
				width := ctx.text_measure_proc(word, type.style)
				largest_width = max(width, largest_width)
				append(&measured_words, Word_Measure{text = word, width = width, spaces_before = space_count, start_index = word_start})
			}

			x: f32 = 0
			space_width := ctx.text_measure_proc(" ", type.style)

			wrapping: bool
			line_start: int = 0

			widget_lines_start := len(ctx.text_lines)
			for w in measured_words {
				x += space_width * f32(w.spaces_before)
				if x + w.width > widget.size.x {
					x = 0
					append(&ctx.text_lines, type.text[line_start:w.start_index])
					line_start = w.start_index
					wrapping = true
				}
				x += w.width
			}

			if line_start < len(type.text) {
				append(&ctx.text_lines, type.text[line_start:])
			}
			type._start = widget_lines_start
			type._end = len(ctx.text_lines)
			widget.size.y = f32(type._end - type._start) * type.style.line_spacing
			widget._min = {largest_width, widget.size.y}
			clear(&measured_words)
		}
	}

	#reverse for w in ctx.stacks.post_r {
		_fit_into_parent(.Y, w)
	}

	for w in ctx.stacks.pre {
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

_layout_positioning_pass :: proc(ctx: ^Core_Context) {
	for widget, i in ctx.stacks.pre {
		layout: Layout

		if widget.node.parent != nil {
			widget._z_index = widget.node.parent._z_index + 1 + i
		}

		switch type in widget.config {
		case Floating:
			layout = type.layout
			anchor_pos: Vec2f32
			anchor_size: Vec2f32

			switch type.attachment_to {
			case .Id:
				val, ok := ctx.persistant_data[type.id]
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
			switch type.parent {
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
			switch type.element {
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
		case Layout:
			layout = type
		case Text:
			for offset, i in widget.offset {
				switch offset.kind {
				case .None:
				case .Fixed:
					widget.position[i] = offset.value
				case .Relative:
					widget.position[i] += offset.value
				case .Percent:
					if widget.node.parent != nil {
						widget.position[i] += offset.value * widget.node.parent.size[i]
					}
				}
			}

			for expand, i in widget.expand {
				switch expand.kind {
				case .None:
				case .Absolute:
					widget.size[i] += expand.value
				case .Percent:
					if widget.node.parent != nil {
						widget.size[i] += expand.value * widget.node.parent.size[i]
					}
				}
			}
			command_rect: Command_Rect
			command_rect.size = widget.size
			command_rect.color = widget.style.color
			command_rect.position = widget.position
			command_rect.border_radius = widget.style.border_radius
			command_rect.border_thickness = widget.style.border_thickness
			append(&ctx.render_commands, Render_Command{z_index = widget._z_index, type = command_rect})
			command_text: Command_Text
			command_text.position = widget.position
			command_text.style = type.style
			command_text.end = type._end
			command_text.start = type._start
			append(&ctx.render_commands, Render_Command{z_index = widget._z_index, type = command_text})
			continue // Text never has children hence skip. This loops goes from top to bottom into the tree. Any text will have its position resolved always 
		}

		total_size: Vec2f32
		for child := widget.node.first_child; child != nil; child = child.node.next {
			total_size += child.size + layout.child_gap
		}
		padding := layout.padding
		position_increment: Vec2f32

		switch layout.direction {
		case .X:
			switch layout.child_alignment.x {
			case .Left:
				position_increment.x = widget.position.x + padding[3]
				for child := widget.node.first_child; child != nil; child = child.node.next {
					child.position.x = position_increment.x
					position_increment.x += child.size.x + layout.child_gap
				}
			case .Right:
				position_increment.x = widget.position.x + widget.size.x + layout.child_gap - padding[1]
				for child := widget.node.last_child; child != nil; child = child.node.prev {
					position_increment.x -= child.size.x + layout.child_gap
					child.position.x = position_increment.x
				}
			case .Center:
				position_increment.x = widget.position.x + widget.size.x / 2 - total_size.x / 2
				for child := widget.node.first_child; child != nil; child = child.node.next {
					child.position.x = position_increment.x
					position_increment.x += child.size.x + layout.child_gap
				}
			}
			switch layout.child_alignment.y {
			case .Top:
				position_increment.y = widget.position.y + padding[0]
				for child := widget.node.first_child; child != nil; child = child.node.next {
					child.position.y = position_increment.y
				}
			case .Bottom:
				position_increment.y = widget.position.y + widget.size.y - padding[2]
				for child := widget.node.first_child; child != nil; child = child.node.next {
					child.position.y = position_increment.y - child.size.y
				}
			case .Center:
				center := widget.position.y + widget.size.y / 2
				for child := widget.node.first_child; child != nil; child = child.node.next {
					child.position.y = center - child.size.y / 2
				}
			}
		case .Y:
			switch layout.child_alignment.x {
			case .Left:
				position_increment.x = widget.position.x + padding[3]
				for child := widget.node.first_child; child != nil; child = child.node.next {
					child.position.x = position_increment.x
				}
			case .Right:
				position_increment.x = widget.position.x + widget.size.x - padding[1]
				for child := widget.node.first_child; child != nil; child = child.node.next {
					child.position.x = position_increment.x - child.size.x
				}
			case .Center:
				center := widget.position.x + widget.size.x / 2
				for child := widget.node.first_child; child != nil; child = child.node.next {
					child.position.x = center - child.size.x / 2
				}
			}
			switch layout.child_alignment.y {
			case .Center:
				position_increment.y = widget.position.y + widget.size.y / 2 - total_size.y / 2
				for child := widget.node.first_child; child != nil; child = child.node.next {
					child.position.y = position_increment.y
					position_increment.y += child.size.y + layout.child_gap
				}
			case .Top:
				position_increment.y = widget.position.y + padding[0]
				for child := widget.node.first_child; child != nil; child = child.node.next {
					child.position.y = position_increment.y
					position_increment.y += child.size.y + layout.child_gap
				}
			case .Bottom:
				position_increment.y = widget.position.y + widget.size.y - padding[2]
				for child := widget.node.last_child; child != nil; child = child.node.prev {
					position_increment.y -= child.size.y + layout.child_gap
					child.position.y = position_increment.y
				}
			}
		}

		for offset, i in widget.offset {
			switch offset.kind {
			case .None:
			case .Fixed:
				widget.position[i] = offset.value
			case .Relative:
				widget.position[i] += offset.value
			case .Percent:
				if widget.node.parent != nil {
					widget.position[i] += offset.value * widget.node.parent.size[i]
				}
			}
		}

		for expand, i in widget.expand {
			switch expand.kind {
			case .None:
			case .Absolute:
				widget.size[i] += expand.value * 2
				widget.position[i] -= expand.value
			case .Percent:
				if widget.node.parent != nil {
					v := expand.value * widget.node.parent.size[i]
					widget.size[i] += v * 2
					widget.position[i] -= v
				}
			}
		}

		for r, i in widget.style.border_radius {
			widget.style.border_radius[i] = clamp(0, min(widget.size.x, widget.size.y) / 2, r)
		}

		if _is_point_in_rect(widget.position, widget.size, ctx.mouse.position, widget.style.border_radius) && ctx.active_widget_id == 0 {
			ctx.hot_widget_id = widget.node.id
		}

		command_rect: Command_Rect
		command_rect.size = widget.size
		command_rect.color = widget.style.color
		command_rect.position = widget.position
		command_rect.border_radius = widget.style.border_radius
		command_rect.border_thickness = widget.style.border_thickness
		append(&ctx.render_commands, Render_Command{z_index = widget._z_index, type = command_rect})

		if len(widget.primitives) > 0 {
			append(
				&ctx.render_commands,
				Render_Command{type = Command_Clip_Start{clip_size = widget.size, clip_position = widget.position}, z_index = widget._z_index},
			)
			defer widget._z_index += len(widget.primitives) + 1
			defer append(&ctx.render_commands, Render_Command{type = Command_Clip_End{}, z_index = widget._z_index + len(widget.primitives)})
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
				}
				append(&ctx.render_commands, Render_Command{z_index = widget._z_index + i + 1, type = p})
			}
		}
	}
	sort.quick_sort_proc(ctx.render_commands[:], proc(a, b: Render_Command) -> int {return a.z_index - b.z_index})
}

_build_stacks :: proc(ctx: ^Core_Context) {
	append(&ctx.stacks.temp, &ctx.widgets[0]) // append root node 

	// Perhaps I should make this a breathd first tree instead of depth first tree

	for {
		widget := pop_safe(&ctx.stacks.temp) or_break

		append(&ctx.stacks.post_r, widget)

		for child_widget := widget.node.first_child; child_widget != nil; child_widget = child_widget.node.next {
			append(&ctx.stacks.temp, child_widget)
		}
	}

	clear(&ctx.stacks.temp)
	append(&ctx.stacks.temp, &ctx.widgets[0])

	for {
		widget := pop_safe(&ctx.stacks.temp) or_break

		append(&ctx.stacks.pre, widget)

		for child_widget := widget.node.last_child; child_widget != nil; child_widget = child_widget.node.prev {
			append(&ctx.stacks.temp, child_widget)
		}
	}

	clear(&ctx.stacks.temp)
}
