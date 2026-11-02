/**
 * The open pamflow project: its folder (remembered between sessions) and
 * what the engine found in it.
 */
import { inApp, runJob, type JobEvent } from './tauri';
import { processJob } from './process.svelte';
import { validation } from './validation.svelte';
import { occupancy } from './occupancy.svelte';
import { report } from './report.svelte';
import { scan } from './scan.svelte';
import { filterInfo } from './filter.svelte';
import { standardize } from './standardize.svelte';

const STORAGE_KEY = 'pamflow-project-folder';

/** One editable setting from config.yml (or pamflow's default if the file does not set it). */
export interface Setting {
  section: string;
  key: string;
  kind: 'folder' | 'file' | 'text' | 'number' | 'integer' | 'integer_or_null' | 'boolean' | 'choice';
  value: unknown;
  in_file: boolean;
}

export interface ProjectFacts {
  config: string;
  root: string;
  audio_folder: string;
  audio_folder_found: boolean;
  n_audio: number | null;
  audio_gb: number | null;
  filename_example: { file: string; grid: string | null; start: string | null; valid: boolean; sample_size: number } | null;
  n_unreadable_names: number | null;
  n_deployments: number | null;
  labels_found: boolean;
  n_labels: number | null;
  settings: Setting[];
  scanned: boolean;
  deployment_sheet: string;
  deployment_sheet_found: boolean;
  model_file: string | null;
  model_found: boolean;
  run_id: string;
  min_confidence: number;
  workers: number | null;
  cores_physical: number;
  cores_logical: number;
  detections_folder: string;
  processing: {
    min_confidence: number | null;
    drop_outside_deployment: boolean;
    merge_gap_s: number;
    max_overrun_s: number;
    thresholds_file: string | null;
    season_file: string | null;
    n_whitelist: number;
    n_blacklist: number;
    date_range: string[] | null;
  };
}

function savedFolder(): string {
  try {
    return localStorage.getItem(STORAGE_KEY) ?? '';
  } catch {
    return '';
  }
}

export const project = $state<{
  folder: string;
  facts: ProjectFacts | null;
  checking: boolean;
  error: string;
}>({ folder: savedFolder(), facts: null, checking: false, error: '' });

/** Open a project folder and ask the engine what is in it. */
export async function openProject(folder: string): Promise<void> {
  project.folder = folder;
  project.facts = null;
  project.error = '';
  processJob.summary = null; // results belong to the previous project
  validation.status = 'idle';
  validation.info = null;
  validation.metrics = null;
  occupancy.status = 'idle';
  occupancy.info = null;
  occupancy.model = null;
  report.preview = null;
  scan.status = 'idle';
  scan.summary = null;
  filterInfo.settings = null;
  standardize.state = null;
  try {
    localStorage.setItem(STORAGE_KEY, folder);
  } catch {
    /* not remembered; still works now */
  }
  await refreshProject();
}

export async function refreshProject(): Promise<void> {
  if (!inApp || !project.folder) return;
  project.checking = true;
  project.error = '';
  try {
    const events: JobEvent[] = await runJob({ job: 'inspect', project: project.folder });
    const facts = events.find((e) => e.type === 'project');
    const finished = events.find((e) => e.type === 'finished');
    if (facts) project.facts = facts as unknown as ProjectFacts;
    else project.error = String(finished?.message ?? 'The project could not be read.');
  } catch (e) {
    project.error = String(e);
  } finally {
    project.checking = false;
  }
}
