package sdl_gpu_backend

import ui "./../../../"
import "vendor:sdl3/ttf"

import "core:fmt"
import "core:mem"
import "core:os/os2"
import sdl "vendor:sdl3"

Vec2f32 :: [2]f32
Vec4f32 :: [4]f32

Gpu_Batch :: struct {
	commands: []Gpu_Render_Command,
	texture:  ^sdl.GPUTexture,
}

Gpu_Render_Command :: struct {
	radius:       Vec4f32,
	position:     Vec2f32,
	size:         Vec2f32,
	rect_index:   i32,
	border_index: i32,
	text_index:   i32,
	_:            [1]i32,
}

Text :: struct {
	uv:    [4]Vec2f32,
	color: Vec4f32,
}

Border :: struct {
	thickness: Vec4f32,
	color:     [4]Vec4f32,
}

Rect :: struct {
	color: Vec4f32,
}

Gpu_Dynamic_Buffer :: struct {
	data:           ^sdl.GPUBuffer,
	tansfer:        ^sdl.GPUTransferBuffer,
	byte_size:      int,
	prev_byte_size: int,
}

Backend_Context :: struct {
	gpu:                 ^sdl.GPUDevice,
	window:              ^sdl.Window,
	pipeline:            ^sdl.GPUGraphicsPipeline,
	font_engine:         ^ttf.TextEngine,
	font_sampler:        ^sdl.GPUSampler,
	rects_buf:           Gpu_Dynamic_Buffer,
	borders_buf:         Gpu_Dynamic_Buffer,
	text_buf:            Gpu_Dynamic_Buffer,
	render_commands_buf: Gpu_Dynamic_Buffer,
	fonts:               [dynamic]^ttf.Font,
	texts:               [dynamic]Text,
	rects:               [dynamic]Rect,
	borders:             [dynamic]Border,
	render_commands:     [dynamic]Gpu_Render_Command,
	batch:               [dynamic]Gpu_Batch,
}

init :: proc(window_title: cstring, vert_path, frag_path: string) -> Backend_Context {
	sdl.SetLogPriorities(.VERBOSE)
	assert(sdl.Init({.VIDEO}))

	window := sdl.CreateWindow(window_title, 800, 600, {.RESIZABLE})
	gpu := sdl.CreateGPUDevice({.SPIRV}, true, nil)
	assert(sdl.ClaimWindowForGPUDevice(gpu, window))

	vert_shader := load_shader(gpu, vert_path, .VERTEX, {.SPIRV}, 1, 0, 4)
	frag_shader := load_shader(gpu, frag_path, .FRAGMENT, {.SPIRV}, 0, 1, 0)

	pipeline := sdl.CreateGPUGraphicsPipeline(
		gpu,
		{
			fragment_shader = frag_shader,
			vertex_shader = vert_shader,
			target_info = {
				num_color_targets = 1,
				color_target_descriptions = &sdl.GPUColorTargetDescription {
					format = sdl.GetGPUSwapchainTextureFormat(gpu, window),
					blend_state = {
						src_alpha_blendfactor = .ONE,
						dst_alpha_blendfactor = .ONE_MINUS_SRC_ALPHA,
						alpha_blend_op = .ADD,
						src_color_blendfactor = .SRC_ALPHA,
						dst_color_blendfactor = .ONE_MINUS_SRC_ALPHA,
						color_blend_op = .ADD,
						enable_blend = true,
						enable_color_write_mask = true,
						color_write_mask = ~{},
					},
				},
			},
			primitive_type = .TRIANGLELIST,
		},
	)

	sdl.ReleaseGPUShader(gpu, vert_shader)
	sdl.ReleaseGPUShader(gpu, frag_shader)

	backend_ctx: Backend_Context
	backend_ctx.gpu = gpu
	backend_ctx.window = window
	backend_ctx.pipeline = pipeline
	backend_ctx.text_buf = init_gpu_dynamic_buffer(&backend_ctx)
	backend_ctx.rects_buf = init_gpu_dynamic_buffer(&backend_ctx)
	backend_ctx.borders_buf = init_gpu_dynamic_buffer(&backend_ctx)
	backend_ctx.render_commands_buf = init_gpu_dynamic_buffer(&backend_ctx)

	assert(sdl.SetGPUSwapchainParameters(gpu, window, .SDR, .VSYNC))
	return backend_ctx
}

