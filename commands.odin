package core_ui

import "core:math/linalg"

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

_emit_render_commands :: proc(ctx: ^Core_Context, widget: ^Widget, z_index: ^int, style: ^Style, active_clip: ^^Widget) {
    widget_clip := ctx.clips[widget.form.clip]
    emitted: bool

    if widget_clip.kind.x != .None || widget_clip.kind.y != .None {
        if active_clip^ != nil {
            append(&ctx.temp, active_clip^)
        }
        if widget.first != -1 {
            active_clip^ = widget
            emitted = true
            _emit_clip_start_command(ctx, widget, z_index, style)
            _emit_rect_command(ctx, widget, z_index, style)
            _emit_image_command(ctx, widget, z_index, style)
            _emit_text_command(ctx, widget, z_index, style)
        }
    }

    if !emitted {
        _emit_rect_command(ctx, widget, z_index, style)
        _emit_image_command(ctx, widget, z_index, style)
        _emit_text_command(ctx, widget, z_index, style)
    }

    if widget.next == -1 && widget.first == -1 {
        for parent_index := widget.parent; parent_index != -1; {
            parent := &ctx.widgets[parent_index]
            parent_index = parent.parent
            if parent == active_clip^ {
                _emit_clip_end_command(ctx, parent, z_index)
                active_clip^, _ = pop_safe(&ctx.temp)
                break
            }
            if parent.next != -1 {break}
        }
    }
}

_emit_clip_end_command :: proc(ctx: ^Core_Context, widget: ^Widget, z_index: ^int) {
	_add_render_command(ctx, widget, Command_Clip_End{}, z_index)
}

_emit_clip_start_command :: proc(ctx: ^Core_Context, widget: ^Widget, z_index: ^int, style: ^Style) {
	_add_render_command(ctx, widget, Command_Clip_Start{border_radius = style.border.radius}, z_index)
}

_emit_text_command :: proc(ctx: ^Core_Context, widget: ^Widget, z_index: ^int, style: ^Style) {
	if widget.form.text != 0 {
		text := get_text(ctx, widget.form.text)
		command_text: Command_Text
		old := widget.rect.position
		widget.rect.position = widget.info.text_position
		command_text.style = ctx.styles[widget.form.style].text
		command_text.lines = ctx.lines[widget.info.text_lines_range.start:widget.info.text_lines_range.end]
		_add_render_command(ctx, widget, command_text, z_index)
		widget.rect.position = old
	}
}

_emit_rect_command :: proc(ctx: ^Core_Context, widget: ^Widget, z_index: ^int, style: ^Style) {
	command_rect: Command_Rect
	command_rect.color = style.color
	command_rect.border = style.border
	_add_render_command(ctx, widget, command_rect, z_index)
}

_emit_image_command :: proc(ctx: ^Core_Context, widget: ^Widget, z_index: ^int, style: ^Style) {
	if widget.form.image != nil {
		_add_render_command(ctx, widget, Command_Image{data = widget.form.image, tint = style.image_tint}, z_index)
	}
}

_add_render_command :: proc(ctx: ^Core_Context, widget: ^Widget, kind: Render_Command_Kind, z_index: ^int) {
	append(
		&ctx.render_commands,
		Render_Command {
			kind = kind,
			z_index = z_index^ + widget.z_index,
			rect = {widget.rect.position, widget.rect.size, widget.rect.content_size},
			emitter_hash = widget.info.hash,
			emitter_string_id = widget.info.key,
		},
	)
	z_index^ += 1
}
