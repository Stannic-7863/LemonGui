package nanovg_backend

import cu "../../../"
import nvg "vendor:nanovg"
import nvg_gl "vendor:nanovg/gl"

render :: proc(nvg_ctx: ^nvg.Context, ui_ctx: ^cu.Core_Context) {
	for command in ui_ctx.render_commands {
		switch commmand_kind in command.kind {
		case cu.Command_Rect:
		case cu.Command_Text:
		case cu.Command_Image:
		case cu.Command_Border:
		case cu.Command_Custom:
		case cu.Command_Clip_End:
		case cu.Command_Primitive:
		case cu.Command_Clip_Start:
		}
	}
}

measure_text :: proc() {

}
