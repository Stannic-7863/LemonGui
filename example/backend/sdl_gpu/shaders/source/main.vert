#version 460

struct Render_Cmd {
  vec4 position_and_size;
  vec4 f1;
  vec4 f2;
  vec4 color;
  vec4 border_color[4];
  ivec4 flags;
};

layout(set = 0, binding = 0) readonly buffer Render_Cmds { Render_Cmd cmds[]; };
layout(set = 1, binding = 0) uniform mats { mat4 proj; };

layout(location = 0) out vec4 out_color;
layout(location = 1) out vec4 out_radius;
layout(location = 2) out vec4 out_thickness;
layout(location = 3) out vec2 out_size;
layout(location = 4) out vec2 out_uv;
layout(location = 5) out vec4 out_border_color[4];
layout(location = 9) out ivec4 out_flags;

const vec2 positions[6] =
    vec2[](vec2(0.5, 0.5), vec2(-0.5, 0.5), vec2(-0.5, -0.5), vec2(0.5, 0.5),
           vec2(-0.5, -0.5), vec2(0.5, -0.5));

const vec2 uvs[6] = vec2[](vec2(1.0, 1.0), vec2(0.0, 1.0), vec2(0.0, 0.0),
                           vec2(1.0, 1.0), vec2(0.0, 0.0), vec2(1.0, 0.0));

const int uv_map[6] = int[](1, 0, 3, 1, 3, 2);

void main() {
  Render_Cmd cmd = cmds[gl_InstanceIndex];

  vec2 pos = cmd.position_and_size.xy;
  vec2 size = cmd.position_and_size.zw;

  vec2 vert_pos = positions[gl_VertexIndex];

  out_color = cmd.color;
  out_radius = cmd.f1;
  out_thickness = cmd.f2;
  out_size = size;
  out_uv = uvs[gl_VertexIndex];;
  out_border_color = cmd.border_color;
  out_flags = cmd.flags;

  if (cmd.flags.x == 1) {
	  out_uv = vec2(cmd.f1[uv_map[gl_VertexIndex]], cmd.f2[uv_map[gl_VertexIndex]]);
  }

  gl_Position = proj * vec4(vert_pos * size + pos + size / 2,
                            0.0, 1.0);
}
