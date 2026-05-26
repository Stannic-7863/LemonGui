package sokol_backend

import sgfx "sokol-odin/sokol/gfx"
import lui "../../"

import fs "vendor:fontstash"

FONT_ATLAS_W :: 1024
FONT_ATLAS_H :: 1024
Vec4f32 :: [4]f32

Font_Context :: struct {
	fs_ctx:     fs.FontContext,
	atlas_view: sgfx.View,
	atlas:      sgfx.Image,
	sampler:    sgfx.Sampler,
	binding:    sgfx.Bindings,
	dirty:      bool,
}

Backend_Context :: struct {
	pipeline:          sgfx.Pipeline,
	shader:            sgfx.Shader,
	action:            sgfx.Pass_Action,
	target:            sgfx.Image,
	target_view:       sgfx.View,

	target_attachment: sgfx.Attachments,
	binding:           sgfx.Bindings,

	render_cmd_view:   sgfx.View,
	render_cmd_buffer: sgfx.Buffer,

	clip_buffer:       sgfx.Buffer,
	clip_view:         sgfx.View,

	clip_idx_buffer:   sgfx.Buffer,
	clip_idx_view:     sgfx.View,

	clips:             [dynamic]Clip,
	clip_indices:      [dynamic]i32,
	clip_stack:        [dynamic]i32,

	render_commands:   [dynamic]Render_Cmd,

	font:              Font_Context,
}

fs_render_update :: proc (user_data: rawptr, rect: [4]f32, texture_data: rawptr) {
	ctx := cast(^Font_Context)user_data
	ctx.dirty = true
}

fs_render_resize :: proc(user_data: rawptr, width, height: int) {
    ctx := cast(^Font_Context)user_data

    sgfx.uninit_image(ctx.atlas)
    sgfx.init_image(ctx.atlas, {
        width        = i32(width),
        height       = i32(height),
        pixel_format = .R8,
        usage        = {dynamic_update = true},
        sample_count = 1,
    })

    sgfx.uninit_view(ctx.atlas_view)
    sgfx.init_view(ctx.atlas_view, {texture = {image = ctx.atlas}})

    ctx.dirty = true
}

init :: proc(width, height: i32, initial_cmds: int, allocator := context.allocator) -> Backend_Context {
	backend_ctx := Backend_Context{}

	backend_ctx.action.colors[0] = {clear_value = {0, 0, 0, 0}, load_action = .CLEAR, store_action = .STORE}

	shader_desc := ui_shader_desc(sgfx.query_backend())

	backend_ctx.shader = sgfx.make_shader(shader_desc)

	backend_ctx.pipeline = sgfx.make_pipeline({shader = backend_ctx.shader, depth = {pixel_format = .NONE}, colors = {0 = { blend = { enabled = true, src_factor_rgb = .ONE, dst_factor_rgb = .ONE_MINUS_SRC_ALPHA, src_factor_alpha = .ONE, dst_factor_alpha = .ONE_MINUS_SRC_ALPHA, } }}})
	backend_ctx.target = sgfx.make_image({width = width, height = height, pixel_format = .RGBA8, usage = {color_attachment = true}, sample_count = 1})
	backend_ctx.target_view = sgfx.make_view({color_attachment = {image = backend_ctx.target}})
	backend_ctx.target_attachment.colors[0] = backend_ctx.target_view

	backend_ctx.render_commands = make([dynamic]Render_Cmd, initial_cmds, allocator = allocator)
	backend_ctx.clips = make([dynamic]Clip, initial_cmds, allocator = allocator)
	backend_ctx.clip_stack = make([dynamic]i32, initial_cmds, allocator = allocator)
	backend_ctx.clip_indices = make([dynamic]i32, initial_cmds, allocator = allocator)

	{
		buffer_desc := sgfx.Buffer_Desc{usage = {dynamic_update = true, storage_buffer = true}, size = size_of(Render_Cmd) * uint(initial_cmds)}

		backend_ctx.render_cmd_buffer = sgfx.make_buffer(buffer_desc)
		backend_ctx.clip_buffer = sgfx.make_buffer(buffer_desc)
		backend_ctx.clip_idx_buffer = sgfx.make_buffer(buffer_desc)
	}

	backend_ctx.render_cmd_view = sgfx.make_view({storage_buffer = {buffer = backend_ctx.render_cmd_buffer}})
	backend_ctx.clip_view = sgfx.make_view({storage_buffer = {buffer = backend_ctx.clip_buffer}})
	backend_ctx.clip_idx_view = sgfx.make_view({storage_buffer = {buffer = backend_ctx.clip_idx_buffer}})

	{
		font_ctx := Font_Context{}

		fs.Init(&font_ctx.fs_ctx, FONT_ATLAS_W, FONT_ATLAS_H, .TOPLEFT)

		font_ctx.fs_ctx.callbackResize = fs_render_resize
		font_ctx.fs_ctx.callbackUpdate = fs_render_update

		font_ctx.atlas = sgfx.make_image({width = FONT_ATLAS_W, height = FONT_ATLAS_H, pixel_format = .R8, usage = {dynamic_update = true}, sample_count = 1})
		font_ctx.sampler = sgfx.make_sampler({min_filter = .LINEAR, mag_filter = .LINEAR, wrap_u = .REPEAT, wrap_v = .REPEAT})
		font_ctx.atlas_view = sgfx.make_view({texture = {image = font_ctx.atlas}})

		backend_ctx.font = font_ctx
	}

	backend_ctx.binding.views[VIEW_render_cmds_ssbo] = backend_ctx.render_cmd_view
	backend_ctx.binding.views[VIEW_clips_ssbo] = backend_ctx.clip_view
	backend_ctx.binding.views[VIEW_clip_indices_ssbo] = backend_ctx.clip_idx_view
	backend_ctx.binding.views[VIEW_font_tex] = backend_ctx.font.atlas_view
	backend_ctx.binding.samplers[SMP_font_smp] = backend_ctx.font.sampler

	return backend_ctx
}

