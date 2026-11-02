/**
 * Step 2 · Scan: read every recording's header, check quality and match the
 * deployment sheet (pamflow Stage 1).
 */
import { runJob } from './tauri';

export interface ScanSummary {
  available: boolean;
  updated?: string;
  audio_folder: string;
  metadata_folder?: string;
  n_files?: number;
  n_grids?: number;
  total_hours?: number;
  n_qc_pass?: number;
  issues?: Record<'invalid_name' | 'unreadable' | 'truncated' | 'short' | 'duplicate' | 'gaps' | 'outside_deployment', number>;
  per_grid?: Record<string, unknown>[];
  deployment_issues?: Record<string, unknown>[];
}

export const scan = $state({
  status: 'idle' as 'idle' | 'loading' | 'scanning' | 'ready' | 'failed',
  summary: null as ScanSummary | null,
  message: '',
  log: [] as string[]
});

async function run(project: string, job: 'scan' | 'scan_results', force = false) {
  const events = await runJob({ job, project, force });
  const summary = events.find((e) => e.type === 'scan');
  const finished = events.find((e) => e.type === 'finished');
  scan.log = events.filter((e) => e.type === 'log' || e.type === 'text').map((e) => String(e.text ?? ''));
  if (summary) scan.summary = summary as unknown as ScanSummary;
  scan.status = finished?.status === 'ok' ? 'ready' : 'failed';
  scan.message = finished?.status === 'ok' ? '' : String(finished?.message ?? 'Scanning failed.');
}

export async function loadScan(project: string) {
  if (!project) return;
  scan.status = 'loading';
  try { await run(project, 'scan_results'); } catch (e) { scan.status = 'failed'; scan.message = String(e); }
}

export async function runScan(project: string, force: boolean) {
  scan.status = 'scanning';
  scan.message = '';
  try { await run(project, 'scan', force); } catch (e) { scan.status = 'failed'; scan.message = String(e); }
}
