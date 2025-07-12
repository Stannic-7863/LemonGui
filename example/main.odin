package main

import "base:runtime"

import "core:fmt"
import rl "vendor:raylib"

import cu "./../"


main :: proc() {
	for arg in runtime.args__ {
		if arg == "demo" {
			demo()
			break
		}
		if arg == "test" {
			test()
			break
		}
	}
}

render :: proc(ctx: cu.Core_Context, texture: rl.Texture, shader: rl.Shader) {
	rect_center_loc := rl.GetShaderLocation(shader, "rect_center")
	rect_size_loc := rl.GetShaderLocation(shader, "rect_size")
	border_radius_loc := rl.GetShaderLocation(shader, "border_radius")
	color_loc := rl.GetShaderLocation(shader, "color")

	for cmd in ctx.render_commands {
		switch v in cmd.type {
		case cu.Command_Rect:
			// rl.DrawRectangleV(v.position, v.size, cast(rl.Color)v.color)
			size := v.size / 2
			pos := v.position + size
			rad := v.border_radius
			color: [4]f32
			for c, i in v.color {
				color[i] = f32(c) / 255
			}

			rl.BeginShaderMode(shader)
			rl.SetShaderValue(shader, rect_center_loc, &pos, .VEC2)
			rl.SetShaderValue(shader, rect_size_loc, &size, .VEC2)
			rl.SetShaderValue(shader, border_radius_loc, &rad, .VEC4)
			rl.SetShaderValue(shader, color_loc, &color, .VEC4)

			src := rl.Rectangle{0, 0, 1, 1}
			dst := rl.Rectangle{v.position.x, v.position.y, v.size.x, v.size.y}

			rl.DrawTexturePro(texture, src, dst, {}, 0.0, rl.WHITE)
			rl.EndShaderMode()
		case cu.Command_Text:
			if cursor, ok := v.cursor.([2]int); ok {
				{
					total_length: int
					line_position_y := v.position.y
					last_line: string
					for l, i in ctx.text_lines[v.start:v.end] {
						if cursor.x >= total_length && cursor.x < total_length + len(l) {
							relative := cursor.x - total_length
							rl.DrawRectangleV(
								{v.position.x + ctx.text_measure_proc(l[:relative], v.style), line_position_y},
								{1, v.style.font_size},
								rl.GREEN,
							)
							break
						}
						total_length += len(l)
						last_line = l
						line_position_y += v.style.line_spacing + v.style.font_size
					}
					if cursor.x == total_length {
						if len(last_line) > 0 {
							if last_line[len(last_line) - 1] != '\n' {
								line_position_y -= v.style.line_spacing + v.style.font_size
								rl.DrawRectangleV(
									{v.position.x + ctx.text_measure_proc(last_line, v.style), line_position_y},
									{1, v.style.font_size},
									rl.GREEN,
								)
							} else {
								rl.DrawRectangleV({v.position.x, line_position_y}, {1, v.style.font_size}, rl.GREEN)
							}
						}
					}
				}

				if cursor.x != cursor.y {
					if cursor.x > cursor.y {
						cursor.x, cursor.y = cursor.y, cursor.x
					}

					line_x: int
					line_y: int
					relative_x: int
					relative_y: int
					total_length: int
					last_line: int
					for l, i in ctx.text_lines[v.start:v.end] {
						if cursor.x >= total_length && cursor.x < total_length + len(l) {
							line_x = i + v.start
							relative_x = cursor.x - total_length
						}
						if cursor.y >= total_length && cursor.y < total_length + len(l) {
							line_y = i + v.start
							relative_y = cursor.y - total_length
						}
						last_line = i + v.start
						total_length += len(l)
					}

					if cursor.x == total_length {
						if len(ctx.text_lines[last_line]) > 0 {
							if ctx.text_lines[last_line][max(len(ctx.text_lines[last_line]) - 1, 0)] != '\n' {
								line_x = last_line
								relative_x = len(ctx.text_lines[line_x])
							}
						}
					}
					if cursor.y == total_length {
						if len(ctx.text_lines[last_line]) > 0 {
							if ctx.text_lines[last_line][max(len(ctx.text_lines[last_line]) - 1, 0)] != '\n' {
								line_y = last_line
								relative_y = len(ctx.text_lines[line_y])
							}
						}
					}

					if line_x == line_y {
						rl.DrawRectangleV(
							{
								v.position.x + ctx.text_measure_proc(ctx.text_lines[line_x][:relative_x], v.style),
								v.position.y + f32(line_x - v.start) * (v.style.font_size + v.style.line_spacing),
							},
							{ctx.text_measure_proc(ctx.text_lines[line_x][relative_x:relative_y], v.style), v.style.font_size},
							rl.BLUE,
						)
					} else {
						rl.DrawRectangleV(
							{
								v.position.x + ctx.text_measure_proc(ctx.text_lines[line_x][:relative_x], v.style),
								v.position.y + f32(line_x - v.start) * (v.style.font_size + v.style.line_spacing),
							},
							{ctx.text_measure_proc(ctx.text_lines[line_x][relative_x:], v.style), v.style.font_size},
							rl.BLUE,
						)

						for i in line_x + 1 ..< line_y {
							rl.DrawRectangleV(
								{v.position.x, v.position.y + f32(i - v.start) * (v.style.font_size + v.style.line_spacing)},
								{ctx.text_measure_proc(ctx.text_lines[i], v.style), v.style.font_size},
								rl.BLUE,
							)
						}

						rl.DrawRectangleV(
							{v.position.x, v.position.y + f32(line_y - v.start) * (v.style.font_size + v.style.line_spacing)},
							{ctx.text_measure_proc(ctx.text_lines[line_y][:relative_y], v.style), v.style.font_size},
							rl.BLUE,
						)
					}
				}
			}

			line_y := v.position.y
			for l, i in ctx.text_lines[v.start:v.end] {
				rl.DrawTextEx(
					jet_brains_mono,
					fmt.ctprint(l),
					{v.position.x, line_y},
					v.style.font_size,
					v.style.letter_spacing,
					cast(rl.Color)v.style.color,
				)
				line_y += v.style.line_spacing + v.style.font_size
			}
		case cu.Command_Clip_End:
			rl.EndScissorMode()
		case cu.Command_Clip_Start:
			rl.BeginScissorMode(cast(i32)v.clip_position.x, cast(i32)v.clip_position.y, cast(i32)v.clip_size.x, cast(i32)v.clip_size.y)
		case cu.Command_Primitive:
			switch p in v {
			case cu.Primitive_Line:
				rl.DrawLineEx(p.start_position, p.end_position, p.thickness, cast(rl.Color)p.color)
			case cu.Primitive_Rect:
				switch p.fill {
				case .Line:
					rl.DrawRectangleLinesEx({p.position.x, p.position.y, p.size.x, p.size.y}, p.thickness, cast(rl.Color)p.color)
				case .Solid:
					rl.DrawRectangleV(p.position, p.size, cast(rl.Color)p.color)
				}
			case cu.Primitive_Points:
			case cu.Primitive_Ellipse:
				rl.DrawEllipse(cast(i32)p.position.x, cast(i32)p.position.y, p.size.x, p.size.y, cast(rl.Color)p.color)
			case cu.Primitive_Custom:
			}

		case cu.Command_Border:
			{
				pos := v.position
				size := v.size
				t := v.style.thickness
				c := v.style.color

				if t[0] > 0 {
					rl.DrawRectangleRec(rl.Rectangle{pos.x, pos.y, size.x, t[0]}, cast(rl.Color)c[0])
				}

				if t[1] > 0 {
					rl.DrawRectangleRec(rl.Rectangle{pos.x + size.x - t[1], pos.y, t[1], size.y}, cast(rl.Color)c[1])
				}

				if t[2] > 0 {
					rl.DrawRectangleRec(rl.Rectangle{pos.x, pos.y + size.y - t[2], size.x, t[2]}, cast(rl.Color)c[2])
				}

				if t[3] > 0 {
					rl.DrawRectangleRec(rl.Rectangle{pos.x, pos.y, t[3], size.y}, cast(rl.Color)c[3])
				}
			}
		case cu.Command_Image:
			image := cast(^rl.Texture)v.image_data
			rl.DrawTextureEx(image^, v.position, 0, v.size.x / cast(f32)image.width, cast(rl.Color)v.color)
		case cu.Command_Custom:
		}
	}
}

measure_text :: proc(text: string, config: cu.Text_Style) -> f32 {
	width: f32
	font := jet_brains_mono
	scale := config.font_size / f32(font.baseSize)
	for r in text {
		advance: f32
		glyph_index := rl.GetGlyphIndex(font, r)
		glyph := font.glyphs[glyph_index]

		if glyph.advanceX != 0 {
			advance = f32(glyph.advanceX) * scale + config.letter_spacing
		} else {
			advance = font.recs[glyph_index].width * scale + f32(glyph.offsetX) + config.letter_spacing
		}
		width += advance
	}
	return width
}
