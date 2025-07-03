package main

import "base:runtime"
import "core:reflect"

import "core:fmt"
import "core:time"
import rl "vendor:raylib"

import cu "./../"

WHITE :: cu.Color{255, 255, 255, 255}
BLACK :: cu.Color{0, 0, 0, 255}
RED :: cu.Color{255, 130, 100, 255}
ORANGE :: cu.Color{255, 180, 130, 255}
GREEN :: cu.Color{230, 255, 170, 255}
BLUE :: cu.Color{170, 230, 255, 255}
CHILD_BACKGROUND :: [4]u8{52, 52, 84, 255} // #2A2A40
DEFAULT_BACKGROUND :: [4]u8{20, 20, 36, 255} // #1E1E2E
HOVER_COLOR :: [4]u8{58, 58, 90, 255} // #3A3A5A
PRESS_COLOR :: [4]u8{136, 221, 255, 255} // #88DDFF
LONG_PRESS_COLOR :: [4]u8{255, 136, 170, 255} // #FF88AA

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
			rl.DrawRectangleV(v.position, v.size, cast(rl.Color)v.color)
		// size := v.size / 2
		// pos := v.position + size
		// rad := v.border_radius
		// color: [4]f32
		// for c, i in v.color {
		// 	color[i] = f32(c) / 255
		// }
		//
		// rl.BeginShaderMode(shader)
		// rl.SetShaderValue(shader, rect_center_loc, &pos, .VEC2)
		// rl.SetShaderValue(shader, rect_size_loc, &size, .VEC2)
		// rl.SetShaderValue(shader, border_radius_loc, &rad, .VEC4)
		// rl.SetShaderValue(shader, color_loc, &color, .VEC4)
		//
		// src := rl.Rectangle{0, 0, 1, 1}
		// dst := rl.Rectangle{v.position.x, v.position.y, v.size.x, v.size.y}
		//
		// rl.DrawTexturePro(texture, src, dst, {}, 0.0, rl.WHITE)
		// rl.EndShaderMode()
		case cu.Command_Text:
			initial_y := v.position.y

			for l in ctx.text_lines[v.start:v.end] {
				rl.DrawTextEx(
					rl.GetFontDefault(),
					fmt.ctprint(l),
					{v.position.x, initial_y},
					v.style.font_size,
					v.style.letter_spacing,
					cast(rl.Color)v.style.color,
				)
				initial_y += v.style.line_spacing + v.style.font_size
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
			}
		case cu.Command_Border:
			rl.DrawRectangleLinesEx({v.position.x, v.position.y, v.size.x, v.size.y}, v.thickness[0], cast(rl.Color)v.color[0])
		case cu.Command_Image:
			image := cast(^rl.Texture)v.image_data
			fmt.println(image)
			rl.DrawTextureEx(image^, v.position, 0, v.size.x / cast(f32)image.width, rl.WHITE)
		}
	}
}

measure_text :: proc(text: string, config: cu.Text_Style) -> f32 {
	width: f32
	font := rl.GetFontDefault()
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
