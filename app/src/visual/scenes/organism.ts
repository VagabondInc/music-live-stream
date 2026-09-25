import { GlyphGrid } from '../grid';
import type { SceneCtx } from '../sceneTypes';
import type { Scene } from '../scene';
import { motionScale } from '../scene';
import { lerpColor, densityChar } from '../palette';
import { fbm2D, mulberry32 } from '../../audio/noise';

interface Node {
  x: number; // normalized 0..1
  y: number;
  vx: number;
  vy: number;
  phase: number;
}

export class OrganismScene implements Scene {
  private nodes: Node[] = [];
  private seed = 1;
  private lastT = 0;

  reset(seed: number) {
    this.seed = seed;
    const rng = mulberry32(seed + 77);
    this.nodes = [];
    for (let i = 0; i < 15; i++) {
      this.nodes.push({
        x: rng(),
        y: rng(),
        vx: (rng() - 0.5) * 0.04,
        vy: (rng() - 0.5) * 0.04,
        phase: rng() * Math.PI * 2,
      });
    }
    this.lastT = 0;
  }

  draw(grid: GlyphGrid, ctx: SceneCtx) {
    const { cols, rows, palette, features, dna, t } = ctx;
    const mScale = motionScale(dna);
    const dt = Math.max(0, Math.min(0.1, t - this.lastT || 0.016));
    this.lastT = t;

    const bloom = ctx.sceneShiftPulse;
    const amp = 1 + features.bass * 0.9 + bloom * 0.8;
    const drift = 0.06 * mScale;
    const freq = 0.09 + features.centroid * 0.08;

    for (let y = 0; y < rows; y++) {
      for (let x = 0; x < cols; x++) {
        const n = fbm2D(x * freq, y * freq * 1.7, this.seed, 3) * amp + t * drift;
        const v = Math.abs(Math.sin(n * Math.PI));
        const boosted = Math.pow(v, 1.4 - features.mid * 0.6);
        const ch = densityChar(Math.min(1, boosted), ctx.strictAscii);
        const colorT = Math.min(1, boosted * 0.85 + bloom * 0.3);
        const color = lerpColor(palette.dim, colorT > 0.55 ? palette.accentA : palette.mid, colorT);
        grid.set(x, y, boosted < 0.08 ? ' ' : ch, color);
      }
    }

    // Update + draw graph nodes (persistent "data structure" entities).
    for (const node of this.nodes) {
      node.x += node.vx * dt * (1 + features.mid) * mScale;
      node.y += node.vy * dt * (1 + features.mid) * mScale;
      if (node.x < 0 || node.x > 1) node.vx *= -1;
      if (node.y < 0 || node.y > 1) node.vy *= -1;
      node.x = Math.max(0, Math.min(1, node.x));
      node.y = Math.max(0, Math.min(1, node.y));
    }

    for (let i = 0; i < this.nodes.length; i++) {
      for (let j = i + 1; j < this.nodes.length; j++) {
        const a = this.nodes[i];
        const b = this.nodes[j];
        const dx = (a.x - b.x) * cols;
        const dy = (a.y - b.y) * rows;
        const dist = Math.sqrt(dx * dx + dy * dy);
        if (dist < 16) {
          const steps = Math.ceil(dist);
          for (let s = 0; s <= steps; s += 1) {
            const px = Math.round((a.x + (b.x - a.x) * (s / steps)) * cols);
            const py = Math.round((a.y + (b.y - a.y) * (s / steps)) * rows);
            grid.set(px, py, '\u00B7', lerpColor(palette.dim, palette.mid, 1 - dist / 16));
          }
        }
      }
    }
    for (const node of this.nodes) {
      const pulse = 0.5 + 0.5 * Math.sin(t * 2 + node.phase) + (features.onset ? features.onsetStrength : 0);
      const px = Math.round(node.x * cols);
      const py = Math.round(node.y * rows);
      const ch = pulse > 1 ? '\u2726' : pulse > 0.6 ? '\u25C8' : '\u25C7';
      grid.set(px, py, ch, lerpColor(palette.accentA, palette.bright, Math.min(1, Math.max(0, pulse - 0.4))));
    }
  }
}
