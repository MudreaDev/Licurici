// Apa (Pescarul): degradeu de adâncime, raze de lumină care se leagănă, caustice blânde.
// Ordinea uniformelor e contractul cu `shared/fx/scene_background.dart`.
#include <flutter/runtime_effect.glsl>

precision mediump float;

uniform vec2 uSize;    // 0, 1
uniform float uTime;   // 2
uniform float uSeed;   // 3
uniform vec3 uTop;     // 4..6  apa de la suprafață
uniform vec3 uDeep;    // 7..9  apa de jos
uniform vec3 uLight;   // 10..12 culoarea luminii
uniform float uQuiet;  // 13

out vec4 fragColor;

float hash(vec2 p) {
  p = fract(p * vec2(123.34, 456.21));
  p += dot(p, p + 45.32);
  return fract(p.x * p.y);
}

float noise(vec2 p) {
  vec2 i = floor(p);
  vec2 f = fract(p);
  vec2 u = f * f * (3.0 - 2.0 * f);
  return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
             mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

void main() {
  vec2 uv = FlutterFragCoord().xy / uSize;
  float aspect = uSize.x / uSize.y;
  float t = uTime;

  vec3 col = mix(uTop, uDeep, smoothstep(0.0, 1.0, uv.y));

  // Raze: benzi oblice care se leagănă lent și se sting spre fund.
  float x = uv.x * aspect + uv.y * 0.35;
  float rays = 0.0;
  for (int i = 0; i < 3; i++) {
    float fi = float(i);
    float f = 2.0 + fi * 1.7;
    rays += pow(0.5 + 0.5 * sin(x * f + uSeed * (1.0 + fi) + sin(t * (0.15 + fi * 0.05)) * 0.8), 6.0);
  }
  rays *= (1.0 - uv.y) * 0.16;
  col = mix(col, uLight, rays);

  // Caustice: rețea de zgomot deformată în timp, doar aproape de suprafață.
  vec2 p = vec2(uv.x * aspect, uv.y) * 7.0;
  float c1 = noise(p + vec2(t * 0.12, t * 0.05) + uSeed);
  float c2 = noise(p * 1.3 - vec2(t * 0.07, t * 0.1) + uSeed * 2.0);
  float caustic = pow(1.0 - abs(c1 - c2), 8.0) * smoothstep(0.75, 0.0, uv.y);
  col += uLight * caustic * 0.12;

  float gray = dot(col, vec3(0.299, 0.587, 0.114));
  vec3 quiet = mix(mix(col, vec3(gray), 0.3), vec3(1.0), 0.22);
  col = mix(col, quiet, uQuiet);

  fragColor = vec4(col, 1.0);
}
