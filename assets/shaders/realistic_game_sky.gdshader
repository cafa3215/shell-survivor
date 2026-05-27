// 1080p 写实向：暮光天空渐变 + 极轻体积感 + 胶片颗粒（无外部贴图）
shader_type canvas_item;

uniform vec3 zenith_color : source_color = vec3(0.04, 0.06, 0.11);
uniform vec3 horizon_color : source_color = vec3(0.16, 0.15, 0.18);
uniform float haze : hint_range(0.0, 0.12) = 0.045;
uniform float grain : hint_range(0.0, 0.04) = 0.014;
uniform float time_scale : hint_range(0.0, 0.2) = 0.035;

void fragment() {
	vec2 uv = UV;
	float h = clamp(uv.y, 0.0, 1.0);
	float t = pow(mix(0.35, 1.0, h), 1.22);
	vec3 col = mix(horizon_color, zenith_color, t);
	// 极低频「层云」亮度偏移（避免卡通云块）
	float band = sin(uv.x * 5.5 + TIME * time_scale) * sin(uv.y * 3.2 - TIME * (time_scale * 0.7));
	col += vec3(0.02, 0.022, 0.028) * band * haze * (0.35 + h * 0.65);
	// 极轻颗粒
	float n = fract(sin(dot(uv * vec2(1920.0, 1080.0) + vec2(TIME * 13.0, TIME * 9.0), vec2(12.9898, 78.233))) * 43758.5453);
	col += (n - 0.5) * grain;
	COLOR = vec4(col, 1.0);
}
