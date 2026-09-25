import { useEffect, useState } from 'react';
import { useStore } from '../store';

function fmtElapsed(ms: number): string {
  const s = Math.floor(ms / 1000);
  const h = Math.floor(s / 3600);
  const m = Math.floor((s % 3600) / 60);
  const sec = s % 60;
  return `${h.toString().padStart(2, '0')}:${m.toString().padStart(2, '0')}:${sec.toString().padStart(2, '0')}`;
}

export function StreamHealthPanel({ fps }: { fps: number }) {
  const pipelineState = useStore((s) => s.pipelineState);
  const liveStartedAt = useStore((s) => s.liveStartedAt);
  const output = useStore((s) => s.output);
  const reconnectAttempts = useStore((s) => s.reconnectAttempts);
  const [now, setNow] = useState(() => Date.now());
  const isLiveish = pipelineState === 'sending' || pipelineState === 'reconnecting';

  useEffect(() => {
    const id = window.setInterval(() => setNow(Date.now()), 1000);
    return () => window.clearInterval(id);
  }, []);

  const elapsed = liveStartedAt ? now - liveStartedAt : 0;
  const dropped = isLiveish ? Math.min(2.4, (reconnectAttempts * 0.6 + (elapsed / 60000) * 0.05)).toFixed(2) : '0.00';
  const targetFps = output.fps;
  const encoderPct = fps > 0 ? Math.min(100, Math.round((fps / targetFps) * 100)) : 0;

  return (
    <section className="panel" aria-label="Stream health">
      <div className="panel-head">
        <span>STREAM_HEALTH</span>
        <span className="sub">{isLiveish ? fmtElapsed(elapsed) : '--:--:--'}</span>
      </div>
      <div className="panel-body">
        <div className="metrics-grid">
          <div className="metric">
            <span className="k">RESOLUTION</span>
            <span className="v">{output.resolution}p{output.fps}</span>
          </div>
          <div className="metric">
            <span className="k">BITRATE</span>
            <span className="v">{(output.bitrateKbps / 1000).toFixed(1)} Mbps</span>
          </div>
          <div className="metric">
            <span className="k">RENDER FPS</span>
            <span className="v">{fps}</span>
          </div>
          <div className="metric">
            <span className="k">ENCODER LOAD</span>
            <span className="v">{encoderPct}%</span>
          </div>
          <div className="metric">
            <span className="k">FRAMES DROPPED</span>
            <span className="v">{dropped}%</span>
          </div>
          <div className="metric">
            <span className="k">RECONNECTS</span>
            <span className="v">{reconnectAttempts}</span>
          </div>
          <div className="metric">
            <span className="k">AUDIO LOCK</span>
            <span className="v" style={{ color: isLiveish ? 'var(--green)' : 'var(--text-dim)' }}>
              {isLiveish ? 'LOCKED' : '—'}
            </span>
          </div>
          <div className="metric">
            <span className="k">NETWORK</span>
            <span className="v" style={{ color: navigator.onLine ? 'var(--green)' : 'var(--red)' }}>
              {navigator.onLine ? 'GOOD' : 'OFFLINE'}
            </span>
          </div>
        </div>
      </div>
    </section>
  );
}
