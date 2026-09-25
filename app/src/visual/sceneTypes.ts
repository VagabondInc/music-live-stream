import type { AudioFeatures, DnaSettings } from '../types';
import type { WorldPalette } from './palette';

export interface SceneCtx {
  cols: number;
  rows: number;
  t: number; // continuous seconds, monotonic, used for ambient animation
  trackTime: number; // seconds into current track
  duration: number;
  features: AudioFeatures;
  dna: DnaSettings;
  palette: WorldPalette;
  seed: number;
  sectionTier: number; // 0..1 narrative energy
  sectionProgress: number; // 0..1 progress through current section
  sceneShiftPulse: number; // 0..1, decays after a section change (a "beat" for the camera/composition)
  strictAscii: boolean;
  bpmHint: number; // bpm/120, 1 when unknown
}
