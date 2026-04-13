shader_type sky;

// Wird vom AnimationPlayer gesteuert (0.0 = Mitternacht, 0.5 = Mittag, 1.0 = Mitternacht)
uniform float time_of_day : hint_range(0.0, 1.0) = 0.35;

// Tag-Farben
uniform vec4 day_zenith   : source_color = vec4(0.18, 0.48, 0.90, 1.0);
uniform vec4 day_horizon  : source_color = vec4(0.72, 0.90, 1.00, 1.0);

// Sonnenaufgang/Untergang
uniform vec4 sunset_zenith  : source_color = vec4(0.25, 0.12, 0.28, 1.0);
uniform vec4 sunset_horizon : source_color = vec4(1.00, 0.45, 0.10, 1.0);
uniform vec4 sunset_glow    : source_color = vec4(1.00, 0.70, 0.20, 1.0);

// Nacht-Farben
uniform vec4 night_zenith  : source_color = vec4(0.01, 0.02, 0.08, 1.0);
uniform vec4 night_horizon : source_color = vec4(0.04, 0.06, 0.18, 1.0);

// Sonne & Mond
uniform float sun_size       : hint_range(0.001, 0.15) = 0.025;
uniform float sun_glow_power : hint_range(1.0, 16.0)   = 4.5;
uniform float moon_size      : hint_range(0.001, 0.1)  = 0.018;

// Wolken
uniform float cloud_speed   : hint_range(0.0, 1.0) = 0.015;
uniform float cloud_scale   : hint_range(0.1, 4.0) = 1.1;
uniform float cloud_density : hint_range(0.0, 1.0) = 0.50;

// Nebel am Horizont
uniform float horizon_fog_strength : hint_range(0.0, 1.0) = 0.55;
uniform vec4  horizon_fog_color    : source_color = vec4(0.08, 0.10, 0.20, 1.0);

// ─────────────────────────────────────────────
// Noise
// ─────────────────────────────────────────────
float hash(vec2 p) {
    p = fract(p * vec2(127.1, 311.7));
    p += dot(p, p + 19.19);
    return fract(p.x * p.y);
}

float hash3(vec3 p) {
    p = fract(p * vec3(127.1, 311.7, 74.7));
    p += dot(p, p + 19.19);
    return fract(p.x * p.y + p.y * p.z);
}

float vnoise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(
        mix(hash(i),           hash(i + vec2(1,0)), u.x),
        mix(hash(i+vec2(0,1)), hash(i + vec2(1,1)), u.x), u.y);
}

float fbm(vec2 p) {
    float v = 0.0; float a = 0.5;
    mat2 rot = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8));
    for (int i = 0; i < 5; i++) { v += a * vnoise(p); p = rot * p * 2.1; a *= 0.48; }
    return v;
}

float cloud_shape(vec2 uv, float t, float offset) {
    vec2 p = uv * cloud_scale + vec2(t + offset, offset * 0.3);
    vec2 q = vec2(fbm(p), fbm(p + vec2(5.2, 1.3)));
    float raw = fbm(p + q);
    return step(cloud_density + offset * 0.04, raw);
}

// ─────────────────────────────────────────────
// Sterne: mehrere Größenklassen + Farbtönung
// ─────────────────────────────────────────────
vec3 star_layer(vec2 uv, float grid, float threshold, float size, vec3 tint, float time_offset) {
    vec2 gv  = fract(uv * grid) - 0.5;
    vec2 id  = floor(uv * grid);
    float rnd = hash(id);
    if (rnd < threshold) return vec3(0.0);

    // Twinkle
    float twinkle = 0.7 + 0.3 * sin(TIME * (1.5 + rnd * 3.0) + rnd * 47.3 + time_offset);
    // Weicher Punkt
    float d = length(gv);
    float brightness = smoothstep(size, 0.0, d) * twinkle;

    // Leichte Zufallsfärbung (warmweiß bis kaltblau)
    vec3 color = mix(vec3(1.0, 0.85, 0.6), vec3(0.7, 0.85, 1.0), hash(id + vec2(7.3, 2.1)));
    return tint * color * brightness * (0.6 + rnd * 0.8);
}

