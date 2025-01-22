precision highp float;
uniform vec2 uResolution;
uniform float uTime;

#define MAX_STEPS 100
#define MAX_DIST 100.0
#define SURF_DIST 0.01

// Hash function for noise
float hash(vec2 p) {
    p = fract(p * vec2(234.34, 435.345));
    p += dot(p, p + 34.23);
    return fract(p.x * p.y);
}

// 2D Noise function
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

// FBM (Fractal Brownian Motion)
float fbm(vec2 p) {
    float value = 0.0;
    float amplitude = 0.5;
    float frequency = 1.0;
    
    for(int i = 0; i < 6; i++) {
        value += amplitude * noise(p * frequency);
        amplitude *= 0.5;
        frequency *= 2.0;
    }
    
    return value;
}

// Signed Distance Function for the terrain
float getTerrain(vec3 p) {
    float height = fbm(p.xz * 0.3) * 2.0;
    height += fbm(p.xz * 1.0) * 0.5;
    return p.y - height;
}

// Raymarching function
float raymarch(vec3 ro, vec3 rd) {
    float dO = 0.0;
    
    for(int i = 0; i < MAX_STEPS; i++) {
        vec3 p = ro + rd * dO;
        float dS = getTerrain(p);
        dO += dS;
        if(dO > MAX_DIST || abs(dS) < SURF_DIST) break;
    }
    
    return dO;
}

// Calculate normal
vec3 getNormal(vec3 p) {
    float d = getTerrain(p);
    vec2 e = vec2(0.01, 0.0);
    vec3 n = d - vec3(
        getTerrain(p - e.xyy),
        getTerrain(p - e.yxy),
        getTerrain(p - e.yyx)
    );
    return normalize(n);
}

void main() {
    vec2 uv = (gl_FragCoord.xy - 0.5 * uResolution.xy) / uResolution.y;
    
    // Camera setup
    vec3 ro = vec3(sin(uTime * 0.5) * 5.0, 2.5, cos(uTime * 0.5) * 5.0);
    vec3 lookAt = vec3(0.0, 0.0, 0.0);
    vec3 forward = normalize(lookAt - ro);
    vec3 right = normalize(cross(vec3(0.0, 1.0, 0.0), forward));
    vec3 up = cross(forward, right);
    vec3 rd = normalize(forward + right * uv.x + up * uv.y);

    // Raymarching
    float d = raymarch(ro, rd);
    vec3 p = ro + rd * d;
    vec3 n = getNormal(p);

    // Lighting
    vec3 sunDir = normalize(vec3(0.8, 0.4, 0.2));
    float sunDiffuse = max(dot(n, sunDir), 0.0);
    float sunShadow = step(raymarch(p + n * 0.02, sunDir), MAX_DIST);
    
    // Color
    vec3 col = vec3(0.2, 0.3, 0.1);
    col *= 0.5 + 0.5 * n.y;
    col *= sunDiffuse * sunShadow;
    
    // Fog
    float fog = 1.0 - exp(-d * 0.05);
    vec3 fogCol = vec3(0.6, 0.7, 0.8);
    col = mix(col, fogCol, fog);
    
    // Gamma correction
    col = pow(col, vec3(0.4545));
    
    gl_FragColor = vec4(col, 1.0);
}