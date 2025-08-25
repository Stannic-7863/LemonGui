package core_ui

override :: proc(flags: [Axis]Override_Flags, offset: [Axis]Override_Transform, expand: [Axis]Override_Transform) -> [Axis]Override {
	return {.X = {flags = flags[.X], offset = offset[.X], expand = expand[.X]}, .Y = {flags = flags[.Y], offset = offset[.Y], expand = expand[.Y]}}
}

flags :: proc(x: Override_Flags = {}, y: Override_Flags = {}) -> [Axis]Override_Flags {
	return {.X = x, .Y = y}
}

expand :: proc(x: Override_Transform = nil, y: Override_Transform = nil) -> [Axis]Override_Transform {
	return {.X = x, .Y = y}
}

offset :: proc(x: Override_Transform = nil, y: Override_Transform = nil) -> [Axis]Override_Transform {
	return {.X = x, .Y = y}
}

text :: proc(text: string, style: Text_Style = {}, preferred_min: f32 = 0, preferred_max: f32 = max(f32)) -> Text {
	return Text{text = text, style = style, preferred_min = preferred_min, preferred_max = preferred_max}
}

layout :: proc(sizing: [Axis]Sizing, alignment: [Axis]Alignment = {}, child_gap: f32 = 0, direction: Axis = .X) -> Layout {
	return {sizing = sizing, alignment = alignment, direction = direction, child_gap = child_gap}
}

sizing :: proc(x: Sizing = Fit{0, max(f32)}, y: Sizing = Fit{0, max(f32)}) -> [Axis]Sizing {
	return {.X = x, .Y = y}
}

alignment :: proc(x: Alignment = .Negative, y: Alignment = .Negative) -> [Axis]Alignment {
	return {.X = x, .Y = y}
}

fit :: proc "contextless" (min: f32 = 0, max: f32 = max(f32)) -> Sizing {
	return Fit{min = min, max = max}
}

grow :: proc "contextless" (min: f32 = 0, max: f32 = max(f32)) -> Sizing {
	return Grow{min = min, max = max}
}

percent :: proc "contextless" (value: f32 = 1) -> Sizing {
	return Percent{value = value}
}

fixed :: proc "contextless" (value: f32) -> Sizing {
	return Fixed{value = value}
}

text_style :: proc "contextless" (
	color: Color = 0,
	font_size: f32 = 0,
	letter_spacing: f32 = 0,
	line_spacing: f32 = 0,
	font: rawptr = nil,
	font_name: string = "",
	font_id: int = 0,
) -> Text_Style {
	return {
		color = color,
		font_size = font_size,
		letter_spacing = letter_spacing,
		line_spacing = line_spacing,
		font = font,
		font_name = font_name,
		font_id = font_id,
	}
}

style :: proc "contextless" (color: Color = 0, padding: [Axis]Vec2f32 = {}, border: Border_Style = {}) -> Rect_Style {
	return {color = color, border = border, padding = padding}
}

border :: proc "contextless" (color: [4]Color = 0, radius: Vec4f32 = 0, thickness: [Axis]Vec2f32 = {}) -> Border_Style {
	return {color = color, radius = radius, thickness = thickness}
}

axis_vec2f32 :: proc "contextless" (x: Vec2f32 = 0, y: Vec2f32 = 0) -> [Axis]Vec2f32 {
	return {.X = x, .Y = y}
}

vec4f32_to_axis_vec2f32 :: proc "contextless" (padding: Vec4f32) -> [Axis]Vec2f32 {
	return {.X = {padding[3], padding[1]}, .Y = {padding[0], padding[2]}}
}
