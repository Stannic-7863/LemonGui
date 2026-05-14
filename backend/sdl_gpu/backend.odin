package sdl_gpu_backend

import "base:runtime"
import ui "./../../"
import "vendor:sdl3/ttf"

import "core:fmt"
import "core:mem"
import "core:os"
import sdl "vendor:sdl3"

Vec2f32 :: [2]f32
Vec4f32 :: [4]f32

Gpu_Batch :: struct {
	start, end: int,
	texture:    ^sdl.GPUTexture,
}

Gpu_Render_Command :: struct #packed {
	position_and_size: Vec4f32,
	f1:                Vec4f32, // uv_x on flag.x = 1 else border radius
	f2:                Vec4f32, // uv_y on flag.x = 1 else border thickness
	color:             Vec4f32,
	border_color:      [4]Vec4f32,
	flags:             [4]i32, // [0] type, rect or text, [1] clip idx
}

Gpu_Dynamic_Buffer :: struct {
	data:           ^sdl.GPUBuffer,
	tansfer:        ^sdl.GPUTransferBuffer,
	byte_size:      int,
	prev_byte_size: int,
}

Clip :: struct {
	position_and_size: Vec4f32,
	radius:            Vec4f32,
}

Backend_Context :: struct {
	window_size:         [2]i32,
	gpu:                 ^sdl.GPUDevice,
	window:              ^sdl.Window,
	font_engine:         ^ttf.TextEngine,
	font_sampler:        ^sdl.GPUSampler,
	dummy_texture:       ^sdl.GPUTexture,
	pipeline:            ^sdl.GPUGraphicsPipeline,
	render_commands_buf: Gpu_Dynamic_Buffer,
	clip_buf:            Gpu_Dynamic_Buffer,
	clip_idx_buf:        Gpu_Dynamic_Buffer,
	clips:               [dynamic]Clip,
	clip_stack:          [dynamic]i32,
	clip_idx:            [dynamic]i32,
	fonts:               [dynamic]^ttf.Font,
	render_commands:     [dynamic]Gpu_Render_Command,
	batch:               [dynamic]Gpu_Batch,
}

init :: proc(window_title: cstring, vert_path, frag_path: string, allocator: runtime.Allocator) -> Backend_Context {
	sdl.SetLogPriorities(.VERBOSE)
	assert(sdl.Init({.VIDEO}))

	window := sdl.CreateWindow(window_title, 800, 600, {.RESIZABLE})
	gpu := sdl.CreateGPUDevice({.SPIRV}, false, nil)
	assert(sdl.ClaimWindowForGPUDevice(gpu, window))

	vert_shader := load_shader(gpu, vert_path, .VERTEX, {.SPIRV}, 1, 0, 1)
	frag_shader := load_shader(gpu, frag_path, .FRAGMENT, {.SPIRV}, 0, 1, 2)
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
						alpha_blend_op = .ADD,
						src_alpha_blendfactor = .ONE,
						dst_alpha_blendfactor = .ONE_MINUS_SRC_ALPHA,
						src_color_blendfactor = .ONE,
						dst_color_blendfactor = .ONE_MINUS_SRC_ALPHA,
						color_blend_op = .ADD,
						enable_blend = true,
						enable_color_write_mask = true,
						color_write_mask = ~{},
					},
				},
			},
		},
	)

	sdl.ReleaseGPUShader(gpu, vert_shader)
	sdl.ReleaseGPUShader(gpu, frag_shader)

	window_width, window_height: i32
	sdl.GetWindowSize(window, &window_width, &window_height)

	backend_ctx: Backend_Context
	backend_ctx.window_size = {window_width, window_height}
	backend_ctx.gpu = gpu
	backend_ctx.window = window
	backend_ctx.pipeline = pipeline
	backend_ctx.clips = make([dynamic]Clip, allocator)
	backend_ctx.clip_idx = make([dynamic]i32, allocator)
	backend_ctx.clip_stack = make([dynamic]i32, allocator)
	backend_ctx.batch = make([dynamic]Gpu_Batch, allocator)
	backend_ctx.fonts = make([dynamic]^ttf.Font, allocator)
	backend_ctx.render_commands = make([dynamic]Gpu_Render_Command, allocator)
	backend_ctx.render_commands_buf = init_gpu_dynamic_buffer(&backend_ctx)
	backend_ctx.clip_buf = init_gpu_dynamic_buffer(&backend_ctx)
	backend_ctx.clip_idx_buf = init_gpu_dynamic_buffer(&backend_ctx)
	backend_ctx.dummy_texture = sdl.CreateGPUTexture(gpu, {height = 1, width = 1, format = .R8G8B8A8_UNORM, usage = {.SAMPLER}, layer_count_or_depth = 1, num_levels = 1})

	assert(sdl.SetGPUSwapchainParameters(gpu, window, .SDR, .IMMEDIATE))
	return backend_ctx
}

