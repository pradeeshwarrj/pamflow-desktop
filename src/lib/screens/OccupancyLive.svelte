<!-- Occupancy step, connected to pamflow through the analysis engine. -->
<script lang="ts">
  import { onMount } from 'svelte';
  import PageHeader from '$lib/components/PageHeader.svelte';
  import Card from '$lib/components/Card.svelte';
  import Button from '$lib/components/Button.svelte';
  import Badge from '$lib/components/Badge.svelte';
  import Pills from '$lib/components/Pills.svelte';
  import OccupancyResults from './OccupancyResults.svelte';
  import { showFolder } from '$lib/backend/tauri';
  import { project } from '$lib/backend/project.svelte';
  import { detectJob, isActive } from '$lib/backend/detect.svelte';
  import { occupancy, loadOccupancy, buildOccupancy, prepareModelInput, asList } from '$lib/backend/occupancy.svelte';
  import { t } from '$lib/i18n';

  onMount(() => {
    if (project.folder && occupancy.status === 'idle') loadOccupancy(project.folder);
  });

  const info = $derived(occupancy.info);
  const s = $derived(info?.settings);
  const building = $derived(occupancy.status === 'building');
  const detecting = $derived(isActive(detectJob.status));

  let response = $state<'detection' | 'counts'>('detection');
  let standardize = $state(false);
  const model = $derived(occupancy.model);
  const modelDims = $derived.by(() => {
    if (!model) return '';
    const names: Record<string, string> = {
      species: t('occupancy.species'), site: t('occupancy.sites'), occasion: t('occupancy.occasions')
    };
    return model.dims.map((n, i) => `${n} ${names[model.layout[i]] ?? model.layout[i]}`).join(' × ');
  });
  const allPassed = $derived(model ? model.checks.every((c) => c.passed) : false);
</script>

<PageHeader stage="occupancy" title={t('occupancy.title')} intro={t('occupancy.intro')} />

{#if !project.folder}
  <Card title={t('detect.chooseProject')}>
    <div><Button variant="primary" href="/">{t('detect.goProject')}</Button></div>
  </Card>
{:else}
  <Card title={t('occupancy.settingsTitle')} hint={t('process.rulesHint')}>
    {#if s}
      <dl>
        <dt>{t('occupancy.run')}</dt>
        <dd>
          {s.run_id}
          {#if s.config_run_id && s.config_run_id !== s.run_id}
            <span class="muted"> · {t('occupancy.runNote', { run: s.config_run_id })}</span>
          {/if}
        </dd>
        <dt>{t('occupancy.occasionLength')}</dt><dd>{t('occupancy.days', { n: s.occasion_length_days })}</dd>
        <dt>{t('occupancy.minEffort')}</dt><dd>{t('occupancy.hours', { n: s.min_effort_hours })}</dd>
        <dt>{t('occupancy.minDetections')}</dt><dd>{s.min_detections}</dd>
        <dt>{t('process.minConfidence')}</dt>
        <dd>{s.thresholds_file ? t('process.perSpecies', { file: s.thresholds_file }) : s.min_confidence}</dd>
      </dl>
    {/if}
    <div class="actions">
      <Button variant="primary" size="lg" onclick={() => buildOccupancy(project.folder)} disabled={building || detecting}>
        {building ? t('occupancy.building') : info?.available ? t('occupancy.rebuild') : t('occupancy.build')}
      </Button>
      {#if info?.available}
        <Button onclick={() => showFolder(info.dir)}>{t('detect.openFolder')}</Button>
        <span class="muted">{t('process.updated', { when: info.updated ?? '' })}</span>
      {/if}
      {#if detecting}<Badge palette="peach">{t('process.waitDetect')}</Badge>{/if}
    </div>
    {#if occupancy.message}<p class="problem">{occupancy.message}</p>{/if}
  </Card>

  {#if info?.available}
    <OccupancyResults {info} bind:selected={occupancy.selected} />

    <Card title={t('occupancy.modelTitle')} hint={t('occupancy.modelHint')}>
      <div class="grid-2">
        <div class="field">
          <span class="label">{t('occupancy.response')}</span>
          <Pills label={t('occupancy.response')} bind:value={response} options={[
            { value: 'detection', label: t('occupancy.detectionResponse') },
            { value: 'counts', label: t('occupancy.countsResponse') }
          ]} />
          <span class="muted">{response === 'detection' ? t('occupancy.detectionHint') : t('occupancy.countsHint')}</span>
        </div>
        <div class="field">
          <span class="label">{t('occupancy.covariates')}</span>
          <label class="check"><input type="checkbox" bind:checked={standardize} /> {t('occupancy.standardize')}</label>
        </div>
      </div>
      <div class="actions">
        <Button variant="primary" onclick={() => prepareModelInput(project.folder, response, standardize)}
          disabled={occupancy.modelStatus === 'running'}>
          {occupancy.modelStatus === 'running' ? t('occupancy.preparing') : t('occupancy.prepare')}
        </Button>
        {#if model}<Button onclick={() => showFolder(model.dir)}>{t('detect.openFolder')}</Button>{/if}
      </div>
      {#if occupancy.modelMessage}<p class="problem">{occupancy.modelMessage}</p>{/if}
      {#if model}
        <div class="result">
          <p><b>{modelDims}</b></p>
          <p class="muted">{t('occupancy.siteCovs')}: {asList(model.site_covariates).join(', ') || '–'}
            · {t('occupancy.obsCovs')}: {asList(model.obs_covariates).join(', ') || '–'}</p>
          <ul class="checks">
            {#each model.checks as c (c.check)}
              <li class:fail={!c.passed}><span class="mark">{c.passed ? '✓' : '✗'}</span>{c.check}{c.detail ? ` — ${c.detail}` : ''}</li>
            {/each}
          </ul>
          <p class="muted">{allPassed ? t('occupancy.ready') : t('occupancy.notReady')}</p>
          <p class="muted mono files">{asList(model.files).join(' · ')}</p>
        </div>
      {/if}
    </Card>
  {:else if occupancy.status === 'ready'}
    <Card title={t('occupancy.noneTitle')} hint={t('occupancy.noneHint')} />
  {/if}
{/if}

<style>
  dl { margin: 0; display: grid; grid-template-columns: auto 1fr; gap: var(--space-2) var(--space-6); font-size: var(--text-sm); }
  dt { color: var(--muted); }
  dd { margin: 0; }
  .actions { display: flex; flex-wrap: wrap; align-items: center; gap: var(--space-3); margin-top: var(--space-2); }
  .muted { font-size: var(--text-sm); color: var(--muted); margin: 0; }
  .problem { margin: 0; color: var(--rose-ink); font-weight: var(--weight-semibold); font-size: var(--text-sm); }
  .field { display: flex; flex-direction: column; gap: var(--space-2); min-width: 0; }
  .label { font-weight: var(--weight-semibold); }
  .check { display: flex; align-items: center; gap: var(--space-2); min-height: 40px; font-size: var(--text-sm); cursor: pointer; }
  .check input { width: 18px; height: 18px; margin: 0; }
  .result { display: flex; flex-direction: column; gap: var(--space-2); padding-top: var(--space-2); border-top: 1px solid var(--line); }
  .result p { margin: 0; }
  .checks { list-style: none; margin: 0; padding: 0; font-size: var(--text-sm); display: flex; flex-direction: column; gap: 2px; }
  .checks .mark { display: inline-block; width: 20px; color: var(--mint-ink); font-weight: var(--weight-bold); }
  .checks .fail .mark { color: var(--rose-ink); }
  .files { font-size: 12px; }
</style>
