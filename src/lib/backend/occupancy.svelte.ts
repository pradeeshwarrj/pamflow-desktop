/**
 * Step 7 · Occupancy: detection histories (pamflow Stage 6) and model input
 * for unmarked / spOccupancy / ubms (Stage 7). pamflow prepares the data;
 * models are fitted by the user in those packages.
 */
import { runJob, type JobEvent } from './tauri';

export interface OccupancySettings {
  run_id: string;
  config_run_id: string | null;
  occasion_length_days: number;
  min_effort_hours: number;
  min_detections: number;
  min_confidence: number;
  thresholds_file: string | null;
}

export interface SpeciesSummary {
  species: string;
  threshold_used: number;
  n_sites: number;
  n_occasions: number;
  n_sites_detected: number;
  naive_occupancy: number;
}

/** One species' history: rows[i] has one character per occasion: "1", "0" or "." (not surveyed). */
export interface History {
  species: string;
  sites: string[];
  occasions: string[];
  rows: string[];
}

export interface OccupancyInfo {
  available: boolean;
  dir: string;
  updated?: string;
  settings: OccupancySettings;
  summary?: SpeciesSummary[];
  histories?: History[];
  site_covariates?: string[];
}

export interface ModelInput {
  dir: string;
  binary: boolean;
  standardize: boolean;
  dims: number[];
  layout: string[];
  n_sites: number;
  site_covariates: string[] | string;
  obs_covariates: string[] | string;
  checks: { check: string; passed: boolean; detail: string }[];
  files: string[] | string;
}

export const occupancy = $state({
  status: 'idle' as 'idle' | 'loading' | 'building' | 'ready' | 'failed',
  info: null as OccupancyInfo | null,
  message: '',
  log: [] as string[],
  selected: '' as string,
  modelStatus: 'idle' as 'idle' | 'running' | 'failed',
  model: null as ModelInput | null,
  modelMessage: ''
});

const asList = (x: string[] | string | undefined) => (Array.isArray(x) ? x : x ? [x] : []);
export { asList };

function absorb(events: JobEvent[], building: boolean) {
  const info = events.find((e) => e.type === 'occupancy') as unknown as OccupancyInfo | undefined;
  const finished = events.find((e) => e.type === 'finished');
  occupancy.log = events.filter((e) => e.type === 'log' || e.type === 'text').map((e) => String(e.text ?? ''));
  if (info) {
    occupancy.info = info;
    const names = (info.histories ?? []).map((h) => h.species);
    if (!names.includes(occupancy.selected)) occupancy.selected = names[0] ?? '';
  }
  if (finished?.status === 'ok') {
    occupancy.status = 'ready';
    occupancy.message = '';
  } else {
    occupancy.status = info ? 'ready' : 'failed';
    occupancy.message = String(finished?.message ?? (building ? 'Building failed.' : 'Could not read the results.'));
  }
}

export async function loadOccupancy(project: string) {
  if (!project) return;
  occupancy.status = 'loading';
  try {
    absorb(await runJob({ job: 'occupancy_results', project }), false);
  } catch (e) {
    occupancy.status = 'failed';
    occupancy.message = String(e);
  }
}

export async function buildOccupancy(project: string) {
  occupancy.status = 'building';
  occupancy.message = '';
  occupancy.model = null;
  try {
    absorb(await runJob({ job: 'occupancy_build', project }), true);
  } catch (e) {
    occupancy.status = 'failed';
    occupancy.message = String(e);
  }
}

export async function prepareModelInput(project: string, response: 'detection' | 'counts', standardize: boolean) {
  occupancy.modelStatus = 'running';
  occupancy.modelMessage = '';
  try {
    const events = await runJob({ job: 'model_input', project, response, standardize });
    const m = events.find((e) => e.type === 'model_input');
    const finished = events.find((e) => e.type === 'finished');
    if (m && finished?.status === 'ok') {
      occupancy.model = m as unknown as ModelInput;
      occupancy.modelStatus = 'idle';
    } else {
      occupancy.modelStatus = 'failed';
      occupancy.modelMessage = String(finished?.message ?? 'Preparing the model input failed.');
    }
  } catch (e) {
    occupancy.modelStatus = 'failed';
    occupancy.modelMessage = String(e);
  }
}
