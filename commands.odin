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

_emit_render_commands :: proc(ctx: ^Core_Context, widget: ^Widget, z_index: ^int) {

	if widget.clip.kind[.X] != .None || widget.clip.kind[.Y] != .None {
		if ctx.active_clip != nil {
			append(&ctx.clips, ctx.active_clip)
		}

		ctx.active_clip = widget
		_emit_clip_start_command(ctx, widget, z_index)
	}

	_emit_rect_command(ctx, widget, z_index)
	_emit_image_command(ctx, widget, z_index)
	_emit_custom_command(ctx, widget, z_index)
	_emit_text_command(ctx, widget, z_index)
	_emit_widget_border_command(ctx, widget, z_index)

	if widget.next == nil && widget.first == nil {
		for parent := widget.parent; parent != nil; parent = parent.parent {
			if parent == ctx.active_clip {
				_emit_clip_end_command(ctx, parent, z_index)
				ctx.active_clip, _ = pop_safe(&ctx.clips)
				break
			}
			if parent.next != nil {
				break
			}
		}
	}
}

_emit_clip_end_command :: proc(ctx: ^Core_Context, widget: ^Widget, z_index: ^int) {
	_add_render_command(ctx, widget, Command_Clip_End{}, z_index)
}

_emit_clip_start_command :: proc(ctx: ^Core_Context, widget: ^Widget, z_index: ^int) {
	_add_render_command(ctx, widget, Command_Clip_Start{border_radius = widget.style.border.radius}, z_index)
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
		command_text.lines = ctx.lines[text.start:text.end]
		_add_render_command(ctx, widget, command_text, z_index)
		widget.rect.position.x -= widget.style.padding[.X][0]
		widget.rect.position.y -= widget.style.padding[.Y][0]
	}
}

_emit_rect_command :: proc(ctx: ^Core_Context, widget: ^Widget, z_index: ^int) {
	command_rect: Command_Rect
	command_rect.color = widget.style.color
	command_rect.border_radius = widget.style.border.radius
	_add_render_command(ctx, widget, command_rect, z_index)
}

_emit_image_command :: proc(ctx: ^Core_Context, widget: ^Widget, z_index: ^int) {
	if widget.image != nil {
		_add_render_command(ctx, widget, Command_Image{data = widget.image, tint = widget.style.color}, z_index)
	}
}

_emit_custom_command :: proc(ctx: ^Core_Context, widget: ^Widget, z_index: ^int) {
	if widget.custom != nil {
		_add_render_command(ctx, widget, Command_Custom{data = widget.custom}, z_index)
	}
}

_add_render_command :: proc(ctx: ^Core_Context, widget: ^Widget, kind: Render_Command_Kind, z_index: ^int) {
	append(
		&ctx.render_commands,
		Render_Command {
			kind = kind,
			z_index = z_index^ + widget.override.z_index,
			rect = widget.rect,
			emitter_id = widget.id,
			emitter_string_id = widget.key.keying_id,
		},
	)
	z_index^ += 1
}
