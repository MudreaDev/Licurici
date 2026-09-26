// Clasele (grădiniță + 1-4) și materiile — pentru un produs aliniat curriculumului primar.
import { store } from './store.js';

export const GRADES = [
  { id: 'gradinita', name: 'Grădiniță', emoji: '🧸' },
  { id: 'clasa1',    name: 'Clasa 1',   emoji: '1️⃣' },
  { id: 'clasa2',    name: 'Clasa 2',   emoji: '2️⃣' },
  { id: 'clasa3',    name: 'Clasa 3',   emoji: '3️⃣' },
  { id: 'clasa4',    name: 'Clasa 4',   emoji: '4️⃣' }
];
export const GRADE_ORDER = GRADES.map(g => g.id);

export function gradeIndex(id) { const i = GRADE_ORDER.indexOf(id); return i < 0 ? 0 : i; }
export function currentGrade() { return store.get('grade') || 'clasa1'; }
export function gradeInfo(id) { return GRADES.find(g => g.id === id) || GRADES[1]; }
// Tier implicit de dificultate din clasă (folosit de jocurile care scalează): grădiniță→1 … clasa4→5.
export function gradeTier(id = currentGrade()) { return gradeIndex(id) + 1; }

// Materiile (grupare curriculară pentru meniu).
export const SUBJECTS = [
  { id: 'romana',      name: 'Limba română',    emoji: '📖', color: '#e79b86' },
  { id: 'matematica',  name: 'Matematică',       emoji: '🔢', color: '#5b9bb5' },
  { id: 'timp-bani',   name: 'Timp & bani',      emoji: '🕐', color: '#6fb0c8' },
  { id: 'stiinte',     name: 'Științe & mediu',  emoji: '🌍', color: '#6bbf8a' },
  { id: 'istorie',     name: 'Istorie',          emoji: '🏛️', color: '#c9a06a' },
  { id: 'forme',       name: 'Forme & logică',   emoji: '🔷', color: '#a9a3d1' },
  { id: 'emotii',      name: 'Emoții & viață',   emoji: '💙', color: '#f0a9c0' },
  { id: 'engleza',     name: 'Engleză',          emoji: '🌐', color: '#f2cf6b' }
];
export function subjectInfo(id) { return SUBJECTS.find(s => s.id === id); }
