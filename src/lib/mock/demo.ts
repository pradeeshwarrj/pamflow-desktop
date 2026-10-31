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
