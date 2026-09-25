import { useStore } from '../store';
import { fmtTime } from '../audio/tracks';

export function NowPlayingCard() {
  const tracks = useStore((s) => s.tracks);
  const currentIndex = useStore((s) => s.currentIndex);
  const currentTime = useStore((s) => s.currentTime);
  const track = tracks[currentIndex];
  const next = tracks[(currentIndex + 1) % tracks.length];

  if (!track) {
    return (
      <section className="panel" aria-label="Now playing">
        <div className="panel-head">NOW_PLAYING</div>
        <div className="panel-body hint">Nothing loaded.</div>
      </section>
    );
  }

  const progressPct = Math.min(100, (currentTime / track.duration) * 100);

  return (
    <section className="panel" aria-label="Now playing">
      <div className="panel-head">NOW_PLAYING</div>
      <div className="now-playing">
        <div className="album-art" style={{ background: `linear-gradient(135deg, ${track.accent}, #10161d)` }}>
          {track.icon}
        </div>
        <div className="np-meta">
          <div className="track-num" style={{ display: 'inline', marginRight: 4 }}>
            {String(currentIndex + 1).padStart(2, '0')}
          </div>
          <span className="np-title">{track.title}</span>
          <div className="np-artist">{track.artist}</div>
          <div className="np-progress">
            <div className="np-progress-bar" style={{ width: `${progressPct}%` }} />
          </div>
          <div className="np-times">
            <span>{fmtTime(currentTime)}</span>
            <span>{fmtTime(track.duration)}</span>
          </div>
          {next && (
            <div className="np-next">
              NEXT // {next.title} · {fmtTime(next.duration)}
            </div>
          )}
        </div>
      </div>
    </section>
  );
}
