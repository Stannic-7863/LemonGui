package main

import "core:fmt"
import "core:hash"
import "core:mem"

import rl "vendor:raylib"

Vec2f32 :: [2]f32
Color :: [4]u8

// TODO : Clipping rects 
// TODO : Style strcut + its placement, is it local to each widget or is it a global ctx thing? 
// TODO : Separate Flags into render flags and events flags 
// TODO : Support for floating elements
// TODO : Support for free elements that will be dragged and set by the user
// TODO : Allow overgrowing elements. (They will probably need some special handling to having the correct draw order)
// TODO : Add more events in widget events and time tracking for events like double click
// TODO : Keyboard Interface directly from core. Add helpers to map events. Add focus events or focus state  
// TODO : Errors for the primitive functions 
// TODO : Good defaults, or leave that to builder code 
// TODO : Padding and child gap calc in Layout alg 
// TODO : Max size constraint 
// TODO : Support for free elements and elements with position set to mouse + offset

// TODO : Add root node in init context proc. Write deinit ctx proc 

/*
   Check events against widgets from prev frame.
   Generate a new layout 
   Render new layout 
*/

Core_Context :: struct {
	widgets_added:      int,
	commands_added:     int,
	current_parent:     ^Widget,
	last_widget:        ^Widget, // last widget index 
	hot_widget_id:      uint, //id, widget currently under mouse 😩  
	active_widget_id:   uint, //id, widget currently being interacted with 
	mouse_position:     Vec2f32, // position of cursor
	mouse_delta:        Vec2f32, // change in position per frame 
	widgets:            []Widget, // array of widgets
	render_commands:    []Render_Command,
	mouse_events:       bit_set[Mouse_Events],
	last_frame_widgets: map[uint]Widget, // widgets from last frame. Used to query events. Accessed by widget.id
}

Render_Command :: struct {
	size, position: Vec2f32,
	color:          [4]u8,
}

// The rendering flags should probably be baked into styling instead of here, More control per widget + no push pop ???

Widget_Flags :: enum {
	Left_Clickable,
	Right_Clickable,
	Double_Left_Clickable,
	Dobule_Right_Clickable,
	Dragable,
	No_Event_Cull, // Child will not cull event from parent (If mouse over child, parent will recieve the event instead)
}

Style :: struct {
	current_color: Color,
	default_color: Color,
	hover_color:   Color,
	press_color:   Color,
}

// TODO : clean this struct 
Widget :: struct {
	next:                  ^Widget,
	prev:                  ^Widget,
	parent:                ^Widget,
	last_child:            ^Widget,
	first_child:           ^Widget,
	id:                    uint,
	index, total_children: int,
	size, position:        Vec2f32, // computed positions and sizes
	layout:                Layout, // describe how the widget should be placed along x, y axis 
	flags:                 bit_set[Widget_Flags],
	style:                 Style,
}

init_core_context :: proc(widget_arr_backing_length: int) -> Core_Context {
	ctx := Core_Context{}
	ctx.widgets = make([]Widget, widget_arr_backing_length)
	return ctx
}

begin_ui :: proc(ctx: ^Core_Context) {
	ctx.widgets_added = 0
	ctx.commands_added = 0
	ctx.current_parent = nil
	ctx.last_widget = nil
	ctx.mouse_events = {}
}

push_parent :: proc(ctx: ^Core_Context, widget: ^Widget) {
	ctx.current_parent = widget
}

pop_parent :: proc(ctx: ^Core_Context) {
	ctx.current_parent = ctx.current_parent.parent
}

create_widget :: proc(ctx: ^Core_Context, flags: bit_set[Widget_Flags], layout_config: Layout, style: Style) -> ^Widget {
	w: ^Widget = &ctx.widgets[ctx.widgets_added]

	w^ = {}

	w.index = ctx.widgets_added
	w.flags = flags
	w.parent = ctx.current_parent
	w.layout = layout_config
	w.style = style
	w.style.current_color = w.style.default_color
	ctx.widgets_added += 1

	if ctx.current_parent != nil {
		ctx.current_parent.total_children += 1

		if ctx.current_parent.first_child == nil {
			ctx.current_parent.first_child = w
		}
		w.prev = ctx.current_parent.last_child

		if ctx.current_parent.last_child != nil {
			ctx.current_parent.last_child.next = w
		}

		ctx.current_parent.last_child = w
	}

	buffer: [size_of(int) * 4 + 1]byte
	offset: int
	temp: [size_of(int)]u8

	buffer[offset] = transmute(u8)w.flags
	offset += 1

	if w.prev != nil {
		temp = transmute([size_of(int)]u8)w.prev
		copy(buffer[offset:offset + size_of(int)], temp[:])
	}
	offset += size_of(int)

	if w.parent != nil {
		temp = transmute([size_of(int)]u8)w.parent
		copy(buffer[offset:offset + size_of(int)], temp[:])
	}
	offset += size_of(int)

	temp = transmute([size_of(int)]u8)w.total_children
	copy(buffer[offset:offset + size_of(int)], temp[:])
	offset += size_of(int)

	temp = transmute([size_of(int)]u8)w.index
	copy(buffer[offset:offset + size_of(int)], temp[:])
	offset += size_of(int)


	w.id = cast(uint)hash.fnv64a(buffer[:])

	return w
}


