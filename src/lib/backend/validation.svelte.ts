/**
 * Validate step: samples to review, answers, drawing new rounds and
 * precision. Files are pamflow's own (detections/<run>/validation/), so
 * reviewing here or in pamflow's Shiny app gives the same results.
 */
import { invoke, convertFileSrc } from '@tauri-apps/api/core';
import { runJob } from './tauri';

export type Verdict = 'correct' | 'incorrect' | 'unsure';

export interface Sample {
  sample_id: number;
  round: number;
  strategy: string;
  species: string;
  scientific_name: string;
  common_name: string;
  confidence: number;
  band: string;
  grid: string;
  recorder?: string;
  detection_datetime: string;
  filename?: string;
  clip_file: string;
  spec_file: string;
  clip_dur_s: number;
  event_offset_s: number;
  event_end_offset_s: number;
}

export interface Answer {
  sample_id: number;
  verdict: Verdict;
  true_species: string;
  note: string;
  reviewer: string;
  reviewed_at: string;
}

export interface ValidationInfo {
  available: boolean;
  n_samples: number;
  n_ready: number;
  rounds?: number;
  samples: Sample[];
  results: Answer[];
  labels: string[];
  val_dir: string;
  clips_dir: string;
  specs_dir: string;
  results_path: string;
  show_confidence: boolean;
  reviewer: string;
  spec_max_hz?: number;
  pool: { n_events: number; species: { scientific_name: string; common_name: string; N: number }[] } | null;
}

export interface SpeciesPrecision {
  scientific_name: string;
  n_pool: number;
  n_reviewed: number;
  n_correct: number;
  n_incorrect: number;
  n_unsure: number;
  precision: number | null;
  ci_low: number | null;
  ci_high: number | null;
}

const REVIEWER_KEY = 'pamflow-reviewer';

export const validation = $state({
  status: 'idle' as 'idle' | 'loading' | 'ready' | 'drawing' | 'failed',
  info: null as ValidationInfo | null,
  answers: {} as Record<number, Answer>,
  pos: 0,
  message: '',
  drawLabel: '',
  saveError: '',
  reviewer: (() => { try { return localStorage.getItem(REVIEWER_KEY) ?? ''; } catch { return ''; } })(),
  metrics: null as SpeciesPrecision[] | null,
  metricsStatus: 'idle' as 'idle' | 'loading' | 'failed',
  metricsDir: ''
});

export const clipUrl = (s: Sample) => convertFileSrc(`${validation.info?.clips_dir}/${s.clip_file}`);
export const specUrl = (s: Sample) => convertFileSrc(`${validation.info?.specs_dir}/${s.spec_file}`);

/** The species part of a BirdNET label "Scientific name_Common name". */
export function commonOf(label: string): string {
  const i = label.indexOf('_');
  return i >= 0 ? label.slice(i + 1) : label;
}

async function absorbState(info: ValidationInfo) {
  validation.info = info;
  validation.answers = Object.fromEntries((info.results ?? []).map((a) => [a.sample_id, {
    ...a, true_species: a.true_species ?? '', note: a.note ?? '', reviewer: a.reviewer ?? ''
  }]));
  if (!validation.reviewer && info.reviewer) validation.reviewer = info.reviewer;
  if (info.available) {
    try {
      await invoke('allow_media_folder', { folder: info.val_dir });
    } catch (e) {
      validation.message = String(e);
    }
  }
  // Start at the first sample without an answer, like pamflow's app.
  const first = info.samples.findIndex((s) => !validation.answers[s.sample_id]);
  validation.pos = first >= 0 ? first : 0;
}

export async function loadValidation(project: string) {
  if (!project) return;
  validation.status = 'loading';
  validation.message = '';
  try {
    const events = await runJob({ job: 'validation_state', project, with_pool: true });
    const info = events.find((e) => e.type === 'validation');
    const finished = events.find((e) => e.type === 'finished');
    if (info) {
      await absorbState(info as unknown as ValidationInfo);
      validation.status = 'ready';
    } else {
      validation.status = 'failed';
      validation.message = String(finished?.message ?? 'Could not read the validation files.');
    }
  } catch (e) {
    validation.status = 'failed';
    validation.message = String(e);
  }
}

/** Draw a new round of events and make their clips and spectrograms. */
export async function drawRound(project: string, strategy: 'stratified' | 'random' | 'rare', n: number) {
  validation.status = 'drawing';
  validation.drawLabel = '';
  validation.message = '';
  try {
    const events = await runJob({ job: 'validation_draw', project, strategy, n }, (e) => {
      if (e.type === 'stage') validation.drawLabel = String(e.label ?? '');
    });
    const info = events.find((e) => e.type === 'validation');
    const finished = events.find((e) => e.type === 'finished');
    if (info) {
      await absorbState(info as unknown as ValidationInfo);
      validation.metrics = null;
    }
    validation.status = info ? 'ready' : 'failed';
    if (finished?.status !== 'ok') validation.message = String(finished?.message ?? 'Drawing events failed.');
  } catch (e) {
    validation.status = 'failed';
    validation.message = String(e);
  }
}

function timestamp(): string {
  const d = new Date();
  const p = (n: number) => String(n).padStart(2, '0');
  return `${d.getFullYear()}-${p(d.getMonth() + 1)}-${p(d.getDate())} ${p(d.getHours())}:${p(d.getMinutes())}:${p(d.getSeconds())}`;
}

export function setReviewer(name: string) {
  validation.reviewer = name;
  try { localStorage.setItem(REVIEWER_KEY, name); } catch { /* not remembered */ }
}

/** Save an answer for the current sample (saved to disk at once). */
export async function saveAnswer(sample: Sample, verdict: Verdict, trueSpecies = '', note?: string) {
  const answer: Answer = {
    sample_id: sample.sample_id,
    verdict,
    true_species: verdict === 'incorrect' ? trueSpecies : '',
    note: note ?? validation.answers[sample.sample_id]?.note ?? '',
    reviewer: validation.reviewer,
    reviewed_at: timestamp()
  };
  validation.saveError = '';
  try {
    await invoke('save_validation_answer', { resultsPath: validation.info!.results_path, answer });
    validation.answers[sample.sample_id] = answer;
    validation.metrics = null; // precision is out of date now
  } catch (e) {
    validation.saveError = String(e);
    throw e;
  }
}

/** Move to the next sample without an answer (wrapping around), or stay. */
export function nextOpen() {
  const samples = validation.info?.samples ?? [];
  const open = samples.map((s, i) => (validation.answers[s.sample_id] ? -1 : i)).filter((i) => i >= 0);
  const later = open.find((i) => i > validation.pos);
  validation.pos = later ?? open[0] ?? validation.pos;
}

export async function loadMetrics(project: string) {
  validation.metricsStatus = 'loading';
  try {
    const events = await runJob({ job: 'validation_metrics', project });
    const m = events.find((e) => e.type === 'metrics');
    if (m) {
      validation.metrics = m.species as SpeciesPrecision[];
      validation.metricsDir = String(m.out_dir ?? '');
      validation.metricsStatus = 'idle';
    } else {
      validation.metricsStatus = 'failed';
    }
  } catch {
    validation.metricsStatus = 'failed';
  }
}
