package core_ui

Render_Command_Kind :: union {
	Command_Rect,
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
	emitter_string_id: Key,
}

Command_Rect :: struct {
	color:  Vec4f32,
	border: Border_Style,
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

_emit_render_commands :: proc(ctx: ^Core_Context, widget: ^Widget, active_clip: ^^Widget) {
	style := get_style(ctx, widget.form.style)
	widget_clip := ctx.clips[widget.form.clip]

	if widget_clip.info.x.kind != .None || widget_clip.info.y.kind != .None {
		if active_clip^ != nil {
			append(&ctx.temp, active_clip^)
		}
		if widget.first != -1 {
			active_clip^ = widget
			_add_render_command(ctx, widget.info.hash, Command_Clip_Start{border_radius = style.border.radius}, widget.rect, widget.z_index + widget.form.z_offset)
		}
	}

	border := style.border
	comp := min(widget.rect.size.x, widget.rect.size.y) / 2
	for &r in border.radius {r = min(comp, r)}
	_add_render_command(ctx, widget.info.hash, Command_Rect{border = border, color = style.color}, widget.rect, widget.z_index + widget.form.z_offset + 1)

	if widget.form.image != nil {
		_add_render_command(ctx, widget.info.hash, Command_Image{data = widget.form.image, tint = style.image_tint}, widget.rect, widget.z_index + widget.form.z_offset + 2)
	}

	if widget.form.text != 0 {
		text := get_text(ctx, widget.form.text)
		lines := ctx.lines[widget.text_info.lines_range.start:widget.text_info.lines_range.end]
		cmd := Command_Text {
			lines = lines,
			style = style.text,
		}
		rect := widget.rect
		rect.position = widget.text_info.position
		rect.size = widget.text_info.size + {_get_axis_spacing(.X, widget.form.layout.padding), _get_axis_spacing(.Y, widget.form.layout.padding)}
		_add_render_command(ctx, widget.info.hash, cmd, rect, widget.z_index + widget.form.z_offset + 3)
	}

	if widget.next == -1 && widget.first == -1 {
		for parent_index := widget.parent; parent_index != -1; {
			parent := &ctx.widgets[parent_index]
			parent_index = parent.parent
			if parent == active_clip^ {
				_add_render_command(ctx, parent.info.hash, Command_Clip_End{}, parent.rect, widget.z_index + widget.form.z_offset + 4)
				active_clip^, _ = pop_safe(&ctx.temp)
				break
			}
			if parent.next != -1 {break}
		}
	}
}

_add_render_command :: proc(ctx: ^Core_Context, hash: Hash, kind: Render_Command_Kind, rect: Rect, z_index: int) {
	append(&ctx.render_commands, Render_Command{kind = kind, z_index = z_index, rect = rect, emitter_hash = hash})
	return
}