init_font :: proc(backend_ctx: ^Backend_Context) {
	assert(ttf.Init())
	engine := ttf.CreateGPUTextEngine(backend_ctx.gpu)

	backend_ctx.font_sampler = sdl.CreateGPUSampler(
		backend_ctx.gpu,
		{
			address_mode_u = .REPEAT,
			address_mode_v = .REPEAT,
			address_mode_w = .REPEAT,
			mag_filter = .LINEAR,
			min_filter = .LINEAR,
			mipmap_mode = .LINEAR,
		},
	)
	backend_ctx.font_engine = engine
}

add_font :: proc(backend_ctx: ^Backend_Context, path: cstring, size: f32) -> ^ttf.Font {
	font := ttf.OpenFont(path, size)
	assert(font != nil)
	append(&backend_ctx.fonts, font)
	return font
}

init_gpu_dynamic_buffer :: proc(backend_ctx: ^Backend_Context) -> Gpu_Dynamic_Buffer {
	data_buffer := sdl.CreateGPUBuffer(backend_ctx.gpu, {size = 64, usage = {.GRAPHICS_STORAGE_READ}})
	transfer_buffer := sdl.CreateGPUTransferBuffer(backend_ctx.gpu, {size = 64, usage = .UPLOAD})

	dyn_buf: Gpu_Dynamic_Buffer
	dyn_buf.byte_size = 64
	dyn_buf.prev_byte_size = 64
	dyn_buf.data = data_buffer
	dyn_buf.tansfer = transfer_buffer

	return dyn_buf
}

de_init :: proc() {}
de_init_font :: proc() {}
de_init_gpu_dynamic_buffer :: proc() {}

update_dynamic_buffer :: proc(backend_ctx: ^Backend_Context, buf: ^Gpu_Dynamic_Buffer, command_buffer: ^sdl.GPUCommandBuffer, data: rawptr) {
	if buf.byte_size > buf.prev_byte_size {
		sdl.ReleaseGPUBuffer(backend_ctx.gpu, buf.data)
		buf.data = sdl.CreateGPUBuffer(backend_ctx.gpu, {size = u32(buf.byte_size), usage = {.GRAPHICS_STORAGE_READ}})

		sdl.ReleaseGPUTransferBuffer(backend_ctx.gpu, buf.tansfer)
		buf.tansfer = sdl.CreateGPUTransferBuffer(backend_ctx.gpu, {size = u32(buf.byte_size), usage = .UPLOAD})
	}

	if buf.byte_size > 0 {
		tmem := sdl.MapGPUTransferBuffer(backend_ctx.gpu, buf.tansfer, false)
		mem.copy(tmem, data, buf.byte_size)
		sdl.UnmapGPUTransferBuffer(backend_ctx.gpu, buf.tansfer)

		copy_pass := sdl.BeginGPUCopyPass(command_buffer)
		sdl.UploadToGPUBuffer(copy_pass, {transfer_buffer = buf.tansfer}, {size = u32(buf.byte_size), buffer = buf.data}, false)
		sdl.EndGPUCopyPass(copy_pass)
	}
}

