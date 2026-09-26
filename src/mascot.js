// Mascota Licurici — un licurici prietenos, desenat în SVG (crisp la orice mărime).
// Fără fișiere externe: totul inline, offline.
let uid = 0;

export function fireflySVG(size = 48, glow = true) {
  const id = 'ff' + (uid++);
  return `
<svg class="firefly" width="${size}" height="${size}" viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg" aria-hidden="true">
  <defs>
    <radialGradient id="${id}g" cx="50%" cy="50%" r="50%">
      <stop offset="0%" stop-color="#fff6c2"/>
      <stop offset="45%" stop-color="#f6df84"/>
      <stop offset="100%" stop-color="#f6df84" stop-opacity="0"/>
    </radialGradient>
    <linearGradient id="${id}b" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0%" stop-color="#8fb389"/>
      <stop offset="100%" stop-color="#6f9a6b"/>
    </linearGradient>
    <filter id="${id}s" x="-50%" y="-50%" width="200%" height="200%">
      <feGaussianBlur stdDeviation="2.4"/>
    </filter>
  </defs>
  ${glow ? `<circle cx="50" cy="70" r="34" fill="url(#${id}g)"/>` : ''}
  <!-- aripioare -->
  <ellipse cx="34" cy="46" rx="18" ry="12" fill="#eaf1ff" opacity="0.85" transform="rotate(-18 34 46)"/>
  <ellipse cx="66" cy="46" rx="18" ry="12" fill="#eaf1ff" opacity="0.85" transform="rotate(18 66 46)"/>
  <!-- antene -->
  <path d="M44 30 Q40 20 34 17" stroke="#6f9a6b" stroke-width="3" fill="none" stroke-linecap="round"/>
  <path d="M56 30 Q60 20 66 17" stroke="#6f9a6b" stroke-width="3" fill="none" stroke-linecap="round"/>
  <circle cx="33" cy="16" r="3.4" fill="#6f9a6b"/>
  <circle cx="67" cy="16" r="3.4" fill="#6f9a6b"/>
  <!-- corp -->
  <ellipse cx="50" cy="54" rx="18" ry="22" fill="url(#${id}b)"/>
  <ellipse cx="50" cy="38" rx="15" ry="13" fill="#7ba676"/>
  <!-- ochi prietenoși -->
  <circle cx="44" cy="37" r="5" fill="#fff"/><circle cx="45" cy="38" r="2.4" fill="#3a3a3a"/>
  <circle cx="56" cy="37" r="5" fill="#fff"/><circle cx="57" cy="38" r="2.4" fill="#3a3a3a"/>
  <!-- zâmbet -->
  <path d="M45 45 Q50 49 55 45" stroke="#3a3a3a" stroke-width="2" fill="none" stroke-linecap="round"/>
  <!-- coada strălucitoare -->
  <circle cx="50" cy="70" r="9" fill="#fff3ad" filter="url(#${id}s)"/>
  <circle cx="50" cy="70" r="6" fill="#fffbe0"/>
</svg>`;
}
