shader_type canvas_item;

uniform vec4 glow_color : source_color = vec4(0.2, 0.6, 1.0, 0.8);
uniform float glow_intensity : hint_range(0.0, 2.0) = 0.6;
uniform float pulse_speed : hint_range(0.0, 4.0) = 1.5;
uniform float corner_radius : hint_range(0.0, 32.0) = 12.0;

void fragment() {
    vec2 uv = UV;
    vec2 size = vec2(1.0) / TEXTURE_PIXEL_SIZE;
    
    // 计算到边缘的距离
    float edge_dist = min(min(uv.x, 1.0 - uv.x), min(uv.y, 1.0 - uv.y));
    
    // 圆角处理
    float radius = corner_radius / min(size.x, size.y);
    vec2 q = uv - vec2(radius, radius);
    if (uv.x < radius && uv.y < radius) {
        float d = length(q) - radius;
        if (d > 0.0) {
            COLOR = vec4(0.0);
            return;
        }
    }
    q = uv - vec2(1.0 - radius, radius);
    if (uv.x > 1.0 - radius && uv.y < radius) {
        float d = length(q) - radius;
        if (d > 0.0) {
            COLOR = vec4(0.0);
            return;
        }
    }
    q = uv - vec2(radius, 1.0 - radius);
    if (uv.x < radius && uv.y > 1.0 - radius) {
        float d = length(q) - radius;
        if (d > 0.0) {
            COLOR = vec4(0.0);
            return;
        }
    }
    q = uv - vec2(1.0 - radius, 1.0 - radius);
    if (uv.x > 1.0 - radius && uv.y > 1.0 - radius) {
        float d = length(q) - radius;
        if (d > 0.0) {
            COLOR = vec4(0.0);
            return;
        }
    }
    
    // 发光边缘效果
    float glow = smoothstep(radius * 2.0, radius * 0.5, edge_dist);
    float pulse = 0.8 + 0.2 * sin(TIME * pulse_speed);
    
    // 获取原始颜色并叠加发光
    vec4 base = texture(TEXTURE, uv);
    vec4 glow_effect = glow_color * glow * glow_intensity * pulse;
    
    COLOR = base + glow_effect;
    COLOR.a = max(COLOR.a, glow * glow_intensity * 0.3 * pulse);
}