deinit :: proc(backend_ctx: ^Backend_Context) {
	delete(backend_ctx.render_commands)

	delete(backend_ctx.clips)
	delete(backend_ctx.clip_stack)
	delete(backend_ctx.clip_indices)

	sgfx.destroy_pipeline(backend_ctx.pipeline)
	sgfx.destroy_shader(backend_ctx.shader)

	sgfx.destroy_image(backend_ctx.target)

	sgfx.destroy_view(backend_ctx.target_view)

	sgfx.destroy_buffer(backend_ctx.render_cmd_buffer)
	sgfx.destroy_view(backend_ctx.render_cmd_view)

	sgfx.destroy_buffer(backend_ctx.clip_buffer)
	sgfx.destroy_view(backend_ctx.clip_view)

	sgfx.destroy_buffer(backend_ctx.clip_idx_buffer)
	sgfx.destroy_view(backend_ctx.clip_idx_view)

	fs.Destroy(&backend_ctx.font.fs_ctx)
	sgfx.destroy_image(backend_ctx.font.atlas)
	sgfx.destroy_view(backend_ctx.font.atlas_view)
	sgfx.destroy_sampler(backend_ctx.font.sampler)
}

add_font :: proc(backend_ctx: ^Backend_Context, name: string, path: string) -> (font_id: int) {
	font_id = fs.AddFontPath(&backend_ctx.font.fs_ctx, name, path)
	return font_id
}

resize_cmd_buffer :: proc(backend_ctx: ^Backend_Context) {
	if len(backend_ctx.render_commands) == 0 { return }
	sgfx.uninit_buffer(backend_ctx.render_cmd_buffer)
	sgfx.init_buffer(backend_ctx.render_cmd_buffer, {usage = {dynamic_update = true, storage_buffer = true}, size = 2 * size_of(Render_Cmd) * len(backend_ctx.render_commands)})
	sgfx.uninit_view(backend_ctx.render_cmd_view)
	sgfx.init_view(backend_ctx.render_cmd_view, {storage_buffer = {buffer = backend_ctx.render_cmd_buffer}})
}

resize_clip_buffer :: proc(backend_ctx: ^Backend_Context) {
	if len(backend_ctx.clips) == 0 { return }
	sgfx.uninit_buffer(backend_ctx.clip_buffer)
	sgfx.init_buffer(backend_ctx.clip_buffer, {usage = {dynamic_update = true, storage_buffer = true}, size = 2 * size_of(Clip) * len(backend_ctx.clips)})
	sgfx.uninit_view(backend_ctx.clip_view)
	sgfx.init_view(backend_ctx.clip_view, {storage_buffer = {buffer = backend_ctx.clip_buffer}})
}

