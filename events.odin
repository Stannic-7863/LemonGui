package ui_core

import "core:math/linalg"
import "core:time"

Mouse_Button :: enum u8 {
	Left,
	Middle,
	Right,
}

Keyboard_Key :: enum u8 {
	A,
	B,
	C,
	D,
	E,
	F,
	G,
	H,
	I,
	J,
	K,
	L,
	M,
	N,
	O,
	P,
	Q,
	R,
	S,
	T,
	U,
	V,
	W,
	X,
	Y,
	Z,
	Key_0,
	Key_1,
	Key_2,
	Key_3,
	Key_4,
	Key_5,
	Key_6,
	Key_7,
	Key_8,
	Key_9,
	F1,
	F2,
	F3,
	F4,
	F5,
	F6,
	F7,
	F8,
	F9,
	F10,
	F11,
	F12,
	Left_Bracket, // [ 
	Right_Bracket, // ]
	Comma,
	Period,
	Minus,
	Equal,
	Backspace,
	Return,
	Backslash,
	Slash,
	Left_Shift,
	Right_Shift,
	Left_Control,
	Right_Control,
	Left_Alt,
	Right_Alt,
	Right_Super,
	Left_Super,
	Caps_Lock,
	Grave,
	Apostrophe,
	Insert,
	Home,
	Page_Up,
	Page_Down,
	Delete,
	End,
	Print_Screen,
	Scroll_Lock,
	Pause,
	Num_Lock,
	Num_1,
	Num_2,
	Num_3,
	Num_4,
	Num_5,
	Num_6,
	Num_7,
	Num_8,
	Num_9,
	Num_0,
	Num_Delete,
	Num_Return,
	Num_Plus,
	Num_Minus,
	Num_Asterisk,
	Num_Slash,
	Space,
	Escape,
	Tab,
	Up,
	Down,
	Left,
	Right,
	Semicolon,
	F13,
	F14,
	F15,
	F16,
	F17,
	F18,
	F19,
	F20,
	F21,
	F22,
	F23,
	F24,
	Help,
	Menu,
	Execute,
	Select,
	Stop,
	Again,
	Undo,
	Cut,
	Copy,
	Paste,
	Find,
	Mute,
	Volume_Up,
	Volume_Down,
}

Key_Event :: enum u8 {
	Down,
	Pressed,
	Released,
}

Widget_Key_Event :: enum u8 {
	Clicked,
	Double_Clicked,
	Triple_Clicked,
	Pressed,
	Down,
	Long_Down,
}

Widget_Event_Context :: struct {
	mouse:      [Mouse_Button]bit_set[Widget_Key_Event],
	is_hovered: bool,
}

Mouse_Context :: struct {
	last_click:           [Mouse_Button]time.Time,
	down_start:           [Mouse_Button]time.Time,
	mapped_events:        [Mouse_Button]bit_set[Key_Event],
	double_click_timeout: time.Duration,
	long_down_timeout:    time.Duration,
	old_position:         Vec2f32,
	position:             Vec2f32,
	delta:                Vec2f32,
	scroll_v:             Vec2f32,
	scroll:               f32,
}

Keyboard_Context :: struct {
	last_click:           [Keyboard_Key]time.Time,
	down_start:           [Keyboard_Key]time.Time,
	mapped_events:        [Keyboard_Key]bit_set[Key_Event],
	events:               [Keyboard_Key]bit_set[Widget_Key_Event],
	double_click_timeout: time.Duration,
	long_down_timeout:    time.Duration,
}

_resolve_events :: proc(ctx: ^Core_Context, widget: ^Widget) -> (event_context: Widget_Event_Context) {
	for mouse_events, mouse_button in ctx.mouse.mapped_events {
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

_handle_mouse_pressed :: proc(ctx: ^Core_Context, event_ctx: ^Widget_Event_Context, button: Mouse_Button, event: Key_Event) {
	event_ctx.mouse[button] += {.Pressed}
	ctx.mouse.down_start[button] = time.now()
}

_handle_mouse_down :: proc(ctx: ^Core_Context, event_ctx: ^Widget_Event_Context, button: Mouse_Button, event: Key_Event) {
	event_ctx.mouse[button] += {.Down}
	if time.since(ctx.mouse.down_start[button]) > ctx.mouse.long_down_timeout {
		event_ctx.mouse[button] += {.Long_Down}
	}
}

_handle_mouse_released :: proc(ctx: ^Core_Context, event_ctx: ^Widget_Event_Context, button: Mouse_Button, event: Key_Event) {
	event_ctx.mouse[button] += {.Clicked}
	ctx.active_widget_id = 0
	if time.since(ctx.mouse.last_click[button]) < ctx.mouse.double_click_timeout {
		event_ctx.mouse[button] += {.Double_Clicked}
	} else {
		ctx.mouse.last_click[button] = time.now()
	}
}

_handle_keyboard_pressed :: proc(ctx: ^Core_Context, button: Keyboard_Key, event: Key_Event) {
	ctx.keyboard.events[button] += {.Pressed}
	ctx.keyboard.down_start[button] = time.now()
}

_handle_keyboard_down :: proc(ctx: ^Core_Context, button: Keyboard_Key, event: Key_Event) {
	ctx.keyboard.events[button] += {.Down}
	if time.since(ctx.keyboard.down_start[button]) > ctx.keyboard.long_down_timeout {
		ctx.keyboard.events[button] += {.Long_Down}
	}
}

_handle_keyboard_released :: proc(ctx: ^Core_Context, button: Keyboard_Key, event: Key_Event) {
	ctx.keyboard.events[button] += {.Clicked}
	if time.since(ctx.keyboard.last_click[button]) < ctx.keyboard.double_click_timeout {
		ctx.keyboard.events[button] += {.Double_Clicked}
	} else {
		ctx.keyboard.last_click[button] = time.now()
	}
}
