#version 460

layout(location = 0) in vec4 in_color;
layout(location = 1) in vec4 in_radius;
layout(location = 2) in vec4 in_border_thickness;
layout(location = 3) in vec2 in_size;
layout(location = 4) in vec2 in_uv;
layout(location = 5) in vec4 in_border_color[4];
layout(location = 9) flat in ivec4 in_flags;

layout(set = 2, binding = 0) uniform sampler2D font_sampler;

layout(location = 0) out vec4 out_color;

float rect_select_side(vec2 pos, vec4 s) {
    s.xy = pos.x < 0 ? s.xw : s.yz;
    s.x = pos.y > 0 ? s.x : s.y;
    return s.x;
}

vec4 rect_get_blended_border_color(vec2 p, vec2 half_size) {
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

float sdf_rect(vec2 pos, vec2 half_size, float radius) {
    vec2 q = abs(pos) - half_size + radius;
    return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) -
        radius; // NEGATIVE inside, POSITIVE outside
}

float sdf_inner_rect(vec2 pos, vec2 half_size, vec4 thickness,
    float rad_outer) {
    vec2 inner_half =
        half_size -
            vec2(thickness.w + thickness.y, thickness.x + thickness.z) * 0.5;

    vec2 offset =
        vec2(thickness.w - thickness.y, thickness.x - thickness.z) * 0.5;

    vec2 s = sign(pos);
    float t_corner = (s.x < 0.0) ? ((s.y < 0.0) ? max(thickness.w, thickness.x) : max(thickness.w, thickness.z)) : ((s.y < 0.0) ? max(thickness.y, thickness.x) : max(thickness.y, thickness.z));

    float rad_inner = max(0.0, rad_outer - t_corner);

    return sdf_rect(pos - offset, inner_half, rad_inner);
}
void main() {
    if (in_flags.x == 0) {
        vec2 h_size = in_size * 0.5;
        vec2 s_pos = in_uv * in_size - h_size;
        float rad = rect_select_side(s_pos, in_radius);
        float aa = 1.0;

        float sdf_outer = sdf_rect(s_pos, h_size, rad);
        float sdf_inner = sdf_inner_rect(s_pos, h_size, in_border_thickness, rad);
        float outer_mask = smoothstep(aa, -aa, sdf_outer);
        float fill_mask = smoothstep(aa, -aa, sdf_inner);
        float border_mask = smoothstep(-aa, aa, sdf_inner);

        // premultiply
        vec4 fill_col = vec4(in_color.rgb * in_color.a, in_color.a);

        vec4 border_col = rect_get_blended_border_color(s_pos, h_size);
        vec4 border_col_premul = vec4(border_col.rgb * border_col.a, border_col.a);

        out_color = fill_col * fill_mask;
        out_color += border_col_premul * outer_mask * border_mask;
    } else {
        vec4 t = texture(font_sampler, in_uv);
        out_color = vec4(in_color.rgb * in_color.a, in_color.a) * t.a;
    }
}
