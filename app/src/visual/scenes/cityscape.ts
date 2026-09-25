import { GlyphGrid } from '../grid';
import type { SceneCtx } from '../sceneTypes';
import type { Scene } from '../scene';
import { motionScale } from '../scene';
import { lerpColor } from '../palette';
import { mulberry32, hashString } from '../../audio/noise';

interface Building {
  x0: number;
  x1: number;
  height: number;
  flickerSeed: number;
}

const VIRTUAL_WIDTH = 260;

export class CityscapeScene implements Scene {
  private buildings: Building[] = [];
  private stars: { x: number; y: number; phase: number }[] = [];
  private seed = 1;

  reset(seed: number) {
    this.seed = seed;
    const rng = mulberry32(seed);
    this.buildings = [];
    let x = 0;
    while (x < VIRTUAL_WIDTH) {
      const w = 3 + Math.floor(rng() * 6);
      const h = 3 + Math.floor(rng() * 14);
      this.buildings.push({ x0: x, x1: x + w, height: h, flickerSeed: Math.floor(rng() * 1e6) });
      x += w + 1;
    }
    this.stars = [];
    for (let i = 0; i < 60; i++) {
      this.stars.push({ x: rng() * VIRTUAL_WIDTH, y: rng() * 0.6, phase: rng() * Math.PI * 2 });
    }
  }

  private buildingAt(vx: number): Building {
    const wrapped = ((vx % VIRTUAL_WIDTH) + VIRTUAL_WIDTH) % VIRTUAL_WIDTH;
    for (const b of this.buildings) if (wrapped >= b.x0 && wrapped < b.x1) return b;
    return this.buildings[0];
  }

  draw(grid: GlyphGrid, ctx: SceneCtx) {
    const { cols, rows, palette, features, dna, t } = ctx;
    const mScale = motionScale(dna);
    const baseline = Math.floor(rows * 0.8);
    const scrollSpeed = (2 + ctx.bpmHint * 2) * (0.15 + (dna.camera / 100) * 0.9) * mScale;
    const camOffset = t * scrollSpeed;

    grid.clear(' ', palette.dim);

    // Sky + stars, reactive to high-frequency energy.
    for (const s of this.stars) {
      const vx = (s.x - camOffset * 0.4) % VIRTUAL_WIDTH;
      const sx = Math.floor(((vx + VIRTUAL_WIDTH) % VIRTUAL_WIDTH) * (cols / VIRTUAL_WIDTH));
      const sy = Math.floor(s.y * baseline);
      const twinkle = 0.5 + 0.5 * Math.sin(t * 1.5 + s.phase + features.high * 6);
      if (twinkle > 0.35) {
        grid.set(sx, sy, twinkle > 0.8 ? '*' : '.', lerpColor(palette.dim, palette.bright, twinkle * features.high * 1.4 + 0.15));
      }
    }

    // Moon.
    const moonX = Math.floor(cols * 0.78);
    const moonY = Math.floor(rows * 0.14);
    grid.set(moonX, moonY, '\u25CE', palette.accentB);

    // Section-change light sweep across the skyline.
    const sweepX = ctx.sceneShiftPulse > 0.02 ? Math.floor((1 - ctx.sceneShiftPulse) * cols * 1.4 - cols * 0.2) : -999;

    for (let x = 0; x < cols; x++) {
      const vx = (x / cols) * VIRTUAL_WIDTH + camOffset;
      const b = this.buildingAt(Math.floor(vx));
      const localSeed = hashString(`${this.seed}-${b.flickerSeed}`);
      for (let row = 0; row < b.height; row++) {
        const y = baseline - row;
        if (y < 0) break;
        const isEdge = row === b.height - 1;
        let fg = palette.dim;
        let ch = '\u2591';
        if (!isEdge && x % 2 === (b.flickerSeed % 2) && row % 2 === 1) {
          const flick = 0.5 + 0.5 * Math.sin(t * (0.6 + features.mid * 3) + (localSeed % 100) + row * 1.3);
          const lit = flick > 0.55 - features.mid * 0.3;
          if (lit) {
            ch = '\u25A0';
            fg = lerpColor(palette.mid, palette.accentA, Math.min(1, flick));
          } else {
            ch = '\u2592';
            fg = palette.dim;
          }
        } else if (isEdge) {
          ch = '\u2580';
          fg = palette.mid;
        }
        if (Math.abs(x - sweepX) < 3 && ctx.sceneShiftPulse > 0.02) {
          fg = lerpColor(fg, palette.bright, ctx.sceneShiftPulse);
          ch = '\u2588';
        }
        grid.set(x, y, ch, fg);
      }
      if (features.onset && (Math.floor(vx) + Math.floor(t * 3)) % 37 === 0) {
        for (let row = 0; row < b.height; row++) {
          const y = baseline - row;
          grid.set(x, y, '\u2588', palette.bright);
        }
      }
    }

    // Ground line + bass-reactive reflection glints.
    for (let x = 0; x < cols; x++) {
      grid.set(x, baseline + 1, '\u2500', palette.dim);
      if (features.bass > 0.5 && (x + Math.floor(t * 20)) % 9 === 0) {
        grid.set(x, baseline + 2, '\u02DC', lerpColor(palette.dim, palette.accentA, features.bass));
      }
    }
  }
}
