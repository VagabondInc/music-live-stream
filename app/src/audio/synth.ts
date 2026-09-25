import type { TrackDef, SectionMarker } from '../types';
import { hashString, mulberry32 } from './noise';

export function midiToFreq(midi: number): number {
  return 440 * Math.pow(2, (midi - 69) / 12);
}

export function sectionAt(track: TrackDef, trackTime: number): SectionMarker {
  const ratio = Math.min(0.999999, Math.max(0, trackTime / track.duration));
  for (const s of track.sections) {
    if (ratio >= s.startRatio && ratio < s.endRatio) return s;
  }
  return track.sections[track.sections.length - 1];
}

export function sectionIndexAt(track: TrackDef, trackTime: number): number {
  const s = sectionAt(track, trackTime);
  return track.sections.indexOf(s);
}

// Rough narrative "energy tier" per section label, used by both the
// procedural composer (arrangement density) and the visual engine
// (pacing / stillness vs. escalation). Deterministic and label-driven —
// not an ML classifier — per the Product Mission's guidance to prefer
// deterministic signal processing where it suffices.
export function energyTier(label: string): number {
  const l = label.toUpperCase();
  if (l.includes('CHORUS') || l === 'B' || l === "B'" || l.includes('PULSE') || l.includes('OVERDRIVE'))
    return 1;
  if (l.includes('BREAKDOWN') || l === 'C' || l.includes('SPACE') || l.includes('BLACKOUT') || l.includes('DROPOUT'))
    return 0.25;
  if (l.includes('OUT') || l.includes('FADE') || l.includes('RUNOFF') || l.includes('STILLNESS')) return 0.35;
  if (l.includes('INTRO')) return 0.3;
  return 0.6; // verse / A default
}

function stepRand(seed: number, a: number, b: number): number {
  const s = (seed ^ Math.imul(a + 1, 374761393) ^ Math.imul(b + 1, 668265263)) >>> 0;
  return mulberry32(s)();
}

function whiteNoiseBuffer(ctx: BaseAudioContext): AudioBuffer {
  const buf = ctx.createBuffer(1, ctx.sampleRate, ctx.sampleRate);
  const data = buf.getChannelData(0);
  for (let i = 0; i < data.length; i++) data[i] = Math.random() * 2 - 1;
  return buf;
}

/**
 * ProceduralComposer generates a fully synthetic, license-free backing
 * track in real time using Web Audio oscillators/noise. Pattern decisions
 * are pure functions of (trackSeed, bar, step) so seeking never requires
 * replaying history — the audio at any offset is deterministic.
 */
export class ProceduralComposer {
  private ctx: AudioContext;
  private out: AudioNode;
  private track: TrackDef;
  private seed: number;
  private stepDur: number;
  private noiseBuf: AudioBuffer;
  private timer: number | null = null;
  private epochCtxTime = 0;
  private epochTrackTime = 0;
  private nextStepIndex = 0;
  private playing = false;
  private scaleFreqs: number[];

  constructor(ctx: AudioContext, out: AudioNode, track: TrackDef) {
    this.ctx = ctx;
    this.out = out;
    this.track = track;
    this.seed = hashString(track.id);
    this.stepDur = 60 / track.bpm / 4; // 16th note
    this.noiseBuf = whiteNoiseBuffer(ctx);
    const degrees = track.scale;
    this.scaleFreqs = [];
    for (let oct = 0; oct < 3; oct++) {
      for (const d of degrees) this.scaleFreqs.push(midiToFreq(track.rootMidi + d + oct * 12));
    }
  }

  getTrackTime(): number {
    if (!this.playing) return this.epochTrackTime;
    const tt = this.epochTrackTime + (this.ctx.currentTime - this.epochCtxTime);
    return Math.min(tt, this.track.duration);
  }

  private reepoch(offset: number) {
    this.epochCtxTime = this.ctx.currentTime + 0.05;
    this.epochTrackTime = Math.max(0, offset);
    this.nextStepIndex = Math.ceil(this.epochTrackTime / this.stepDur);
  }

