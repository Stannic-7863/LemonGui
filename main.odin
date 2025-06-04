package main

import "core:fmt"
import "core:hash"
import "core:time"

import rl "vendor:raylib"

Vec2f32 :: [2]f32
Vec4f32 :: [4]f32 // for corners and padding : top right bottom left 
Color :: [4]u8

Sides :: struct {
	left, right, top, bottom: f32,
}

// Passes : 
// Widget creation + event checks from last frame 
// Layout pass 
// Style pass (This will handle anims and styling for hot and active widgets) 
// Render command pass
// Render pass 

// API
// Main Task : Collapse feature flags into Layout, Layout styling, styling
// Keyboard Interface directly from core. Add helpers to map events. Add focus events or focus state  
// Errors for the primitive functions 

// LAYOUT 
// Support clipping rects 
// Support max size constraint 
// Support for floating elements
// Support for free elements that are rendered on top of everything else. Position set by user
// Support for justify and related layout styling options 
// Support vertical text (example : Jap)
// Support overgrowing elements (They will probably need some special handling to having the correct draw order)

/*
   Check events against widgets from prev frame.
   Generate a new layout 
   Render new layout 
*/

Core_Context :: struct {
	window_height, window_width: f32,
	widgets_added:               int,
	commands_added:              int,
	hot_widget_id:               uint, //id, widget currently under mouse  
	active_widget_id:            uint, //id, widget currently being interacted with 
	current_parent:              ^Widget,
	last_widget:                 ^Widget,
	mouse:                       Mouse_Context,
	widgets:                     []Widget,
	render_commands:             []Render_Command,
	last_frame_widgets:          map[uint]Widget, // widgets from last frame. Used to query events. Accessed by widget.id
}

Mouse_Context :: struct {
	old_position:         Vec2f32,
	position:             Vec2f32,
	scroll:               f32,
	last_left_click:      time.Time,
	last_right_click:     time.Time,
	left_down_start:      time.Time,
	right_down_start:     time.Time,
	long_down_timeout:    time.Duration,
	double_click_timeout: time.Duration,
	events:               bit_set[Mouse_Event],
}

Render_Command :: struct {
	size, position: Vec2f32,
	color:          [4]u8,
}

// The rendering flags should probably be baked into styling instead of here, More control per widget + no push pop ???
// Push pop system should be builder code responsibilty 
Widget_Flags :: enum {
	Dragable,
	No_Event_Cull, // Child will not cull event from parent (If mouse over child, parent will recieve the event instead)
}

Border_Style :: struct {
	color:     Color,
	radius:    Vec4f32,
	thickness: Vec4f32,
}

Style :: struct {
	current_color: Color,
	default_color: Color,
	hover_color:   Color,
	press_color:   Color,
	border:        Border_Style,
}

Widget :: struct {
	next:                  ^Widget,
	prev:                  ^Widget,
	parent:                ^Widget,
	last_child:            ^Widget,
	first_child:           ^Widget,
	index, total_children: int,
	id:                    uint,
	size, position:        Vec2f32, // computed positions and sizes
	layout:                Layout, // describe how the widget should be placed along x, y axis 
	style:                 Style,
	flags:                 bit_set[Widget_Flags],
}

init_core_context :: proc(widget_arr_backing_length: int) -> Core_Context {
	ctx := Core_Context{}
	ctx.widgets = make([]Widget, widget_arr_backing_length)
	ctx.render_commands = make([]Render_Command, widget_arr_backing_length)
	return ctx
}

deinit_core_context :: proc(ctx: ^Core_Context) {
	delete(ctx.widgets)
	delete(ctx.render_commands)
	delete(ctx.last_frame_widgets)
}

begin_ui :: proc(ctx: ^Core_Context) {
	ctx.widgets_added = 0
	ctx.commands_added = 0
	root := create_widget(ctx, {}, layout({fixed(ctx.window_width), fixed(ctx.window_height)}, 16, 16, .Row), {})
	push_parent(ctx, root)
}

end_ui :: proc(ctx: ^Core_Context) {
	ctx.last_widget = nil
	ctx.mouse.events = {}
	ctx.current_parent = nil
}

push_parent :: proc(ctx: ^Core_Context, widget: ^Widget) {
	ctx.current_parent = widget
}

pop_parent :: proc(ctx: ^Core_Context) {
	ctx.current_parent = ctx.current_parent.parent
}

