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

layout :: proc(sizing: [2]Sizing, padding: Vec4f32, child_gap: f32, direction: Direction = .Row) -> Layout {
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

Layout :: struct {
	padding:   Vec4f32,
	_min:      Vec2f32,
	child_gap: f32,
	sizing:    [2]Sizing,
	direction: Direction,
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

import "core:fmt"

layout_grow_along_axis :: proc(axis: int, node: ^Widget, growables: ^[dynamic]^Widget) {
	if node.first_child == nil { 	// node has no childs. Leaf node, leave.
		return
	}

	remaining: f32 = node.size[axis] - node.layout.child_gap * f32(node.total_children - 1) // node size is the initial remaining size 

	if axis == 0 {
		padding := node.layout.padding
		remaining -= padding[3] + padding[1]
	} else {
		padding := node.layout.padding
		remaining -= padding[0] + padding[2]
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
	for remaining >= 1e-9 {
		smallest: f32 = growables[0].size[axis]
		second_smallest: f32 = max(f32)
		to_add: f32 = remaining

		// We find the smallest and second smallest along the axis we to expand to. 
		// Once we find the smallest, we grow it until its the size of second smallest and repeat this process until all space is distributed 

		for child in growables {
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

		for child in growables {
			if child.size[axis] == smallest {
				child.size[axis] += to_add
				remaining -= to_add
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
		child.layout._min[axis] = max(child.layout._min[axis], child.layout.sizing[axis].min)
		if child.layout.sizing[axis].kind == .Grow {
			child.size[axis] = node.size[axis] - to_subtract
			if child.size[axis] < child.layout._min[axis] {
				child.size[axis] = child.layout._min[axis]
			}
		}
	}
}
