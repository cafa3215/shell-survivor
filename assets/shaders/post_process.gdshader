// 赛博朋克后处理 - 降低光污染版
// Bloom/暗角/色差大幅减弱，保留微妙氛围
shader_type canvas_item;

uniform float bloom_intensity : hint_range(0.0, 1.0) = 0.2;
uniform float bloom_threshold : hint_range(0.0, 1.5) = 0.8;
uniform float chromatic_aberration : hint_range(0.0, 3.0) = 0.4;
uniform float scanline_strength : hint_range(0.0, 0.3) = 0.02;
uniform float scanline_count : hint_range(50.0, 800.0) = 320.0;
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.15;
uniform float vignette_softness : hint_range(0.1, 1.0) = 0.6;
uniform float saturation : hint_range(0.7, 1.35) = 1.0;
uniform float contrast : hint_range(0.85, 1.2) = 1.0;
uniform float grain_strength : hint_range(0.0, 0.08) = 0.0;
/// 参考《重生细胞》：青绿抬阴影 + 略压暖色 + 微提对比（0=关闭）
uniform float dc_style_mix : hint_range(0.0, 1.0) = 0.0;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 pixel_size = 1.0 / vec2(textureSize(screen_tex, 0));
	
	// 色差偏移 - 轻微
	float ca_offset = chromatic_aberration * pixel_size.x;
	vec2 ca_dir = normalize(uv - 0.5) * ca_offset;
	
	float r = texture(screen_tex, uv + ca_dir).r;
	float g = texture(screen_tex, uv).g;
	float b = texture(screen_tex, uv - ca_dir).b;
	vec3 color = vec3(r, g, b);
	
	// Bloom - 更高阈值，更低强度
	vec3 bright = max(color - vec3(bloom_threshold), vec3(0.0));
	float bloom_amount = dot(bright, vec3(0.2126, 0.7152, 0.0722));
	bloom_amount = smoothstep(0.0, 1.0, bloom_amount);
	
	// 简化bloom采样（减少4次采样降低光污染）
	vec3 bloom_color = vec3(0.0);
	float bloom_samples = 4.0;
	for (float i = 0.0; i < bloom_samples; i++) {
		float angle = i * 1.5708; // PI/2
		vec2 offset = vec2(cos(angle), sin(angle)) * pixel_size * 2.0;
		vec3 sample_col = texture(screen_tex, uv + offset).rgb;
		vec3 sample_bright = max(sample_col - vec3(bloom_threshold), vec3(0.0));
		bloom_color += sample_bright;
	}
	bloom_color /= bloom_samples;
	
	color += bloom_color * bloom_intensity * bloom_amount;
	
	// 扫描线效果 - 非常轻微
	float scanline = sin(uv.y * scanline_count * 3.14159) * 0.5 + 0.5;
	scanline = mix(1.0, scanline, scanline_strength);
	color *= scanline;
	
	// 暗角效果 - 轻微
	float dist = distance(uv, vec2(0.5));
	float vignette = smoothstep(0.5, 0.5 - vignette_softness, dist);
	vignette = mix(1.0, vignette, vignette_strength);
	color *= vignette;
	
	// 饱和度 / 对比度（高画质下略提色）
	float luma = dot(color, vec3(0.2126, 0.7152, 0.0722));
	color = mix(vec3(luma), color, saturation);
	color = (color - 0.5) * contrast + 0.5;
	
	// 极轻胶片颗粒（打破色带、增加质感）
	if (grain_strength > 0.0001) {
		float g = fract(sin(dot(uv * vec2(1280.0, 720.0) + vec2(TIME * 60.0), vec2(12.9898, 78.233))) * 43758.5453);
		color += (g - 0.5) * 2.0 * grain_strength;
	}
	
	// 重生细胞式：暗部青绿 lift、整体略冷、对比微强化
	if (dc_style_mix > 0.001) {
		float l = dot(color, vec3(0.2126, 0.7152, 0.0722));
		float shadow_mask = 1.0 - smoothstep(0.06, 0.48, l);
		color += vec3(0.02, 0.05, 0.07) * shadow_mask * dc_style_mix;
		color = mix(color, color * vec3(1.02, 0.97, 1.06), dc_style_mix * 0.22);
		color = (color - 0.5) * (1.0 + 0.07 * dc_style_mix) + 0.5;
	}
	
	color = clamp(color, 0.0, 1.0);
	COLOR = vec4(color, 1.0);
}
