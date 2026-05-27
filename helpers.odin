package core_ui

import "core:math/linalg"
import "core:time"

clip :: proc "contextless" (info_x, info_y: Clip_Info, hash: Hash = 0) -> Clip {
	return Clip{info = {info_x, info_y}, hash = hash}
}

clip_custom :: proc "contextless" (value: f32, scale: f32, min: f32 = min(f32), max: f32 = max(f32)) -> Clip_Info {
	return {kind = .Custom, max = max, min = min, scale = scale, value = value}
}

clip_auto :: proc "contextless" (scale: f32, min: f32 = min(f32), max: f32 = max(f32)) -> Clip_Info {
	return {kind = .Auto, max = max, min = min, scale = scale}
}

override :: proc "contextless" (offset: [2]Override_Transform, expand: [2]Override_Transform) -> Override {
	return {offset = offset, expand = expand}
}

flags :: proc "contextless" (x: Layout_Flags = {}, y: Layout_Flags = {}) -> [Axis]Layout_Flags {
	return {.X = x, .Y = y}
}

expand :: proc "contextless" (x: Override_Transform = nil, y: Override_Transform = nil) -> [Axis]Override_Transform {
	return {.X = x, .Y = y}
}

offset :: proc "contextless" (x: Override_Transform = nil, y: Override_Transform = nil) -> [Axis]Override_Transform {
	return {.X = x, .Y = y}
}

text :: proc "contextless" (text: string, wrap_mode: Text_Wrap_Mode = .Words, preferred_min: f32 = 0, preferred_max: f32 = max(f32)) -> Text {
	return Text{text = text, preferred_min = preferred_min, preferred_max = preferred_max, wrap_mode = wrap_mode}
}

layout :: proc "contextless" (sizing: [2]Sizing, placement: [2]Placement = {}, child_gap: f32 = 0, direction: Axis = .X) -> Layout {
	return {sizing = sizing, placement = placement, direction = direction, child_gap = child_gap}
}

sizing :: proc "contextless" (x: Sizing = Fit{0, max(f32)}, y: Sizing = Fit{0, max(f32)}) -> [2]Sizing {
	return {x, y}
}

alignment :: proc "contextless" (x: Align = .Negative, y: Align = .Negative) -> [2]Align {
	return {x, y}
}

ratio :: proc "contextless" (value: f32) -> Sizing {
	return Ratio{value = value}
}

fit :: proc "contextless" (min: f32 = 0, max: f32 = max(f32)) -> Fit {
	return Fit{min = min, max = max}
}

grow :: proc "contextless" (min: f32 = 0, max: f32 = max(f32)) -> Grow {
	return Grow{min = min, max = max}
}

percent :: proc "contextless" (value: f32 = 0) -> Percent {
	return Percent{value = value}
}

percent_self :: proc "contextless" (value: f32 = 1) -> Percent_Self {
	return Percent_Self{value = value}
}

fixed :: proc "contextless" (value: f32 = 0) -> Fixed {
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
	selection_background: Color = 0,
	selection_border: Border_Style = {}
) -> Text_Style {
	return {color = color, selection_background = selection_background, selection_border = selection_border, font_size = font_size, letter_spacing = letter_spacing, line_spacing = line_spacing, font = font, font_name = font_name, font_id = font_id}
}

style :: proc "contextless" (color: Color = 0, image_tint: Color = 255, border: Border_Style = {}, text: Text_Style = {}, rect_custom: rawptr = nil) -> Style {
	return {color = color, border = border, text = text, image_tint = image_tint, rect_custom = rect_custom}
}

border :: proc "contextless" (color: [4]Color = 0, radius: Vec4f32 = 0, thickness: [2]Vec2f32 = {}) -> Border_Style {
	return {color = color, radius = radius, thickness = thickness}
}

axis_from_2vec2f32 :: proc "contextless" (x: Vec2f32 = 0, y: Vec2f32 = 0) -> [2]Vec2f32 {
	return {x, y}
}

axis_from_vec4f32 :: proc "contextless" (vec4: Vec4f32) -> [2]Vec2f32 {
	return {{vec4[3], vec4[1]}, {vec4[0], vec4[2]}}
}

vec4f32_from_axis :: proc "contextless" (vec: [2]Vec2f32) -> Vec4f32 {
	return {vec.y.x, vec.x.y, vec.y.y, vec.x.x}
}

