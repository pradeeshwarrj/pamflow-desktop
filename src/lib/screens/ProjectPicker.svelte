<!--
  Choose the pamflow project and show what the engine found in it.
  A folder with no settings file gets pamflow's default settings on request,
  so nothing has to be prepared beforehand; the settings file can live
  anywhere (Save as... on every settings bar, Open another settings file...).
-->
<script lang="ts">
  import Card from '$lib/components/Card.svelte';
  import Button from '$lib/components/Button.svelte';
  import Badge from '$lib/components/Badge.svelte';
  import { pickFolder, pickFile, pickSavePath, showFolder } from '$lib/backend/tauri';
  import { project, openProject, openConfigFile, createProject, createExample, refreshProject } from '$lib/backend/project.svelte';
  import { t } from '$lib/i18n';
  import { onMount } from 'svelte';

  let folder = $state(project.folder);
  $effect(() => { folder = project.folder; }); // follows the open project

  onMount(() => {
    if (project.folder && !project.facts && !project.noConfig && !project.checking) refreshProject();
  });

  async function browse() {
    const picked = await pickFolder(t('project.folderTitle'));
    if (picked) {
      folder = picked;
      await openProject(picked);
    }
  }

  // New project: pick a folder (the dialog can make a new one); an existing
  // settings file in it is simply opened, never replaced.
  async function newProject() {
    const picked = await pickFolder(t('project.newTitle'));
    if (!picked) return;
    folder = picked;
    await openProject(picked);
    if (project.noConfig) await createProject(picked);
  }

  async function openOther() {
    const picked = await pickFile(t('project.openOtherTitle'), t('settings.yamlFiles'), ['yml', 'yaml']);
    if (picked) await openConfigFile(picked);
  }

  // Start with the default settings, but save them somewhere else.
  async function createElsewhere() {
    const nc = project.noConfig;
    if (!nc) return;
    const picked = await pickSavePath(t('settings.saveAsTitle'), nc.suggested, t('settings.yamlFiles'), ['yml', 'yaml']);
    if (picked) await createProject(nc.folder, picked);
  }

  const f = $derived(project.facts);
  const nc = $derived(project.noConfig);
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
  <div class="row links">
    <Button variant="ghost" size="sm" onclick={newProject} disabled={project.checking}>{t('project.newProject')}</Button>
    <Button variant="ghost" size="sm" onclick={openOther} disabled={project.checking}>{t('project.openOther')}</Button>
    <Button variant="ghost" size="sm" onclick={createExample} disabled={project.checking}>{t('project.tryExample')}</Button>
  </div>

  {#if project.checking}
    <span class="muted">{t('project.checking')}</span>
  {:else if project.error}
    <pre class="error">{project.error}</pre>
  {:else if nc && !nc.exists && !nc.missingFile}
    <pre class="error">{t('project.folderMissing', { folder: nc.folder })}</pre>
  {:else if nc}
    <div class="offer">
      <strong>{nc.missingFile ? t('project.configMissingTitle') : t('project.noConfigTitle')}</strong>
      <span class="muted">
        {nc.missingFile
          ? t('project.configMissingBody', { file: nc.missingFile })
          : t('project.noConfigBody', { file: nc.suggested })}
      </span>
      {#if nc.exists}
        <div class="row">
          <Button variant="primary" onclick={() => createProject(nc.folder)}>{t('project.createHere')}</Button>
          <Button onclick={createElsewhere}>{t('project.createElsewhere')}</Button>
        </div>
      {/if}
    </div>
  {:else if f}
    <div class="chips">
      {#if project.created}<Badge palette="sky">{t('project.configCreated')}</Badge>
      {:else}<Badge palette="mint">{t('project.configFound')}</Badge>{/if}
      {#if f.audio_folder_found}
        <Badge palette="mint">{t('project.recordingsN', { n: (f.n_audio ?? 0).toLocaleString() })}</Badge>
      {:else}
        <Badge palette="peach">{t('project.audioMissing', { folder: f.audio_folder })}</Badge>
      {/if}
      <Badge palette={f.scanned ? 'mint' : undefined}>{f.scanned ? t('project.scanned') : t('project.notScanned')}</Badge>
      {#if f.model_found}<Badge palette="mint">{t('project.modelOk')}</Badge>
      {:else}<Badge palette="peach">{t('project.modelMissing', { file: f.model_file ?? '' })}</Badge>{/if}
    </div>
    <div class="file">
      <span class="muted">{t('project.settingsFile')}</span>
      <span class="path mono" title={f.config}>{f.config}</span>
      <Button variant="ghost" size="sm" onclick={() => showFolder(f.config)}>{t('project.showFile')}</Button>
    </div>
    {#if project.example}<span class="muted">{t('project.exampleHint')}</span>
    {:else if project.created}<span class="muted">{t('project.createdHint')}</span>{/if}
  {/if}
</Card>

<style>
  .row { display: flex; gap: var(--space-2); flex-wrap: wrap; align-items: center; }
  .row :global(.input) { flex: 1; min-width: 240px; }
  .links { margin-top: calc(var(--space-1) * -1); }
  .chips { display: flex; flex-wrap: wrap; gap: var(--space-2); }
  .muted { font-size: var(--text-sm); color: var(--muted); }
  .error { margin: 0; white-space: pre-wrap; font-size: var(--text-sm); color: var(--rose-ink); }
  .offer { display: flex; flex-direction: column; gap: var(--space-2); padding: var(--space-4);
    border-radius: var(--radius-lg); background: var(--accent-tint); color: var(--accent-ink); }
  .offer .muted { color: inherit; opacity: 0.85; overflow-wrap: anywhere; }
  .file { display: flex; align-items: center; gap: var(--space-2); min-width: 0; }
  .path { flex: 1; min-width: 0; font-size: var(--text-xs); overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
</style>
