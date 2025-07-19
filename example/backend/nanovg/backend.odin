package nanovg_backend

import cu "../../../"
import "core:fmt"
import nvg "vendor:nanovg"
import nvg_gl "vendor:nanovg/gl"

render :: proc(nvg_ctx: ^nvg.Context, ui_ctx: ^cu.Core_Context) {
	for command in ui_ctx.render_commands {
		switch commmand_kind in command.kind {
		case cu.Command_Rect:
			position := commmand_kind.position
			size := commmand_kind.size
			color := commmand_kind.color
			border := commmand_kind.border_radius

			if size.x == 0 || size.y == 0 {
				break
			}

			nvg.BeginPath(nvg_ctx)
			nvg.FillColor(nvg_ctx, nvg.RGBA(color.r, color.g, color.b, color.a))
			nvg.RoundedRectVarying(nvg_ctx, position.x, position.y, size.x, size.y, border.x, border.y, border.z, border.w)
			nvg.Fill(nvg_ctx)
		case cu.Command_Text:
			position := commmand_kind.position
			style := commmand_kind.style
			color := style.color

			nvg.FillColor(nvg_ctx, nvg.RGBA(color.r, color.g, color.b, color.a))
			nvg.FontSize(nvg_ctx, style.font_size)
			nvg.TextLetterSpacing(nvg_ctx, style.letter_spacing)

			for l in ui_ctx.text_lines[commmand_kind.start:commmand_kind.end] {
				nvg.BeginPath(nvg_ctx)
				nvg.TextAlignVertical(nvg_ctx, .TOP)
				nvg.Text(nvg_ctx, position.x, position.y, l)
				nvg.Fill(nvg_ctx)
				position.y += style.line_spacing + style.font_size
			}

		case cu.Command_Image:
			image: int = (cast(^int)commmand_kind.image_data)^
			position := commmand_kind.position
			size := commmand_kind.size
			color := commmand_kind.color
			paint := nvg.ImagePattern(position.x, position.y, size.x, size.y, 0, image, 1)
			nvg.BeginPath(nvg_ctx)
			nvg.Rect(nvg_ctx, position.x, position.y, size.x, size.y)
			nvg.FillPaint(nvg_ctx, paint)
			nvg.Fill(nvg_ctx)
		case cu.Command_Border:
			position := commmand_kind.position
			size := commmand_kind.size
			color := commmand_kind.style.color[0]
			thickness := commmand_kind.style.thickness[0]
			radius := commmand_kind.style.radius

			if size.x == 0 || size.y == 0 {
				break
			}
			nvg.BeginPath(nvg_ctx)
			nvg.StrokeColor(nvg_ctx, nvg.RGBA(color.r, color.g, color.b, color.a))
			nvg.StrokeWidth(nvg_ctx, thickness)
			nvg.RoundedRectVarying(nvg_ctx, position.x, position.y, size.x, size.y, radius.x, radius.y, radius.z, radius.w)
			nvg.Stroke(nvg_ctx)

		case cu.Command_Custom:
		case cu.Command_Primitive:

		case cu.Command_Clip_End:
		case cu.Command_Clip_Start:
		}
	}
}

measure_text :: proc(text: string, style: cu.Text_Style) -> f32 {
	nvg_context := cast(^nvg.Context)style.font

	bounds: [4]f32
	nvg.FontSize(nvg_context, style.font_size)
	nvg.TextLetterSpacing(nvg_context, style.letter_spacing)
	advance := nvg.TextBounds(nvg_context, 0, 0, text, &bounds)

	size := bounds[2] - bounds[0]
	return size
}
