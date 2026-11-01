/**
 * Spectrogram maths for the Validate screen: turns decoded audio into a grid
 * of loudness values (time × frequency) that a canvas can paint.
 *
 * Short-time Fourier transform with a Hann window. Settings are chosen for
 * bird calls in 48 kHz recordings: ~47 Hz frequency resolution, and about one
 * column per screen pixel.
 */

export interface SpectrogramData {
  /** loudness in dB, column-major: values[col * rows + row], row 0 = lowest frequency */
  values: Float32Array;
  cols: number;
  rows: number;
  /** dB at the quiet and loud ends of the colour scale */
  lowDb: number;
  highDb: number;
  maxHz: number;
  duration: number;
}

const FFT_SIZE = 1024;

/** Mix all channels to mono. */
function mono(buffer: AudioBuffer): Float32Array {
  if (buffer.numberOfChannels === 1) return buffer.getChannelData(0);
  const out = new Float32Array(buffer.length);
  for (let c = 0; c < buffer.numberOfChannels; c++) {
    const ch = buffer.getChannelData(c);
    for (let i = 0; i < ch.length; i++) out[i] += ch[i] / buffer.numberOfChannels;
  }
  return out;
}

/** In-place radix-2 FFT on (re, im). Length must be a power of two. */
function fft(re: Float64Array, im: Float64Array): void {
  const n = re.length;
  for (let i = 1, j = 0; i < n; i++) {
    let bit = n >> 1;
    for (; j & bit; bit >>= 1) j ^= bit;
    j ^= bit;
    if (i < j) {
      [re[i], re[j]] = [re[j], re[i]];
      [im[i], im[j]] = [im[j], im[i]];
    }
  }
  for (let len = 2; len <= n; len <<= 1) {
    const ang = (-2 * Math.PI) / len;
    const wr = Math.cos(ang), wi = Math.sin(ang);
    for (let i = 0; i < n; i += len) {
      let cr = 1, ci = 0;
      for (let k = 0; k < len / 2; k++) {
        const a = i + k, b = a + len / 2;
        const tr = re[b] * cr - im[b] * ci;
        const ti = re[b] * ci + im[b] * cr;
        re[b] = re[a] - tr; im[b] = im[a] - ti;
        re[a] += tr; im[a] += ti;
        const ncr = cr * wr - ci * wi;
        ci = cr * wi + ci * wr;
        cr = ncr;
      }
    }
  }
}

/**
 * Compute the spectrogram of an audio buffer.
 * @param targetCols about how many time columns to produce (canvas width)
 * @param maxHz highest frequency to keep (pamflow's spec_max_hz, 12 kHz by default)
 */
export function computeSpectrogram(buffer: AudioBuffer, targetCols: number, maxHz: number): SpectrogramData {
  const samples = mono(buffer);
  const sr = buffer.sampleRate;
  const top = Math.min(maxHz, sr / 2);
  const rows = Math.max(1, Math.floor((top / sr) * FFT_SIZE));
  const hop = Math.max(32, Math.floor((samples.length - FFT_SIZE) / Math.max(1, targetCols)));
  const cols = Math.max(1, Math.floor((samples.length - FFT_SIZE) / hop) + 1);

  const window = new Float64Array(FFT_SIZE);
  for (let i = 0; i < FFT_SIZE; i++) window[i] = 0.5 - 0.5 * Math.cos((2 * Math.PI * i) / (FFT_SIZE - 1));

  const values = new Float32Array(cols * rows);
  const re = new Float64Array(FFT_SIZE);
  const im = new Float64Array(FFT_SIZE);
  for (let c = 0; c < cols; c++) {
    const start = c * hop;
    for (let i = 0; i < FFT_SIZE; i++) {
      re[i] = (samples[start + i] ?? 0) * window[i];
      im[i] = 0;
    }
    fft(re, im);
    for (let r = 0; r < rows; r++) {
      const power = re[r] * re[r] + im[r] * im[r];
      values[c * rows + r] = 10 * Math.log10(power + 1e-12);
    }
  }

  // Colour scale: from the typical background level to just under the loudest
  // sounds, so calls stand out whatever the recording level.
  const sample: number[] = [];
  const step = Math.max(1, Math.floor(values.length / 20000));
  for (let i = 0; i < values.length; i += step) sample.push(values[i]);
  sample.sort((a, b) => a - b);
  const pick = (q: number) => sample[Math.min(sample.length - 1, Math.floor(q * sample.length))];
  const lowDb = pick(0.55);
  const highDb = Math.max(lowDb + 20, pick(0.999));

  return { values, cols, rows, lowDb, highDb, maxHz: top, duration: buffer.duration };
}

/** "#rrggbb" or "rgb(r, g, b)" → [r, g, b] */
export function parseColour(css: string): [number, number, number] {
  const s = css.trim();
  if (s.startsWith('#')) {
    const hex = s.length === 4 ? s.slice(1).split('').map((c) => c + c).join('') : s.slice(1, 7);
    return [0, 2, 4].map((i) => parseInt(hex.slice(i, i + 2), 16)) as [number, number, number];
  }
  const m = s.match(/\d+(\.\d+)?/g);
  return m ? [Number(m[0]), Number(m[1]), Number(m[2])] : [0, 0, 0];
}

/**
 * Paint the spectrogram onto a canvas with a three-stop colour ramp:
 * quiet → background, middle → pastel tint, loud → pastel ink.
 */
export function paintSpectrogram(
  canvas: HTMLCanvasElement,
  data: SpectrogramData,
  colours: { quiet: string; middle: string; loud: string }
): void {
  canvas.width = data.cols;
  canvas.height = data.rows;
  const ctx = canvas.getContext('2d');
  if (!ctx) return;
  const img = ctx.createImageData(data.cols, data.rows);
  const q = parseColour(colours.quiet), m = parseColour(colours.middle), l = parseColour(colours.loud);
  const span = data.highDb - data.lowDb;
  for (let c = 0; c < data.cols; c++) {
    for (let r = 0; r < data.rows; r++) {
      let t = (data.values[c * data.rows + r] - data.lowDb) / span;
      t = t <= 0 ? 0 : t >= 1 ? 1 : Math.pow(t, 0.8);
      const [a, b, u] = t < 0.5 ? [q, m, t * 2] : [m, l, (t - 0.5) * 2];
      const y = data.rows - 1 - r; // low frequencies at the bottom
      const o = (y * data.cols + c) * 4;
      img.data[o] = a[0] + (b[0] - a[0]) * u;
      img.data[o + 1] = a[1] + (b[1] - a[1]) * u;
      img.data[o + 2] = a[2] + (b[2] - a[2]) * u;
      img.data[o + 3] = 255;
    }
  }
  ctx.putImageData(img, 0, 0);
}
