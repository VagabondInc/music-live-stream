import { useRef, useState } from 'react';
import { useStore } from '../store';
import { fmtTime } from '../audio/tracks';

export function QueuePanel() {
  const tracks = useStore((s) => s.tracks);
  const currentIndex = useStore((s) => s.currentIndex);
  const selectTrack = useStore((s) => s.selectTrack);
  const removeTrack = useStore((s) => s.removeTrack);
  const activeTab = useStore((s) => s.activeTab);
  const setActiveTab = useStore((s) => s.setActiveTab);
  const importFiles = useStore((s) => s.importFiles);
  const importNotice = useStore((s) => s.importNotice);
  const setError = useStore((s) => s.setError);

  const [dragOver, setDragOver] = useState(false);
  const fileInput = useRef<HTMLInputElement>(null);

  const nextUp = tracks.slice(currentIndex + 1, currentIndex + 4);

  return (
    <section className="panel" aria-label="Playlist queue">
      <div className="tabs">
        {(['QUEUE', 'LIBRARY', 'FILTER', 'IMPORT'] as const).map((t) => (
          <button key={t} className={activeTab === t ? 'active' : ''} onClick={() => setActiveTab(t)}>
            {t}
          </button>
        ))}
      </div>

      {activeTab === 'QUEUE' && (
        <div className="panel-body">
          <div className="panel-head" style={{ border: 'none', padding: '0 0 6px' }}>
            <span>QUEUE // {tracks.length} TRACKS</span>
          </div>

          {importNotice && (
            <div className="notice-banner">
              <span>{importNotice}</span>
              <button onClick={() => useStore.setState({ importNotice: null })} aria-label="Dismiss">
                ×
              </button>
            </div>
          )}

          <div
            className={`dropzone ${dragOver ? 'drag' : ''}`}
            onDragOver={(e) => {
              e.preventDefault();
              setDragOver(true);
            }}
            onDragLeave={() => setDragOver(false)}
            onDrop={(e) => {
              e.preventDefault();
              setDragOver(false);
              if (e.dataTransfer.files?.length) void importFiles(e.dataTransfer.files);
            }}
          >
            Drag local audio files here, or{' '}
            <button className="btn-small" onClick={() => fileInput.current?.click()}>
              Choose Files
            </button>
            <input
              ref={fileInput}
              type="file"
              accept="audio/*"
              multiple
              hidden
              onChange={(e) => {
                if (e.target.files?.length) void importFiles(e.target.files);
                e.target.value = '';
              }}
            />
          </div>

          {tracks.map((track, i) => (
            <div
              key={track.id}
              className={`track-row ${i === currentIndex ? 'active' : ''}`}
              onClick={() => selectTrack(i, true)}
              role="button"
              tabIndex={0}
              onKeyDown={(e) => {
                if (e.key === 'Enter') selectTrack(i, true);
              }}
              aria-current={i === currentIndex}
            >
              <span className="track-num">{String(i + 1).padStart(2, '0')}</span>
              <span className="track-icon" style={{ color: track.accent }}>
                {track.icon}
              </span>
              <span className="track-meta">
                <div className="track-title">{track.title}</div>
                <div className="track-artist">{track.artist}</div>
              </span>
              <span className="track-dur">{fmtTime(track.duration)}</span>
              <button
                className="track-remove"
                aria-label={`Remove ${track.title}`}
                onClick={(e) => {
                  e.stopPropagation();
                  if (tracks.length <= 1) {
                    setError('At least one track must remain in the queue.');
                    return;
                  }
                  removeTrack(track.id);
                }}
              >
                ×
              </button>
            </div>
          ))}

          {nextUp.length > 0 && (
            <>
              <div className="next-up-label">NEXT UP</div>
              {nextUp.map((t) => (
                <div key={t.id} className="track-row" style={{ opacity: 0.7, cursor: 'default' }}>
                  <span className="track-icon" style={{ color: t.accent }}>
                    {t.icon}
                  </span>
                  <span className="track-meta">
                    <div className="track-title">{t.title}</div>
                  </span>
                  <span className="track-dur">{fmtTime(t.duration)}</span>
                </div>
              ))}
            </>
          )}
        </div>
      )}

      {activeTab === 'LIBRARY' && (
        <div className="panel-body">
          <p className="hint">
            Full media-library browsing (Apple Music / Files) is out of scope for this browser-based MVP. The Product
            Mission's source matrix (playlist metadata vs. playback vs. raw audio vs. analysis vs. rebroadcast rights)
            still governs the Import tab: use it to bring in your own local audio files.
          </p>
        </div>
      )}

      {activeTab === 'FILTER' && (
        <div className="panel-body">
          <p className="hint">Sort / filter / duplicate-detection tooling is planned for a later stage (see roadmap). Not yet implemented in this MVP.</p>
        </div>
      )}

      {activeTab === 'IMPORT' && (
        <div className="panel-body">
          <p className="hint" style={{ marginBottom: 8 }}>
            Import local audio files. Each becomes a real track: decoded, played back, and analyzed live through the
            same audio pipeline as the demo program — nothing here is faked. Structure (intro/build/peak/outro) is
            estimated from the file's amplitude envelope, not licensed metadata.
          </p>
          <button className="btn-small" onClick={() => fileInput.current?.click()}>
            Choose Audio Files…
          </button>
          <p className="hint">
            Rights: you are responsible for confirming you have the necessary rights before including a track in a
            live broadcast. This MVP does not verify licensing.
          </p>
        </div>
      )}
    </section>
  );
}
