import type { AudioFeatures, TrackDef, SectionMarker } from '../types';
import { ProceduralComposer } from './synth';

type EndedHandler = () => void;
type TimeHandler = (t: number) => void;

/**
 * Owns the single program audio path: one AudioContext, one analyser tap,
 * and one active source (procedural synth graph OR an imported media
 * element). Playback and analysis always observe the same signal, per the
 * Product Mission's requirement to not analyze a different signal than the
 * one that would be broadcast.
 */
export class AudioEngine {
  ctx: AudioContext;
  private masterGain: GainNode;
  private analyser: AnalyserNode;
  private freqData: Uint8Array;
  private timeData: Uint8Array;

  private composer: ProceduralComposer | null = null;
  private mediaEl: HTMLAudioElement | null = null;
  private mediaSource: MediaElementAudioSourceNode | null = null;

  private track: TrackDef | null = null;
  private playing = false;
  private loop = false;

  private prevSpectralSum = 0;
  private fluxEnv = 0;
  private onsetCooldown = 0;
  private smoothed: AudioFeatures = { rms: 0, bass: 0, mid: 0, high: 0, centroid: 0, flux: 0, onset: false, onsetStrength: 0 };

  private endedHandlers: EndedHandler[] = [];
  private timeHandlers: TimeHandler[] = [];

  constructor() {
    this.ctx = new (window.AudioContext || (window as any).webkitAudioContext)();
    this.masterGain = this.ctx.createGain();
    this.analyser = this.ctx.createAnalyser();
    this.analyser.fftSize = 1024;
    this.analyser.smoothingTimeConstant = 0.0; // we smooth ourselves for tunable response
    this.masterGain.connect(this.analyser);
    this.analyser.connect(this.ctx.destination);
    this.freqData = new Uint8Array(this.analyser.frequencyBinCount);
    this.timeData = new Uint8Array(this.analyser.fftSize);
  }

  async resume() {
    if (this.ctx.state === 'suspended') await this.ctx.resume();
  }

  onEnded(fn: EndedHandler) {
    this.endedHandlers.push(fn);
  }
  onTime(fn: TimeHandler) {
    this.timeHandlers.push(fn);
  }

  setMasterVolume(v: number) {
    this.masterGain.gain.value = v;
  }

  get currentTrack() {
    return this.track;
  }
  get isPlaying() {
    return this.playing;
  }
  setLoop(v: boolean) {
    this.loop = v;
  }

  private teardownSource() {
    if (this.composer) {
      this.composer.dispose();
      this.composer = null;
    }
    if (this.mediaEl) {
      this.mediaEl.pause();
      this.mediaEl.src = '';
      this.mediaEl = null;
    }
    if (this.mediaSource) {
      try {
        this.mediaSource.disconnect();
      } catch {
        /* noop */
      }
      this.mediaSource = null;
    }
  }

  async loadTrack(track: TrackDef, autoplay: boolean, startAt = 0) {
    await this.resume();
    this.teardownSource();
    this.track = track;
    this.playing = false;

    if (track.source === 'procedural') {
      this.composer = new ProceduralComposer(this.ctx, this.masterGain, track);
      if (autoplay) this.play(startAt);
    } else if (track.fileUrl) {
      const el = new Audio();
      el.crossOrigin = 'anonymous';
      el.src = track.fileUrl;
      el.preload = 'auto';
      el.loop = false;
      el.addEventListener('ended', () => this.handleEnded());
      this.mediaEl = el;
      this.mediaSource = this.ctx.createMediaElementSource(el);
      this.mediaSource.connect(this.masterGain);
      if (startAt > 0) el.currentTime = startAt;
      if (autoplay) this.play(startAt);
    }
  }

  play(atOffset?: number) {
    if (!this.track) return;
    this.resume();
    if (this.composer) {
      this.composer.play(atOffset ?? this.composer.getTrackTime());
    } else if (this.mediaEl) {
      if (atOffset != null) this.mediaEl.currentTime = atOffset;
      void this.mediaEl.play();
    }
    this.playing = true;
  }

  pause() {
    if (this.composer) this.composer.pause();
    if (this.mediaEl) this.mediaEl.pause();
    this.playing = false;
  }

  stop() {
    if (this.composer) this.composer.seek(0);
    if (this.mediaEl) this.mediaEl.currentTime = 0;
    this.pause();
  }

  seek(t: number) {
    if (!this.track) return;
    const clamped = Math.max(0, Math.min(this.track.duration, t));
    if (this.composer) this.composer.seek(clamped);
    if (this.mediaEl) this.mediaEl.currentTime = clamped;
  }

  getTrackTime(): number {
    if (this.composer) return this.composer.getTrackTime();
    if (this.mediaEl) return this.mediaEl.currentTime;
    return 0;
  }

  private handleEnded() {
    this.playing = false;
    this.endedHandlers.forEach((fn) => fn());
  }

  /** Call once per animation frame from the render loop. */
  tick() {
    if (!this.track) return;
    const t = this.getTrackTime();
    this.timeHandlers.forEach((fn) => fn(t));
    if (this.playing && t >= this.track.duration - 0.03) {
      if (this.loop) {
        this.seek(0);
        this.play(0);
      } else {
        this.handleEnded();
      }
    }
  }

