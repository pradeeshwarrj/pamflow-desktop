<!-- Detect step, connected to pamflow through the analysis engine. -->
<script lang="ts">
  import { onMount } from 'svelte';
  import PageHeader from '$lib/components/PageHeader.svelte';
  import Card from '$lib/components/Card.svelte';
  import Badge from '$lib/components/Badge.svelte';
  import Button from '$lib/components/Button.svelte';
  import Pills from '$lib/components/Pills.svelte';
  import Icon from '$lib/components/Icon.svelte';
  import LongJobPanel from '$lib/components/LongJobPanel.svelte';
  import { runtimeInfo, type RuntimeInfo } from '$lib/backend/tauri';
  import { project, refreshProject } from '$lib/backend/project.svelte';
  import {
    detectJob, startDetect, stopDetect, isActive, minutesLeft, minutesElapsed
  } from '$lib/backend/detect.svelte';
  import { t } from '$lib/i18n';

  const TEST_FILES = 5;

  let runtime = $state<RuntimeInfo | null>(null);

  onMount(() => {
    runtimeInfo().then((r) => (runtime = r));
    if (project.folder && !project.facts && !project.checking) refreshProject();
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
    <LongJobPanel job={detectJob} kind="detect" onstop={stopDetect} {minutesLeft} {minutesElapsed} />
  {/if}
{/if}

<style>
  .field { display: flex; flex-direction: column; gap: var(--space-2); min-width: 0; }
  .label { font-weight: var(--weight-semibold); }
  .muted { font-size: var(--text-sm); color: var(--muted); }
  .actions { display: flex; flex-wrap: wrap; align-items: center; gap: var(--space-3); margin-top: var(--space-2); }
  .message { margin: 0; white-space: pre-wrap; font-size: var(--text-sm); color: var(--muted); }
</style>
