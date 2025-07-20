package ui_core

import "core:math/linalg"
import "core:time"

Mouse_Button :: enum u8 {
	Left,
	Middle,
	Right,
}

Mouse_Event :: enum u8 {
	Down,
	Pressed,
	Released,
}

Widget_Mouse_Event :: enum {
	Clicked,
	Double_Clicked,
	Triple_Clicked,
	Pressed,
	Down,
	Long_Down,
}

Widget_Event_Context :: struct {
	mouse:      [Mouse_Button]bit_set[Widget_Mouse_Event],
	is_hovered: bool,
}

Mouse_Context :: struct {
	double_click_timeout: time.Duration,
	long_down_timeout:    time.Duration,
	last_click:           [Mouse_Button]time.Time,
	down_start:           [Mouse_Button]time.Time,
	old_position:         Vec2f32,
	position:             Vec2f32,
	delta:                Vec2f32,
	scroll_v:             Vec2f32,
	scroll:               f32,
	events:               [Mouse_Button]bit_set[Mouse_Event],
}

Keyboard_Context :: struct {}

_resolve_events :: proc(ctx: ^Core_Context, widget: ^Widget) -> (event_context: Widget_Event_Context) {
	for mouse_events, mouse_button in ctx.mouse.events {
		for mouse_event in mouse_events {
			switch mouse_event {
			case .Pressed:
				_handle_mouse_pressed(ctx, &event_context, mouse_button, mouse_event)
				ctx.active_widget_id = widget.node.id
			case .Down:
				_handle_mouse_down(ctx, &event_context, mouse_button, mouse_event)
				ctx.active_widget_id = widget.node.id
			case .Released:
				_handle_mouse_released(ctx, &event_context, mouse_button, mouse_event)
			}
		}
	}
	return
}

_handle_mouse_pressed :: proc(ctx: ^Core_Context, event_ctx: ^Widget_Event_Context, button: Mouse_Button, event: Mouse_Event) {
	event_ctx.mouse[button] += {.Pressed}
	ctx.mouse.down_start[button] = time.now()
}

_handle_mouse_down :: proc(ctx: ^Core_Context, event_ctx: ^Widget_Event_Context, button: Mouse_Button, event: Mouse_Event) {
	event_ctx.mouse[button] += {.Down}
	if time.since(ctx.mouse.down_start[button]) > ctx.mouse.long_down_timeout {
		event_ctx.mouse[button] += {.Long_Down}
	}
}

_handle_mouse_released :: proc(ctx: ^Core_Context, event_ctx: ^Widget_Event_Context, button: Mouse_Button, event: Mouse_Event) {
	event_ctx.mouse[button] += {.Clicked}
	ctx.active_widget_id = 0
	if time.since(ctx.mouse.last_click[button]) < ctx.mouse.double_click_timeout {
		event_ctx.mouse[button] += {.Double_Clicked}
	} else {
		ctx.mouse.last_click[button] = time.now()
	}
}
