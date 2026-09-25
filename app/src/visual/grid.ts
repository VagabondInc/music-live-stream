export class GlyphGrid {
  cols: number;
  rows: number;
  chars: string[];
  fgs: string[];
  bgs: (string | null)[];

  constructor(cols: number, rows: number) {
    this.cols = cols;
    this.rows = rows;
    const size = cols * rows;
    this.chars = new Array(size).fill(' ');
    this.fgs = new Array(size).fill('#33424f');
    this.bgs = new Array(size).fill(null);
  }

  resize(cols: number, rows: number) {
    if (cols === this.cols && rows === this.rows) return;
    this.cols = cols;
    this.rows = rows;
    const size = cols * rows;
    this.chars = new Array(size).fill(' ');
    this.fgs = new Array(size).fill('#33424f');
    this.bgs = new Array(size).fill(null);
  }

  clear(ch = ' ', fg = '#33424f') {
    this.chars.fill(ch);
    this.fgs.fill(fg);
    this.bgs.fill(null);
  }

  idx(x: number, y: number) {
    return y * this.cols + x;
  }

  set(x: number, y: number, ch: string, fg: string, bg: string | null = null) {
    if (x < 0 || x >= this.cols || y < 0 || y >= this.rows) return;
    const i = this.idx(x, y);
    this.chars[i] = ch;
    this.fgs[i] = fg;
    if (bg !== null) this.bgs[i] = bg;
  }

  setBg(x: number, y: number, bg: string | null) {
    if (x < 0 || x >= this.cols || y < 0 || y >= this.rows) return;
    this.bgs[this.idx(x, y)] = bg;
  }

  get(x: number, y: number) {
    const i = this.idx(x, y);
    return { ch: this.chars[i], fg: this.fgs[i], bg: this.bgs[i] };
  }
}