create_widget :: proc(ctx: ^Core_Context, flags: bit_set[Widget_Flags], layout_config: Layout, style: Style) -> ^Widget {
	w: ^Widget = &ctx.widgets[ctx.widgets_added]

	w^ = {} // zero out 

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

get_render_commands :: proc(ctx: ^Core_Context) {

	/*

	    Need to propagate min sizes during fit phase. Otherwise grow breaks 

		Fixed size handling 
		Fit size along x axes -> post order traversal. Childs will propagate their sizes to parents. Post order ensures childs have valid sizes
		Grow size along x axes -> pre order traversal. Parents will give remaining space to growable childs

		Text wrap -> Any widget containing text will have the text wrapped along its x axes. 
		
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
			node.size.x = max(node.layout._min.x, node.layout.sizing.x.min)
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
			node.size.y = max(node.layout._min.y, node.layout.sizing.y.min)
		}

		layout_fit(1, node)

		padding := node.layout.padding

		if node.layout.sizing.y.kind == .Fit {
			node.size.y += padding[0] + padding[2]
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
			position_increment[along_axis] += padding[3]
			position_increment[across_axis] += padding[0]
		}
		if along_axis == 1 {
			position_increment[along_axis] += padding[0]
			position_increment[across_axis] += padding[3]
		}

		for child := node.first_child; child != nil; child = child.next {
			child.position[across_axis] = position_increment[across_axis]
			child.position[along_axis] += position_increment[along_axis]
			position_increment[along_axis] += child.size[along_axis] + node.layout.child_gap
		}

		if node.flags & {.No_Event_Cull} == {} {
			if is_point_in_rect(node.position, node.size, ctx.mouse.position) && ctx.active_widget_id == 0 {
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

	ctx := init_core_context(32)
	ctx.mouse.double_click_timeout = time.Millisecond * 300
	ctx.mouse.long_down_timeout = time.Millisecond * 1000

	defer delete(ctx.last_frame_widgets)
	defer delete(ctx.render_commands)
	defer delete(ctx.widgets)

	for !rl.WindowShouldClose() {
		ctx.window_width = cast(f32)rl.GetScreenWidth()
		ctx.window_height = cast(f32)rl.GetScreenHeight()

		defer free_all(context.temp_allocator)
		begin_ui(&ctx)

		if rl.IsMouseButtonDown(.LEFT) {ctx.mouse.events += {.Left_Down}}
		if rl.IsMouseButtonDown(.RIGHT) {ctx.mouse.events += {.Right_Down}}
		if rl.IsMouseButtonDown(.MIDDLE) {ctx.mouse.events += {.Middle_Down}}
		if rl.IsMouseButtonPressed(.LEFT) {ctx.mouse.events += {.Left_Pressed}}
		if rl.IsMouseButtonPressed(.RIGHT) {ctx.mouse.events += {.Right_Pressed}}
		if rl.IsMouseButtonPressed(.MIDDLE) {ctx.mouse.events += {.Middle_Pressed}}
		if rl.IsMouseButtonReleased(.LEFT) {ctx.mouse.events += {.Left_Released}}
		if rl.IsMouseButtonReleased(.RIGHT) {ctx.mouse.events += {.Right_Released}}
		if rl.IsMouseButtonReleased(.MIDDLE) {ctx.mouse.events += {.Middle_Released}}

		ctx.mouse.old_position = ctx.mouse.position
		ctx.mouse.position = rl.GetMousePosition()

		style := Style {
			press_color   = {0, 0, 0, 255},
			hover_color   = {255, 255, 255, 255},
			default_color = {75, 75, 75, 255},
		}

		style.default_color = {255, 255, 150, 255}
		w_1 := create_widget(&ctx, {}, {sizing = {fixed(50), fixed(50)}}, style)
		w_2 := create_widget(&ctx, {}, {sizing = {grow(100, 0), grow(100, 0)}, padding = 16}, style)
		e, _ := get_widget_events(&ctx, w_1)
		if e != {} && e != {.Hovered} {
			fmt.println(e)
		}

		push_parent(&ctx, w_2)
		{
			style.default_color = {255, 0, 150, 255}
			w_21 := create_widget(&ctx, {}, {sizing = {fixed(50), fixed(50)}}, style)
			get_widget_events(&ctx, w_21)
		}
		pop_parent(&ctx)

		style.default_color = {255, 255, 150, 255}
		w_3 := create_widget(&ctx, {.Dragable}, {sizing = {fit(0, 0), fit(0, 0)}, child_gap = 16, padding = 16, direction = .Row}, style)
		get_widget_events(&ctx, w_3)

		push_parent(&ctx, w_3)
		{
			style.default_color = {255, 0, 150, 255}
			w_31 := create_widget(&ctx, {.No_Event_Cull}, {sizing = {grow(50, 50), grow(50, 50)}}, style)
			get_widget_events(&ctx, w_31)
			w_32 := create_widget(&ctx, {}, {sizing = {grow(50, 50), grow(50, 50)}}, style)
			get_widget_events(&ctx, w_32)
		}
		pop_parent(&ctx)

		style.default_color = {255, 255, 150, 255}
		w_6 := create_widget(&ctx, {}, {sizing = {grow(50, 50), grow(50, 50)}}, style)
		get_widget_events(&ctx, w_6)

		end_ui(&ctx)
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
	rl.DrawFPS(10, 10)
}
