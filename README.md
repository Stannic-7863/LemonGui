# A simple (POTENTIAL) Imgui written in Odin

# Note
Some api changes happening right now. `Floating` layout type will be removed in favour of a new `Grid` parameter in `Layout` and some flags will be added to define if widget contributes to parent size per axis and can it overflow parent per axis. 

# Progress so far
## Features:
- [x] Layout
- [x] Word Wrapping
- [x] Basic mouse event handling
- [x] Basic styling options and tag system for compose-able styles
## Planned things:
- [ ] Animation system
- [ ] Caching (text wrapping especially) for better performance
- [ ] Well defined/documented behaviour for all combinations of layouts and text wrapping
- [ ] Layout type to support **wrapping** for Widgets and more freedom with floating widgets in terms of anchor position
	- Anchor position should be defined in terms of a grid perhaps? Parent can specify the grid in terms of rows and columns. Floating would attach to the rows and cols specified. 
- [ ] Errors and Error handler support
- [x] Keyboard events [Done]
- [x] Better Id/Keying system for widget [Done]
# How to Use?

## The general setup is as follows:

- Initialize Core_Context by calling `init_core_context` and setup some values in it before entering main loop. Initialised `Core_Context` will now be referred to as `ctx`

- In the main loop:
    - Set events in `ctx` 
    - Call `begin_ui`. This clears up left over data from last frame.
    - Create a widget hierarchy using `create_widget`, `push_parent`, `pop_parent` procs.
    - Handle `widget.events`.  
    - Call `end_ui(&ctx)`. This handles the layout, positioning, emission of rendering commands, and events.
    - Lastly, render `ctx.render_commands` using a custom `render()` proc. (A basic one provided in `example/main.odin`).
- Free up Core_Context by calling `deinit_core_context`

Note that widgets are rendered at the updated positions and sizes immediately however the events have 1 frame lag.

## Initialization 
`init_core_context` takes a `total_widgets` parameter and returns a `ctx`. Initialises `ctx.widgets` array with the provided length. `total_widgets` must be higher than the number of the widgets intended to be added. Otherwise due to memory re-location the pointers in widget.node become invalid and cause a segfault 

After that set the `ctx.text_measure_proc` and `ctx.mouse.events.*_timeouts`.

### text_measure proc 
`text_measure_proc` (`proc(text: string, style: Text_Style) -> f32`) should return the width of a character based on `Text_Style`.  

## Now entering the main loop
You need to set some fields in `ctx` such as `mouse.events` and `delta_time`.

The first widget added is considered to be the root widget. All other widgets must be its children. `push_parent` and `pop_parent` procs are used to manage current parent.

`end_ui` is called called after the widget hierarchy is constructed. It lays out and positions all the widgets and fills the `ctx.render_commands` array.

## Creating widgets 

Widgets are created using the `create_widget` proc.  

proc definition:
```odin
proc(ctx: ^Core_Context, widget_kind: Widget_kind = nil, string_id: string = "", aspect_ratio: Maybe(f32) = nil, image: Maybe(Image) = nil, clip: Maybe([2]Clip) = nil, expand: [2]Expand = {}, offset: [2]Offset = {}, style: Style = {}, event_passthrough: bool = false,) -> ^Widget
```
`create_widget` returns a pointer to `widget` that was created so that the properties can be modified later after creation. 

### ctx : ^Core_Context
Explicit passing of context is annoying but this choice was made to facilitate threading in future if ever needed.

### widget_kind : Widget_Kind

Internally `Widget_Kind` is 
```odin 
Widget_Kind :: union {
    Layout,
    Floating,
    Text,
}
```
These are discussed below

#### Layout

Internally `layout` is 
```odin
Layout :: struct {
	sizing:          [Axis]Sizing,
	child_gap:       f32,
	child_alignment: Child_Alignment,
	direction:       Axis,
}
```
Axis is 
```odin
Axis :: enum {
    X, 
    Y,
}
``` 

`Sizing` is defined for each `Axis`. Its a union of different kinds of layout kinds. 
- `Fit`: Of type `Min_Max`. The widget will expand or shrink its own size to accommodate its children.
- `Grow`: Of type `Min_Max`. The widget will expand to fill up any remaining space in the parent. Space is distributed equally between multiple `Grow` widgets.
- `Fixed`: Of type `Value`. The size of widget is fixed and given by user in pixels.  
- `Percent`: Of type `Value`. Percentage of parent's size minus all child gaps and parent padding. Percent widgets can overgrow their parents. 

`child_gap` is spacing between each children of a parent. 

`child_alignment` defines how the children of a widget are aligned along x and y axis. Children can be aligned at `Left`, `Center` or `Right` at `X` axis and `Top`, `Center` or `Bottom` at `Y` axis. 

