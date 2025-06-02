package main

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

layout :: proc(sizing: [2]Sizing, padding: Padding, child_gap: f32, direction: Direction = .Row) -> Layout {
	return Layout{sizing = sizing, padding = padding, child_gap = child_gap, direction = direction}
}

fit :: proc(min, max: f32) -> Sizing {
	return Sizing{min = min, max = max, kind = .Fit}
}

grow :: proc(min, max: f32) -> Sizing {
	return Sizing{min = min, max = max, kind = .Grow}
}

fixed :: proc(size: f32) -> Sizing {
	return Sizing{size, size, .Fixed}
}

percent :: proc(p: f32) -> Sizing {
	return Sizing{p, 0, .Percent}
}


Sizing :: struct {
	min, max: f32,
	kind:     Kind,
}

Padding :: struct {
	top:    f32,
	bottom: f32,
	left:   f32,
	right:  f32,
}

Layout :: struct {
	sizing:    [2]Sizing,
	min:       [2]f32,
	padding:   Padding,
	child_gap: f32,
	direction: Direction,
}


layout_fit :: proc(along: int, node: ^Widget) {
	parent := node.parent

	if parent == nil {return}

	if parent.layout.sizing[along].kind == .Fit {
		if cast(int)parent.layout.direction == along {
			parent.size[along] += node.size[along]
		} else {
			parent.size[along] = max(parent.size[along], node.size[along])
		}
	}
}

layout_grow_along_axis :: proc(along: int, node: ^Widget, growables: ^[dynamic]^Widget) {
	if node.first_child == nil { 	// node has no childs. Leaf node, leave.
		return
	}

	remaining: f32 = node.size[along] - node.layout.child_gap * f32(node.total_children - 1) // node size is the initial remaining size 

	if along == 0 {
		padding := node.layout.padding
		remaining -= padding.left + padding.right
	} else {
		padding := node.layout.padding
		remaining -= padding.top + padding.bottom
	}

	for child := node.first_child; child != nil; child = child.next {
		if child.layout.sizing[along].kind != .Grow {
			// sizes of no growable widgets must be exluded from remaining size 
			remaining -= child.size[along]
		} else {
			append(growables, child)
			remaining -= child.size[along]
		}
	}

	if len(growables) == 0 || remaining < 0 {
		return
	}

	// as long as there is space, distribute it, 1e-20 for floating point err   
	for remaining >= 1e-45 {
		smallest: f32 = growables[0].size[along]
		second_smallest: f32 = max(f32)
		to_add: f32 = remaining

		// We find the smallest and second smallest along the axis we to expand to. 
		// Once we find the smallest, we grow it until its the size of second smallest and repeat this process until all space is distributed 

		for child in growables {
			if child.size[along] <= smallest {
				smallest = child.size[along]
				second_smallest = smallest
				continue
			}
			second_smallest = min(second_smallest, child.size[along])
			to_add = second_smallest - smallest
		}

		// If all growables are smallest then we distribute remaining space equally, other wise we add space to smallest one only 
		to_add = min(to_add, remaining / cast(f32)len(growables))

		for child in growables {
			if child.size[along] == smallest {
				child.size[along] += to_add
				remaining -= to_add
			}
		}
	}
}


layout_grow_across_axis :: proc(across: int, node: ^Widget, growables: ^[dynamic]^Widget) {
	if node.first_child == nil {return}

	to_subtract: f32

	padding := node.layout.padding

	if across == 0 {
		to_subtract += padding.left + padding.right
	}
	if across == 1 {
		to_subtract += padding.top + padding.bottom
	}

	for child := node.first_child; child != nil; child = child.next {
		child.layout.min[across] = max(child.layout.min[across], child.layout.sizing[across].min)
		if child.layout.sizing[across].kind == .Grow {
			child.size[across] = node.size[across] - to_subtract
			if child.size[across] < child.layout.min[across] {
				child.size[across] = child.layout.min[across]
			}
		}
	}
}