resize_clip_idx_buffer :: proc(backend_ctx: ^Backend_Context) {
	if len(backend_ctx.clip_indices) == 0 { return }
	sgfx.uninit_buffer(backend_ctx.clip_idx_buffer)
	sgfx.init_buffer(backend_ctx.clip_idx_buffer, {usage = {dynamic_update = true, storage_buffer = true}, size = 2 * size_of(i32) * len(backend_ctx.clip_indices)})
	sgfx.uninit_view(backend_ctx.clip_idx_view)
	sgfx.init_view(backend_ctx.clip_idx_view, {storage_buffer = {buffer = backend_ctx.clip_idx_buffer}})
}

resize_target :: proc(backend_ctx: ^Backend_Context, width, height: i32) {
	sgfx.uninit_image(backend_ctx.target)
	sgfx.init_image(backend_ctx.target, {
  		width = width,
  		height = height,
  		pixel_format = .RGBA8,
  		usage = {color_attachment = true},
  		sample_count = 1,
	})

	sgfx.uninit_view(backend_ctx.target_view)
	sgfx.init_view(backend_ctx.target_view, {color_attachment = {image = backend_ctx.target}})
}

render :: proc(core_ctx: ^lui.Core_Context, backend_ctx: ^Backend_Context) {
	feed_backend(core_ctx, backend_ctx)

	if backend_ctx.font.dirty {
		pixels := backend_ctx.font.fs_ctx.textureData
		sgfx.update_image(backend_ctx.font.atlas, {mip_levels = {0 = {ptr = raw_data(pixels), size = size_of(u8) * len(pixels)}}})
		backend_ctx.font.dirty = false
	}

	if sgfx.query_buffer_size(backend_ctx.render_cmd_buffer) < size_of(Render_Cmd) * len(backend_ctx.render_commands) {
		resize_cmd_buffer(backend_ctx)
	}

	if sgfx.query_buffer_size(backend_ctx.clip_buffer) < size_of(Clip) * len(backend_ctx.clips) {
		resize_clip_buffer(backend_ctx)
	}

	if sgfx.query_buffer_size(backend_ctx.clip_idx_buffer) < size_of(i32) * len(backend_ctx.clip_indices) {
		resize_clip_idx_buffer(backend_ctx)
	}

	width, height := i32(core_ctx.window_size.x), i32(core_ctx.window_size.y)

	if len(backend_ctx.render_commands) > 0 {
		sgfx.update_buffer(backend_ctx.render_cmd_buffer, { ptr = raw_data(backend_ctx.render_commands), size = size_of(Render_Cmd) * len(backend_ctx.render_commands) })
	}
	if len(backend_ctx.clips) > 0 {
		sgfx.update_buffer(backend_ctx.clip_buffer, { ptr = raw_data(backend_ctx.clips), size = size_of(Clip) * len(backend_ctx.clips) })
	}
	if len(backend_ctx.clip_indices) > 0 {
		sgfx.update_buffer(backend_ctx.clip_idx_buffer, { ptr = raw_data(backend_ctx.clip_indices), size = size_of(i32) * len(backend_ctx.clip_indices) })
	}

	view := matrix[4, 4]f32{
		2.0 / f32(width), 0, 0, -1,
		0, -2.0 / f32(height), 0, 1,
		0, 0, 1, 0,
		0, 0, 0, 1,
	}

	sgfx.begin_pass({ action = backend_ctx.action, attachments = backend_ctx.target_attachment })
	sgfx.apply_viewport(0, 0, width, height, true)
	sgfx.apply_pipeline(backend_ctx.pipeline)
	sgfx.apply_bindings(backend_ctx.binding)
	sgfx.apply_uniforms(UB_ui_vs_params, { ptr = &view, size = size_of(matrix[4, 4]f32)})
	sgfx.draw(0, 6, len(backend_ctx.render_commands))
	sgfx.end_pass()

}

