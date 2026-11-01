<!-- Step 4 · Detect, connected to pamflow through the analysis engine. -->
<script lang="ts">
  import { onMount } from 'svelte';
  import PageHeader from '$lib/components/PageHeader.svelte';
  import Card from '$lib/components/Card.svelte';
  import StatTile from '$lib/components/StatTile.svelte';
  import ProgressBar from '$lib/components/ProgressBar.svelte';
  import Badge from '$lib/components/Badge.svelte';
  import Button from '$lib/components/Button.svelte';
  import Pills from '$lib/components/Pills.svelte';
  import Icon from '$lib/components/Icon.svelte';
  import { runtimeInfo, showFolder, type RuntimeInfo } from '$lib/backend/tauri';
  import { project, refreshProject } from '$lib/backend/project.svelte';
  import {
    detectJob, startDetect, stopDetect, isActive, minutesLeft, minutesElapsed
  } from '$lib/backend/detect.svelte';
  import { t } from '$lib/i18n';

  const TEST_FILES = 5;

  let runtime = $state<RuntimeInfo | null>(null);
  let tick = $state(0); // refreshes the elapsed / time-left text
  let showLog = $state(false);

  onMount(() => {
    runtimeInfo().then((r) => (runtime = r));
    if (project.folder && !project.facts && !project.checking) refreshProject();
    const timer = setInterval(() => tick++, 5000);
    return () => clearInterval(timer);
  });

  const facts = $derived(project.facts);
  const physical = $derived(facts?.cores_physical ?? 4);
  const logical = $derived(facts?.cores_logical ?? physical);

  // Worker choices: a few common values up to "all but two" physical cores.
  const workerChoices = $derived(
    [...new Set([2, 4, 8, 12, Math.max(1, physical - 2)])]
      .filter((n) => n >= 1 && n <= Math.max(1, physical - 1) && n <= logical)
      .sort((a, b) => a - b)
  );
  let workers = $state(0);
  $effect(() => {
    if (!workers && workerChoices.length) {
      const fromConfig = facts?.workers ?? Math.max(1, Math.floor(physical / 2));
      workers = workerChoices.reduce((best, n) =>
        Math.abs(n - fromConfig) < Math.abs(best - fromConfig) ? n : best, workerChoices[0]);
    }
  });

  let scope = $state<'test' | 'all'>('test');

  const active = $derived(isActive(detectJob.status));
  const finishedFiles = $derived(detectJob.done + detectJob.failed);
  const percent = $derived(detectJob.total ? (finishedFiles / detectJob.total) * 100 : 0);
  // `tick` changes every 5 s so these recalculate while a job runs
  const left = $derived.by(() => { void tick; return minutesLeft(); });
  const elapsed = $derived.by(() => { void tick; return minutesElapsed(); });

  const statusText = $derived(
    ({
      idle: '', starting: t('detect.starting'), scanning: t('detect.scanning'),
      running: t('detect.running'), stopping: t('detect.stopping'), stopped: t('detect.stopped'),
      finished: t('detect.finished'), failed: t('detect.failedStatus')
    })[detectJob.status]
  );

  const canStart = $derived(!!project.folder && !!runtime?.found && !active);
  const startLabel = $derived(
    detectJob.status === 'stopped' || detectJob.alreadyDone > 0 ? t('detect.continue') : t('detect.start')
  );

  function start() {
    startDetect(project.folder, { workers, sampleN: scope === 'test' ? TEST_FILES : null });
  }
</script>

<PageHeader stage="detect" title={t('detect.title')}
  intro={facts ? t('detect.intro', { grid: facts.root.split(/[\\/]/).pop() ?? '' }) : undefined} />

