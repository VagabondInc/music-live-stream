import { useStore } from '../store';
import { fmtTime } from '../audio/tracks';

export function TransportBar() {
  const tracks = useStore((s) => s.tracks);
  const currentIndex = useStore((s) => s.currentIndex);
  const isPlaying = useStore((s) => s.isPlaying);
  const currentTime = useStore((s) => s.currentTime);
  const loop = useStore((s) => s.loop);
  const autoAdvance = useStore((s) => s.autoAdvance);
  const playPause = useStore((s) => s.playPause);
  const stopTransport = useStore((s) => s.stopTransport);
  const next = useStore((s) => s.next);
  const prev = useStore((s) => s.prev);
  const seekRatio = useStore((s) => s.seekRatio);
  const toggleLoop = useStore((s) => s.toggleLoop);
  const toggleAutoAdvance = useStore((s) => s.toggleAutoAdvance);

  const track = tracks[currentIndex];
  const progress = track ? Math.min(1, currentTime / track.duration) : 0;

  return (
    <section className="panel" aria-label="Transport controls">
      <div className="panel-head">TRANSPORT</div>
      <div className="panel-body">
        <div className="transport-time">{fmtTime(currentTime)}</div>
        <div className="transport-sub">/ {fmtTime(track?.duration ?? 0)}</div>
        <input
          className="seek"
          type="range"
          min={0}
          max={1000}
          value={Math.round(progress * 1000)}
          aria-label="Seek"
          onChange={(e) => seekRatio(Number(e.target.value) / 1000)}
        />
        <div className="transport-controls">
          <button aria-label="Previous track" onClick={prev}>
            ⏮
          </button>
          <button aria-label={isPlaying ? 'Pause' : 'Play'} className="primary" onClick={playPause}>
            {isPlaying ? '❚❚' : '▶'}
          </button>
          <button aria-label="Stop" onClick={stopTransport}>
            ■
          </button>
          <button aria-label="Next track" onClick={next}>
            ⏭
          </button>
        </div>
        <div className="transport-toggles">
          <span className={loop ? 'on' : ''} onClick={toggleLoop} role="button" tabIndex={0}>
            LOOP {loop ? '●' : '○'}
          </span>
          <span className={autoAdvance ? 'on' : ''} onClick={toggleAutoAdvance} role="button" tabIndex={0}>
            AUTO ADVANCE {autoAdvance ? '●' : '○'}
          </span>
        </div>
        {track && (
          <div className="transport-sub" style={{ marginTop: 8 }}>
            BPM {track.bpm || '—'} · {track.timeSig}
          </div>
        )}
      </div>
    </section>
  );
}
