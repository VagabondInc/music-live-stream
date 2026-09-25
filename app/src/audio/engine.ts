import { AudioEngine } from './AudioEngine';

// Single shared program audio engine instance for the whole app — mirrors
// the Product Mission's "one program PCM bus" principle: exactly one
// pipeline owns playback + analysis, and every consumer observes it.
export const engine = new AudioEngine();
