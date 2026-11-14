import test from 'node:test';
import assert from 'node:assert/strict';
import { createCarousel } from '../../deploy/landing/carousel.mjs';

function fixture() {
  let nextId = 0;
  const timers = new Map();
  const changes = [];
  let state;
  const clock = {
    setTimeout(fn, delay) { assert.equal(delay, 7000); timers.set(++nextId, fn); return nextId; },
    clearTimeout(id) { timers.delete(id); },
  };
  const carousel = createCarousel({count:6, clock, onChange:(...args) => changes.push(args), onState:s => {state=s;}});
  function tick() { const entry = timers.entries().next().value; if (entry) { timers.delete(entry[0]); entry[1](); } }
  return {carousel, timers, changes, tick, state:() => state};
}
test('automatic rotation wraps after six slides without live announcements', () => {
  const f = fixture(); f.carousel.pause(false);
  for(let i=0;i<7;i++) f.tick();
  assert.deepEqual(f.changes, [[1,false],[2,false],[3,false],[4,false],[5,false],[0,false],[1,false]]);
  assert.equal(f.timers.size,1);
});
test('hover, focus, hidden tab and modal blockers compose without duplicate timers', () => {
  const f=fixture(); f.carousel.pause(false);
  for(const reason of ['hover','focus','hidden','dialog','outside']) f.carousel.block(reason,true);
  f.tick(); assert.equal(f.changes.length,0);
  for(const reason of ['hover','focus','hidden','dialog']) f.carousel.block(reason,false);
  assert.equal(f.timers.size,0);
  f.carousel.block('outside',false); f.carousel.block('outside',false);
  assert.equal(f.timers.size,1); f.tick(); assert.deepEqual(f.changes,[[1,false]]);
});
test('manual selection pauses rotation until explicitly resumed', () => {
  const f=fixture(); f.carousel.pause(false); f.carousel.select(4);
  f.tick(); assert.deepEqual(f.changes,[[4,true]]); assert.equal(f.state().paused,true);
  f.carousel.block('hover',false); assert.equal(f.timers.size,0);
  f.carousel.pause(false); f.tick(); assert.deepEqual(f.changes.at(-1),[5,false]);
});
test('previous and next wrap in both directions', () => {
  const f=fixture(); f.carousel.step(-1); assert.deepEqual(f.changes.at(-1),[5,true]);
  f.carousel.step(1); assert.deepEqual(f.changes.at(-1),[0,true]);
});
test('reduced-motion pause survives visibility changes and cleanup stops timers', () => {
  const f=fixture(); f.carousel.pause(true); f.carousel.block('outside',true); f.carousel.block('outside',false);
  f.tick(); assert.equal(f.changes.length,0);
  f.carousel.pause(false); f.carousel.dispose(); f.tick();
  assert.equal(f.changes.length,0); assert.equal(f.timers.size,0);
});
