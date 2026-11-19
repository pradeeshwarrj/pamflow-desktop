/**
 * The workflow steps shown in the sidebar, in order.
 *
 * To change the steps:
 *  - reorder this list to reorder the sidebar (step numbers follow)
 *  - change `palette` to give a step a different pastel (see tokens.css)
 *  - the step's name comes from src/lib/i18n/en.json -> "stages"
 *  - `path` is the screen's folder under src/routes
 */

export type Palette =
  | 'sky' | 'mint' | 'aqua' | 'lavender'
  | 'peach' | 'rose' | 'butter' | 'sage';

/** A = detection (birds and other species), B = soundscape indices. */
export type Workflow = 'A' | 'B';

export interface Stage {
  id: string;
  path: string;
  palette: Palette;
  /** Which workflows show this step. */
  workflows: Workflow[];
}

export const stages: Stage[] = [
  { id: 'project',   path: '/',          palette: 'sky', workflows: ['A', 'B'] },
  { id: 'standardize', path: '/standardize', palette: 'butter', workflows: ['A', 'B'] },
  { id: 'scan',      path: '/scan',      palette: 'mint', workflows: ['A', 'B'] },
  { id: 'filter',    path: '/filter',    palette: 'aqua', workflows: ['A'] },
  { id: 'soundscape', path: '/soundscape', palette: 'sage', workflows: ['B'] },
  { id: 'visualize', path: '/visualize', palette: 'aqua', workflows: ['B'] },
  { id: 'detect',    path: '/detect',    palette: 'lavender', workflows: ['A'] },
  { id: 'process',   path: '/process',   palette: 'peach', workflows: ['A'] },
  { id: 'validate',  path: '/validate',  palette: 'rose', workflows: ['A'] },
  { id: 'occupancy', path: '/occupancy', palette: 'butter', workflows: ['A'] },
  { id: 'report',    path: '/report',    palette: 'sage', workflows: ['A'] }
];

export const workflowStages = (w: Workflow): Stage[] => stages.filter((s) => s.workflows.includes(w));

/** Which step a URL belongs to (falls back to the first step). */
export function stageForPath(pathname: string): Stage {
  const clean = pathname.replace(/\/+$/, '') || '/';
  return stages.find((s) => s.path === clean) ?? stages[0];
}

/** 1-based step number within a workflow, used in "Detect step". */
export function stageNumber(id: string, w: Workflow): number {
  return workflowStages(w).findIndex((s) => s.id === id) + 1;
}

/** CSS that makes a block use a step's pastel as its accent. */
export function accentStyle(palette: Palette): string {
  return `--accent-tint: var(--${palette}-tint); --accent-ink: var(--${palette}-ink);`;
}
