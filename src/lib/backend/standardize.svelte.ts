/**
 * Standardize step: Raven Compass-style triage of the raw recordings
 * (pamflow Stage 00, pam_standardize).
 *
 *  - `checkRaw`         dry run: reads every raw file and plans what happens to it
 *  - `startStandardize` the real run (copies / converts; raw files are never changed)
 * The settings come from config.yml (section `standardization`, paths
 * `audio_raw`, `audio_standardized`, `audio_isolated`).
 */
import { createLongJob } from './longjob.svelte';
import { runJob, type JobEvent, failureMessage } from './tauri';

export interface StdSettings {
  raw_dir: string;
  standardized_dir: string;
  isolated_dir: string;
  target_format: 'flac' | 'wav';
  target_hz: number;
  channels: number;
  min_duration_s: number;
  organize_folders: string;
  rename_strategy: 'auto' | 'keep';
  prefix: string;
  isolate_non_audio: boolean;
  isolate_short: boolean;
  timezone: string;
}

export interface StdSummary {
  available: boolean;
  kind: 'plan' | 'run';
  updated?: string;
  n_files?: number;
  n_recordings?: number;
  n_memos?: number;
  n_non_audio?: number;
  n_corrupt?: number;
  n_convert?: number;
  n_copy?: number;
  n_failed?: number;
  raw_gb?: number;
  per_grid?: { grid: string; files: number }[];
  examples?: { from: string; to: string }[];
  problems?: { file: string; category: string; action: string; message: string }[];
}

export interface StdState {
  settings: StdSettings;
  raw_found: boolean;
  n_raw_files: number | null;
  problems: string[];
  plan: StdSummary;
  last_run: StdSummary;
}

export const standardize = $state({
  state: null as StdState | null,
  loading: false,
  checking: false,
  prepDone: 0,
  prepTotal: 0,
  message: '',
  log: [] as string[]
});

const takeState = (events: JobEvent[]) => {
  const s = events.find((e) => e.type === 'std_state');
  if (s) standardize.state = s as unknown as StdState;
};

const run = createLongJob((e) => {
  if (e.type === 'std_state') standardize.state = e as unknown as StdState;
});
export const stdJob = run.state;
export const stopStandardize = run.stop;
export const stdMinutesLeft = run.minutesLeft;
export const stdMinutesElapsed = run.minutesElapsed;

export async function loadStdState(project: string) {
  if (!project) return;
  standardize.loading = true;
  try {
    takeState(await runJob({ job: 'std_state', project }));
  } finally {
    standardize.loading = false;
  }
}

/** Dry run: plan every raw file; nothing but the plan table is written. */
export async function checkRaw(project: string) {
  Object.assign(standardize, { checking: true, prepDone: 0, prepTotal: 0, message: '', log: [] });
  try {
    const events = await runJob({ job: 'std_plan', project }, (e) => {
      if (e.type === 'prep') {
        standardize.prepDone = Number(e.done);
        standardize.prepTotal = Number(e.total);
      }
      if (e.type === 'log' || e.type === 'text') standardize.log.push(String(e.text ?? ''));
    });
    takeState(events);
    const finished = events.find((e) => e.type === 'finished');
    if (finished?.status !== 'ok') standardize.message = failureMessage(events, 'Checking failed.');
  } catch (e) {
    standardize.message = String(e);
  } finally {
    standardize.checking = false;
  }
}

export function startStandardize(project: string) {
  return run.start({ job: 'standardize', project });
}
