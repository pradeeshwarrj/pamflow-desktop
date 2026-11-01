/**
 * The Detect job: start, stop, and everything the screen shows while it runs.
 * The state lives here (not in the screen), so leaving the Detect screen and
 * coming back does not lose a running job's progress.
 */
import { onJobEvent, startJob, stopJob, type JobEvent } from './tauri';

export type DetectStatus =
  | 'idle' | 'starting' | 'scanning' | 'running' | 'stopping'
  | 'stopped' | 'finished' | 'failed';

export interface FileRow {
  rel: string;
  ok: boolean;
  n_detections: number;
  seconds: number;
  message: string | null;
  time: string;
}

export interface LogLine {
  time: string;
  level: string;
  text: string;
}

const MAX_ROWS = 300;
const MAX_LOG = 500;

export const detectJob = $state({
  id: '' as string,
  status: 'idle' as DetectStatus,
  total: null as number | null,     // files to do in this run
  alreadyDone: 0,                   // finished in earlier runs (resume)
  done: 0,
  failed: 0,
  detections: 0,
  batch: 0,
  batches: 0,
  runDir: '',
  startedAt: 0,                     // when detection (not scanning) started, ms
  message: '',
  rows: [] as FileRow[],            // newest first
  log: [] as LogLine[]
});

const now = () => new Date().toLocaleTimeString([], { hour12: false });

export const isActive = (s: DetectStatus) =>
  s === 'starting' || s === 'scanning' || s === 'running' || s === 'stopping';

/** Minutes left, from the average time per finished file so far. */
export function minutesLeft(): number | null {
  const finished = detectJob.done + detectJob.failed;
  if (!detectJob.startedAt || !finished || detectJob.total === null) return null;
  const perFile = (Date.now() - detectJob.startedAt) / finished;
  return Math.max(0, Math.round(((detectJob.total - finished) * perFile) / 60000));
}

export function minutesElapsed(): number {
  return detectJob.startedAt ? Math.round((Date.now() - detectJob.startedAt) / 60000) : 0;
}

let listening = false;
function listenOnce() {
  if (listening) return;
  listening = true;
  onJobEvent((id, event) => {
    if (id === detectJob.id) handle(event);
  });
}

export async function startDetect(project: string, settings: { workers: number; sampleN: number | null }) {
  listenOnce();
  Object.assign(detectJob, {
    status: 'starting', total: null, alreadyDone: 0, done: 0, failed: 0, detections: 0,
    batch: 0, batches: 0, runDir: '', startedAt: 0, message: '', rows: [], log: []
  });
  // Small batches so progress (and the resume point) update often.
  const chunk = Math.min(50, Math.max(4, settings.workers * 2));
  try {
    detectJob.id = await startJob({
      job: 'detect',
      project,
      birdnet: { workers: settings.workers, chunk_size: chunk },
      sample_n: settings.sampleN
    });
  } catch (e) {
    detectJob.status = 'failed';
    detectJob.message = String(e);
  }
}

export async function stopDetect() {
  if (!detectJob.id || !isActive(detectJob.status)) return;
  detectJob.status = 'stopping';
  try {
    await stopJob(detectJob.id);
  } catch (e) {
    detectJob.message = String(e);
  }
}

function addLog(level: string, text: string) {
  detectJob.log.push({ time: now(), level, text });
  if (detectJob.log.length > MAX_LOG) detectJob.log.splice(0, detectJob.log.length - MAX_LOG);
}

function handle(e: JobEvent) {
  switch (e.type) {
    case 'stage':
      if (e.stage === 'scan') detectJob.status = 'scanning';
      if (e.stage === 'detect') {
        detectJob.status = 'running';
        detectJob.runDir = String(e.run_dir ?? '');
        detectJob.alreadyDone = Number(e.already_done ?? 0);
        detectJob.startedAt = Date.now();
      }
      break;
    case 'total':
      detectJob.total = Number(e.n);
      break;
    case 'files': {
      detectJob.done = Number(e.done);
      detectJob.failed = Number(e.failed);
      detectJob.detections = Number(e.detections);
      detectJob.batch = Number(e.batch);
      detectJob.batches = Number(e.batches);
      const rows = (Array.isArray(e.rows) ? e.rows : []) as Omit<FileRow, 'time'>[];
      const t = now();
      detectJob.rows.unshift(...rows.map((r) => ({ ...r, time: t })).reverse());
      if (detectJob.rows.length > MAX_ROWS) detectJob.rows.length = MAX_ROWS;
      break;
    }
    case 'log':
      addLog(String(e.level ?? 'INFO'), String(e.text ?? ''));
      break;
    case 'text':
      addLog('OUT', String(e.text ?? ''));
      break;
    case 'stopping':
      detectJob.status = 'stopping';
      break;
    case 'finished':
      detectJob.status = e.status === 'ok' ? 'finished' : 'failed';
      detectJob.message = String(e.message ?? '');
      break;
    case 'exit':
      if (e.stopped) detectJob.status = 'stopped';
      else if (isActive(detectJob.status)) {
        detectJob.status = 'failed';
        detectJob.message ||= `The analysis engine stopped unexpectedly (exit code ${e.code ?? 'unknown'}).`;
      }
      break;
  }
}