  play(offsetSeconds: number) {
    this.reepoch(offsetSeconds);
    this.playing = true;
    if (this.timer == null) {
      this.timer = window.setInterval(() => this.tick(), 25);
    }
  }

  pause() {
    this.epochTrackTime = this.getTrackTime();
    this.playing = false;
  }

  seek(offsetSeconds: number) {
    const wasPlaying = this.playing;
    this.reepoch(offsetSeconds);
    this.playing = wasPlaying;
  }

  stop() {
    this.playing = false;
    if (this.timer != null) {
      window.clearInterval(this.timer);
      this.timer = null;
    }
  }

  dispose() {
    this.stop();
  }

  private ctxTimeForTrackTime(tt: number): number {
    return this.epochCtxTime + (tt - this.epochTrackTime);
  }

  private tick() {
    if (!this.playing) return;
    const trackTime = this.getTrackTime();
    if (trackTime >= this.track.duration) return; // let AudioEngine handle end-of-track
    const lookahead = 0.22;
    let guard = 0;
    while (this.nextStepIndex * this.stepDur < trackTime + lookahead && guard < 64) {
      this.scheduleStep(this.nextStepIndex);
      this.nextStepIndex++;
      guard++;
    }
  }

  private scheduleStep(stepIndex: number) {
    const stepTime = stepIndex * this.stepDur;
    if (stepTime >= this.track.duration) return;
    const when = this.ctxTimeForTrackTime(stepTime);
    if (when < this.ctx.currentTime - 0.01) return; // don't schedule in the past
    const barLen = 16;
    const barIndex = Math.floor(stepIndex / barLen);
    const stepInBar = stepIndex % barLen;
    const phrase = Math.floor(barIndex / 4);
    const section = sectionAt(this.track, stepTime);
    const tier = energyTier(section.label);
    const density = this.track.density;

    // Kick: four-on-the-floor once tier is moderate, extra hits at high tier.
    if (tier > 0.4 && stepInBar % 4 === 0) this.kick(when, 0.9);
    else if (tier > 0.8 && stepRand(this.seed, phrase, stepInBar + 200) < 0.22) this.kick(when, 0.6);

    // Hats: density-scaled probability, favors off-beats.
    const hatBias = stepInBar % 2 === 1 ? 0.55 : 0.2;
    if (stepRand(this.seed, phrase, stepInBar + 400) < density * (0.25 + 0.75 * tier) * hatBias + 0.03) {
      this.hat(when, 0.18 + 0.5 * tier);
    }

    // Bass: half-note root/fifth motion, changes character every 4 bars.
    if (stepInBar === 0 || stepInBar === 8) {
      const degIdx = Math.floor(stepRand(this.seed, phrase, 900) * 3); // root, 3rd-ish, 5th-ish region
      const freq = this.scaleFreqs[degIdx % this.scaleFreqs.length] / 2;
      this.bass(when, freq, this.stepDur * (stepInBar === 0 ? 7.5 : 7.5), 0.5 + 0.3 * tier);
    }

    // Arp / lead: only active with enough energy or density; melodic motion
    // through the scale keyed off step position + phrase for slow evolution.
    const arpProb = tier > 0.3 ? density * (0.2 + 0.6 * tier) : density * 0.08;
    if (stepRand(this.seed, phrase, stepInBar + 700) < arpProb) {
      const idx = (stepInBar * 3 + phrase * 5 + Math.floor(stepRand(this.seed, phrase, stepInBar + 1000) * 4)) %
        this.scaleFreqs.length;
      const freq = this.scaleFreqs[idx + 7 < this.scaleFreqs.length ? idx + 7 : idx];
      this.pluck(when, freq, this.stepDur * 3.2, 0.16 + 0.35 * tier);
    }

    // Section-change riser cue: first step of a new section gets a short
    // upward sweep, giving the visual "section change" flash a matching
    // audible cue (mirrors "arrival of a chorus" vs. a bare transient).
    if (stepTime - section.startRatio * this.track.duration < this.stepDur * 0.6 && stepInBar === 0) {
      this.riser(when, tier);
    }
  }

