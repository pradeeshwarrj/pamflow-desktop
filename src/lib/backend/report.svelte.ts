/**
 * Step 8 · Report: pamflow's HTML and Excel report of the run.
 * (PDF is not offered: pamflow's PDF needs LaTeX, which the app does not bundle.)
 */
import { runJob } from './tauri';

export interface ReportFile {
  format: 'html' | 'excel';
  path: string;
  exists: boolean;
  updated: string | null;
  size_kb: number | null;
}

export interface ReportPreview {
  run_id: string;
  title: string;
  author: string;
  formats: string[] | string | null;
  reports_dir: string;
  pandoc: boolean;
  numbers: { effort_hours: number | null; sites: number | null; events: number; species: number };
  sections: Record<'effort' | 'detections' | 'richness' | 'activity' | 'validation' | 'occupancy', boolean>;
  top_species: { species: string; events: number; sites: number }[];
  files: ReportFile[];
}

export const report = $state({
  status: 'idle' as 'idle' | 'loading' | 'ready' | 'writing' | 'failed',
  preview: null as ReportPreview | null,
  message: '',
  made: [] as string[],
  missing: [] as string[],
  log: [] as string[]
});

const list = (x: unknown): string[] => (Array.isArray(x) ? x.map(String) : x ? [String(x)] : []);

export async function loadReportPreview(project: string) {
  if (!project) return;
  report.status = 'loading';
  try {
    const events = await runJob({ job: 'report_preview', project });
    const p = events.find((e) => e.type === 'report_preview');
    if (p) {
      report.preview = p as unknown as ReportPreview;
      report.status = 'ready';
    } else {
      report.status = 'failed';
      report.message = String(events.find((e) => e.type === 'finished')?.message ?? 'Could not read the project.');
    }
  } catch (e) {
    report.status = 'failed';
    report.message = String(e);
  }
}

export async function writeReport(project: string, formats: string[]) {
  report.status = 'writing';
  report.message = '';
  report.made = [];
  report.missing = [];
  try {
    const events = await runJob({ job: 'report', project, formats });
    const done = events.find((e) => e.type === 'report_done');
    const finished = events.find((e) => e.type === 'finished');
    report.log = events.filter((e) => e.type === 'log' || e.type === 'text').map((e) => String(e.text ?? ''));
    if (done && report.preview) report.preview.files = done.files as ReportFile[];
    report.made = list(done?.made);
    report.missing = list(done?.missing);
    report.status = 'ready';
    if (finished?.status !== 'ok') report.message = String(finished?.message ?? 'Writing the report failed.');
  } catch (e) {
    report.status = 'failed';
    report.message = String(e);
  }
}
