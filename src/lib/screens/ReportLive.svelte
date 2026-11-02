<!-- Report step, written by pamflow through the analysis engine. -->
<script lang="ts">
  import { onMount } from 'svelte';
  import PageHeader from '$lib/components/PageHeader.svelte';
  import Card from '$lib/components/Card.svelte';
  import StatTile from '$lib/components/StatTile.svelte';
  import Button from '$lib/components/Button.svelte';
  import Icon from '$lib/components/Icon.svelte';
  import { showFolder, openFile } from '$lib/backend/tauri';
  import { project } from '$lib/backend/project.svelte';
  import { report, loadReportPreview, writeReport } from '$lib/backend/report.svelte';
  import { splitSpecies } from '$lib/species';
  import { t } from '$lib/i18n';

  onMount(() => {
    if (project.folder) loadReportPreview(project.folder);
  });

  const p = $derived(report.preview);
  const writing = $derived(report.status === 'writing');

  let wantHtml = $state(true);
  let wantExcel = $state(true);
  const chosen = $derived([wantHtml && 'html', wantExcel && 'excel'].filter(Boolean) as string[]);

  const sectionList = $derived(
    p ? (['effort', 'detections', 'richness', 'activity', 'validation', 'occupancy'] as const).map((id) => ({
      id, included: p.sections[id]
    })) : []
  );
  const fileLabel: Record<string, string> = { html: 'HTML', excel: 'Excel' };
</script>

<PageHeader stage="report" title={t('report.title')}
  intro={p ? t('report.introLive', { title: p.title, run: p.run_id }) : t('report.introDefault')} />

