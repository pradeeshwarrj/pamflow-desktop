/**
 * The open pamflow project: its folder (remembered between sessions) and
 * what the engine found in it.
 */
import { inApp, runJob, jobContext, type JobEvent, failureMessage } from './tauri';
import { processJob } from './process.svelte';
import { validation } from './validation.svelte';
import { occupancy } from './occupancy.svelte';
import { report } from './report.svelte';
import { scan } from './scan.svelte';
import { filterInfo } from './filter.svelte';
import { standardize } from './standardize.svelte';
import { notePamflowVersion } from './appinfo.svelte';

const STORAGE_KEY = 'pamflow-project-folder';
const CONFIG_KEY = 'pamflow-project-config';

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

function saved(key: string): string {
  try {
    return localStorage.getItem(key) ?? '';
  } catch {
    return '';
  }
}

function remember(key: string, value: string) {
  try {
    localStorage.setItem(key, value);
  } catch {
    /* not remembered; still works now */
  }
}

/** A folder that has no settings file (or whose settings file has gone). */
export interface NoConfig {
  folder: string;
  exists: boolean;
  suggested: string;
  missingFile: string | null;
}

export const project = $state<{
  folder: string;          // what the user opened: a project folder (or a settings file, until it is read)
  config: string;          // the settings file in use, wherever it is
  facts: ProjectFacts | null;
  checking: boolean;
  error: string;
  noConfig: NoConfig | null;
  created: string;         // settings file just made from the defaults (shown once)
  example: boolean;        // the open project is pamflow's example project, just made
}>({ folder: saved(STORAGE_KEY), config: saved(CONFIG_KEY), facts: null, checking: false, error: '', noConfig: null, created: '', example: false });
jobContext.config = project.config;

/** Forget everything shown for the previous project. */
function resetProjectState() {
  project.facts = null;
  project.error = '';
  project.noConfig = null;
  project.created = '';
  project.example = false;
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
}

function setConfig(path: string) {
  project.config = path;
  jobContext.config = path;
  remember(CONFIG_KEY, path);
}

const isYaml = (p: string) => /\.ya?ml$/i.test(p);

/** Use what the engine reported: the project, or that it has no settings file. */
export function applyInspect(events: JobEvent[], fallback = 'The project could not be read.') {
  notePamflowVersion(events);
  const facts = events.find((e) => e.type === 'project');
  const none = events.find((e) => e.type === 'no_config');
  if (facts) {
    project.facts = facts as unknown as ProjectFacts;
    project.noConfig = null;
    setConfig(project.facts.config);
    if (isYaml(project.folder)) project.folder = project.facts.root; // opened by file: the folder is its project
    remember(STORAGE_KEY, project.folder);
  } else if (none) {
    project.facts = null;
    project.noConfig = {
      folder: String(none.folder ?? project.folder),
      exists: none.exists === true,
      suggested: String(none.suggested ?? ''),
      missingFile: none.missing_file ? String(none.missing_file) : null
    };
  } else {
    project.error = failureMessage(events, fallback);
  }
}

/** Open a project folder and ask the engine what is in it. */
export async function openProject(folder: string): Promise<void> {
  project.folder = folder;
  resetProjectState();
  setConfig('');
  remember(STORAGE_KEY, folder);
  await refreshProject();
}

/** Open a settings file kept anywhere; its project is the folder it points to. */
export async function openConfigFile(path: string): Promise<void> {
  project.folder = path;
  resetProjectState();
  setConfig('');
  await refreshProject();
}

/**
 * Start a new project: write pamflow's default settings for it (to
 * <folder>/config/config.yml, or to `target`), then open it. Never replaces
 * an existing settings file.
 */
export async function createProject(folder: string, target?: string): Promise<void> {
  project.folder = folder;
  resetProjectState();
  setConfig('');
  project.checking = true;
  try {
    const events = await runJob({ job: 'project_create', project: folder, target });
    const made = events.find((e) => e.type === 'project_created');
    applyInspect(events, 'The new project could not be created.');
    if (made && project.facts) project.created = String(made.config ?? '');
  } catch (e) {
    project.error = String(e);
  } finally {
    project.checking = false;
  }
}

/** Make pamflow's small example project in the Documents folder and open it. */
export async function createExample(): Promise<void> {
  resetProjectState();
  setConfig('');
  project.folder = '';
  project.checking = true;
  try {
    const events = await runJob({ job: 'example_project', project: '' });
    const made = events.find((e) => e.type === 'example_created');
    if (made) project.folder = String(made.root);
    applyInspect(events, 'The example project could not be made.');
    if (made && project.facts) project.example = true;
  } catch (e) {
    project.error = String(e);
  } finally {
    project.checking = false;
  }
}

export async function refreshProject(): Promise<void> {
  if (!inApp || !project.folder) return;
  project.checking = true;
  project.error = '';
  try {
    applyInspect(await runJob({ job: 'inspect', project: project.folder }));
  } catch (e) {
    project.error = String(e);
  } finally {
    project.checking = false;
  }
}
