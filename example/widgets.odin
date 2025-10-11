package main

import cu "../"
import "core:fmt"

Image :: struct {
	w, h: f32,
	data: rawptr,
}

build_ui :: proc(ctx: ^cu.Core_Context, tick_image: Image, aaloo_image: Image, font: rawptr, width, height: f32) {
	style_basic := cu.create_style(
		ctx,
		{padding = cu.axis_vec2f32(16, 16), color = BACKGROUND_COLOR, border = cu.border(BORDER_COLOR, 0, cu.axis_vec2f32(2, 2))},
	)
	style_scroll := cu.create_style(ctx, {color = SUCCESS_COLOR})
	style_elevated := cu.create_style(
		ctx,
		{padding = cu.axis_vec2f32(8, 8), color = ELEVATED_SURFACE_COLOR, border = cu.border(BORDER_COLOR, 0, cu.axis_vec2f32(2, 2))},
	)
	text_style := cu.create_style(
		ctx,
		{
			padding = cu.axis_vec2f32(16, 16),
			border = cu.border(BORDER_COLOR, 0, cu.axis_vec2f32(2, 2)),
			text = {color = TEXT_PRIMARY_COLOR, font = font, font_size = 16, letter_spacing = 2, line_spacing = 0},
		},
	)
	text_style_no_pad := cu.create_style(
		ctx,
		{
			border = cu.border(BORDER_COLOR, 0, cu.axis_vec2f32(2, 2)),
			text = {color = TEXT_PRIMARY_COLOR, font = font, font_size = 16, letter_spacing = 2, line_spacing = 0},
		},
	)


	root := cu.create_widget(ctx, "Root", cu.layout(cu.sizing(cu.fixed(width), cu.fixed(height)), {}, 16))
	root.style = style_basic

	cu.push_parent(ctx, root)
	grow_1 := cu.create_widget(
		ctx,
		"grow scrollable container",
		cu.layout(cu.sizing(cu.grow(), cu.grow()), child_gap = 8, direction = .Y),
		event_flags = {.Lock_Active, .Lock_Hover},
	)


	grow_1.clip = cu.create_clip(ctx, cu.clip(cu.clip_none(), cu.clip_auto(50, 0, (grow_1.resolved.content_size.y - grow_1.resolved.size.y)), 1))
	grow_1.style = style_basic
	cu.push_parent(ctx, grow_1)

	grow_1_clip := cu.get_clip(ctx, grow_1.clip)
	scroll_bar_size := (grow_1.resolved.size.y / grow_1.resolved.content_size.y) * grow_1.resolved.size.y
	scroll_bar_progress := (grow_1_clip.value[.Y]) / grow_1.resolved.content_size.y
	scroll_bar := cu.create_widget(ctx, "scroll bar", cu.layout(cu.sizing(cu.fixed(10), cu.fixed(scroll_bar_size))), style = style_scroll)

	scroll_bar.override = cu.create_override(
		ctx,
		cu.override(
			cu.flags(
				{.No_Size_Propagation, .No_Positioning_Relative, .No_Clip_Offset},
				{.No_Size_Propagation, .No_Positioning_Relative, .No_Clip_Offset},
			),
			cu.offset(cu.fixed(grow_1.resolved.size.x - 10), cu.percent(scroll_bar_progress)),
			cu.expand(),
		),
	)

	for i in 0 ..< 5 {
		w := cu.create_widget(ctx, i, cu.layout(cu.sizing(cu.grow(), cu.percent(0.5))), event_flags = {.Lock_Hover}, style = style_elevated)
		if i == 0 do fmt.println(cu.get_widget_mouse_events(ctx, w, .Left))
		if cu.is_widget_hovered(ctx, w) {
			style_index := cu.copy_style(ctx, w.style)
			style := cu.get_style(ctx, style_index)
			w.style = style_index
			style.color = WARNING_COLOR
			style.border.thickness = cu.axis_vec2f32(1, 1)
		}
	}

	cu.pop_parent(ctx)

	// grow_2 := cu.create_widget(ctx, "child 2", cu.layout(cu.sizing(cu.grow(), cu.grow())), style = style_basic)
	// grow_3 := cu.create_widget(ctx, "child 3", cu.layout(cu.sizing(cu.grow(), cu.grow()), direction = .Y), style = style_basic)
	//
	// cu.push_parent(ctx, grow_3)
	//
	//
	// cu.create_widget(ctx, "text", cu.text("A QUICK BROWN FOX JUMPS OVER THE LAZY DOG"), style = text_style)
	//
	// body := cu.create_widget(ctx, "body", cu.layout(cu.sizing(cu.grow(), cu.fit())), style = style_basic)
	//
	// cu.push_parent(ctx, body)
	//
	// thumb_rail := cu.create_widget(
	// 	ctx,
	// 	"grow fixed",
	// 	cu.layout(cu.sizing(cu.grow(), cu.fixed(8)), cu.alignment(.Center, .Center), direction = .Y),
	// 	style = style_elevated,
	// )
	//
	// cu.push_parent(ctx, thumb_rail)
	//
	// maximum: f32 = 10
	// minimum: f32 = 5
	// @(static) value: f32
	//
	// thumb_along := (value - minimum) / (maximum - minimum) - 0.5
	//
	// thumb := cu.create_widget(
	// 	ctx,
	// 	"slider thumb",
	// 	cu.layout(cu.sizing(cu.fixed(12), cu.fixed(12))),
	// 	event_flags = {.Lock_Active, .Lock_Hover},
	// 	style = style_scroll,
	// )
	//
	// thumb.override = cu.create_override(
	// 	ctx,
	// 	cu.override(cu.flags({.No_Size_Propagation}, {.No_Size_Propagation}), cu.offset(cu.Percent{thumb_along}), cu.expand()),
	// )
	//
	// label := cu.create_widget(ctx, "slider value label", cu.text(fmt.tprintf("%v", value), .None), style = text_style_no_pad)
	// label.override = cu.create_override(
	// 	ctx,
	// 	cu.override(
	// 		cu.flags({.No_Size_Propagation}, {.No_Size_Propagation, .No_Positioning}),
	// 		cu.offset(cu.percent(thumb_along), cu.fixed(thumb.resolved.position.y + thumb.resolved.size.x + 8)),
	// 		cu.expand(),
	// 	),
	// )
	//
	// if cu.is_widget_active(ctx, thumb) {
	// 	thumb_style := cu.get_style(ctx, thumb.style)
	// 	thumb_style.color = WARNING_COLOR
	// 	local_position_x := ctx.mouse.position.x - thumb_rail.resolved.position.x
	// 	local_position_x /= thumb_rail.resolved.size.x
	// 	value = f32(minimum) + f32(maximum - minimum) * local_position_x
	// }
	// value = max(minimum, value)
	// value = min(maximum, value)
	//
	// cu.pop_parent(ctx)
	//
	// cu.pop_parent(ctx)
	//
	// cu.pop_parent(ctx)

	cu.pop_parent(ctx)
}