render :: proc(backend_ctx: ^Backend_Context, core_ctx: ^ui.Core_Context) {
	clear(&backend_ctx.rects)
	clear(&backend_ctx.borders)
	clear(&backend_ctx.render_commands)
	clear(&backend_ctx.texts)
	clear(&backend_ctx.batch)

	feed_backend(backend_ctx, core_ctx)

	command_buf := sdl.AcquireGPUCommandBuffer(backend_ctx.gpu)

	update_buffers(backend_ctx, command_buf)

	swapchain_texture: ^sdl.GPUTexture
	assert(sdl.WaitAndAcquireGPUSwapchainTexture(command_buf, backend_ctx.window, &swapchain_texture, nil, nil))

	color_target := sdl.GPUColorTargetInfo {
		texture  = swapchain_texture,
		load_op  = .CLEAR,
		store_op = .STORE,
	}

	projection_mat := matrix[4, 4]f32{
		2.0 / f32(core_ctx.window_size.x), 0, 0, -1,
		0, -2.0 / f32(core_ctx.window_size.y), 0, 1,
		0, 0, 1, 0,
		0, 0, 0, 1,
	}

	render_pass := sdl.BeginGPURenderPass(command_buf, &color_target, 1, nil)
	sdl.BindGPUGraphicsPipeline(render_pass, backend_ctx.pipeline)
	sdl.PushGPUVertexUniformData(command_buf, 0, &projection_mat, size_of(projection_mat))
	storage_bufs := []^sdl.GPUBuffer {
		backend_ctx.rects_buf.data,
		backend_ctx.borders_buf.data,
		backend_ctx.text_buf.data,
		backend_ctx.render_commands_buf.data,
	}
	sdl.BindGPUVertexStorageBuffers(render_pass, 0, raw_data(storage_bufs), u32(len(storage_bufs)))
	instance_offset: u32
	for batch_data in backend_ctx.batch {
		sdl.BindGPUFragmentSamplers(
			render_pass,
			0,
			&sdl.GPUTextureSamplerBinding{texture = batch_data.texture, sampler = backend_ctx.font_sampler},
			1,
		)
		sdl.DrawGPUPrimitives(render_pass, 6, u32(len(batch_data.commands)), 0, instance_offset)
		instance_offset += u32(len(batch_data.commands))
	}
	sdl.EndGPURenderPass(render_pass)

	assert(sdl.SubmitGPUCommandBuffer(command_buf))
}

update_buffers :: proc(backend_ctx: ^Backend_Context, command_buffer: ^sdl.GPUCommandBuffer) {
	backend_ctx.borders_buf.prev_byte_size = backend_ctx.borders_buf.byte_size
	backend_ctx.rects_buf.prev_byte_size = backend_ctx.borders_buf.byte_size
	backend_ctx.render_commands_buf.prev_byte_size = backend_ctx.render_commands_buf.byte_size
	backend_ctx.text_buf.prev_byte_size = backend_ctx.text_buf.byte_size

	backend_ctx.borders_buf.byte_size = len(backend_ctx.borders) * size_of(Border)
	backend_ctx.rects_buf.byte_size = len(backend_ctx.rects) * size_of(Rect)
	backend_ctx.render_commands_buf.byte_size = len(backend_ctx.render_commands) * size_of(Gpu_Render_Command)
	backend_ctx.text_buf.byte_size = len(backend_ctx.texts) * size_of(Text)

	update_dynamic_buffer(backend_ctx, &backend_ctx.text_buf, command_buffer, raw_data(backend_ctx.texts))
	update_dynamic_buffer(backend_ctx, &backend_ctx.rects_buf, command_buffer, raw_data(backend_ctx.rects))
	update_dynamic_buffer(backend_ctx, &backend_ctx.borders_buf, command_buffer, raw_data(backend_ctx.borders))
	update_dynamic_buffer(backend_ctx, &backend_ctx.render_commands_buf, command_buffer, raw_data(backend_ctx.render_commands))
}

