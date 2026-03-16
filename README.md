Chass chao 👍 (means to have fun in the present moment, in my native language) .

# A simple Imgui written in Odin
# Progress so far
## Features:
- [x] Flex box sort of layout
- [x] Word wrapping
- [x] Raylib-esq event handling for keyboard and mouse (callbacks are technically possible as well)
- [x] Form based api (reserve widget, create a form, submit form to the widget)
- [x] Caching (text wrapping especially) for better performance
- [x] Animations
- [x] Decently fast

# Example usage 

> API is experimental. Refer to files in example/ directory for latest API. 

```odin
package main

import lui "LemonGui"

main :: proc () {

	// First argument in init_context will pre allocate space for widgets, while second argument defines the word cache (to store measured widths)
	ctx := lui.init_context(256, 2048)
	defer lui.deinit_context()

	// Need to set this function as well. Otherwise there will be a segfault.
	ctx.measure_text_proc = measure_text

	// Magically create a window to render stuff in
	init_window_somehow()
	defer deinit_the_window_somehow()

	for window_open {
		// in your main app loop
		lui.begin(&ctx)
		
		// Relevent data has to be provided to ctx.mouse and ctx.keyboard, for example
		ctx.mouse.position = get_mouse_position_somehow()
		ctx.mouse.scroll = get_mouse_scroll_somehow()
		// check out handle_events functions in example/main.odin file for more details

		// Resoruce such as animations, styles, overrides, clip, text must be explicitly created and reused.

		// ANIM_COLOR provided by the library, you can define your own anims 
		anim_color := lui.create_animation(&ctx, ui.ANIM_COLOR, time.Millisecond * 250)

		// Creates a style and returns a handle (index in ctx.styles array) to it
		root_style := lui.create_style(&ctx, { ... }) 
		root_style_hovered := ui.create_style(&ctx, { ... })

		// Each widget must be explicitly reserved.
		// Reservation does:
		// - allocates a widget into the ctx.widgets array, adds the widget in the widget tree.
		// - generates the widget hash and reads its properties such as size, position etc from the previous frame
		// - returns an Info struct, from which user can read useful properties such as widget size, content size, scroll offset etc. 
		root_info := lui.reserve_info(&ctx, "root_id")

		// For each reserved widget you create a form struct and fill it in with required data. Note that form.layout.sizing must be always defined
		// otherwise layout bugs will happen.
		root_form := lui.Form{}
		root_form.layout.sizing = lui.sizing(lui.fixed(window_size.x), lui.fixed(window_size.y)) // lui.sizing() for default layout
		root_form.layout.padding = { x = {10, 10}, y = {20, 20}} // left right, top bottom
		root_form.layout.maring = { ... } // same as padding. 
		root_form.style = lui.is_widget_hovered(&ctx, root_info) ? root_style_hovered : root_style
		root_form.anim = anim_color

		// All event queries use Info struct of the widget. 
		evs := lui.get_widget_events(&ctx, root_info, .Left) 
		// .Clicked in evs, .Down in evs, .Double_Clicked in evs etc
		
		// After you've created the form and modified it based on events etc, you can submit the form.
		// After submission this you should not modify the widget in any way. Unless you know what you are doing.
		lui.submit_widget(&ctx, root_info, root_form)

		lui.push_parent(&ctx, root_info)
		// Children of root go here.
		// A widget must be pushed as a parent after its been submitted, otherwise, there will be errors or bugs.
		// Library assumes you'll submit children once only. So you cannot do [push a, add children, pop a, push b, add children, pop b, push a again ...]
		// That will break the library. (intended by design, for faster perf)
		lui.pop_parent(&ctx)

		// lui.end will do the layout things (sizing, positioning), animations, events handling etc and emit render commands
		// stores render commands in ctx.render_commands, render em yourself or use the sdl backend in za repo
		lui.end(&ctx) 

		render_the_commands_somehow(ctx)

	}
}
```

# Some more docs 
[Todo lator]
