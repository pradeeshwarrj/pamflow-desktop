<!--
  Live view of a long-running job (Detect, Filter): progress panel with Stop,
  totals, and the list of finished files (or the full log).
-->
<script lang="ts">
  import { onMount } from 'svelte';
  import Card from './Card.svelte';
  import StatTile from './StatTile.svelte';
  import ProgressBar from './ProgressBar.svelte';
  import Badge from './Badge.svelte';
  import Button from './Button.svelte';
  import Icon from './Icon.svelte';
  import { showFolder } from '$lib/backend/tauri';
  import { isActive, type LongJobState } from '$lib/backend/longjob.svelte';
  import { t } from '$lib/i18n';

  let { job, kind, onstop, minutesLeft, minutesElapsed }: {
    job: LongJobState;
    kind: 'detect' | 'filter';
    onstop: () => void;
    minutesLeft: () => number | null;
    minutesElapsed: () => number;
  } = $props();

  let tick = $state(0); // refreshes the elapsed / time-left text
  let showLog = $state(false);
  onMount(() => {
    const timer = setInterval(() => tick++, 5000);
    return () => clearInterval(timer);
  });

  const active = $derived(isActive(job.status));
  const finishedFiles = $derived(job.done + job.failed);
  const percent = $derived(job.total ? (finishedFiles / job.total) * 100 : 0);
  const left = $derived.by(() => { void tick; return minutesLeft(); });
  const elapsed = $derived.by(() => { void tick; return minutesElapsed(); });

  const statusText = $derived(
    ({
      idle: '', starting: t('detect.starting'), scanning: t('detect.scanning'),
      running: t('detect.running'), stopping: t('detect.stopping'), stopped: t('detect.stopped'),
      finished: t('detect.finished'), failed: t('detect.failedStatus')
    })[job.status]
  );
</script>

<section class="hero">
  <div class="top">
    <div class="count">
      <span class="status">{statusText}</span>
      {#if job.total !== null}
        <span class="big">{finishedFiles} <small>{t('detect.ofFiles', { n: job.total })}</small></span>
      {:else}
        <span class="big"><small>{statusText}</small></span>
      {/if}
    </div>
    <div class="buttons">
      {#if active}
        <Button variant="accent" onclick={onstop} disabled={job.status === 'stopping'}>
          <Icon name="pause" size={14} /> {t('detect.stop')}
        </Button>
      {/if}
      {#if job.runDir}
        <Button variant="accent-outline" onclick={() => showFolder(job.runDir)}>{t('detect.openFolder')}</Button>
      {/if}
    </div>
  </div>
  <ProgressBar percent={percent} label={t('detect.progressLabel')} dim={!active} track="var(--hero-track)" />
  <div class="meta">
    {#if left !== null && active}<span>{t('detect.left', { n: left })}</span>{/if}
    {#if job.startedAt}<span>{t('detect.elapsed', { n: elapsed })}</span>{/if}
    {#if job.batches}<span>{t('detect.batch', { n: job.batch, total: job.batches })}</span>{/if}
    {#if job.alreadyDone}<span>{t('detect.alreadyDone', { n: job.alreadyDone })}</span>{/if}
  </div>
  {#if job.message}<p class="problem">{job.message}</p>{/if}
</section>

<div class={kind === 'detect' ? 'grid-3' : 'grid-2'}>
  {#if kind === 'detect'}
    <StatTile plain value={job.detections.toLocaleString()} label={active ? t('detect.detectionsSoFar') : t('detect.detections')} />
  {/if}
  <StatTile plain value={job.done} label={t('detect.filesDone')} />
  <StatTile plain value={job.failed} label={t('detect.filesFailed')} />
</div>

<Card flush title={t('detect.activity')}>
  {#snippet actions()}
    <Button size="sm" onclick={() => (showLog = !showLog)}>{showLog ? t('detect.hideLog') : t('detect.showLog')}</Button>
  {/snippet}
  {#if showLog}
    <ul class="log mono">
      {#each job.log.slice(-200) as line, i (i)}
        <li class:warn={line.level === 'WARN'} class:error={line.level === 'ERROR'}>
          <span class="time">{line.time}</span><span class="text">{line.text}</span>
        </li>
      {/each}
    </ul>
  {:else if job.rows.length}
    <ul class="rows">
      {#each job.rows as row, i (i)}
        <li>
          <span class="time">{row.time}</span>
          <span class="file mono">{row.rel}</span>
          {#if !row.ok}
            <Badge round palette="peach">{t('detect.failedFile')}{row.message ? ` · ${row.message}` : ''}</Badge>
          {:else if kind === 'filter'}
            <Badge round palette="mint">{t('filter.fileDone')}</Badge>
          {:else if (row.n_detections ?? 0) > 0}
            <Badge round palette="mint">{t('detect.nDetections', { n: row.n_detections ?? 0 })}</Badge>
          {:else}
            <Badge round>{t('detect.none')}</Badge>
          {/if}
        </li>
      {/each}
    </ul>
  {:else}
    <p class="empty">{t('detect.noActivity')}</p>
  {/if}
</Card>

<style>
  .hero {
    --hero-track: rgba(255, 255, 255, 0.75);
    display: flex; flex-direction: column; gap: var(--space-4);
    padding: var(--space-7);
    border-radius: var(--radius-2xl);
    background: var(--accent-tint);
    color: var(--accent-ink);
  }
  :global([data-theme='dark']) .hero { --hero-track: rgba(255, 255, 255, 0.1); }
  .top { display: flex; flex-wrap: wrap; justify-content: space-between; align-items: flex-end; gap: var(--space-4); }
  .count { display: flex; flex-direction: column; gap: var(--space-1); }
  .status { font-size: var(--text-sm); font-weight: var(--weight-semibold); }
  .big { font-size: var(--text-3xl); font-weight: var(--weight-bold); letter-spacing: -0.03em; line-height: 1; }
  .big small { font-size: 22px; font-weight: var(--weight-semibold); letter-spacing: -0.01em; }
  .buttons { display: flex; gap: var(--space-2); }
  .meta { display: flex; flex-wrap: wrap; gap: var(--space-2) var(--space-6); font-size: var(--text-sm); }
  .problem { margin: 0; font-size: var(--text-sm); font-weight: var(--weight-semibold); }

  .rows, .log { list-style: none; margin: 0; padding: 0; max-height: 420px; overflow-y: auto; }
  .rows li {
    display: flex; align-items: center; gap: var(--space-4);
    padding: 11px var(--space-5); border-bottom: 1px solid var(--line); font-size: var(--text-sm);
  }
  .rows li:last-child { border-bottom: 0; }
  .time { width: 64px; flex: none; color: var(--muted); font-variant-numeric: tabular-nums; }
  .file { flex: 1; min-width: 0; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; font-size: 12.5px; }
  .log li { display: flex; gap: var(--space-3); padding: 4px var(--space-5); font-size: 12px; }
  .log .text { white-space: pre-wrap; word-break: break-word; }
  .log li.warn .text { color: var(--peach-ink); }
  .log li.error .text { color: var(--rose-ink); font-weight: var(--weight-semibold); }
  .empty { margin: 0; padding: var(--space-5); color: var(--muted); font-size: var(--text-sm); }
</style>
