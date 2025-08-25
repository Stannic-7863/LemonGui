package backend_raylib

import ui "../../../"
import "core:fmt"
import rl "vendor:raylib"

render :: proc(ctx: ui.Core_Context) {
	for command in ctx.render_commands {
		switch command_kind in command.kind {
		case ui.Command_Rect:
			rl.DrawRectangleV(command_kind.rect.position, command_kind.rect.size, color_to_rl(command_kind.color))
		case ui.Command_Text:
			line_y := command_kind.rect.position.y
			font := (cast(^rl.Font)command_kind.style.font)^
			for l, i in command_kind.lines {
				rl.DrawTextEx(
					font,
					fmt.ctprint(l),
					{command_kind.rect.position.x, line_y},
					command_kind.style.font_size,
					command_kind.style.letter_spacing,
					color_to_rl(command_kind.style.color),
				)
				line_y += command_kind.style.line_spacing + command_kind.style.font_size
			}
		case ui.Command_Clip_End:
			rl.EndScissorMode()
		case ui.Command_Clip_Start:
			rl.BeginScissorMode(
				cast(i32)command_kind.rect.position.x,
				cast(i32)command_kind.rect.position.y,
				cast(i32)command_kind.rect.size.x,
				cast(i32)command_kind.rect.size.y,
			)
		case ui.Command_Custom:
		case ui.Command_Border:
			{
				pos := command_kind.rect.position
				size := command_kind.rect.size
				t := command_kind.style.thickness
				c := command_kind.style.color

				if t[.Y][0] > 0 { 	// top
					rl.DrawRectangleRec(rl.Rectangle{pos.x, pos.y, size.x, t[.Y][0]}, color_to_rl(c[0]))
				}

				if t[.X][1] > 0 { 	// right
					rl.DrawRectangleRec(rl.Rectangle{pos.x + size.x - t[.X][1], pos.y, t[.X][1], size.y}, color_to_rl(c[1]))
				}

				if t[.Y][1] > 0 { 	// bottom
					rl.DrawRectangleRec(rl.Rectangle{pos.x, pos.y + size.y - t[.Y][1], size.x, t[.Y][1]}, color_to_rl(c[2]))
				}

				if t[.X][0] > 0 { 	// left
					rl.DrawRectangleRec(rl.Rectangle{pos.x, pos.y, t[.X][0], size.y}, color_to_rl(c[3]))
				}
			}
		case ui.Command_Image:
		// image := cast(^rl.Texture)command_kind.image_data
		// rl.DrawTextureEx(image^, command_kind.position, 0, command_kind.size.x / cast(f32)image.width, cast(rl.Color)command_kind.color)
		}
	}
}

color_to_rl :: proc(color: ui.Vec4f32) -> rl.Color {
	return {u8(color.r), u8(color.g), u8(color.b), u8(color.a)}
}

measure_text :: proc(text: string, config: ui.Text_Style) -> f32 {
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
			advance = font.recs[glyph_index].width * scale + f32(glyph.offsetX) + config.letter_spacing
		}
		width += advance
	}
	return width
}
