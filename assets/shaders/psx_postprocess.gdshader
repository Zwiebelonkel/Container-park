## psx_postprocess.gdshader
## PSX / Retro-Horror Post-Processing Shader
## Verwendung: Als ShaderMaterial auf einem ColorRect (Vollbild) in einem SubViewportContainer
##
## Features:
##   - Pixelierung (PSX-Look)
##   - CRT-Scanlines
##   - Vignette (dunkle Ränder)
##   - Farbaberation (chromatic aberration)
##   - Film-Grain / Rauschen
##   - Dither-Pattern

shader_type canvas_item;

// ─── Pixel / Auflösung ─────────────────────────────────────────────────────────
uniform float pixel_size : hint_range(1.0, 8.0, 0.5) = 2.0;

// ─── CRT Scanlines ─────────────────────────────────────────────────────────────
uniform bool enable_scanlines = true;
uniform float scanline_intensity : hint_range(0.0, 1.0) = 0.12;
uniform float scanline_count : hint_range(100.0, 600.0) = 240.0;

// ─── Vignette ──────────────────────────────────────────────────────────────────
uniform bool enable_vignette = true;
uniform float vignette_strength : hint_range(0.0, 2.0) = 0.7;
uniform float vignette_size : hint_range(0.1, 1.5) = 0.85;

// ─── Chromatische Aberration ───────────────────────────────────────────────────
uniform bool enable_chromatic = true;
uniform float chromatic_strength : hint_range(0.0, 0.02) = 0.004;

// ─── Film Grain / Rauschen ─────────────────────────────────────────────────────
uniform bool enable_grain = true;
uniform float grain_strength : hint_range(0.0, 0.5) = 0.08;
uniform float grain_speed : hint_range(0.5, 8.0) = 3.0;

// ─── Farb-Grading ──────────────────────────────────────────────────────────────
uniform vec3 color_tint : source_color = vec3(0.92, 0.88, 0.80);  // leicht warm/gelb
uniform float contrast : hint_range(0.5, 2.0) = 1.08;
uniform float saturation : hint_range(0.0, 2.0) = 0.75;  // leicht entsättigt für Horror

// ─── Hilfsfunktionen ───────────────────────────────────────────────────────────

float rand(vec2 co) {
	return fract(sin(dot(co, vec2(12.9898, 78.233))) * 43758.5453);
}

vec3 apply_contrast(vec3 color, float c) {
	return (color - 0.5) * c + 0.5;
}

vec3 apply_saturation(vec3 color, float s) {
	float gray = dot(color, vec3(0.299, 0.587, 0.114));
	return mix(vec3(gray), color, s);
}

// ─── Main ──────────────────────────────────────────────────────────────────────
void fragment() {
	vec2 uv = UV;
	
	// 1. Pixelierung (PSX-Auflösung simulieren)
	if (pixel_size > 1.0) {
		vec2 screen_size = 1.0 / TEXTURE_PIXEL_SIZE;
		vec2 pixelated_size = floor(screen_size / pixel_size);
		uv = (floor(uv * pixelated_size) + 0.5) / pixelated_size;
	}
	
	// 2. Chromatische Aberration
	vec4 color;
	if (enable_chromatic) {
		vec2 dir = uv - vec2(0.5);
		float dist = length(dir) * chromatic_strength;
		vec2 offset = normalize(dir) * dist;
		float r = texture(TEXTURE, uv + offset).r;
		float g = texture(TEXTURE, uv).g;
		float b = texture(TEXTURE, uv - offset).b;
		color = vec4(r, g, b, 1.0);
	} else {
		color = texture(TEXTURE, uv);
	}
	
	// 3. CRT Scanlines
	if (enable_scanlines) {
		float scan = sin(uv.y * scanline_count * 3.14159) * 0.5 + 0.5;
		scan = pow(scan, 1.5);
		color.rgb -= scanline_intensity * (1.0 - scan);
	}
	
	// 4. Film Grain
	if (enable_grain) {
		float grain = rand(uv + fract(TIME * grain_speed)) * 2.0 - 1.0;
		color.rgb += grain * grain_strength;
	}
	
	// 5. Farb-Grading
	color.rgb = apply_contrast(color.rgb, contrast);
	color.rgb = apply_saturation(color.rgb, saturation);
	color.rgb *= color_tint;
	
	// 6. Vignette (zuletzt, damit sie alles abdunkelt)
	if (enable_vignette) {
		vec2 vig_uv = uv - 0.5;
		float vig = 1.0 - dot(vig_uv, vig_uv) * vignette_strength / vignette_size;
		vig = clamp(vig, 0.0, 1.0);
		vig = pow(vig, 0.8);
		color.rgb *= vig;
	}
	
	COLOR = clamp(color, 0.0, 1.0);
}