init_font :: proc(backend_ctx: ^Backend_Context) {
	assert(ttf.Init())
	engine := ttf.CreateGPUTextEngine(backend_ctx.gpu)

	backend_ctx.font_sampler = sdl.CreateGPUSampler(
		backend_ctx.gpu,
		{address_mode_u = .REPEAT, address_mode_v = .REPEAT, address_mode_w = .REPEAT, mag_filter = .LINEAR, min_filter = .LINEAR, mipmap_mode = .LINEAR},
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

de_init :: proc(backend_ctx: ^Backend_Context) {
	delete(backend_ctx.render_commands)
	delete(backend_ctx.batch)
	delete(backend_ctx.fonts)
	delete(backend_ctx.clip_idx)
	delete(backend_ctx.clip_stack)
	delete(backend_ctx.clips)

	de_init_gpu_dynamic_buffer(backend_ctx, &backend_ctx.render_commands_buf)
	de_init_gpu_dynamic_buffer(backend_ctx, &backend_ctx.clip_buf)
	de_init_gpu_dynamic_buffer(backend_ctx, &backend_ctx.clip_idx_buf)

	sdl.ReleaseGPUTexture(backend_ctx.gpu, backend_ctx.dummy_texture)
	sdl.ReleaseGPUGraphicsPipeline(backend_ctx.gpu, backend_ctx.pipeline)
	sdl.ReleaseWindowFromGPUDevice(backend_ctx.gpu, backend_ctx.window)
	sdl.DestroyGPUDevice(backend_ctx.gpu)
	sdl.DestroyWindow(backend_ctx.window)
	sdl.Quit()
}

de_init_font :: proc(backend_ctx: ^Backend_Context) {
	for font in backend_ctx.fonts {
		ttf.CloseFont(font)
	}
	ttf.DestroyGPUTextEngine(backend_ctx.font_engine)
	sdl.ReleaseGPUSampler(backend_ctx.gpu, backend_ctx.font_sampler)
	ttf.Quit()
}

de_init_gpu_dynamic_buffer :: proc(backend_ctx: ^Backend_Context, buffer: ^Gpu_Dynamic_Buffer) {
	sdl.ReleaseGPUBuffer(backend_ctx.gpu, buffer.data)
	sdl.ReleaseGPUTransferBuffer(backend_ctx.gpu, buffer.tansfer)
}

update_dynamic_buffer :: proc(backend_ctx: ^Backend_Context, buf: ^Gpu_Dynamic_Buffer, command_buffer: ^sdl.GPUCommandBuffer, data: rawptr) {
	if buf.byte_size > buf.prev_byte_size {
		buf.prev_byte_size = buf.byte_size
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
	clear(&backend_ctx.render_commands)
	clear(&backend_ctx.batch)
	clear(&backend_ctx.clips)
	clear(&backend_ctx.clip_stack)
	clear(&backend_ctx.clip_idx)

	window_w, window_h: i32
	sdl.GetWindowSize(backend_ctx.window, &window_w, &window_h)

	backend_ctx.window_size = {window_w, window_h}

	projection_mat := matrix[4, 4]f32{
		2.0 / f32(core_ctx.window_size.x), 0, 0, -1,
		0, -2.0 / f32(core_ctx.window_size.y), 0, 1,
		0, 0, 1, 0,
		0, 0, 0, 1,
	}

	feed_backend(backend_ctx, core_ctx)

	command_buf := sdl.AcquireGPUCommandBuffer(backend_ctx.gpu)

	backend_ctx.render_commands_buf.byte_size = len(backend_ctx.render_commands) * size_of(Gpu_Render_Command)
	update_dynamic_buffer(backend_ctx, &backend_ctx.render_commands_buf, command_buf, raw_data(backend_ctx.render_commands))

	backend_ctx.clip_buf.byte_size = len(backend_ctx.clips) * size_of(Clip)
	update_dynamic_buffer(backend_ctx, &backend_ctx.clip_buf, command_buf, raw_data(backend_ctx.clips))

	backend_ctx.clip_idx_buf.byte_size = len(backend_ctx.clip_idx) * size_of(i32)
	update_dynamic_buffer(backend_ctx, &backend_ctx.clip_idx_buf, command_buf, raw_data(backend_ctx.clip_idx))

	swapchain_texture: ^sdl.GPUTexture
	assert(sdl.WaitAndAcquireGPUSwapchainTexture(command_buf, backend_ctx.window, &swapchain_texture, nil, nil))

	swapchain_target := sdl.GPUColorTargetInfo {
		texture  = swapchain_texture,
		load_op  = .CLEAR,
		store_op = .STORE,
	}

	render_pass := sdl.BeginGPURenderPass(command_buf, &swapchain_target, 1, nil)
	geometry_pass(backend_ctx, core_ctx, render_pass, command_buf, &projection_mat)
	sdl.EndGPURenderPass(render_pass)

	assert(sdl.SubmitGPUCommandBuffer(command_buf))
}

geometry_pass :: proc(
	backend_ctx: ^Backend_Context,
	core_ctx: ^ui.Core_Context,
	render_pass: ^sdl.GPURenderPass,
	command_buf: ^sdl.GPUCommandBuffer,
	projection: ^matrix[4, 4]f32,
) {
	storage_bufs_vert := []^sdl.GPUBuffer{backend_ctx.render_commands_buf.data}
	storage_bufs_frag := []^sdl.GPUBuffer{backend_ctx.clip_buf.data, backend_ctx.clip_idx_buf.data}

	sdl.BindGPUGraphicsPipeline(render_pass, backend_ctx.pipeline)
	sdl.PushGPUVertexUniformData(command_buf, 0, projection, size_of(projection^))
	sdl.BindGPUVertexStorageBuffers(render_pass, 0, raw_data(storage_bufs_vert), u32(len(storage_bufs_vert)))
	sdl.BindGPUFragmentStorageBuffers(render_pass, 0, raw_data(storage_bufs_frag), u32(len(storage_bufs_frag)))
	sdl.BindGPUFragmentSamplers(render_pass, 0, &sdl.GPUTextureSamplerBinding{texture = backend_ctx.dummy_texture, sampler = backend_ctx.font_sampler}, 1)

	instance_offset: u32
	for batch in backend_ctx.batch {
		count := u32(batch.end - batch.start)
		if count == 0 do continue
		if batch.texture != nil {
			sdl.BindGPUFragmentSamplers(render_pass, 0, &sdl.GPUTextureSamplerBinding{texture = batch.texture, sampler = backend_ctx.font_sampler}, 1)
		}
		sdl.DrawGPUPrimitives(render_pass, 6, count, 0, instance_offset)
		instance_offset += count
	}
}

feed_backend :: proc(backend_ctx: ^Backend_Context, core_ctx: ^ui.Core_Context) {
	batch_start := int(0)
	active_atlast_texture: ^sdl.GPUTexture

	for &cmd, cmd_index in core_ctx.render_commands {
		cmd.rect.position += cmd.rect.scroll_offset
		switch cmd_kind in cmd.kind {
		case ui.Command_Rect:
			r := Gpu_Render_Command{}
			r.f1 = cmd_kind.border.radius.wzyx
			r.f2 = ui.vec4f32_to_axis(cmd_kind.border.thickness)
			r.color = cmd_kind.color / 255
			r.border_color = cmd_kind.border.color / 255
			r.position_and_size.xy = cmd.rect.position
			r.position_and_size.zw = cmd.rect.size
			if len(backend_ctx.clip_stack) > 0 {
				r.flags[1] = i32(len(backend_ctx.clip_idx))
				append(&backend_ctx.clip_idx, ..backend_ctx.clip_stack[:])
				r.flags[2] = i32(len(backend_ctx.clip_stack))
			} else {
				r.flags[1] = -1
				r.flags[2] = 0
			}
			append(&backend_ctx.render_commands, r)
		case ui.Command_Clip_Start:
			c := Clip{}
			c.position_and_size.xy = cmd.rect.position
			c.position_and_size.zw = cmd.rect.size
			c.radius = cmd_kind.border_radius
			append(&backend_ctx.clips, c)
			append(&backend_ctx.clip_stack, i32(len(backend_ctx.clips)) - 1)
		case ui.Command_Clip_End:
			pop_safe(&backend_ctx.clip_stack)
		case ui.Command_Image:
		case ui.Command_Custom:
		case ui.Command_Text:
			for line in cmd_kind.lines {
				text := ttf.CreateText(backend_ctx.font_engine, cast(^ttf.Font)cmd_kind.style.font, cast(cstring)raw_data(line.line), len(line.line))
				defer ttf.DestroyText(text)
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

						position := line.position + {x_min, -y_min}

						index := len(backend_ctx.render_commands)

						r := Gpu_Render_Command{}

						r.position_and_size.xy = position
						r.position_and_size.zw = {width, -height}
						r.f1 = {uv0.x, uv1.x, uv2.x, uv3.x}
						r.f2 = {uv0.y, uv1.y, uv2.y, uv3.y}
						r.flags.x = 1
						r.color = cmd_kind.style.color / 255
						if len(backend_ctx.clip_stack) > 0 {
							r.flags[1] = i32(len(backend_ctx.clip_idx))
							append(&backend_ctx.clip_idx, ..backend_ctx.clip_stack[:])
							r.flags[2] = i32(len(backend_ctx.clip_stack))
						} else {
							r.flags[1] = -1
							r.flags[2] = 0
						}
						append(&backend_ctx.render_commands, r)

						if active_atlast_texture == nil {
							active_atlast_texture = draw_data.atlas_texture
						}

						if seq.next != nil && seq.next.atlas_texture != active_atlast_texture {
							append(&backend_ctx.batch, Gpu_Batch{start = batch_start, end = index, texture = active_atlast_texture})
							active_atlast_texture = draw_data.atlas_texture
							batch_start = index
						}
					}
				}
			}
		}
	}

	if batch_start < len(backend_ctx.render_commands) {
		append(&backend_ctx.batch, Gpu_Batch{start = batch_start, end = len(backend_ctx.render_commands), texture = active_atlast_texture})
	}
}

load_shader :: proc(gpu: ^sdl.GPUDevice, path: string, stage: sdl.GPUShaderStage, format: sdl.GPUShaderFormat, num_ubo, num_samplers, num_storage_buffers: u32) -> ^sdl.GPUShader {

	source, read_err := os.read_entire_file_from_path(path, context.allocator)
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
	w, h: i32
	ttf.GetStringSize(font, cast(cstring)raw_data(text), len(text), &w, &h)
	return f32(w)
}

measure_text_height :: proc(style: ui.Text_Style) -> f32 {
	font := cast(^ttf.Font)(style.font)
	return f32(ttf.GetFontHeight(font))
}

measure_text_hover_index :: proc(text: string, point: Vec2f32, style: ui.Text_Style, user_data: rawptr) -> (int) {
	engine := cast(^ttf.TextEngine)user_data
	font := cast(^ttf.Font)style.font

	if engine == nil || font == nil { return 0 }

	text := ttf.CreateText(engine, font, cast(cstring)raw_data(text), uint(len(text)))
	defer ttf.DestroyText(text)
	if text == nil { return 0 }

	substring: ttf.SubString
	if ttf.GetTextSubStringForPoint(text, i32(point.x), 0, &substring) {
		return int(substring.offset)
	}

	return 0
}
