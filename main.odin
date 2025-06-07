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
	hot_widget_id:               uint, //id, widget currently under mouse  
	active_widget_id:            uint, //id, widget currently being interacted with 
	current_parent:              ^Widget,
	last_widget:                 ^Widget,
	mouse:                       Mouse_Context,
	widgets:                     [dynamic]Widget,
	render_commands:             [dynamic]Render_Command,
	layout_stack:                struct {
		reverse_post_order: [dynamic]^Widget,
		pre_order:          [dynamic]^Widget,
		temp:               [dynamic]^Widget,
	},
	last_frame_widgets:          map[uint]Widget, // widgets from last frame. Used to query events. Accessed by widget.id
}

Mouse_Context :: struct {
	scroll:               f32,
	position:             Vec2f32,
	old_position:         Vec2f32,
	last_left_click:      time.Time,
	last_right_click:     time.Time,
	left_down_start:      time.Time,
	right_down_start:     time.Time,
	long_down_timeout:    time.Duration,
	double_click_timeout: time.Duration,
	events:               bit_set[Mouse_Event],
}

Render_Command :: struct {
	type: Render_Command_Type,
}

Render_Command_Type :: union {
	Command_Rect,
}

Command_Rect :: struct {
	size, position:   Vec2f32,
	border_radius:    Vec4f32,
	border_thickness: Vec4f32,
	color:            [4]u8,
}

Style :: struct {
	current_color:    Color,
	default_color:    Color,
	hover_color:      Color,
	press_color:      Color,
	border_radius:    Vec4f32,
	border_thickness: Vec4f32,
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

// The rendering flags should probably be baked into styling instead of here, More control per widget + no push pop ???
// Push pop system should be builder code responsibilty 
Widget_Flags :: enum {
	Draw_Text,
	No_Event_Cull, // Child will not cull event from parent (If mouse over child, parent will recieve the event instead)
}

init_core_context :: proc(widget_arr_backing_length: int) -> Core_Context {
	ctx := Core_Context{}
	ctx.widgets = make([dynamic]Widget, widget_arr_backing_length)
	ctx.render_commands = make([dynamic]Render_Command, widget_arr_backing_length)
	ctx.layout_stack.temp = make([dynamic]^Widget, 0, widget_arr_backing_length)
	ctx.layout_stack.pre_order = make([dynamic]^Widget, 0, widget_arr_backing_length)
	ctx.layout_stack.reverse_post_order = make([dynamic]^Widget, 0, widget_arr_backing_length)
	return ctx
}

deinit_core_context :: proc(ctx: ^Core_Context) {
	delete(ctx.widgets)
	delete(ctx.render_commands)
	delete(ctx.last_frame_widgets)
	delete(ctx.layout_stack.temp)
	delete(ctx.layout_stack.pre_order)
	delete(ctx.layout_stack.reverse_post_order)
}

begin_ui :: proc(ctx: ^Core_Context) {
	clear(&ctx.render_commands)
	clear(&ctx.widgets)
	root := create_widget(ctx, {}, layout({fixed(ctx.window_width), fixed(ctx.window_height)}, 16, 16, .Colom), {})
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
	append(&ctx.widgets, Widget{})
	w: ^Widget = &ctx.widgets[len(ctx.widgets) - 1]

	w^ = {} // zero out 

	w.index = len(ctx.widgets) - 1
	w.flags = flags
	w.parent = ctx.current_parent
	w.layout = layout_config
	w.style = style
	w.style.current_color = w.style.default_color

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

	layout_sizing_pass(ctx)

	for node in ctx.layout_stack.pre_order {
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

		if !(.No_Event_Cull in node.flags) {
			if is_point_in_rect(node.position, node.size, ctx.mouse.position, node.style.border_radius) && ctx.active_widget_id == 0 {
				ctx.hot_widget_id = node.id
			}
		}

		command_rect: Command_Rect
		command_rect.size = node.size
		command_rect.color = node.style.current_color
		command_rect.position = node.position

		for r, i in node.style.border_radius {
			command_rect.border_radius[i] = clamp(0, min(node.size.x, node.size.y) / 2, r)
		}

		command_rect.border_thickness = node.style.border_thickness

		append(&ctx.render_commands, Render_Command{command_rect})
	}

	clear_map(&ctx.last_frame_widgets)

	clear(&ctx.layout_stack.reverse_post_order)
	clear(&ctx.layout_stack.pre_order)
	clear(&ctx.layout_stack.temp)

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

	sdf_shader := rl.LoadShader("", "./sdf_rect_shader.frag")

	img := rl.GenImageColor(1, 1, rl.WHITE)
	render_texture := rl.LoadTextureFromImage(img)
	rl.UnloadImage(img)
	defer rl.UnloadTexture(render_texture)

	rl.SetTargetFPS(60)

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
			border_radius = {50, 0, 50, 0},
		}

		style.default_color = {255, 255, 150, 255}
		w_1 := create_widget(&ctx, {}, {sizing = {fixed(50), fixed(50)}}, style)
		w_2 := create_widget(&ctx, {}, {sizing = {grow(0, 1000), grow(0, 1000)}, padding = 16}, style)
		e, _ := get_widget_events(&ctx, w_2)

		if e != {} {
			fmt.println(e)
		}

		push_parent(&ctx, w_2)
		{
			style.default_color = {255, 0, 150, 255}
			w_21 := create_widget(&ctx, {}, {sizing = {fixed(50), fixed(50)}}, style)
		}
		pop_parent(&ctx)

		style.default_color = {255, 255, 150, 255}
		w_3 := create_widget(&ctx, {}, {sizing = {fit(0, 0), fit(0, 0)}, child_gap = 16, padding = 16, direction = .Row}, style)

		push_parent(&ctx, w_3)
		{
			style.default_color = {255, 0, 150, 255}
			w_31 := create_widget(&ctx, {.No_Event_Cull}, {sizing = {grow(50, 50), grow(50, 50)}}, style)
			w_32 := create_widget(&ctx, {}, {sizing = {grow(50, 50), grow(50, 50)}}, style)
		}
		pop_parent(&ctx)

		style.default_color = {255, 255, 150, 255}
		w_6 := create_widget(&ctx, {}, {sizing = {grow(50, 50), grow(50, 50)}}, style)

		end_ui(&ctx)
		get_render_commands(&ctx)

		rl.BeginDrawing()
		rl.ClearBackground({0, 0, 0, 255})
		render(ctx, render_texture, sdf_shader)
		rl.EndDrawing()
	}
}

