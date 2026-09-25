import { useStore } from '../store';
import { WORLDS } from '../types';
import type { WorldId } from '../types';
import { Slider, Toggle } from './ui';

export function VisualDnaPanel() {
  const dna = useStore((s) => s.dna);
  const setDna = useStore((s) => s.setDna);
  const tracks = useStore((s) => s.tracks);
  const currentIndex = useStore((s) => s.currentIndex);
  const track = tracks[currentIndex];

  const setTrackWorld = (world: WorldId) => {
    if (!track) return;
    const updated = tracks.map((t, i) => (i === currentIndex ? { ...t, world } : t));
    useStore.setState({ tracks: updated });
  };

  return (
    <section className="panel" aria-label="Visual DNA controls">
      <div className="panel-head">
        <span>VISUAL DNA</span>
        <span className="sub">GUIDED</span>
      </div>
      <div className="panel-body">
        <div className="dna-field">
          <label htmlFor="dna-program">PROGRAM</label>
          <input
            id="dna-program"
            type="text"
            value={dna.programName}
            onChange={(e) => setDna({ programName: e.target.value.toUpperCase().replace(/\s+/g, '_') })}
          />
        </div>

        <div className="dna-field">
          <label htmlFor="dna-world">CURRENT WORLD</label>
          <select id="dna-world" value={track?.world} onChange={(e) => setTrackWorld(e.target.value as WorldId)}>
            {WORLDS.map((w) => (
              <option key={w.id} value={w.id}>
                {w.label}
              </option>
            ))}
          </select>
        </div>

        <div className="dna-field">
          <label htmlFor="dna-perf">PERFORMANCE</label>
          <select id="dna-perf" value={dna.performance} onChange={(e) => setDna({ performance: e.target.value as any })}>
            <option value="subtle">Subtle</option>
            <option value="expressive">Expressive</option>
            <option value="intense">Intense</option>
          </select>
        </div>

        <div className="dna-field">
          <label htmlFor="dna-detail">DETAIL</label>
          <select id="dna-detail" value={dna.detail} onChange={(e) => setDna({ detail: e.target.value as any })}>
            <option value="minimal">Minimal</option>
            <option value="layered">Layered</option>
            <option value="dense">Dense</option>
          </select>
        </div>

        <div className="dna-field">
          <label htmlFor="dna-color">COLOR</label>
          <select id="dna-color" value={dna.color} onChange={(e) => setDna({ color: e.target.value as any })}>
            <option value="restrained">Restrained</option>
            <option value="vivid">Vivid</option>
            <option value="mono">Mono</option>
          </select>
        </div>

        <Slider label="GLYPHS" value={dna.glyphs} onChange={(v) => setDna({ glyphs: v })} />
        <Slider label="MOTION" value={dna.motion} onChange={(v) => setDna({ motion: v })} />
        <Slider label="GLITCH" value={dna.glitch} onChange={(v) => setDna({ glitch: v })} />
        <Slider label="TITLES" value={dna.titles} onChange={(v) => setDna({ titles: v })} />
        <Slider label="CAMERA" value={dna.camera} onChange={(v) => setDna({ camera: v })} />

        <div className="section-divider">ADVANCED</div>
        <Toggle label="Strict ASCII (7-bit only)" on={dna.strictAscii} onToggle={() => setDna({ strictAscii: !dna.strictAscii })} />

        <div className="section-divider">ACCESSIBILITY</div>
        <Toggle
          label="Reduce Motion"
          on={dna.reduceMotion}
          onToggle={() => setDna({ reduceMotion: !dna.reduceMotion })}
        />
        <Toggle
          label="Photosensitivity Safe"
          on={dna.photosensitivitySafe}
          onToggle={() => setDna({ photosensitivitySafe: !dna.photosensitivitySafe })}
        />
        <p className="hint">
          Photosensitivity Safe suppresses glitch/flash effects and caps luminance-change rate on the generated
          broadcast graphics themselves, not just the control UI.
        </p>
      </div>
    </section>
  );
}
