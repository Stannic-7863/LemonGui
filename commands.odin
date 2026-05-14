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
	lines: []Text_Line,
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

	for i := Widget_Index(0); i < Widget_Index(len(ctx.widgets)) && i != -1; {
		widget := get_widget(ctx, i)

		if !is_widget_on_screen(ctx, widget) {
			if widget.next != -1 {
				i = widget.next
				continue
			}

			i = -1

			for parent_index := widget.parent; parent_index != -1; {
				parent := get_widget(ctx, parent_index)
				if parent.next != -1 {
					i = parent.next
					break
				}
				parent_index = parent.parent
			}
			continue
		}

		defer i += 1

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
			lines := ctx.lines[widget.text_info.lines_range.start:widget.text_info.lines_range.end]
			line_height := ctx.measure_text_height(style.text)
			s_kind := Command_Rect{ color = style.text.selection_background, border = style.text.selection_border }
			emit_selection: if widget.form.selection != 0 {
				selection := get_selection(ctx, widget.form.selection)
				if selection.cursor == selection.anchor { break emit_selection }
				selection_start, selection_end := min(selection.anchor, selection.cursor), max(selection.anchor, selection.cursor)
				start_line := 0
				end_line := 0
				for line, i in lines {
					if selection_end >= line.start && selection_end <= line.end { end_line = i }
					if selection_start >= line.start && selection_start <= line.end { start_line = i }
				}

				if start_line == end_line { // juz slice, meausre and emit
				 	line := lines[start_line]
					rel_start := max(0, selection_start - line.start)
					rel_end := max(0, selection_end - line.start)
					if rel_end < len(line.line) {
						w := ctx.measure_text_width(line.line[min(rel_start, rel_end):max(rel_start, rel_end)], style.text)
						s := ctx.measure_text_width(line.line[:rel_start], style.text) if rel_start > 0 else 0
						s_cmd := cmd
						s_cmd.rect = {position = line.position + {s, 0}, size = {w, line_height}, scroll_offset = s_cmd.rect.scroll_offset}
						_add_render_command(ctx, &s_cmd, s_kind, widget.form.z_offset)
						cmd.z_index += 1
					}
				} else {
					{
						line := lines[start_line]

						rel_start := max(0, selection_start - line.start)

						s := ctx.measure_text_width(line.line[:rel_start], style.text) if rel_start > 0 else 0
						w := ctx.measure_text_width(line.line[rel_start:], style.text)

						s_cmd := cmd
						s_cmd.rect = {
							position      = line.position + {s, 0},
							size          = {w, line_height},
							scroll_offset = s_cmd.rect.scroll_offset,
						}
						_add_render_command(ctx, &s_cmd, s_kind, widget.form.z_offset)
						cmd.z_index += 1
					}

					// handle middle lines
					for l in start_line + 1 ..< end_line {
						s_cmd := cmd
						s_cmd.rect = {position = lines[l].position, size = {lines[l].width, line_height}, scroll_offset = s_cmd.rect.scroll_offset}
						_add_render_command(ctx, &s_cmd, s_kind, widget.form.z_offset)
						cmd.z_index += 1
					}

					{
						line := lines[end_line]

						rel_end := max(0, selection_end - line.start)

						w := ctx.measure_text_width(line.line[:rel_end], style.text)

						s_cmd := cmd
						s_cmd.rect = {
							position      = line.position,
							size          = {w, line_height},
							scroll_offset = s_cmd.rect.scroll_offset,
						}
						_add_render_command(ctx, &s_cmd, s_kind, widget.form.z_offset)
						cmd.z_index += 1
					}
					// handle end line
				}
			}

			cmd.kind = Command_Text{style.text, lines}
			t_cmd := cmd
			t_cmd.rect.position = widget.text_info.position
			t_cmd.rect.size = widget.text_info.size
			t_cmd.z_index += widget.form.z_offset

			append(&ctx.render_commands, t_cmd)
			cmd.z_index += 1
			z_offset += 1
		}
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
}
