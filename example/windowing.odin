package main

import gl "vendor:OpenGL"
import glfw "vendor:glfw"
import rl "vendor:raylib"

init_window_raylib :: proc(width: i32 = 800, height: i32 = 600, name: cstring = "Window", config: rl.ConfigFlags = {}) {
	rl.SetConfigFlags({})
	rl.InitWindow(width, height, name)
}

close_window_raylib :: proc() {
	rl.CloseWindow()
}

init_window_glfw :: proc(width: i32 = 800, height: i32 = 640, name: cstring = "Opengl Window", major: i32 = 4, minor: i32 = 6) -> glfw.WindowHandle {

	glfw.Init()
	glfw.WindowHint(glfw.CONTEXT_VERSION_MAJOR, major)
	glfw.WindowHint(glfw.CONTEXT_VERSION_MINOR, minor)
	glfw.WindowHint(glfw.OPENGL_PROFILE, glfw.OPENGL_CORE_PROFILE)

	window := glfw.CreateWindow(width, height, name, nil, nil)

	if window == nil {
		panic("Could not create a window")
	}

	glfw.MakeContextCurrent(window)
	glfw.SetFramebufferSizeCallback(window, proc "c" (window: glfw.WindowHandle, width, height: i32) {
		gl.Viewport(0, 0, width, height)
	})

	gl.load_up_to(cast(int)major, cast(int)minor, glfw.gl_set_proc_address)
	gl.Viewport(0, 0, 800, 800)

	gl.Enable(gl.BLEND)
	gl.BlendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA)
	gl.Enable(gl.DEPTH_TEST)

	return window
}

close_window_glfw :: proc(window: glfw.WindowHandle) {
	glfw.DestroyWindow(window)
	glfw.Terminate()
}
