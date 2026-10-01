// Pajiștea generată din seed (SceneSpec, licurici_core/lib/src/scene.dart):
// cer în degradeu, soare blând, nori din zgomot fractal, două rânduri de dealuri cu paralaxă.
// Ordinea uniformelor e contractul cu `shared/fx/scene_background.dart`.
#include <flutter/runtime_effect.glsl>

precision mediump float;

uniform vec2 uSize;      // 0, 1
uniform float uTime;     // 2  secunde
uniform float uSeed;     // 3  forma dealurilor
uniform float uCloud;    // 4  acoperirea cu nori 0..1
uniform float uWind;     // 5  viteza norilor
uniform float uParallax; // 6  decalaj orizontal (-1..1), urmează derularea
uniform vec3 uSkyTop;    // 7..9
uniform vec3 uSkyBottom; // 10..12
uniform vec3 uHillFar;   // 13..15
uniform vec3 uHillNear;  // 16..18
uniform vec3 uCloudCol;  // 19..21
uniform vec3 uGlow;      // 22..24
uniform float uQuiet;    // 25 0 = acasă, 1 = ecran de joc (estompat)

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
  float a = hash(i);
  float b = hash(i + vec2(1.0, 0.0));
  float c = hash(i + vec2(0.0, 1.0));
  float d = hash(i + vec2(1.0, 1.0));
  return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float fbm(vec2 p) {
  float v = 0.0;
  float a = 0.5;
  for (int i = 0; i < 5; i++) {
    v += a * noise(p);
    p = p * 2.03 + vec2(17.1, 9.2);
    a *= 0.5;
  }
  return v;
}

// Profilul unui deal: înălțimea (0 = sus) la abscisa x.
float hill(float x, float base, float amp, float freq, float offset) {
  return base - amp * (fbm(vec2(x * freq + offset, offset * 0.37)) - 0.5) * 2.0;
}

void main() {
  vec2 frag = FlutterFragCoord().xy;
  vec2 uv = frag / uSize;
  float aspect = uSize.x / uSize.y;

  // Cerul
  vec3 col = mix(uSkyTop, uSkyBottom, pow(uv.y, 0.85));

  // Soarele: doar o strălucire caldă, fără disc orbitor.
  vec2 sunPos = vec2(0.82 - uParallax * 0.02, 0.16);
  float sun = exp(-length((uv - sunPos) * vec2(aspect, 1.0)) * 5.5);
  col = mix(col, uGlow, sun * 0.45);

  // Norii: zgomot fractal care alunecă lent, doar în partea de sus.
  vec2 cp = vec2(uv.x * aspect * 1.6 + uTime * uWind * 6.0 - uParallax * 0.15, uv.y * 3.2);
  float n = fbm(cp + uSeed);
  float cloud = smoothstep(1.0 - uCloud * 0.75, 1.12 - uCloud * 0.6, n);
  cloud *= smoothstep(0.62, 0.15, uv.y);
  col = mix(col, uCloudCol, cloud * 0.85);

  // Dealurile (departe și aproape), cu margini netede și paralaxă diferită.
  float px = uv.x * aspect;
  float farH = hill(px - uParallax * 0.08, 0.66, 0.07, 0.55, uSeed);
  float nearH = hill(px - uParallax * 0.22, 0.80, 0.06, 0.8, uSeed + 31.0);
  float aa = 1.5 / uSize.y;

  float far = smoothstep(farH - aa, farH + aa, uv.y);
  vec3 farCol = mix(uHillFar, uSkyBottom, 0.25) * (0.97 + 0.06 * (1.0 - (uv.y - farH) * 3.0));
  col = mix(col, farCol, far);

  float near = smoothstep(nearH - aa, nearH + aa, uv.y);
  float grass = fbm(vec2(px * 18.0, uv.y * 6.0) + uSeed) * 0.08;
  vec3 nearCol = uHillNear * (1.02 - (uv.y - nearH) * 0.35 + grass);
  col = mix(col, nearCol, near);

  // Ecranele de joc: mai luminos și mai puțin saturat, ca stimulul să rămână vedeta.
  float gray = dot(col, vec3(0.299, 0.587, 0.114));
  vec3 quiet = mix(mix(col, vec3(gray), 0.35), vec3(1.0), 0.28);
  col = mix(col, quiet, uQuiet);

  fragColor = vec4(col, 1.0);
}