color_from_hex :: proc "contextless" (hex: u32) -> Color {
    return {
        f32((hex >> 24) & 0xFF),
        f32((hex >> 16) & 0xFF),
        f32((hex >>  8) & 0xFF),
        f32((hex      ) & 0xFF),
    }
}

selection :: proc (hash: Hash) -> Text_Selection {
	return {hash = hash}
}

set_selection_anchor :: proc (ctx: ^Core_Context, index: Selection_Index, anchor: i32) {
	selection := get_selection(ctx, index)
	selection.anchor = anchor
}

set_selection_cursor :: proc (ctx: ^Core_Context, index: Selection_Index, cursor: i32) {
	selection := get_selection(ctx, index)
	selection.cursor = cursor
}

set_selection :: proc (ctx: ^Core_Context, index: Selection_Index, anchor, cursor: i32) {
	selection := get_selection(ctx, index)
	selection.anchor = anchor
	selection.cursor = cursor
}

is_mouse_pressed :: proc(ctx: ^Core_Context, button: Mouse_Button) -> bool {
	return .Pressed in ctx.mouse.mapped_events[button]
}

is_mouse_down :: proc(ctx: ^Core_Context, button: Mouse_Button) -> bool {
	return .Down in ctx.mouse.mapped_events[button]
}

is_mouse_released :: proc(ctx: ^Core_Context, button: Mouse_Button) -> bool {
	return .Released in ctx.mouse.mapped_events[button]
}

is_widget_hovered :: proc(ctx: ^Core_Context, info: Widget_Info) -> bool {
	return info.hash == ctx.mouse.hovered
}

is_widget_active :: proc(ctx: ^Core_Context, info: Widget_Info) -> bool {
	return info.hash == ctx.mouse.active
}

get_widget_mouse_events_all :: proc(ctx: ^Core_Context, info: Widget_Info) -> Mouse_Events {
	if is_widget_active(ctx, info) {
		return ctx.mouse.events
	}
	return {}
}

get_widget_mouse_events :: proc(ctx: ^Core_Context, info: Widget_Info, button: Mouse_Button) -> bit_set[Widget_Key_Event] {
	return get_widget_mouse_events_all(ctx, info)[button]
}

is_widget_on_screen :: proc(ctx: ^Core_Context, widget: ^Widget) -> bool {
	p := widget.rect.position
	return !(p.x + widget.rect.size.x < 0 || p.y + widget.rect.size.y < 0 || p.x > ctx.window_size.x || p.y > ctx.window_size.y)
}

is_point_in_rect :: proc(rect: Rect, point: Vec2f32, border_style: Border_Style) -> bool {
	border_radius := border_style.radius.zywx

	comp := min(rect.size.x, rect.size.y) / 2
	for &r in border_radius {
		r = min(comp, r)
	}

	half_size := rect.size / 2
	rel_pos := point - (rect.position + half_size)

	border_radius.xy = rel_pos.x > 0 ? border_radius.xy : border_radius.zw
	border_radius.x = rel_pos.y > 0 ? border_radius.x : border_radius.y

	p := [2]f32{abs(rel_pos.x), abs(rel_pos.y)} - half_size + border_radius.x

	dist := linalg.length(linalg.max(p, 0.0)) + min(max(p.x, p.y), 0.0) - border_radius.x

	if dist < 0 {
		return true
	}
	return false
}

create_clip :: proc(ctx: ^Core_Context, clip: Clip) -> Clip_Index {
	clip_index := Clip_Index(len(ctx.clips))
	clip := clip

	if clip.hash != 0 {
		persistant_clip := ctx.persistent.clips[clip.hash]
		for clip_kind, axis in clip.info {
			if clip_kind.kind == .Auto {
				clip.info[axis].value = persistant_clip[axis]
			}
		}
	}

	append(&ctx.clips, clip)
	return clip_index
}

create_selection :: proc(ctx: ^Core_Context, selection: Text_Selection) -> Selection_Index {
	selection_index := Selection_Index(len(ctx.selections))
	selection := selection

	if selection.hash != 0 {
		persistant_selection := ctx.persistent.selections[selection.hash]
		selection.anchor = persistant_selection.anchor
		selection.cursor = persistant_selection.cursor
	}

	append(&ctx.selections, selection)
	return selection_index
}

