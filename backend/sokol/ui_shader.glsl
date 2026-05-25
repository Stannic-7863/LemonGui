@header package sokol_backend
@header import sg "./sokol-odin/sokol/gfx"

@block render_cmd
struct Render_Cmd {
    vec4 position_and_size;
    vec4 f1;
    vec4 f2;
    vec4 color;
    vec4 border_color[4];
    ivec4 flags;
};
@end

@block clip_types
struct Clip {
    vec4 position_and_size;
    vec4 radius;
};

struct Clip_Index {
    int value;
};
@end

@vs ui_vs
@include_block render_cmd

layout(binding=0) uniform ui_vs_params {
    mat4 view;
};

layout(binding=1) readonly buffer render_cmds_ssbo {
    Render_Cmd cmds[];
};

layout(location=0) out vec4 out_color;
layout(location=1) out vec4 out_radius;
layout(location=2) out vec4 out_thickness;
layout(location=3) out vec2 out_size;
layout(location=4) out vec2 out_uv;
layout(location=5) out vec4 out_border_color[4];
layout(location=9) out flat ivec4 out_flags;
layout(location=10) out vec2 out_screen_pos;

const vec2 positions[6] = vec2[](
    vec2(0.5, 0.5),
    vec2(-0.5, 0.5),
    vec2(-0.5, -0.5),

    vec2(0.5, 0.5),
    vec2(-0.5, -0.5),
    vec2(0.5, -0.5)
);

const vec2 uvs[6] = vec2[](
    vec2(1.0, 1.0),
    vec2(0.0, 1.0),
    vec2(0.0, 0.0),

    vec2(1.0, 1.0),
    vec2(0.0, 0.0),
    vec2(1.0, 0.0)
);

const int uv_map[6] = int[](1, 0, 3, 1, 3, 2);

void main() {
    Render_Cmd cmd = cmds[gl_InstanceIndex];

    vec2 pos = cmd.position_and_size.xy;
    vec2 size = cmd.position_and_size.zw;
    vec2 vert_pos = positions[gl_VertexIndex];

    out_screen_pos = vert_pos * size + pos + size * 0.5;
    out_color = cmd.color;
    out_radius = cmd.f1;
    out_thickness = cmd.f2;
    out_size = size;
    out_uv = uvs[gl_VertexIndex];
    out_border_color = cmd.border_color;
    out_flags = cmd.flags;

    if (cmd.flags.x == 1) {
        out_uv = vec2(cmd.f1[uv_map[gl_VertexIndex]], cmd.f2[uv_map[gl_VertexIndex]]);
    }

    gl_Position = view * vec4(vert_pos * size + pos + size * 0.5, 0.0, 1.0);
}
@end

@fs ui_fs
@include_block clip_types

layout(binding=2) readonly buffer clips_ssbo {
    Clip clips[];
};

layout(binding=3) readonly buffer clip_indices_ssbo {
    Clip_Index clips_indices[];
};

layout(binding=4) uniform texture2D font_tex;
layout(binding=5) uniform sampler font_smp;

layout(location=0) in vec4 out_color;
layout(location=1) in vec4 out_radius;
layout(location=2) in vec4 out_thickness;
layout(location=3) in vec2 out_size;
layout(location=4) in vec2 out_uv;
layout(location=5) in vec4 out_border_color[4];
layout(location=9) flat in ivec4 out_flags;
layout(location=10) in vec2 out_screen_pos;

out vec4 frag_color;

float rect_select_side(vec2 pos, vec4 s) {
    s.xy = pos.x < 0.0 ? s.xw : s.yz;
    s.x = pos.y < 0.0 ? s.x : s.y;
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

    return (
        out_border_color[3] * wl +
        out_border_color[0] * wt +
        out_border_color[1] * wr +
        out_border_color[2] * wb
    ) / (wl + wt + wr + wb);
}

float sdf_rect(vec2 pos, vec2 half_size, float radius) {
    vec2 q = abs(pos) - half_size + radius;
    return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - radius;
}

float sdf_inner_rect(vec2 pos, vec2 half_size, vec4 thickness, float rad_outer) {
    vec2 inner_half = half_size - vec2(thickness.w + thickness.y, thickness.x + thickness.z) * 0.5;

    vec2 offset = vec2(thickness.w - thickness.y, thickness.x - thickness.z) * 0.5;

    vec2 s = sign(pos);

    float t_corner =
        (s.x < 0.0)
            ? ((s.y < 0.0) ? max(thickness.w, thickness.x) : max(thickness.w, thickness.z))
            : ((s.y < 0.0) ? max(thickness.y, thickness.x) : max(thickness.y, thickness.z));

    return sdf_rect(pos - offset, inner_half, max(0.0, rad_outer - t_corner));
}

float sdf_clip_rect(vec2 frag_pos, vec4 pos_size, vec4 radius) {
    vec2 center = pos_size.xy + pos_size.zw * 0.5;
    vec2 half_size = pos_size.zw * 0.5;

    vec2 p = frag_pos - center;
    float r = rect_select_side(p, radius);
    vec2 q = abs(p) - half_size + r;

    return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

void do_clip_test() {
    if (out_flags.z <= 0) {
        return;
    }

    for (int i = out_flags.z - 1; i >= 0; i--) {
        int idx = clips_indices[out_flags.y + i].value;
        Clip clip = clips[idx];

        if (sdf_clip_rect(out_screen_pos, clip.position_and_size, clip.radius) > 0.0) {
            discard;
        }
    }
}

vec4 render_rect() {
    vec2 h_size = out_size * 0.5;
    vec2 s_pos = out_uv * out_size - h_size;

    float rad = rect_select_side(s_pos, out_radius);
    float aa = 1.0;

    float sdf_outer = sdf_rect(s_pos, h_size, rad);
    float sdf_inner = sdf_inner_rect(s_pos, h_size, out_thickness, rad);

    float outer_mask = smoothstep(aa, -aa, sdf_outer);
    float fill_mask = smoothstep(aa, -aa, sdf_inner);

    vec4 fill_col = vec4(out_color.rgb * out_color.a, out_color.a);

    vec4 border_col = rect_get_blended_border_color(s_pos, h_size);

    vec4 border_col_pre = vec4(
        border_col.rgb * border_col.a,
        border_col.a
    );

    vec4 color = fill_col * fill_mask;

    color += border_col_pre * max(0.0, outer_mask - fill_mask);

    return color;
}

vec4 render_text() {
    float a = texture(sampler2D(font_tex, font_smp), out_uv).r;

    return vec4(out_color.rgb * out_color.a, out_color.a) * a;
}

void main() {
    do_clip_test();

    frag_color = (out_flags.x == 0) ? render_rect() : render_text();
}
@end

@program ui ui_vs ui_fs
