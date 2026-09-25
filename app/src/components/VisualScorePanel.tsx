import type { MouseEvent, ReactNode } from 'react';
import { useStore } from '../store';
import { energyTier } from '../audio/synth';
import type { SectionMarker, TrackDef } from '../types';

const TRANSITION_CYCLE = ['CROSSFADE', 'DISSOLVE', 'BEAT MATCH', 'HOLD', 'FADE'];

function transitionLabel(prevTier: number, tier: number, i: number): string {
  if (i === 0) return 'FADE IN';
  const delta = tier - prevTier;
  if (delta > 0.35) return 'BUILD → GLITCH';
  if (delta < -0.35) return 'CROSSFADE';
  return TRANSITION_CYCLE[i % TRANSITION_CYCLE.length];
}

function sceneLabel(section: SectionMarker, i: number, total: number): string {
  const tier = energyTier(section.label);
  if (i === 0) return 'INTRO';
  if (i === total - 1) return tier > 0.6 ? 'CALLBACK' : 'OUTRO';
  if (tier >= 0.85) return 'PEAK';
  if (tier <= 0.3) return 'NEG_SPACE';
  return i % 2 === 0 ? 'APPROACH' : 'DRIFT';
}

function tierColor(tier: number): string {
  if (tier >= 0.85) return '#e05252';
  if (tier <= 0.3) return '#5c6b78';
  return tier > 0.5 ? '#5ad1ea' : '#3ddc84';
}

export function VisualScorePanel() {
  const tracks = useStore((s) => s.tracks);
  const currentIndex = useStore((s) => s.currentIndex);
  const currentTime = useStore((s) => s.currentTime);
  const seekRatio = useStore((s) => s.seekRatio);
  const track: TrackDef | undefined = tracks[currentIndex];

  if (!track) {
    return (
      <section className="panel" aria-label="Visual score">
        <div className="panel-head">VISUAL_SCORE // STRUCTURE</div>
        <div className="panel-body hint">No program loaded.</div>
      </section>
    );
  }

  const progress = Math.max(0, Math.min(1, currentTime / track.duration));
  const titleWindow = Math.min(0.5, 10 / track.duration);

  const handleSeek = (e: MouseEvent<HTMLDivElement>) => {
    const rect = e.currentTarget.getBoundingClientRect();
    const ratio = (e.clientX - rect.left) / rect.width;
    seekRatio(Math.max(0, Math.min(1, ratio)));
  };

  return (
    <section className="panel" aria-label="Visual score">
      <div className="panel-head">
        <span>VISUAL_SCORE // STRUCTURE</span>
        <span className="sub">SCORE: {track.title.toUpperCase().replace(/\s+/g, '_')}</span>
      </div>
      <div className="panel-body">
        <div className="score-rows">
          <ScoreRow label="CHAPTERS" onSeek={handleSeek} progress={progress}>
            {track.sections.map((s, i) => (
              <div
                key={`ch-${i}`}
                className="score-seg"
                style={{ width: `${(s.endRatio - s.startRatio) * 100}%`, background: tierColor(energyTier(s.label)) }}
                title={s.label}
              >
                {s.id}
              </div>
            ))}
          </ScoreRow>

          <ScoreRow label="SCENES" onSeek={handleSeek} progress={progress}>
            {track.sections.map((s, i) => {
              const active = progress >= s.startRatio && progress < s.endRatio;
              return (
                <div
                  key={`sc-${i}`}
                  className={`score-seg scene ${active ? 'active' : ''}`}
                  style={{ width: `${(s.endRatio - s.startRatio) * 100}%` }}
                  title={sceneLabel(s, i, track.sections.length)}
                >
                  {String(i + 1).padStart(2, '0')}_{sceneLabel(s, i, track.sections.length)}
                </div>
              );
            })}
          </ScoreRow>

          <ScoreRow label="TRANSITIONS" onSeek={handleSeek} progress={progress}>
            {track.sections.map((s, i) => (
              <div
                key={`tr-${i}`}
                className="score-seg scene"
                style={{ width: `${(s.endRatio - s.startRatio) * 100}%`, fontSize: 9 }}
              >
                {transitionLabel(i === 0 ? energyTier(s.label) : energyTier(track.sections[i - 1].label), energyTier(s.label), i)}
              </div>
            ))}
          </ScoreRow>

          <ScoreRow label="TITLES" onSeek={handleSeek} progress={progress}>
            <div className="score-seg scene" style={{ width: `${titleWindow * 100}%`, color: '#e8963c' }}>
              {track.title.toUpperCase()}
            </div>
            <div className="score-seg scene" style={{ width: `${(1 - 2 * titleWindow) * 100}%` }} />
            <div className="score-seg scene" style={{ width: `${titleWindow * 100}%`, color: '#e8963c' }}>
              {track.artist.toUpperCase()}
            </div>
          </ScoreRow>

          <div className="score-row" style={{ marginTop: 4 }}>
            <span className="score-row-label">
              {track.structureConfidence === 'authored' ? 'AUTHORED' : track.structureConfidence === 'estimated' ? 'ESTIMATED' : 'N/A'}
            </span>
            <span className="hint" style={{ margin: 0 }}>
              {track.structureConfidence === 'authored'
                ? 'Structure is program-authored (procedural demo track) — exact section boundaries.'
                : 'Structure estimated from the file\u2019s amplitude envelope. Treat labels as advisory, not semantic.'}
            </span>
          </div>
        </div>
      </div>
    </section>
  );
}

function ScoreRow({
  label,
  children,
  onSeek,
  progress,
}: {
  label: string;
  children: ReactNode;
  onSeek: (e: MouseEvent<HTMLDivElement>) => void;
  progress: number;
}) {
  return (
    <div className="score-row">
      <span className="score-row-label">{label}</span>
      <div className="score-track" onClick={onSeek}>
        {children}
        <div className="playhead" style={{ left: `${progress * 100}%` }} />
      </div>
    </div>
  );
}
