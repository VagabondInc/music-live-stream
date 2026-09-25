import { useState } from 'react';
import { useStore } from '../store';
import { StatusDot } from './ui';

const STATE_TEXT: Record<string, string> = {
  offline: 'OFFLINE',
  previewing: 'PREVIEWING',
  preflighting: 'PREFLIGHTING…',
  connecting: 'CONNECTING…',
  sending: 'SENDING',
  reconnecting: 'RECONNECTING…',
  stopping: 'STOPPING…',
  error: 'ERROR',
};

export function OutputPanel() {
  const output = useStore((s) => s.output);
  const setOutput = useStore((s) => s.setOutput);
  const pipelineState = useStore((s) => s.pipelineState);
  const destinationVisibility = useStore((s) => s.destinationVisibility);
  const preflight = useStore((s) => s.preflight);
  const runPreflight = useStore((s) => s.runPreflight);
  const goLive = useStore((s) => s.goLive);
  const stopSending = useStore((s) => s.stopSending);
  const confirmLive = useStore((s) => s.confirmLive);
  const simulateReconnect = useStore((s) => s.simulateReconnect);
  const lastError = useStore((s) => s.lastError);
  const [showKey, setShowKey] = useState(false);

  const canGoLive = pipelineState === 'previewing' && preflight.some((c) => c.status !== 'pending') && !preflight.some((c) => c.status === 'fail');
  const isLiveish = pipelineState === 'sending' || pipelineState === 'reconnecting';

  let destLabel = 'Destination unverified';
  if (destinationVisibility === 'creatorReportedLive') destLabel = 'LIVE — creator confirmed';

  return (
    <section className="panel" aria-label="Output and stream configuration">
      <div className="panel-head">
        <span>OUTBOUND_STATE</span>
        <span className="sub">{output.resolution}p{output.fps}</span>
      </div>
      <div className="panel-body">
        {lastError && <div className="error-banner">{lastError}</div>}

        <div className="status-line">
          <StatusDot status={isLiveish ? 'fail' : pipelineState === 'previewing' ? 'pass' : pipelineState === 'error' ? 'fail' : 'pending'} />
          {STATE_TEXT[pipelineState]}
        </div>
        {isLiveish && (
          <p className="hint" style={{ marginBottom: 8 }}>
            {destLabel}.{' '}
            {destinationVisibility !== 'creatorReportedLive' && (
              <button className="btn-small" onClick={confirmLive}>
                I confirmed this is live on YouTube
              </button>
            )}
          </p>
        )}

        <div className="field-row">
          <label htmlFor="rtmp-url">RTMPS URL</label>
          <input
            id="rtmp-url"
            type="text"
            placeholder="rtmps://a.rtmp.youtube.com/live2"
            value={output.rtmpUrl}
            onChange={(e) => setOutput({ rtmpUrl: e.target.value })}
          />
        </div>
        <div className="field-row">
          <label htmlFor="rtmp-key">STREAM KEY</label>
          <div style={{ display: 'flex', gap: 6 }}>
            <input
              id="rtmp-key"
              type={showKey ? 'text' : 'password'}
              placeholder="stream key"
              value={output.rtmpKey}
              onChange={(e) => setOutput({ rtmpKey: e.target.value })}
            />
            <button className="btn-small" onClick={() => setShowKey((v) => !v)} aria-label="Toggle key visibility">
              {showKey ? 'hide' : 'show'}
            </button>
          </div>
        </div>
        <div className="field-row" style={{ display: 'flex', gap: 6 }}>
          <div style={{ flex: 1 }}>
            <label htmlFor="res">RESOLUTION</label>
            <select id="res" value={output.resolution} onChange={(e) => setOutput({ resolution: e.target.value as any })}>
              <option value="720p">720p</option>
              <option value="1080p">1080p</option>
              <option value="1440p">1440p</option>
            </select>
          </div>
          <div style={{ width: 70 }}>
            <label htmlFor="fps">FPS</label>
            <select id="fps" value={output.fps} onChange={(e) => setOutput({ fps: Number(e.target.value) as any })}>
              <option value={24}>24</option>
              <option value={30}>30</option>
              <option value={60}>60</option>
            </select>
          </div>
        </div>

        <button className="btn-small" style={{ width: '100%', marginBottom: 8 }} onClick={runPreflight}>
          Run Preflight
        </button>

        <div className="check-list">
          {preflight.map((c) => (
            <div className="check-item" key={c.id}>
              <span className={`check-dot ${c.status}`} />
              <span>
                <span className="check-label">{c.label}</span>
                <br />
                <span className="check-detail">{c.detail}</span>
              </span>
            </div>
          ))}
        </div>

        <div style={{ marginTop: 10 }}>
          {!isLiveish ? (
            <button className={`go-live-btn ${canGoLive ? '' : 'idle'}`} disabled={!canGoLive} onClick={goLive}>
              ● GO LIVE
            </button>
          ) : (
            <button className="go-live-btn" onClick={stopSending}>
              ■ STOP SENDING
            </button>
          )}
        </div>
        {pipelineState === 'sending' && (
          <button className="btn-small" style={{ width: '100%', marginTop: 6 }} onClick={simulateReconnect}>
            Simulate network hiccup
          </button>
        )}
        <p className="hint">
          This MVP runs entirely in the browser and cannot open a real RTMPS/H.264 publisher — browsers have no such
          API. "Sending" here simulates the state machine and preflight checklist from the product spec. The native
          app implements AVFoundation/VideoToolbox capture and an RTMPS publisher for real YouTube delivery.
        </p>
      </div>
    </section>
  );
}
