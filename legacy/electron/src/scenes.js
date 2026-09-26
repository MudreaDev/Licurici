// Fundaluri ILUSTRATE, desenate în cod (SVG), pentru episoadele de explorat.
// Cartoon, culori calme (saturație joasă, prietenos cu autismul). Fără fișiere de imagine
// — totul procedural, offline (spirit .kkrieger). Fiecare scenă umple containerul
// (preserveAspectRatio „slice"). Nuanțele urmează paleta din styles.css.

// Nori blânzi, reutilizați în mai multe scene.
function clouds() {
  return `
    <g fill="#ffffff" opacity="0.85">
      <ellipse cx="180" cy="120" rx="70" ry="30"/>
      <ellipse cx="240" cy="130" rx="55" ry="26"/>
      <ellipse cx="820" cy="90"  rx="64" ry="27"/>
      <ellipse cx="880" cy="100" rx="48" ry="22"/>
    </g>`;
}
function sun(x = 900, y = 110) {
  return `
    <g transform="translate(${x},${y})">
      <circle r="52" fill="#f4d98a"/>
      <circle r="38" fill="#f7e6ad"/>
    </g>`;
}
// Copac blând (coroană rotundă).
function tree(x, y, s = 1, leaf = '#8fc9a0') {
  return `<g transform="translate(${x},${y}) scale(${s})">
    <rect x="-14" y="0" width="28" height="90" rx="12" fill="#b98a63"/>
    <circle cx="0"   cy="-20" r="70" fill="${leaf}"/>
    <circle cx="-52" cy="18"  r="48" fill="${leaf}"/>
    <circle cx="52"  cy="18"  r="48" fill="${leaf}"/>
  </g>`;
}

// Cadru comun: viewBox 1000×640, cer + deal.
function frame(inner, sky = ['#d7ecf5', '#eaf6f3']) {
  return `<svg class="scene-svg" viewBox="0 0 1000 640" preserveAspectRatio="xMidYMid slice" xmlns="http://www.w3.org/2000/svg" aria-hidden="true">
    <defs>
      <linearGradient id="sky" x1="0" y1="0" x2="0" y2="1">
        <stop offset="0" stop-color="${sky[0]}"/>
        <stop offset="1" stop-color="${sky[1]}"/>
      </linearGradient>
    </defs>
    <rect width="1000" height="640" fill="url(#sky)"/>
    ${inner}
  </svg>`;
}

