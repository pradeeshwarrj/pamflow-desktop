<!--
  "Save to config.yml" bar for the settings draft (backend/settings.svelte.ts).
  Used on every screen that edits config.yml; sticky while there are unsaved changes.
-->
<script lang="ts">
  import Button from './Button.svelte';
  import { showFolder } from '$lib/backend/tauri';
  import { settings, resetDraft, changedSettings, saveSettings } from '$lib/backend/settings.svelte';
  import { t } from '$lib/i18n';

  const nChanges = $derived(changedSettings().length);
</script>

<div class="savebar" class:dirty={nChanges > 0}>
  {#if nChanges > 0}
    <span>{t('settings.unsaved', { n: nChanges })}</span>
    <div class="actions">
      <Button variant="ghost" onclick={resetDraft} disabled={settings.saving}>{t('settings.discard')}</Button>
      <Button variant="primary" onclick={saveSettings} disabled={settings.saving}>
        {settings.saving ? t('settings.saving') : t('settings.save')}
      </Button>
    </div>
  {:else if settings.message}
    <span>{t('settings.saved', { n: settings.message })}</span>
    <Button variant="ghost" size="sm" onclick={() => showFolder(settings.backup)}>{t('settings.showBackup')}</Button>
  {:else}
    <span class="muted">{t('settings.allSaved')}</span>
  {/if}
</div>
{#if settings.error}<p class="problem">{settings.error}</p>{/if}

<style>
  .savebar {
    display: flex; align-items: center; justify-content: space-between; gap: var(--space-3);
    padding: var(--space-3) var(--space-5); border-radius: var(--radius-xl);
    background: var(--surface); border: 1px solid var(--line); font-size: var(--text-sm);
  }
  .savebar.dirty { position: sticky; bottom: 0; z-index: 2; background: var(--accent-tint); color: var(--accent-ink); border-color: transparent; font-weight: var(--weight-semibold); }
  .actions { display: flex; gap: var(--space-2); }
  .muted { color: var(--muted); }
  .problem { margin: 0; color: var(--rose-ink); font-weight: var(--weight-semibold); font-size: var(--text-sm); }
</style>
