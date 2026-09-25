// Deterministic seeded PRNG + value-noise helpers used by the visual engine.
// No external dependencies: keeps the "demo mode" fully self-contained and
// license-free, per the Product Mission's emphasis on deterministic signal
// processing over black-box generation.

export function mulberry32(seed: number) {
  let a = seed >>> 0;
  return function rand() {
    a |= 0;
    a = (a + 0x6d2b79f5) | 0;
    let t = Math.imul(a ^ (a >>> 15), 1 | a);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

export function hashString(str: string): number {
  let h = 2166136261;
  for (let i = 0; i < str.length; i++) {
    h ^= str.charCodeAt(i);
    h = Math.imul(h, 16777619);
  }
  return h >>> 0;
}

// Simple 2D value-noise (smoothstep interpolated hash lattice). Cheap and
// dependency-free; sufficient for organic density fields at glyph-grid
// resolution.
function hash2(x: number, y: number, seed: number): number {
  let n = x * 374761393 + y * 668265263 + seed * 974521;
  n = (n ^ (n >> 13)) * 1274126177;
  n = n ^ (n >> 16);
  return ((n >>> 0) % 100000) / 100000;
}

function smooth(t: number) {
  return t * t * (3 - 2 * t);
}

export function valueNoise2D(x: number, y: number, seed = 0): number {
  const xi = Math.floor(x);
  const yi = Math.floor(y);
  const xf = x - xi;
  const yf = y - yi;
  const tl = hash2(xi, yi, seed);
  const tr = hash2(xi + 1, yi, seed);
  const bl = hash2(xi, yi + 1, seed);
  const br = hash2(xi + 1, yi + 1, seed);
  const u = smooth(xf);
  const v = smooth(yf);
  const top = tl + (tr - tl) * u;
  const bottom = bl + (br - bl) * u;
  return top + (bottom - top) * v;
}

// Fractal sum of a few octaves for richer organic texture.
export function fbm2D(x: number, y: number, seed = 0, octaves = 3): number {
  let total = 0;
  let amp = 0.5;
  let freq = 1;
  let max = 0;
  for (let i = 0; i < octaves; i++) {
    total += valueNoise2D(x * freq, y * freq, seed + i * 101) * amp;
    max += amp;
    amp *= 0.5;
    freq *= 2;
  }
  return total / max;
}
