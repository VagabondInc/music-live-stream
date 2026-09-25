import { useEffect, useState } from 'react';
import { useStore } from '../store';

export function BottomBar() {
  const bottomTab = useStore((s) => s.bottomTab);
  const setBottomTab = useStore((s) => s.setBottomTab);
  const pipelineState = useStore((s) => s.pipelineState);
  const [now, setNow] = useState(new Date());

  useEffect(() => {
    const id = window.setInterval(() => setNow(new Date()), 1000);
    return () => window.clearInterval(id);
  }, []);

  const tabs = ['SCENES', 'OVERLAYS', 'AUDIO', 'OUTPUT', 'SHORTCUTS'] as const;

  return (
    <div className="bottom-tabbar">
      <div className="left">
        {tabs.map((t) => (
          <button key={t} className={bottomTab === t ? 'active' : ''} onClick={() => setBottomTab(t)}>
            {t}
          </button>
        ))}
      </div>
      <div className="right">
        <span className="status-chip">
          <span className="dot" style={{ background: 'var(--green)' }} /> ENCODER
        </span>
        <span className="status-chip">
          <span className="dot" style={{ background: 'var(--green)' }} /> AUDIO
        </span>
        <span className="status-chip">
          <span className="dot" style={{ background: navigator.onLine ? 'var(--green)' : 'var(--red)' }} /> NETWORK
        </span>
        <span className="status-chip">
          <span
            className="dot"
            style={{
              background:
                pipelineState === 'sending' || pipelineState === 'reconnecting' ? 'var(--red)' : 'var(--text-dim)',
            }}
          />{' '}
          GPU
        </span>
        <span>{now.toLocaleString()}</span>
      </div>
    </div>
  );
}
