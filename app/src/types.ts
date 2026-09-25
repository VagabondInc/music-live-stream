export type WorldId = 'NIGHT_TRANSIT' | 'GLASS_CITIES' | 'DATA_VOID';

export const WORLDS: { id: WorldId; label: string; blurb: string }[] = [
  { id: 'NIGHT_TRANSIT', label: 'Night Transit', blurb: 'Perspective tunnels, platform signage, glass & neon.' },
  { id: 'GLASS_CITIES', label: 'Glass Cities', blurb: 'Parallax skyline, lit windows, drifting atmosphere.' },
  { id: 'DATA_VOID', label: 'Data Void', blurb: 'Organic noise fields, graph nodes, density blooms.' },
];

export interface SectionMarker {
  id: string; // 'A' | 'B' | 'C' | "A'"
  label: string; // e.g. THE ARRIVAL
  startRatio: number; // 0..1 of track duration
  endRatio: number;
}

export type TrackSource = 'procedural' | 'file';

export interface TrackDef {
  id: string;
  title: string;
  artist: string;
  album: string;
  year: number;
  duration: number; // seconds
  bpm: number;
  timeSig: string;
  world: WorldId;
  rootMidi: number; // root note for procedural synth
  scale: number[]; // semitone offsets
  density: number; // 0..1 rhythmic density
  source: TrackSource;
  fileUrl?: string;
  sections: SectionMarker[];
  accent: string; // hex accent color for queue row icon
  icon: string; // glyph icon
  structureConfidence: 'authored' | 'estimated' | 'unavailable';
}

export type LocalPipelineState =
  | 'offline'
  | 'previewing'
  | 'preflighting'
  | 'connecting'
  | 'sending'
  | 'reconnecting'
  | 'stopping'
  | 'error';

export type DestinationVisibility =
  | 'unknown'
  | 'creatorReportedLive'
  | 'providerConfirmedLive'
  | 'providerReportedNotLive'
  | 'providerError';

export interface PreflightCheck {
  id: string;
  label: string;
  status: 'pending' | 'pass' | 'warn' | 'fail';
  detail: string;
}

export type PerformanceLevel = 'subtle' | 'expressive' | 'intense';
export type DetailLevel = 'minimal' | 'layered' | 'dense';
export type ColorMode = 'restrained' | 'vivid' | 'mono';

export interface DnaSettings {
  programName: string;
  performance: PerformanceLevel;
  detail: DetailLevel;
  color: ColorMode;
  glyphs: number; // 0-100 density
  motion: number; // 0-100
  glitch: number; // 0-100
  titles: number; // 0-100 (duration/prominence)
  camera: number; // 0-100 (parallax amount)
  strictAscii: boolean;
  photosensitivitySafe: boolean;
  reduceMotion: boolean;
}

export interface AudioFeatures {
  rms: number; // 0..1 smoothed amplitude
  bass: number; // 0..1
  mid: number; // 0..1
  high: number; // 0..1
  centroid: number; // 0..1 normalized spectral centroid
  flux: number; // 0..1 spectral flux (change)
  onset: boolean; // transient/beat detected this frame
  onsetStrength: number; // 0..1
}
