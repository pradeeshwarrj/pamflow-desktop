/** Which workflow the sidebar shows: A (detection) or B (soundscape indices). Remembered between launches. */
import type { Workflow } from '$lib/config/stages';

const STORAGE_KEY = 'pamflow-workflow';

function initial(): Workflow {
  try {
    return localStorage.getItem(STORAGE_KEY) === 'B' ? 'B' : 'A';
  } catch {
    return 'A'; // storage unavailable
  }
}

export const workflow = $state<{ current: Workflow }>({ current: initial() });

export function setWorkflow(w: Workflow): void {
  workflow.current = w;
  try {
    localStorage.setItem(STORAGE_KEY, w);
  } catch {
    /* not saved; still switches for this session */
  }
}
