package main

/*
	Distance of inner content from parent's border 
	Removes a bit of content space of the parent
	Adds to min size and max size contraints
*/

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

layout :: proc "contextless" (sizing: [2]Sizing, padding: Vec4f32, child_gap: f32, direction: Direction = .Row) -> Layout {
	return Layout{sizing = sizing, padding = padding, child_gap = child_gap, direction = direction}
}

fit :: proc "contextless" (min, max: f32) -> Sizing {
	return Sizing{min = min, max = max, kind = .Fit}
}

grow :: proc "contextless" (min, max: f32) -> Sizing {
	return Sizing{min = min, max = max, kind = .Grow}
}

fixed :: proc "contextless" (size: f32) -> Sizing {
	return Sizing{size, size, .Fixed}
}

percent :: proc "contextless" (p: f32) -> Sizing {
	return Sizing{p, 0, .Percent}
}

Sizing :: struct {
	min, max: f32,
	kind:     Kind,
}

Layout :: struct {
	padding:   Vec4f32,
	_min:      Vec2f32,
	child_gap: f32,
	sizing:    [2]Sizing,
	direction: Direction,
}

layout_sizing_pass :: proc(ctx: ^Core_Context) {
	append(&ctx.layout_stack.temp, &ctx.widgets[0]) // append root node 

	for {
		node := pop_safe(&ctx.layout_stack.temp) or_break

		append(&ctx.layout_stack.reverse_post_order, node)

		for node_child := node.first_child; node_child != nil; node_child = node_child.next {
			append(&ctx.layout_stack.temp, node_child)
		}
	}


	clear(&ctx.layout_stack.temp)
	append(&ctx.layout_stack.temp, &ctx.widgets[0])

	for {
		node := pop_safe(&ctx.layout_stack.temp) or_break

		append(&ctx.layout_stack.pre_order, node)

		for node_child := node.last_child; node_child != nil; node_child = node_child.prev {
			append(&ctx.layout_stack.temp, node_child)
		}
	}

	clear(&ctx.layout_stack.temp)

	// 1st pass : Fixed Size 
	#reverse for node in ctx.layout_stack.reverse_post_order {
		for i in 0 ..= 1 {
			if node.layout.sizing[i].kind == .Fixed {
				node.size[i] = node.layout.sizing[i].max
				if node.parent != nil {
					node.parent.layout._min[i] += node.size[i]
				}
			}
		}
	}

	// 2nd pass : Fit sizing along x axis 
	#reverse for node in ctx.layout_stack.reverse_post_order {
		if node.layout.sizing.x.kind == .Grow {
			node.size.x = max(node.layout._min.x, node.layout.sizing.x.min) + node.layout.padding[1] + node.layout.padding[3]
		} // Tree is walked from leaf nodes. 

		layout_fit(0, node)

		if node.layout.sizing.x.kind == .Fit {
			padding := node.layout.padding
			node.size.x += padding[3] + padding[1]
			if node.layout.direction == .Row {
				node.size.x += f32(node.total_children - 1) * node.layout.child_gap
			}
		}

	}


	growables := make([dynamic]^Widget, 0, 16, context.temp_allocator)
	// 3rd pass : Grow sizing along x axis 
	for node in ctx.layout_stack.pre_order {
		if node.layout.direction == .Row {
			layout_grow_along_axis(0, node, &growables)
			clear(&growables)
		} else {
			layout_grow_across_axis(0, node, &growables)
			clear(&growables)
		}
	}

	#reverse for node in ctx.layout_stack.reverse_post_order {
		if node.layout.sizing.y.kind == .Grow {
			node.size.y = max(node.layout._min.y, node.layout.sizing.y.min) + node.layout.padding[0] + node.layout.padding[2]
		}

		layout_fit(1, node)


		if node.layout.sizing.y.kind == .Fit {
			padding := node.layout.padding
			node.size.y += padding[0] + padding[2]
			if node.layout.direction == .Colom {
				node.size.y += f32(node.total_children - 1) * node.layout.child_gap
			}
		}
	}

	for node in ctx.layout_stack.pre_order {
		if node.layout.direction == .Colom {
			layout_grow_along_axis(1, node, &growables)
			clear(&growables)
		} else {
			layout_grow_across_axis(1, node, &growables)
			clear(&growables)
		}
	}

}

layout_fit :: proc(axis: int, node: ^Widget) {
	parent := node.parent

	if parent == nil {return}

	if parent.layout.sizing[axis].kind == .Fit {
		if cast(int)parent.layout.direction == axis {
			parent.size[axis] += node.size[axis]
		} else {
			parent.size[axis] = max(parent.size[axis], node.size[axis])
		}
	}
}

layout_grow_along_axis :: proc(axis: int, node: ^Widget, growables: ^[dynamic]^Widget) {
	if node.first_child == nil {
		return
	}

	remaining: f32 = node.size[axis] - node.layout.child_gap * f32(node.total_children - 1) // node size is the initial remaining size 
	removed_padding: f32
	if axis == 0 {
		padding := node.layout.padding
		removed_padding = padding[3] + padding[1]
		remaining -= removed_padding
	} else {
		padding := node.layout.padding
		removed_padding = padding[0] + padding[2]
		remaining -= removed_padding
	}

	for child := node.first_child; child != nil; child = child.next {
		if child.layout.sizing[axis].kind != .Grow {
			// sizes of no growable widgets must be exluded from remaining size 
			remaining -= child.size[axis]
		} else {
			append(growables, child)
			remaining -= child.size[axis]
		}
	}

	if len(growables) == 0 || remaining < 0 {
		return
	}

	// as long as there is space, distribute it, 1e-20 for floating point err   
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
			if child.size[axis] > child.layout.sizing[axis].max {
				child.size[axis] = child.layout.sizing[axis].max
				remaining += to_add
				ordered_remove(growables, i)
				continue
			}
		}
	}
}


layout_grow_across_axis :: proc(axis: int, node: ^Widget, growables: ^[dynamic]^Widget) {
	if node.first_child == nil {return}

	to_subtract: f32

	padding := node.layout.padding

	if axis == 0 {
		to_subtract += padding[3] + padding[1]
	}
	if axis == 1 {
		to_subtract += padding[0] + padding[2]
	}

	for child := node.first_child; child != nil; child = child.next {
		if child.layout.sizing[axis].kind == .Grow {
			child_min := child.size[axis]
			child.size[axis] = node.size[axis] - to_subtract
			if child.size[axis] < child_min {
				child.size[axis] = child_min
			}
			if child.size[axis] >= child.layout.sizing[axis].max {
				child.size[axis] = child.layout.sizing[axis].max
			}
		}
	}
}
