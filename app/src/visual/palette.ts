import type { WorldId } from '../types';

export type ColorMode = 'restrained' | 'vivid' | 'mono';

export interface WorldPalette {
  bg: string;
  dim: string;
  mid: string;
  bright: string;
  accentA: string;
  accentB: string;
  title: string;
}

const PALETTES: Record<WorldId, WorldPalette> = {
  NIGHT_TRANSIT: {
    bg: '#070a0e',
    dim: '#243241',
    mid: '#4f96ad',
    bright: '#bfeaf5',
    accentA: '#5ad1ea',
    accentB: '#e8963c',
    title: '#f4f7fa',
  },
  GLASS_CITIES: {
    bg: '#080a10',
    dim: '#22303f',
    mid: '#3d8fc4',
    bright: '#dff0ff',
    accentA: '#5ad1ea',
    accentB: '#f0d675',
    title: '#f4f7fa',
  },
  DATA_VOID: {
    bg: '#07080c',
    dim: '#2a2438',
    mid: '#8f6bd6',
    bright: '#e7d9ff',
    accentA: '#b78cf2',
    accentB: '#e8963c',
    title: '#f4f7fa',
  },
};

export function getPalette(world: WorldId, mode: ColorMode): WorldPalette {
  const p = PALETTES[world];
  if (mode === 'mono') {
    return { ...p, accentA: p.mid, accentB: p.bright, bright: '#eef3f6', mid: '#7d8b96', dim: '#2a333c' };
  }
  if (mode === 'vivid') {
    return { ...p, mid: p.accentA, dim: shade(p.dim, 1.4) };
  }
  return p;
}

function shade(hex: string, factor: number): string {
  const c = hex.replace('#', '');
  const r = Math.min(255, Math.round(parseInt(c.slice(0, 2), 16) * factor));
  const g = Math.min(255, Math.round(parseInt(c.slice(2, 4), 16) * factor));
  const b = Math.min(255, Math.round(parseInt(c.slice(4, 6), 16) * factor));
  return `rgb(${r},${g},${b})`;
}

export function lerpColor(a: string, b: string, t: number): string {
  const pa = hexToRgb(a);
  const pb = hexToRgb(b);
  const r = Math.round(pa.r + (pb.r - pa.r) * t);
  const g = Math.round(pa.g + (pb.g - pa.g) * t);
  const bl = Math.round(pa.b + (pb.b - pa.b) * t);
  return `rgb(${r},${g},${bl})`;
}

function hexToRgb(hex: string) {
  const c = hex.replace('#', '');
  return {
    r: parseInt(c.slice(0, 2), 16),
    g: parseInt(c.slice(2, 4), 16),
    b: parseInt(c.slice(4, 6), 16),
  };
}

export const DENSITY_RAMP = ' .\'`^:;~-_,+<>i!lI?/\\|(){}[]*#MW&8%B@$';

export function densityChar(v: number, strictAscii: boolean): string {
  const ramp = strictAscii ? ' .:-=+*#%@' : DENSITY_RAMP;
  const idx = Math.max(0, Math.min(ramp.length - 1, Math.floor(v * (ramp.length - 1))));
  return ramp[idx];
}
