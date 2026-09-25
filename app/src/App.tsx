import { useState } from 'react';
import { Header } from './components/Header';
import { QueuePanel } from './components/QueuePanel';
import { PreviewPanel } from './components/PreviewPanel';
import { VisualScorePanel } from './components/VisualScorePanel';
import { VisualDnaPanel } from './components/VisualDnaPanel';
import { NowPlayingCard } from './components/NowPlayingCard';
import { TransportBar } from './components/TransportBar';
import { OutputPanel } from './components/OutputPanel';
import { StreamHealthPanel } from './components/StreamHealthPanel';
import { BottomBar } from './components/BottomBar';

export default function App() {
  const [health, setHealth] = useState({ fps: 0, cols: 0, rows: 0 });

  return (
    <div className="app-shell">
      <Header fps={health.fps} cols={health.cols} rows={health.rows} />

      <div className="workspace">
        <QueuePanel />
        <div className="center-col">
          <PreviewPanel onHealth={setHealth} />
          <VisualScorePanel />
        </div>
        <VisualDnaPanel />
      </div>

      <div className="bottom-row">
        <NowPlayingCard />
        <TransportBar />
        <OutputPanel />
        <StreamHealthPanel fps={health.fps} />
      </div>

      <BottomBar />
    </div>
  );
}
