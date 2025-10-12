package main

import lui "../"
import "core:fmt"

Image :: struct {
	w, h: f32,
	data: rawptr,
}

build_ui :: proc(ctx: ^lui.Core_Context, tick_image: Image, aaloo_image: Image, font: rawptr, width, height: f32) {
	style_basic := lui.create_style(
		ctx,
		{padding = lui.axis_vec2f32(16, 16), color = BACKGROUND_COLOR, border = lui.border(BORDER_COLOR, 0, lui.axis_vec2f32(2, 2))},
	)
	style_scroll := lui.create_style(ctx, {color = SUCCESS_COLOR})
	style_elevated := lui.create_style(
		ctx,
		{padding = lui.axis_vec2f32(8, 8), color = ELEVATED_SURFACE_COLOR, border = lui.border(BORDER_COLOR, 0, lui.axis_vec2f32(2, 2))},
	)
	text_style := lui.create_style(
		ctx,
		{
			padding = lui.axis_vec2f32(16, 16),
			border = lui.border(BORDER_COLOR, 0, lui.axis_vec2f32(2, 2)),
			text = {color = TEXT_PRIMARY_COLOR, font = font, font_size = 16, letter_spacing = 2, line_spacing = 0},
		},
	)
	text_style_no_pad := lui.create_style(
		ctx,
		{
			border = lui.border(BORDER_COLOR, 0, lui.axis_vec2f32(2, 2)),
			text = {color = TEXT_PRIMARY_COLOR, font = font, font_size = 16, letter_spacing = 2, line_spacing = 0},
		},
	)


	root := lui.create_widget(ctx, "Root", lui.layout(lui.sizing(lui.fixed(width), lui.fixed(height)), lui.alignment(.Center, .Center), 16, .Y))
	root.style = style_basic

	lui.push_parent(ctx, root)

	@(static) widget_arr: [dynamic][dynamic]int

	if widget_arr == nil {
		for i in 0 ..< 5 {
			append(&widget_arr, [dynamic]int{})
			arr := &widget_arr[i]
			for j in 0 ..< 5 {
				append(arr, j)
			}
		}
	}

	for &w_row, i in widget_arr {
		lui.push_parent(ctx, lui.create_widget(ctx, i + 1, lui.layout(lui.sizing(lui.grow(), lui.grow()), lui.alignment(.Center, .Center), 16)))
		defer lui.pop_parent(ctx)

		add_button := lui.create_widget(ctx, i + 10000, lui.text("Add", .None), animate_props = {.Size}, style = text_style)
		if lui.is_widget_hovered(ctx, add_button) {
			events := lui.get_widget_mouse_events(ctx, add_button, .Left)
			if .Clicked in events {
				if len(w_row) > 0 {
					append(&widget_arr[i], w_row[len(w_row) - 1] + 1)
				} else {
					append(&widget_arr[i], 0)
				}
			}
		}

		for w_col, j in w_row {
			w := lui.create_widget(
				ctx,
				j + 1,
				lui.layout(lui.sizing(lui.fixed(100), lui.fixed(100)), lui.alignment(.Center, .Center)),
				animate_props = {.Size},
				style = style_elevated,
			)
			lui.push_parent(ctx, w)
			lui.create_widget(ctx, fmt.tprint("text"), lui.text(fmt.tprint(w_col)), animate_props = {.Size}, style = text_style)
			lui.pop_parent(ctx)
			if lui.is_widget_hovered(ctx, w) {
				w.style = style_scroll
				events := lui.get_widget_mouse_events(ctx, w, .Left)
				if .Clicked in events {
					ordered_remove(&w_row, j)
				}
			}
		}
	}

	lui.pop_parent(ctx)
}
