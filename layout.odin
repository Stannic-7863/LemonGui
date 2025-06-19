package main

import "core:fmt"
import "core:sort"

Direction :: enum {
	Row,
	Colom,
}

Kind :: enum {
	Fit,
	Grow,
	Fixed,
	Percent,
}

Child_Alignment_X :: enum {
	Left,
	Center,
	Right,
}

Child_Alignment_Y :: enum {
	Top,
	Center,
	Bottom,
}

Attachment_Points :: enum {
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

Attachment_To :: enum {
	Parent,
	Root,
	None,
	Id,
}

Child_Alignment :: struct {
	x: Child_Alignment_X,
	y: Child_Alignment_Y,
}

Sizing :: struct {
	min, max: f32,
	kind:     Kind,
}

Floating :: struct {
	attachments:    struct {
		parent:  Attachment_Points,
		element: Attachment_Points,
	},
	attachment_to:  Attachment_To,
	expand, offset: Vec2f32,
	id:             Id,
}

Layout :: struct {
	min:             Vec2f32,
	sizing:          [2]Sizing,
	direction:       Direction,
	child_alignment: Child_Alignment,
}

@(private = "file")
Growable :: struct {
	min:  f32,
	max:  f32,
	size: ^Vec2f32,
}

layout_fit :: proc(axis: int, widget: ^Widget) {
	parent := widget.node.parent

	if widget.text != "" {
		widget.size[axis] += widget.prev_text_size[axis]
		widget.size[axis] += widget.style.child_gap
	}

	if parent == nil {return}

	if parent.layout.sizing[axis].kind == .Fit {
		if cast(int)parent.layout.direction == axis {
			parent.size[axis] += widget.size[axis]
		} else {
			parent.size[axis] = max(parent.size[axis], widget.size[axis])
		}
	}
}

layout_grow_along_axis :: proc(axis: int, widget: ^Widget, growables: ^[dynamic]Growable) {
	if widget.node.first_child == nil {return}

	axis_padding: f32
	total_child_gaps: f32 = widget.style.child_gap * f32(widget.node.total_children - 1)

	if axis == 0 {
		axis_padding = widget.style.padding[3] + widget.style.padding[1] // left + right 
	}
	if axis == 1 {
		axis_padding = widget.style.padding[0] + widget.style.padding[2] // top + bottom 
	}

	remaining: f32 = widget.size[axis] - widget.text_size.x

	if widget.text != "" && axis != 1 {
		append(growables, Growable{size = &widget.text_size, max = widget.text_size[axis], min = widget.prev_text_size.x})
		remaining -= widget.style.child_gap
	}
	remaining -= axis_padding
	remaining -= total_child_gaps

	for child_widget := widget.node.first_child; child_widget != nil; child_widget = child_widget.node.next {

		if child_widget.floating != {} {
			if child_widget.layout.sizing[axis].kind == .Grow {
				child_widget.size[axis] = max(child_widget.layout.min[axis], child_widget.layout.sizing[axis].min)
				child_widget.size[axis] += child_widget.node.parent.size[axis] + child_widget.floating.expand[axis]
			}
			if child_widget.layout.sizing[axis].kind == .Percent {
				child_widget.size[axis] =
					widget.size[axis] * child_widget.layout.sizing[axis].min -
					(axis_padding + total_child_gaps) +
					child_widget.floating.expand[axis]
				child_widget.size[axis] = max(child_widget.layout.min[axis], child_widget.size[axis])
			}
			continue
		}

		if child_widget.layout.sizing[axis].kind != .Grow {
			if child_widget.layout.sizing[axis].kind == .Percent {
				child_widget.size[axis] = widget.size[axis] * child_widget.layout.sizing[axis].min - (axis_padding + total_child_gaps)
			}
			remaining -= child_widget.size[axis]
		} else {
			child_widget.size[axis] = max(child_widget.layout.min[axis], child_widget.layout.sizing[axis].min)
			append(
				growables,
				Growable{size = &child_widget.size, min = child_widget.size[axis], max = child_widget.layout.sizing[axis].max},
			)
			remaining -= child_widget.size[axis]
		}

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
				if child.size[axis] < smallest {
					smallest = child.size[axis]
					second_smallest = smallest
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

layout_grow_across_axis :: proc(axis: int, widget: ^Widget) {
	if widget.node.first_child == nil {return}

	axis_padding: f32

	if axis == 0 {
		axis_padding += widget.style.padding[3] + widget.style.padding[1]
	}
	if axis == 1 {
		axis_padding += widget.style.padding[0] + widget.style.padding[2]
	}

	for child_widget := widget.node.first_child; child_widget != nil; child_widget = child_widget.node.next {
		if child_widget.layout.sizing[axis].kind == .Percent {
			child_widget.size[axis] = widget.size[axis] * child_widget.layout.sizing[axis].min - axis_padding
			child_widget.size[axis] = max(child_widget.layout.min[axis], child_widget.size[axis])
		}
		if child_widget.layout.sizing[axis].kind == .Grow {
			child_min := max(child_widget.layout.min[axis], child_widget.layout.sizing[axis].min)
			child_widget.size[axis] = max(widget.size[axis] - axis_padding, child_min)
			child_widget.size[axis] = min(child_widget.size[axis], child_widget.layout.sizing[axis].max)
		}
	}
}

layout_sizing_pass :: proc(ctx: ^Core_Context) {
	#reverse for w in ctx.stacks.reverse_post {
		for sizing, i in w.layout.sizing {
			w.size[i] = sizing.min
		}
		if w.node.first_child != nil {
			w.layout.min.x += w.style.padding[3] + w.style.padding[1]
			w.layout.min.y += w.style.padding[2] + w.style.padding[0]
			if w.layout.direction == .Row {
				w.layout.min.x += f32(w.node.total_children - 1) * w.style.child_gap
			}
			if w.layout.direction == .Colom {
				w.layout.min.y += f32(w.node.total_children - 1) * w.style.child_gap
			}
		}
		w.layout.min += w.floating.expand
		w.size += w.floating.expand
		if w.text != "" {
			if w.node.first_child != nil {
				w.layout.min.x += w.style.child_gap
			} else {
				w.layout.min.x += w.style.padding[3] + w.style.padding[1]
				w.layout.min.y += w.style.padding[2] + w.style.padding[0]
			}
			w.layout.min.x += w.prev_text_size.x
			w.layout.min.y += w.prev_text_size.y
		}
	}

	#reverse for w in ctx.stacks.reverse_post {
		layout_fit(0, w)

		if w.layout.sizing.x.kind == .Fit {
			if w.node.first_child != nil {
				w.size.x += w.style.padding[3] + w.style.padding[1]
			}
			if w.layout.direction == .Row {
				w.size.x += f32(w.node.total_children - 1) * w.style.child_gap
			}
		}

		w.size.x = max(w.size.x, w.layout.sizing.x.min)
		w.size.x = min(w.size.x, w.layout.sizing.x.max)

		if w.node.parent != nil {
			if w.node.parent.layout.direction == .Row {
				w.node.parent.layout.min.x += w.size.x
			} else {
				w.node.parent.layout.min.x = max(w.node.parent.layout.min.x, w.size.x + w.style.padding[3] + w.style.padding[1])
			}
		}
	}


	growables := make([dynamic]Growable, 0, 16, context.temp_allocator)
	for w in ctx.stacks.pre {
		w.text_size = ctx.text_measure_proc(w.text, w.style.text)
		if w.layout.direction == .Row {
			layout_grow_along_axis(0, w, &growables)
			clear(&growables)
		} else {
			layout_grow_across_axis(0, w)
			clear(&growables)
		}
	}

	measured_words := make([dynamic]Word_Measure, context.temp_allocator)
	for widget in ctx.stacks.pre {
		if len(widget.text) == 0 {
			continue
		}

		word_start: int
		in_word: bool
		largest_width: f32
		for r, i in widget.text {
			if r == ' ' {
				if in_word {
					w := widget.text[word_start:i]

					spaces_before: i32 = 0
					for r_w in w {
						if r_w != ' ' {
							break
						}
						spaces_before += 1
						word_start += 1
					}
					text := widget.text[word_start:i]
					width := ctx.text_measure_proc(text, widget.style.text)
					largest_width = max(width, largest_width)
					append(
						&measured_words,
						Word_Measure{text = text, width = width, spaces_before = spaces_before, start_index = word_start},
					)

					word_start = i
					in_word = false
				}
			} else {
				if !in_word {
					in_word = true
				}
			}
		}

		if in_word && word_start < len(widget.text) {
			word := widget.text[word_start:]
			space_count: i32 = 0

			for wr, _ in word {
				if wr != ' ' {
					break
				}
				space_count += 1
				word_start += 1
			}
			word = widget.text[word_start:]
			width := ctx.text_measure_proc(word, widget.style.text)
			largest_width = max(width, largest_width)
			append(&measured_words, Word_Measure{text = word, width = width, spaces_before = space_count, start_index = word_start})
		}

		x: f32 = 0
		space_width := ctx.text_measure_proc(" ", widget.style.text)

		wrapping: bool
		line_start: int = 0

		widget_lines_start := len(ctx.text_lines)

		width: f32
		if widget.layout.direction == .Row {
			width = widget.text_size.x
		} else {
			width = widget.size.x - (widget.style.padding[1] + widget.style.padding[3])

			if width < widget.text_size.x {
				widget.text_size.x = width
			}

		}

		for w in measured_words {
			x += space_width * f32(w.spaces_before)
			if x + w.width > width {
				x = 0
				new_line := widget.text[line_start:w.start_index]
				append(&ctx.text_lines, new_line)
				line_start = w.start_index
				wrapping = true
			}
			x += w.width
		}

		if line_start < len(widget.text) {
			append(&ctx.text_lines, widget.text[line_start:])
		}
		widget.lines = ctx.text_lines[widget_lines_start:len(ctx.text_lines)]
		widget.text_size.y = f32(len(widget.lines)) * widget.style.text.line_height
		widget.prev_text_size.x = largest_width
		widget.prev_text_size.y = widget.text_size.y
		clear(&measured_words)
	}

	#reverse for w in ctx.stacks.reverse_post {
		layout_fit(1, w)

		if w.layout.sizing.y.kind == .Fit {
			if w.node.first_child != nil {
				w.size.y += w.style.padding[0] + w.style.padding[2]
			}
			if w.layout.direction == .Colom {
				w.size.y += f32(w.node.total_children - 1) * w.style.child_gap
			}
		}

		w.size.y = max(w.size.y, w.layout.sizing.y.min)
		w.size.y = min(w.size.y, w.layout.sizing.y.max)

		if w.node.parent != nil {
			if w.node.parent.layout.direction == .Colom {
				w.node.parent.layout.min.y += w.size.y
			} else {
				w.node.parent.layout.min.y = max(w.node.parent.layout.min.y, w.size.y + w.style.padding[0] + w.style.padding[2])
			}
		}
	}

	for w in ctx.stacks.pre {
		if w.layout.direction == .Colom {
			layout_grow_along_axis(1, w, &growables)
			clear(&growables)
		} else {
			layout_grow_across_axis(1, w)
			clear(&growables)
		}

	}
}

layout_positioning_pass :: proc(ctx: ^Core_Context) {

	for widget in ctx.stacks.pre {
		along_axis: int = cast(int)widget.layout.direction

		total_size: Vec2f32

		for child := widget.node.first_child; child != nil; child = child.node.next {
			total_size[along_axis] += child.size[along_axis] + widget.style.child_gap
		}

		if widget.text != "" {
			total_size[along_axis] += widget.text_size[along_axis] + widget.style.child_gap
		}

		padding := widget.style.padding
		position_increment: Vec2f32

		if widget.floating != {} {

			anchor_pos: Vec2f32
			anchor_size: Vec2f32

			switch widget.floating.attachment_to {
			case .Id:
				val, ok := ctx.persistant_data[widget.floating.id]
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
			switch widget.floating.attachments.parent {
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
			switch widget.floating.attachments.element {
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
			widget.position = offset + widget.floating.offset
		}

		if along_axis == 0 {
			switch widget.layout.child_alignment.x {
			case .Left:
				position_increment.x = widget.position.x + widget.text_size.x + padding[3]
				if widget.text != "" {
					position_increment.x += widget.style.child_gap
				}
				for child := widget.node.first_child; child != nil; child = child.node.next {
					child.position.x = position_increment.x
					position_increment.x += child.size.x + widget.style.child_gap
				}
				widget.text_position.x = widget.position.x + padding[3]
			case .Right:
				position_increment.x = widget.position.x + widget.size.x + widget.style.child_gap - padding[1]
				for child := widget.node.last_child; child != nil; child = child.node.prev {
					position_increment.x -= child.size.x + widget.style.child_gap
					child.position.x = position_increment.x
				}
				widget.text_position.x = position_increment.x - (widget.text_size.x + widget.style.child_gap)
			case .Center:
				position_increment.x = widget.position.x + widget.size.x / 2 - total_size.x / 2
				widget.text_position.x = position_increment.x
				if widget.text != "" {
					position_increment.x += widget.text_size.x + widget.style.child_gap
				}
				for child := widget.node.first_child; child != nil; child = child.node.next {
					child.position.x = position_increment.x
					position_increment.x += child.size.x + widget.style.child_gap
				}
			}
			switch widget.layout.child_alignment.y {
			case .Top:
				position_increment.y = widget.position.y + padding[0]
				widget.text_position.y = position_increment.y
				for child := widget.node.first_child; child != nil; child = child.node.next {
					child.position.y = position_increment.y
				}
			case .Bottom:
				position_increment.y = widget.position.y + widget.size.y - padding[2]
				widget.text_position.y = position_increment.y - widget.text_size.y
				for child := widget.node.first_child; child != nil; child = child.node.next {
					child.position.y = position_increment.y - child.size.y
				}
			case .Center:
				center := widget.position.y + widget.size.y / 2
				for child := widget.node.first_child; child != nil; child = child.node.next {
					child.position.y = center - child.size.y / 2
				}
				widget.text_position.y = center - widget.text_size.y / 2
			}
		}
		if along_axis == 1 {
			switch widget.layout.child_alignment.x {
			case .Left:
				position_increment.x = widget.position.x + padding[3]
				widget.text_position.x = position_increment.x
				for child := widget.node.first_child; child != nil; child = child.node.next {
					child.position.x = position_increment.x
				}
			case .Right:
				position_increment.x = widget.position.x + widget.size.x - padding[1]
				for child := widget.node.first_child; child != nil; child = child.node.next {
					child.position.x = position_increment.x - child.size.x
				}
				widget.text_position.x = position_increment.x - widget.text_size.x
			case .Center:
				center := widget.position.x + widget.size.x / 2
				for child := widget.node.first_child; child != nil; child = child.node.next {
					child.position.x = center - child.size.x / 2
				}
				widget.text_position.x = center - widget.text_size.x / 2
			}
			switch widget.layout.child_alignment.y {
			case .Center:
				position_increment.y = widget.position.y + widget.size.y / 2 - total_size.y / 2
				widget.text_position.y = position_increment.y
				if widget.text != "" {
					position_increment.y += widget.text_size.y + widget.style.child_gap
				}
				for child := widget.node.first_child; child != nil; child = child.node.next {
					child.position.y = position_increment.y
					position_increment.y += child.size.y + widget.style.child_gap
				}
			case .Top:
				position_increment.y = widget.position.y + padding[0]
				if widget.text != "" {
					widget.text_position.y = position_increment.y
					position_increment.y += widget.text_size.y + widget.style.child_gap
				}
				for child := widget.node.first_child; child != nil; child = child.node.next {
					child.position.y = position_increment.y
					position_increment.y += child.size.y + widget.style.child_gap
				}
			case .Bottom:
				position_increment.y = widget.position.y + widget.size.y + widget.style.child_gap - padding[2]
				for child := widget.node.last_child; child != nil; child = child.node.prev {
					position_increment.y -= child.size.y + widget.style.child_gap
					child.position.y = position_increment.y
				}
				widget.text_position.y = position_increment.y - (widget.text_size.y + widget.style.child_gap)
			}
		}

		for r, i in widget.target.border_radius {
			widget.target.border_radius[i] = clamp(0, min(widget.size.x, widget.size.y) / 2, r)
		}

		if is_point_in_rect(widget.position, widget.size, ctx.mouse.position, widget.style.border_radius) &&
		   ctx.active_widget_id == 0 &&
		   widget.events_mask != ~{} {
			ctx.hot_widget_id = widget.node.id
		}

		if widget.node.parent != nil {
			widget.z_index = widget.node.parent.z_index + 1
		}

		command_rect: Command_Rect
		command_rect.size = widget.size
		command_rect.color = widget.style.color
		command_rect.position = widget.position
		command_rect.border_radius = widget.style.border_radius
		command_rect.border_thickness = widget.style.border_thickness

		append(&ctx.render_commands, Render_Command{widget.z_index, command_rect})

		if widget.text != "" {
			command_text: Command_Text
			command_text.color = WHITE
			command_text.position = widget.text_position
			command_text.spacing = widget.style.text.spacing
			command_text.font_size = widget.style.text.font_size
			command_text.line_height = widget.style.text.line_height
			command_text.lines = widget.lines
			append(&ctx.render_commands, Render_Command{widget.z_index + 1, command_text})
		}
	}

	sort.quick_sort_proc(ctx.render_commands[:], proc(a, b: Render_Command) -> int {return a.z_index - b.z_index})
}

build_stacks :: proc(ctx: ^Core_Context) {
	append(&ctx.stacks.temp, &ctx.widgets[0]) // append root node 

	for {
		widget := pop_safe(&ctx.stacks.temp) or_break

		append(&ctx.stacks.reverse_post, widget)

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
