shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;

uniform float intensity : hint_range(0.0, 1.0, 0.01) = 1.0;     // blur strength (feed from code)
uniform float direction : hint_range(0.0, 6.2832, 0.01) = 3.14; // streak angle (3.14 = R→L, 0 = L→R)
uniform float length : hint_range(0.0, 0.25, 0.005) = 0.25;     // streak length (fraction of screen)
uniform int steps : hint_range(4, 32, 1) = 32;                  // taps per pixel (quality vs cost)
uniform vec2 center = vec2(0.5, 0.5);                           // corridor origin (screen UV)
uniform float streak_zone : hint_range(0.0, 0.5, 0.01) = 0.25;  // half-height of the untouched corridor (0 = smear everywhere)
uniform float streak_soft : hint_range(0.01, 0.5, 0.01) = 0.05; // graduation of the band edge
uniform float edge_jitter : hint_range(0.0, 0.2, 0.01) = 0.05;  // raggedness of the band edge (kills the straight cut)
uniform float flow : hint_range(0.0, 1.0, 0.01) = 1.0;          // traveling streak lines (0 = static)
uniform float flow_speed : hint_range(0.0, 20.0, 0.1) = 20.0;   // how fast the lines drag

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 dir = vec2(cos(direction), sin(direction));
	float par = dot(uv - center, dir);
	float perp = dot(uv - center, vec2(-dir.y, dir.x));

	// irregular band edge: streaks die out at different heights —
	// no straight hard cut between corridor and streak
	float edge = streak_zone
	           + sin(par * 21.0 + TIME * flow_speed * 0.5)
	           * sin(par * 7.0 - TIME * flow_speed * 0.3)
	           * edge_jitter;
	float gate = smoothstep(edge, edge + streak_soft, abs(perp));

	// traveling speed lines ("riscos"): thin irregular bands along
	// perp sliding along `dir` — continuous, so no banding/pixelation
	float t = TIME * flow_speed;
	float ln = sin(perp * 90.0 + sin(perp * 31.0) * 2.5)
	         * sin(par * 6.0 - t + sin(perp * 17.0) * 1.5);
	ln = ln * 0.5 + 0.5;
	gate *= mix(1.0, mix(0.3, 1.7, ln), flow);

	float amt = length * intensity * gate;
	vec3 col = texture(screen_texture, uv).rgb;
	float tot = 1.0;
	for (int i = 1; i <= steps; i++) {
		float k = float(i) / float(steps);
		float w = 1.0 - k;
		col += texture(screen_texture, uv - dir * amt * k).rgb * w;
		tot += w;
	}
	COLOR = vec4(col / tot, 1.0);
}
