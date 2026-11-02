/**
 * DEMO DATA — shown on screen until the app is connected to R (Phase 1–2).
 *
 * Numbers come from the G_1180 pilot run. Every screen imports its
 * numbers from here, so replacing this file with real calls to pamflow
 * is the only change needed to make the screens live.
 */

/** Sidebar status for each step: finished, or a short progress note. */
export const stageStatus: Record<string, { done?: boolean; note?: string }> = {
  project: { done: true },
  scan: { done: true },
  filter: { done: true },
  detect: { note: '65%' },
  process: {},
  validate: { note: '24/120' },
  occupancy: {},
  report: {}
};

export const project = {
  name: 'pamflow_pilot',
  recordings: 6000,
  sizeLabel: '1.3 TB',
  deployments: 89,
  recordingsFolder: 'E:/Pradeeshwar/pamflow_pilot/standardized',
  pattern: '{site}_{YYYYMMDD}_{HHMMSS}',
  exampleFile: 'G0059_20260405_182425.wav',
  exampleParts: ['site G0059', '5 Apr 2026', '18:24:25'],
  sheetFile: 'deployments.xlsx',
  modelFile: 'BirdNet_v2_custom.tflite',
  cores: 24,
  workerChoices: [2, 4, 8, 12],
  defaultWorkers: 4,
  minConfidence: 0.3
};

export const detect = {
  grid: 'G_1180',
  done: 41,
  total: 63,
  minutesLeft: 19,
  minutesElapsed: 35,
  workers: 4,
  detections: 1114,
  minConfidence: 0.3,
  skipped: 1,
  log: [
    { time: '11:42:08', file: 'G1180_20260407_051226.wav', note: '38 detections', kind: 'ok' },
    { time: '11:41:16', file: 'G1180_20260407_041225.wav', note: '21 detections', kind: 'ok' },
    { time: '11:40:31', file: 'G1180_20260407_031224.wav', note: 'skipped · unreadable header', kind: 'warn' },
    { time: '11:39:47', file: 'G1180_20260407_021223.wav', note: '4 detections', kind: 'ok' },
    { time: '11:38:55', file: 'G1180_20260407_011222.wav', note: 'no detections', kind: 'none' }
  ] as { time: string; file: string; note: string; kind: 'ok' | 'warn' | 'none' }[]
};

export const validate = {
  species: 'Black-naped Monarch',
  confidence: 0.87,
  site: 'G1180',
  recorded: '7 Apr 2026, 05:24',
  clip: '12:06 – 12:09',
  clipSeconds: 3,
  checked: 24,
  total: 120,
  correct: 19,
  wrong: 4,
  unsure: 1
};

export const report = {
  grid: 'G_1180',
  subtitle: 'Grid G_1180 · 63 recordings · pilot run',
  recordings: 63,
  rawDetections: 1712,
  eventsKept: 88,
  precision: 0.83,
  funnel: [
    { label: 'All BirdNET detections', value: 1712 },
    { label: 'Inside deployment dates', value: 1470 },
    { label: 'Confidence 0.5 and above', value: 88 }
  ],
  species: [
    { name: 'Black-naped Monarch', n: 83 },
    { name: 'Other species', n: 5 }
  ]
};

/** Process step demo: the G_1180 pilot (1,712 raw detections -> 88 events). */
export const processSummary = {
  available: true,
  out_dir: '',
  updated: '',
  raw: 1712,
  removed: 1624,
  events: 88,
  n_species: 2,
  n_grids: 1,
  steps: [
    { rule: 'invalid confidence or timestamps', n_before: 1712, n_removed: 0 },
    { rule: 'file not in master table', n_before: 1712, n_removed: 0 },
    { rule: 'beyond end of recording', n_before: 1712, n_removed: 0 },
    { rule: 'outside deployment window', n_before: 1712, n_removed: 242 },
    { rule: 'below confidence threshold', n_before: 1470, n_removed: 1382 },
    { rule: 'merged overlapping windows into events (not removed)', n_before: 88, n_removed: 0 }
  ],
  species: [
    { scientific_name: 'Hypothymis azurea', common_name: 'Black-naped Monarch', events: 83, max_confidence: 0.97 },
    { scientific_name: '', common_name: 'Other species', events: 5, max_confidence: 0.8 }
  ]
};

/** Occupancy demo: an illustrative history (not real results). */
const demoSites = ['G0059', 'G0110', 'G0263', 'G1180', 'G1204', 'G1310'];
const demoDates = Array.from({ length: 21 }, (_, i) => `2026-04-${String(4 + i).padStart(2, '0')}`);
const pattern = (seed: number) =>
  demoSites.map((_, s) => demoDates.map((_, d) => ((s * 7 + d * 3 + seed) % 11 === 0 ? '.' : (s + d + seed) % 4 === 0 ? '1' : '0')).join(''));
export const occupancyInfo = {
  available: true,
  dir: '',
  updated: '',
  settings: { run_id: 'run01', config_run_id: 'run01', occasion_length_days: 1, min_effort_hours: 2, min_detections: 10, min_confidence: 0.4, thresholds_file: null },
  summary: [
    { species: 'Otus alius_Nicobar Scops-Owl', threshold_used: 0.4, n_sites: 6, n_occasions: 21, n_sites_detected: 5, naive_occupancy: 0.833 },
    { species: 'Ducula nicobarica_Nicobar Imperial-Pigeon', threshold_used: 0.4, n_sites: 6, n_occasions: 21, n_sites_detected: 3, naive_occupancy: 0.5 }
  ],
  histories: [
    { species: 'Otus alius_Nicobar Scops-Owl', sites: demoSites, occasions: demoDates, rows: pattern(1) },
    { species: 'Ducula nicobarica_Nicobar Imperial-Pigeon', sites: demoSites, occasions: demoDates, rows: pattern(2) }
  ]
};
