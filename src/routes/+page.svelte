<!-- Step 1 · Project -->
<script lang="ts">
  import PageHeader from '$lib/components/PageHeader.svelte';
  import Card from '$lib/components/Card.svelte';
  import StatTile from '$lib/components/StatTile.svelte';
  import PathField from '$lib/components/PathField.svelte';
  import Pills from '$lib/components/Pills.svelte';
  import Badge from '$lib/components/Badge.svelte';
  import Button from '$lib/components/Button.svelte';
  import Icon from '$lib/components/Icon.svelte';
  import { project } from '$lib/mock/demo';
  import { t } from '$lib/i18n';
  import { inApp } from '$lib/backend/tauri';
  import ProjectPicker from '$lib/screens/ProjectPicker.svelte';

  let recordingsFolder = $state(project.recordingsFolder);
  let pattern = $state(project.pattern);
  let model = $state<'global' | 'custom'>('custom');
  let workers = $state(project.defaultWorkers);
  let minConfidence = $state(project.minConfidence);
</script>

<PageHeader stage="project" title={t('project.title')} intro={t('project.intro')} />

{#if inApp}
  <ProjectPicker />
  <p class="preview-note">{t('project.demoBelow')}</p>
{/if}

<div class="grid-3">
  <StatTile value={project.recordings.toLocaleString()} label={t('project.recordingsFound')} />
  <StatTile value={project.sizeLabel} label={t('project.ofAudio')} palette="mint" />
  <StatTile value={project.deployments} label={t('project.deploymentsInSheet')} palette="lavender" />
</div>

<div class="grid-2">
  <Card title={t('project.recordingsFolder')} hint={t('project.recordingsFolderHint')} labelFor="recordings">
    <PathField id="recordings" bind:value={recordingsFolder} />
  </Card>

  <Card title={t('project.pattern')} hint={t('project.patternHint')} labelFor="pattern">
    <input id="pattern" class="input mono" bind:value={pattern} />
    <div class="chips">
      <Badge>{project.exampleFile}</Badge>
      {#each project.exampleParts as part (part)}<Badge palette="mint">{part}</Badge>{/each}
    </div>
  </Card>

  <Card title={t('project.sheet')} hint={t('project.sheetHint')}>
    <div class="file">
      <Icon name="sheet" />
      <span class="grow">{project.sheetFile}</span>
      <span class="muted">{t('project.sheetRows', { n: project.deployments })}</span>
    </div>
    <div><Badge palette="peach">{t('project.sheetWarning')}</Badge></div>
  </Card>

  <Card title={t('project.model')} hint={t('project.modelHint')}>
    <Pills label={t('project.model')} bind:value={model} options={[
      { value: 'global', label: t('project.modelGlobal') },
      { value: 'custom', label: t('project.modelCustom') }
    ]} />
    {#if model === 'custom'}
      <span class="muted">{t('project.modelFound', { file: project.modelFile })}</span>
    {/if}
  </Card>

  <Card title={t('project.workers')} hint={t('project.workersHint', { n: project.cores })}>
    <Pills label={t('project.workers')} bind:value={workers}
      options={project.workerChoices.map((n) => ({ value: n, label: String(n) }))} />
  </Card>

  <Card>
    <div class="between">
      <label for="confidence" class="strong">{t('project.confidence')}</label>
      <span class="value">{minConfidence.toFixed(2)}</span>
    </div>
    <span class="muted">{t('project.confidenceHint')}</span>
    <input id="confidence" type="range" min="0.05" max="0.95" step="0.05" bind:value={minConfidence} />
  </Card>
</div>

<div class="actions">
  <Button variant="primary" size="lg" href="/scan">
    {t('project.save')} <Icon name="arrowRight" size={16} />
  </Button>
  <Button variant="ghost" size="lg">{t('project.advanced')}</Button>
</div>

<style>
  .chips { display: flex; flex-wrap: wrap; gap: var(--space-2); }
  .file {
    display: flex; align-items: center; gap: var(--space-3);
    min-height: var(--control-height); padding: 0 var(--space-3);
    border-radius: var(--radius-md); background: var(--soft);
  }
  .grow { flex: 1; }
  .muted { font-size: var(--text-sm); color: var(--muted); }
  .between { display: flex; justify-content: space-between; align-items: baseline; }
  .strong { font-weight: var(--weight-semibold); }
  .value { font-weight: var(--weight-semibold); color: var(--accent-ink); font-variant-numeric: tabular-nums; }
  input[type='range'] { width: 100%; }
  .preview-note { font-size: var(--text-sm); color: var(--muted); }
  .actions { display: flex; flex-wrap: wrap; align-items: center; gap: var(--space-3); }
</style>
