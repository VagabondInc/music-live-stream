import { GlyphGrid } from './grid';
import type { SceneCtx } from './sceneTypes';
import type { Scene } from './scene';
import { glitchAllowed } from './scene';
import { TransitScene } from './scenes/transit';
import { CityscapeScene } from './scenes/cityscape';
import { OrganismScene } from './scenes/organism';
import { getPalette } from './palette';
import type { AudioFeatures, DnaSettings, TrackDef, WorldId } from '../types';
import { hashString } from '../audio/noise';
import { sectionAt, sectionIndexAt, energyTier } from '../audio/synth';

const TRANSITION_KINDS = ['dissolve', 'wipe', 'reconstruct'] as const;
type TransitionKind = (typeof TRANSITION_KINDS)[number];

interface RenderInput {
  track: TrackDef | null;
  trackTime: number;
  features: AudioFeatures;
  dna: DnaSettings;
}

export interface FrameHealth {
  fps: number;
  cols: number;
  rows: number;
}

export class AsciiRenderer {
  private canvas: HTMLCanvasElement;
  private ctx2d: CanvasRenderingContext2D;
  private cellW = 9;
  private cellH = 16;
  private fontSize = 14;
  private grid: GlyphGrid;
  private prevGridSnapshot: { chars: string[]; fgs: string[] } | null = null;

  private scenes: Record<WorldId, Scene> = {
    NIGHT_TRANSIT: new TransitScene(),
    GLASS_CITIES: new CityscapeScene(),
    DATA_VOID: new OrganismScene(),
  };
  private activeWorld: WorldId | null = null;
  private currentTrackId: string | null = null;
  private lastSectionIndex = -1;
  private sceneShiftPulse = 0;

  private transition: { active: boolean; start: number; kind: TransitionKind; duration: number } = {
    active: false,
    start: 0,
    kind: 'dissolve',
    duration: 0.7,
  };
  private transitionCounter = 0;

  private startTime = performance.now() / 1000;
  private glitchBands: { y: number; life: number }[] = [];
  private frameCount = 0;
  private fpsAccumTime = 0;
  private fps = 0;

  constructor(canvas: HTMLCanvasElement) {
    this.canvas = canvas;
    const c2d = canvas.getContext('2d');
    if (!c2d) throw new Error('2D canvas context unavailable');
    this.ctx2d = c2d;
    this.grid = new GlyphGrid(80, 30);
    this.resize();
  }

  resize() {
    const parent = this.canvas.parentElement;
    if (!parent) return;
    const dpr = Math.min(2, window.devicePixelRatio || 1);
    const displayW = Math.max(200, parent.clientWidth);
    const displayH = Math.max(150, parent.clientHeight);
    this.canvas.width = Math.floor(displayW * dpr);
    this.canvas.height = Math.floor(displayH * dpr);
    this.canvas.style.width = `${displayW}px`;
    this.canvas.style.height = `${displayH}px`;
    this.ctx2d.setTransform(dpr, 0, 0, dpr, 0, 0);

    this.fontSize = displayW > 900 ? 14 : 11;
    this.cellW = this.fontSize * 0.62;
    this.cellH = this.fontSize * 1.32;
    const cols = Math.max(40, Math.floor(displayW / this.cellW));
    const rows = Math.max(18, Math.floor(displayH / this.cellH));
    this.grid.resize(cols, rows);
  }

  private ensureScene(track: TrackDef | null) {
    if (!track) return;
    const seed = hashString(track.id);
    if (track.id !== this.currentTrackId) {
      this.beginTransition();
      this.currentTrackId = track.id;
      this.lastSectionIndex = -1;
    }
    if (track.world !== this.activeWorld) {
      this.activeWorld = track.world;
      this.scenes[track.world].reset(seed);
    }
  }

  private beginTransition() {
    this.transition = {
      active: true,
      start: performance.now() / 1000,
      kind: TRANSITION_KINDS[this.transitionCounter % TRANSITION_KINDS.length],
      duration: 0.8,
    };
    this.transitionCounter++;
    this.prevGridSnapshot = { chars: [...this.grid.chars], fgs: [...this.grid.fgs] };
  }

  getFps() {
    return this.fps;
  }
  getGridSize() {
    return { cols: this.grid.cols, rows: this.grid.rows };
  }

  render(input: RenderInput) {
    const now = performance.now() / 1000;
    const t = now - this.startTime;
    this.ensureScene(input.track);

    if (input.track && this.activeWorld) {
      const secIdx = sectionIndexAt(input.track, input.trackTime);
      if (secIdx !== this.lastSectionIndex && this.lastSectionIndex !== -1) {
        this.sceneShiftPulse = 1;
      }
      this.lastSectionIndex = secIdx;
      this.sceneShiftPulse = Math.max(0, this.sceneShiftPulse - (1 / 45));

      const section = sectionAt(input.track, input.trackTime);
      const tier = energyTier(section.label);
      const sectionLen = (section.endRatio - section.startRatio) * input.track.duration;
      const sectionProgress = sectionLen > 0 ? (input.trackTime - section.startRatio * input.track.duration) / sectionLen : 0;

      const palette = getPalette(input.track.world, input.dna.color);
      const sceneCtx: SceneCtx = {
        cols: this.grid.cols,
        rows: this.grid.rows,
        t,
        trackTime: input.trackTime,
        duration: input.track.duration,
        features: input.features,
        dna: input.dna,
        palette,
        seed: hashString(input.track.id),
        sectionTier: tier,
        sectionProgress: Math.max(0, Math.min(1, sectionProgress)),
        sceneShiftPulse: this.sceneShiftPulse,
        strictAscii: input.dna.strictAscii,
        bpmHint: input.track.bpm / 120,
      };
      this.scenes[input.track.world].draw(this.grid, sceneCtx);
      this.applyEffects(sceneCtx, input.dna);
    } else {
      this.grid.clear(' ', '#1a222b');
      this.drawIdle(t);
    }

    this.composite();
    this.updateFps(now);
  }

