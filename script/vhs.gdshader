shader_type canvas_item;
// converted from vhs.slang by slang2gdshader.py
// original: https://github.com/libretro/slang-shaders
// OSD "play" icon overlay removed (depended on a texture that doesn't exist).

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform float wiggle : hint_range(0.0, 5.0, 0.1) = 1.0; // Wiggle
uniform float smear : hint_range(0.0, 1.0, 0.05) = 0.5; // Chroma Smear

varying flat int frame_count;
varying vec2 vTexCoord;
vec3 rgb2yiq(vec3 c){
	return vec3((0.2989*c.x + 0.5959*c.y + 0.2115*c.z), (0.5870*c.x - 0.2744*c.y - 0.5229*c.z), (0.1140*c.x - 0.3216*c.y + 0.3114*c.z));
}

vec3 yiq2rgb(vec3 c){
	return vec3((1.0*c.x	+ 1.0*c.y	+ 1.0*c.z), (0.956*c.x	- 0.2720*c.y	- 1.1060*c.z), (0.6210*c.x	- 0.6474*c.y	+ 1.7046*c.z));
}

vec2 Circle(float Start, float Points, float Point)
{
	float Rad = (3.141592 * 2.0 * (1.0 / Points)) * (Point + Start);

		return vec2(-(.3+Rad), cos(Rad));

}

vec3 Blur(vec2 uv, float d, sampler2D _bp_TEXTURE){
    vec2 PixelOffset=vec2(d, 0.0);

    float Start = 2.0 / 14.0;
    vec2 Scale = 0.66 * 4.0 * 2.0 * PixelOffset.xy;

    vec3 N0 = texture(_bp_TEXTURE, uv + Circle(Start, 14.0, 0.0) * Scale).rgb;
    vec3 N1 = texture(_bp_TEXTURE, uv + Circle(Start, 14.0, 1.0) * Scale).rgb;
    vec3 N2 = texture(_bp_TEXTURE, uv + Circle(Start, 14.0, 2.0) * Scale).rgb;
    vec3 N3 = texture(_bp_TEXTURE, uv + Circle(Start, 14.0, 3.0) * Scale).rgb;
    vec3 N4 = texture(_bp_TEXTURE, uv + Circle(Start, 14.0, 4.0) * Scale).rgb;
    vec3 N5 = texture(_bp_TEXTURE, uv + Circle(Start, 14.0, 5.0) * Scale).rgb;
    vec3 N6 = texture(_bp_TEXTURE, uv + Circle(Start, 14.0, 6.0) * Scale).rgb;
    vec3 N7 = texture(_bp_TEXTURE, uv + Circle(Start, 14.0, 7.0) * Scale).rgb;
    vec3 N8 = texture(_bp_TEXTURE, uv + Circle(Start, 14.0, 8.0) * Scale).rgb;
    vec3 N9 = texture(_bp_TEXTURE, uv + Circle(Start, 14.0, 9.0) * Scale).rgb;
    vec3 N10 = texture(_bp_TEXTURE, uv + Circle(Start, 14.0, 10.0) * Scale).rgb;
    vec3 N11 = texture(_bp_TEXTURE, uv + Circle(Start, 14.0, 11.0) * Scale).rgb;
    vec3 N12 = texture(_bp_TEXTURE, uv + Circle(Start, 14.0, 12.0) * Scale).rgb;
    vec3 N13 = texture(_bp_TEXTURE, uv + Circle(Start, 14.0, 13.0) * Scale).rgb;
    vec3 N14 = texture(_bp_TEXTURE, uv).rgb;

    float W = 1.0 / 15.0;

    vec3 clr =
		(N0 * W) +
		(N1 * W) +
		(N2 * W) +
		(N3 * W) +
		(N4 * W) +
		(N5 * W) +
		(N6 * W) +
		(N7 * W) +
		(N8 * W) +
		(N9 * W) +
		(N10 * W) +
		(N11 * W) +
		(N12 * W) +
		(N13 * W) +
		(N14 * W);
    return clr;
}

float onOff(float a, float b, float c, float framecount)
{
	return step(c, sin((framecount * 0.001) + a*cos((framecount * 0.001)*b)));
}

vec2 jumpy(vec2 uv, float framecount)
{
	vec2 look = uv;
	float window = 1.0/(1.0+80.0*(look.y-mod(framecount/4.0, 1.0))*(look.y-mod(framecount/4.0, 1.0)));
	look.x += 0.05 * sin(look.y*10.0 + framecount)/20.0*onOff(4.0,4.0,.3, framecount)*(0.5+cos(framecount*20.0))*window;
	float vShift = (0.1*wiggle) * 0.4*onOff(2.0,3.0,.9, framecount)*(sin(framecount)*sin(framecount*20.0) +
										 (0.5 + 0.1*sin(framecount*200.0)*cos(framecount)));
	look.y = mod(look.y - 0.01 * vShift, 1.0);
	return look;
}

void fragment() {
	frame_count = int(TIME * 60.0);
	vTexCoord = SCREEN_UV;
	float fc7 = mod(float(frame_count), 7.0);  // was recomputed ~10x
	float d = .1-round(mod(fc7/3.0, 1.0))*.1;
	vec2 uv = jumpy(vTexCoord.xy, fc7);
	float s = 0.0001 * wiggle * -d + 0.0001 * wiggle * sin(fc7);
	float e = min(.30, pow(max(0.0, cos(uv.y*4.0+.3)-.75)*(s+0.5)*1.0, 3.0))*25.0;
	float r = fc7*(2.0*s);
	uv.x += abs(r*pow(min(.003, (-uv.y+(.01*mod(fc7, 17.0))))*3.0, 2.0));
	d = .051+abs(sin(s/4.0));
	float c = max(0.0001, .002*d) * smear;
	vec4 final;
	if (smear > 0.0) {
		final.xyz =Blur(uv,c+c*(uv.x), screen_texture);
		float y = rgb2yiq(final.xyz).r;
		uv.x += .01*d;
		c *= 6.0;
		final.xyz =Blur(uv,c, screen_texture);
		float i = rgb2yiq(final.xyz).g;
		uv.x += .005*d;
		c *= 2.50;
		final.xyz =Blur(uv,c, screen_texture);
		float q = rgb2yiq(final.xyz).b;
		final = vec4(yiq2rgb(vec3(y, i, q)), 1.0);
	} else {
		final = texture(screen_texture, uv);
	}
	final.xyz -= pow(s+e*2.0, 3.0);
	COLOR = final;
}
