#version 460

layout(set = 1, binding = 0) uniform rect_data {
  vec4 position_and_size;
  vec4 radius;
  mat4 projection;
};

layout(location = 0) out vec2 out_size;
layout(location = 1) out vec2 out_uv;
layout(location = 2) out vec4 out_radius;

const vec2 positions[6] =
    vec2[](vec2(0.5, 0.5), vec2(-0.5, 0.5), vec2(-0.5, -0.5), vec2(0.5, 0.5),
           vec2(-0.5, -0.5), vec2(0.5, -0.5));

const vec2 uvs[6] = vec2[](vec2(1.0, 1.0), vec2(0.0, 1.0), vec2(0.0, 0.0),
                           vec2(1.0, 1.0), vec2(0.0, 0.0), vec2(1.0, 0.0));

void main() {
  vec2 in_pos = positions[gl_VertexIndex];
  gl_Position =
      projection * vec4(in_pos * position_and_size.zw + position_and_size.xy +
                            position_and_size.zw / 2,
                        1.0, 1.0);
  out_uv = uvs[gl_VertexIndex];
  out_size = position_and_size.zw;
  out_radius = radius;
}
