// Timer isolated from the DOM so pause/resume behavior can be tested precisely.
export function createCarousel({ count, onChange, onState, delay = 7000, clock = globalThis }) {
  let index = 0;
  let paused = false;
  let timer;
  let disposed = false;
  const blockers = new Set();
  function sync() {
    clock.clearTimeout(timer);
    const running = !disposed && !paused && blockers.size === 0;
    onState({ running, paused });
    if (running) timer = clock.setTimeout(() => {
      index = (index + 1) % count;
      onChange(index, false);
      sync();
    }, delay);
  }
  return {
    select(next) {
      if (disposed) return;
      index = ((next % count) + count) % count;
      paused = true;
      onChange(index, true);
      sync();
    },
    step(delta) { this.select(index + delta); },
    pause(value) { paused = value; sync(); },
    block(reason, value) { value ? blockers.add(reason) : blockers.delete(reason); sync(); },
    dispose() { disposed = true; sync(); },
  };
}
