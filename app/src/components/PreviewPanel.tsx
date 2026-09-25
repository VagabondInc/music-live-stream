import { useEffect, useRef, useState } from 'react';
import { useStore } from '../store';
import { engine } from '../audio/engine';
import { AsciiRenderer } from '../visual/renderer';
import { fmtTimecode, fmtTime } from '../audio/tracks';
import { sectionAt } from '../audio/synth';

export function PreviewPanel({
  onHealth,
}: {
  onHealth: (h: { fps: number; cols: number; rows: number }) => void;
}) {
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const rendererRef = useRef<AsciiRenderer | null>(null);
  const [displayTime, setDisplayTime] = useState(0);
  const frameCounter = useRef(0);

  const tracks = useStore((s) => s.tracks);
  const currentIndex = useStore((s) => s.currentIndex);
  const track = tracks[currentIndex] ?? null;
  const dna = useStore((s) => s.dna);
  const isPlaying = useStore((s) => s.isPlaying);
  const pipelineState = useStore((s) => s.pipelineState);
  const setCurrentTime = useStore((s) => s.setCurrentTime);

  useEffect(() => {
    if (!canvasRef.current) return;
    const renderer = new AsciiRenderer(canvasRef.current);
    rendererRef.current = renderer;
    const ro = new ResizeObserver(() => renderer.resize());
    if (canvasRef.current.parentElement) ro.observe(canvasRef.current.parentElement);

    let raf = 0;
    const loop = () => {
      engine.tick();
      const t = engine.getTrackTime();
      const features = engine.getFeatures();
      renderer.render({ track: useStore.getState().tracks[useStore.getState().currentIndex] ?? null, trackTime: t, features, dna: useStore.getState().dna });

      frameCounter.current++;
      if (frameCounter.current % 6 === 0) {
        setDisplayTime(t);
        setCurrentTime(t);
        onHealth({ fps: renderer.getFps(), ...renderer.getGridSize() });
      }
      raf = requestAnimationFrame(loop);
    };
    raf = requestAnimationFrame(loop);

    return () => {
      cancelAnimationFrame(raf);
      ro.disconnect();
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  // Handle end-of-track -> auto-advance or stop, driven by engine callback.
  useEffect(() => {
    const handler = () => {
      const st = useStore.getState();
      if (st.autoAdvance) {
        st.next();
      } else {
        useStore.setState({ isPlaying: false });
      }
    };
    engine.onEnded(handler);
  }, []);

  const duration = track?.duration ?? 0;
  const nearStart = displayTime < 10;
  const nearEnd = duration > 0 && duration - displayTime < 10;
  const showTitle = !!track && dna.titles > 0 && (nearStart || nearEnd);
  const titleOpacity = showTitle
    ? Math.min(1, nearStart ? (10 - displayTime) / 2 + 0.3 : (10 - (duration - displayTime)) / 2 + 0.3)
    : 0;

  const section = track ? sectionAt(track, displayTime) : null;
  const sceneIndex = track && section ? track.sections.indexOf(section) + 1 : 0;

  return (
    <section className="panel" aria-label="Program preview" style={{ position: 'relative' }}>
      <div className="panel-head">
        <span>
          PROGRAM // {track ? `SCENE ${String(sceneIndex).padStart(2, '0')}` : 'IDLE'}
          {section ? ` // ${section.label}` : ''}
        </span>
        {(pipelineState === 'sending' || pipelineState === 'reconnecting') && (
          <span className="live-badge">● {pipelineState === 'sending' ? 'LIVE' : 'RECONNECTING'}</span>
        )}
      </div>
      <div className="preview-wrap">
        <div className="preview-canvas-holder">
          <canvas ref={canvasRef} className="preview-canvas" />
        </div>
        <div className="preview-topbar">
          <span>
            WORLD: {track?.world ?? '—'} · GLYPHS: {dna.strictAscii ? 'STRICT' : 'EXPANDED'}
          </span>
          <span>RENDER: REALTIME</span>
        </div>
        {track && (
          <div className="title-overlay" style={{ opacity: titleOpacity }}>
            <div className="t1">{track.title.toUpperCase()}</div>
            <div className="t2">{track.artist.toUpperCase()}</div>
          </div>
        )}
        <div className="preview-bottombar">
          <span>{isPlaying ? '▶ PLAYING' : '❚❚ PAUSED'}</span>
          <span>
            TC {fmtTimecode(displayTime)} / {fmtTime(duration)}
          </span>
        </div>
      </div>
    </section>
  );
}
