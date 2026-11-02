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

export interface Stage {
  id: string;
  path: string;
  palette: Palette;
}

export const stages: Stage[] = [
  { id: 'project',   path: '/',          palette: 'sky' },
  { id: 'standardize', path: '/standardize', palette: 'butter' },
  { id: 'scan',      path: '/scan',      palette: 'mint' },
  { id: 'filter',    path: '/filter',    palette: 'aqua' },
  { id: 'detect',    path: '/detect',    palette: 'lavender' },
  { id: 'process',   path: '/process',   palette: 'peach' },
  { id: 'validate',  path: '/validate',  palette: 'rose' },
  { id: 'occupancy', path: '/occupancy', palette: 'butter' },
  { id: 'report',    path: '/report',    palette: 'sage' }
];

/** Which step a URL belongs to (falls back to the first step). */
export function stageForPath(pathname: string): Stage {
  const clean = pathname.replace(/\/+$/, '') || '/';
  return stages.find((s) => s.path === clean) ?? stages[0];
}

/** 1-based step number, used in "Detect step". */
export function stageNumber(id: string): number {
  return stages.findIndex((s) => s.id === id) + 1;
}

/** CSS that makes a block use a step's pastel as its accent. */
export function accentStyle(palette: Palette): string {
  return `--accent-tint: var(--${palette}-tint); --accent-ink: var(--${palette}-ink);`;
}
