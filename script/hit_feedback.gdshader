shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;

// CLOCK MODEL - hit_elapsed = clock - hit_time.

uniform float hit_time = -10.0;                          // when the burst starts - set from code on hit
uniform float clock = 0.0;                               // caller-fed clock (see above); >0 overrides TIME
uniform int pulses : hint_range(0, 6) = 1;               // thumps per hit — 0 = infinite train
uniform float pulse_freq : hint_range(0.5, 8.0) = 2.0;   // pulse spacing (Hz)
uniform float decay : hint_range(1.0, 10.0) = 4.0;       // how fast each pulse fades
uniform float trauma : hint_range(0.0, 1.0) = 1.0;       // strength multiplier (escalate via code)
uniform float shake : hint_range(0.0, 60.0) = 50.0;      // max pixel displacement (X and Y)
uniform float shake_speed : hint_range(5.0, 60.0) = 30.0;// shake frequency
uniform float flash : hint_range(0.0, 1.0) = 0.5;        // edge vignette flash
uniform vec3 flash_color : source_color = vec3(1.0, 1.0, 1.0);
uniform float chromatic : hint_range(0.0, 1.0) = 0.4;    // RGB split kick on impact

// hash12 — David Hoskins' "hash without sine": turns a 2D position
// into a pseudo-random 0..1 value (no textures, no tables)
float hash12(vec2 position) {
	vec3 scrambled = fract(vec3(position.xyx) * 0.1031);
	scrambled += dot(scrambled, scrambled.yzx + 33.33);
	return fract((scrambled.x + scrambled.y) * scrambled.z);
}

float vnoise(vec2 pos) {
	vec2 cell = floor(pos);              // which grid cell we're in
	vec2 inside = fract(pos);            // position inside that cell
	inside = inside * inside * (3.0 - 2.0 * inside);  // smooth blend curve
	float corner00 = hash12(cell);
	float corner10 = hash12(cell + vec2(1.0, 0.0));
	float corner01 = hash12(cell + vec2(0.0, 1.0));
	float corner11 = hash12(cell + vec2(1.0, 1.0));
	return mix(mix(corner00, corner10, inside.x),
	           mix(corner01, corner11, inside.x), inside.y);
}

void fragment() {
	// hit_elapsed = seconds since the hit — the whole effect is
	// a function of it: an amplitude `envelope` that peaks at 1.0
	// at the impact frame and decays to ~0, then EVERYTHING scales
	// by envelope (shake offset, chromatic split, vignette flash).
	//   decay      → tail length    (4.0 ≈ 0.5s, 2.0 ≈ 1.2s)
	//   pulse_freq → spacing between thumps in Hz
	//                (pulses=3 @ 2Hz = thumps at 0s, 0.5s, 1.0s)
	//   pulses = 0 → infinite train (fract loop, never ends)
	// Prefer the caller-fed clock: canvas_item TIME is
	// material-local, not wall time — raw timestamps land ~1s in
	// the future and delay the pulse.
	float hit_elapsed = (clock > 0.0 ? clock : TIME) - hit_time;
	float envelope = 0.0;
	if (hit_elapsed >= 0.0) {
		if (pulses <= 0) {        // infinite train — heartbeat thump
			envelope = trauma * exp(-4.0 * fract(hit_elapsed * pulse_freq));
		} else {                  // finite pulse train
			float spacing = 1.0 / pulse_freq;
			for (int pulse_index = 0; pulse_index < 6; pulse_index++) {
				if (pulse_index >= pulses) break;
				float pulse_elapsed = hit_elapsed - float(pulse_index) * spacing;
				if (pulse_elapsed < 0.0) break;   // this pulse hasn't started yet
				envelope += trauma * exp(-decay * pulse_elapsed);
			}
		}
		envelope = min(envelope, 1.0);
	}

	vec3 color;
	if (envelope < 0.001) {
		// idle: no hit in flight — one tap and done (99% of frames)
		color = texture(screen_texture, SCREEN_UV).rgb;
	} else {
		// organic shake — two noise channels, decays with the hit
		vec2 shake_offset = vec2(
			vnoise(vec2(TIME * shake_speed, 1.7)) - 0.5,
			vnoise(vec2(4.1, TIME * shake_speed * 0.9)) - 0.5)
			* 2.0 * envelope * shake * SCREEN_PIXEL_SIZE;

		// chromatic kick along the shake direction — 3 taps only when used
		if (chromatic > 0.0) {
			float chroma_offset = envelope * chromatic * 0.02;
			color.r = texture(screen_texture, SCREEN_UV + shake_offset + shake_offset * chroma_offset).r;
			color.g = texture(screen_texture, SCREEN_UV + shake_offset).g;
			color.b = texture(screen_texture, SCREEN_UV + shake_offset - shake_offset * chroma_offset).b;
		} else {
			color = texture(screen_texture, SCREEN_UV + shake_offset).rgb;
		}

		// vignette flash — damage reads from the edges inward
		float vignette = smoothstep(0.25, 0.7, distance(SCREEN_UV, vec2(0.5)));
		color += flash_color * flash * envelope * (0.3 + 0.7 * vignette);
	}

	COLOR = vec4(color, 1.0);
}