render :: proc(ctx: Core_Context, texture: rl.Texture, shader: rl.Shader) {

	rect_center_loc := rl.GetShaderLocation(shader, "rect_center")
	rect_size_loc := rl.GetShaderLocation(shader, "rect_size")
	border_radius_loc := rl.GetShaderLocation(shader, "border_radius")
	color_loc := rl.GetShaderLocation(shader, "color")

	for cmd in ctx.render_commands {
		switch v in cmd.type {
		case Command_Rect:
			size := v.size / 2
			pos := v.position + size
			rad := v.border_radius
			color: [4]f32
			for c, i in v.color {
				color[i] = f32(c) / 255
			}

			rl.BeginShaderMode(shader)
			rl.SetShaderValue(shader, rect_center_loc, &pos, .VEC2)
			rl.SetShaderValue(shader, rect_size_loc, &size, .VEC2)
			rl.SetShaderValue(shader, border_radius_loc, &rad, .VEC4)
			rl.SetShaderValue(shader, color_loc, &color, .VEC4)

			src := rl.Rectangle{0, 0, 1, 1}
			dst := rl.Rectangle{v.position.x, v.position.y, v.size.x, v.size.y}

			rl.DrawTexturePro(texture, src, dst, {}, 0.0, rl.BLACK)
			rl.EndShaderMode()
		}
	}

	// for cmd in ctx.render_commands {
	// 	switch v in cmd.type {
	// 	case Command_Rect:
	// 		rl.DrawRectangleV(v.position, v.size, cast(rl.Color)v.color)
	// 	}
	// }

	rl.DrawFPS(10, 10)
}
