// Test de încărcare (README §19): sincronizarea sesiunilor de pe tabletă, ținta p95 < 200 ms.
// Pe un server de TEST (niciodată producția), cu un cont de test care are acordul SYNC și un copil:
//   k6 run -e API=https://api.test.licurici.ro/api/v1 -e EMAIL=test@exemplu.ro -e PASSWORD=... tools/k6/sync.js
// Fiecare iterație trimite o sesiune nouă (id unic) construită din fixture-ul contractului Dart ↔ TS.
import http from 'k6/http';
import { check } from 'k6';
import { uuidv4 } from 'https://jslib.k6.io/k6-utils/1.4.0/index.js';

const API = __ENV.API || 'http://localhost:3000/api/v1';
const fixture = JSON.parse(open('../../backend/src/sync/sync-fixture.json'));

export const options = {
  scenarios: {
    sync: { executor: 'constant-arrival-rate', rate: 200, timeUnit: '1s', duration: '2m', preAllocatedVUs: 50, maxVUs: 300 },
  },
  thresholds: {
    'http_req_duration{name:sync}': ['p(95)<200'],
    'checks': ['rate>0.99'],
  },
};

const json = { headers: { 'content-type': 'application/json' } };

export function setup() {
  const login = http.post(`${API}/auth/login`, JSON.stringify({ email: __ENV.EMAIL, password: __ENV.PASSWORD }), json);
  check(login, { autentificat: (r) => r.status === 200 });
  const token = login.json('accessToken');
  const auth = { headers: { ...json.headers, authorization: `Bearer ${token}` } };
  const kids = http.get(`${API}/children`, auth).json();
  return { auth, childId: kids[0].id };
}

export default function ({ auth, childId }) {
  const s = fixture.sessions[Math.floor(Math.random() * fixture.sessions.length)];
  const body = { sessions: [{ ...s, record: { ...s.record, id: uuidv4() } }] };
  const r = http.post(`${API}/children/${childId}/sessions`, JSON.stringify(body), { ...auth, tags: { name: 'sync' } });
  check(r, { acceptat: (res) => res.status === 201 || res.status === 200 });
}
