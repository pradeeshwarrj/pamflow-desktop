<!-- Choose the pamflow project folder and show what the engine found in it. -->
<script lang="ts">
  import Card from '$lib/components/Card.svelte';
  import Button from '$lib/components/Button.svelte';
  import Badge from '$lib/components/Badge.svelte';
  import { pickFolder } from '$lib/backend/tauri';
  import { project, openProject, refreshProject } from '$lib/backend/project.svelte';
  import { t } from '$lib/i18n';
  import { onMount } from 'svelte';

  let folder = $state(project.folder);

  onMount(() => {
    if (project.folder && !project.facts && !project.checking) refreshProject();
  });

  async function browse() {
    const picked = await pickFolder(t('project.folderTitle'));
    if (picked) {
      folder = picked;
      await openProject(picked);
    }
  }

  const f = $derived(project.facts);
</script>

<Card title={t('project.folderTitle')} hint={t('project.folderHint')} labelFor="project-folder">
  <div class="row">
    <input id="project-folder" class="input" bind:value={folder}
      onkeydown={(e) => e.key === 'Enter' && openProject(folder)} />
    <Button onclick={browse}>{t('common.browse')}</Button>
    <Button variant="primary" onclick={() => openProject(folder)} disabled={!folder || project.checking}>
      {t('project.open')}
    </Button>
  </div>

  {#if project.checking}
    <span class="muted">{t('project.checking')}</span>
  {:else if project.error}
    <pre class="error">{project.error}</pre>
  {:else if f}
    <div class="chips">
      <Badge palette="mint">{t('project.configFound')}</Badge>
      {#if f.audio_folder_found}
        <Badge palette="mint">{t('project.recordingsN', { n: (f.n_audio ?? 0).toLocaleString() })}</Badge>
      {:else}
        <Badge palette="peach">{t('project.audioMissing', { folder: f.audio_folder })}</Badge>
      {/if}
      <Badge palette={f.scanned ? 'mint' : undefined}>{f.scanned ? t('project.scanned') : t('project.notScanned')}</Badge>
      {#if f.model_found}<Badge palette="mint">{t('project.modelOk')}</Badge>
      {:else}<Badge palette="peach">{t('project.modelMissing', { file: f.model_file ?? '' })}</Badge>{/if}
    </div>
  {/if}
</Card>

<style>
  .row { display: flex; gap: var(--space-2); }
  .chips { display: flex; flex-wrap: wrap; gap: var(--space-2); }
  .muted { font-size: var(--text-sm); color: var(--muted); }
  .error { margin: 0; white-space: pre-wrap; font-size: var(--text-sm); color: var(--rose-ink); }
</style>