// ─────────────────────────────────────────────
// SKY
// ─────────────────────────────────────────────
void sky() {
    vec3 dir = normalize(EYEDIR);

    float tod = time_of_day;

    float sun_angle = tod * TAU;
    vec3 sun_dir = normalize(vec3(sin(sun_angle), cos(sun_angle) * 0.8, -0.6));
    vec3 moon_dir = -sun_dir;

    float sun_height = clamp(sun_dir.y, 0.0, 1.0);
    float sun_below  = clamp(-sun_dir.y, 0.0, 1.0);

    float is_day    = smoothstep(0.0, 0.15, sun_height);
    float is_night  = smoothstep(0.0, 0.15, sun_below);
    float is_sunset = 1.0 - smoothstep(0.0, 0.22, abs(sun_dir.y));

    // ── Himmels-Gradient ──────────────────────────────────────────
    float up = clamp(dir.y, 0.0, 1.0);

    // Nachts: tiefes Blau-Schwarz mit etwas mehr Tiefe
    vec3 night_z = mix(night_zenith.rgb, vec3(0.005, 0.008, 0.04), 0.4);
    vec3 night_h = night_horizon.rgb;

    vec3 c_zenith  = mix(mix(night_z,           sunset_zenith.rgb,  is_sunset), day_zenith.rgb,  is_day);
    vec3 c_horizon = mix(mix(night_h,            sunset_horizon.rgb, is_sunset), day_horizon.rgb, is_day);

    // Weicherer Gradient-Übergang (stärkere Kurve nachts)
    float grad_curve = mix(0.5, 0.35, is_night);
    vec3 sky_col = mix(c_horizon, c_zenith, smoothstep(0.0, grad_curve + 0.25, up));

    // ── Horizont-Nebel (Tag & Nacht) ──────────────────────────────
    // Blendet nahe am Horizont (dir.y ≈ 0) einen Nebelschleier ein
    vec3 fog_col_day   = mix(day_horizon.rgb, vec3(0.8, 0.88, 0.95), 0.3);
    vec3 fog_col_night = horizon_fog_color.rgb;
    vec3 fog_col       = mix(fog_col_night, fog_col_day, is_day);

    float fog_band = smoothstep(0.18, -0.04, dir.y); // nur nahe Horizont
    sky_col = mix(sky_col, fog_col, fog_band * horizon_fog_strength);

    // Sonnenuntergangs-Glow am Horizont
    float sun_horiz_dot = dot(dir, sun_dir) * 0.5 + 0.5;
    sky_col += sunset_glow.rgb * pow(sun_horiz_dot, 8.0) * is_sunset * 0.8 * (1.0 - up * 2.0);

    // ── Atmosphärische Streuung am Nachthorizont ──────────────────
    // Mondschein-Aufhellung am Horizont
    float moon_horiz = dot(dir, vec3(moon_dir.x, 0.0, moon_dir.z));
    float moon_scatter = pow(clamp(moon_horiz * 0.5 + 0.5, 0.0, 1.0), 6.0);
    sky_col += vec3(0.05, 0.07, 0.18) * moon_scatter * is_night * (1.0 - up) * 0.6;

    // ── Sterne ───────────────────────────────────────────────────
    float star_brightness = is_night * (1.0 - is_sunset * 2.0);
    star_brightness = clamp(star_brightness, 0.0, 1.0);

    if (dir.y > -0.05 && star_brightness > 0.01) {
        // Projektion: gleichmäßig über die Himmelskugel
        float y_safe = max(dir.y, 0.001);
        vec2 star_uv = dir.xz / (y_safe + 0.3) * 0.6;

        // Schicht 1: Viele kleine, schwache Sterne
        vec3 s1 = star_layer(star_uv, 80.0,  0.94, 0.018, vec3(0.6), 0.0);
        // Schicht 2: Mittelgroße Sterne
        vec3 s2 = star_layer(star_uv, 40.0,  0.88, 0.028, vec3(0.9), 1.7);
        // Schicht 3: Helle Sterne (wenige)
        vec3 s3 = star_layer(star_uv, 18.0,  0.85, 0.04,  vec3(1.4), 3.3);
        // Schicht 4: Sehr helle Einzelsterne
        vec3 s4 = star_layer(star_uv, 9.0,   0.92, 0.055, vec3(2.2), 6.1);

        // Sterne verblassen nahe Horizont (atmosphärische Extinktion)
        float horizon_fade = smoothstep(0.0, 0.12, dir.y);
        vec3 all_stars = (s1 + s2 + s3 + s4) * horizon_fade;

        sky_col += all_stars * star_brightness;
    }

    // ── Milchstraße ───────────────────────────────────────────────
    if (dir.y > 0.0 && star_brightness > 0.01) {
        float y_safe = max(dir.y, 0.001);
        vec2 mw_uv = dir.xz / y_safe * 0.25;

        // Milchstraßen-Band: breites fbm-Band
        float mw_band = fbm(mw_uv * 0.3 + vec2(2.1, 0.7));
        float mw_thin = fbm(mw_uv * 0.7 + vec2(0.4, 3.2));

        // Band-Maske: konzentriert sich in einem Bogen
        float band_mask = exp(-pow(dir.x * 1.5 + 0.3, 2.0) * 2.0);
        band_mask *= smoothstep(0.02, 0.2, dir.y);

        float mw = (mw_band * 0.7 + mw_thin * 0.3) * band_mask;

        // Farbige Milchstraße: bläulich-lila Kern, warm außen
        vec3 mw_core  = vec3(0.30, 0.35, 0.60);
        vec3 mw_outer = vec3(0.15, 0.18, 0.35);
        vec3 mw_col   = mix(mw_outer, mw_core, mw_band);

        sky_col += mw_col * mw * 0.18 * star_brightness;

        // Extra: helle Kerndichte als Leuchten
        float mw_bright = max(mw - 0.5, 0.0) * 2.0;
        sky_col += vec3(0.4, 0.42, 0.7) * mw_bright * band_mask * 0.12 * star_brightness;
    }

    // ── Nachts: subtile Himmelsaufhellung (Airglow) ──────────────
    // In der Realität leuchtet der Nachthimmel leicht durch Airglow
    float airglow = smoothstep(0.0, 1.0, up) * 0.025 * is_night;
    sky_col += vec3(0.1, 0.15, 0.35) * airglow;

    // ── Sonne ─────────────────────────────────────────────────────
    float sun_dot  = dot(dir, sun_dir);
    float sun_disc = step(1.0 - sun_size, sun_dot);

    float g1 = step(1.0 - sun_size * 3.0,  sun_dot) * 0.25;
    float g2 = step(1.0 - sun_size * 8.0,  sun_dot) * 0.12;
    float g3 = step(1.0 - sun_size * 18.0, sun_dot) * 0.06;
    float g4 = pow(clamp(sun_dot, 0.0, 1.0), sun_glow_power) * 0.5;

    vec3 sun_col = mix(vec3(1.0, 0.55, 0.1), vec3(1.0, 0.97, 0.85), sun_height);
    sky_col += sun_col * (sun_disc + g1 + g2 + g3 + g4) * (1.0 - is_night);

    // ── Mond ──────────────────────────────────────────────────────
    float moon_dot  = dot(dir, moon_dir);
    float moon_disc = step(1.0 - moon_size, moon_dot);
    float moon_glow = step(1.0 - moon_size * 5.0, moon_dot) * 0.08;
    float moon_atm  = pow(clamp(moon_dot, 0.0, 1.0), 12.0) * 0.15;

    // Weicheres Mondleuchten (atmosphärischer Halo)
    float moon_halo = pow(clamp(moon_dot, 0.0, 1.0), 60.0) * 0.4;
    sky_col += vec3(0.55, 0.60, 0.75) * moon_halo * is_night;

    // Mondsichel
    vec3 moon_offset_dir = normalize(moon_dir + vec3(moon_size * 3.5, moon_size * 1.0, 0.0));
    float moon_cut   = step(1.0 - moon_size * 1.1, dot(dir, moon_offset_dir));
    float moon_shape = clamp(moon_disc - moon_cut, 0.0, 1.0);

    // Mondfarbe: leicht gelblich-weiß
    vec3 moon_col = mix(vec3(0.85, 0.88, 0.95), vec3(0.95, 0.92, 0.80), 0.3);
    sky_col += moon_col * (moon_shape * 2.0 + moon_glow + moon_atm) * is_night;

    // Mond beleuchtet Wolken/Umgebung leicht
    sky_col += vec3(0.08, 0.09, 0.18) * moon_shape * is_night * (1.0 - up * 0.5);

    // ── Wolken ────────────────────────────────────────────────────
    float cloud_mask = smoothstep(-0.02, 0.15, dir.y);
    float y_s = max(abs(dir.y), 0.015);
    vec2 c_uv = dir.xz / y_s * 0.4;
    float t   = TIME * cloud_speed;

    float clouds = 0.0;
    float shads  = 0.0;
    for (int i = 0; i < 3; i++) {
        float fi  = float(i);
        float sf  = 1.0 - fi * 0.2;
        float af  = 1.0 - fi * 0.28;
        float c   = cloud_shape(c_uv * sf, t * (1.0 - fi * 0.22), fi * 2.3);
        float sh  = cloud_shape(c_uv * sf + vec2(0.0, 0.018), t * (1.0 - fi * 0.22), fi * 2.3 + 0.1);
        clouds   += c  * af;
        shads    += max(sh - c, 0.0) * af * 0.5;
    }
    clouds = clamp(clouds, 0.0, 1.0) * cloud_mask;
    shads  = clamp(shads,  0.0, 1.0) * cloud_mask;

    vec3 cloud_day    = vec3(1.0, 0.98, 0.96);
    vec3 cloud_sunset = vec3(1.0, 0.60, 0.25);
    // Nachts: Wolken vom Mond leicht beleuchtet (silbrig-blau)
    vec3 cloud_night  = mix(vec3(0.05, 0.06, 0.12), vec3(0.18, 0.20, 0.30), moon_dot * 0.5 + 0.5) * is_night;
    vec3 cloud_bot_d  = vec3(0.72, 0.76, 0.82);
    vec3 cloud_bot_n  = vec3(0.04, 0.05, 0.10);

    vec3 cloud_top = mix(mix(cloud_night, cloud_sunset, is_sunset), cloud_day, is_day);
    vec3 cloud_bot = mix(cloud_bot_n, cloud_bot_d, is_day);

    vec3 cloud_col = mix(cloud_bot, cloud_top, clamp(dir.y * 3.0, 0.0, 1.0));
    sky_col = mix(sky_col, cloud_col,       clouds);
    sky_col = mix(sky_col, cloud_bot * 0.6, shads * (1.0 - clouds));

    // ── Posterize ─────────────────────────────────────────────────
    // Nachts weniger Posterize → weichere Farbverläufe
    float ps = mix(10.0, 18.0, is_day);
    float r = floor(sky_col.r * ps) / ps;
    float g = floor(sky_col.g * ps) / ps;
    float b = floor(sky_col.b * ps) / ps;

    COLOR = vec3(r, g, b);
}
