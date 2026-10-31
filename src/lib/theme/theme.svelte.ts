/**
 * Light / dark mode.
 *
 * On first launch the app follows the computer's own setting.
 * Once the user flips the switch, their choice is remembered.
 */

export type ThemeMode = 'light' | 'dark';

const STORAGE_KEY = 'pamflow-theme';

function initialMode(): ThemeMode {
  try {
    const saved = localStorage.getItem(STORAGE_KEY);
    if (saved === 'light' || saved === 'dark') return saved;
  } catch {
    /* storage unavailable: fall through to system setting */
  }
  return window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light';
}

export const theme = $state<{ mode: ThemeMode }>({ mode: initialMode() });

export function toggleTheme(): void {
  theme.mode = theme.mode === 'dark' ? 'light' : 'dark';
  try {
    localStorage.setItem(STORAGE_KEY, theme.mode);
  } catch {
    /* not saved; still switches for this session */
  }
}
