<!-- Step 5 · Process, connected to pamflow through the analysis engine. -->
<script lang="ts">
  import { onMount } from 'svelte';
  import PageHeader from '$lib/components/PageHeader.svelte';
  import Card from '$lib/components/Card.svelte';
  import Button from '$lib/components/Button.svelte';
  import Badge from '$lib/components/Badge.svelte';
  import ProcessResults from './ProcessResults.svelte';
  import { showFolder } from '$lib/backend/tauri';
  import { project, refreshProject } from '$lib/backend/project.svelte';
  import { detectJob, isActive } from '$lib/backend/detect.svelte';
  import { processJob, loadProcessResults, runProcess } from '$lib/backend/process.svelte';
  import { t } from '$lib/i18n';

  onMount(() => {
    if (project.folder && !project.facts && !project.checking) refreshProject();
    if (project.folder && !processJob.summary) loadProcessResults(project.folder);
  });

  const rules = $derived(project.facts?.processing);
  const detecting = $derived(isActive(detectJob.status));
  const running = $derived(processJob.status === 'running');
  const summary = $derived(processJob.summary?.available ? processJob.summary : null);
</script>

<PageHeader stage="process" title={t('process.title')} intro={t('process.intro')} />

{#if !project.folder}
  <Card title={t('detect.chooseProject')}>
    <div><Button variant="primary" href="/">{t('detect.goProject')}</Button></div>
  </Card>
{:else}
  <Card title={t('process.rulesTitle')} hint={t('process.rulesHint')}>
    {#if rules}
      <dl>
        <dt>{t('process.minConfidence')}</dt>
        <dd>
          {rules.thresholds_file
            ? t('process.perSpecies', { file: rules.thresholds_file })
            : (rules.min_confidence ?? '–')}
        </dd>
        <dt>{t('process.outsideDeployment')}</dt>
        <dd>{rules.drop_outside_deployment ? t('process.dropped') : t('process.kept')}</dd>
        <dt>{t('process.mergeGap')}</dt><dd>{t('process.seconds', { n: rules.merge_gap_s })}</dd>
        {#if rules.n_whitelist}<dt>{t('process.whitelist')}</dt><dd>{t('process.nSpecies', { n: rules.n_whitelist })}</dd>{/if}
        {#if rules.n_blacklist}<dt>{t('process.blacklist')}</dt><dd>{t('process.nSpecies', { n: rules.n_blacklist })}</dd>{/if}
        {#if rules.date_range?.length === 2}<dt>{t('process.dates')}</dt><dd>{rules.date_range.join(' – ')}</dd>{/if}
        {#if rules.season_file}<dt>{t('process.seasons')}</dt><dd>{rules.season_file}</dd>{/if}
      </dl>
    {/if}
    <div class="actions">
      <Button variant="primary" size="lg" onclick={() => runProcess(project.folder)} disabled={running || detecting}>
        {running ? t('process.running') : summary ? t('process.runAgain') : t('process.run')}
      </Button>
      {#if summary}
        <Button onclick={() => showFolder(summary.out_dir)}>{t('detect.openFolder')}</Button>
        <span class="muted">{t('process.updated', { when: summary.updated ?? '' })}</span>
      {/if}
      {#if detecting}<Badge palette="peach">{t('process.waitDetect')}</Badge>{/if}
    </div>
    {#if processJob.status === 'failed'}
      <p class="problem">{processJob.message}</p>
      {#if processJob.log.length}<pre class="log">{processJob.log.slice(-15).join('\n')}</pre>{/if}
    {/if}
  </Card>

  {#if summary}
    <ProcessResults {summary} />
  {:else if processJob.status === 'done' || processJob.summary?.available === false}
    <Card title={t('process.noResultsTitle')} hint={t('process.noResultsHint')} />
  {/if}
{/if}

<style>
  dl { margin: 0; display: grid; grid-template-columns: auto 1fr; gap: var(--space-2) var(--space-6); font-size: var(--text-sm); }
  dt { color: var(--muted); }
  dd { margin: 0; }
  .actions { display: flex; flex-wrap: wrap; align-items: center; gap: var(--space-3); margin-top: var(--space-2); }
  .muted { font-size: var(--text-sm); color: var(--muted); }
  .problem { margin: 0; color: var(--rose-ink); font-weight: var(--weight-semibold); font-size: var(--text-sm); }
  .log { margin: 0; white-space: pre-wrap; font-family: var(--font-mono); font-size: 12px; color: var(--muted); }
</style>
