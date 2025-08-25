package core_ui

Render_Command :: struct {
	kind:              Render_Command_Kind,
	z_index:           int,
	emitter_id:        u64,
	emitter_string_id: string,
}

Render_Command_Kind :: union {
	Command_Rect,
	Command_Border,
	Command_Clip_Start,
	Command_Clip_End,
	Command_Text,
	Command_Image,
	Command_Custom,
}

Command_Rect :: struct {
	rect:  Rect,
	color: Vec4f32,
}

Command_Border :: struct {
	rect:  Rect,
	style: Border_Style,
}

Command_Clip_Start :: struct {
	rect: Rect,
}

Command_Clip_End :: struct {}

Command_Text :: struct {
	rect:  Rect,
	style: Text_Style,
	lines: []string,
}

Command_Image :: struct {
	rect: Rect,
}

Command_Custom :: struct {}

_emit_render_commands :: proc(ctx: ^Core_Context, widget: ^Widget, z_index: ^int) {
	_emit_rect_command(ctx, widget, z_index)
	_emit_image_command(ctx, widget, z_index)
	_emit_custom_command(ctx, widget, z_index)
	_emit_text_command(ctx, widget, z_index)
	_emit_widget_border_command(ctx, widget, z_index)
}

_emit_clip_end_command :: proc(ctx: ^Core_Context, widget: ^Widget, z_index: int) {
	append(&ctx.render_commands, Render_Command{kind = Command_Clip_End{}, z_index = z_index})
}

_emit_clip_start_command :: proc(ctx: ^Core_Context, widget: ^Widget, z_index: int) {
	append(&ctx.render_commands, Render_Command{kind = Command_Clip_Start{rect = widget.rect}, z_index = z_index})
}

_emit_widget_border_command :: proc(ctx: ^Core_Context, widget: ^Widget, z_index: ^int) {
	if widget.style.border != {} {
		command_border: Command_Border
		command_border.rect = widget.rect
		command_border.style = widget.style.border
		_add_render_command(ctx, widget, command_border, z_index)
	}
}

_emit_text_command :: proc(ctx: ^Core_Context, widget: ^Widget, z_index: ^int) {
	if text, ok := widget.kind.(Text); ok {
		command_text: Command_Text
		position := widget.rect.position
		position.x += widget.style.padding[.X][0]
		position.y += widget.style.padding[.Y][0]
		command_text.rect.position = position
		command_text.style = text.style
		command_text.lines = ctx.text_lines[text.start:text.end]
		_add_render_command(ctx, widget, command_text, z_index)
	}
}

_emit_rect_command :: proc(ctx: ^Core_Context, widget: ^Widget, z_index: ^int) {
	command_rect: Command_Rect = {
		rect  = widget.rect,
		color = widget.style.color,
	}
	_add_render_command(ctx, widget, command_rect, z_index)
}

_emit_image_command :: proc(ctx: ^Core_Context, widget: ^Widget, z_index: ^int) {
	// if widget.image.data != nil {
	// 	_add_render_command(ctx, widget, Command_Image{rect = widget.rect}, z_index)
	// }
}

_emit_custom_command :: proc(ctx: ^Core_Context, widget: ^Widget, z_index: ^int) {
	// if widget.custom_data != nil {
	// 	_add_render_command(ctx, widget, Command_Custom{widget.position, widget.custom_data}, z_index)
	// }
}

_add_render_command :: proc(ctx: ^Core_Context, widget: ^Widget, kind: Render_Command_Kind, z_index: ^int) {
	append(
		&ctx.render_commands,
		Render_Command{kind = kind, z_index = z_index^ + widget.z_index, emitter_id = widget.id, emitter_string_id = widget.key.string_id},
	)
	z_index^ += 1
}
