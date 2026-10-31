<script lang="ts">
  import Icon from './Icon.svelte';
  import { theme, toggleTheme } from '$lib/theme/theme.svelte';
  import { t } from '$lib/i18n';

  const dark = $derived(theme.mode === 'dark');
</script>

<button type="button" class="switch" role="switch" aria-checked={dark} onclick={toggleTheme}>
  <Icon name={dark ? 'moon' : 'sun'} />
  <span class="label">{dark ? t('common.darkMode') : t('common.lightMode')}</span>
  <span class="track" class:on={dark}><span class="knob"></span></span>
</button>

<style>
  .switch {
    display: flex;
    align-items: center;
    gap: var(--space-3);
    min-height: var(--control-height);
    padding: 0 var(--space-3);
    border-radius: var(--radius-lg);
    border: 1px solid var(--line);
    background: var(--soft);
    cursor: pointer;
  }
  .label { flex: 1; text-align: left; }
  .track {
    position: relative;
    width: 34px;
    height: 20px;
    border-radius: var(--radius-pill);
    background: var(--switch-off);
    transition: background 0.2s;
  }
  .track.on { background: var(--sky-ink); }
  .knob {
    position: absolute;
    top: 2px;
    left: 2px;
    width: 16px;
    height: 16px;
    border-radius: 50%;
    background: var(--surface);
    transition: left 0.2s;
  }
  .track.on .knob { left: 16px; }
</style>
