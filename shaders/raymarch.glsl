precision highp float;
uniform float uTime;
uniform vec3 uCameraPos;
uniform vec2 uCameraRot;
uniform vec2 uResolution;

const int MAX_STEPS = 1000;
const float MAX_DIST = 100.0;
const float SURF_DIST = 0.001;

// Signed distance function for a sphere
float sphereSDF(vec3 p, vec3 center, float radius) {
    return length(p - center) - radius;
}

float sdBox( vec3 p, vec3 b )
{
  vec3 q = abs(p) - b;
  return length(max(q,0.0)) + min(max(q.x,max(q.y,q.z)),0.0);
}

float sdCross( vec3 p )
{
  float da = sdBox(p.xyz,vec3(255.0,1.0,1.0));
  float db = sdBox(p.yzx,vec3(1.0,255.0,1.0));
  float dc = sdBox(p.zxy,vec3(1.0,1.0,255.0));
  return min(da,min(db,dc));
}

// Signed distance function for a plane
float planeSDF(vec3 p, vec4 n) {
    return dot(p, n.xyz) + n.w;
}

// Repeat a point in space
vec3 opRep(vec3 p, vec3 c) {
    return mod(p + 0.5 * c, c) - 0.5 * c;
}

// Scene SDF
float sceneSDF(vec3 p) {
    // Create grid of spheres
    vec3 boxP = p - vec3(0.0, 2.0, 0.0);
    float d = sphereSDF(boxP,vec3(0.0), 1.0);

   float s = 1.0;
   for( int m=0; m<5; m++ )
   {
      vec3 a = mod( boxP*s, 2.0 )-1.0;
      s *= 3.0;
      vec3 r = 1.0 - 3.0*abs(a);

      float c = sdCross(r)/s;
      d = max(d,c);
   }

    // Ground plane
    float plane = planeSDF(p, vec4(0.0, 1.0, 0.0, 0.0));
    
    return min(plane, d);
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
float raymarch(vec3 ro, vec3 rd) {
    float d0 = 0.0;
    
    for(int i = 0; i < MAX_STEPS; i++) {
        vec3 p = ro + rd * d0;
        float ds = sceneSDF(p);
        d0 += ds;
        if(ds < SURF_DIST || d0 > MAX_DIST) break;
    }
    
    return d0;
}

void main() {
    vec2 uv = (gl_FragCoord.xy - 0.5 * uResolution.xy) / uResolution.y;
    
    // Camera setup with rotation
    vec3 ro = uCameraPos;
    mat3 camMatrix = getCameraRotation();
    vec3 rd = camMatrix * normalize(vec3(uv.x, uv.y, 1.0));
    
    float d = raymarch(ro, rd);
    
    vec3 col = vec3(0.0);
    
    if(d < MAX_DIST) {
        vec3 p = ro + rd * d;
        vec3 normal = calcNormal(p);
        
        // Basic lighting
        vec3 lightPos = vec3(2.0, 4.0, -3.0);
        vec3 lightDir = normalize(lightPos - p);
        float diff = max(dot(normal, lightDir), 0.0);
        
        // Add some ambient occlusion based on height
        float ao = clamp(p.y * 0.5, 0.0, 1.0);
        
        // Checkerboard pattern for the floor
        float checkerboard = mod(floor(p.x) + floor(p.z), 2.0);
        vec3 albedo = mix(vec3(0.2), vec3(0.8), checkerboard);
        
        col = albedo * (diff * 0.8 + 0.2);
    }
    
    // Add some fog
    col = mix(col, vec3(0.6, 0.7, 0.8), 1.0 - exp(-0.02 * d));
    
    // Gamma correction
    col = pow(col, vec3(0.4545));
    
    gl_FragColor = vec4(col, 1.0);
}