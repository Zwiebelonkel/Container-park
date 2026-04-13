// PSX-Like Shader — Grain, CRT, Vignette, Pixelation, Warble
// FIX: Distortion + Warble werden VOR der Pixelierung angewendet,
//      dadurch sind die Pixel immer bildschirmausgerichtet (nicht UV-space).

shader_type canvas_item;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_nearest, repeat_disable;

uniform float grain_intensity    : hint_range(0.0, 1.0)  = 0.1;
uniform float min_lum            : hint_range(0.0, 1.0)  = 0.0;
uniform float max_lum            : hint_range(0.0, 1.0)  = 1.0;
uniform float time_scale         : hint_range(0.0, 1.0)  = 0.5;

uniform float vignette_darkness      : hint_range(0.0, 1.0) = 0.5;
uniform float vignette_outer_radius  : hint_range(0.1, 2.0) = 0.7;
uniform float vignette_inner_radius  : hint_range(0.0, 1.9) = 0.2;

uniform float scanline_intensity     : hint_range(0.0, 1.0)  = 0.2;
uniform float barrel_distortion      : hint_range(0.0, 0.5)  = 0.15;
uniform float chromatic_aberration   : hint_range(0.0, 0.01) = 0.005;
uniform float crt_vignette_power     : hint_range(0.0, 5.0)  = 2.0;

uniform int   pixel_resolution_x     : hint_range(32, 1080) = 320;
uniform int   pixel_resolution_y     : hint_range(24, 900)  = 240;
uniform bool  enable_color_quantization = true;
uniform float color_quant_steps      : hint_range(2.0, 64.0) = 32.0;

uniform float warble_amount          : hint_range(0.0, 0.01) = 0.002;
uniform float warble_speed           : hint_range(0.0, 10.0) = 5.0;


float noise(vec2 p) {
    return (fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453) - 0.5) * 2.0;
}

vec3 soft_light(vec3 A, vec3 B) {
    vec3 branch1 = 2.0 * A * B + A * A * (1.0 - 2.0 * B);
    vec3 branch2 = 2.0 * A * (1.0 - B) + sqrt(A) * (2.0 * B - 1.0);
    vec3 condition = step(0.5, B);
    return mix(branch1, branch2, condition);
}

vec3 quantize_color(vec3 color, float steps) {
    return floor(color * steps) / steps;
}


void fragment() {
    vec2 uv = SCREEN_UV;
    vec2 screen_size = 1.0 / SCREEN_PIXEL_SIZE;

    // ----------------------------------------------------------------
    // SCHRITT 1: Barrel-Distortion auf den rohen UV anwenden
    // ----------------------------------------------------------------
    vec2 center_uv = uv - 0.5;
    float r2 = dot(center_uv, center_uv);
    vec2 distorted_uv = center_uv * (1.0 + barrel_distortion * r2) + 0.5;

    // Außerhalb des Bildschirms → schwarz, sonst normaler Pfad
    if (distorted_uv.x < 0.0 || distorted_uv.x > 1.0 ||
        distorted_uv.y < 0.0 || distorted_uv.y > 1.0) {

        COLOR = vec4(0.0, 0.0, 0.0, 1.0);

    } else {

        // ------------------------------------------------------------
        // SCHRITT 2: Warble auf den verzerrten UV anwenden
        // ------------------------------------------------------------
        vec2 warble_offset = vec2(
            sin(TIME * warble_speed + uv.x * 10.0) * cos(TIME * warble_speed * 0.7 + uv.y * 7.0),
            cos(TIME * warble_speed * 0.8 + uv.y * 11.0) * sin(TIME * warble_speed * 0.9 + uv.x * 8.0)
        ) * warble_amount;

        vec2 warbled_uv = clamp(distorted_uv + warble_offset, vec2(0.0), vec2(1.0));

        // ------------------------------------------------------------
        // SCHRITT 3: ERST JETZT pixelieren (snap zum Pixel-Grid)
        //            → Pixel sind immer bildschirmausgerichtet
        // ------------------------------------------------------------
        vec2 pixel_uv = floor(warbled_uv * vec2(float(pixel_resolution_x), float(pixel_resolution_y)))
                      / vec2(float(pixel_resolution_x), float(pixel_resolution_y));

        // ------------------------------------------------------------
        // SCHRITT 4: Chromatische Aberration + Farbe samplen
        // ------------------------------------------------------------
        vec3 col;
        col.r = texture(SCREEN_TEXTURE, pixel_uv + vec2(chromatic_aberration, 0.0)).r;
        col.g = texture(SCREEN_TEXTURE, pixel_uv).g;
        col.b = texture(SCREEN_TEXTURE, pixel_uv - vec2(chromatic_aberration, 0.0)).b;

        vec3 original_color = col;

        if (enable_color_quantization) {
            original_color = quantize_color(original_color, color_quant_steps);
        }

        // ------------------------------------------------------------
        // SCHRITT 5: Film-Grain (luminanzabhängig)
        // ------------------------------------------------------------
        float lum = dot(original_color, vec3(0.299, 0.587, 0.114));
        float factor = 1.0 - smoothstep(min_lum, max_lum, lum);

        vec2 grain_offset = vec2(sin(TIME * time_scale), cos(TIME * time_scale)) * 20.0;
        vec2 noise_uv = uv + grain_offset;

        float noise_r = noise(noise_uv);
        float noise_g = noise(noise_uv + vec2(0.1, 0.2));
        float noise_b = noise(noise_uv + vec2(0.3, 0.4));
        vec3 grain = vec3(noise_r, noise_g, noise_b) * grain_intensity * factor;

        vec3 grain_color = clamp(vec3(0.5) + grain, 0.0, 1.0);
        vec3 processed_color = soft_light(original_color, grain_color);

        // ------------------------------------------------------------
        // SCHRITT 6: Vignette (auf originalem UV für korrekte Form)
        // ------------------------------------------------------------
        float aspect_ratio = screen_size.x / screen_size.y;
        vec2 adjusted_uv = uv - 0.5;
        adjusted_uv.x *= aspect_ratio;

        float inner_rad = min(vignette_inner_radius, vignette_outer_radius - 0.01);
        float vdist = length(adjusted_uv);
        float vignette_pct = smoothstep(vignette_outer_radius, inner_rad, vdist);
        float vignette_factor = mix(1.0 - vignette_darkness, 1.0, vignette_pct);

        processed_color *= vignette_factor;

        // ------------------------------------------------------------
        // SCHRITT 7: Scanlines (auf echten Bildschirm-Pixeln)
        // ------------------------------------------------------------
        float scanline_alpha = sin(uv.y * screen_size.y * 3.0);
        scanline_alpha = clamp(scanline_alpha * 0.5 + 0.5, 0.0, 1.0);
        scanline_alpha = 1.0 - (scanline_alpha * scanline_intensity);
        processed_color *= scanline_alpha;

        // ------------------------------------------------------------
        // SCHRITT 8: CRT-Vignette (basierend auf verzerrtem r2)
        // ------------------------------------------------------------
        vec2 distorted_center = distorted_uv - 0.5;
        float distorted_r2 = clamp(dot(distorted_center, distorted_center), 0.0, 1.0);
        float crt_vignette = pow(1.0 - distorted_r2, crt_vignette_power);
        processed_color *= crt_vignette;

        COLOR = vec4(processed_color, 1.0);

    }
}
