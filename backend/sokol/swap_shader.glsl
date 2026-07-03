@header package sokol_backend
@header import sg "./sokol-odin/sokol/gfx"

@vs swap_vs

out vec2 uv;

const vec2 positions[6] = vec2[](
    vec2( 1.0,  1.0),
    vec2(-1.0,  1.0),
    vec2(-1.0, -1.0),
    vec2( 1.0,  1.0),
    vec2(-1.0, -1.0),
    vec2( 1.0, -1.0)
);

const vec2 uvs[6] = vec2[](
    vec2(1.0, 1.0),
    vec2(0.0, 1.0),
    vec2(0.0, 0.0),
    vec2(1.0, 1.0),
    vec2(0.0, 0.0),
    vec2(1.0, 0.0)
);

void main() {
    gl_Position = vec4(positions[gl_VertexIndex], 0.0, 1.0);
    uv = uvs[gl_VertexIndex];
}
@end

@fs swap_fs

layout(binding=0) uniform texture2D swap_tex;
layout(binding=1) uniform sampler swap_smp;

in vec2 uv;
out vec4 frag_color;

void main() {
    frag_color = texture(sampler2D(swap_tex, swap_smp), uv);
}
@end

@program swap swap_vs swap_fs
