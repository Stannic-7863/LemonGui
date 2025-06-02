package main

import "core:text/edit"

Mouse_Events :: enum {
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

Widget_Events :: struct {
	left_clicked:         bool,
	left_pressed:         bool,
	right_clicked:        bool,
	right_pressed:        bool,
	dragging:             bool,
	hovering:             bool,
	double_left_clicked:  bool,
	double_right_clicked: bool,
}


get_widget_events :: proc(ctx: ^Core_Context, widget: ^Widget) -> (event: Widget_Events) {

	val, ok := ctx.last_frame_widgets[widget.id]

	if !ok {return}
	if (val.id != ctx.hot_widget_id && val.id != ctx.active_widget_id) {return}

	hovering := is_point_in_rect(val.position, val.size, ctx.mouse_position)

	for f in widget.flags {
		#partial switch f {
		case .Left_Clickable:
			if hovering && (ctx.active_widget_id == 0 || ctx.active_widget_id == widget.id) {
				event.hovering = hovering
				widget.style.current_color = widget.style.hover_color
			}

			if .Left_Down in ctx.mouse_events && (ctx.active_widget_id == 0 || ctx.active_widget_id == widget.id) {
				event.left_pressed = true
				widget.style.current_color = widget.style.press_color
				ctx.active_widget_id = widget.id
			} else {
				ctx.active_widget_id = 0
			}

			if .Left_Released in ctx.mouse_events {
				event.left_clicked = true
				widget.style.current_color = widget.style.press_color
			}

		case .Right_Clickable:
			(hovering) or_break

			if .Right_Released in ctx.mouse_events {
				event.right_clicked = true
				widget.style.current_color = widget.style.press_color
			}
		case .Dragable:
		}
	}

	return event
}

is_point_in_rect :: proc(rect_pos, rect_size, point: [2]f32) -> bool {

	return point.x > rect_pos.x && point.y > rect_pos.y && point.x < rect_pos.x + rect_size.x && point.y < rect_pos.y + rect_size.y

}
