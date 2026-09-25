import { create } from 'zustand';
import { persist } from 'zustand/middleware';
import type {
  DestinationVisibility,
  DnaSettings,
  LocalPipelineState,
  PreflightCheck,
  TrackDef,
} from './types';
import { DEMO_TRACKS } from './audio/tracks';
import { engine } from './audio/engine';
import { estimateStructure } from './audio/AudioEngine';

export type ActiveTab = 'QUEUE' | 'LIBRARY' | 'FILTER' | 'IMPORT';
export type BottomTab = 'SCENES' | 'OVERLAYS' | 'AUDIO' | 'OUTPUT' | 'SHORTCUTS';

interface OutputProfile {
  rtmpUrl: string;
  rtmpKey: string;
  resolution: '720p' | '1080p' | '1440p';
  fps: 24 | 30 | 60;
  bitrateKbps: number;
}

interface AppState {
  tracks: TrackDef[];
  currentIndex: number;
  isPlaying: boolean;
  loop: boolean;
  autoAdvance: boolean;
  currentTime: number; // throttled, for UI display only
  activeTab: ActiveTab;
  bottomTab: BottomTab;
  dna: DnaSettings;
  output: OutputProfile;
  pipelineState: LocalPipelineState;
  destinationVisibility: DestinationVisibility;
  preflight: PreflightCheck[];
  liveStartedAt: number | null;
  reconnectAttempts: number;
  lastError: string | null;
  importNotice: string | null;

  selectTrack: (index: number, autoplay?: boolean) => void;
  playPause: () => void;
  stopTransport: () => void;
  next: () => void;
  prev: () => void;
  seekRatio: (ratio: number) => void;
  toggleLoop: () => void;
  toggleAutoAdvance: () => void;
  setActiveTab: (t: ActiveTab) => void;
  setBottomTab: (t: BottomTab) => void;
  setDna: (partial: Partial<DnaSettings>) => void;
  setOutput: (partial: Partial<OutputProfile>) => void;
  importFiles: (files: FileList | File[]) => Promise<void>;
  removeTrack: (id: string) => void;
  setCurrentTime: (t: number) => void;
  runPreflight: () => void;
  goLive: () => void;
  stopSending: () => void;
  confirmLive: () => void;
  simulateReconnect: () => void;
  setError: (msg: string | null) => void;
}

const defaultDna: DnaSettings = {
  programName: 'GLASS_CITIES',
  performance: 'expressive',
  detail: 'layered',
  color: 'restrained',
  glyphs: 70,
  motion: 60,
  glitch: 18,
  titles: 80,
  camera: 50,
  strictAscii: false,
  photosensitivitySafe: true,
  reduceMotion: false,
};

function basePreflight(): PreflightCheck[] {
  return [
    { id: 'audio', label: 'Program audio available', status: 'pending', detail: 'Awaiting check.' },
    { id: 'analysis', label: 'Visual score analysis coverage', status: 'pending', detail: 'Awaiting check.' },
    { id: 'encoder', label: 'Encoder capability (simulated)', status: 'pending', detail: 'Awaiting check.' },
    { id: 'network', label: 'Network reachability (simulated)', status: 'pending', detail: 'Awaiting check.' },
    { id: 'destination', label: 'Destination URL / key present', status: 'pending', detail: 'Awaiting check.' },
    { id: 'safety', label: 'Photosensitivity / motion safety mode', status: 'pending', detail: 'Awaiting check.' },
  ];
}

