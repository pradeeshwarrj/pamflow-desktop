/**
 * Facts about the app itself: its version, whether the analysis engine is
 * there, the pamflow version in it; plus "Save diagnostics" and the question
 * asked when the window is closed during a long run.
 */
import { invoke } from '@tauri-apps/api/core';
import { listen } from '@tauri-apps/api/event';
import { inApp, runtimeInfo, runJob, pickSavePath, showFolder, failureMessage } from './tauri';

export const appInfo = $state({
  app: '',                              // this app's version
  pamflow: '',                          // pamflow's version in the analysis engine (known after a project is read)
  runtimeFound: null as boolean | null, // null = not asked yet
  runtimeMessage: '',
  diagnosticsBusy: false,
  diagnosticsError: ''
});

export async function loadAppInfo() {
  if (!inApp) return;
  try {
    const { getVersion } = await import('@tauri-apps/api/app');
    appInfo.app = await getVersion();
  } catch {
    /* the label simply omits the version */
  }
  try {
    const rt = await runtimeInfo();
    appInfo.runtimeFound = rt.found;
    appInfo.runtimeMessage = rt.message ?? '';
  } catch {
    appInfo.runtimeFound = false;
  }
}

/** Pick the pamflow version out of a job's "started" event. */
export function notePamflowVersion(events: { type: string; [k: string]: unknown }[]) {
  const started = events.find((e) => e.type === 'started');
  if (started?.pamflow) appInfo.pamflow = String(started.pamflow);
}

/**
 * Ask before the window closes while a long run is going. The Rust side
 * sends "close-requested"; "yes" stops the run (it continues on the next
 * Start) and quits.
 */
export async function watchClose(text: { message: string; title: string; stop: string; keep: string }) {
  if (!inApp) return;
  await listen('close-requested', async () => {
    let stop = false;
    try {
      const { ask } = await import('@tauri-apps/plugin-dialog');
      stop = await ask(text.message, { title: text.title, kind: 'warning', okLabel: text.stop, cancelLabel: text.keep });
    } finally {
      await invoke('close_prompt_done');
    }
    if (stop) await invoke('quit_app');
  });
}

/** Write one text file with versions, system, settings and log tails; then show it in its folder. */
export async function saveDiagnostics(project: string, dialog: { title: string; kind: string }) {
  if (!inApp || appInfo.diagnosticsBusy) return;
  const day = new Date().toISOString().slice(0, 10);
  const target = await pickSavePath(dialog.title, `pamflow-diagnostics-${day}.txt`, dialog.kind, ['txt']);
  if (!target) return;
  appInfo.diagnosticsBusy = true;
  appInfo.diagnosticsError = '';
  try {
    const events = await runJob({ job: 'diagnostics', project, target });
    const saved = events.find((e) => e.type === 'diagnostics_saved');
    if (saved) await showFolder(String(saved.path));
    else appInfo.diagnosticsError = failureMessage(events, 'The diagnostics file could not be written.');
  } catch (e) {
    appInfo.diagnosticsError = String(e);
  } finally {
    appInfo.diagnosticsBusy = false;
  }
}
