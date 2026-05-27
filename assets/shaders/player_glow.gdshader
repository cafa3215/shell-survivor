// 玩家光晕脉冲着色器
shader_type canvas_item;

uniform vec4 core_color : source_color = vec4(0.2, 0.95, 1.0, 1.0);
uniform vec4 glow_color : source_color = vec4(0.1, 0.6, 1.0, 0.6);
uniform float pulse_speed : hint_range(1.0, 10.0) = 3.0;
uniform float glow_radius : hint_range(0.0, 0.5) = 0.15;
uniform float invincible_flash : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec2 center = vec2(0.5);
	float dist = distance(UV, center);
	
	// 核心圆
	float core = smoothstep(0.38, 0.32, dist);
	
	// 边缘渐变
	float edge = smoothstep(0.42, 0.35, dist) * (1.0 - smoothstep(0.35, 0.25, dist));
	
	// 外部辉光
	float pulse = 0.5 + 0.5 * sin(TIME * pulse_speed);
	float glow = smoothstep(0.5, 0.3, dist) * glow_radius * pulse;
	
	// 无敌闪烁
	float inv_flash = sin(TIME * 15.0) * 0.5 + 0.5;
	
	vec3 final_color = core_color.rgb * core + glow_color.rgb * (edge + glow);
	float alpha = core + edge * 0.8 + glow * 0.6;
	
	// 无敌时整体闪烁
	if (invincible_flash > 0.0) {
		final_color = mix(final_color, vec3(1.0), inv_flash * invincible_flash * 0.4);
		alpha *= mix(1.0, 0.5 + 0.5 * inv_flash, invincible_flash);
	}
	
	COLOR = vec4(final_color, alpha);
}
