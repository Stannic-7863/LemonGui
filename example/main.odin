package main

import "core:fmt"
import "core:time"

import ui "../"
import sdl_backend "backend/sdl_gpu"
import sdl "vendor:sdl3"

Theme :: struct {
    bg, surf, surf_2:     ui.Color,
    fg, fg_dim:           ui.Color,
    primary, primary_d:   ui.Color,
    green, green_d:       ui.Color,
    red, red_d:           ui.Color,
    border:               ui.Color,
}

DARK :: Theme{
    bg       = { 15,  15,  20, 255},
    surf     = { 24,  24,  32, 255},
    surf_2   = { 36,  36,  48, 255},
    fg       = {230, 228, 255, 255},
    fg_dim   = {120, 116, 150, 255},
    primary  = {140, 120, 255, 255},
    primary_d= { 70,  55, 160, 255},
    green    = { 80, 200, 130, 255},
    green_d  = { 30, 100,  60, 255},
    red      = {240,  90, 100, 255},
    red_d    = {130,  30,  40, 255},
    border   = { 50,  48,  68, 255},
}

LIGHT :: Theme{
    bg       = {242, 242, 250, 255},
    surf     = {255, 255, 255, 255},
    surf_2   = {230, 228, 245, 255},
    fg       = { 20,  18,  40, 255},
    fg_dim   = {120, 116, 150, 255},
    primary  = { 90,  65, 210, 255},
    primary_d= { 50,  35, 140, 255},
    green    = { 30, 150,  80, 255},
    green_d  = { 15,  80,  40, 255},
    red      = {200,  50,  60, 255},
    red_d    = {110,  20,  28, 255},
    border   = {200, 196, 225, 255},
}

t: Theme

Filter :: enum { All, Active, Done }

Todo :: struct {
    text:  string,
    done:  bool,
    alive: bool,
}

State :: struct {
    todos:     [64]Todo,
    count:     int,
    filter:    Filter,
    dark_mode: bool,
}

state: State

add_todo :: proc(text: string) {
    if state.count >= 64 { return }
    state.todos[state.count] = {text = text, done = false, alive = true}
    state.count += 1
}

PAD   :: f32(16)
PAD_S :: f32(8)
R     :: f32(14)