  private drawIdle(t: number) {
    const msg = 'AWAITING PROGRAM SOURCE';
    const y = Math.floor(this.grid.rows / 2);
    const x0 = Math.floor((this.grid.cols - msg.length) / 2);
    for (let i = 0; i < msg.length; i++) {
      const flick = 0.5 + 0.5 * Math.sin(t * 2 + i * 0.3);
      this.grid.set(x0 + i, y, msg[i], `rgba(90,209,234,${0.3 + flick * 0.5})`);
    }
  }

  private applyEffects(sceneCtx: SceneCtx, dna: DnaSettings) {
    // Glitch bands: brief horizontal corruption on strong onsets.
    if (sceneCtx.features.onset && glitchAllowed(dna) && Math.random() < dna.glitch / 140) {
      this.glitchBands.push({ y: Math.floor(Math.random() * this.grid.rows), life: 3 + Math.floor(Math.random() * 3) });
    }
    this.glitchBands = this.glitchBands.filter((b) => b.life > 0);
    for (const band of this.glitchBands) {
      for (let x = 0; x < this.grid.cols; x++) {
        if (Math.random() < 0.4) {
          const chars = '#%&$XZ01/\\|';
          this.grid.set(x, band.y, chars[Math.floor(Math.random() * chars.length)], sceneCtx.palette.accentB);
        }
      }
      band.life--;
    }
  }

  private composite() {
    const { ctx2d, cellW, cellH, grid } = this;
    ctx2d.textBaseline = 'top';
    ctx2d.font = `${this.fontSize}px 'JetBrains Mono', ui-monospace, monospace`;

    ctx2d.fillStyle = '#05070a';
    ctx2d.fillRect(0, 0, this.canvas.width, this.canvas.height);

    const trans = this.transition;
    let mixT = 1;
    if (trans.active) {
      const nowAbs = performance.now() / 1000;
      const age = nowAbs - trans.start;
      mixT = Math.min(1, age / trans.duration);
      if (mixT >= 1) this.transition.active = false;
    }

    for (let y = 0; y < grid.rows; y++) {
      let x = 0;
      while (x < grid.cols) {
        const idx = grid.idx(x, y);
        let showPrev = false;
        if (trans.active && this.prevGridSnapshot) {
          showPrev = this.shouldShowPrev(trans.kind, x, y, mixT);
        }
        const bg = grid.bgs[idx];
        const fg = showPrev && this.prevGridSnapshot ? this.prevGridSnapshot.fgs[idx] : grid.fgs[idx];
        const ch = showPrev && this.prevGridSnapshot ? this.prevGridSnapshot.chars[idx] : grid.chars[idx];

        if (bg && !showPrev) {
          ctx2d.fillStyle = bg;
          ctx2d.fillRect(x * cellW, y * cellH, cellW + 0.5, cellH + 0.5);
        }

        // Batch a run of identical fg/bg-less cells for perf.
        let runLen = 1;
        if (!bg) {
          while (x + runLen < grid.cols) {
            const ni = grid.idx(x + runLen, y);
            const nShowPrev = trans.active && this.prevGridSnapshot ? this.shouldShowPrev(trans.kind, x + runLen, y, mixT) : false;
            const nFg = nShowPrev && this.prevGridSnapshot ? this.prevGridSnapshot.fgs[ni] : grid.fgs[ni];
            const nBg = grid.bgs[ni];
            if (nBg || nFg !== fg || nShowPrev !== showPrev) break;
            runLen++;
          }
        }
        let str = '';
        for (let k = 0; k < runLen; k++) {
          const ci = grid.idx(x + k, y);
          const cShowPrev = trans.active && this.prevGridSnapshot ? this.shouldShowPrev(trans.kind, x + k, y, mixT) : false;
          str += cShowPrev && this.prevGridSnapshot ? this.prevGridSnapshot.chars[ci] : grid.chars[ci];
        }
        if (str.trim().length > 0) {
          ctx2d.fillStyle = fg;
          ctx2d.fillText(str, x * cellW, y * cellH);
        } else if (ch !== ' ' && bg) {
          ctx2d.fillStyle = fg;
          ctx2d.fillText(ch, x * cellW, y * cellH);
        }
        x += runLen;
      }
    }
  }

  private shouldShowPrev(kind: TransitionKind, x: number, y: number, mixT: number): boolean {
    if (kind === 'wipe') {
      const frac = x / this.grid.cols;
      return frac > mixT;
    }
    if (kind === 'reconstruct') {
      // reveal in scattered blocks based on a cheap hash, biased by mixT
      const h = ((x * 928371 + y * 68917) % 997) / 997;
      return h > mixT;
    }
    // dissolve: probabilistic per-cell reveal, stable across the transition via hash
    const h = ((x * 3 + y * 928371 + 17) % 1000) / 1000;
    return h > mixT;
  }

  private updateFps(now: number) {
    this.frameCount++;
    if (now - this.fpsAccumTime > 0.5) {
      this.fps = Math.round(this.frameCount / (now - this.fpsAccumTime));
      this.frameCount = 0;
      this.fpsAccumTime = now;
    }
  }
}
