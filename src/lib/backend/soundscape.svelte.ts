/**
 * Soundscape step: acoustic indices per site and day/night (pamflow Stage 2b).
 * Computing is a long job (progress by batch, Stop; a stopped run continues
 * where it stopped); reading results and making plots are short jobs.
 */
import { invoke, convertFileSrc } from '@tauri-apps/api/core';
import { runJob, failureMessage, type JobEvent } from './tauri';
import { createLongJob } from './longjob.svelte';

export interface SoundscapeInfo {
  available: boolean;
  dir: string;
  updated?: string;
  n_sites?: number;
  settings: { window_mins: number | null; low_stop_hz: number | null; day_hours: number[] | number; indices: string[] | string | null };
  /** One row per site and phase; the other columns are "<index>_mean". */
  diel?: Record<string, string | number | null>[];
  files?: string[] | string;
  has_raw?: boolean;
  n_files?: number;
  plots_dir?: string;
  plots?: string[] | string;
  report?: string;
}

export const soundscape = $state({
  status: 'idle' as 'idle' | 'loading' | 'running' | 'ready' | 'failed',
  info: null as SoundscapeInfo | null,
  message: '',
  log: [] as string[]
});

export const asList = <T,>(x: T[] | T | null | undefined): T[] => (Array.isArray(x) ? x : x == null ? [] : [x]);

const compute = createLongJob((e: JobEvent) => {
  if (e.type === 'soundscape') soundscape.info = e as unknown as SoundscapeInfo; // the finished results
});
export const soundscapeJob = compute.state;
export const stopSoundscape = compute.stop;
export const soundscapeMinutesLeft = compute.minutesLeft;
export const soundscapeMinutesElapsed = compute.minutesElapsed;
export const runSoundscape = (project: string) => compute.start({ job: 'soundscape', project });

async function load(project: string, job: 'soundscape_results' | 'soundscape_vis') {
  const running = job !== 'soundscape_results';
  soundscape.status = running ? 'running' : 'loading';
  soundscape.message = '';
  try {
    const events = await runJob({ job, project });
    const info = events.find((e) => e.type === 'soundscape') as unknown as SoundscapeInfo | undefined;
    const ok = events.find((e) => e.type === 'finished')?.status === 'ok';
    soundscape.log = events.filter((e) => e.type === 'log').map((e) => String(e.text ?? ''));
    if (info) { soundscape.info = info; await allowPlots(info); }
    soundscape.status = ok || info ? 'ready' : 'failed';
    if (!ok) soundscape.message = failureMessage(events, job === 'soundscape_vis' ? 'Making the plots failed.' : 'Could not read the results.');
  } catch (e) {
    soundscape.status = 'failed';
    soundscape.message = String(e);
  }
}

/** Let the window show the plot pictures. */
async function allowPlots(info: SoundscapeInfo) {
  if (!info.plots_dir) return;
  try {
    await invoke('allow_media_folder', { folder: info.plots_dir });
  } catch (e) {
    soundscape.message = String(e);
  }
}
/** Plot pictures: name (without .png) and address the window can show. */
export const plotUrl = (info: SoundscapeInfo, file: string) => convertFileSrc(`${info.plots_dir}/${file}`);

export const loadSoundscape = (project: string) => project && load(project, 'soundscape_results');

let shownFor = '';
/**
 * Call from an $effect on the Soundscape screens: reads the results again when the
 * project or its run name changes, so a screen never shows another run's results.
 */
export function syncSoundscape(folder: string, runName: string) {
  const key = `${folder}|${runName}`;
  if (!folder || key === shownFor) return;
  shownFor = key;
  if (compute.state.status === 'starting' || compute.state.status === 'running') return; // its own results arrive at the end
  soundscape.info = null;
  loadSoundscape(folder);
}
export const runSoundscapeVis = (project: string) => load(project, 'soundscape_vis');