  private env(gainNode: GainNode, when: number, attack: number, decay: number, peak: number) {
    const g = gainNode.gain;
    g.cancelScheduledValues(when);
    g.setValueAtTime(0.0001, when);
    g.linearRampToValueAtTime(peak, when + attack);
    g.exponentialRampToValueAtTime(0.0001, when + attack + decay);
  }

  private kick(when: number, vel: number) {
    const osc = this.ctx.createOscillator();
    const gain = this.ctx.createGain();
    osc.type = 'sine';
    osc.frequency.setValueAtTime(150, when);
    osc.frequency.exponentialRampToValueAtTime(42, when + 0.14);
    gain.gain.setValueAtTime(0.0001, when);
    gain.gain.linearRampToValueAtTime(vel, when + 0.005);
    gain.gain.exponentialRampToValueAtTime(0.0001, when + 0.26);
    osc.connect(gain).connect(this.out);
    osc.start(when);
    osc.stop(when + 0.3);
  }

  private hat(when: number, vel: number) {
    const src = this.ctx.createBufferSource();
    src.buffer = this.noiseBuf;
    const hp = this.ctx.createBiquadFilter();
    hp.type = 'highpass';
    hp.frequency.value = 7000;
    const gain = this.ctx.createGain();
    gain.gain.setValueAtTime(0.0001, when);
    gain.gain.linearRampToValueAtTime(vel * 0.35, when + 0.002);
    gain.gain.exponentialRampToValueAtTime(0.0001, when + 0.05);
    src.connect(hp).connect(gain).connect(this.out);
    src.start(when);
    src.stop(when + 0.06);
  }

  private bass(when: number, freq: number, dur: number, vel: number) {
    const osc = this.ctx.createOscillator();
    const lp = this.ctx.createBiquadFilter();
    lp.type = 'lowpass';
    lp.frequency.value = 420;
    const gain = this.ctx.createGain();
    osc.type = 'triangle';
    osc.frequency.setValueAtTime(freq, when);
    this.env(gain, when, 0.02, dur, vel * 0.5);
    osc.connect(lp).connect(gain).connect(this.out);
    osc.start(when);
    osc.stop(when + dur + 0.05);
  }

  private pluck(when: number, freq: number, dur: number, vel: number) {
    const osc = this.ctx.createOscillator();
    const bp = this.ctx.createBiquadFilter();
    bp.type = 'bandpass';
    bp.frequency.value = freq * 2;
    bp.Q.value = 1.2;
    const gain = this.ctx.createGain();
    osc.type = 'sawtooth';
    osc.frequency.setValueAtTime(freq, when);
    this.env(gain, when, 0.005, dur, vel * 0.35);
    osc.connect(bp).connect(gain).connect(this.out);
    osc.start(when);
    osc.stop(when + dur + 0.05);
  }

  private riser(when: number, tier: number) {
    const src = this.ctx.createBufferSource();
    src.buffer = this.noiseBuf;
    src.loop = true;
    const bp = this.ctx.createBiquadFilter();
    bp.type = 'bandpass';
    bp.Q.value = 0.8;
    bp.frequency.setValueAtTime(400, when);
    bp.frequency.linearRampToValueAtTime(3200, when + 0.9);
    const gain = this.ctx.createGain();
    gain.gain.setValueAtTime(0.0001, when);
    gain.gain.linearRampToValueAtTime(0.05 + tier * 0.05, when + 0.85);
    gain.gain.exponentialRampToValueAtTime(0.0001, when + 1.0);
    src.connect(bp).connect(gain).connect(this.out);
    src.start(when);
    src.stop(when + 1.05);
  }
}
