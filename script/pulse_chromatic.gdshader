shader_type canvas_item;
// pulse-alternate — positive score feedback that alternates between
// two looks each trigger:
//   fringe — RGB edge split only (pulse-chromatic)
//   paint  — full-frame false color + fringe (pulse-colorize)
//
// `mode` picks the behavior:
//   0 = auto (random ~50/50 per pulse, no game code needed)
//   1 = force fringe, 2 = force paint — flip it from code for a
//   STRICT alternation:
//       _pulse_mode = 2 - _pulse_mode   // toggles 1 <-> 2
//
// Same clock model as the other pulse shaders:
//   _clock += delta
//   material.set_shader_parameter("clock", _clock)
//   // on score:
//   material.set_shader_parameter("hit_time", _clock)

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;

uniform float hit_time = -10.0;                          // when the pulse started — set from code
uniform float clock = 0.0;                               // caller-fed clock; >0 overrides TIME

uniform int mode : hint_enum("Auto (random)", "Fringe only", "Paint only") = 0;

uniform float duration : hint_range(0.2, 2.0) = 0.6;     // total pulse life
uniform float fringe : hint_range(0.0, 1.0) = 0.7;       // RGB edge-split strength
uniform float intensity : hint_range(0.0, 1.0) = 0.85;   // paint coverage
uniform float hue_span : hint_range(0.5, 3.0) = 1.5;     // ramp wraps — >1 = rainbow bands
uniform float saturation : hint_range(0.0, 1.0) = 1.0;   // palette saturation

// bias/gain shaping — the Teleglitch envelope: sharp attack at ~15%
// of the pulse, then a long smooth decay.
float get_bias(float x, float bias) {
	return x / (((1.0 / bias) - 2.0) * (1.0 - x) + 1.0);
}

float get_gain(float x, float gain) {
	if (x < 0.5)
		return get_bias(x * 2.0, gain) / 2.0;
	return get_bias(x * 2.0 - 1.0, 1.0 - gain) / 2.0 + 0.5;
}

float prog_to_curv(float f) {
	const float PIKE = 0.15;
	if (f < PIKE)
		return get_gain(f / PIKE, 0.25);
	return 1.0 - get_bias((f - PIKE) / (1.0 - PIKE), 0.75);
}

// smooth hue ramp — wraps so 0 and 1 join cleanly
vec3 hue(float h) {
	vec3 k = mod(vec3(5.0, 3.0, 1.0) + h * 6.0, 6.0);
	return 1.0 - clamp(min(k, 4.0 - k), 0.0, 1.0);
}

// per-pulse constants are frame-uniform — hash once in vertex()
// (4 calls per fullscreen quad) instead of ~200k fragment calls
varying vec4 v_rot;          // rotation matrix packed as columns
varying float v_hue_offset;
varying float v_paint;       // resolved mode: 0 = fringe, 1 = paint

void vertex() {
	float rnd = fract(sin(hit_time * 43758.5453) * 43758.5453);
	v_hue_offset = rnd;
	v_paint = mode == 1 ? 0.0 : (mode == 2 ? 1.0 : step(0.5, rnd));
	float ang = rnd * 6.28318;
	v_rot = vec4(cos(ang), sin(ang), -sin(ang), cos(ang));
}

void fragment() {
	float elapsed = (clock > 0.0 ? clock : TIME) - hit_time;

	// idle fast-path — skip everything outside the pulse window
	if (elapsed < 0.0 || elapsed > duration) {
		COLOR = vec4(texture(screen_texture, SCREEN_UV).rgb, 1.0);
	} else {
		float envelope = prog_to_curv(clamp(elapsed / duration, 0.0, 1.0));

		// RGB edge fringe — 3-axis fan, rotated per pulse
		vec2 offs = SCREEN_PIXEL_SIZE * (envelope * fringe * 30.0);
		vec3 fringed;
		fringed.r = texture(screen_texture,
			SCREEN_UV + vec2(dot(v_rot.xz, vec2(0.0, 0.707)),
			                 dot(v_rot.yw, vec2(0.0, 0.707))) * offs).r;
		fringed.g = texture(screen_texture,
			SCREEN_UV + vec2(dot(v_rot.xz, vec2(0.707, -0.707)),
			                 dot(v_rot.yw, vec2(0.707, -0.707))) * offs).g;
		fringed.b = texture(screen_texture,
			SCREEN_UV + vec2(dot(v_rot.xz, vec2(-0.707, -0.707)),
			                 dot(v_rot.yw, vec2(-0.707, -0.707))) * offs).b;

		vec3 color;
		if (v_paint > 0.5) {
			// paint mode — luminance drives the hue ramp; image
			// contrast preserved, whole frame colored
			vec3 src = texture(screen_texture, SCREEN_UV).rgb;
			float lum = dot(src, vec3(0.299, 0.587, 0.114));
			vec3 painted = hue(fract(lum * hue_span + v_hue_offset)) * lum;
			painted = mix(vec3(lum), painted, saturation);
			painted *= 1.15;   // vibrancy pop
			color = mix(fringed, painted, envelope * intensity);
		} else {
			// fringe-only mode — edges split, frame keeps its colors
			color = fringed;
		}

		COLOR = vec4(color, 1.0);
	}
}
