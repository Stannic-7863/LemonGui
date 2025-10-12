package core_ui

Animate_Prop :: enum u8 {
	Position,
	Size,
	Color,
}

Animate_Props :: bit_set[Animate_Prop]

Animate_Props_Data :: struct($T: typeid) {
	start, end:        T,
	duration, elapsed: f32,
}

Animate_Persistant_Data :: struct {
	position, size: Animate_Props_Data(Vec2f32),
	color:          Animate_Props_Data(Vec4f32),
}

_resolve_widget_animation :: proc(ctx: ^Core_Context, widget: ^Widget) {
	if widget.animate_props != {} {
		if widget.key.hash not_in ctx.persistant.animate {
			widget_style := ctx.styles[widget.style]
			ctx.persistant.animate[widget.key.hash] = Animate_Persistant_Data {
				position = {duration = 1, start = widget.rect.position, end = widget.rect.position},
				size = {duration = 1, end = widget.rect.size},
				color = {duration = 1, end = widget_style.color},
			}
		} else {
			widget_style := ctx.styles[widget.style]
			animate_data := &ctx.persistant.animate[widget.key.hash]

			for prop in widget.animate_props {
				switch prop {
				case .Position:
					animate_data.position.elapsed += ctx.frametime
					animate_data.position.elapsed = min(animate_data.position.duration, animate_data.position.elapsed)

					if animate_data.position.end != widget.rect.position {
						animate_data.position.start = animate_data.position.end
						animate_data.position.end = widget.rect.position
						animate_data.position.elapsed = 0
					}

					widget.rect.position = _lerp_vec2f32(animate_data.position.start, animate_data.position.end, animate_data.position.elapsed)
				case .Size:
					if animate_data.size.end != widget.rect.size {
						animate_data.size.start = animate_data.size.end
						animate_data.size.end = widget.rect.size
						animate_data.size.elapsed = 0
					}

					animate_data.size.elapsed += ctx.frametime
					animate_data.size.elapsed = min(animate_data.size.duration, animate_data.size.elapsed)
					widget.rect.size = _lerp_vec2f32(animate_data.size.start, animate_data.size.end, animate_data.size.elapsed)
					widget.rect.position += animate_data.size.end / 2
					widget.rect.position -= widget.rect.size / 2
				case .Color:
				}
			}
		}
	}
}

_lerp_vec2f32 :: proc(a, b: Vec2f32, t: f32) -> Vec2f32 {
	return a + (b - a) * t
}

_lerp_vec4f32 :: proc(a, b: Vec4f32, t: f32) -> Vec4f32 {
	return a + (b - a) * t
}
