package core_ui

Render_Command_Kind :: union {
	Command_Rect,
	Command_Border,
	Command_Clip_Start,
	Command_Clip_End,
	Command_Text,
	Command_Image,
	Command_Custom,
}

Render_Command :: struct {
	kind:              Render_Command_Kind,
	rect:              Rect,
	z_index:           int,
	emitter_id:        u64,
	emitter_string_id: string,
}

Command_Rect :: struct {
	color: Vec4f32,
}

Command_Border :: struct {
	style: Border_Style,
}

Command_Clip_Start :: struct {}

Command_Clip_End :: struct {}

Command_Text :: struct {
	style: Text_Style,
	lines: []string,
}

Command_Image :: struct {}
Command_Custom :: struct {}

_emit_render_commands :: proc(ctx: ^Core_Context, widget: ^Widget, z_index: ^int) {
	_emit_rect_command(ctx, widget, z_index)
	_emit_image_command(ctx, widget, z_index)
	_emit_custom_command(ctx, widget, z_index)
	_emit_text_command(ctx, widget, z_index)
	_emit_widget_border_command(ctx, widget, z_index)
}

_emit_clip_end_command :: proc(ctx: ^Core_Context, widget: ^Widget, z_index: ^int) {
	_add_render_command(ctx, widget, Command_Clip_End{}, z_index)
}

_emit_clip_start_command :: proc(ctx: ^Core_Context, widget: ^Widget, z_index: ^int) {
	_add_render_command(ctx, widget, Command_Clip_Start{}, z_index)
}

_emit_widget_border_command :: proc(ctx: ^Core_Context, widget: ^Widget, z_index: ^int) {
	if widget.style.border != {} {
		command_border: Command_Border
		command_border.style = widget.style.border
		_add_render_command(ctx, widget, command_border, z_index)
	}
}

_emit_text_command :: proc(ctx: ^Core_Context, widget: ^Widget, z_index: ^int) {
	if text, ok := widget.kind.(Text); ok {
		command_text: Command_Text
		widget.rect.position.x += widget.style.padding[.X][0]
		widget.rect.position.y += widget.style.padding[.Y][0]
		command_text.style = text.style
		command_text.lines = ctx.text_lines[text.start:text.end]
		_add_render_command(ctx, widget, command_text, z_index)
		widget.rect.position.x -= widget.style.padding[.X][0]
		widget.rect.position.y -= widget.style.padding[.Y][0]
	}
}

_emit_rect_command :: proc(ctx: ^Core_Context, widget: ^Widget, z_index: ^int) {
	command_rect: Command_Rect
	command_rect.color = widget.style.color
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
		Render_Command{kind = kind, z_index = z_index^ + widget.z_index, rect = widget.rect, emitter_id = widget.id, emitter_string_id = widget.key.string_id},
	)
	z_index^ += 1
}
