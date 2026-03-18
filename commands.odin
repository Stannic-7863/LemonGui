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
	kind:         Render_Command_Kind,
	rect:         Rect,
	z_index:      int,
	emitter_hash: Hash,
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

_emit_render_commands :: proc(ctx: ^Core_Context) {
	active_clip := Widget_Index(-1)
	z_offset := 0
	for i := 0; i < len(ctx.widgets) && i != -1; {
		widget := get_widget(ctx, Widget_Index(i))

		if !is_widget_on_screen(ctx, widget) {
			j := widget.next
			p: ^Widget
			if widget.parent != -1 {p = get_widget(ctx, widget.parent)}
			for (j == -1 && p != nil) {
				j = p.next
				if p.parent == -1 {break}
				p = get_widget(ctx, p.parent)
			}
			i = int(j)
			continue
		}

		style := get_style(ctx, widget.form.style)
		target := widget.clip_parent

		for len(ctx.clip_stack) > 0 && ctx.clip_stack[len(ctx.clip_stack) - 1] != target {
			parent := get_widget(ctx, pop(&ctx.clip_stack))
			cmd := Render_Command{}
			cmd.emitter_hash = parent.info.hash
			cmd.kind = Command_Clip_End{}
			cmd.rect = parent.rect
			cmd.z_index = z_offset + parent.form.z_offset
			append(&ctx.render_commands, cmd)
			z_offset += 1
		}

		cmd := Render_Command{}
		cmd.emitter_hash = widget.info.hash
		cmd.rect = widget.rect
		cmd.z_index = z_offset

		if widget.form.clip != 0 && widget.first != -1 {
			_add_render_command(ctx, &cmd, Command_Clip_Start{style.border.radius}, widget.form.z_offset)
			z_offset += 1
			append(&ctx.clip_stack, widget.info.index)
		}

		border := style.border
		for &r in border.radius {r = min(min(widget.rect.size.x, widget.rect.size.y) / 2, r)}
		_add_render_command(ctx, &cmd, Command_Rect{style.color, border}, widget.form.z_offset)
		z_offset += 1

		if widget.form.image != nil {
			_add_render_command(ctx, &cmd, Command_Image{widget.form.image, style.image_tint}, widget.form.z_offset)
			z_offset += 1
		}

		if widget.form.text != 0 {
			cmd.kind = Command_Text{style.text, ctx.lines[widget.text_info.lines_range.start:widget.text_info.lines_range.end]}
			t_cmd := cmd
			t_cmd.rect.position = widget.text_info.position
			t_cmd.rect.size = widget.text_info.size + {_get_axis_spacing(.X, widget.form.layout.padding), _get_axis_spacing(.Y, widget.form.layout.padding)}
			t_cmd.z_index += widget.form.z_offset
			append(&ctx.render_commands, t_cmd)
			cmd.z_index += 1
			z_offset += 1
		}
		i += 1
	}

	for len(ctx.clip_stack) > 0 {
		widget := get_widget(ctx, pop(&ctx.clip_stack))
		cmd := Render_Command{}
		cmd.emitter_hash = widget.info.hash
		cmd.rect = widget.rect
		cmd.z_index = z_offset + widget.form.z_offset
		cmd.kind = Command_Clip_End{}
		append(&ctx.render_commands, cmd)
		z_offset += 1
	}
}

_add_render_command :: proc(ctx: ^Core_Context, cmd: ^Render_Command, kind: Render_Command_Kind, offset: int) {
	cmd.kind = kind
	t := cmd.z_index
	cmd.z_index += offset
	append(&ctx.render_commands, cmd^)
	cmd.z_index = t
	cmd.z_index += 1
	return
}
