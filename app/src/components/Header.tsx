import { useStore } from '../store';

const STATE_LABEL: Record<string, string> = {
  offline: 'OFFLINE',
  previewing: 'PREVIEWING',
  preflighting: 'PREFLIGHTING',
  connecting: 'CONNECTING',
  sending: 'SENDING',
  reconnecting: 'RECONNECTING',
  stopping: 'STOPPING',
  error: 'ERROR',
};

export function Header({ fps, cols, rows }: { fps: number; cols: number; rows: number }) {
  const dna = useStore((s) => s.dna);
  const pipelineState = useStore((s) => s.pipelineState);
  const output = useStore((s) => s.output);

  let pillClass = 'off';
  if (pipelineState === 'sending' || pipelineState === 'reconnecting') pillClass = 'live';
  else if (pipelineState === 'previewing') pillClass = 'ready';
  else if (pipelineState === 'preflighting' || pipelineState === 'connecting') pillClass = 'busy';

  return (
    <header className="header">
      <div className="brand">
        <span className="mark">V</span>
        VAGABOND <small>// ASCII BROADCAST</small>
      </div>
      <div className="session-name">
        SESSION: <b>{dna.programName || 'UNNAMED'}</b>
      </div>
      <div className="header-stats">
        <span>
          GRID <b>{cols}×{rows}</b>
        </span>
        <span>
          FPS <b>{fps}</b>
        </span>
        <span>
          <b>{output.resolution}</b>
        </span>
        <span>AUDIO <b>48k</b></span>
        <span>RTMP</span>
        <span className={`pill ${pillClass}`}>PIPELINE // {STATE_LABEL[pipelineState]}</span>
      </div>
    </header>
  );
}