feed_backend :: proc(backend_ctx: ^Backend_Context, core_ctx: ^ui.Core_Context) {
	start_hash: ui.Hash
	start_index: int

	grc: ^Gpu_Render_Command

	batch_start: int
	active_atlast_texture: ^sdl.GPUTexture

	for cmd, cmd_index in core_ctx.render_commands {
		if start_hash != cmd.emitter_hash {
			start_hash = cmd.emitter_hash
			start_index = cmd_index
			append(&backend_ctx.render_commands, Gpu_Render_Command{})
			grc = &backend_ctx.render_commands[len(backend_ctx.render_commands) - 1]
			grc.position = cmd.rect.position
			grc.size = cmd.rect.size
			grc.border_index = -1
			grc.rect_index = -1
			grc.text_index = -1
		}

		switch cmd_kind in cmd.kind {
		case ui.Command_Rect:
			grc.radius = cmd_kind.border_radius
			grc.rect_index = i32(len(backend_ctx.rects))
			append(&backend_ctx.rects, Rect{cmd_kind.color / 255})
		case ui.Command_Border:
			grc.border_index = i32(len(backend_ctx.borders))
			append(&backend_ctx.borders, Border{color = cmd_kind.style.color / 255, thickness = transmute(Vec4f32)cmd_kind.style.thickness})
		case ui.Command_Clip_Start:
		case ui.Command_Clip_End:
		case ui.Command_Image:
		case ui.Command_Custom:
		case ui.Command_Text:
			// Text command is emitted at the end of the cluster from an emitter.
			// So a new gpu render commands can be issued from here and will cause no problem
			line_offset: f32
			text_height := measure_text_height(cmd_kind.style)
			for line in cmd_kind.lines {
				ttf.SetFontSize(cast(^ttf.Font)cmd_kind.style.font, cmd_kind.style.font_size)

				text := ttf.CreateText(backend_ctx.font_engine, cast(^ttf.Font)cmd_kind.style.font, cast(cstring)raw_data(line), len(line))
				draw_data := ttf.GetGPUTextDrawData(text)

				for seq := draw_data; seq != nil; seq = seq.next {
					for idx: i32 = 0; idx < seq.num_indices; idx += 6 {
						i0 := seq.indices[idx + 0]
						i1 := seq.indices[idx + 1]
						i2 := seq.indices[idx + 2]
						i3 := seq.indices[idx + 5]

						v0 := seq.xy[i0]
						v1 := seq.xy[i1]
						v2 := seq.xy[i2]
						v3 := seq.xy[i3]

						uv0 := seq.uv[i0]
						uv1 := seq.uv[i1]
						uv2 := seq.uv[i2]
						uv3 := seq.uv[i3]

						x_min := min(min(v0.x, v1.x), min(v2.x, v3.x))
						y_min := min(min(v0.y, v1.y), min(v2.y, v3.y))
						x_max := max(max(v0.x, v1.x), max(v2.x, v3.x))
						y_max := max(max(v0.y, v1.y), max(v2.y, v3.y))

						width := x_max - x_min
						height := y_max - y_min

						position := cmd.rect.position + {x_min, -y_min + line_offset}

						text_command: Text = {
							uv    = {uv0.xy, uv1.xy, uv2.xy, uv3.xy},
							color = cmd_kind.style.color / 255,
						}

						index := len(backend_ctx.texts)
						append(&backend_ctx.texts, text_command)

						render_command: Gpu_Render_Command
						render_command.rect_index = -1
						render_command.border_index = -1
						render_command.position = position
						render_command.size = {width, -height}
						render_command.text_index = i32(index)
						append(&backend_ctx.render_commands, render_command)

						if active_atlast_texture == nil {
							active_atlast_texture = draw_data.atlas_texture
						}

						if draw_data.next != nil && draw_data.next.atlas_texture != active_atlast_texture {
							append(&backend_ctx.batch, Gpu_Batch{backend_ctx.render_commands[batch_start:index], active_atlast_texture})
							active_atlast_texture = draw_data.atlas_texture
							batch_start = index
						}
					}
				}
				line_offset += text_height + cmd_kind.style.line_spacing
				ttf.DestroyText(text)
			}
		}
	}

	if batch_start < len(backend_ctx.render_commands) {
		append(&backend_ctx.batch, Gpu_Batch{backend_ctx.render_commands[batch_start:len(backend_ctx.render_commands)], active_atlast_texture})
	}
}

load_shader :: proc(
	gpu: ^sdl.GPUDevice,
	path: string,
	stage: sdl.GPUShaderStage,
	format: sdl.GPUShaderFormat,
	num_ubo, num_samplers, num_storage_buffers: u32,
) -> ^sdl.GPUShader {

	source, read_err := os2.read_entire_file_from_path(path, context.allocator)
	defer delete(source, context.allocator)

	if read_err != nil {
		panic(fmt.tprint(read_err))
	}

	shader := sdl.CreateGPUShader(
		gpu,
		{
			code_size = len(source),
			entrypoint = "main",
			code = raw_data(source),
			stage = stage,
			format = format,
			num_uniform_buffers = num_ubo,
			num_samplers = num_samplers,
			num_storage_buffers = num_storage_buffers,
		},
	)
	assert(shader != nil)
	return shader
}

measure_text_width :: proc(text: string, style: ui.Text_Style) -> f32 {
	font := cast(^ttf.Font)(style.font)
	ttf.SetFontSize(font, style.font_size)

	w, h: i32
	ttf.GetStringSize(font, cast(cstring)raw_data(text), len(text), &w, &h)

	return f32(w)
}

measure_text_height :: proc(style: ui.Text_Style) -> f32 {
	font := cast(^ttf.Font)(style.font)
	ttf.SetFontSize(font, style.font_size)
	return f32(ttf.GetFontHeight(font))
}
