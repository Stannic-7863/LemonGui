#version 460

layout(location = 0) in vec2 size;
layout(location = 1) in vec2 uv;
layout(location = 2) in vec4 radius;

float sdf_rounded_rect(vec2 p, vec2 half_size, float radius) {
  vec2 q = abs(p) - half_size + radius;
  return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - radius;
}

void main() {
  vec2 sample_location = uv * size - size / 2;

  float selected_border_radius;

  if (sample_location.x > 0.0) {
    selected_border_radius = (sample_location.y < 0.0) ? radius.y : radius.z;
  } else {
    selected_border_radius = (sample_location.y < 0.0) ? radius.x : radius.w;
  }

  float sdf =
      sdf_rounded_rect(sample_location, size / 2, selected_border_radius);

  float alpha = 1 - smoothstep(0, 1.0, sdf);

  if (!(alpha > 0.0)) {
    discard;
  }
}
