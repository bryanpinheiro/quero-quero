shader_type canvas_item;
// converted from crt-consumer-1w.slang by slang2gdshader.py
// original: https://github.com/libretro/slang-shaders

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform float dummy2 : hint_range(0.0, 0.0, 0.0) = 0.0; //  [ ----CRT---- ]
uniform float u_sharp : hint_range(0.0, 0.5, 0.01) = 0.25; // Reverse Sharpness
uniform float u_warp : hint_range(0.0, 0.15, 0.01) = 0.08; // Curvature
uniform float u_overscanx : hint_range(0.3, 2.0, 0.05) = 0.3; // Overscan Horiz.
uniform float u_overscany : hint_range(0.3, 2.0, 0.05) = 0.3; // Overscan Vertic.
uniform float res_flash : hint_range(0.0, 1.0, 1.0) = 0.0; // Resolution Switch Glitch
uniform float u_scan : hint_range(0.0, 1.0, 0.05) = 0.45; // Scanlines Strength
uniform float u_wid : hint_range(2.0, 3.0, 1.0) = 2.0; // Mask Fine/Coarse
uniform float u_mask : hint_range(0.0, 1.0, 0.05) = 0.3; // Mask Strength
uniform float u_slot : hint_range(0.0, 1.0, 1.0) = 0.0; // Slot Mask On/Off
uniform float slot_str : hint_range(0.0, 1.0, 0.05) = 0.7; // Slot Mask Strength
uniform float u_deconv : hint_range(-2.0, 2.0, 0.05) = 0.3; // De-Convergence Horiz.
uniform float u_brightb : hint_range(1.0, 2.0, 0.05) = 1.35; // Bright Boost
uniform float u_vignette : hint_range(0.0, 0.5, 0.01) = 0.2; // Vignette
uniform float u_smptec : hint_range(0.0, 2.0, 1.0) = 0.0; // sRGB, SMPTE-C, Japan NTSC
uniform vec4 OriginalHistorySize1; // from uniform block

varying vec4 SourceSize;
varying vec4 OriginalSize;
varying vec4 OutputSize;
varying flat int frame_count;
varying vec2 vTexCoord;
varying vec2 invdims;
varying vec2 maskpos;
varying vec2 barrel;
float slot(vec2 pos)
{
    float odd = 1.0;
    if (fract(pos.x/(u_wid*2.0)) < 0.5) odd = 0.0;

 return slot_str*sin((pos.y+odd)*3.14159265358979323846)+1.0;
}

float res_glitch(vec2 uv, vec4 _bp_OriginalSize)
{
float flash_strength = 0.7;
float flash_width = 0.08;
float flash_decay = 0.92;

    float flashTimer = 0.0;

    float curx  = _bp_OriginalSize.x;
    float cury  = _bp_OriginalSize.y;
    float prevx = OriginalHistorySize1.x;
    float prevy = OriginalHistorySize1.y;

    
    if (curx != prevx || cury != prevy) flashTimer = 1.0;
    flashTimer *= flash_decay;

    float y = uv.y;
    float bar = exp( -pow((y - 0.50) / flash_width, 2.0) );
   
   return flashTimer*bar*flash_strength;
}

void fragment() {
	SourceSize = vec4(1.0 / SCREEN_PIXEL_SIZE, SCREEN_PIXEL_SIZE);
	OriginalSize = SourceSize;
	OutputSize = vec4(1.0 / SCREEN_PIXEL_SIZE, SCREEN_PIXEL_SIZE);
	frame_count = int(TIME * 60.0);
	vTexCoord = SCREEN_UV;
	invdims = u_deconv/SourceSize.xy;
	maskpos = vTexCoord.xy*OutputSize.xy*2.0/u_wid;
	barrel = vec2(1.0-u_warp*u_overscanx, 1.0-u_warp*u_overscany);
	vec2 interlace = OriginalSize.y >300.0? vec2(0.0, mod(float(frame_count), 2.0)) : vec2(0.0);
	float interl_lines = OriginalSize.y >300.0? 0.5 : 1.0;
	vec2 uv = vTexCoord;
	vec2 pos = uv;
	vec2 n = uv * 2.0 - 1.0;
	float rsq = dot(vec2(n), n);
	n *= 1.0 + u_warp*rsq*1.5;
	n -= n*(barrel*u_warp);
	n *= barrel;
	uv = (n + 1.0) * 0.5;
	vec2 corn   = min(pos, vec2(1.0-pos));
	corn.x = 0.0012/corn.x;
	float px = invdims.x;
	uv += interlace*1.0/SourceSize.y;
	vec2 offR = vec2(px, 0.0);
	vec2 offB = vec2(- px, 0.0);
	vec2 dx = vec2(1.0/SourceSize.x, 0.0);
	vec3 colG = texture(screen_texture, uv).rgb;
	vec3 colR = texture(screen_texture, uv + offR).rgb;
	vec3 colB = texture(screen_texture, uv + offB).rgb;
	vec3 col = vec3(colR.r, colG.g, colB.b);
	if (u_sharp > 0.0) { // 4 extra taps — skip when off
		vec3 sharpl  = texture(screen_texture, uv      -dx).rgb*(-u_sharp);
		vec3 sharpl2 = texture(screen_texture, uv - 2.0*dx).rgb*(u_sharp*0.1);
		vec3 sharpr  = texture(screen_texture, uv     + dx).rgb*(-u_sharp);
		vec3 sharpr2 = texture(screen_texture, uv + 2.0*dx).rgb*(u_sharp*0.1);
		col = col*(1.0 + u_sharp*1.8) + sharpl+sharpr+sharpl2+sharpr2;
	}
	if (u_smptec == 1.0)
		col *= transpose(mat3(vec3(0.8407, 0.0809, 0.0663), vec3(-0.0373, 0.9960, 0.0363), vec3(0.0089, -0.0411, 1.1619)));
	if (u_smptec == 2.0)
		col *= transpose(mat3(vec3(1.0617, -0.1145, 0.0702), vec3(0.1261, 0.8585, 0.0199), vec3(0.0196, -0.0606, 1.3597)));
	float scan = 0.5*sin((uv.y*SourceSize.y*interl_lines-0.25 - interlace.y)*6.2831852)+0.5;
	float mask = 0.5*sin((maskpos.x)*3.14159265358979323846)+0.5;
	col *= mix(1.0, scan, u_scan);
	if (u_slot == 1.0){
	mask *= slot(vTexCoord*OutputSize.xy);
	}
	col *= mix(u_brightb, mask, u_mask);
	if (res_flash == 1.0) col += res_glitch(uv, OriginalSize);
	float nl = length(n);
	float vig = 1.0 - u_vignette * nl * sqrt(nl);
	col *= vig;
	// off-tube pixels: the warp can push sampling outside the screen —
	// screen_texture clamps, which streaks edge rows. Real CRTs just
	// show black bezel there.
	if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0)
		col = vec3(0.0);
	if (u_warp > 0.0){
	if (corn.y <= corn.x || corn.x < 0.0001)
	col = vec3(0.0);}
	COLOR = vec4(col, 1.0);
}
