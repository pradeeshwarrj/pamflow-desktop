/**
 * First launch of an installed pamflow: unpack the analysis engine that ships
 * inside the installer (Rust side: src-tauri/src/setup.rs). Development builds
 * and runtimes given with PAMFLOW_RUNTIME need no setup.
 */
import { invoke } from '@tauri-apps/api/core';
import { listen } from '@tauri-apps/api/event';
import { inApp } from './tauri';

export type SetupPhase = 'space' | 'unpack' | 'extras' | 'check' | 'done' | 'failed';

export const setup = $state({
  checked: !inApp,        // in a plain browser there is nothing to set up
  needed: false,
  running: false,
  phase: '' as SetupPhase | '',
  step: '' as SetupPhase | '',   // last step reached (kept when it fails)
  seconds: 0,
  target: '',
  problem: '',
  message: '',
  log: [] as string[]
});

interface SetupStatus { needed: boolean; packed: boolean; running?: boolean; target?: string; problem?: string | null }

let listening = false;
async function listenOnce() {
  if (listening) return;
  listening = true;
  await listen<{ phase: string; message: string; seconds: number }>('setup-event', ({ payload }) => {
    setup.seconds = payload.seconds;
    if (payload.phase === 'log') {
      setup.log.push(payload.message);
      if (setup.log.length > 400) setup.log.splice(0, setup.log.length - 400);
      return;
    }
    setup.phase = payload.phase as SetupPhase;
    if (payload.phase !== 'failed') setup.step = payload.phase as SetupPhase;
    setup.message = payload.message;
    if (payload.phase === 'done') { setup.running = false; setup.needed = false; }
    if (payload.phase === 'failed') setup.running = false;
  });
}

export async function checkSetup() {
  if (!inApp) return;
  await listenOnce();
  const s = await invoke<SetupStatus>('setup_status');
  setup.needed = s.needed;
  setup.target = s.target ?? '';
  setup.problem = s.problem ?? '';
  setup.checked = true;
  if (s.running) setup.running = true;
}

export async function startSetup() {
  await listenOnce();
  Object.assign(setup, { running: true, phase: 'space', step: 'space', message: '', log: [], seconds: 0 });
  try {
    await invoke('start_setup');
  } catch (e) {
    setup.running = false;
    setup.phase = 'failed';
    setup.message = String(e);
  }
}
