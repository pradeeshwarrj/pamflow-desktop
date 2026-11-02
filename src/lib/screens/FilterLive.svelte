<!-- Filter step: high-pass filter the recordings (pamflow Stage 2). -->
<script lang="ts">
  import { onMount } from 'svelte';
  import PageHeader from '$lib/components/PageHeader.svelte';
  import Card from '$lib/components/Card.svelte';
  import Button from '$lib/components/Button.svelte';
  import Badge from '$lib/components/Badge.svelte';
  import Pills from '$lib/components/Pills.svelte';
  import Icon from '$lib/components/Icon.svelte';
  import LongJobPanel from '$lib/components/LongJobPanel.svelte';
  import { freeSpace } from '$lib/backend/tauri';
  import { project, refreshProject } from '$lib/backend/project.svelte';
  import { detectJob, isActive } from '$lib/backend/detect.svelte';
  import {
    filterJob, filterInfo, loadFilterInfo, startFilter, stopFilter, filterMinutesLeft, filterMinutesElapsed
  } from '$lib/backend/filter.svelte';
  import { t } from '$lib/i18n';

  let freeGb = $state<number | null>(null);

  onMount(() => {
    if (project.folder) loadFilterInfo(project.folder);
    if (project.folder && !project.facts && !project.checking) refreshProject();
  });

  const s = $derived(filterInfo.settings);
  $effect(() => {
    if (s?.output_folder) freeSpace(s.output_folder).then((g) => (freeGb = g ?? null));
  });

  const physical = $derived(project.facts?.cores_physical ?? 4);
  const workerChoices = $derived(
    [...new Set([2, 4, 8, 12, Math.max(1, physical - 2)])]
      .filter((n) => n >= 1 && n <= Math.max(1, physical - 1))
      .sort((a, b) => a - b)
  );
  let workers = $state(0);
  $effect(() => {
    if (!workers && project.facts && s && workerChoices.length) {
      const want = s?.workers ?? 4;
      workers = workerChoices.reduce((best, n) => (Math.abs(n - want) < Math.abs(best - want) ? n : best), workerChoices[0]);
    }
  });

  const active = $derived(isActive(filterJob.status));
  const busyElsewhere = $derived(isActive(detectJob.status));
  const needGb = $derived(s?.input_gb ?? null);
  const tooSmall = $derived(freeGb !== null && needGb !== null && freeGb < needGb);
  const startLabel = $derived(
    filterJob.status === 'stopped' || (s?.already_done ?? 0) > 0 ? t('detect.continue') : t('filter.start')
  );
  const gb = (x: number) => (x >= 1024 ? `${(x / 1024).toFixed(1)} TB` : `${x.toFixed(1)} GB`);
</script>

<PageHeader stage="filter" title={t('filter.title')} intro={t('filter.intro')} />

{#if !project.folder}
  <Card title={t('detect.chooseProject')}>
    <div><Button variant="primary" href="/">{t('detect.goProject')}</Button></div>
  </Card>
{:else if s}
  {#if !active}
    <Card title={t('filter.settingsTitle')} hint={t('filter.settingsHint')}>
      <dl>
        <dt>{t('filter.filter')}</dt>
        <dd>{s.enabled ? t('filter.highpass', { hz: s.highpass_hz, order: s.order }) : t('filter.disabled')}</dd>
        <dt>{t('filter.output')}</dt><dd class="mono">{s.output_folder}</dd>
        <dt>{t('filter.space')}</dt>
        <dd>
          {needGb !== null ? t('filter.needs', { size: gb(needGb) }) : '–'}
          {#if freeGb !== null} · {t('filter.free', { size: gb(freeGb) })}{/if}
        </dd>
        {#if s.already_done}<dt>{t('filter.done')}</dt><dd>{t('detect.alreadyDone', { n: s.already_done })}</dd>{/if}
      </dl>
      {#if tooSmall}<Badge palette="peach">{t('filter.notEnoughSpace')}</Badge>{/if}
      <div class="field">
        <span class="label">{t('project.workers')}</span>
        <Pills label={t('project.workers')} bind:value={workers}
          options={workerChoices.map((n) => ({ value: n, label: String(n) }))} />
        <span class="muted">{t('filter.workersHint')}</span>
      </div>
      <div class="actions">
        <Button variant="primary" size="lg" onclick={() => startFilter(project.folder, workers)}
          disabled={!s.enabled || busyElsewhere}>
          <Icon name="play" size={14} /> {startLabel}
        </Button>
        <Button variant="ghost" href="/">{t('filter.changeSettings')}</Button>
        {#if busyElsewhere}<Badge palette="peach">{t('process.waitDetect')}</Badge>{/if}
      </div>
    </Card>
  {/if}

  {#if filterJob.status !== 'idle'}
    <LongJobPanel job={filterJob} kind="filter" onstop={stopFilter}
      minutesLeft={filterMinutesLeft} minutesElapsed={filterMinutesElapsed} />
  {/if}
{:else}
  <p class="muted">{t('report.loading')}</p>
{/if}

<style>
  dl { margin: 0; display: grid; grid-template-columns: auto 1fr; gap: var(--space-2) var(--space-6); font-size: var(--text-sm); }
  dt { color: var(--muted); }
  dd { margin: 0; overflow-wrap: anywhere; }
  .field { display: flex; flex-direction: column; gap: var(--space-2); margin-top: var(--space-2); }
  .label { font-weight: var(--weight-semibold); }
  .muted { font-size: var(--text-sm); color: var(--muted); }
  .actions { display: flex; flex-wrap: wrap; align-items: center; gap: var(--space-3); margin-top: var(--space-2); }
</style>
