package main

import cu "../"
import "core:fmt"
import "core:math"
import "core:reflect"
import "core:strings"
import "core:text/edit"
import "core:time"
import "core:unicode/utf8"
import rl "vendor:raylib"

Image :: struct {
	w, h: f32,
	data: rawptr,
}

build_ui :: proc(ctx: ^cu.Core_Context, tick_image: Image, aaloo_image: Image, state: ^edit.State, buffer: ^strings.Builder) {
	root := cu.create_widget(
		ctx,
		"Root",
		cu.layout(cu.sizing(cu.fixed(ctx.window_width), cu.fixed(ctx.window_height))),
		style = {padding = cu.padding(32), color = BACKGROUND_COLOR},
	)

	cu.push_parent(ctx, root)
	cu.pop_parent(ctx)
}

update_edit_state :: proc(state: ^edit.State) {
	char := rl.GetCharPressed()

	if cast(bool)char {
		edit.input_rune(state, char)
	}

	if rl.IsKeyPressed(.ENTER) {
		edit.perform_command(state, .New_Line)
	}

	if rl.IsKeyPressed(.BACKSPACE) {
		edit.perform_command(state, .Backspace)
	}

	if rl.IsKeyPressed(.DELETE) {
		edit.perform_command(state, .Delete)
	}

	if rl.IsKeyPressed(.A) && rl.IsKeyDown(.LEFT_CONTROL) {
		edit.perform_command(state, .Select_All)
	}

	if rl.IsKeyPressed(.LEFT) {
		if rl.IsKeyDown(.LEFT_CONTROL) && rl.IsKeyDown(.LEFT_SHIFT) {
			edit.perform_command(state, .Select_Word_Left)
		} else if rl.IsKeyDown(.LEFT_SHIFT) {
			edit.perform_command(state, .Select_Left)
		} else if rl.IsKeyDown(.LEFT_CONTROL) {
			edit.perform_command(state, .Word_Left)
		} else {
			edit.perform_command(state, .Left)
		}
	}

	if rl.IsKeyPressed(.RIGHT) {
		if rl.IsKeyDown(.LEFT_CONTROL) && rl.IsKeyDown(.LEFT_SHIFT) {
			edit.perform_command(state, .Select_Word_Right)
		} else if rl.IsKeyDown(.LEFT_SHIFT) {
			edit.perform_command(state, .Select_Right)
		} else if rl.IsKeyDown(.LEFT_CONTROL) {
			edit.perform_command(state, .Word_Right)
		} else {
			edit.perform_command(state, .Right)
		}
	}

	if rl.IsKeyPressed(.UP) {
		if rl.IsKeyDown(.LEFT_SHIFT) {
			edit.perform_command(state, .Select_Up)
		} else {
			edit.perform_command(state, .Up)
		}
	}

	if rl.IsKeyPressed(.DOWN) {
		if rl.IsKeyDown(.LEFT_SHIFT) {
			edit.perform_command(state, .Select_Down)
		} else {
			edit.perform_command(state, .Down)
		}
	}

	if rl.IsKeyPressed(.HOME) {
		if rl.IsKeyDown(.LEFT_CONTROL) {
			edit.perform_command(state, .Start)
		} else {
			edit.perform_command(state, .Line_Start)
		}
	}

	if rl.IsKeyPressed(.END) {
		if rl.IsKeyDown(.LEFT_CONTROL) {
			edit.perform_command(state, .End)
		} else {
			edit.perform_command(state, .Line_End)
		}
	}
}
