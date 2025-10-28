#version 460

struct Render_Cmd {
  vec4 radius;
  vec4 position_and_size;
  int rect_index;
  int border_index;
  int text_index;
};

struct Text {
  vec2 uv[4];
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
layout(location = 9) out int out_render_type;

const vec2 positions[6] =
    vec2[](vec2(0.5, 0.5), vec2(-0.5, 0.5), vec2(-0.5, -0.5), vec2(0.5, 0.5),
           vec2(-0.5, -0.5), vec2(0.5, -0.5));

const vec2 uvs[6] = vec2[](vec2(1.0, 1.0), vec2(0.0, 1.0), vec2(0.0, 0.0),
                           vec2(1.0, 1.0), vec2(0.0, 0.0), vec2(1.0, 0.0));

const int uv_map[6] = int[](1, 0, 3, 1, 3, 2);

void main() {
  Render_Cmd cmd = cmds[gl_InstanceIndex];

  vec2 in_pos = positions[gl_VertexIndex];
  vec2 in_uv = uvs[gl_VertexIndex];
  vec2 size = cmd.position_and_size.zw;

  out_radius = vec4(0.0);
  out_color = vec4(0.0);
  out_thickness = vec4(0.0);
  out_uv = vec2(0.0);
  out_border_color = vec4[](vec4(0.0), vec4(0.0), vec4(0.0), vec4(0.0));

  if (cmd.text_index < 0) {
    gl_Position =
        proj *
        vec4(in_pos * size + cmd.position_and_size.xy + size / 2, 1.0, 1.0);

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
    out_render_type = 0;
  } else {
    Text text = texts[cmd.text_index];

    gl_Position =
        proj *
        vec4(in_pos * size + cmd.position_and_size.xy + size / 2, 1.0, 1.0);

    vec2 uv;
    uv = text.uv[uv_map[gl_VertexIndex]];

    out_uv = uv;
    out_size = vec2(10, 10);
    out_color = text.color;
    out_render_type = 1;
  }
}
