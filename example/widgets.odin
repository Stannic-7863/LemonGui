package main

import cu "../"
import "core:fmt"
import rl "vendor:raylib"

Image :: struct {
	w, h: f32,
	data: rawptr,
}

build_ui :: proc(ctx: ^cu.Core_Context, tick_image: Image, aaloo_image: Image, font: rawptr, width, height: f32) {
	root := cu.create_widget(
		ctx,
		"Root",
		cu.layout(cu.sizing(cu.fixed(width), cu.fixed(height)), {}, 16),
		style = {padding = cu.axis_vec2f32(32, 32), color = BACKGROUND_COLOR},
	)

	cu.push_parent(ctx, root)
	grow_1 := cu.create_widget(ctx, "child 1", cu.layout(cu.sizing(cu.grow(), cu.grow())), {}, {.Lock_Active, .Lock_Hover}, style = cu.style(SURFACE_COLOR))

	cu.push_parent(ctx, grow_1)

	grow_1_child := cu.create_widget(
		ctx,
		"e",
		cu.layout(cu.sizing(cu.grow(), cu.fixed(50)), cu.alignment(.Center, .Center)),
		style = cu.style(ELEVATED_SURFACE_COLOR),
	)

	cu.push_parent(ctx, grow_1_child)

	cu.create_widget(
		ctx,
		"f",
		cu.layout(cu.sizing(cu.fixed(25), cu.fixed(25))),
		override = cu.override(cu.flags(), cu.offset(cu.percent(0.5)), cu.expand()),
		style = cu.style(WARNING_COLOR),
	)

	cu.pop_parent(ctx)

	cu.pop_parent(ctx)

	grow_2 := cu.create_widget(ctx, "child 2", cu.layout(cu.sizing(cu.grow(), cu.grow())), style = cu.style(SURFACE_COLOR))
	grow_3 := cu.create_widget(
		ctx,
		"child 3",
		cu.layout(cu.sizing(cu.grow(), cu.grow())),
		clip = cu.clip(cu.clip_none(), cu.clip_auto(5)),
		style = cu.style(SURFACE_COLOR, cu.axis_vec2f32(16, 16)),
	)

	cu.push_parent(ctx, grow_3)

	body := cu.create_widget(ctx, "body", cu.layout(cu.sizing(cu.grow(), cu.fit())), style = cu.style(ERROR_COLOR, cu.axis_vec2f32(8, 8)))

	cu.push_parent(ctx, body)

	thumb_rail := cu.create_widget(
		ctx,
		"grow fixed",
		cu.layout(cu.sizing(cu.grow(), cu.fixed(8)), cu.alignment(.Center, .Center)),
		style = cu.style(ELEVATED_SURFACE_COLOR),
	)

	cu.push_parent(ctx, thumb_rail)

	maximum: f32 = 10
	minimum: f32 = 0
	@(static) value: f32

	thumb_along := (f32(value) / f32(maximum - minimum)) - minimum - 0.5

	thumb := cu.create_widget(
		ctx,
		"slider thumb",
		cu.layout(cu.sizing(cu.fixed(12), cu.fixed(12))),
		override = cu.override(cu.flags({.No_Size_Propagation}, {.No_Size_Propagation}), cu.offset(cu.Percent{thumb_along}), cu.expand()),
		event_flags = {.Lock_Active, .Lock_Hover},
		style = cu.style(SUCCESS_COLOR),
	)

	cu.create_widget(
		ctx,
		"slider value label",
		cu.text(fmt.tprintf("%v", value), cu.text_style(TEXT_PRIMARY_COLOR, 20, 1, 0, font)),
		cu.override(
			cu.flags({.No_Size_Propagation, .No_Positioning}, {.No_Size_Propagation, .No_Positioning}),
			cu.offset(cu.fixed(thumb.resolved_rect.position.x), cu.fixed(thumb.resolved_rect.position.y + thumb.resolved_rect.size.x + 8)),
			cu.expand(),
		),
	)

	if cu.is_widget_active(ctx, thumb) {
		thumb.style.color = WARNING_COLOR
		local_position_x := ctx.mouse.position.x - thumb_rail.resolved_rect.position.x
		local_position_x /= thumb_rail.resolved_rect.size.x
		value = f32(minimum) + f32(maximum - minimum) * local_position_x
		value = max(minimum, value)
		value = min(maximum, value)
	}

	cu.pop_parent(ctx)
	cu.pop_parent(ctx)

	cu.pop_parent(ctx)

	cu.pop_parent(ctx)
}
