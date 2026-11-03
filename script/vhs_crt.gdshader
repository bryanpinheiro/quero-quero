shader_type canvas_item;
// vhs-crt — merged VHS + consumer-CRT in a single node: tape wiggle,
// chroma smear (YIQ blur), barrel warp, de-convergence, sharpening,
// scanlines, mask, vignette and bezel — one shader, one rect, and NO
// BackBufferCopy between stages (saves a full-screen copy vs stacking
// vhs.gdshader + crt-consumer-1w.gdshader).
// Note: in a real two-pass stack the CRT taps read post-VHS pixels;
// here they read the raw frame at the wiggled+warped coordinate —
// visually near-identical, the smear is low-frequency anyway.

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;

// ---- VHS ----
uniform float wiggle : hint_range(0.0, 5.0, 0.1) = 0.7; // Wiggle
uniform float smear : hint_range(0.0, 1.0, 0.05) = 0.5; // Chroma Smear

// ---- CRT ----
uniform float u_sharp : hint_range(0.0, 0.5, 0.01) = 0.25; // Reverse Sharpness
uniform float u_warp : hint_range(0.0, 0.15, 0.01) = 0.08; // Curvature
uniform float u_overscanx : hint_range(0.3, 2.0, 0.05) = 0.3; // Overscan Horiz.
uniform float u_overscany : hint_range(0.3, 2.0, 0.05) = 0.3; // Overscan Vertic.
uniform float u_scan : hint_range(0.0, 1.0, 0.05) = 0.45; // Scanlines Strength
uniform float u_wid : hint_range(2.0, 3.0, 1.0) = 2.0; // Mask Fine/Coarse
uniform float u_mask : hint_range(0.0, 1.0, 0.05) = 0.3; // Mask Strength
uniform float u_slot : hint_range(0.0, 1.0, 1.0) = 0.0; // Slot Mask On/Off
uniform float slot_str : hint_range(0.0, 1.0, 0.05) = 0.7; // Slot Mask Strength
uniform float u_deconv : hint_range(-2.0, 2.0, 0.05) = 0.3; // De-Convergence Horiz.
uniform float u_brightb : hint_range(1.0, 2.0, 0.05) = 1.35; // Bright Boost
uniform float u_vignette : hint_range(0.0, 0.5, 0.01) = 0.2; // Vignette
uniform float u_smptec : hint_range(0.0, 2.0, 1.0) = 0.0; // sRGB, SMPTE-C, Japan NTSC

varying flat int frame_count;

// ======================= VHS stage =======================

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

