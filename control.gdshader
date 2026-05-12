shader_type canvas_item;

uniform vec4 color1 : source_color = vec4(0.1, 0.0, 0.2, 1.0);
uniform vec4 color2 : source_color = vec4(0.0, 0.2, 0.4, 1.0);
uniform vec4 color3 : source_color = vec4(0.0, 0.4, 0.3, 1.0);

uniform float speed = 1.0;
uniform float wave_size = 2.0;

// Mouse parameters passed from script
uniform vec2 mouse_position = vec2(0.5, 0.5);
uniform float mouse_radius = 0.25;
uniform float mouse_strength = 0.4;

void fragment() {
    vec2 uv = UV;
    
    // Calculate distance between current pixel and mouse cursor
    float dist = distance(uv, mouse_position);
    
    // Create a smooth deformation area around the mouse
    if (dist < mouse_radius) {
        float force = (1.0 - (dist / mouse_radius)) * mouse_strength;
        vec2 dir = normalize(uv - mouse_position);
        uv += dir * force; // Displace the texture coordinates
    }
    
    // Apply standard wave math to the warped coordinates
    vec2 wave_uv = uv * wave_size;
    float wave = sin(wave_uv.x + TIME * speed) + cos(wave_uv.y + TIME * speed);
    
    vec4 final_color = mix(color1, color2, wave);
    final_color = mix(final_color, color3, sin(TIME * speed * 0.5));
    
    COLOR = final_color;
}