import t "core:time"
get_render_commands :: proc(ctx: ^Core_Context) {

	/*

	    Need to propagate min sizes during fit phase. Otherwise grow breaks 

		Fixed size handling 
		Fit size along x axes -> post order traversal. Childs will propagate their sizes to parents. Post order ensures childs have valid sizes
		Grow size along x axes -> pre order traversal. Parents will give remaining space to growable childs

		Text wrap -> Any widget containing text will have the text wrapped along its x axes. Need to add handling for vertical text (Jap)
		
		Fit size along y axes -> post order traversal 
		Grow size along y axes -> pre order traversal 

		Alignment and position -> pre order traversal 

		emit command -> pre order traversal 

	*/

	reverse_stack_post_order: [dynamic]^Widget = make([dynamic]^Widget, 0, len(ctx.widgets), context.temp_allocator)
	stack_pre_order: [dynamic]^Widget = make([dynamic]^Widget, 0, len(ctx.widgets), context.temp_allocator)
	temp_stack: [dynamic]^Widget = make([dynamic]^Widget, 0, len(ctx.widgets), context.temp_allocator)

	append(&temp_stack, &ctx.widgets[0]) // append root node 

	for {
		node := pop_safe(&temp_stack) or_break

		append(&reverse_stack_post_order, node)

		for node_child := node.first_child; node_child != nil; node_child = node_child.next {
			append(&temp_stack, node_child)
		}
	}


	clear(&temp_stack)
	append(&temp_stack, &ctx.widgets[0])

	for {
		node := pop_safe(&temp_stack) or_break

		append(&stack_pre_order, node)

		for node_child := node.last_child; node_child != nil; node_child = node_child.prev {
			append(&temp_stack, node_child)
		}
	}

	clear(&temp_stack)

	// 1st pass : Fixed Size 
	#reverse for node in reverse_stack_post_order {
		for i in 0 ..= 1 {
			if node.layout.sizing[i].kind == .Fixed {
				node.size[i] = node.layout.sizing[i].max
			}
		}
	}

	// 2nd pass : Fit sizing along x axis 
	#reverse for node in reverse_stack_post_order {
		if node.layout.sizing.x.kind == .Grow {
			node.size.x = max(node.layout.min.x, node.layout.sizing.x.min)
		} // Tree is walked from leaf nodes. 

		layout_fit(0, node)


		if node.layout.sizing.x.kind == .Fit {
			padding := node.layout.padding
			node.size.x += padding.left + padding.right
			if node.layout.direction == .Row {
				node.size.x += f32(node.total_children - 1) * node.layout.child_gap
			}
		}

	}


	growables := make([dynamic]^Widget, 0, 16, context.temp_allocator)
	// 3rd pass : Grow sizing along x axis 
	for node in stack_pre_order {
		if node.layout.direction == .Row {
			layout_grow_along_axis(0, node, &growables)
			clear(&growables)
		} else {
			layout_grow_across_axis(0, node, &growables)
			clear(&growables)
		}
	}

	#reverse for node in reverse_stack_post_order {
		if node.layout.sizing.y.kind == .Grow {
			node.size.y = max(node.layout.min.y, node.layout.sizing.y.min)
		}

		layout_fit(1, node)

		padding := node.layout.padding

		if node.layout.sizing.y.kind == .Fit {
			node.size.y += padding.top + padding.bottom
			if node.layout.direction == .Colom {
				node.size.y += f32(node.total_children - 1) * node.layout.child_gap
			}
		}
	}

	for node in stack_pre_order {
		if node.layout.direction == .Colom {
			layout_grow_along_axis(1, node, &growables)
			clear(&growables)
		} else {
			layout_grow_across_axis(1, node, &growables)
			clear(&growables)
		}
	}

	for node in stack_pre_order {
		along_axis: int = cast(int)node.layout.direction
		across_axis: int = (along_axis + 1) % 2

		position_increment: [2]f32 = node.position
		padding := node.layout.padding

		if along_axis == 0 {
			position_increment[along_axis] += padding.left
			position_increment[across_axis] += padding.top
		}
		if along_axis == 1 {
			position_increment[along_axis] += padding.top
			position_increment[across_axis] += padding.left
		}

		for child := node.first_child; child != nil; child = child.next {
			child.position[across_axis] = position_increment[across_axis]
			child.position[along_axis] += position_increment[along_axis]
			position_increment[along_axis] += child.size[along_axis] + node.layout.child_gap
		}

		if node.flags & {.No_Event_Cull} == {} {
			if is_point_in_rect(node.position, node.size, ctx.mouse_position) && ctx.active_widget_id == 0 {
				ctx.hot_widget_id = node.id
			}
		}

		command: Render_Command
		command.size = node.size
		command.color = node.style.current_color
		command.position = node.position

		ctx.render_commands[ctx.commands_added] = command
		ctx.commands_added += 1
	}


	clear_map(&ctx.last_frame_widgets)

	for w in ctx.widgets {
		ctx.last_frame_widgets[w.id] = w
	}

}


