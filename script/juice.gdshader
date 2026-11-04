shader_type canvas_item;
// ============================================================================
// juice.gdshader — merged gameplay feedback: 3 effects, ONE fullscreen pass.
//
// Replaces the old chain of 3 ColorRects + 3 BackBufferCopies:
//     hit-feedback → pulse-chromatic → speed-blur-2d
//
// CLOCK MODEL — hit and pulse share one counter, fed from code:
//     _shader_clock += delta                    → "clock" every frame
//     on damage → "hit_time"   = clock          (white shake/flash burst)
//     on score  → "pulse_time" = clock + "pulse_mode" (RGB fan or paint)
//     speed blur is always-on via "speed_intensity" (0 = off)
//
// EFFECTS:
//   1. HIT   — screen shake offset + white vignette flash (no chroma)
//   2. PULSE — random-rotated RGB fan fringe, or full-frame luminance paint
//   3. SPEED — directional streak blur; blur and chroma share the same taps
// ============================================================================

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;

uniform float clock = 0.0;

// ---- 1. hit (negative feedback — death/damage) ----
uniform float hit_time = -10.0;
uniform float hit_duration : hint_range(0.2, 2.0) = 1.0;
uniform float hit_shake : hint_range(0.0, 120.0) = 90.0;
uniform float hit_flash : hint_range(0.0, 1.0) = 0.8;
uniform vec3 hit_flash_color : source_color = vec3(1.0);

// ---- 2. pulse (positive feedback — score) ----
uniform float pulse_time = -10.0;
uniform int pulse_mode : hint_enum("Auto", "Fringe", "Paint") = 0;
uniform float pulse_duration : hint_range(0.2, 4.0) = 0.9;         // fringe-only duration
uniform float pulse_paint_duration : hint_range(0.1, 2.0) = 0.35;   // full-paint duration (snappier)
uniform float pulse_fringe : hint_range(0.0, 1.0) = 0.7;
uniform float pulse_intensity : hint_range(0.0, 1.0) = 0.85;
uniform float hue_span : hint_range(0.5, 3.0) = 1.5;
uniform float saturation : hint_range(0.0, 1.0) = 1.0;  // 1 = fully vibrant

// ---- 3. speed blur (sprint/fast pace) ----
uniform float speed_intensity : hint_range(0.0, 1.0) = 0.0;
uniform float direction : hint_range(0.0, 6.2832) = 3.14;
uniform float length : hint_range(0.0, 0.25) = 0.25;
uniform int steps : hint_range(4, 32) = 24;
uniform float streak_zone : hint_range(0.0, 0.5) = 0.25;
uniform float streak_soft : hint_range(0.01, 0.5) = 0.05;
uniform float edge_jitter : hint_range(0.0, 0.2) = 0.05;
uniform float flow : hint_range(0.0, 1.0) = 1.0;
uniform float flow_speed : hint_range(0.0, 20.0) = 20.0;
uniform vec2 center = vec2(0.5, 0.5);

// ============================================================================
// SHARED MATH — Teleglitch-style envelope curves + helpers
// ============================================================================

float get_bias(float x, float b) {
	return x / (((1.0 / b) - 2.0) * (1.0 - x) + 1.0);
}

float get_gain(float x, float g) {
	if (x < 0.5) return get_bias(x * 2.0, g) / 2.0;
	return get_bias(x * 2.0 - 1.0, 1.0 - g) / 2.0 + 0.5;
}

// envelope: fast attack → soft decay, same shape used by hit and pulse
float progress_to_curve(float progress) {
	const float PIKE = 0.15;
	if (progress < PIKE) return get_gain(progress / PIKE, 0.25);
	return 1.0 - get_bias((progress - PIKE) / (1.0 - PIKE), 0.75);
}

vec3 hue(float h) {
	vec3 phase = mod(vec3(5.0, 3.0, 1.0) + h * 6.0, 6.0);
	return 1.0 - clamp(min(phase, 4.0 - phase), 0.0, 1.0);
}

float hash12(vec2 position) {
	vec3 scrambled = fract(vec3(position.xyx) * 0.1031);
	scrambled += dot(scrambled, scrambled.yzx + 33.33);
	return fract((scrambled.x + scrambled.y) * scrambled.z);
}

// ============================================================================
// PER-PULSE CONSTANTS — computed once in vertex() instead of per-pixel
// (4 vertex calls vs ~200k pixels)
// ============================================================================

varying vec4 v_pulse_rotation;   // fan rotation for THIS pulse (packed 2x2)
varying float v_hue_offset;      // palette seed for paint mode
varying float v_paint;           // resolved mode: 1.0 = paint, 0.0 = fringe
varying vec3 v_channel_jitter;   // per-channel angle jitter — decorrelates R/G/B fans

