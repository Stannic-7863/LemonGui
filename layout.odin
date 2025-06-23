package main

import "core:fmt"
import "core:sort"

Layout_Direction :: enum u8 {
	Row,
	Colom,
}

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

Floating :: struct {
	layout:          Layout,
	parent_id:       Id,
	parent, element: Anchor,
	attachment_to:   Attachment_To,
}

Layout :: struct {
	sizing:          [2]Sizing,
	padding:         Vec4f32,
	child_gap:       f32,
	child_alignment: Child_Alignment,
	direction:       Layout_Direction,
}

Text :: struct {
	text:       string,
	start, end: int, // index into ctx.text_lines 
	min:        f32,
}

@(private = "file")
Growable :: struct {
	size: ^Vec2f32,
	min:  f32,
	max:  f32,
}

fit_into_parent :: proc(axis: int, widget: ^Widget) {
	parent := widget.node.parent

	if parent == nil {return}

	parent_layout: Layout

	switch type in parent.config {
	case Floating:
		parent_layout = type.layout
	case Layout:
		parent_layout = type
	case Text:
		return
	}

	if parent_layout.sizing[axis].kind == .Fit {
		if cast(int)parent_layout.direction == axis {
			parent.size[axis] += widget.size[axis]
		} else {
			parent.size[axis] = max(parent.size[axis], widget.size[axis])
		}
	}

	widget_layout: Layout
	switch type in widget.config {
	case Floating:
		widget_layout = type.layout
	case Layout:
		widget_layout = type
	case Text:
	}

	padding: f32

	if axis == 0 {
		padding = widget_layout.padding[3] + widget_layout.padding[1]
	}
	if axis == 1 {
		padding = widget_layout.padding[0] + widget_layout.padding[2]
	}

	if cast(int)widget_layout.direction == axis {
		if widget_layout.sizing[axis].kind == .Fit {
			widget.size[axis] += max(0, f32(widget.node.total_children - 1) * widget_layout.child_gap)
		}
		widget._min[axis] += max(0, f32(widget.node.total_children - 1) * widget_layout.child_gap)
	}

	widget._min[axis] += padding
	widget.size[axis] += padding
	widget.size[axis] = max(widget.size[axis], widget_layout.sizing[axis].min)
	widget.size[axis] = min(widget.size[axis], widget_layout.sizing[axis].max)

	if cast(int)parent_layout.direction == axis {
		parent._min[axis] += widget.size[axis]
	} else {
		parent._min[axis] = max(parent._min[axis], widget.size[axis])
	}

}

grow_shrink_children_along_axis :: proc(axis: int, layout: Layout, widget: ^Widget, growables: ^[dynamic]Growable) {
	if widget.node.first_child == nil {return}

	remaining: f32 = widget.size[axis]

	if axis == 0 {
		remaining -= layout.padding[3] + layout.padding[1] // left + right 
	}
	if axis == 1 {
		remaining -= layout.padding[0] + layout.padding[2] // top + bottom 
	}

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
				append(growables, Growable{&child_widget.size, child_widget.size[axis], type.sizing[axis].max})
			case .Percent:
				child_widget.size[axis] = widget.size[axis] * type.sizing[axis].min
			case .Fixed:
			case .Fit:
			}
		case Text:
			append(growables, Growable{&child_widget.size, type.min, max(f32)})
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

grow_children_across_axis :: proc(axis: int, layout: Layout, widget: ^Widget) {
	if widget.node.first_child == nil {return}

	axis_padding: f32

	if axis == 0 {
		axis_padding = layout.padding[3] + layout.padding[1]
	}
	if axis == 1 {
		axis_padding = layout.padding[0] + layout.padding[2]
	}

	for child_widget := widget.node.first_child; child_widget != nil; child_widget = child_widget.node.next {
		layout: Layout

		switch type in child_widget.config {
		case Text:
			continue
		case Layout:
			layout = type
		case Floating:
			layout = type.layout
		}

		if layout.sizing[axis].kind == .Percent {
			child_widget.size[axis] = widget.size[axis] * layout.sizing[axis].min
			child_widget.size[axis] = max(child_widget._min[axis], child_widget.size[axis])
		}
		if layout.sizing[axis].kind == .Grow {
			child_min := max(child_widget._min[axis], layout.sizing[axis].min)
			child_widget.size[axis] = max(widget.size[axis] - axis_padding, child_min)
			child_widget.size[axis] = min(child_widget.size[axis], layout.sizing[axis].max)
		}
	}
}

