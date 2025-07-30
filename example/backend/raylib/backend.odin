package backend_raylib

import cu "../../../"
import "core:fmt"
import rl "vendor:raylib"

render :: proc(ctx: cu.Core_Context) {

	for command in ctx.render_commands {
		switch command_kind in command.kind {
		case cu.Command_Rect:
			rl.DrawRectangleV(
				command_kind.position,
				command_kind.size,
				cast(rl.Color)command_kind.color,
			)
		case cu.Command_Text:
			if cursor, ok := command_kind.cursor.([2]int); ok {
				{
					total_length: int
					line_position_y := command_kind.position.y
					last_line: string
					for l, i in ctx.text_lines[command_kind.start:command_kind.end] {
						if cursor.x >= total_length && cursor.x < total_length + len(l) {
							relative := cursor.x - total_length
							rl.DrawRectangleV(
								{
									command_kind.position.x +
									ctx.text_measure_proc(l[:relative], command_kind.style),
									line_position_y,
								},
								{1, command_kind.style.font_size},
								rl.GREEN,
							)
							break
						}
						total_length += len(l)
						last_line = l
						line_position_y +=
							command_kind.style.line_spacing + command_kind.style.font_size
					}
					if cursor.x == total_length {
						if len(last_line) > 0 {
							if last_line[len(last_line) - 1] != '\n' {
								line_position_y -=
									command_kind.style.line_spacing + command_kind.style.font_size
								rl.DrawRectangleV(
									{
										command_kind.position.x +
										ctx.text_measure_proc(last_line, command_kind.style),
										line_position_y,
									},
									{1, command_kind.style.font_size},
									rl.GREEN,
								)
							} else {
								rl.DrawRectangleV(
									{command_kind.position.x, line_position_y},
									{1, command_kind.style.font_size},
									rl.GREEN,
								)
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
					for l, i in ctx.text_lines[command_kind.start:command_kind.end] {
						if cursor.x >= total_length && cursor.x < total_length + len(l) {
							line_x = i + command_kind.start
							relative_x = cursor.x - total_length
						}
						if cursor.y >= total_length && cursor.y < total_length + len(l) {
							line_y = i + command_kind.start
							relative_y = cursor.y - total_length
						}
						last_line = i + command_kind.start
						total_length += len(l)
					}

					if cursor.x == total_length {
						if len(ctx.text_lines[last_line]) > 0 {
							if ctx.text_lines[last_line][max(len(ctx.text_lines[last_line]) - 1, 0)] !=
							   '\n' {
								line_x = last_line
								relative_x = len(ctx.text_lines[line_x])
							}
						}
					}
					if cursor.y == total_length {
						if len(ctx.text_lines[last_line]) > 0 {
							if ctx.text_lines[last_line][max(len(ctx.text_lines[last_line]) - 1, 0)] !=
							   '\n' {
								line_y = last_line
								relative_y = len(ctx.text_lines[line_y])
							}
						}
					}

					if line_x == line_y {
						rl.DrawRectangleV(
							{
								command_kind.position.x +
								ctx.text_measure_proc(
									ctx.text_lines[line_x][:relative_x],
									command_kind.style,
								),
								command_kind.position.y +
								f32(line_x - command_kind.start) *
									(command_kind.style.font_size +
											command_kind.style.line_spacing),
							},
							{
								ctx.text_measure_proc(
									ctx.text_lines[line_x][relative_x:relative_y],
									command_kind.style,
								),
								command_kind.style.font_size,
							},
							rl.BLUE,
						)
					} else {
						rl.DrawRectangleV(
							{
								command_kind.position.x +
								ctx.text_measure_proc(
									ctx.text_lines[line_x][:relative_x],
									command_kind.style,
								),
								command_kind.position.y +
								f32(line_x - command_kind.start) *
									(command_kind.style.font_size +
											command_kind.style.line_spacing),
							},
							{
								ctx.text_measure_proc(
									ctx.text_lines[line_x][relative_x:],
									command_kind.style,
								),
								command_kind.style.font_size,
							},
							rl.BLUE,
						)

						for i in line_x + 1 ..< line_y {
							rl.DrawRectangleV(
								{
									command_kind.position.x,
									command_kind.position.y +
									f32(i - command_kind.start) *
										(command_kind.style.font_size +
												command_kind.style.line_spacing),
								},
								{
									ctx.text_measure_proc(ctx.text_lines[i], command_kind.style),
									command_kind.style.font_size,
								},
								rl.BLUE,
							)
						}

						rl.DrawRectangleV(
							{
								command_kind.position.x,
								command_kind.position.y +
								f32(line_y - command_kind.start) *
									(command_kind.style.font_size +
											command_kind.style.line_spacing),
							},
							{
								ctx.text_measure_proc(
									ctx.text_lines[line_y][:relative_y],
									command_kind.style,
								),
								command_kind.style.font_size,
							},
							rl.BLUE,
						)
					}
				}
			}

			line_y := command_kind.position.y
			font := (cast(^rl.Font)command_kind.style.font)^
			for l, i in ctx.text_lines[command_kind.start:command_kind.end] {
				rl.DrawTextEx(
					font,
					fmt.ctprint(l),
					{command_kind.position.x, line_y},
					command_kind.style.font_size,
					command_kind.style.letter_spacing,
					cast(rl.Color)command_kind.style.color,
				)
				line_y += command_kind.style.line_spacing + command_kind.style.font_size
			}
		case cu.Command_Clip_End:
			rl.EndScissorMode()
		case cu.Command_Clip_Start:
			rl.BeginScissorMode(
				cast(i32)command_kind.clip_position.x,
				cast(i32)command_kind.clip_position.y,
				cast(i32)command_kind.clip_size.x,
				cast(i32)command_kind.clip_size.y,
			)
		case cu.Command_Primitive:
			switch primitive_kind in command_kind {
			case cu.Primitive_Line:
				rl.DrawLineEx(
					primitive_kind.start_position,
					primitive_kind.end_position,
					primitive_kind.thickness,
					cast(rl.Color)primitive_kind.color,
				)
			case cu.Primitive_Rect:
				switch primitive_kind.fill {
				case .Line:
					rl.DrawRectangleLinesEx(
						{
							primitive_kind.position.x,
							primitive_kind.position.y,
							primitive_kind.size.x,
							primitive_kind.size.y,
						},
						primitive_kind.thickness,
						cast(rl.Color)primitive_kind.color,
					)
				case .Solid:
					rl.DrawRectangleV(
						primitive_kind.position,
						primitive_kind.size,
						cast(rl.Color)primitive_kind.color,
					)
				}
			case cu.Primitive_Points:
			case cu.Primitive_Ellipse:
				rl.DrawEllipse(
					cast(i32)primitive_kind.position.x,
					cast(i32)primitive_kind.position.y,
					primitive_kind.size.x,
					primitive_kind.size.y,
					cast(rl.Color)primitive_kind.color,
				)
			case cu.Primitive_Custom:
			}

		case cu.Command_Border:
			{
				pos := command_kind.position
				size := command_kind.size
				t := command_kind.style.thickness
				c := command_kind.style.color

				if t[0] > 0 {
					rl.DrawRectangleRec(
						rl.Rectangle{pos.x, pos.y, size.x, t[0]},
						cast(rl.Color)c[0],
					)
				}

				if t[1] > 0 {
					rl.DrawRectangleRec(
						rl.Rectangle{pos.x + size.x - t[1], pos.y, t[1], size.y},
						cast(rl.Color)c[1],
					)
				}

				if t[2] > 0 {
					rl.DrawRectangleRec(
						rl.Rectangle{pos.x, pos.y + size.y - t[2], size.x, t[2]},
						cast(rl.Color)c[2],
					)
				}

				if t[3] > 0 {
					rl.DrawRectangleRec(
						rl.Rectangle{pos.x, pos.y, t[3], size.y},
						cast(rl.Color)c[3],
					)
				}
			}
		case cu.Command_Image:
			image := cast(^rl.Texture)command_kind.image_data
			rl.DrawTextureEx(
				image^,
				command_kind.position,
				0,
				command_kind.size.x / cast(f32)image.width,
				cast(rl.Color)command_kind.color,
			)
		case cu.Command_Custom:
		}
	}
}

measure_text :: proc(text: string, config: cu.Text_Style) -> f32 {
	width: f32
	font := (cast(^rl.Font)config.font)^
	scale := config.font_size / f32(font.baseSize)
	for r in text {
		advance: f32
		glyph_index := rl.GetGlyphIndex(font, r)
		glyph := font.glyphs[glyph_index]

		if glyph.advanceX != 0 {
			advance = f32(glyph.advanceX) * scale + config.letter_spacing
		} else {
			advance =
				font.recs[glyph_index].width * scale + f32(glyph.offsetX) + config.letter_spacing
		}
		width += advance
	}
	return width
}