export const useStore = create<AppState>()(
  persist(
    (set, get) => ({
      tracks: DEMO_TRACKS,
      currentIndex: 0,
      isPlaying: false,
      loop: false,
      autoAdvance: true,
      currentTime: 0,
      activeTab: 'QUEUE',
      bottomTab: 'SCENES',
      dna: defaultDna,
      output: { rtmpUrl: '', rtmpKey: '', resolution: '1080p', fps: 30, bitrateKbps: 9800 },
      pipelineState: 'offline',
      destinationVisibility: 'unknown',
      preflight: basePreflight(),
      liveStartedAt: null,
      reconnectAttempts: 0,
      lastError: null,
      importNotice: null,

      selectTrack: (index, autoplay = true) => {
        const track = get().tracks[index];
        if (!track) return;
        set({ currentIndex: index, currentTime: 0, isPlaying: autoplay });
        void engine.loadTrack(track, autoplay, 0).then(() => {
          engine.setLoop(get().loop);
        });
        if (get().pipelineState === 'offline') set({ pipelineState: 'previewing' });
      },

      playPause: () => {
        const { isPlaying, tracks, currentIndex } = get();
        if (!engine.currentTrack && tracks[currentIndex]) {
          get().selectTrack(currentIndex, true);
          return;
        }
        if (isPlaying) {
          engine.pause();
          set({ isPlaying: false });
        } else {
          engine.play();
          set({ isPlaying: true, pipelineState: get().pipelineState === 'offline' ? 'previewing' : get().pipelineState });
        }
      },

      stopTransport: () => {
        engine.stop();
        set({ isPlaying: false, currentTime: 0 });
      },

      next: () => {
        const { currentIndex, tracks } = get();
        const n = (currentIndex + 1) % tracks.length;
        get().selectTrack(n, true);
      },

      prev: () => {
        const { currentIndex, tracks } = get();
        const p = (currentIndex - 1 + tracks.length) % tracks.length;
        get().selectTrack(p, true);
      },

      seekRatio: (ratio) => {
        const track = get().tracks[get().currentIndex];
        if (!track) return;
        const t = Math.max(0, Math.min(track.duration, ratio * track.duration));
        engine.seek(t);
        set({ currentTime: t });
      },

      toggleLoop: () => {
        const loop = !get().loop;
        engine.setLoop(loop);
        set({ loop });
      },
      toggleAutoAdvance: () => set({ autoAdvance: !get().autoAdvance }),

      setActiveTab: (t) => set({ activeTab: t }),
      setBottomTab: (t) => set({ bottomTab: t }),

      setDna: (partial) => set({ dna: { ...get().dna, ...partial } }),
      setOutput: (partial) => set({ output: { ...get().output, ...partial } }),

      importFiles: async (files) => {
        const list = Array.from(files).filter((f) => f.type.startsWith('audio/'));
        if (list.length === 0) {
          set({ importNotice: 'No playable audio files were found in that selection.' });
          return;
        }
        const worlds: TrackDef['world'][] = ['NIGHT_TRANSIT', 'GLASS_CITIES', 'DATA_VOID'];
        const newTracks: TrackDef[] = [];
        for (const file of list) {
          const url = URL.createObjectURL(file);
          const id = `file-${Date.now()}-${Math.random().toString(36).slice(2, 8)}`;
          const world = worlds[Math.floor(Math.random() * worlds.length)];
          let duration = 0;
          try {
            const buf = await file.arrayBuffer();
            const decodeCtx = new (window.AudioContext || (window as any).webkitAudioContext)();
            const audioBuffer = await decodeCtx.decodeAudioData(buf.slice(0));
            duration = audioBuffer.duration;
            const sections = estimateStructure(audioBuffer);
            newTracks.push({
              id,
              title: file.name.replace(/\.[^/.]+$/, ''),
              artist: 'Imported File',
              album: 'Local Import',
              year: new Date().getFullYear(),
              duration,
              bpm: 0,
              timeSig: '—',
              world,
              rootMidi: 45,
              scale: [0, 2, 3, 5, 7, 8, 10],
              density: 0.5,
              source: 'file',
              fileUrl: url,
              sections,
              accent: '#8f9bb3',
              icon: '\u266A',
              structureConfidence: 'estimated',
            });
            void decodeCtx.close();
          } catch {
            set({ importNotice: `"${file.name}" could not be decoded and was skipped.` });
          }
        }
        if (newTracks.length > 0) {
          set({ tracks: [...get().tracks, ...newTracks], importNotice: `Imported ${newTracks.length} local file(s). Structure is estimated from amplitude, not guaranteed rights-cleared for live use.` });
        }
      },

      removeTrack: (id) => {
        const tracks = get().tracks.filter((t) => t.id !== id);
        set({ tracks });
      },

      setCurrentTime: (t) => set({ currentTime: t }),

      runPreflight: () => {
        const { output, dna, tracks, currentIndex } = get();
        set({ pipelineState: 'preflighting', preflight: basePreflight() });
        const track = tracks[currentIndex];
        window.setTimeout(() => {
          const checks: PreflightCheck[] = [
            {
              id: 'audio',
              label: 'Program audio available',
              status: track ? 'pass' : 'fail',
              detail: track ? `${track.title} — program bus active.` : 'No track loaded.',
            },
            {
              id: 'analysis',
              label: 'Visual score analysis coverage',
              status: track?.structureConfidence === 'authored' ? 'pass' : 'warn',
              detail:
                track?.structureConfidence === 'authored'
                  ? 'Full authored structure available.'
                  : 'Structure is an amplitude-based estimate, not semantic analysis.',
            },
            {
              id: 'encoder',
              label: 'Encoder capability (simulated)',
              status: 'warn',
              detail: 'This browser MVP simulates the H.264/AAC RTMPS publisher; no native encoder is present.',
            },
            {
              id: 'network',
              label: 'Network reachability (simulated)',
              status: navigator.onLine ? 'pass' : 'fail',
              detail: navigator.onLine ? 'Browser reports online.' : 'Browser reports offline.',
            },
            {
              id: 'destination',
              label: 'Destination URL / key present',
              status: output.rtmpUrl && output.rtmpKey ? 'pass' : 'fail',
              detail: output.rtmpUrl && output.rtmpKey ? 'Destination configured.' : 'Enter an RTMPS URL and stream key.',
            },
            {
              id: 'safety',
              label: 'Photosensitivity / motion safety mode',
              status: dna.photosensitivitySafe ? 'pass' : 'warn',
              detail: dna.photosensitivitySafe
                ? 'Photosensitivity Safe is enabled.'
                : 'Photosensitivity Safe is off — flashing effects are permitted.',
            },
          ];
          const hasFail = checks.some((c) => c.status === 'fail');
          set({ preflight: checks, pipelineState: hasFail ? 'error' : 'previewing', lastError: hasFail ? 'Preflight found blocking issues. Resolve them before going live.' : null });
        }, 900);
      },

      goLive: () => {
        const { preflight } = get();
        const hasFail = preflight.some((c) => c.status === 'fail');
        if (hasFail) {
          set({ lastError: 'Cannot go live: resolve blocking preflight issues first.' });
          return;
        }
        set({ pipelineState: 'connecting', lastError: null });
        window.setTimeout(() => {
          set({
            pipelineState: 'sending',
            destinationVisibility: 'unknown',
            liveStartedAt: Date.now(),
            reconnectAttempts: 0,
          });
        }, 1100);
      },

      stopSending: () => {
        set({ pipelineState: 'stopping' });
        window.setTimeout(() => {
          set({ pipelineState: 'previewing', destinationVisibility: 'unknown', liveStartedAt: null });
        }, 500);
      },

      confirmLive: () => set({ destinationVisibility: 'creatorReportedLive' }),

      simulateReconnect: () => {
        if (get().pipelineState !== 'sending') return;
        set({ pipelineState: 'reconnecting', destinationVisibility: 'unknown', reconnectAttempts: get().reconnectAttempts + 1 });
        window.setTimeout(() => {
          if (get().pipelineState === 'reconnecting') set({ pipelineState: 'sending' });
        }, 2200);
      },

      setError: (msg) => set({ lastError: msg }),
    }),
    {
      name: 'vagabond-ascii-broadcast-mvp',
      partialize: (state) => ({
        dna: state.dna,
        output: { ...state.output, rtmpUrl: '', rtmpKey: '' },
        loop: state.loop,
        autoAdvance: state.autoAdvance,
      }),
    },
  ),
);