{#if runtime && !runtime.found}
  <Card title={t('detect.noEngine')}>
    <pre class="message">{runtime.message}</pre>
  </Card>
{:else if !project.folder}
  <Card title={t('detect.chooseProject')}>
    <div><Button variant="primary" href="/">{t('detect.goProject')}</Button></div>
  </Card>
{:else}
  {#if !active}
    <Card title={t('detect.settings')} hint={t('detect.settingsHint')}>
      <div class="grid-2">
        <div class="field">
          <span class="label">{t('project.workers')}</span>
          <Pills label={t('project.workers')} bind:value={workers}
            options={workerChoices.map((n) => ({ value: n, label: String(n) }))} />
          <span class="muted">{t('project.workersHint', { n: physical })}</span>
        </div>
        <div class="field">
          <span class="label">{t('detect.files')}</span>
          <Pills label={t('detect.files')} bind:value={scope} options={[
            { value: 'test', label: t('detect.testFew', { n: TEST_FILES }) },
            { value: 'all', label: t('detect.allFiles') }
          ]} />
        </div>
      </div>
      <div class="actions">
        <Button variant="primary" size="lg" onclick={start} disabled={!canStart}>
          <Icon name="play" size={14} /> {startLabel}
        </Button>
        {#if facts && !facts.model_found}
          <Badge palette="peach">{t('project.modelMissing', { file: facts.model_file ?? '' })}</Badge>
        {/if}
      </div>
    </Card>
  {/if}

  {#if detectJob.status !== 'idle'}
    <section class="hero" class:quiet={!active}>
      <div class="top">
        <div class="count">
          <span class="status">{statusText}</span>
          {#if detectJob.total !== null}
            <span class="big">{finishedFiles} <small>{t('detect.ofFiles', { n: detectJob.total })}</small></span>
          {:else}
            <span class="big"><small>{statusText}</small></span>
          {/if}
        </div>
        <div class="buttons">
          {#if active}
            <Button variant="accent" onclick={stopDetect} disabled={detectJob.status === 'stopping'}>
              <Icon name="pause" size={14} /> {t('detect.stop')}
            </Button>
          {/if}
          {#if detectJob.runDir}
            <Button variant="accent-outline" onclick={() => showFolder(detectJob.runDir)}>{t('detect.openFolder')}</Button>
          {/if}
        </div>
      </div>
      <ProgressBar percent={percent} label={t('detect.progressLabel')} dim={!active} track="var(--hero-track)" />
      <div class="meta">
        {#if left !== null && active}<span>{t('detect.left', { n: left })}</span>{/if}
        {#if detectJob.startedAt}<span>{t('detect.elapsed', { n: elapsed })}</span>{/if}
        {#if detectJob.batches}<span>{t('detect.batch', { n: detectJob.batch, total: detectJob.batches })}</span>{/if}
        {#if detectJob.alreadyDone}<span>{t('detect.alreadyDone', { n: detectJob.alreadyDone })}</span>{/if}
      </div>
      {#if detectJob.message}<p class="problem">{detectJob.message}</p>{/if}
    </section>

    <div class="grid-3">
      <StatTile plain value={detectJob.detections.toLocaleString()} label={active ? t('detect.detectionsSoFar') : t('detect.detections')} />
      <StatTile plain value={detectJob.done} label={t('detect.filesDone')} />
      <StatTile plain value={detectJob.failed} label={t('detect.filesFailed')} />
    </div>

    <Card flush title={t('detect.activity')}>
      {#snippet actions()}
        <Button size="sm" onclick={() => (showLog = !showLog)}>{showLog ? t('detect.hideLog') : t('detect.showLog')}</Button>
      {/snippet}
      {#if showLog}
        <ul class="log mono">
          {#each detectJob.log.slice(-200) as line, i (i)}
            <li class:warn={line.level === 'WARN'} class:error={line.level === 'ERROR'}>
              <span class="time">{line.time}</span><span class="text">{line.text}</span>
            </li>
          {/each}
        </ul>
      {:else if detectJob.rows.length}
        <ul class="rows">
          {#each detectJob.rows as row, i (i)}
            <li>
              <span class="time">{row.time}</span>
              <span class="file mono">{row.rel}</span>
              {#if !row.ok}
                <Badge round palette="peach">{t('detect.failedFile')}{row.message ? ` · ${row.message}` : ''}</Badge>
              {:else if row.n_detections > 0}
                <Badge round palette="mint">{t('detect.nDetections', { n: row.n_detections })}</Badge>
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
  {/if}
{/if}

<style>
  .field { display: flex; flex-direction: column; gap: var(--space-2); min-width: 0; }
  .label { font-weight: var(--weight-semibold); }
  .muted { font-size: var(--text-sm); color: var(--muted); }
  .actions { display: flex; flex-wrap: wrap; align-items: center; gap: var(--space-3); margin-top: var(--space-2); }
  .message { margin: 0; white-space: pre-wrap; font-size: var(--text-sm); color: var(--muted); }

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
  .problem { font-size: var(--text-sm); font-weight: var(--weight-semibold); }

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
  .empty { padding: var(--space-5); color: var(--muted); font-size: var(--text-sm); }
</style>
