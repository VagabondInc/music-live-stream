import type { SectionMarker, TrackDef, WorldId } from '../types';

// Demo playlist. Audio is 100% procedurally synthesized in-browser at
// playback time (see synth.ts) — no licensed or third-party recordings are
// bundled, matching the Product Mission's requirement that first-run demo
// content carry no rights ambiguity. Titles/artist are fictional placeholder
// program content used to mirror the GUI mockup layout.

const MAJOR = [0, 2, 4, 5, 7, 9, 11];
const MINOR = [0, 2, 3, 5, 7, 8, 10];
const DORIAN = [0, 2, 3, 5, 7, 9, 10];
const PENT_MINOR = [0, 3, 5, 7, 10];

function buildSections(labels: [string, string][]): SectionMarker[] {
  // labels: tuples of [id, label]; proportions follow a conventional pop
  // energy arc so the "Visual Score" has meaningful, non-random structure.
  const ratios =
    labels.length === 5
      ? [0.08, 0.24, 0.2, 0.16, 0.32]
      : labels.length === 6
      ? [0.07, 0.19, 0.18, 0.14, 0.18, 0.24]
      : labels.map(() => 1 / labels.length);
  let acc = 0;
  return labels.map(([id, label], i) => {
    const start = acc;
    acc += ratios[i];
    return { id, label, startRatio: start, endRatio: Math.min(acc, 1) };
  });
}

interface Seed {
  title: string;
  artist: string;
  album: string;
  year: number;
  duration: number;
  bpm: number;
  world: WorldId;
  rootMidi: number;
  scale: number[];
  density: number;
  accent: string;
  icon: string;
  sectionLabels: [string, string][];
}

