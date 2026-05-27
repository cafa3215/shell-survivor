shader_type canvas_item;

uniform vec4 overlay_color : source_color = vec4(0.0, 0.0, 0.0, 0.6);
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.8;
uniform float pulse_speed : hint_range(0.0, 2.0) = 0.5;

void fragment() {
    vec2 uv = UV;
    vec2 center = vec2(0.5);
    
    // 暗角效果
    float dist = length(uv - center);
    float vignette = smoothstep(0.8, vignette_strength, dist);
    
    // 轻微脉冲
    float pulse = 0.95 + 0.05 * sin(TIME * pulse_speed);
    
    // 扫描线
    float scanline = 0.98 + 0.02 * sin(uv.y * 200.0);
    
    vec4 base = texture(TEXTURE, uv);
    vec4 final_color = overlay_color;
    final_color.a *= vignette * pulse;
    
    if (base.a > 0.0) {
        COLOR = base;
    } else {
        COLOR = final_color * scanline;
    }
}
