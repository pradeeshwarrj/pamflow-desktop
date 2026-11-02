/**
 * Editing the project's config.yml from the Project screen.
 *
 * `draft` holds the values on screen; saving sends only the settings that
 * differ from what config.yml says now. The bridge changes just those lines
 * (comments and everything else stay), checks the file with pamflow's own
 * reader first, and keeps a dated backup in config/backups/.
 */
import { runJob } from './tauri';
import { project, type ProjectFacts } from './project.svelte';
export type { Setting } from './project.svelte';

export const settings = $state({
  draft: {} as Record<string, unknown>,
  saving: false,
  message: '',
  error: '',
  backup: ''
});

export const id = (section: string, key: string) => `${section}.${key}`;

function originals(): Record<string, unknown> {
  const out: Record<string, unknown> = {};
  for (const s of project.facts?.settings ?? []) out[id(s.section, s.key)] = s.value ?? null;
  return out;
}

/** Put the saved values on screen (after opening a project, saving or discarding). */
export function resetDraft() {
  settings.draft = originals();
  settings.error = '';
}

let shownFor = '';
/**
 * Call from an $effect on screens that edit settings: loads the saved values
 * into the form when a project opens or its config.yml changes, and leaves
 * unsaved edits alone otherwise (so they survive moving between screens).
 */
export function syncDraft() {
  const f = project.facts;
  const key = f ? `${f.config}|${JSON.stringify(f.settings)}` : '';
  if (key && key !== shownFor) {
    shownFor = key;
    resetDraft();
  }
}

/** Settings whose value on screen differs from config.yml. */
export function changedSettings(): { section: string; key: string; value: unknown }[] {
  const orig = originals();
  return Object.entries(settings.draft)
    .filter(([k, v]) => JSON.stringify(v ?? null) !== JSON.stringify(orig[k] ?? null))
    .map(([k, value]) => {
      const dot = k.indexOf('.');
      return { section: k.slice(0, dot), key: k.slice(dot + 1), value: value ?? null };
    });
}

export async function saveSettings() {
  const changes = changedSettings();
  if (!changes.length || !project.folder) return;
  settings.saving = true;
  settings.error = '';
  settings.message = '';
  try {
    const events = await runJob({ job: 'config_save', project: project.folder, changes });
    const saved = events.find((e) => e.type === 'config_saved');
    const facts = events.find((e) => e.type === 'project');
    const finished = events.find((e) => e.type === 'finished');
    if (saved && finished?.status === 'ok') {
      if (facts) project.facts = facts as unknown as ProjectFacts;
      settings.backup = String(saved.backup ?? '');
      settings.message = `${changes.length}`;
      resetDraft();
    } else {
      settings.error = String(finished?.message ?? 'The settings could not be saved.');
    }
  } catch (e) {
    settings.error = String(e);
  } finally {
    settings.saving = false;
  }
}
