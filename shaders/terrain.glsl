precision highp float;
uniform float uTime;
uniform vec3 uCameraPos;
uniform vec2 uCameraRot;

const int MAX_STEPS = 1000;
const float MAX_DIST = 100.0;
const float SURF_DIST = 0.01;


vec4 mod289(vec4 x)
{
  return x - floor(x * (1.0 / 289.0)) * 289.0;
}

vec4 permute(vec4 x)
{
  return mod289(((x*34.0)+10.0)*x);
}

vec4 taylorInvSqrt(vec4 r)
{
  return 1.79284291400159 - 0.85373472095314 * r;
}

vec2 fade(vec2 t) {
  return t*t*t*(t*(t*6.0-15.0)+10.0);
}

// Classic Perlin noise
float perlinNoise(vec2 P)
{
  vec4 Pi = floor(P.xyxy) + vec4(0.0, 0.0, 1.0, 1.0);
  vec4 Pf = fract(P.xyxy) - vec4(0.0, 0.0, 1.0, 1.0);
  Pi = mod289(Pi); // To avoid truncation effects in permutation
  vec4 ix = Pi.xzxz;
  vec4 iy = Pi.yyww;
  vec4 fx = Pf.xzxz;
  vec4 fy = Pf.yyww;

  vec4 i = permute(permute(ix) + iy);

  vec4 gx = fract(i * (1.0 / 41.0)) * 2.0 - 1.0 ;
  vec4 gy = abs(gx) - 0.5 ;
  vec4 tx = floor(gx + 0.5);
  gx = gx - tx;

  vec2 g00 = vec2(gx.x,gy.x);
  vec2 g10 = vec2(gx.y,gy.y);
  vec2 g01 = vec2(gx.z,gy.z);
  vec2 g11 = vec2(gx.w,gy.w);

  vec4 norm = taylorInvSqrt(vec4(dot(g00, g00), dot(g01, g01), dot(g10, g10), dot(g11, g11)));

  float n00 = norm.x * dot(g00, vec2(fx.x, fy.x));
  float n10 = norm.y * dot(g10, vec2(fx.y, fy.y));
  float n01 = norm.z * dot(g01, vec2(fx.z, fy.z));
  float n11 = norm.w * dot(g11, vec2(fx.w, fy.w));

  vec2 fade_xy = fade(Pf.xy);
  vec2 n_x = mix(vec2(n00, n01), vec2(n10, n11), fade_xy.x);
  float n_xy = mix(n_x.x, n_x.y, fade_xy.y);
  return 2.3 * n_xy;
}


// Fractal Brownian Motion (fBm) with Perlin noise
float fbm(vec2 p) {
    float value = 0.0;
    float amplitude = 0.5;
    float frequency = 0.5;
    
    // Add multiple octaves of noise
    for (int i = 0; i < 6; i++) {
        value += amplitude * perlinNoise(p * frequency);
        frequency *= 2.0;
        amplitude *= 0.5;
    }
    
    return value;
}


// Signed distance function for a plane
float planeSDF(vec3 p, vec4 n) {
    return dot(p, n.xyz) + n.w;
}

float terrainDist(vec2 xz) {
    return 10.0 * fbm(xz * 0.1);
}

// Scene SDF
float sceneSDF(vec3 p) {

    // Ground plane
    float plane = planeSDF(p + vec3(0.0, terrainDist(p.xz), 0.0), vec4(0.0, 1.0, 0.0, 0.0));
    
    return plane;
}

// Calculate normal using small offsets
vec3 calcNormal(vec3 p) {
    float h = 0.0001;
    vec2 k = vec2(1.0, -1.0);
    return normalize(
        k.xyy * sceneSDF(p + k.xyy * h) +
        k.yyx * sceneSDF(p + k.yyx * h) +
        k.yxy * sceneSDF(p + k.yxy * h) +
        k.xxx * sceneSDF(p + k.xxx * h)
    );
}

// Get rotation matrix for camera
mat3 getCameraRotation() {
    float cx = cos(uCameraRot.x);
    float sx = sin(uCameraRot.x);
    float cy = cos(uCameraRot.y);
    float sy = sin(uCameraRot.y);

    return mat3(
        cy, 0.0, -sy,
        sx*sy, cx, sx*cy,
        cx*sy, -sx, cx*cy
    );
}

// Raymarching function
vec4 raymarch(vec3 ro, vec3 rd) {
    float d0 = 0.0;
    
    for(int i = 0; i < MAX_STEPS; i++) {
        vec3 p = ro + rd * d0;
        float ds = sceneSDF(p);
        d0 += ds;
        if(ds < SURF_DIST || d0 > MAX_DIST) break;
    }
    
    return vec4(d0, 0.0, 0.0, 0.0);
}

void main() {
    vec2 uv = (gl_FragCoord.xy - 0.5 * vec2(800.0, 400.0)) / 400.0;
    
    // Camera setup with rotation
    vec3 ro = uCameraPos;
    mat3 camMatrix = getCameraRotation();
    vec3 rd = camMatrix * normalize(vec3(uv.x, uv.y, 1.0));
    

    vec4 d = raymarch(ro, rd);
    
    vec3 col = vec3(0.0);
    vec3 lightPos = vec3(2.0, 4.0, -3.0);

    if(d.x < MAX_DIST) {
        vec3 p = ro + rd * d.x;
        vec3 normal = calcNormal(p);
        
        // Basic lighting
        vec3 lightDir = normalize(lightPos - p);
        float diff = max(dot(normal, lightDir), 0.0);
        
        // Add some ambient occlusion based on height
        float ao = clamp(p.y * 0.5, 0.0, 1.0);
        
        vec3 albedo = mix(vec3(0.2), vec3(0.8), vec3(ao));
        
        col = albedo * (diff * 0.8 + 0.2);

        // Add some fog
        col = mix(col, vec3(0.6, 0.7, 0.8), 1.0 - exp(-0.02 * d.x));

    }
    else {
        // Sky color
        vec3 col1 = vec3(0.6, 0.7, 0.8);
        // Night sky
        vec3 col2 = vec3(0.0, 0.0, 0.1);
        vec2 uv = vec2(atan(rd.z, rd.x)/3.14, (asin(rd.y)+(3.14/2.0))/3.14);
        float theta_diff = acos(dot(normalize(lightPos), normalize(rd)));
        // glow around horizon
        vec3 skyColor = mix(col1, col2, uv.y*1.0);

        if (theta_diff < 0.1) {
            col = vec3(1.0, 1.0, 1.0);
        }
        else if (theta_diff < 0.2) {
            col = mix(vec3(1.0, 1.0, 1.0), skyColor, (theta_diff-0.1)/0.1);
        }
        else {
            col = skyColor;
        }
    }
    
    
    // Gamma correction
    col = pow(col, vec3(0.4545));
    
    gl_FragColor = vec4(col, 1.0);
}