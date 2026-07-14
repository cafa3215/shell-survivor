shader_type canvas_item;

uniform vec4 rim_color : source_color = vec4(0.75, 0.92, 1.0, 1.0);
uniform float rim_power : hint_range(0.5, 8.0) = 2.4;
uniform float pulse_speed : hint_range(0.0, 8.0) = 2.6;
uniform float rim_strength : hint_range(0.0, 1.5) = 0.55;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float edge = 1.0 - tex.a;
	edge = pow(clamp(edge, 0.0, 1.0), rim_power);
	float pulse = 0.76 + 0.24 * sin(TIME * pulse_speed);
	vec3 rim = rim_color.rgb * edge * rim_strength * pulse;
	COLOR.rgb = tex.rgb + rim;
	COLOR.a = max(tex.a, edge * rim_color.a * 0.32 * pulse);
}