  /** Real-time spectral feature extraction from the single analyser tap. */
  getFeatures(): AudioFeatures {
    this.analyser.getByteFrequencyData(this.freqData as Uint8Array<ArrayBuffer>);
    this.analyser.getByteTimeDomainData(this.timeData as Uint8Array<ArrayBuffer>);

    // RMS from time-domain samples.
    let sumSq = 0;
    for (let i = 0; i < this.timeData.length; i++) {
      const v = (this.timeData[i] - 128) / 128;
      sumSq += v * v;
    }
    const rms = Math.sqrt(sumSq / this.timeData.length);

    const n = this.freqData.length;
    const bassEnd = Math.floor(n * 0.08);
    const midEnd = Math.floor(n * 0.35);
    let bassSum = 0,
      midSum = 0,
      highSum = 0,
      total = 0,
      weighted = 0;
    for (let i = 0; i < n; i++) {
      const v = this.freqData[i] / 255;
      total += v;
      weighted += v * i;
      if (i < bassEnd) bassSum += v;
      else if (i < midEnd) midSum += v;
      else highSum += v;
    }
    const bass = bassSum / Math.max(1, bassEnd);
    const mid = midSum / Math.max(1, midEnd - bassEnd);
    const high = highSum / Math.max(1, n - midEnd);
    const centroid = total > 0 ? weighted / total / n : 0;

    // Spectral flux (positive-only) drives onset/transient detection.
    let flux = 0;
    let specSum = 0;
    for (let i = 0; i < n; i++) specSum += this.freqData[i];
    const rawFlux = Math.max(0, specSum - this.prevSpectralSum) / (n * 255);
    this.prevSpectralSum = specSum;
    this.fluxEnv = this.fluxEnv * 0.8 + rawFlux * 0.2;
    flux = Math.min(1, rawFlux * 6);

    this.onsetCooldown = Math.max(0, this.onsetCooldown - 1);
    let onset = false;
    if (rawFlux > this.fluxEnv * 1.6 + 0.02 && this.onsetCooldown === 0) {
      onset = true;
      this.onsetCooldown = 4;
    }

    const smooth = (prev: number, next: number, a = 0.35) => prev + (next - prev) * a;
    this.smoothed = {
      rms: smooth(this.smoothed.rms, rms),
      bass: smooth(this.smoothed.bass, bass),
      mid: smooth(this.smoothed.mid, mid),
      high: smooth(this.smoothed.high, high),
      centroid: smooth(this.smoothed.centroid, centroid),
      flux: smooth(this.smoothed.flux, flux, 0.5),
      onset,
      onsetStrength: onset ? 1 : Math.max(0, this.smoothed.onsetStrength - 0.08),
    };
    return this.smoothed;
  }
}

/**
 * Deterministic, non-ML structure estimate for imported files: windowed RMS
 * envelope from a fully-decoded buffer, bucketed into contiguous
 * intro/build/peak/breakdown/outro regions. Explicitly labeled "estimated"
 * in the UI — the Product Mission requires distinguishing measured vs.
 * inferred characteristics.
 */
export function estimateStructure(buffer: AudioBuffer): SectionMarker[] {
  const ch = buffer.getChannelData(0);
  const windowSec = 1.5;
  const windowSize = Math.max(1024, Math.floor(buffer.sampleRate * windowSec));
  const windows: number[] = [];
  for (let i = 0; i < ch.length; i += windowSize) {
    let sum = 0;
    const end = Math.min(ch.length, i + windowSize);
    for (let j = i; j < end; j += 4) {
      const v = ch[j];
      sum += v * v;
    }
    windows.push(Math.sqrt(sum / ((end - i) / 4)));
  }
  const max = Math.max(...windows, 1e-6);
  const norm = windows.map((v) => v / max);
  const sorted = [...norm].sort((a, b) => a - b);
  const pct = (p: number) => sorted[Math.min(sorted.length - 1, Math.floor(p * sorted.length))];
  const lowT = pct(0.35);
  const highT = pct(0.75);

  const tierOf = (v: number) => (v >= highT ? 2 : v <= lowT ? 0 : 1);
  const tiers = norm.map(tierOf);

  // Merge into runs.
  const runs: { tier: number; start: number; end: number }[] = [];
  let cur = { tier: tiers[0] ?? 1, start: 0, end: 1 };
  for (let i = 1; i < tiers.length; i++) {
    if (tiers[i] === cur.tier) cur.end = i + 1;
    else {
      runs.push(cur);
      cur = { tier: tiers[i], start: i, end: i + 1 };
    }
  }
  runs.push(cur);

  // Merge adjacent runs of the same tier, and fold tiny runs into their
  // neighbor, so the estimated structure reads as a handful of coherent
  // sections rather than noisy micro-segments.
  const minLen = Math.max(1, Math.floor(tiers.length * 0.05));
  const merged: typeof runs = [];
  for (const r of runs) {
    const prev = merged[merged.length - 1];
    if (prev && (r.end - r.start < minLen || prev.tier === r.tier)) {
      prev.end = r.end;
    } else {
      merged.push({ ...r });
    }
  }

  const totalWindows = tiers.length || 1;
  const labelFor = (tier: number, i: number, count: number) => {
    if (i === 0) return 'INTRO';
    if (i === count - 1) return 'OUTRO';
    return tier === 2 ? 'PEAK' : tier === 0 ? 'BREAKDOWN' : 'BUILD';
  };
  const idFor = (tier: number) => (tier === 2 ? 'B' : tier === 0 ? 'C' : 'A');

  return merged.map((r, i) => ({
    id: idFor(r.tier),
    label: labelFor(r.tier, i, merged.length),
    startRatio: r.start / totalWindows,
    endRatio: r.end / totalWindows,
  }));
}