const seeds: Seed[] = [
  {
    title: 'Glass Cities',
    artist: 'Tyler Jay',
    album: 'Night Transit EP',
    year: 2024,
    duration: 246,
    bpm: 122,
    world: 'NIGHT_TRANSIT',
    rootMidi: 45,
    scale: MINOR,
    density: 0.6,
    accent: '#e8963c',
    icon: '\u25B3',
    sectionLabels: [
      ['A', 'THE ARRIVAL'],
      ['B', 'THE TRANSIT'],
      ["B'", 'THE CITY'],
      ['C', 'NEG. SPACE'],
      ["A'", 'THE RETURN'],
    ],
  },
  {
    title: 'Paper Satellites',
    artist: 'Tyler Jay',
    album: 'Night Transit EP',
    year: 2024,
    duration: 321,
    bpm: 96,
    world: 'DATA_VOID',
    rootMidi: 48,
    scale: DORIAN,
    density: 0.35,
    accent: '#5ad1ea',
    icon: '\u2735',
    sectionLabels: [
      ['A', 'DRIFT'],
      ['B', 'ORBIT'],
      ['C', 'SIGNAL LOSS'],
      ["B'", 'RE-ACQUIRE'],
      ["A'", 'FADE'],
    ],
  },
  {
    title: 'Neon Fields',
    artist: 'Tyler Jay',
    album: 'Night Transit EP',
    year: 2024,
    duration: 278,
    bpm: 128,
    world: 'GLASS_CITIES',
    rootMidi: 43,
    scale: MINOR,
    density: 0.7,
    accent: '#5ad1ea',
    icon: '\u26A1',
    sectionLabels: [
      ['A', 'SKYLINE'],
      ['B', 'PULSE'],
      ["B'", 'OVERDRIVE'],
      ['C', 'BLACKOUT'],
      ["A'", 'DAWN'],
    ],
  },
  {
    title: 'Rain Archive',
    artist: 'Tyler Jay',
    album: 'Folded Maps',
    year: 2022,
    duration: 232,
    bpm: 84,
    world: 'NIGHT_TRANSIT',
    rootMidi: 50,
    scale: DORIAN,
    density: 0.3,
    accent: '#8f9bb3',
    icon: '\u2637',
    sectionLabels: [
      ['A', 'STATIC'],
      ['B', 'MEMORY'],
      ["A'", 'ARCHIVE'],
      ['OUT', 'RUNOFF'],
    ],
  },
  {
    title: 'Folded Maps',
    artist: 'Tyler Jay',
    album: 'Folded Maps',
    year: 2022,
    duration: 374,
    bpm: 104,
    world: 'DATA_VOID',
    rootMidi: 41,
    scale: PENT_MINOR,
    density: 0.45,
    accent: '#e8963c',
    icon: '\u25C8',
    sectionLabels: [
      ['A', 'UNFOLD'],
      ['B', 'GRID'],
      ["B'", 'OVERLAY'],
      ['C', 'TEAR'],
      ["A'", 'RECONSTRUCT'],
    ],
  },
  {
    title: 'Lossless Days',
    artist: 'Tyler Jay',
    album: 'Folded Maps',
    year: 2022,
    duration: 267,
    bpm: 118,
    world: 'GLASS_CITIES',
    rootMidi: 47,
    scale: MAJOR,
    density: 0.55,
    accent: '#5ad1ea',
    icon: '\u25C7',
    sectionLabels: [
      ['A', 'MORNING'],
      ['B', 'CLARITY'],
      ["A'", 'GOLDEN HOUR'],
      ['OUT', 'AFTERGLOW'],
    ],
  },
  {
    title: 'Signal Drift',
    artist: 'Tyler Jay',
    album: 'Rain Archive',
    year: 2023,
    duration: 303,
    bpm: 132,
    world: 'NIGHT_TRANSIT',
    rootMidi: 44,
    scale: MINOR,
    density: 0.65,
    accent: '#e05252',
    icon: '\u25B2',
    sectionLabels: [
      ['A', 'CARRIER'],
      ['B', 'NOISE FLOOR'],
      ["B'", 'LOCK'],
      ['C', 'DROPOUT'],
      ["A'", 'RESYNC'],
    ],
  },
  {
    title: 'The Way Out',
    artist: 'Tyler Jay',
    album: 'Rain Archive',
    year: 2023,
    duration: 251,
    bpm: 140,
    world: 'DATA_VOID',
    rootMidi: 46,
    scale: DORIAN,
    density: 0.8,
    accent: '#5ad1ea',
    icon: '\u2726',
    sectionLabels: [
      ['A', 'THRESHOLD'],
      ['B', 'ESCAPE'],
      ["B'", 'PURSUIT'],
      ["A'", 'CLEARING'],
    ],
  },
  {
    title: 'Afterglow',
    artist: 'Tyler Jay',
    album: 'Rain Archive',
    year: 2023,
    duration: 368,
    bpm: 90,
    world: 'GLASS_CITIES',
    rootMidi: 49,
    scale: MAJOR,
    density: 0.4,
    accent: '#e8963c',
    icon: '\u2600',
    sectionLabels: [
      ['A', 'EMBER'],
      ['B', 'BLOOM'],
      ["B'", 'HAZE'],
      ['C', 'STILLNESS'],
      ["A'", 'AFTERGLOW'],
    ],
  },
];

export const DEMO_TRACKS: TrackDef[] = seeds.map((s, i) => ({
  id: `demo-${i}`,
  title: s.title,
  artist: s.artist,
  album: s.album,
  year: s.year,
  duration: s.duration,
  bpm: s.bpm,
  timeSig: '4/4',
  world: s.world,
  rootMidi: s.rootMidi,
  scale: s.scale,
  density: s.density,
  source: 'procedural',
  sections: buildSections(s.sectionLabels),
  accent: s.accent,
  icon: s.icon,
  structureConfidence: 'authored',
}));

export function fmtTime(totalSeconds: number): string {
  if (!isFinite(totalSeconds) || totalSeconds < 0) totalSeconds = 0;
  const m = Math.floor(totalSeconds / 60);
  const s = Math.floor(totalSeconds % 60);
  return `${m}:${s.toString().padStart(2, '0')}`;
}

export function fmtTimecode(totalSeconds: number): string {
  if (!isFinite(totalSeconds) || totalSeconds < 0) totalSeconds = 0;
  const h = Math.floor(totalSeconds / 3600);
  const m = Math.floor((totalSeconds % 3600) / 60);
  const s = Math.floor(totalSeconds % 60);
  const f = Math.floor((totalSeconds % 1) * 30);
  return `${h.toString().padStart(2, '0')}:${m.toString().padStart(2, '0')}:${s
    .toString()
    .padStart(2, '0')}:${f.toString().padStart(2, '0')}`;
}