feed_backend :: proc(core_ctx: ^lui.Core_Context, backend_ctx: ^Backend_Context) {
	clear(&backend_ctx.render_commands)
	clear(&backend_ctx.clips)
	clear(&backend_ctx.clip_stack)
	clear(&backend_ctx.clip_indices)

	for cmd in core_ctx.render_commands {
		switch cmd_kind in cmd.kind {

		case lui.Command_Rect:
			render_cmd := Render_Cmd{}

			render_cmd.position_and_size.xy = cmd.rect.position
			render_cmd.position_and_size.zw = cmd.rect.size

			render_cmd.f1 = cmd_kind.border.radius
			render_cmd.f2 = lui.vec4f32_from_axis(cmd_kind.border.thickness)

			render_cmd.color = cmd_kind.color / 255.0
			render_cmd.border_color = cmd_kind.border.color / 255.0

			if len(backend_ctx.clip_stack) > 0 {
				render_cmd.flags[1] = i32(len(backend_ctx.clip_indices))

				append(&backend_ctx.clip_indices, ..backend_ctx.clip_stack[:])

				render_cmd.flags[2] = i32(len(backend_ctx.clip_stack))
			} else {
				render_cmd.flags[1] = -1
				render_cmd.flags[2] = 0
			}

			append(&backend_ctx.render_commands, render_cmd)

		case lui.Command_Clip_Start:
			clip := Clip{}

			clip.position_and_size.xy = cmd.rect.position
			clip.position_and_size.zw = cmd.rect.size

			clip.radius = cmd_kind.border_radius

			append(&backend_ctx.clips, clip)

			append(&backend_ctx.clip_stack, i32(len(backend_ctx.clips) - 1))
		case lui.Command_Clip_End:
			pop(&backend_ctx.clip_stack)
		case lui.Command_Text:
		    fs.BeginState(&backend_ctx.font.fs_ctx)
		    fs.SetFont(&backend_ctx.font.fs_ctx, int(cmd_kind.style.font_id))
		    fs.SetSize(&backend_ctx.font.fs_ctx, cmd_kind.style.font_size)

			ascender, _, _ := fs.VerticalMetrics(&backend_ctx.font.fs_ctx)

		    for line in cmd_kind.lines {
		        iter := fs.TextIterInit(&backend_ctx.font.fs_ctx, line.position.x, line.position.y + ascender, line.line)
		        quad: fs.Quad

		        for fs.TextIterNext(&backend_ctx.font.fs_ctx, &iter, &quad) {
		            render_cmd := Render_Cmd{}
		            render_cmd.position_and_size.xy = {quad.x0, quad.y0}
		            render_cmd.position_and_size.zw = {quad.x1 - quad.x0, quad.y1 - quad.y0}

					render_cmd.f1 = {quad.s0, quad.s1, quad.s1, quad.s0}
					render_cmd.f2 = {quad.t1, quad.t1, quad.t0, quad.t0}

		            render_cmd.color = cmd_kind.style.color / 255.0
		            render_cmd.flags.x = 1

		            if len(backend_ctx.clip_stack) > 0 {
		                render_cmd.flags[1] = i32(len(backend_ctx.clip_indices))
		                append(&backend_ctx.clip_indices, ..backend_ctx.clip_stack[:])
		                render_cmd.flags[2] = i32(len(backend_ctx.clip_stack))
		            } else {
		                render_cmd.flags[1] = -1
		                render_cmd.flags[2] = 0
		            }

		            append(&backend_ctx.render_commands, render_cmd)
		        }
		    }

		    fs.EndState(&backend_ctx.font.fs_ctx) // triggers callbackUpdate if new glyphs were baked
		case lui.Command_Image:
		case lui.Command_Custom:
		}
	}
}

measure_text_width :: proc(text: string, style: lui.Text_Style, user_data: rawptr) -> f32 {
    fctx := cast(^Font_Context)user_data
    fs.SetFont(&fctx.fs_ctx, int(style.font_id))
    fs.SetSize(&fctx.fs_ctx, style.font_size)
    return fs.TextBounds(&fctx.fs_ctx, text)
}

measure_text_height :: proc(style: lui.Text_Style, user_data: rawptr) -> f32 {
    fctx := cast(^Font_Context)user_data
    if fctx == nil { return style.font_size }
    fs.SetFont(&fctx.fs_ctx, int(style.font_id))
    fs.SetSize(&fctx.fs_ctx, style.font_size)
    _, _, line_height := fs.VerticalMetrics(&fctx.fs_ctx)
    return style.font_size
}

measure_text_hover_index :: proc(text: string, point: [2]f32, style: lui.Text_Style, user_data: rawptr) -> (int, bool) {
    fctx := cast(^Font_Context)user_data
    fs.SetFont(&fctx.fs_ctx, int(style.font_id))
    fs.SetSize(&fctx.fs_ctx, style.font_size)

    iter := fs.TextIterInit(&fctx.fs_ctx, 0, 0, text)
    quad: fs.Quad

    prev_next := 0

    for fs.TextIterNext(&fctx.fs_ctx, &iter, &quad) {
        mid := (quad.x0 + quad.x1) * 0.5
        if point.x <= mid {
            return iter.str, true
        }
        prev_next = iter.next
    }

    if len(text) > 0 && point.x >= 0 {
        return len(text), true
    }

    return 0, false
}