{#if !project.folder}
  <Card title={t('detect.chooseProject')}>
    <div><Button variant="primary" href="/">{t('detect.goProject')}</Button></div>
  </Card>
{:else if report.status === 'loading' && !p}
  <p class="muted">{t('report.loading')}</p>
{:else if p}
  <div class="grid-4">
    <StatTile value={p.numbers.effort_hours === null ? '–' : p.numbers.effort_hours.toLocaleString()} label={t('report.hours')} palette="sky" />
    <StatTile value={p.numbers.sites ?? '–'} label={t('report.sites')} palette="mint" />
    <StatTile value={p.numbers.events.toLocaleString()} label={t('report.eventsKept')} palette="peach" />
    <StatTile value={p.numbers.species} label={t('report.speciesCount')} palette="lavender" />
  </div>

  <div class="layout">
    <div class="main">
      <Card title={t('report.contentsTitle')} hint={t('report.contentsHint')}>
        <ul class="sections">
          {#each sectionList as s (s.id)}
            <li class:off={!s.included}>
              <span class="mark">{#if s.included}<Icon name="check" size={14} />{:else}–{/if}</span>
              <span class="name">{t(`report.sections.${s.id}`)}</span>
              <span class="note">{s.included ? t('report.included') : t(`report.missing.${s.id}`)}</span>
            </li>
          {/each}
        </ul>
      </Card>

      {#if p.top_species.length}
        <Card title={t('report.speciesTitle')} hint={t('report.speciesHintLive')}>
          <table>
            <thead><tr><th>{t('occupancy.colSpecies')}</th><th>{t('report.colEvents')}</th><th>{t('report.colSites')}</th></tr></thead>
            <tbody>
              {#each p.top_species as sp (sp.species)}
                {@const name = splitSpecies(sp.species)}
                <tr><td>{name.common} <i class="muted">{name.scientific}</i></td><td>{sp.events}</td><td>{sp.sites}</td></tr>
              {/each}
            </tbody>
          </table>
        </Card>
      {/if}
    </div>

    <aside>
      <Card title={t('report.format')}>
        <div class="checks">
          <label><input type="checkbox" bind:checked={wantHtml} disabled={!p.pandoc} /> HTML
            {#if !p.pandoc}<span class="muted">· {t('report.needsPandoc')}</span>{/if}</label>
          <label><input type="checkbox" bind:checked={wantExcel} /> Excel</label>
        </div>
        <p class="muted">{t('report.pdfTip')}</p>
        <Button variant="primary" size="lg" full onclick={() => writeReport(project.folder, chosen)}
          disabled={writing || !chosen.length}>
          {writing ? t('report.writing') : t('report.create')}
        </Button>
        {#if report.message}<p class="problem">{report.message}</p>{/if}
        {#if report.missing.length}
          <p class="problem">{t('report.notWritten', { formats: report.missing.map((f) => fileLabel[f] ?? f).join(', ') })}</p>
        {/if}
      </Card>

      <Card title={t('report.filesTitle')}>
        <ul class="files">
          {#each p.files.filter((f) => f.exists) as f (f.format)}
            <li class:fresh={report.made.includes(f.format)}>
              <div class="fname">
                <b>{fileLabel[f.format]}</b>
                <span class="muted">{f.updated}{f.size_kb !== null ? ` · ${f.size_kb} KB` : ''}</span>
              </div>
              <Button size="sm" onclick={() => openFile(f.path)}>{t('report.open')}</Button>
            </li>
          {:else}
            <li class="muted">{t('report.noFiles')}</li>
          {/each}
        </ul>
        <Button variant="ghost" onclick={() => showFolder(p.reports_dir)}>{t('detect.openFolder')}</Button>
      </Card>
    </aside>
  </div>
{:else if report.status === 'failed'}
  <p class="problem">{report.message}</p>
{/if}

<style>
  .muted { font-size: var(--text-sm); color: var(--muted); }
  .problem { margin: 0; color: var(--rose-ink); font-weight: var(--weight-semibold); font-size: var(--text-sm); }
  .layout { display: flex; flex-wrap: wrap; gap: var(--space-4); align-items: flex-start; }
  .main { flex: 999 1 460px; min-width: 0; display: flex; flex-direction: column; gap: var(--space-4); }
  aside { flex: 1 1 280px; min-width: 0; display: flex; flex-direction: column; gap: var(--space-4); }

  .sections { list-style: none; margin: 0; padding: 0; display: flex; flex-direction: column; }
  .sections li { display: flex; align-items: center; gap: var(--space-3); min-height: 40px; border-bottom: 1px solid var(--line); font-size: var(--text-sm); }
  .sections li:last-child { border-bottom: 0; }
  .mark { width: 22px; height: 22px; border-radius: 6px; display: inline-flex; align-items: center; justify-content: center;
    background: var(--accent-tint); color: var(--accent-ink); font-weight: var(--weight-bold); flex: none; }
  .off .mark { background: var(--soft); color: var(--muted); }
  .name { font-weight: var(--weight-medium); min-width: 160px; }
  .off .name { color: var(--muted); }
  .note { color: var(--muted); }

  table { width: 100%; border-collapse: collapse; font-size: var(--text-sm); }
  th, td { text-align: left; padding: var(--space-2) var(--space-3); border-bottom: 1px solid var(--line); }
  th { color: var(--muted); font-weight: var(--weight-medium); }

  .checks { display: flex; flex-direction: column; }
  .checks label { display: flex; align-items: center; gap: var(--space-3); min-height: 40px; cursor: pointer; font-size: var(--text-sm); }
  .checks input { width: 18px; height: 18px; margin: 0; }
  .files { list-style: none; margin: 0; padding: 0; display: flex; flex-direction: column; gap: var(--space-2); }
  .files li { display: flex; align-items: center; justify-content: space-between; gap: var(--space-3); padding: var(--space-2) var(--space-3); border-radius: var(--radius-md); background: var(--soft); }
  .files li.fresh { background: var(--accent-tint); }
  .files li.muted { background: none; padding: 0; }
  .fname { display: flex; flex-direction: column; }
</style>
