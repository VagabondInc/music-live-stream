import type { GlyphGrid } from './grid';
import type { SceneCtx } from './sceneTypes';

export interface Scene {
  reset(seed: number): void;
  draw(grid: GlyphGrid, ctx: SceneCtx): void;
}

export function motionScale(dna: SceneCtx['dna']): number {
  if (dna.reduceMotion) return 0.25;
  const base = dna.performance === 'intense' ? 1.4 : dna.performance === 'subtle' ? 0.65 : 1;
  return base * (0.3 + (dna.motion / 100) * 1.2);
}

export function glitchAllowed(dna: SceneCtx['dna']): boolean {
  return !dna.photosensitivitySafe && !dna.reduceMotion && dna.glitch > 4;
}
