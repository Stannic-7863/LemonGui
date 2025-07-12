# A simple (POTENTIAL) Imgui written in Odin

# Progress so far:
- [x] Layout
- [x] Word Wrapping
- [x] Basic mouse event handling
- [x] Basic styling options
- [ ] Keyboard events
- [ ] Animation system
- [ ] Caching (text wrapping especially) for better performance
- [ ] Well defined/documented behaviour for all combinations of layouts and text wrapping
- [ ] Layout type to support **wrapping** for Widgets + More freedom with floating widgets in terms of anchor position
- [ ] Errors and Error handler support

# How to Use?

## The general setup is as follows:

- Initialize Core_Context by calling `init_core_context` and setup some values in it before entering main loop.

- In main loop:
    - Feed the Core_Context mouse events for now

    - Call `begin_ui(&ctx)`. This is only a semantic choice. The `begin_ui(&ctx)` is empty and does not do anything. 

    - Create widget heirarchy using `create_widget`, `push_parent`, `pop_parent` procs
    - Update your data/state based on last frame inputs stored in `your_widget.events`

    - Call `end_ui(&ctx)`. This handles the Layout, Positioning, Emittion of rendering commands, and Events.

    - Lastly, render `ctx.render_commands` using a custom `render()` proc. (One provided in `example/main.odin`. Although its really naive)

- Free up Core_Context by calling `deinit_core_context`

Note that widgets are rendered at the updated positions and sizes immediatly however the event detection get a 1 frame penalty.

I'll now refer to initialised `Core_Context` as `ctx`. 

## Initialization 
`init_core_context` takes a max_widget_number parameter. That specifies the max number of widget that can potentially be added into the widget heirarchy. Due to memory re-location (limit reached but allocator can't extend the current memory block in place, it has to move to a new location) the `Widget` pointers used anywhere become invalidated and program segfaults. [Behvaiour likely to change in next iterations]

Once you have `ctx` you need setup to the `ctx.text_measure` proc pointer. Program will segfault otherwise. 
You also need to setup the `ctx.mouse.double_click_timeout` and `ctx.mouse.long_down_timeout`. These are used for `*_double_click` and `long_*_down` events. (`*` refering to different mouse buttons)

### text_measure proc 
Proc definition for text_measure is : `proc(text: string, style: Text_Style) -> f32`. Second argument style is of type `Text_Style` which contains a `rawptr` to a Font, a `font_size`, `line_spacing` (Internel usage : Determines font position as `widget.position.x + (line_number) * (line_spacing + font_size)`), `letter_spacing` (space in terms of pixel between each letter) and a `color`. This information is also provided to renderer without any modifications.

## Now entering the main loop

`ctx` needs to be fed with `Mouse_Events` and `delta_time` before `end_ui` is called.

The first ever widget added during the frame is considered a root widget. Each subsequent widget must be its child otherwise undefined behaviour will occur. Parent management is explicit with `push_parent` and `pop_parent` procs.

Once widget heirarchy is constructed, `end_ui` is called. It first lays out all widgets and applies the layout rules. It then positions all the widgets. And at last checks for events on `hot_widgets`.
`ctx.render_commands` are emitted during positioning pass. 

## Creating widgets 

Widgets are created using the `create_widget` proc call. Proc definition of `create_widget` is 

```odin
proc(ctx: ^Core_Context, widget_type: Widget_Type = nil, string_id: string = "", aspect_ratio: Maybe(f32) = nil, image: Maybe(Image) = nil, clip: Maybe([2]Clip) = nil, expand: [2]Expand = {}, offset: [2]Offset = {}, style: Style = {}, event_passthrough: bool = false,) -> ^Widget
```
(Intimidating indeed)

The first argument is a pointer to `ctx`. Explicit passing of context is annoying but this choice was made to facilitate threading in future if ever needed.
`create_widget` returns a pointer to `widget` that was created. This means two things: 
1. Widget's properties can be changed after its creation.
2. `create_widget` fills in widget with some data from previous frame. Like position, size and events. 
Second argument is `Widget_Type`. There are three types of widgets: `Layout`, `Floating` and `Text`. Since layout is Clay inspired ( or Clay port :) ) the same rules almost apply. Below will be a basic rundown of widget type.
We'll look at all arguments and what they entail now

### widget_type : Widget_Type

Widget can be of these following types [More might be added later].

#### Layout

Internally layout is 
```odin
Layout :: struct {
	sizing:          [Axis]Sizing,
	child_gap:       f32,
	child_alignment: Child_Alignment,
	direction:       Axis,
}
```
Axis is an enum which can be either `X` or `Y`. Its defined only for better semantics (`X` `Y` instead of 0, 1).

`Sizing` is defined for each `Axis`. Sizing holds a min, max value and `Layout_Kind`. `Layout_Kind` has four types: 

`Fit`: The widget will expand or shrink its own size to accomodate its children.

`Grow`: This widget will expand to fill up any remaining space in the parent. Space distributed equally between multiple `Grow` siblings.

`Fixed`: Widget with predetermined fixed set size. Only affected by aspect ratio.

`Percent`: Percentage of parent's size - child gaps - padding. This can and will overflow the parent widget.

