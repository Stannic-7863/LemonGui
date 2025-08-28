# A simple (POTENTIAL) Imgui written in Odin

# Progress so far
## Features:
- [x] Flex box sort of layout
- [x] Word wrapping
- [x] Basic mouse event handling
- [x] Basic styling options and tag system for compose-able styles
- [x] Keyboard events
- [x] Id/Keying system for widgets
## Planned things:
- [ ] Animation system
- [ ] Caching (text wrapping especially) for better performance
- [ ] Errors and Error handler support

# Example usage 

```odin
package main

import omgui "Omgui"

main :: proc () {

	// Init the ui context. Size parameter specified the length of widget array. Although its dynamic, the resizing of array can cause memory rellocation which result in invalid pointers and lead to segfault
	ctx := omgui.init_context(256)
	defer omgui.deinit_context()

	// Need to set this function as well. Otherwise there will be a segfault
	ctx.measure_text_proc = measure_text

	// Magically create a window to render stuff in
	init_window_somehow()
	defer deinit_the_window_somehow()

	for window_open {

		// all create_widget proc calls should be inside the begin_ui and end_ui
		omgui.begin_ui(&ctx)

		// The id's are generated from the string + parent's hash.
		// This means as children of different parents can have same id if their parent id differs.
		// Useful for creating widgets like buttons as the button's body widget can have a unique id while all inner children can have same id's such as label or icon 
		root := omgui.create_widget(&ctx, "id root", omgui.layout(omgui.sizing(omgui.fixed(window_width), omgui.fixed(window_height))), style = omgui.style(background_color)))

		// Set a widget as parent. This is how the tree is constructed. Can also do if omgui.push_parent(...) {defer omgui.pop_parent() ...}
		omgui.push_parent(&ctx, root)

		// Add more stuff inside the root. First widget is considered root and all other widgets MUST be children of root. Otherwise they'll probably simply not work

		// All parameters specified : ). 
		omgui.create_widget(
			&ctx,
			id = "example widget",
			layout = omgui.layout(omgui.sizing(omgui.grow(min=50, max=250), omgui.fit(50, 700)), omgui.alignment(.Negative, .Positive), child_gap = 16, direction = .Y),
			override = omgui.override(omgui.flags(x = {}, y = {}), omgui.offset(omgui.fixed(50), omgui.Percent_Self(0.5)), omgui.expand(omgui.percent(0.5), omgui.fixed(50)), z_index = 100),
			event_flag = {.Lock_Active, .Lock_Hover},
			clip = omgui.clip(omgui.clip_custom(value = custom_clip_value, scale = 15), omgui.clip_auto(scale = 15))
			image = nil,
			style = omgui.style(color = {250,250,250,255}, padding = omgui.axis_vec2f32({16, 16}, {8, 8}), border = omgui.border(color = {28,28,28,255}, radius = {4,4,4,4}, thickness = omgui.axis_vec2f32({2, 2}, {2, 2})))
		)

		omgui.pop_parent(&ctx)

		omgui.end_ui(&ctx)

		render_the_commands_somehow(ctx)

	}
}
```

# Some more docs 
[Todo lator]
