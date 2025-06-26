package ui_core

import "core:math/linalg"
import "core:time"

Mouse_Event :: enum u8 {
	Right_Down,
	Right_Pressed,
	Right_Released,
	Left_Down,
	Left_Released,
	Left_Pressed,
	Middle_Down,
	Middle_Released,
	Middle_Pressed,
	Scroll_Up,
	Scroll_Down,
}

Widget_Event :: enum u8 {
	Left_Clicked,
	Left_Pressed,
	Left_Down,
	Right_Clicked,
	Right_Pressed,
	Right_Down,
	Long_Left_Down,
	Long_Right_Down,
	Double_Left_Clicked,
	Double_Right_Clicked,
	Hovered,
	Dragged,
}

Widget_Events :: bit_set[Widget_Event]

Mouse_Context :: struct {
	double_click_timeout: time.Duration,
	long_down_timeout:    time.Duration,
	last_left_click:      time.Time,
	last_right_click:     time.Time,
	left_down_start:      time.Time,
	right_down_start:     time.Time,
	old_position:         Vec2f32,
	position:             Vec2f32,
	delta:                Vec2f32,
	scroll_v:             Vec2f32,
	scroll:               f32,
	events:               bit_set[Mouse_Event],
}

_resolve_events :: proc(ctx: ^Core_Context, widget: ^Widget) -> (event: Widget_Events) {

	if .Left_Released in ctx.mouse.events {
		event += {.Left_Clicked}
		ctx.active_widget_id = 0
		if time.since(ctx.mouse.last_left_click) < ctx.mouse.double_click_timeout {
			event += {.Double_Left_Clicked}
		} else {
			ctx.mouse.last_left_click = time.now()
		}
	}

	if .Right_Released in ctx.mouse.events {
		event += {.Right_Clicked}
		ctx.active_widget_id = 0
		if time.since(ctx.mouse.last_right_click) < ctx.mouse.double_click_timeout {
			event += {.Double_Right_Clicked}
		} else {
			ctx.mouse.last_right_click = time.now()
		}
	}

	if .Left_Pressed in ctx.mouse.events {
		event += {.Left_Pressed}
		ctx.mouse.left_down_start = time.now()
		ctx.active_widget_id = widget.node.id
	}

	if .Left_Down in ctx.mouse.events {
		event += {.Left_Down}
		ctx.active_widget_id = widget.node.id

		if time.since(ctx.mouse.left_down_start) > ctx.mouse.long_down_timeout {
			event += {.Long_Left_Down}
		}
	}

	if .Right_Pressed in ctx.mouse.events {
		event += {.Right_Pressed}
		ctx.mouse.right_down_start = time.now()
		ctx.active_widget_id = widget.node.id
	}

	if .Right_Down in ctx.mouse.events {
		event += {.Right_Down}
		ctx.active_widget_id = widget.node.id

		if time.since(ctx.mouse.right_down_start) > ctx.mouse.long_down_timeout {
			event += {.Long_Right_Down}
		}
	}
	return
}

_is_point_in_rect :: proc(rect_pos, rect_size, point: Vec2f32, border_radius: Vec4f32) -> bool {

	border_radius := border_radius.zywx

	half_size := rect_size / 2
	rel_pos := point - (rect_pos + half_size)

	border_radius.xy = rel_pos.x > 0 ? border_radius.xy : border_radius.zw
	border_radius.x = rel_pos.y > 0 ? border_radius.x : border_radius.y

	p := [2]f32{abs(rel_pos.x), abs(rel_pos.y)} - half_size + border_radius.x

	dist := linalg.length(linalg.max(p, 0.0)) + min(max(p.x, p.y), 0.0) - border_radius.x

	if dist < 0 {
		return true
	}
	return false
}
