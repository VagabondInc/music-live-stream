import { GlyphGrid } from '../grid';
import type { SceneCtx } from '../sceneTypes';
import type { Scene } from '../scene';
import { motionScale } from '../scene';
import { lerpColor, densityChar } from '../palette';
import { mulberry32 } from '../../audio/noise';

interface Shock {
  start: number;
  strength: number;
}
interface Mote {
  angle: number;
  dist: number;
  speed: number;
}

const STRUT_ANGLES = [0, Math.PI / 4, Math.PI / 2, (3 * Math.PI) / 4, Math.PI, (-3 * Math.PI) / 4, -Math.PI / 2, -Math.PI / 4];

export class TransitScene implements Scene {
  private shocks: Shock[] = [];
  private motes: Mote[] = [];
  private lastOnsetHandled = -1;
  private rng = mulberry32(1);

  reset(seed: number) {
    this.rng = mulberry32(seed);
    this.shocks = [];
    this.motes = [];
    for (let i = 0; i < 46; i++) {
      this.motes.push({ angle: this.rng() * Math.PI * 2, dist: this.rng() * 24 + 2, speed: 4 + this.rng() * 5 });
    }
  }

  draw(grid: GlyphGrid, ctx: SceneCtx) {
    const { cols, rows, palette, features, dna, t } = ctx;
    const mScale = motionScale(dna);
    const aspect = 0.52; // cell width/height correction for a circular tunnel
    const camX = Math.sin(t * 0.05) * (dna.camera / 100) * 5;
    const zoomKick = 1 + ctx.sceneShiftPulse * 0.18;
    const cx = cols / 2 + camX;
    const cy = rows * 0.46;

    if (features.onset && ctx.sceneShiftPulse < 0.85) {
      const now = t;
      if (now - this.lastOnsetHandled > 0.08) {
        this.shocks.push({ start: now, strength: 0.6 + features.onsetStrength * 0.6 });
        this.lastOnsetHandled = now;
        if (this.shocks.length > 6) this.shocks.shift();
      }
    }
    if (ctx.sceneShiftPulse > 0.9 && this.shocks.every((s) => t - s.start > 0.3)) {
      this.shocks.push({ start: t, strength: 1.4 });
    }

    const speed = (0.55 + features.bass * 1.3) * mScale;
    const ringSpacing = ctx.dna.detail === 'dense' ? 1.6 : ctx.dna.detail === 'minimal' ? 2.6 : 2.1;

    for (let y = 0; y < rows; y++) {
      for (let x = 0; x < cols; x++) {
        const dx = (x - cx) * aspect;
        const dy = (y - cy) / zoomKick;
        const dist = Math.sqrt(dx * dx + dy * dy) / zoomKick;
        const angle = Math.atan2(dy, dx);

        let val = 0.5 + 0.5 * Math.sin(dist * ringSpacing - t * speed);
        val *= Math.max(0, 1 - dist / (Math.max(cols, rows) * 0.62)); // vignette falloff

        // Struts: bright rays at fixed angles simulating tunnel structure.
        let strutChar: string | null = null;
        for (const sa of STRUT_ANGLES) {
          let d = Math.abs(angle - sa);
          if (d > Math.PI) d = 2 * Math.PI - d;
          if (d < 0.05 + 0.02 / (dist * 0.05 + 0.2)) {
            strutChar = Math.abs(Math.sin(sa)) > 0.8 ? '|' : Math.abs(Math.cos(sa)) > 0.8 ? '-' : sa > 0 === sa < Math.PI ? '\\' : '/';
            val = Math.max(val, 0.55);
            break;
          }
        }

        // Shockwaves ripple outward from onsets / section changes.
        for (const s of this.shocks) {
          const age = t - s.start;
          const radius = age * 16;
          const width = 2.2;
          const d = Math.abs(dist - radius);
          if (d < width) {
            const amt = (1 - d / width) * s.strength * Math.max(0, 1 - age / 1.4);
            val = Math.min(1.4, val + amt);
          }
        }

        const ch = strutChar ?? densityChar(Math.min(1, val), ctx.strictAscii);
        const colorT = Math.min(1, val * 0.8 + features.bass * 0.2);
        const color = lerpColor(palette.dim, colorT > 0.6 ? palette.accentA : palette.mid, Math.min(1, colorT));
        const finalColor = val > 0.95 ? lerpColor(color, palette.bright, 0.6) : color;
        grid.set(x, y, val < 0.06 ? ' ' : ch, finalColor);
      }
    }

    // Dust motes approaching the viewer.
    for (const m of this.motes) {
      m.dist -= (0.14 + features.mid * 0.5) * m.speed * mScale * 0.06;
      if (m.dist <= 0.6) {
        m.dist = 22 + this.rng() * 8;
        m.angle = this.rng() * Math.PI * 2;
      }
      const px = Math.round(cx + (Math.cos(m.angle) * m.dist) / aspect);
      const py = Math.round(cy + Math.sin(m.angle) * m.dist);
      const close = 1 - m.dist / 24;
      if (close > 0.05) {
        grid.set(px, py, close > 0.7 ? '*' : '.', lerpColor(palette.mid, palette.bright, close));
      }
    }

    // Platform signage block.
    const label = ctx.dna.programName.replace(/_/g, ' ');
    drawSignage(grid, Math.round(cols * 0.12), Math.round(rows * 0.22), label.slice(0, 14), palette.accentB, palette.bg);
    drawSignage(grid, Math.round(cols * 0.74), Math.round(rows * 0.28), 'EXIT ->', palette.accentA, palette.bg);
  }
}

function drawSignage(grid: GlyphGrid, x0: number, y0: number, text: string, fg: string, bg: string) {
  const w = text.length + 2;
  for (let x = 0; x < w; x++) {
    grid.set(x0 + x, y0, x === 0 || x === w - 1 ? '\u2502' : '\u2500', fg, bg);
    grid.set(x0 + x, y0 + 2, x === 0 || x === w - 1 ? '\u2502' : '\u2500', fg, bg);
  }
  grid.set(x0, y0 + 1, '\u2502', fg, bg);
  grid.set(x0 + w - 1, y0 + 1, '\u2502', fg, bg);
  for (let i = 0; i < text.length; i++) {
    grid.set(x0 + 1 + i, y0 + 1, text[i].toUpperCase(), fg, bg);
  }
}
