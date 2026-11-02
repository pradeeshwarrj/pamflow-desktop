/**
 * Detect step: BirdNET on the recordings (pamflow Stage 3).
 * Built on the shared long-job runner (longjob.svelte.ts).
 */
import { createLongJob, isActive, type JobStatus, type FileRow, type LogLine } from './longjob.svelte';

export { isActive };
export type DetectStatus = JobStatus;
export type { FileRow, LogLine };

const detect = createLongJob();

export const detectJob = detect.state;
export const stopDetect = detect.stop;
export const minutesLeft = detect.minutesLeft;
export const minutesElapsed = detect.minutesElapsed;

export function startDetect(project: string, settings: { workers: number; sampleN: number | null }) {
  // Small batches so progress (and the resume point) update often.
  const chunk = Math.min(50, Math.max(4, settings.workers * 2));
  return detect.start({
    job: 'detect',
    project,
    birdnet: { workers: settings.workers, chunk_size: chunk },
    sample_n: settings.sampleN
  });
}