`direction` defines along which axis children are laid out. `X` lays children horizontally. `Y` lays children vertically. 

#### Floating 

Floating widgets don't affect the size of their parents and are rendered on top of all other normal widgets. And can be attached to parent at several different pre-defined points. 

Internally floating is 
```odin
Floating :: struct {
	layout:          Layout,
	id:              Id,
	parent, element: Anchor,
	attachment_to:   Attachment_To,
}
```

`layout` specifies the layout for the floating widget. 

`attachment_to` defines to which widget Floating is attached. Floating can be attached to `Root`, `Parent`, `Id`, `None`. 

`id` is used if `attachment_to` is set to `Id`. It uses position and size data from previous frame. 

`parent` `element` *anchor* defines how floating and parent are attached together. `parent` defines the point where the floating is attached to the parent. `element` defines the point where parent is attached to the floating.

#### Text 

Internally Text is 
```odin
Text :: struct {
	style:        Text_Style,
	text:         string,
	_start, _end: int,
	wrap:         Wrap_Kind,
	cursor:       Maybe([2]int),
}
```

Unlike `Floating` or `Layout` `Text` does not have children. Nor can you push it using `push_parent`. 

`_start` and `_end` fields are for internal usage. These are passed onto the renderer. These are used to slice the `ctx.text_lines` to get wrapped lines of the widget. `ctx.text_lines` also only holds slices to `text` string and does not make a copy. 

`style`

`wrap` is a enum that specifies how text is wrapped. 
- `Word_Wrap`: Wrap words if they exceed widget bounds.
- `Letter_Wrap`: Wraps letters if they exceed widget bounds.
- `New_Line_Wrap`: Wraps on only new lines.
- `None`: No Wrap at all.

`cursor` interpretation up to renderer. 

### string_id : string

String id used for debugging. 

### aspect_ratio : f32

Confines widgets height to respect the given aspect ratio. Internally, simply computed as `widget.size.x * aspect_ratio`. This is forced on all layout kinds.

### image : Image

Internally image is 
```odin
Image :: struct {
	image_data: rawptr,
	tint:       Color,
}
```

It is passed down to the renderer unmodified with a position and size. Aspect ratio is needed for images to work. 

### clip : [2]Clip

`Clip` will offset the children of the widget by the clip value provided. 

`Clip_Type` defines if clip value is `Custom` and set by user or is `Auto` and handled by layout.

### expand : [2]Expand

`expand` expands the size of the widget after the sizing pass in layout along a axis. `Expand` is a union for several expand kinds.

Different kinds of expand are:
- `Absolute`: Expand size by provided size defined in pixels.
- `Percent`: Expand size by percentage of parent's size.
- `Percent_Self`: Expand size by percentage of widget's size.

### offset : [2]Offset

`offset` offsets the widget after its been positioned in layout along a axis. `Offset` is a union for several offset kinds. 

Different kinds of offset are:
- `Fixed`: Set position of the widget to value defined in pixels.
- `Absolute`: Offset position by value defined in pixels relative to parent's position.
- `Percent`:  Offset position by percent of parent's size.
- `Percent_Self`: Offset position by percentage of widget's size.

### style : Style

Internally style is 
```odin
Style :: struct {
	border:  Maybe(Border_Style),
	padding: Vec4f32,
	color:   Color,
}
```

`padding` defines how much widgets are offset from the edges of the parent. Order is defined as {top, right, bottom, left}

`color` is the background color of the widget. 

`border` defines a border around the widget. 

### event_passthrough : bool

Widget will this set to true will not detect event and will not occlude the parent

## Creating primitives

[Todo later]

## Using the API 

Procs in `helper.odin` make life a bit easier when making widgets. Each proc has default arguments which default to Zero for everything. 

Some examples of helper procs 
- `sizing(grow(max=300), fit(min=200)))` 
- `offset(offset_absolute(...)) // Specified the x param, y is default`
- `expand(y=expand_percent_self(...))) // x is default`

Example Creation of different widgets: 

```odin
create_widget(&ctx, layout(sizing(grow(), grow()), child_alignment(.Center, .Center), child_gap = 8), expand=expand(y=expand_absolute(50)), style= {color={255,255,255,255})}) 
create_widget(&ctx, floating(layout(sizing(grow(), grow()), child_alignment(.Center, .Center), child_gap = 8), element = .Center_Center, parent = .Center_Center), expand=expand(y=expand_absolute(50)), style= {color={255,255,255,255})})
create_widget(&ctx, text("A quick brown fox jumps over the lazy dog", wrap=.Words, style={font=&your_font, font_size=20, letter_spacing=1}))
```

## Render Commands 
[Todo later]