main :: proc() {
    backend_ctx := sdl_backend.init(
        "todos",
        "./backend/sdl_gpu/shaders/compiled/main.vert.sprv",
        "./backend/sdl_gpu/shaders/compiled/main.frag.sprv",
        "./backend/sdl_gpu/shaders/compiled/stencil.vert.sprv",
        "./backend/sdl_gpu/shaders/compiled/stencil.frag.sprv",
    )
    defer sdl_backend.de_init(&backend_ctx)

    ctx := ui.init_context(1024)
    ctp := &ctx
    defer ui.deinit_context(&ctx)

    ctx.measure_text_width  = sdl_backend.measure_text_width
    ctx.measure_text_height = sdl_backend.measure_text_height
    ctx.mouse.double_click_timeout = time.Millisecond * 300
    ctx.mouse.long_down_timeout    = time.Millisecond * 1000

    sdl_backend.init_font(&backend_ctx)
    font_13 := sdl_backend.add_font(&backend_ctx, "./assets/JetBrainsMono-Regular.ttf", 13)
    font_15 := sdl_backend.add_font(&backend_ctx, "./assets/JetBrainsMono-Regular.ttf", 15)
    font_28 := sdl_backend.add_font(&backend_ctx, "./assets/JetBrainsMono-Regular.ttf", 28)
    defer sdl_backend.de_init_font(&backend_ctx)

    state.dark_mode = true
    t = DARK

    add_todo("design the layout engine")
    add_todo("implement word wrapping")
    add_todo("write the gpu backend")
    add_todo("fix grow and shrink edge cases")
    add_todo("add scrollable clip regions")
    add_todo("document the public api")
    add_todo("ship it")
    state.todos[0].done = true
    state.todos[1].done = true

    for handle_events(ctp, &backend_ctx) {
        defer free_all(context.temp_allocator)
        ui.begin(ctp)

        br :: proc(c: ui.Color, r: f32 = R) -> ui.Border_Style {
            return {color = c, thickness = {{1,1},{1,1}}, radius = {r,r,r,r}}
        }
        bw :: proc(c: ui.Color, r: f32, top, right, bottom, left: f32) -> ui.Border_Style {
            return {color = c, thickness = {{top, bottom}, {left, right}}, radius = {r,r,r,r}}
        }
        no_border :: proc() -> ui.Border_Style {
            return {}
        }

        s_root   := ui.create_style(ctp, {color = t.bg,    border = no_border(),         text = {font = font_15, color = t.fg,    font_size = 15}})
        s_surf   := ui.create_style(ctp, {color = t.surf,  border = br(t.border),        text = {font = font_15, color = t.fg,    font_size = 15}})
        s_surf_nb:= ui.create_style(ctp, {color = t.surf,  border = no_border(),         text = {font = font_15, color = t.fg,    font_size = 15}})
        s_dim    := ui.create_style(ctp, {color = t.surf,  border = no_border(),         text = {font = font_13, color = t.fg_dim,font_size = 13}})
        s_title  := ui.create_style(ctp, {color = t.bg,    border = no_border(),         text = {font = font_28, color = t.fg,    font_size = 28}})
        s_pri    := ui.create_style(ctp, {color = t.primary, border = br(t.primary_d,12),text = {font = font_13, color = t.bg,   font_size = 13}})
        s_pri_out:= ui.create_style(ctp, {color = t.surf_2, border = br(t.primary, 12),  text = {font = font_13, color = t.primary,font_size = 13}})
        s_green  := ui.create_style(ctp, {color = t.green,  border = br(t.green_d, 12),  text = {font = font_13, color = t.bg,   font_size = 13}})
        s_red    := ui.create_style(ctp, {color = t.red,    border = br(t.red_d, 12),    text = {font = font_13, color = t.bg,   font_size = 13}})
        s_red_out:= ui.create_style(ctp, {color = t.surf_2, border = br(t.red, 12),      text = {font = font_13, color = t.red,  font_size = 13}})
        s_ghost  := ui.create_style(ctp, {color = t.surf_2, border = br(t.border, 12),   text = {font = font_13, color = t.fg_dim,font_size = 13}})
        s_tab_on := ui.create_style(ctp, {color = t.primary,border = br(t.primary_d,12), text = {font = font_13, color = t.bg,   font_size = 13}})
        s_tab_off:= ui.create_style(ctp, {color = t.surf_2, border = br(t.border, 12),   text = {font = font_13, color = t.fg_dim,font_size = 13}})
        s_cb_done:= ui.create_style(ctp, {color = t.green,  border = br(t.green_d, 4),   text = {font = font_13, color = t.bg,   font_size = 13}})
        s_cb_open:= ui.create_style(ctp, {color = t.surf_2, border = br(t.border, 4),    text = {font = font_13, color = t.surf_2,font_size = 13}})
        s_prog_bg  := ui.create_style(ctp, {color = t.surf_2, border = br(t.border, 4), text = {}})
        s_prog_fill:= ui.create_style(ctp, {color = t.primary,border = br(t.primary, 4),text = {}})

        total, done_count := 0, 0
        for i in 0..<state.count {
            if !state.todos[i].alive { continue }
            total += 1
            if state.todos[i].done { done_count += 1 }
        }
        pct := total > 0 ? f32(done_count) / f32(total) : 0

        // Root
        {
            root := ui.reserve_widget(ctp, "root")
            rf := ui.Form{
                layout = {
                    sizing    = {ui.fixed(ctp.window_size.x), ui.fixed(ctp.window_size.y)},
                    direction = .Y,
                    padding   = 0,
                    placement = {.Center, .Negative},
                },
                style = s_root,
            }
            ui.submit_widget(ctp, root, rf)
            ui.push_parent(ctp, root)
        }

        // Centered column
        {
            col := ui.reserve_widget(ctp, "col")
            cf := ui.Form{}
            cf.layout.sizing.x = ui.fixed(560)
            cf.layout.sizing.y = ui.grow()
            cf.layout.direction = .Y
            cf.layout.padding = {0, PAD * 2}
            cf.layout.child_gap = PAD
            cf.layout.placement.x = .Center
            cf.style = s_root
            ui.submit_widget(ctp, col, cf)
            ui.push_parent(ctp, col)

            // Header row
            {
                hdr := ui.reserve_widget(ctp, "hdr")
                hf := ui.Form{}
                hf.layout.sizing.x = ui.grow()
                hf.layout.sizing.y = ui.fit()
                hf.layout.direction = .X
                hf.layout.placement.y = .Center
                hf.style = s_root
                ui.submit_widget(ctp, hdr, hf)
                ui.push_parent(ctp, hdr)

                title := ui.reserve_widget(ctp, "title")
                tf := ui.Form{}
                tf.layout.sizing.x = ui.fit()
                tf.layout.sizing.y = ui.fit()
                tf.style = s_title
                tf.text = ui.create_text(ctp, ui.text("Todos", .None))
                tf.event_flags = {.Disable_Hover}
                ui.submit_widget(ctp, title, tf)

                sp := ui.reserve_widget(ctp, "hdr_sp")
                spf := ui.Form{}
                spf.layout.sizing.x = ui.grow()
                spf.layout.sizing.y = ui.fixed(1)
                spf.style = s_root
                spf.event_flags = {.Disable_Hover}
                ui.submit_widget(ctp, sp, spf)

                toggle := ui.reserve_widget(ctp, "toggle")
                tgf := ui.Form{}
                tgf.layout.sizing.x = ui.fit()
                tgf.layout.sizing.y = ui.fit()
                tgf.layout.padding = {PAD_S, PAD_S / 2}
                tgf.style = s_ghost
                tgf.text = ui.create_text(ctp, ui.text(state.dark_mode ? "light" : "dark", .None))
                tgf.event_flags = {.Lock_Active}
                ui.submit_widget(ctp, toggle, tgf)
                if .Clicked in ui.get_widget_mouse_events(ctp, toggle, .Left) {
                    state.dark_mode = !state.dark_mode
                    t = state.dark_mode ? DARK : LIGHT
                }

                ui.pop_parent(ctp)
            }

            // Progress bar
            {
                pb := ui.reserve_widget(ctp, "prog_bg")
                pbf := ui.Form{}
                pbf.layout.sizing.x = ui.grow()
                pbf.layout.sizing.y = ui.fixed(6)
                pbf.layout.direction = .X
                pbf.layout.padding = 0
                pbf.style = s_prog_bg
                pbf.event_flags = {.Disable_Hover}
                ui.submit_widget(ctp, pb, pbf)
                ui.push_parent(ctp, pb)

                fill := ui.reserve_widget(ctp, "prog_fill")
                ff := ui.Form{}
                ff.layout.sizing.x = ui.percent(pct)
                ff.layout.sizing.y = ui.grow()
                ff.style = s_prog_fill
                ff.event_flags = {.Disable_Hover}
                ui.submit_widget(ctp, fill, ff)

                ui.pop_parent(ctp)
            }

            // Filter + actions
            {
                frow := ui.reserve_widget(ctp, "frow")
                frf := ui.Form{}
                frf.layout.sizing.x = ui.grow()
                frf.layout.sizing.y = ui.fit()
                frf.layout.direction = .X
                frf.layout.child_gap = PAD_S / 2
                frf.layout.placement.y = .Center
                frf.style = s_root
                ui.submit_widget(ctp, frow, frf)
                ui.push_parent(ctp, frow)

                filters_arr := []struct{label: string, val: Filter}{
                    {"all",    .All},
                    {"active", .Active},
                    {"done",   .Done},
                }
                for filter, i in filters_arr {
                    fw := ui.reserve_widget(ctp, fmt.tprintf("tab_{}", i))
                    fwf := ui.Form{}
                    fwf.layout.sizing.x = ui.fit()
                    fwf.layout.sizing.y = ui.fit()
                    fwf.layout.padding = {PAD, PAD_S / 2}
                    fwf.style = state.filter == filter.val ? s_tab_on : s_tab_off
                    fwf.text = ui.create_text(ctp, ui.text(filter.label, .None))
                    fwf.event_flags = {.Lock_Active}
                    ui.submit_widget(ctp, fw, fwf)
                    if .Clicked in ui.get_widget_mouse_events(ctp, fw, .Left) {
                        state.filter = filter.val
                    }
                }

                sp := ui.reserve_widget(ctp, "frow_sp")
                spf := ui.Form{}
                spf.layout.sizing.x = ui.grow()
                spf.layout.sizing.y = ui.fixed(1)
                spf.style = s_root
                spf.event_flags = {.Disable_Hover}
                ui.submit_widget(ctp, sp, spf)

                // Summary text
                summ := ui.reserve_widget(ctp, "summ")
                summf := ui.Form{}
                summf.layout.sizing.x = ui.fit()
                summf.layout.sizing.y = ui.fit()
                summf.layout.padding = {8, 4}
                summf.style = s_ghost
                summf.text = ui.create_text(ctp, ui.text(fmt.tprintf("{}/{} done", done_count, total), .None))
                summf.event_flags = {.Disable_Hover}
                ui.submit_widget(ctp, summ, summf)

                ui.pop_parent(ctp)
            }

            // Todo list
            {
                list := ui.reserve_widget(ctp, "list")
                lf := ui.Form{}
                lf.layout.sizing.x = ui.grow()
                lf.layout.sizing.y = ui.fit()
                lf.layout.direction = .Y
                lf.layout.child_gap = PAD_S
                lf.style = s_root
                lf.event_flags = {.Disable_Hover}
                ui.submit_widget(ctp, list, lf)
                ui.push_parent(ctp, list)

                for i in 0..<state.count {
                    todo := &state.todos[i]
                    if !todo.alive { continue }
                    show := true
                    switch state.filter {
                    case .Active: show = !todo.done
                    case .Done:   show =  todo.done
                    case .All:    show =  true
                    }
                    if !show { continue }

                    card := ui.reserve_widget(ctp, fmt.tprintf("card_{}", i))
                    cf := ui.Form{}
                    cf.layout.sizing.x = ui.grow()
                    cf.layout.sizing.y = ui.fit()
                    cf.layout.direction = .X
                    cf.layout.padding = PAD
                    cf.layout.child_gap = PAD_S
                    cf.layout.placement.y = .Center
                    cf.style = s_surf
                    cf.event_flags = {.Lock_Hover}
                    ui.submit_widget(ctp, card, cf)
                    ui.push_parent(ctp, card)

                    card_hovered := ui.is_widget_hovered(ctp, card)

                    // Checkbox
                    cb := ui.reserve_widget(ctp, fmt.tprintf("cb_{}", i))
                    cbf := ui.Form{}
                    cbf.layout.sizing.x = ui.fixed(22)
                    cbf.layout.sizing.y = ui.fixed(22)
                    cbf.layout.placement = {.Center, .Center}
                    cbf.style = todo.done ? s_cb_done : s_cb_open
                    cbf.text = todo.done \
                        ? ui.create_text(ctp, ui.text("✓", .None)) \
                        : ui.create_text(ctp, ui.text("", .None))
                    cbf.event_flags = {.Lock_Active}
                    ui.submit_widget(ctp, cb, cbf)
                    if .Clicked in ui.get_widget_mouse_events(ctp, cb, .Left) {
                        todo.done = !todo.done
                    }

                    // Text — no border, inherits card bg
                    tw := ui.reserve_widget(ctp, fmt.tprintf("todo_text_{}", i))
                    twf := ui.Form{}
                    twf.layout.sizing.x = ui.grow()
                    twf.layout.sizing.y = ui.fit()
                    twf.style = todo.done ? s_dim : s_surf_nb
                    twf.text = ui.create_text(ctp, ui.text(todo.text, .Words))
                    twf.event_flags = {.Disable_Hover}
                    ui.submit_widget(ctp, tw, twf)

                    // Delete
                    del := ui.reserve_widget(ctp, fmt.tprintf("del_{}", i))
                    delf := ui.Form{}
                    delf.layout.sizing.x = ui.fit()
                    delf.layout.sizing.y = ui.fit()
                    delf.layout.padding = {PAD_S, PAD_S / 2}
                    del_hot := ui.is_widget_hovered(ctp, del)
                    delf.style = del_hot ? s_red : (card_hovered ? s_red_out : s_ghost)
                    delf.text = ui.create_text(ctp, ui.text("✕", .None))
                    delf.event_flags = {.Lock_Active}
                    ui.submit_widget(ctp, del, delf)
                    if .Clicked in ui.get_widget_mouse_events(ctp, del, .Left) {
                        todo.alive = false
                    }

                    ui.pop_parent(ctp)
                }

                // Empty state
                visible := 0
                for i in 0..<state.count {
                    if !state.todos[i].alive { continue }
                    show := true
                    switch state.filter {
                    case .Active: show = !state.todos[i].done
                    case .Done:   show =  state.todos[i].done
                    case .All:    show =  true
                    }
                    if show { visible += 1 }
                }
                if visible == 0 {
                    msgs := []string{"nothing yet.", "all done!", "nothing completed."}
                    ew := ui.reserve_widget(ctp, "empty")
                    ewf := ui.Form{}
                    ewf.layout.sizing.x = ui.grow()
                    ewf.layout.sizing.y = ui.fixed(80)
                    ewf.layout.placement = {.Center, .Center}
                    ewf.style = s_dim
                    ewf.text = ui.create_text(ctp, ui.text(msgs[int(state.filter)], .None))
                    ewf.event_flags = {.Disable_Hover}
                    ui.submit_widget(ctp, ew, ewf)
                }

                ui.pop_parent(ctp)
            }

            // Bottom actions
            {
                brow := ui.reserve_widget(ctp, "brow")
                brf := ui.Form{}
                brf.layout.sizing.x = ui.grow()
                brf.layout.sizing.y = ui.fit()
                brf.layout.direction = .X
                brf.layout.child_gap = PAD_S
                brf.layout.placement.y = .Center
                brf.style = s_root
                ui.submit_widget(ctp, brow, brf)
                ui.push_parent(ctp, brow)

                add_btn := ui.reserve_widget(ctp, "add_btn")
                abf := ui.Form{}
                abf.layout.sizing.x = ui.fit()
                abf.layout.sizing.y = ui.fit()
                abf.layout.padding = {PAD, PAD_S}
                abf.style = ui.is_widget_hovered(ctp, add_btn) ? s_pri : s_pri_out
                abf.text = ui.create_text(ctp, ui.text("+ add task", .None))
                abf.event_flags = {.Lock_Active}
                ui.submit_widget(ctp, add_btn, abf)
                if .Clicked in ui.get_widget_mouse_events(ctp, add_btn, .Left) {
                    samples_arr := []string{
                        "refactor the event system",
                        "add animation support",
                        "write integration tests",
                        "benchmark the renderer",
                        "clean up the allocator",
                    }
                    add_todo(samples_arr[state.count % len(samples_arr)])
                }

                sp := ui.reserve_widget(ctp, "brow_sp")
                spf := ui.Form{}
                spf.layout.sizing.x = ui.grow()
                spf.layout.sizing.y = ui.fixed(1)
                spf.style = s_root
                spf.event_flags = {.Disable_Hover}
                ui.submit_widget(ctp, sp, spf)

                mark_all := ui.reserve_widget(ctp, "mark_all")
                maf := ui.Form{}
                maf.layout.sizing.x = ui.fit()
                maf.layout.sizing.y = ui.fit()
                maf.layout.padding = {PAD, PAD_S}
                maf.style = ui.is_widget_hovered(ctp, mark_all) ? s_green : s_ghost
                maf.text = ui.create_text(ctp, ui.text("mark all done", .None))
                maf.event_flags = {.Lock_Active}
                ui.submit_widget(ctp, mark_all, maf)
                if .Clicked in ui.get_widget_mouse_events(ctp, mark_all, .Left) {
                    for j in 0..<state.count {
                        if state.todos[j].alive { state.todos[j].done = true }
                    }
                }

                clear_btn := ui.reserve_widget(ctp, "clear_btn")
                cbf2 := ui.Form{}
                cbf2.layout.sizing.x = ui.fit()
                cbf2.layout.sizing.y = ui.fit()
                cbf2.layout.padding = {PAD, PAD_S}
                cbf2.style = ui.is_widget_hovered(ctp, clear_btn) ? s_red : s_ghost
                cbf2.text = ui.create_text(ctp, ui.text("clear done", .None))
                cbf2.event_flags = {.Lock_Active}
                ui.submit_widget(ctp, clear_btn, cbf2)
                if .Clicked in ui.get_widget_mouse_events(ctp, clear_btn, .Left) {
                    for j in 0..<state.count {
                        if state.todos[j].done { state.todos[j].alive = false }
                    }
                }

                ui.pop_parent(ctp)
            }

            ui.pop_parent(ctp) // col
        }

        ui.pop_parent(ctp) // root
        ui.end(ctp)
        sdl_backend.render(&backend_ctx, &ctx)
    }
}

