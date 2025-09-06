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
	emitter_hash:      Hash,
	emitter_string_id: Keying_Id,
}

Command_Rect :: struct {
	color:         Vec4f32,
	border_radius: Vec4f32,
}

Command_Border :: struct {
	style: Border_Style,
}

Command_Clip_Start :: struct {
	border_radius: Vec4f32,
}

Command_Clip_End :: struct {}

Command_Text :: struct {
	style: Text_Style,
	lines: []string,
}

Command_Image :: struct {
	data: rawptr,
	tint: Color,
}

Command_Custom :: struct {
	data: rawptr,
}

_emit_render_commands :: proc(ctx: ^Core_Context, widget: ^Widget, z_index: ^int, widget_style: ^Widget_Style) {
	widget_clip := ctx.clips[widget.clip]
	if widget_clip.kind[.X] != .None || widget_clip.kind[.Y] != .None {
		if ctx.active_clip != nil {
			append(&ctx.clippers, ctx.active_clip)
		}

		if widget.first != -1 {
			ctx.active_clip = widget
			_emit_clip_start_command(ctx, widget, z_index, widget_style)
		}
	}


	_emit_rect_command(ctx, widget, z_index, widget_style)
	_emit_image_command(ctx, widget, z_index, widget_style)
	_emit_custom_command(ctx, widget, z_index, widget_style)
	_emit_text_command(ctx, widget, z_index, widget_style)
	_emit_widget_border_command(ctx, widget, z_index, widget_style)

	if widget.next == -1 && widget.first == -1 {
		for parent_index := widget.parent; parent_index != -1; {
			parent := &ctx.widgets[parent_index]
			parent_index = parent.parent
			if parent == ctx.active_clip {
				_emit_clip_end_command(ctx, parent, z_index)
				ctx.active_clip, _ = pop_safe(&ctx.clippers)
				break
			}
			if parent.next != -1 {
				break
			}
		}
	}
}

_emit_clip_end_command :: proc(ctx: ^Core_Context, widget: ^Widget, z_index: ^int) {
	_add_render_command(ctx, widget, Command_Clip_End{}, z_index)
}

_emit_clip_start_command :: proc(ctx: ^Core_Context, widget: ^Widget, z_index: ^int, widget_style: ^Widget_Style) {
	_add_render_command(ctx, widget, Command_Clip_Start{border_radius = widget_style.border.radius}, z_index)
}

_emit_widget_border_command :: proc(ctx: ^Core_Context, widget: ^Widget, z_index: ^int, widget_style: ^Widget_Style) {
	if widget_style.border != {} {
		command_border: Command_Border
		command_border.style = widget_style.border
		_add_render_command(ctx, widget, command_border, z_index)
	}
}

_emit_text_command :: proc(ctx: ^Core_Context, widget: ^Widget, z_index: ^int, widget_style: ^Widget_Style) {
	if text, ok := widget.kind.(Text); ok {
		command_text: Command_Text
		widget.rect.position.x += widget_style.padding[.X][0]
		widget.rect.position.y += widget_style.padding[.Y][0]
		command_text.style = text.style
		command_text.lines = ctx.lines[text.start:text.end]
		_add_render_command(ctx, widget, command_text, z_index)
		widget.rect.position.x -= widget_style.padding[.X][0]
		widget.rect.position.y -= widget_style.padding[.Y][0]
	}
}

_emit_rect_command :: proc(ctx: ^Core_Context, widget: ^Widget, z_index: ^int, widget_style: ^Widget_Style) {
	command_rect: Command_Rect
	command_rect.color = widget_style.color
	command_rect.border_radius = widget_style.border.radius
	_add_render_command(ctx, widget, command_rect, z_index)
}

_emit_image_command :: proc(ctx: ^Core_Context, widget: ^Widget, z_index: ^int, widget_style: ^Widget_Style) {
	if widget.image != nil {
		_add_render_command(ctx, widget, Command_Image{data = widget.image, tint = widget_style.image_tint}, z_index)
	}
}

_emit_custom_command :: proc(ctx: ^Core_Context, widget: ^Widget, z_index: ^int, widget_style: ^Widget_Style) {
	if widget.custom_data != nil {
		_add_render_command(ctx, widget, Command_Custom{data = widget.custom_data}, z_index)
	}
}

_add_render_command :: proc(ctx: ^Core_Context, widget: ^Widget, kind: Render_Command_Kind, z_index: ^int) {
	append(
		&ctx.render_commands,
		Render_Command {
			kind = kind,
			z_index = z_index^ + widget.z_index,
			rect = widget.rect,
			emitter_hash = widget.key.hash,
			emitter_string_id = widget.key.keying_id,
		},
	)
	z_index^ += 1
}
