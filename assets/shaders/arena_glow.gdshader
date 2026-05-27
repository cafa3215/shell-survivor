// 竞技场边框辉光脉冲
shader_type canvas_item;

uniform vec4 glow_color : source_color = vec4(0.3, 0.6, 1.0, 1.0);
uniform float pulse_speed : hint_range(0.5, 10.0) = 2.5;
uniform float pulse_min : hint_range(0.3, 0.8) = 0.6;
uniform float pulse_max : hint_range(0.8, 1.5) = 1.2;
uniform float glow_width : hint_range(1.0, 20.0) = 6.0;

void fragment() {
	float pulse = pulse_min + (pulse_max - pulse_min) * (0.5 + 0.5 * sin(TIME * pulse_speed));
	float alpha = pulse * COLOR.a;
	
	// 边缘辉光
	vec2 size = vec2(textureSize(TEXTURE, 0));
	vec2 uv = UV;
	float edge_dist = min(min(uv.x, 1.0 - uv.x), min(uv.y, 1.0 - uv.y));
	float glow = smoothstep(glow_width / size.x, 0.0, edge_dist);
	
	vec3 final_color = mix(COLOR.rgb, glow_color.rgb, glow * 0.5);
	COLOR = vec4(final_color, alpha + glow * 0.3);
}
