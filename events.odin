package main

import "core:time"

Mouse_Event :: enum {
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

Widget_Event :: enum {
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

// ok = false means widget did not exists last frame
get_widget_events :: proc(ctx: ^Core_Context, widget: ^Widget) -> (event: Widget_Events, ok: bool) #optional_ok {

	widget_last_frame := ctx.last_frame_widgets[widget.id] or_return

	active := (ctx.active_widget_id == 0 || ctx.active_widget_id == widget.id)
	hot := widget_last_frame.id == ctx.hot_widget_id

	if hot {
		event += {.Hovered}
	} else {return}

	if .Left_Released in ctx.mouse.events {
		event += {.Left_Clicked}
		if time.since(ctx.mouse.last_left_click) < ctx.mouse.double_click_timeout {
			event += {.Double_Left_Clicked}
		} else {
			ctx.mouse.last_left_click = time.now()
		}
	}

	if .Right_Released in ctx.mouse.events {
		event += {.Right_Clicked}
		if time.since(ctx.mouse.last_right_click) < ctx.mouse.double_click_timeout {
			event += {.Double_Right_Clicked}
		} else {
			ctx.mouse.last_right_click = time.now()
		}
	}

	(active) or_return

	if .Left_Pressed in ctx.mouse.events {
		ctx.mouse.left_down_start = time.now()
	}

	if .Right_Pressed in ctx.mouse.events {
		ctx.mouse.right_down_start = time.now()
	}

	if .Left_Down in ctx.mouse.events {
		event += {.Left_Down}
		ctx.active_widget_id = widget.id

		if time.since(ctx.mouse.left_down_start) > ctx.mouse.long_down_timeout {
			event += {.Long_Left_Down}
		}

	} else {
		ctx.active_widget_id = 0
	}

	if .Right_Down in ctx.mouse.events {
		event += {.Right_Down}
		ctx.active_widget_id = widget.id

		if time.since(ctx.mouse.right_down_start) > ctx.mouse.long_down_timeout {
			event += {.Long_Right_Down}
		}

	} else {
		ctx.active_widget_id = 0
	}

	return event, true
}

is_point_in_rect :: proc(rect_pos, rect_size, point: [2]f32) -> bool {
	return point.x > rect_pos.x && point.y > rect_pos.y && point.x < rect_pos.x + rect_size.x && point.y < rect_pos.y + rect_size.y
}
