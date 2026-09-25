import { createRoot } from 'react-dom/client';
import './index.css';
import App from './App.tsx';

// Note: StrictMode is intentionally omitted. This app owns a single
// long-lived AudioContext + canvas render loop (the Product Mission's
// "one program PCM bus" principle) which does not tolerate React 18
// StrictMode's deliberate double-invoke of effects in development.
createRoot(document.getElementById('root')!).render(<App />);