const SCENES = {
  // Fermă & natură — pentru habitate.
  ferma: () => frame(`
    ${sun(120, 120)} ${clouds()}
    <path d="M0 470 Q250 420 500 460 T1000 450 V640 H0 Z" fill="#bfe0b4"/>
    <path d="M0 520 Q300 500 600 525 T1000 515 V640 H0 Z" fill="#a9d6a0"/>
    ${tree(160, 380, 1.05)} ${tree(860, 400, 0.9)}
    <g transform="translate(430,300)">
      <rect x="0" y="60" width="230" height="140" fill="#d99a86"/>
      <polygon points="-14,60 116,-6 246,60" fill="#b56f5e"/>
      <rect x="88" y="120" width="56" height="80" rx="6" fill="#8a4f42"/>
      <rect x="24" y="96"  width="40" height="40" rx="6" fill="#f3e4c6"/>
      <rect x="168" y="96" width="40" height="40" rx="6" fill="#f3e4c6"/>
    </g>`),

  // Livadă cu deal — pentru anotimpuri.
  anotimpuri: () => frame(`
    ${sun(880, 120)} ${clouds()}
    <path d="M0 480 Q500 400 1000 480 V640 H0 Z" fill="#c3e3b8"/>
    <path d="M0 560 Q500 510 1000 560 V640 H0 Z" fill="#abd8a2"/>
    ${tree(500, 300, 1.5, '#93cca4')}
    ${tree(180, 430, 0.8)} ${tree(830, 440, 0.85, '#a7d6b0')}`,
    ['#dcecf6', '#f0f6ee']),

  // Savană blândă — pentru hrana animalelor.
  hrana: () => frame(`
    ${sun(140, 130)} ${clouds()}
    <path d="M0 460 Q500 420 1000 470 V640 H0 Z" fill="#e6d9a8"/>
    <path d="M0 540 Q500 505 1000 545 V640 H0 Z" fill="#d8c890"/>
    ${tree(820, 360, 1.2, '#a9c98a')}
    <ellipse cx="230" cy="560" rx="140" ry="26" fill="#cdbc80" opacity="0.7"/>`,
    ['#e7eff5', '#f6f1e4']),

  // Parc curat — pentru reciclare.
  reciclare: () => frame(`
    ${sun(880, 120)} ${clouds()}
    <path d="M0 500 H1000 V640 H0 Z" fill="#bfe0b4"/>
    <path d="M0 500 Q500 470 1000 500" fill="none" stroke="#a9d6a0" stroke-width="18"/>
    ${tree(150, 400, 0.95)} ${tree(870, 410, 0.9, '#a7d6b0')}
    <rect x="360" y="470" width="280" height="34" rx="16" fill="#c8b79a"/>`,
    ['#d7ecf5', '#eef6ef']),

  // Cetate pe deal — pentru Istorie (simboluri, trecut).
  cetate: () => frame(`
    ${sun(880, 120)} ${clouds()}
    <path d="M0 480 Q500 440 1000 480 V640 H0 Z" fill="#bfe0b4"/>
    <path d="M0 555 Q500 520 1000 555 V640 H0 Z" fill="#a9d6a0"/>
    <g transform="translate(360,240)">
      <rect x="0" y="70" width="280" height="180" fill="#cabfa6"/>
      <rect x="-34" y="34" width="64" height="216" fill="#bdb298"/>
      <rect x="250" y="34" width="64" height="216" fill="#bdb298"/>
      <g fill="#bdb298">
        <rect x="-34" y="16" width="20" height="22"/><rect x="-2" y="16" width="20" height="22"/>
        <rect x="258" y="16" width="20" height="22"/><rect x="290" y="16" width="20" height="22"/>
      </g>
      <rect x="118" y="150" width="64" height="100" rx="32" fill="#7a5c43"/>
      <rect x="30" y="104" width="34" height="48" rx="6" fill="#8aa6b8"/>
      <rect x="216" y="104" width="34" height="48" rx="6" fill="#8aa6b8"/>
    </g>`,
    ['#dcecf6', '#eef6ef']),

  // Sală de muzeu (coloane) — pentru Istorie (trecut vs prezent).
  muzeu: () => frame(`
    <rect y="0"   width="1000" height="160" fill="#e6dcc8"/>
    <rect y="150" width="1000" height="320" fill="#efe9dd"/>
    <rect y="470" width="1000" height="170" fill="#d9cdb4"/>
    <g fill="#f2ecdd" stroke="#d8ccb2" stroke-width="3">
      ${[150, 380, 620, 850].map(x =>
        `<rect x="${x - 24}" y="160" width="48" height="308"/>` +
        `<rect x="${x - 40}" y="150" width="80" height="22"/>` +
        `<rect x="${x - 40}" y="450" width="80" height="22"/>`).join('')}
    </g>`,
    ['#efe9dd', '#efe9dd']),

  // Cameră caldă — pentru emoții / mâncare sănătoasă.
  camera: () => frame(`
    <rect y="0"   width="1000" height="460" fill="#eef1ea"/>
    <rect y="450" width="1000" height="190" fill="#d9c7ad"/>
    <g transform="translate(120,120)">
      <rect x="0" y="0" width="220" height="180" rx="10" fill="#bfe0ec" stroke="#c9b79a" stroke-width="10"/>
      <line x1="110" y1="0" x2="110" y2="180" stroke="#c9b79a" stroke-width="8"/>
      <line x1="0" y1="90" x2="220" y2="90" stroke="#c9b79a" stroke-width="8"/>
    </g>
    <ellipse cx="540" cy="548" rx="270" ry="58" fill="#e7b7a6" opacity="0.65"/>
    <g transform="translate(840,300)">
      <rect x="-24" y="120" width="48" height="62" rx="8" fill="#c98a63"/>
      <circle cx="0" cy="92" r="46" fill="#8fc9a0"/>
      <circle cx="-34" cy="120" r="30" fill="#8fc9a0"/><circle cx="34" cy="120" r="30" fill="#8fc9a0"/>
    </g>`,
    ['#f2f4ef', '#eef1ea']),

  // Stradă — pentru siguranță.
  oras: () => frame(`
    ${sun(880, 110)} ${clouds()}
    <rect y="430" width="1000" height="90"  fill="#cdd3d6"/>
    <rect y="500" width="1000" height="140" fill="#8f9498"/>
    <g fill="#eef1ea">${[430, 470, 510, 550, 590, 630].map(x => `<rect x="${x}" y="500" width="26" height="140"/>`).join('')}</g>
    <g>
      <rect x="80"  y="230" width="160" height="200" fill="#d7c9b0"/>
      <rect x="300" y="180" width="150" height="250" fill="#c9b79a"/>
      <rect x="720" y="210" width="170" height="220" fill="#d2c3a8"/>
      <g fill="#bfe0ec">${[110, 150, 330, 370, 750, 790].map(x => `<rect x="${x}" y="262" width="30" height="36"/>`).join('')}</g>
    </g>`,
    ['#dcecf6', '#eef6ef']),

  // Hartă-overworld: drum șerpuit prin natură (pinii se așază peste, în explore.js).
  harta: () => frame(`
    ${sun(120, 100)} ${clouds()}
    <path d="M0 430 Q250 370 500 420 T1000 400 V640 H0 Z" fill="#c3e3b8"/>
    <path d="M0 520 Q300 490 600 520 T1000 505 V640 H0 Z" fill="#abd8a2"/>
    <path d="M120 500 C 300 430, 320 330, 470 330 S 700 460, 720 380 S 860 250, 900 250"
          fill="none" stroke="#e6d3a8" stroke-width="34" stroke-linecap="round"/>
    <path d="M120 500 C 300 430, 320 330, 470 330 S 700 460, 720 380 S 860 250, 900 250"
          fill="none" stroke="#efe1bf" stroke-width="16" stroke-linecap="round" stroke-dasharray="4 26"/>
    ${tree(210, 300, 0.8)} ${tree(620, 250, 0.9, '#a7d6b0')} ${tree(830, 430, 0.85)}`,
    ['#dcecf6', '#eef6ef'])
};

// Întoarce markup-ul SVG pentru o scenă (sau o scenă neutră dacă numele lipsește).
export function sceneSVG(name) {
  const fn = SCENES[name] || SCENES.harta;
  return fn();
}
