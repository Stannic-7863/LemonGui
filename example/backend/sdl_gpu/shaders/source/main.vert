#version 460

struct Render_Cmd {
  vec4 radius;
  vec4 position_and_size;
  int rect_index;
  int border_index;
  int text_index;
};

struct Text {
  vec2 pos;
  vec2 uv;
  vec4 color;
};

struct Border {
  vec4 thickness;
  vec4 color[4];
};

struct Rect {
  vec4 color;
};

layout(set = 0, binding = 0) readonly buffer Rects { Rect rects[]; };
layout(set = 0, binding = 1) readonly buffer Borders { Border borders[]; };
layout(set = 0, binding = 2) readonly buffer Texts { Text texts[]; };
layout(set = 0, binding = 3) readonly buffer Render_Cmds { Render_Cmd cmds[]; };
layout(set = 1, binding = 0) uniform mats { mat4 proj; };

layout(location = 0) out vec4 out_color;
layout(location = 1) out vec4 out_radius;
layout(location = 2) out vec4 out_thickness;
layout(location = 3) out vec2 out_size;
layout(location = 4) out vec2 out_uv;
layout(location = 5) out vec4 out_border_color[4];

const vec2 positions[6] =
    vec2[](vec2(0.5, 0.5), vec2(-0.5, 0.5), vec2(-0.5, -0.5), vec2(0.5, 0.5),
           vec2(-0.5, -0.5), vec2(0.5, -0.5));

const vec2 uvs[6] = vec2[](vec2(1.0, 1.0), vec2(0.0, 1.0), vec2(0.0, 0.0),
                           vec2(1.0, 1.0), vec2(0.0, 0.0), vec2(1.0, 0.0));

void main() {
  Render_Cmd cmd = cmds[gl_InstanceIndex];
  vec2 size = cmd.position_and_size.zw;

  vec2 in_pos = positions[gl_VertexIndex];
  vec2 in_uv = uvs[gl_VertexIndex];

  gl_Position = proj * vec4(in_pos * size + cmd.position_and_size.xy + size / 2,
                            1.0, 1.0);

  out_color = vec4(0.0);
  out_thickness = vec4(0.0);
  out_radius = cmd.radius;
  out_size = size;
  out_uv = in_uv;

  if (cmd.rect_index >= 0) {
    out_color = rects[cmd.rect_index].color;
  }

  if (cmd.border_index >= 0) {
    out_thickness = borders[cmd.border_index].thickness;
    out_border_color = borders[cmd.border_index].color;
  }
}