void vertex() {
	// independent seeds — direction, palette, mode and channel
	// jitter must NOT share one random or everything correlates
	float seed_dir = fract(sin(pulse_time * 43758.5453) * 43758.5453);
	float seed_hue = fract(sin(pulse_time * 12345.6789 + 0.123) * 12345.6789);
	float seed_jit = fract(sin(pulse_time * 26537.9123 + 0.456) * 26537.9123);
	float seed_mode = fract(sin(pulse_time * 31415.9265 + 0.789) * 31415.9265);

	v_hue_offset = seed_hue;
	v_paint = pulse_mode == 1 ? 0.0
		: (pulse_mode == 2 ? 1.0 : step(0.5, seed_mode));

	float angle = seed_dir * 6.28318;
	v_pulse_rotation = vec4(cos(angle), sin(angle), -sin(angle), cos(angle));

	// ±0.35 rad per channel — the fan stays readable but no two
	// pulses have the same geometry
	v_channel_jitter = (vec3(seed_jit, fract(seed_jit * 7.31), fract(seed_jit * 13.17)) - 0.5) * 0.7;
}

vec2 rotate_by(vec4 matrix, vec2 dir) {
	return vec2(dot(matrix.xz, dir), dot(matrix.yw, dir));
}

// ============================================================================
// EFFECT 1 — HIT: screen shake offset (sampled before everything else)
// ============================================================================

vec2 hit_uv_offset(vec2 screen_uv, float hit_env, vec2 pixel_size) {
	vec2 shake = (vec2(hash12(vec2(clock * 87.0, 3.1)),
	                   hash12(vec2(clock * 89.0, 7.7))) - 0.5)
	             * hit_shake * hit_env * pixel_size;
	return screen_uv + shake;
}

// ============================================================================
// EFFECT 2 — PULSE: chromatic fan fringe + optional luminance paint
// ============================================================================

// the 3 RGB tap offsets of the rotating fan
vec2 rotate_2d(vec2 vec, float angle) {
	float cos_angle = cos(angle);
	float sin_angle = sin(angle);
	return vec2(
		vec.x * cos_angle - vec.y * sin_angle,
		vec.x * sin_angle + vec.y * cos_angle);
}

// the 3 RGB tap offsets of the rotating fan — paint mode keeps a
// smaller fringe so the color fill reads as the main effect
void pulse_fringe_offsets(float pulse_progress,
		out vec2 offset_r, out vec2 offset_g, out vec2 offset_b) {
	float fringe_scale = v_paint > 0.5 ? 0.3 : 0.3;
	float split = progress_to_curve(pulse_progress) * pulse_fringe * fringe_scale;
	// UV fraction, not pixels — the fringe stays proportional to the
	// screen at every render/output resolution
	vec2 fringe = vec2(split * 0.05);
	// each channel gets its own jittered direction inside the fan
	offset_r = rotate_by(v_pulse_rotation,
		rotate_2d(vec2(0.0, 0.707), v_channel_jitter.x)) * fringe;
	offset_g = rotate_by(v_pulse_rotation,
		rotate_2d(vec2(0.707, -0.707), v_channel_jitter.y)) * fringe;
	offset_b = rotate_by(v_pulse_rotation,
		rotate_2d(vec2(-0.707, -0.707), v_channel_jitter.z)) * fringe;
}

// mode 2 — paint the whole frame in a random hue ramp. Luminance
// drives the ramp so the image's own contrast survives: dark stays
// dark, bright stays bright — just painted in vibrant hues
vec3 pulse_paint(vec3 color, float pulse_progress) {
	float envelope = progress_to_curve(pulse_progress);
	float luminance = dot(color, vec3(0.299, 0.587, 0.114));
	vec3 painted = hue(fract(luminance * hue_span + v_hue_offset)) * luminance;
	painted = mix(vec3(luminance), painted, saturation); // gray floor control
	painted *= 1.15;                                      // vibrancy pop
	return mix(color, painted, envelope * pulse_intensity);
}

// ============================================================================
// EFFECT 3 — SPEED BLUR: directional streaks, chroma taps fused in
// ============================================================================

