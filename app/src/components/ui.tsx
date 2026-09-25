export function Toggle({ on, onToggle, label }: { on: boolean; onToggle: () => void; label?: string }) {
  return (
    <div className="toggle-row" role="group">
      <button
        className={`toggle ${on ? 'on' : ''}`}
        role="switch"
        aria-checked={on}
        aria-label={label || 'toggle'}
        onClick={onToggle}
      >
        <span className="knob" />
      </button>
      {label && <span>{label}</span>}
    </div>
  );
}

export function Slider({
  label,
  value,
  onChange,
  min = 0,
  max = 100,
}: {
  label: string;
  value: number;
  onChange: (v: number) => void;
  min?: number;
  max?: number;
}) {
  return (
    <div className="slider-row">
      <div className="slider-top">
        <span>{label}</span>
        <b>{value}</b>
      </div>
      <input
        type="range"
        min={min}
        max={max}
        value={value}
        aria-label={label}
        onChange={(e) => onChange(Number(e.target.value))}
      />
    </div>
  );
}

const STATUS_COLOR: Record<string, string> = {
  pass: 'var(--green)',
  good: 'var(--green)',
  warn: 'var(--yellow)',
  fail: 'var(--red)',
  pending: 'var(--text-dim)',
  off: 'var(--text-dim)',
};

export function StatusDot({ status }: { status: string }) {
  return <span className="dot" style={{ background: STATUS_COLOR[status] || 'var(--text-dim)' }} />;
}
