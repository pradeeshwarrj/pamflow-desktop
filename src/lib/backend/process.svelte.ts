/**
 * Step 5 · Process: run pamflow's cleaning (Stage 4) and hold its summary.
 */
import { runJob, type JobEvent } from './tauri';

export interface ProcessStep {
  rule: string;
  n_before: number;
  n_removed: number;
}

export interface SpeciesCount {
  scientific_name: string;
  common_name: string;
  events: number;
  max_confidence: number;
}

export interface ProcessSummary {
  available: boolean;
  out_dir: string;
  updated?: string;
  raw: number;
  removed: number;
  events: number;
  n_species: number;
  n_grids: number | null;
  steps: ProcessStep[];
  species: SpeciesCount[];
}

export const processJob = $state({
  status: 'idle' as 'idle' | 'loading' | 'running' | 'done' | 'failed',
  summary: null as ProcessSummary | null,
  message: '',
  log: [] as string[]
});

function absorb(events: JobEvent[]) {
  const summary = events.find((e) => e.type === 'processed');
  const finished = events.find((e) => e.type === 'finished');
  processJob.log = events
    .filter((e) => e.type === 'log' || e.type === 'text')
    .map((e) => String(e.text ?? ''));
  if (summary) processJob.summary = summary as unknown as ProcessSummary;
  if (finished?.status === 'ok') {
    processJob.status = 'done';
    processJob.message = '';
  } else {
    processJob.status = 'failed';
    processJob.message = String(finished?.message ?? 'The engine stopped unexpectedly.');
  }
}

/** Show the results of an earlier cleaning run, if there is one (fast). */
export async function loadProcessResults(project: string) {
  if (!project || processJob.status === 'running') return;
  processJob.status = 'loading';
  try {
    absorb(await runJob({ job: 'process_results', project }));
  } catch (e) {
    processJob.status = 'failed';
    processJob.message = String(e);
  }
}

/** Clean the detections with the rules in the project's config.yml. */
export async function runProcess(project: string) {
  processJob.status = 'running';
  processJob.message = '';
  try {
    absorb(await runJob({ job: 'process', project }));
  } catch (e) {
    processJob.status = 'failed';
    processJob.message = String(e);
  }
}
