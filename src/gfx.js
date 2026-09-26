// Înlocuiește AUTOMAT orice emoji din pagină cu ilustrația reală OpenMoji (SVG desenat,
// cartoon, cu contururi — nu emoji de sistem). Merge global: un MutationObserver prinde
// tot ce se adaugă în DOM și transformă emoji-ul în <img>. Așa nicio pictogramă „ieftină".
// OpenMoji © HfG Gmünd, licență CC BY-SA 4.0 (menționat la „Despre").

const RE = /(?:\p{Extended_Pictographic}(?:️|‍\p{Extended_Pictographic}|[\u{1F3FB}-\u{1F3FF}])*|[0-9#*]️?⃣|[\u{1F1E6}-\u{1F1FF}]{2})/gu;
const hex = cp => cp.toString(16).toUpperCase().padStart(4, '0');
function nameOf(s) { return [...s].map(c => c.codePointAt(0)).filter(cp => cp !== 0xFE0F).map(hex).join('-'); }

function makeImg(emoji) {
  const img = document.createElement('img');
  img.className = 'gfx';
  img.src = 'art/openmoji/' + nameOf(emoji) + '.svg';
  img.alt = emoji;
  img.draggable = false;
  // dacă lipsește ilustrația, revenim la caracterul original (fără să stricăm nimic)
  img.onerror = () => { try { img.replaceWith(document.createTextNode(emoji)); } catch (e) {} };
  return img;
}

function parseNode(node) {
  if (node.nodeType === 3) {                 // nod text
    const txt = node.nodeValue;
    if (!txt) return;
    RE.lastIndex = 0;
    if (!RE.test(txt)) return;
    RE.lastIndex = 0;
    const frag = document.createDocumentFragment();
    let last = 0, m;
    while ((m = RE.exec(txt))) {
      if (m.index > last) frag.appendChild(document.createTextNode(txt.slice(last, m.index)));
      frag.appendChild(makeImg(m[0]));
      last = m.index + m[0].length;
    }
    if (last < txt.length) frag.appendChild(document.createTextNode(txt.slice(last)));
    node.replaceWith(frag);
  } else if (node.nodeType === 1) {          // element
    const t = node.tagName;
    if (t === 'IMG' || t === 'svg' || t === 'SVG') return;
    if (node.classList && node.classList.contains('gfx')) return;
    if (node.namespaceURI && node.namespaceURI.includes('svg')) return;
    [...node.childNodes].forEach(parseNode);
  }
}

export function parse(root) { try { parseNode(root); } catch (e) {} }

export function observe(root) {
  try {
    const obs = new MutationObserver(muts => {
      for (const mu of muts) mu.addedNodes.forEach(n => parse(n));
    });
    obs.observe(root, { childList: true, subtree: true });
  } catch (e) {}
  parse(root);
}
