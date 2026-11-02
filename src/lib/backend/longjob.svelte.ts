/**
 * Long-running pamflow jobs (Detect, Filter): start, follow, stop.
 *
 * The state lives here, not in a screen, so leaving a screen and coming back
 * keeps a running job's progress. Stop ends R and everything it started;
 * pamflow's checkpoints let the next start continue where it stopped.
 */
import { onJobEvent, startJob, stopJob, type JobEvent, type JobSpec } from './tauri';

export type JobStatus =
  | 'idle' | 'starting' | 'scanning' | 'running' | 'stopping'
  | 'stopped' | 'finished' | 'failed';

export interface FileRow {
  rel: string;
  ok: boolean;
  n_detections?: number;
  seconds?: number;
  message: string | null;
  time: string;
}

export interface LogLine {
  time: string;
  level: string;
  text: string;
}

export interface LongJobState {
  id: string;
  status: JobStatus;
  total: number | null;   // files to do in this run
  alreadyDone: number;    // finished in earlier runs (resume)
  done: number;
  failed: number;
  detections: number;
  batch: number;
  batches: number;
  runDir: string;
  startedAt: number;      // when the main work (not scanning) started, ms
  message: string;
  rows: FileRow[];        // newest first
  log: LogLine[];
  prepDone: number;       // files read while preparing (Standardize reads headers first)
  prepTotal: number;
}

const MAX_ROWS = 300;
const MAX_LOG = 500;
const now = () => new Date().toLocaleTimeString([], { hour12: false });

export const isActive = (s: JobStatus) =>
  s === 'starting' || s === 'scanning' || s === 'running' || s === 'stopping';

/** Stages after which the job counts as "running" (anything but scanning first). */
const MAIN_STAGES = new Set(['detect', 'filter', 'standardize']);
/** Stages shown as "preparing" before the main work starts. */
const PREP_STAGES = new Set(['scan', 'std_inspect']);

/** `onEvent` (optional) also sees every event of this job, e.g. to reload results when it ends. */
export function createLongJob(onEvent?: (e: JobEvent) => void) {
  const state = $state<LongJobState>({
    id: '', status: 'idle', total: null, alreadyDone: 0, done: 0, failed: 0, detections: 0,
    batch: 0, batches: 0, runDir: '', startedAt: 0, message: '', rows: [], log: [], prepDone: 0, prepTotal: 0
  });

  let listening = false;
  function listenOnce() {
    if (listening) return;
    listening = true;
    onJobEvent((id, event) => {
      if (id === state.id) handle(event);
    });
  }

  function addLog(level: string, text: string) {
    state.log.push({ time: now(), level, text });
    if (state.log.length > MAX_LOG) state.log.splice(0, state.log.length - MAX_LOG);
  }

  function handle(e: JobEvent) {
    try { onEvent?.(e); } catch { /* a screen's extra handling must not break progress */ }
    switch (e.type) {
      case 'stage':
        if (PREP_STAGES.has(String(e.stage))) state.status = 'scanning';
        if (MAIN_STAGES.has(String(e.stage))) {
          state.status = 'running';
          state.runDir = String(e.run_dir ?? '');
          state.alreadyDone = Number(e.already_done ?? 0);
          state.startedAt = Date.now();
        }
        break;
      case 'prep':
        state.prepDone = Number(e.done);
        state.prepTotal = Number(e.total);
        break;
      case 'total':
        state.total = Number(e.n);
        break;
      case 'files': {
        state.done = Number(e.done);
        state.failed = Number(e.failed);
        state.detections = Number(e.detections ?? 0);
        state.batch = Number(e.batch);
        state.batches = Number(e.batches);
        const rows = (Array.isArray(e.rows) ? e.rows : []) as Omit<FileRow, 'time'>[];
        const t = now();
        state.rows.unshift(...rows.map((r) => ({ ...r, time: t })).reverse());
        if (state.rows.length > MAX_ROWS) state.rows.length = MAX_ROWS;
        break;
      }
      case 'log':
        addLog(String(e.level ?? 'INFO'), String(e.text ?? ''));
        break;
      case 'text':
        addLog('OUT', String(e.text ?? ''));
        break;
      case 'stopping':
        state.status = 'stopping';
        break;
      case 'finished':
        state.status = e.status === 'ok' ? 'finished' : 'failed';
        state.message = String(e.message ?? '');
        break;
      case 'exit':
        if (e.stopped) state.status = 'stopped';
        else if (isActive(state.status)) {
          state.status = 'failed';
          state.message ||= `The analysis engine stopped unexpectedly (exit code ${e.code ?? 'unknown'}).`;
        }
        break;
    }
  }

  async function start(spec: JobSpec) {
    listenOnce();
    Object.assign(state, {
      status: 'starting', total: null, alreadyDone: 0, done: 0, failed: 0, detections: 0,
      batch: 0, batches: 0, runDir: '', startedAt: 0, message: '', rows: [], log: [], prepDone: 0, prepTotal: 0
    });
    try {
      state.id = await startJob(spec);
    } catch (e) {
      state.status = 'failed';
      state.message = String(e);
    }
  }

  async function stop() {
    if (!state.id || !isActive(state.status)) return;
    state.status = 'stopping';
    try {
      await stopJob(state.id);
    } catch (e) {
      state.message = String(e);
    }
  }

  /** Minutes left, from the average time per finished file so far. */
  function minutesLeft(): number | null {
    const finished = state.done + state.failed;
    if (!state.startedAt || !finished || state.total === null) return null;
    const perFile = (Date.now() - state.startedAt) / finished;
    return Math.max(0, Math.round(((state.total - finished) * perFile) / 60000));
  }

  function minutesElapsed(): number {
    return state.startedAt ? Math.round((Date.now() - state.startedAt) / 60000) : 0;
  }

  return { state, start, stop, minutesLeft, minutesElapsed };
}
