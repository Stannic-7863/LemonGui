#version 330

in vec2 fragTexCoord;
out vec4 fragColor;

uniform vec4 color;
uniform vec2 rect_size;
uniform vec4 border_radius;

float sdRoundedBox( in vec2 p, in vec2 b, in vec4 r )
{
	r = r.zywx; 
	r.xy = (p.x>0.0)?r.xy : r.zw;
    r.x  = (p.y>0.0)?r.x  : r.y;
    vec2 q = abs(p)-b+r.x;
    return min(max(q.x,q.y),0.0) + length(max(q,0.0)) - r.x;
}

void main() {
	float sdf = sdRoundedBox(fragTexCoord * rect_size * 2 - rect_size  , rect_size, border_radius);
	float e = smoothstep(1.2,-1.2,sdf);
	
	fragColor = vec4(color.rgb,e);	
}