layout_sizing_pass :: proc(ctx: ^Core_Context) {
	#reverse for w in ctx.stacks.post_r {

		layout: Layout

		switch type in w.config {
		case Layout:
			layout = type
		case Floating:
			layout = type.layout
		case Text:
			// 	if w.node.first_child != nil {
			// 		w.layout.min.x += w.style.child_gap
			// 	} else {
			// 		w.layout.min.x += w.style.padding[3] + w.style.padding[1]
			// 		w.layout.min.y += w.style.padding[2] + w.style.padding[0]
			// 	}
			// 	w.layout.min.x += w.prev_text_size.x
			// 	w.layout.min.y += w.prev_text_size.y
			continue
		}

		for sizing, i in layout.sizing {
			w.size[i] = sizing.min
		}
	}

	#reverse for w in ctx.stacks.post_r {
		fit_into_parent(0, w)
	}

	growables := make([dynamic]Growable, 0, 16, context.temp_allocator)
	for w in ctx.stacks.pre {
		layout: Layout
		switch type in w.config {
		case Text:
			continue
		case Layout:
			layout = type
		case Floating:
			layout = type.layout
		}

		// w.text_size = ctx.text_measure_proc(w.text, w.style.text)
		if layout.direction == .Row {
			grow_shrink_children_along_axis(0, layout, w, &growables)
			clear(&growables)
		} else {
			grow_children_across_axis(0, layout, w)
			clear(&growables)
		}
	}

	#reverse for w in ctx.stacks.post_r {
		fit_into_parent(1, w)
	}

	for w in ctx.stacks.pre {
		layout: Layout

		switch type in w.config {
		case Text:
			continue
		case Layout:
			layout = type
		case Floating:
			layout = type.layout
		}

		if layout.direction == .Colom {
			grow_shrink_children_along_axis(1, layout, w, &growables)
			clear(&growables)
		} else {
			grow_children_across_axis(1, layout, w)
			clear(&growables)
		}
	}
}

layout_positioning_pass :: proc(ctx: ^Core_Context) {
	for widget in ctx.stacks.pre {
		layout: Layout

		switch type in widget.config {
		case Floating:
			layout = type.layout
			anchor_pos: Vec2f32
			anchor_size: Vec2f32

			switch type.attachment_to {
			case .Id:
				val, ok := ctx.persistant_data[type.parent_id]
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
			continue // 
		}

		total_size: Vec2f32
		for child := widget.node.first_child; child != nil; child = child.node.next {
			total_size += child.size + layout.child_gap
		}
		padding := layout.padding
		position_increment: Vec2f32

		switch layout.direction {
		case .Row:
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
		case .Colom:
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
				position_increment.y = widget.position.y + widget.size.y + layout.child_gap - padding[2]
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
				widget.size[i] += expand.value
			case .Percent:
				if widget.node.parent != nil {
					widget.size[i] += expand.value * widget.node.parent.size[i]
				}
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
			widget._z_index = widget.node.parent._z_index + 1
		}

		command_rect: Command_Rect
		command_rect.size = widget.size
		command_rect.color = widget.style.color
		command_rect.position = widget.position
		command_rect.border_radius = widget.style.border_radius
		command_rect.border_thickness = widget.style.border_thickness

		append(&ctx.render_commands, Render_Command{z_index = widget._z_index, type = command_rect})

		// if widget.text != "" {
		// 	command_text: Command_Text
		// 	command_text.color = WHITE
		// 	command_text.position = widget.text_position
		// 	command_text.spacing = widget.style.text.spacing
		// 	command_text.font_size = widget.style.text.font_size
		// 	command_text.line_height = widget.style.text.line_height
		// 	command_text.lines = widget.lines
		// 	append(&ctx.render_commands, Render_Command{z_index = widget.z_index + 1, type = command_text})
		// }
	}

	sort.quick_sort_proc(ctx.render_commands[:], proc(a, b: Render_Command) -> int {return a.z_index - b.z_index})
}

build_stacks :: proc(ctx: ^Core_Context) {
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