Min, max values for `Fit` and `Grow` sizing are defined in pixels. For `Fixed` sizing min = max and are defined in pixels. For `Percent` sizing min=max and hold a value in range 0-1

`child_gap` is the space defined in pixels between each sibling widget. 

`child_alignment` defines how the children of a widget are aligned along x and y axis. Childs can be aligned at `Left`, `Center` or `Right` at `X` axis and `Top`, `Center` or `Bottom` at `Y` axis. 

`direction` defines along which axis childrens are layed out. `X` lays children horizontally. `Y` lays children vertically. 

#### Floating 

Floating widgets donot contribute to the size of their parents and are rendered on top of all other normal widgets. And can be attached to parent at several different pre-defined points [Behaviour likely to change in next iterations.]

Internally floating is 
```odin
Floating :: struct {
	layout:          Layout,
	id:              Id,
	parent, element: Anchor,
	attachment_to:   Attachment_To,
}
```

`layout` here is a field that specifies the layout for the floating widget. 

`attachment_to` defines where the floating widget is attached. Floating can be attached to `Root`, `Parent`, `Id`, `None`. 

`id` is used if `attachment_to` is set to `Id`. It uses previous frame widget data however. 

`parent` `element` *anchor* defines where the floating is attached to parent. `parent` *anchor* is offset of widget by parent size. `element` *anchor* is offset of widget by its own size. [Likely to change. However current behavior is exactly how clay does it]

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

`style` is as defined in [text_measure proc](https://github.com/Stannic-7863/Omgui/Master/README.md#text_measure-proc) section.

`wrap` specifies four ways to wrap text. 

`Word_Wrap`: Wrap words if they exceed widget bounds.

`Letter_Wrap`: Wraps letters if they exceed widget bounds.

`New_Line_Wrap`: Wraps on only new lines.

`None`: No Wrap at all.

`cursor` is passed unmodified to the renderer. It is there just for the convenience. Usage is user-defined. 

### string_id : string

Stays unmodifed. Used for debugging purposes only as of right now. 

### aspect_ratio : f32

Confines widgets height to respect the given aspect ratio (Internally simply computed as `widget.size.x * aspect_ratio`). This is forced on all layout kinds (`Fixed`, `Percent`.. etc).

### image : Image

Internally image is 
```odin
Image :: struct {
	image_data: rawptr,
	tint:       Color,
}
```

It is passed down to the renderer unmodifed with extra data. Aspect ratio MUST be provided for images to work. 

### clip : [2]Clip

`Clip` offsets the children of a widget by the given amount scaled by given speed and clip the widget so children do not render outside the widget's bound. 

`Clip_Type` defines if clip value is `Custom` and set by user or is `Auto` and handled by layout for scrolling.

### expand : [2]Expand

`expand` expands the size of the widget after the sizing pass in layout along a axis. `Expand` has a `value` and a `Expand_Kind`

Different kinds of expand are:

`None`: No expansion in size.

`Absolute`: Exapand size by provided size defined in pixels.

`Percent`: Expand size by percentage of parent's size.

`Percent_Self`: Expand size by percentage of widget's size.

### offset : [2]Offset

`offset` offsets the widget after its been positioned in layout along a axis. `Offset` has a `value` and a `Offset_Kind`

Different kinds of offset are:

`None`: No offset is applied.

`Fixed`: Set position of the widget to value defined in pixels.

`Absolute`: Offset position by value defined in pixels relative to parent's position.

`Percent`:  Offset position by percent of parent's size.

`Percent_Self`: Offset position by percentange of widget's size.

### style : Style

Internally style is 
```odin
Style :: struct {
	border:  Maybe(Border_Style),
	padding: Vec4f32,
	color:   Color,
}
```

`padding` [Placement is subject to change later. Possibly with `child_gap` in `layout`] defines how much widgets are offset for the sides of the parent. Order is defined as {top, right, bottom, left}

`color` is the background color of the widget. 

`border` defines a border around the widget. 

### event_passthrough : bool

Widget will this set to true will not detect event and will not ocllude the parent

## Creating primitives

[Todo later]

## Using the API 

The above is a bit intimidating and a lot of info to absorb. The helper procs in `helper.odin` should assist in specifying all of above and with default parameters not all values have to be defined.

For things that have to be specified for both axis (`[Axis]Type` or `[2]Type`) the general pattern is `Type(Type_Kind(), Type_Kind())` where first argument is for `X` axis and second is for `Y` axis.

Example : `sizing(grow(), fit())`, `offset(offset_absolute(param)) // Only need to specified X, Y will fallback to default`, `expand(y=expand_percent_self()))` 

Example Creation of different widgets: 

```odin
create_widget(&ctx, layout(sizing(grow(), grow()), child_alignment(.Center, .Center), child_gap = 8), expand=expand(y=expand_absolute(50)), style= {color={255,255,255,255})}) 
create_widget(&ctx, floating(layout(sizing(grow(), grow()), child_alignment(.Center, .Center), child_gap = 8), element = .Center_Center, parent = .Center_Center), expand=expand(y=expand_absolute(50)), style= {color={255,255,255,255})})
create_widget(&ctx, text("A quick brown fox jumps over the lazy dog", wrap=.Words, style={font=&your_font, font_size=20, letter_spacing=1}))
```

## Render Commands 
[Todo later]
