<!-- Report step: demo version, shown when the interface runs in a plain browser (pnpm dev). -->
<script lang="ts">
  import PageHeader from '$lib/components/PageHeader.svelte';
  import Card from '$lib/components/Card.svelte';
  import StatTile from '$lib/components/StatTile.svelte';
  import ProgressBar from '$lib/components/ProgressBar.svelte';
  import Pills from '$lib/components/Pills.svelte';
  import Button from '$lib/components/Button.svelte';
  import { report as r } from '$lib/mock/demo';
  import { t } from '$lib/i18n';

  // Bar colours for the "raw to events" chart, one per cleaning step.
  const funnelColours = ['var(--lavender-ink)', 'var(--peach-ink)', 'var(--sage-ink)'];

  const sectionIds = ['effort', 'detections', 'richness', 'activity', 'validation', 'occupancy'] as const;
  let included = $state<Record<string, boolean>>({
    effort: true, detections: true, richness: true, activity: true, validation: true, occupancy: false
  });

  let format = $state<'html' | 'xlsx'>('html');

  const maxFunnel = Math.max(...r.funnel.map((f) => f.value));
  const totalEvents = r.species.reduce((sum, s) => sum + s.n, 0);
</script>

<PageHeader stage="report" title={t('report.title')} intro={r.subtitle} />

<div class="grid-4">
  <StatTile value={r.recordings} label={t('report.recordings')} palette="sky" />
  <StatTile value={r.rawDetections.toLocaleString()} label={t('report.rawDetections')} palette="lavender" />
  <StatTile value={r.eventsKept} label={t('report.eventsKept')} palette="peach" />
  <StatTile value={r.precision.toFixed(2)} label={t('report.precision')} palette="rose" />
</div>

<div class="layout">
  <div class="main">
    <Card title={t('report.funnelTitle')} hint={t('report.funnelHint')}>
      {#each r.funnel as step, i (step.label)}
        <div class="row">
          <div class="between"><span>{step.label}</span><b>{step.value.toLocaleString()}</b></div>
          <ProgressBar percent={(step.value / maxFunnel) * 100} label={step.label} height={12} fill={funnelColours[i]} />
        </div>
      {/each}
    </Card>

    <Card title={t('report.speciesTitle')} hint={t('report.speciesHint')}>
      {#each r.species as sp, i (sp.name)}
        <div class="species">
          <span>{sp.name}</span>
          <ProgressBar percent={(sp.n / totalEvents) * 100} label={sp.name} height={12}
            fill={i === 0 ? 'var(--accent-ink)' : 'var(--muted)'} />
          <b>{sp.n}</b>
        </div>
      {/each}
    </Card>
  </div>

  <aside>
    <Card title={t('report.include')}>
      <div class="checks">
        {#each sectionIds as id (id)}
          <label><input type="checkbox" bind:checked={included[id]} /> {t(`report.sections.${id}`)}</label>
        {/each}
      </div>
    </Card>
    <Card title={t('report.format')}>
      <Pills label={t('report.format')} bind:value={format} options={[
        { value: 'html', label: 'HTML' },
                { value: 'xlsx', label: 'Excel' }
      ]} />
      <Button variant="primary" size="lg" full>{t('report.create')}</Button>
    </Card>
  </aside>
</div>

<style>
  .layout { display: flex; flex-wrap: wrap; gap: var(--space-4); align-items: flex-start; }
  .main { flex: 999 1 460px; min-width: 0; display: flex; flex-direction: column; gap: var(--space-4); }
  aside { flex: 1 1 280px; min-width: 0; display: flex; flex-direction: column; gap: var(--space-4); }

  .row { display: flex; flex-direction: column; gap: 6px; }
  .between { display: flex; justify-content: space-between; font-size: var(--text-sm); font-variant-numeric: tabular-nums; }
  .species { display: grid; grid-template-columns: 180px 1fr 40px; align-items: center; gap: var(--space-3); font-size: var(--text-sm); }
  .species b { text-align: right; font-variant-numeric: tabular-nums; }

  .checks { display: flex; flex-direction: column; }
  .checks label { display: flex; align-items: center; gap: var(--space-3); min-height: 40px; cursor: pointer; }
  .checks input { width: 18px; height: 18px; margin: 0; }
</style>