create_style :: proc(ctx: ^Core_Context, style: Style) -> Style_Index {
	append(&ctx.styles, style)
	return Style_Index(len(ctx.styles) - 1)
}

create_animation :: proc(ctx: ^Core_Context, hooks: Animation_Hooks = ANIM_ALL, duration: time.Duration = time.Second, delay: time.Duration = 0) -> Animation_Index {
	append(&ctx.anims, Animation{hooks = hooks, delay = delay, duration = duration})
	return Animation_Index(len(ctx.anims) - 1)
}

create_override :: proc(ctx: ^Core_Context, overrides: ..Override) -> Override_Range {
	start := cast(i32)len(ctx.overrides)
	for o in overrides {
		append(&ctx.overrides, o)
	}
	return Override_Range{start = start, end = cast(i32)len(ctx.overrides)}
}

create_text :: proc(ctx: ^Core_Context, text: Text) -> Text_Index {
	text_index := Text_Index(len(ctx.text))
	append(&ctx.text, text)
	return text_index
}

get_animation :: #force_inline proc(ctx: ^Core_Context, index: Animation_Index) -> ^Animation #no_bounds_check {
	return &ctx.anims[index]
}

get_clip :: #force_inline proc(ctx: ^Core_Context, index: Clip_Index) -> ^Clip #no_bounds_check {
	return &ctx.clips[index]
}

get_selection :: #force_inline proc(ctx: ^Core_Context, index: Selection_Index) -> ^Text_Selection #no_bounds_check {
	return &ctx.selections[index]
}

get_style :: #force_inline proc(ctx: ^Core_Context, index: Style_Index) -> ^Style #no_bounds_check {
	return &ctx.styles[index]
}

get_widget :: #force_inline proc(ctx: ^Core_Context, index: Widget_Index) -> ^Widget #no_bounds_check {
	return &ctx.widgets[index]
}

get_override :: #force_inline proc(ctx: ^Core_Context, range: Override_Range) -> []Override #no_bounds_check {
	return ctx.overrides[range.start:range.end]
}

get_text :: #force_inline proc(ctx: ^Core_Context, index: Text_Index) -> ^Text #no_bounds_check {
	return &ctx.text[index]
}

copy_style :: proc(ctx: ^Core_Context, style: Style_Index) -> Style_Index {
	append(&ctx.styles, ctx.styles[style])
	return Style_Index(len(ctx.styles) - 1)
}

sort_render_commands :: proc(commands: []Render_Command) #no_bounds_check {
	commands := commands
	length := len(commands)
	if length < 2 {
		return
	}

	p := commands[length / 2]
	i, j := 0, length - 1

	loop: for {
		for (commands[i].z - p.z) < 0 {i += 1}
		for (p.z - commands[j].z) < 0 {j -= 1}

		if i >= j {
			break loop
		}

		commands[i], commands[j] = commands[j], commands[i]
		i += 1
		j -= 1
	}

	sort_render_commands(commands[0:i])
	sort_render_commands(commands[i:length])
}

_get_override_transform_value :: proc(transform: [2]Override_Transform, widget_size: Vec2f32, parent_size: Vec2f32, axis: Axis) -> (offset_value: f32) #no_bounds_check {
	switch kind in transform[axis] {
	case Percent_Self:
		offset_value = widget_size[axis] * kind.value
	case Percent:
		offset_value = parent_size[axis] * kind.value
	case Fixed:
		offset_value = kind.value
	}
	return offset_value
}

get_clip_value :: proc(ctx: ^Core_Context, clip_index: Clip_Index, axis: Axis) -> f32 #no_bounds_check {
	clip := &ctx.clips[clip_index]
	return clip.info[axis].value
}

_get_other_axis :: proc(axis: Axis) -> Axis {
	return .X if axis == .Y else .Y
}

_get_axis_spacing :: proc(axis: Axis, padding: [2]Vec2f32) -> f32 #no_bounds_check {
	return padding[axis].x + padding[axis].y
}

_get_child_gap :: proc(widget: ^Widget, axis: Axis) -> f32 {
	return max(0, f32(widget.total_children - 1 - widget.detached_children[axis])) * widget.form.layout.child_gap
}

_clamp_border_radius :: proc(widget: ^Widget, style: ^Style) {
	comp := min(widget.rect.size.x, widget.rect.size.y)
	for &r in style.border.radius {
		r = min(comp / 2, r)
	}
}
