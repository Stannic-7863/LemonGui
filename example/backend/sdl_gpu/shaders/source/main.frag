#version 460

layout(location = 0) in vec4 in_color;
layout(location = 1) in vec4 in_radius;
layout(location = 2) in vec4 in_border_thickness;
layout(location = 3) in vec2 in_size;
layout(location = 4) in vec2 in_uv;
layout(location = 5) in vec4 in_border_color[4];
layout(location = 9) flat in int in_render_type;

layout(set = 2, binding = 0) uniform sampler2D font_sampler;

layout(location = 0) out vec4 out_color;

float sdf_rounded_rect(vec2 p, vec2 half_size, float radius) {
  vec2 q = abs(p) - half_size + radius;
  return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - radius;
}

vec4 blended_border_color(vec2 p, vec2 half_size) {
  float d_left = abs(p.x + half_size.x);
  float d_right = abs(p.x - half_size.x);
  float d_top = abs(p.y + half_size.y);
  float d_bottom = abs(p.y - half_size.y);

  float wl = 1.0 / (d_left + 1e-9);
  float wr = 1.0 / (d_right + 1e-9);
  float wt = 1.0 / (d_top + 1e-9);
  float wb = 1.0 / (d_bottom + 1e-9);

  vec4 color = (in_border_color[3] * wl + in_border_color[0] * wt +
                in_border_color[1] * wr + in_border_color[2] * wb) /
               (wl + wt + wr + wb);

  return color;
}

float blended_border_thickness(vec2 p, vec2 half_size) {
  float d_left = abs(p.x + half_size.x);
  float d_right = abs(p.x - half_size.x);
  float d_top = abs(p.y + half_size.y);
  float d_bottom = abs(p.y - half_size.y);

  float wl = 1.0 / (d_left + 1e-2);
  float wr = 1.0 / (d_right + 1e-2);
  float wt = 1.0 / (d_top + 1e-2);
  float wb = 1.0 / (d_bottom + 1e-2);

  float thickness =
      (in_border_thickness[3] * wl + in_border_thickness[0] * wt +
       in_border_thickness[1] * wr + in_border_thickness[2] * wb) /
      (wl + wt + wr + wb);

  return thickness;
}

void main() {
  vec2 half_size = in_size * 0.5;
  vec2 sample_location = in_uv * in_size - in_size / 2;
  float inner_border_radius;
  float outer_border_radius;

  if (sample_location.x > 0.0) {
    outer_border_radius = (sample_location.y < 0.0) ? in_radius.y : in_radius.z;
  } else {
    outer_border_radius = (sample_location.y < 0.0) ? in_radius.x : in_radius.w;
  }

  float outer_dist =
      sdf_rounded_rect(sample_location, half_size, outer_border_radius);

  inner_border_radius = outer_border_radius -
                        blended_border_thickness(sample_location, half_size);
  ;

  vec2 inner_half_size = half_size;

  if (sample_location.x > 0.0) {
    inner_half_size.x -= in_border_thickness[1];
  } else {
    inner_half_size.x -= in_border_thickness[0];
  }

  if (sample_location.y > 0.0) {
    inner_half_size.y -= in_border_thickness[3];
  } else {
    inner_half_size.y -= in_border_thickness[2];
  }

  float inner_dist =
      sdf_rounded_rect(sample_location, inner_half_size, inner_border_radius);

  float outer_alpha = 1.0 - smoothstep(-0.5, 1.5, outer_dist);
  float inner_alpha = 1.0 - smoothstep(-0.5, 1.5, inner_dist);
  float border_mask = clamp(outer_alpha - inner_alpha, -1, 1.0);

  out_color = vec4(in_color.rgb, in_color.a * inner_alpha);

  if (border_mask > 0) {
    vec4 border_color = blended_border_color(sample_location, half_size);
    out_color = mix(out_color, border_color, border_mask);
  }

  if (in_render_type == 1) {
    out_color = texture(font_sampler, in_uv) * in_color;
  }
}
