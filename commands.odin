package core_ui

Render_Rect :: struct {
	position: Vec2f32,
	size:     Vec2f32,
}

Render_Command_Kind :: union {
	Command_Rect,
	Command_Text,
	Command_Image,
	Command_Custom,
	Command_Clip_Start,
	Command_Clip_End,
}

Render_Command :: struct {
	kind:         Render_Command_Kind,
	rect:         Render_Rect,
	hash:         Hash,
	z:            int,
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
	_on_screen_widget_iter :: proc(ctx: ^Core_Context, index: ^Widget_Index) -> (^Widget, bool) {
	    for {
	    	// We only emit widgets which are for now visible on screen.
	    	// [TODO]: Make this behaviour toggle able, either at compile time or runtime
	     	// [TODO]: Subtrees can be skipped if parent is not on screen, however due to overrides, we need to check all widgets anyways.
	      	//         Optimize that

	        if index^ >= Widget_Index(len(ctx.widgets)) { return nil, false }
	        widget := get_widget(ctx, index^)
	        if !is_widget_on_screen(ctx, widget) {
	            if widget.next != -1 {
	                index^ = widget.next
	                continue
	            }
	            for parent_index := widget.parent; parent_index != -1; {
	                parent := get_widget(ctx, parent_index)
	                if parent.next != -1 {
	                    index^ = parent.next
	                    return get_widget(ctx, index^), true
	                }
	                parent_index = parent.parent
	            }
	            return nil, false
	        }
	        index^ += 1
	        return widget, true
	    }
	}

	_add_render_command :: proc(ctx: ^Core_Context, rect: Render_Rect, hash: Hash, kind: Render_Command_Kind, z: ^int, offset: int) {
		append(&ctx.render_commands, Render_Command{hash = hash, rect = rect, kind = kind, z = z^ + offset})
		z^ += 1
	}

	active_clip := Widget_Index(-1)
	z := 0

	for index := Widget_Index(0); widget in _on_screen_widget_iter(ctx, &index) {
		style := get_style(ctx, widget.form.style)
		target := widget.clip_parent

		for len(ctx.clip_stack) > 0 && ctx.clip_stack[len(ctx.clip_stack) - 1] != target {
			parent := get_widget(ctx, pop(&ctx.clip_stack))
			rect := Render_Rect{ position = parent.rect.position, size = parent.rect.size }
			_add_render_command(ctx, rect, parent.info.hash, Command_Clip_End{}, &z, parent.form.z_offset)
		}

		rect := Render_Rect{ position = widget.rect.position, size = widget.rect.size }
		hash := widget.info.hash

		if widget.form.clip != 0 && widget.first != -1 {
			_add_render_command(ctx, rect, hash, Command_Clip_Start{style.border.radius}, &z, widget.form.z_offset)
			append(&ctx.clip_stack, widget.info.index)
		}

		border := style.border
		for &r in border.radius { r = min(min(widget.rect.size.x, widget.rect.size.y) / 2, r) }
		_add_render_command(ctx, rect, hash, Command_Rect{style.color, border}, &z, widget.form.z_offset)

		if widget.form.image != nil {
			_add_render_command(ctx, rect, hash, Command_Image{widget.form.image, style.image_tint}, &z, widget.form.z_offset)
		}

		if widget.form.text == 0 { continue }

		lines := ctx.lines[widget.text_info.lines_range.start:widget.text_info.lines_range.end]

		defer {
			t_rect := Render_Rect{position = widget.text_info.position, size = widget.text_info.size}
			_add_render_command(ctx, t_rect, hash, Command_Text{style.text, lines}, &z, widget.form.z_offset)
		}

		if widget.form.selection == 0 { continue }

		selection := get_selection(ctx, widget.form.selection)

		if selection.cursor == selection.anchor { continue }

		line_height := ctx.measure_text_height(style.text, ctx.text_user_data)
		s_kind := Command_Rect{color = style.text.selection_background, border = style.text.selection_border}

		selection_start, selection_end := min(selection.anchor, selection.cursor), max(selection.anchor, selection.cursor)
		start_line := i32(0)
		end_line := i32(0)
		for line, i in lines {
			if selection_end >= line.range.start && selection_end <= line.range.end { end_line = i32(i) }
			if selection_start >= line.range.start && selection_start <= line.range.end { start_line = i32(i) }
		}

		// Two cases: Either the selection start and end exist on same line or on different lines.
		if start_line == end_line {
			// For a single line emit rectangle from selection start (size_of_text(text[:selection_start]))) to selection end.
		 	line := lines[start_line]
			rel_start := max(0, selection_start - line.range.start)
			rel_end := max(0, selection_end - line.range.start)
			if rel_end < i32(len(line.line)) {
				w := ctx.measure_text_width(line.line[min(rel_start, rel_end):max(rel_start, rel_end)], style.text, ctx.text_user_data)
				s := ctx.measure_text_width(line.line[:rel_start], style.text, ctx.text_user_data) if rel_start > 0 else 0
				s_rect := Render_Rect{position = line.position + {s, 0}, size = {w, line_height}}
				_add_render_command(ctx, s_rect, hash, s_kind, &z, widget.form.z_offset)
			}
			continue
		}
		// In case of selection spanning multiple lines, emit the start middle and ends. Since each requires some special handling.
		// TODO: Selection doesn't respect clips, fix that
		{
			line := lines[start_line]

			rel_start := max(0, selection_start - line.range.start)

			s := ctx.measure_text_width(line.line[:rel_start], style.text, ctx.text_user_data) if rel_start > 0 else 0
			w := ctx.measure_text_width(line.line[rel_start:], style.text, ctx.text_user_data)

			s_rect := Render_Rect{position = line.position + {s, 0}, size = {w, line_height}}
			_add_render_command(ctx, s_rect, hash, s_kind, &z, widget.form.z_offset)
		}

		for l in start_line + 1 ..< end_line {
			s_rect := Render_Rect{position = lines[l].position, size = {lines[l].width, line_height}}
			_add_render_command(ctx, s_rect, hash, s_kind, &z, widget.form.z_offset)
		}

		{
			line := lines[end_line]
			rel_end := max(0, selection_end - line.range.start)
			w := ctx.measure_text_width(line.line[:rel_end], style.text, ctx.text_user_data)

			s_rect := Render_Rect{position = line.position, size = {w, line_height} }
			_add_render_command(ctx, s_rect, hash, s_kind, &z, widget.form.z_offset)
		}
	}

	for len(ctx.clip_stack) > 0 {
		widget := get_widget(ctx, pop(&ctx.clip_stack))
		rect := Render_Rect{position = widget.rect.position, size = widget.rect.size}
		_add_render_command(ctx, rect, widget.info.hash, Command_Clip_End{}, &z, widget.form.z_offset)
	}
}
