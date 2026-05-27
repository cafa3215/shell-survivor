shader_type canvas_item;

uniform float time : hint_range(0.0, 100.0) = 0.0;
uniform vec3 base_color : source_color = vec3(0.04, 0.06, 0.12);
uniform vec3 accent_color : source_color = vec3(0.1, 0.3, 0.6);
uniform vec3 glow_color : source_color = vec3(0.15, 0.5, 0.9);
uniform float grid_size : hint_range(10.0, 100.0) = 40.0;
uniform float grid_opacity : hint_range(0.0, 1.0) = 0.15;
uniform float particle_count : hint_range(10.0, 200.0) = 50.0;

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    float a = hash(i);
    float b = hash(i + vec2(1.0, 0.0));
    float c = hash(i + vec2(0.0, 1.0));
    float d = hash(i + vec2(1.0, 1.0));
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void fragment() {
    vec2 uv = UV;
    float t = time * 0.3;
    
    // 基础颜色渐变
    vec3 col = base_color;
    
    // 动态网格
    vec2 grid_uv = uv * vec2(1.0, SCREEN_PIXEL_SIZE.x / SCREEN_PIXEL_SIZE.y) * grid_size;
    vec2 grid = abs(fract(grid_uv - 0.5) - 0.5);
    float grid_line = 1.0 - smoothstep(0.0, 0.05, min(grid.x, grid.y));
    col += accent_color * grid_line * grid_opacity * (0.5 + 0.5 * sin(t));
    
    // 扫描线效果
    float scan = sin((uv.y + t * 0.5) * 80.0) * 0.03;
    col += accent_color * scan;
    
    // 粒子效果
    for (float i = 0.0; i < particle_count; i++) {
        float fi = float(i);
        vec2 pos = vec2(
            hash(vec2(fi, 0.0)),
            hash(vec2(fi, 1.0))
        );
        pos = fract(pos + vec2(t * (0.3 + hash(vec2(fi, 2.0)) * 0.2), t * 0.1));
        float size = 0.002 + hash(vec2(fi, 3.0)) * 0.003;
        float d = length(uv - pos);
        float brightness = smoothstep(size * 2.0, size * 0.5, d);
        brightness *= 0.3 + 0.7 * hash(vec2(fi, floor(TIME * 2.0)));
        col += glow_color * brightness * 0.4;
    }
    
    // 中心光晕
    float center_dist = length(uv - vec2(0.5));
    float center_glow = smoothstep(0.8, 0.0, center_dist) * 0.3;
    col += accent_color * center_glow * (0.7 + 0.3 * sin(t * 2.0));
    
    // 边缘渐暗
    float vignette = 1.0 - smoothstep(0.3, 0.9, center_dist);
    col *= vignette;
    
    // 最终颜色
    COLOR = vec4(col, 1.0);
}
