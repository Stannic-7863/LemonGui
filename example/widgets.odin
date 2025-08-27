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
	events := cu.get_widget_mouse_events(ctx, grow_1, .Left)
	if .Clicked in events {
		fmt.println("Boom")
	}
	cu.create_widget(ctx, "child 2", cu.layout(cu.sizing(cu.grow(), cu.grow())), style = cu.style(SURFACE_COLOR))
	grow_3 := cu.create_widget(
		ctx,
		"child 3",
		cu.layout(cu.sizing(cu.grow(), cu.grow()), child_gap = 16),
		clip = cu.clip(cu.clip_none(), cu.clip_auto(5)),
		style = cu.style(SURFACE_COLOR, cu.axis_vec2f32(16, 16)),
	)
	cu.push_parent(ctx, grow_3)
	fit_1 := cu.create_widget(ctx, "fit", cu.layout(cu.sizing(cu.fit(), cu.fit())), style = cu.style(WARNING_COLOR, cu.axis_vec2f32(5, 5)))
	cu.push_parent(ctx, fit_1)
	cu.create_widget(
		ctx,
		"child 1",
		cu.text("Hmmm", cu.text_style(TEXT_PRIMARY_COLOR, 20, 1, 0, font), 100000),
		style = cu.style(ELEVATED_SURFACE_COLOR, cu.axis_vec2f32(16, 8)),
	)
	cu.pop_parent(ctx)
	cu.create_widget(
		ctx,
		"child 2",
		cu.layout(cu.sizing(cu.grow(), cu.ratio(aaloo_image.h / aaloo_image.w))),
		image = aaloo_image.data,
		style = cu.style(ELEVATED_SURFACE_COLOR),
	)
	cu.create_widget(
		ctx,
		"child 3",
		cu.layout(cu.sizing(cu.grow(), cu.ratio(aaloo_image.h / aaloo_image.w))),
		image = aaloo_image.data,
		style = cu.style(ELEVATED_SURFACE_COLOR),
	)

	cu.pop_parent(ctx)
	cu.pop_parent(ctx)
}
