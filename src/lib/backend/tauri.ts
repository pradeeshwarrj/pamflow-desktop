/**
 * Talking to the Rust side. Every call to the analysis engine goes through
 * this file, so the screens never deal with Tauri directly.
 *
 * When the interface runs in a plain browser (`pnpm dev`), there is no Rust
 * side: `inApp` is false and screens show their demo data instead.
 */
import { invoke } from '@tauri-apps/api/core';
import { listen, type UnlistenFn } from '@tauri-apps/api/event';

export const inApp: boolean =
  typeof window !== 'undefined' && '__TAURI_INTERNALS__' in window;

export interface RuntimeInfo {
  found: boolean;
  prefix?: string;
  message?: string;
}

/** A progress event from a job (see bridge/protocol.R for the full list). */
export type JobEvent = { type: string; [field: string]: unknown };

export interface JobSpec {
  job:
    | 'inspect' | 'detect' | 'process' | 'process_results'
    | 'validation_state' | 'validation_draw' | 'validation_metrics'
    | 'occupancy_build' | 'occupancy_results' | 'model_input'
    | 'report_preview' | 'report' | 'config_save'
    | 'scan' | 'scan_results' | 'filter_info' | 'filter'
    | 'std_state' | 'std_plan' | 'standardize';
  project: string;
  birdnet?: Record<string, unknown>;
  sample_n?: number | null;
  strategy?: 'stratified' | 'random' | 'rare';
  n?: number;
  species?: string[];
  with_pool?: boolean;
  response?: 'detection' | 'counts';
  standardize?: boolean;
  formats?: string[];
  changes?: { section: string; key: string; value: unknown }[];
  filter?: Record<string, unknown>;
  std?: Record<string, unknown>;
  force?: boolean;
}

export function runtimeInfo(): Promise<RuntimeInfo> {
  return invoke<RuntimeInfo>('runtime_info');
}

export function startJob(spec: JobSpec): Promise<string> {
  return invoke<string>('start_job', { spec });
}

export function stopJob(id: string): Promise<void> {
  return invoke('stop_job', { id });
}

/** Receive every job's events; call the returned function to stop listening. */
export function onJobEvent(handler: (id: string, event: JobEvent) => void): Promise<UnlistenFn> {
  return listen<{ id: string; event: JobEvent }>('job-event', (msg) =>
    handler(msg.payload.id, msg.payload.event)
  );
}

/** Ask the user for a folder. Returns null if they cancel. */
export async function pickFolder(title: string): Promise<string | null> {
  const { open } = await import('@tauri-apps/plugin-dialog');
  const picked = await open({ directory: true, multiple: false, title });
  return typeof picked === 'string' ? picked : null;
}

/** Ask the user for a file. `extensions` like ['csv', 'xlsx']. Returns null if they cancel. */
export async function pickFile(title: string, name: string, extensions: string[]): Promise<string | null> {
  const { open } = await import('@tauri-apps/plugin-dialog');
  const picked = await open({ directory: false, multiple: false, title, filters: [{ name, extensions }] });
  return typeof picked === 'string' ? picked : null;
}

/** Free space (GB) on the drive holding `path` (or its nearest existing parent); null if unknown. */
export function freeSpace(path: string): Promise<number | null> {
  return invoke<number | null>('free_space_gb', { path });
}

/** Show a folder in Explorer / Finder. */
export async function showFolder(path: string): Promise<void> {
  const { revealItemInDir } = await import('@tauri-apps/plugin-opener');
  await revealItemInDir(path);
}

/** Open a report file (HTML, Excel, PDF) with the computer's default program. */
export async function openFile(path: string): Promise<void> {
  const { openPath } = await import('@tauri-apps/plugin-opener');
  await openPath(path);
}

/**
 * Run a job and collect its events until it ends. `onEvent` (optional)
 * sees each event as it arrives, e.g. to show which stage is running.
 */
export async function runJob(spec: JobSpec, onEvent?: (event: JobEvent) => void): Promise<JobEvent[]> {
  const events: JobEvent[] = [];
  let jobId: string | null = null;
  const early: { id: string; event: JobEvent }[] = [];
  return new Promise((resolve, reject) => {
    let unlisten: UnlistenFn | undefined;
    const take = (id: string, event: JobEvent) => {
      if (id !== jobId) return;
      events.push(event);
      onEvent?.(event);
      if (event.type === 'exit') {
        unlisten?.();
        resolve(events);
      }
    };
    onJobEvent((id, event) => (jobId === null ? early.push({ id, event }) : take(id, event)))
      .then((u) => {
        unlisten = u;
        return startJob(spec);
      })
      .then((id) => {
        jobId = id;
        early.splice(0).forEach((e) => take(e.id, e.event));
      })
      .catch((e) => {
        unlisten?.();
        reject(e);
      });
  });
}
