<!-- Step 2 · Scan: read and check the recordings (pamflow Stage 1). -->
<script lang="ts">
  import { onMount } from 'svelte';
  import PageHeader from '$lib/components/PageHeader.svelte';
  import Card from '$lib/components/Card.svelte';
  import StatTile from '$lib/components/StatTile.svelte';
  import Button from '$lib/components/Button.svelte';
  import Badge from '$lib/components/Badge.svelte';
  import { showFolder } from '$lib/backend/tauri';
  import { project, refreshProject } from '$lib/backend/project.svelte';
  import { detectJob, isActive } from '$lib/backend/detect.svelte';
  import { scan, loadScan, runScan } from '$lib/backend/scan.svelte';
  import { t } from '$lib/i18n';

  onMount(() => {
    if (project.folder && scan.status === 'idle') loadScan(project.folder);
    if (project.folder && !project.facts && !project.checking) refreshProject();
  });

  const s = $derived(scan.summary);
  const scanning = $derived(scan.status === 'scanning');
  let force = $state(false);
  let showLog = $state(false);

  async function start() {
    await runScan(project.folder, force);
    refreshProject(); // the Project screen and sidebar show the new scan
  }

  const issueList = $derived(
    s?.issues ? (Object.entries(s.issues) as [string, number][]).map(([id, n]) => ({ id, n })) : []
  );
  const gridCols = $derived(s?.per_grid?.length ? Object.keys(s.per_grid[0]) : []);
  const header = (c: string) => c.replace(/_/g, ' ');
  const fmt = (v: unknown) => (typeof v === 'string' && /^\d{4}-\d\d-\d\dT/.test(v) ? v.slice(0, 16).replace('T', ' ') : String(v ?? ''));
</script>

<PageHeader stage="scan" title={t('scan.title')} intro={t('scan.intro')} />

{#if !project.folder}
  <Card title={t('detect.chooseProject')}>
    <div><Button variant="primary" href="/">{t('detect.goProject')}</Button></div>
  </Card>
{:else}
  <Card title={t('scan.runTitle')} hint={s?.audio_folder ? t('scan.folder', { folder: s.audio_folder }) : ''}>
    <label class="check"><input type="checkbox" bind:checked={force} /> {t('scan.force')}</label>
    <div class="actions">
      <Button variant="primary" size="lg" onclick={start} disabled={scanning || isActive(detectJob.status)}>
        {scanning ? t('scan.scanning') : s?.available ? t('scan.again') : t('scan.run')}
      </Button>
      {#if s?.available}
        <Button onclick={() => s?.metadata_folder && showFolder(s.metadata_folder)}>{t('detect.openFolder')}</Button>
        <span class="muted">{t('scan.updated', { when: s.updated ?? '' })}</span>
      {/if}
      {#if isActive(detectJob.status)}<Badge palette="peach">{t('process.waitDetect')}</Badge>{/if}
    </div>
    {#if scanning}<p class="muted">{t('scan.scanningHint')}</p>{/if}
    {#if scan.message}
      <p class="problem">{scan.message}</p>
      {#if scan.log.length}
        <div><Button size="sm" onclick={() => (showLog = !showLog)}>{showLog ? t('detect.hideLog') : t('detect.showLog')}</Button></div>
        {#if showLog}<pre class="log">{scan.log.join('\n')}</pre>{/if}
      {/if}
    {/if}
  </Card>

  {#if s?.available}
    <div class="grid-4">
      <StatTile value={(s.n_files ?? 0).toLocaleString()} label={t('scan.files')} />
      <StatTile value={s.n_grids ?? 0} label={t('scan.grids')} palette="sky" />
      <StatTile value={(s.total_hours ?? 0).toLocaleString()} label={t('scan.hours')} palette="lavender" />
      <StatTile value={(s.n_qc_pass ?? 0).toLocaleString()} label={t('scan.pass')} palette="sage" />
    </div>

    <Card title={t('scan.checksTitle')} hint={t('scan.checksHint')}>
      <ul class="issues">
        {#each issueList as issue (issue.id)}
          <li class:ok={issue.n === 0}>
            <span class="name">{t(`scan.issues.${issue.id}`)}</span>
            <span class="hint">{t(`scan.issueHints.${issue.id}`)}</span>
            {#if issue.n === 0}<Badge palette="mint">{t('scan.none')}</Badge>
            {:else}<Badge palette="peach">{issue.n.toLocaleString()}</Badge>{/if}
          </li>
        {/each}
      </ul>
    </Card>

    {#if s.per_grid?.length}
      <Card title={t('scan.gridsTitle')} hint={t('scan.gridsHint')}>
        <div class="table-wrap">
          <table>
            <thead><tr>{#each gridCols as c (c)}<th>{header(c)}</th>{/each}</tr></thead>
            <tbody>
              {#each s.per_grid as row, i (i)}
                <tr>{#each gridCols as c (c)}<td>{fmt(row[c])}</td>{/each}</tr>
              {/each}
            </tbody>
          </table>
        </div>
      </Card>
    {/if}

    {#if s.deployment_issues?.length}
      <Card title={t('scan.deploymentTitle')} hint={t('scan.deploymentHint')}>
        <div class="table-wrap">
          <table>
            <thead><tr>{#each Object.keys(s.deployment_issues[0]) as c (c)}<th>{header(c)}</th>{/each}</tr></thead>
            <tbody>
              {#each s.deployment_issues as row, i (i)}
                <tr>{#each Object.keys(s.deployment_issues[0]) as c (c)}<td>{fmt(row[c])}</td>{/each}</tr>
              {/each}
            </tbody>
          </table>
        </div>
      </Card>
    {/if}
  {:else if scan.status === 'ready'}
    <Card title={t('scan.noneYet')} hint={t('scan.noneYetHint')} />
  {/if}
{/if}

<style>
  .muted { margin: 0; font-size: var(--text-sm); color: var(--muted); }
  .problem { margin: 0; color: var(--rose-ink); font-weight: var(--weight-semibold); font-size: var(--text-sm); }
  .log { margin: 0; max-height: 280px; overflow: auto; padding: var(--space-3); border-radius: var(--radius-md, 8px);
    background: var(--surface-2, var(--bg)); font-family: var(--font-mono); font-size: var(--text-xs, 12px); white-space: pre-wrap; }
  .actions { display: flex; flex-wrap: wrap; align-items: center; gap: var(--space-3); }
  .check { display: flex; align-items: center; gap: var(--space-2); font-size: var(--text-sm); cursor: pointer; }
  .check input { width: 18px; height: 18px; margin: 0; }
  .issues { list-style: none; margin: 0; padding: 0; }
  .issues li { display: grid; grid-template-columns: 200px 1fr auto; align-items: center; gap: var(--space-3);
    min-height: 44px; border-bottom: 1px solid var(--line); font-size: var(--text-sm); }
  .issues li:last-child { border-bottom: 0; }
  .name { font-weight: var(--weight-medium); }
  .ok .name { color: var(--muted); font-weight: var(--weight-regular); }
  .hint { color: var(--muted); }
  .table-wrap { overflow-x: auto; max-height: 420px; }
  table { width: 100%; border-collapse: collapse; font-size: var(--text-sm); }
  th, td { text-align: left; padding: var(--space-2) var(--space-3); border-bottom: 1px solid var(--line); white-space: nowrap; }
  th { color: var(--muted); font-weight: var(--weight-medium); position: sticky; top: 0; background: var(--surface); }
</style>
