// 血条渐变着色器
shader_type canvas_item;

uniform vec4 low_color : source_color = vec4(1.0, 0.15, 0.1, 1.0);
uniform vec4 mid_color : source_color = vec4(1.0, 0.8, 0.15, 1.0);
uniform vec4 high_color : source_color = vec4(0.15, 1.0, 0.55, 1.0);
uniform float hp_ratio : hint_range(0.0, 1.0) = 1.0;
uniform float flash : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec4 base_color;
	if (hp_ratio < 0.3) {
		base_color = low_color;
	} else if (hp_ratio < 0.6) {
		float t = (hp_ratio - 0.3) / 0.3;
		base_color = mix(low_color, mid_color, t);
	} else {
		float t = (hp_ratio - 0.6) / 0.4;
		base_color = mix(mid_color, high_color, t);
	}
	
	// 受伤闪白
	base_color = mix(base_color, vec4(1.0), flash * 0.5);
	
	// 血条裁剪
	float fill_x = UV.x;
	if (fill_x > hp_ratio) {
		base_color.a = 0.0;
	}
	
	// 顶部高光
	float highlight = smoothstep(0.3, 0.0, UV.y) * 0.25;
	base_color.rgb += highlight;
	
	COLOR = base_color;
}
