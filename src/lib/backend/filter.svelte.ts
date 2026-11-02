/**
 * Filter step: high-pass filter the recordings with ffmpeg (pamflow Stage 2).
 * Built on the shared long-job runner (longjob.svelte.ts).
 */
import { createLongJob } from './longjob.svelte';
import { runJob } from './tauri';

export interface FilterSettings {
  enabled: boolean;
  highpass_hz: number;
  order: number;
  workers: number;
  chunk_size: number;
  output_folder: string;
  scanned: boolean;
  input_gb: number | null;
  already_done: number;
}

const filter = createLongJob();

export const filterJob = filter.state;
export const stopFilter = filter.stop;
export const filterMinutesLeft = filter.minutesLeft;
export const filterMinutesElapsed = filter.minutesElapsed;

export const filterInfo = $state({ settings: null as FilterSettings | null, loading: false });

export async function loadFilterInfo(project: string) {
  if (!project) return;
  filterInfo.loading = true;
  try {
    const events = await runJob({ job: 'filter_info', project });
    const info = events.find((e) => e.type === 'filter_info');
    if (info) filterInfo.settings = info.settings as FilterSettings;
  } finally {
    filterInfo.loading = false;
  }
}

export function startFilter(project: string, workers: number) {
  // Batches of a few files per worker, so progress and the resume point update often.
  const chunk = Math.min(200, Math.max(4, workers * 4));
  return filter.start({ job: 'filter', project, filter: { workers, chunk_size: chunk } });
}