vec3 Blur(vec2 uv, float d){
    vec2 PixelOffset=vec2(d, 0.0);
    float Start = 2.0 / 14.0;
    vec2 Scale = 0.66 * 4.0 * 2.0 * PixelOffset.xy;

    vec3 clr = vec3(0.0);
    float W = 1.0 / 15.0;
    for (int k = 0; k < 14; k++)
        clr += texture(screen_texture, uv + Circle(Start, 14.0, float(k)) * Scale).rgb * W;
    clr += texture(screen_texture, uv).rgb * W;
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

// ======================= CRT helpers =======================

uniform vec4 OriginalHistorySize1; // from uniform block

float slot(vec2 pos)
{
    float odd = 1.0;
    if (fract(pos.x/(u_wid*2.0)) < 0.5) odd = 0.0;
    return slot_str*sin((pos.y+odd)*3.14159265358979323846)+1.0;
}

// ======================= merged pass =======================

void fragment() {
	frame_count = int(TIME * 60.0);
	vec2 vTexCoord = SCREEN_UV;

	// ---- CRT barrel warp (positions the final sample) ----
	vec4 SourceSize = vec4(1.0 / SCREEN_PIXEL_SIZE, SCREEN_PIXEL_SIZE);
	vec4 OriginalSize = SourceSize;
	vec2 maskpos = vTexCoord.xy*SourceSize.xy*2.0/u_wid;
	vec2 barrel = vec2(1.0-u_warp*u_overscanx, 1.0-u_warp*u_overscany);
	vec2 pos = vTexCoord;
	vec2 n = vTexCoord * 2.0 - 1.0;
	float rsq = dot(vec2(n), n);
	n *= 1.0 + u_warp*rsq*1.5;
	n -= n*(barrel*u_warp);
	n *= barrel;
	vec2 wuv = (n + 1.0) * 0.5;
	vec2 corn = min(pos, vec2(1.0-pos));
	corn.x = 0.0012/corn.x;

	// ---- VHS stage at the warped coordinate ----
	float fc7 = mod(float(frame_count), 7.0);
	float d = .1-round(mod(fc7/3.0, 1.0))*.1;
	vec2 uv = jumpy(wuv, fc7);
	float s = 0.0001 * wiggle * -d + 0.0001 * wiggle * sin(fc7);
	float e = min(.30, pow(max(0.0, cos(uv.y*4.0+.3)-.75)*(s+0.5)*1.0, 3.0))*25.0;
	float r = fc7*(2.0*s);
	uv.x += abs(r*pow(min(.003, (-uv.y+(.01*mod(fc7, 17.0))))*3.0, 2.0));
	d = .051+abs(sin(s/4.0));
	float c = max(0.0001, .002*d) * smear;

	vec3 vhs_col;
	if (smear > 0.0) {
		vec3 b1 = Blur(uv, c+c*(uv.x));
		float y = rgb2yiq(b1).r;
		uv.x += .01*d;
		c *= 6.0;
		vec3 b2 = Blur(uv, c);
		float i = rgb2yiq(b2).g;
		uv.x += .005*d;
		c *= 2.50;
		vec3 b3 = Blur(uv, c);
		float q = rgb2yiq(b3).b;
		vhs_col = yiq2rgb(vec3(y, i, q));
	} else {
		vhs_col = texture(screen_texture, uv).rgb;
	}
	vhs_col -= pow(s+e*2.0, 3.0);

	// ---- CRT spatial stage (deconv + sharp taps around vuv) ----
	float px = u_deconv/SourceSize.x;
	vec2 dx = vec2(1.0/SourceSize.x, 0.0);
	vec3 colG = texture(screen_texture, uv).rgb;
	vec3 colR = texture(screen_texture, uv + vec2(px, 0.0)).rgb;
	vec3 colB = texture(screen_texture, uv - vec2(px, 0.0)).rgb;
	vec3 col = vec3(colR.r, colG.g, colB.b);
	if (u_sharp > 0.0) { // 4 extra taps — skip when off
		vec3 sharpl  = texture(screen_texture, uv      -dx).rgb*(-u_sharp);
		vec3 sharpl2 = texture(screen_texture, uv - 2.0*dx).rgb*(u_sharp*0.1);
		vec3 sharpr  = texture(screen_texture, uv     + dx).rgb*(-u_sharp);
		vec3 sharpr2 = texture(screen_texture, uv + 2.0*dx).rgb*(u_sharp*0.1);
		col = col*(1.0 + u_sharp*1.8) + sharpl+sharpr+sharpl2+sharpr2;
	}
	// mix the spatial CRT stage with the smeared VHS signal —
	// smear is the dominant look when enabled
	col = smear > 0.0 ? mix(col, vhs_col, 0.7) : vhs_col;

	if (u_smptec == 1.0)
		col *= transpose(mat3(vec3(0.8407, 0.0809, 0.0663), vec3(-0.0373, 0.9960, 0.0363), vec3(0.0089, -0.0411, 1.1619)));
	if (u_smptec == 2.0)
		col *= transpose(mat3(vec3(1.0617, -0.1145, 0.0702), vec3(0.1261, 0.8585, 0.0199), vec3(0.0196, -0.0606, 1.3597)));

	// ---- CRT post stage ----
	vec2 interlace = OriginalSize.y >300.0? vec2(0.0, mod(float(frame_count), 2.0)) : vec2(0.0);
	float interl_lines = OriginalSize.y >300.0? 0.5 : 1.0;
	float scan = 0.5*sin((uv.y*SourceSize.y*interl_lines-0.25 - interlace.y)*6.2831852)+0.5;
	float mask = 0.5*sin((maskpos.x)*3.14159265358979323846)+0.5;
	col *= mix(1.0, scan, u_scan);
	if (u_slot == 1.0){
		mask *= slot(vTexCoord*SourceSize.xy);
	}
	col *= mix(u_brightb, mask, u_mask);
	float nl = length(n);
	float vig = 1.0 - u_vignette * nl * sqrt(nl);
	col *= vig;

	// off-tube pixels: real CRTs show black bezel there
	if (wuv.x < 0.0 || wuv.x > 1.0 || wuv.y < 0.0 || wuv.y > 1.0)
		col = vec3(0.0);
	if (u_warp > 0.0){
		if (corn.y <= corn.x || corn.x < 0.0001)
			col = vec3(0.0);
	}
	COLOR = vec4(col, 1.0);
}