main :: proc() {
	rl.SetConfigFlags({.WINDOW_RESIZABLE})
	rl.InitWindow(700, 700, "Balls?")
	defer rl.CloseWindow()

	rl.SetTargetFPS(60)

	ctx := init_core_context(32)
	ctx.render_commands = make([]Render_Command, 32)
	defer delete(ctx.last_frame_widgets)
	defer delete(ctx.render_commands)
	defer delete(ctx.widgets)

	for !rl.WindowShouldClose() {

		defer free_all(context.temp_allocator)
		begin_ui(&ctx)

		if rl.IsMouseButtonDown(.LEFT) {ctx.mouse_events |= {.Left_Down}}
		if rl.IsMouseButtonDown(.RIGHT) {ctx.mouse_events |= {.Right_Down}}
		if rl.IsMouseButtonDown(.MIDDLE) {ctx.mouse_events |= {.Middle_Down}}
		if rl.IsMouseButtonPressed(.LEFT) {ctx.mouse_events |= {.Left_Pressed}}
		if rl.IsMouseButtonPressed(.RIGHT) {ctx.mouse_events |= {.Right_Pressed}}
		if rl.IsMouseButtonPressed(.MIDDLE) {ctx.mouse_events |= {.Middle_Pressed}}
		if rl.IsMouseButtonReleased(.LEFT) {ctx.mouse_events |= {.Left_Released}}
		if rl.IsMouseButtonReleased(.RIGHT) {ctx.mouse_events |= {.Right_Released}}
		if rl.IsMouseButtonReleased(.MIDDLE) {ctx.mouse_events |= {.Middle_Released}}

		ctx.mouse_position = rl.GetMousePosition()

		style := Style {
			press_color   = {0, 0, 0, 255},
			hover_color   = {255, 255, 255, 255},
			default_color = {75, 75, 75, 255},
		}

		papa_widget := create_widget(
			&ctx,
			{},
			{
				sizing = {fixed(cast(f32)rl.GetScreenWidth()), fixed(cast(f32)rl.GetScreenHeight())},
				direction = .Colom,
				padding = {16, 16, 16, 16},
				child_gap = 16,
			},
			style,
		)
		push_parent(&ctx, papa_widget)

		style.default_color = {255, 255, 150, 255}
		w_1 := create_widget(&ctx, {.Left_Clickable}, {sizing = {fixed(50), fixed(50)}}, style)
		w_2 := create_widget(&ctx, {.Left_Clickable}, {sizing = {fit(0, 0), fit(0, 0)}, padding = {16, 16, 16, 16}}, style)
		get_widget_events(&ctx, w_1)
		get_widget_events(&ctx, w_2)
		push_parent(&ctx, w_2)
		style.default_color = {255, 0, 150, 255}
		w_21 := create_widget(&ctx, {.Left_Clickable}, {sizing = {fixed(50), fixed(50)}}, style)
		get_widget_events(&ctx, w_21)
		pop_parent(&ctx)

		style.default_color = {255, 255, 150, 255}
		w_3 := create_widget(
			&ctx,
			{.Left_Clickable, .Dragable, .Right_Clickable},
			{sizing = {fit(0, 0), fit(0, 0)}, child_gap = 16, padding = {16, 16, 16, 16}, direction = .Row},
			style,
		)
		get_widget_events(&ctx, w_3)
		push_parent(&ctx, w_3)
		style.default_color = {255, 0, 150, 255}
		w_31 := create_widget(&ctx, {.No_Event_Cull}, {sizing = {grow(50, 50), grow(50, 50)}}, style)
		get_widget_events(&ctx, w_31)
		w_32 := create_widget(&ctx, {.Left_Clickable}, {sizing = {grow(50, 50), grow(50, 50)}}, style)
		get_widget_events(&ctx, w_32)
		pop_parent(&ctx)

		style.default_color = {255, 255, 150, 255}
		w_6 := create_widget(&ctx, {.Left_Clickable, .Right_Clickable}, {sizing = {grow(50, 50), grow(50, 50)}}, style)
		get_widget_events(&ctx, w_6)
		get_render_commands(&ctx)


		rl.BeginDrawing()
		rl.ClearBackground({45, 60, 70, 255})
		render(ctx)
		rl.EndDrawing()
	}
}

render :: proc(ctx: Core_Context) {
	for cmd in ctx.render_commands[:ctx.commands_added] {
		rl.DrawRectangleV(cmd.position, cmd.size, cast(rl.Color)cmd.color)
	}
}
