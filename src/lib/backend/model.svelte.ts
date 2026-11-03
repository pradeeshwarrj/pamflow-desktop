/**
 * BirdNET's own (global) model: is it downloaded, and downloading it.
 *
 * It is fetched once from Zenodo (bridge/download_model.py, run by the
 * analysis engine) into the app's models folder, shared by all projects. A
 * project then uses it by pointing model_dir / classifier_name / labels_file
 * of its settings at it (done on the Project screen).
 */
import { runJob, stopJob, failureMessage } from './tauri';

export interface ModelInfo {
  dir: string;
  downloaded: boolean;
  name: string;            // file name without .tflite: what classifier_name is set to
  model_file: string;
  labels_dir: string;
  languages: string[];     // species-list languages, e.g. "en_us", "de"
  n_species: number | null;
  version: string;
  size_mb: number | null;
  license: string;
}

export const model = $state({
  info: null as ModelInfo | null,
  loading: false,
  downloading: false,
  phase: '' as '' | 'download' | 'extract' | 'done',
  done: 0,
  total: 0,
  message: '',
  id: '',
  /** Set when a download has just finished; the Project screen then selects the model. */
  finished: 0
});

export async function loadModelInfo(project: string) {
  if (!project || model.loading) return;
  model.loading = true;
  try {
    const events = await runJob({ job: 'model_info', project });
    const info = events.find((e) => e.type === 'model_info');
    if (info) model.info = normalise(info);
  } finally {
    model.loading = false;
  }
}

function normalise(e: Record<string, unknown>): ModelInfo {
  return {
    ...(e as unknown as ModelInfo),
    languages: Array.isArray(e.languages) ? (e.languages as string[]) : []
  };
}

export async function downloadModel(project: string) {
  if (model.downloading) return;
  Object.assign(model, { downloading: true, phase: 'download', done: 0, total: 0, message: '', id: '' });
  try {
    const events = await runJob(
      { job: 'model_download', project },
      (e) => {
        if (e.type === 'download') {
          model.phase = e.phase as typeof model.phase;
          if (e.phase === 'download') {
            model.done = Number(e.done ?? 0);
            model.total = Number(e.total ?? 0);
          }
        }
      },
      (id) => (model.id = id)
    );
    const info = events.find((e) => e.type === 'model_info');
    const finished = events.find((e) => e.type === 'finished');
    const exit = events.find((e) => e.type === 'exit');
    if (info) model.info = normalise(info);
    if (finished?.status === 'ok' && model.info?.downloaded) model.finished++;
    else if (!exit?.stopped) model.message = failureMessage(events, 'The model could not be downloaded.');
  } catch (e) {
    model.message = String(e);
  } finally {
    model.downloading = false;
    model.phase = '';
    model.id = '';
  }
}

/** Cancel a running download; nothing is kept from it. */
export async function stopModelDownload() {
  if (model.id) await stopJob(model.id);
}