vec3 speed_blur(vec2 screen_uv, vec2 offset_r, vec2 offset_g, vec2 offset_b, float anim_time) {
	vec2 blur_dir = vec2(cos(direction), sin(direction));
	vec2 blur_perp = vec2(-blur_dir.y, blur_dir.x);
	float along = dot(screen_uv - center, blur_dir);
	float across = dot(screen_uv - center, blur_perp);

	// irregular band edge — streaks fade at different heights
	float band_edge = streak_zone
		+ sin(along * 21.0 + anim_time * flow_speed * 0.5)
		* sin(along * 7.0 - anim_time * flow_speed * 0.3)
		* edge_jitter;
	float gate = smoothstep(band_edge, band_edge + streak_soft, abs(across));

	// corridor early-out: gate == 0 → blur_amount == 0 → the loop
	// would average `steps` identical fringe taps — return them
	// directly and skip the streak math (identical output)
	if (gate <= 0.0) {
		return vec3(
			texture(screen_texture, screen_uv + offset_r).r,
			texture(screen_texture, screen_uv + offset_g).g,
			texture(screen_texture, screen_uv + offset_b).b);
	}

	// traveling speed lines inside the band
	float flow_time = anim_time * flow_speed;
	float line_noise = sin(across * 90.0 + sin(across * 31.0) * 2.5)
		* sin(along * 6.0 - flow_time + sin(across * 17.0) * 1.5);
	line_noise = line_noise * 0.5 + 0.5;
	gate *= mix(1.0, mix(0.3, 1.7, line_noise), flow);

	// multi-tap smear — each channel samples at its own fringe
	// offset, so chroma + blur share the same taps
	float blur_amount = length * speed_intensity * gate;
	vec3 color;
	color.r = texture(screen_texture, screen_uv + offset_r).r;
	color.g = texture(screen_texture, screen_uv + offset_g).g;
	color.b = texture(screen_texture, screen_uv + offset_b).b;
	float total_weight = 1.0;
	for (int i = 1; i <= steps; i++) {
		float tap_fraction = float(i) / float(steps);
		float weight = 1.0 - tap_fraction;
		vec2 tap_uv = screen_uv - blur_dir * blur_amount * tap_fraction;
		color.r += texture(screen_texture, tap_uv + offset_r).r * weight;
		color.g += texture(screen_texture, tap_uv + offset_g).g * weight;
		color.b += texture(screen_texture, tap_uv + offset_b).b * weight;
		total_weight += weight;
	}
	return color / total_weight;
}

// ============================================================================
// MAIN — the merged pass
// ============================================================================

void fragment() {
	float hit_elapsed = clock - hit_time;
	float pulse_elapsed = clock - pulse_time;

	// each pulse mode gets its own duration — paint snaps, fringe lingers
	float effective_pulse_duration = v_paint > 0.5 ? pulse_paint_duration : pulse_duration;
	bool hit_active = hit_elapsed >= 0.0 && hit_elapsed <= hit_duration;
	bool pulse_active = pulse_elapsed >= 0.0 && pulse_elapsed <= effective_pulse_duration;
	bool blur_active = speed_intensity > 0.001;

	if (!hit_active && !pulse_active && !blur_active) {
		// idle fast-path — nothing playing: a single tap
		COLOR = vec4(texture(screen_texture, SCREEN_UV).rgb, 1.0);
	} else {

		// ---- hit envelope + shake ----
		float hit_env = 0.0;
		vec2 screen_uv = SCREEN_UV;
		if (hit_active) {
			float progress = clamp(hit_elapsed / hit_duration, 0.0, 1.0);
			hit_env = 1.0 - get_bias(progress, 0.75);
			screen_uv = hit_uv_offset(screen_uv, hit_env, SCREEN_PIXEL_SIZE);
		}

		// ---- pulse chroma offsets (zero when pulse is off) ----
		vec2 offset_r, offset_g, offset_b;
		if (pulse_active) {
			float pulse_progress = clamp(pulse_elapsed / effective_pulse_duration, 0.0, 1.0);
			pulse_fringe_offsets(pulse_progress, offset_r, offset_g, offset_b);
		} else {
			offset_r = vec2(0.0);
			offset_g = vec2(0.0);
			offset_b = vec2(0.0);
		}

		// ---- sample: blur taps, chroma taps, or plain ----
		vec3 color;
		if (blur_active) {
			color = speed_blur(screen_uv, offset_r, offset_g, offset_b, TIME);
		} else if (pulse_active || hit_active) {
			color.r = texture(screen_texture, screen_uv + offset_r).r;
			color.g = texture(screen_texture, screen_uv + offset_g).g;
			color.b = texture(screen_texture, screen_uv + offset_b).b;
		} else {
			color = texture(screen_texture, screen_uv).rgb;
		}

		// ---- pulse paint (mode 2) ----
		if (pulse_active && v_paint > 0.5) {
			float pulse_progress = clamp(pulse_elapsed / effective_pulse_duration, 0.0, 1.0);
			color = pulse_paint(color, pulse_progress);
		}

		// ---- hit flash: edge vignette + white swell ----
		if (hit_active) {
			float dist = distance(screen_uv, vec2(0.5));
			float vignette = smoothstep(0.3, 0.75, dist);
			color += hit_flash_color * hit_flash * hit_env * vignette;
			color += hit_flash_color * hit_flash * 0.3 * hit_env;
		}

		COLOR = vec4(color, 1.0);
	}
}