handle_events :: proc(ctx: ^ui.Core_Context, backend_ctx: ^sdl_backend.Backend_Context) -> bool {
    event: sdl.Event
    @(static) down: struct { l, r, m: bool }
    ctx.mouse.scroll   = 0
    ctx.mouse.scroll_v = 0
    for sdl.PollEvent(&event) {
        #partial switch event.type {
        case .KEY_DOWN:
            if event.key.scancode == .ESCAPE { return false }
        case .QUIT:
            return false
        case .MOUSE_WHEEL:
            ctx.mouse.scroll_v = {event.wheel.x, event.wheel.y}
            ctx.mouse.scroll   = event.wheel.y
        case .MOUSE_BUTTON_DOWN:
            switch event.button.button {
            case sdl.BUTTON_LEFT:   down.l = true; ctx.mouse.mapped_events[.Left]   += {.Pressed}
            case sdl.BUTTON_RIGHT:  down.r = true; ctx.mouse.mapped_events[.Right]  += {.Pressed}
            case sdl.BUTTON_MIDDLE: down.m = true; ctx.mouse.mapped_events[.Middle] += {.Pressed}
            }
        case .MOUSE_BUTTON_UP:
            switch event.button.button {
            case sdl.BUTTON_LEFT:   down.l = false; ctx.mouse.mapped_events[.Left]   += {.Released}
            case sdl.BUTTON_RIGHT:  down.r = false; ctx.mouse.mapped_events[.Right]  += {.Released}
            case sdl.BUTTON_MIDDLE: down.m = false; ctx.mouse.mapped_events[.Middle] += {.Released}
            }
        }
    }
    if down.l { ctx.mouse.mapped_events[.Left]   += {.Down} }
    if down.r { ctx.mouse.mapped_events[.Right]  += {.Down} }
    if down.m { ctx.mouse.mapped_events[.Middle] += {.Down} }
    ctx.mouse.old_position = ctx.mouse.position
    w_w, w_h: i32
    _ = sdl.GetMouseState(&ctx.mouse.position.x, &ctx.mouse.position.y)
    _ = sdl.GetWindowSize(backend_ctx.window, &w_w, &w_h)
    ctx.mouse.delta = ctx.mouse.position - ctx.mouse.old_position
    ctx.window_size = {f32(w_w), f32(w_h)}
    return true
}
