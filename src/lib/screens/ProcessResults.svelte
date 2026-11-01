<!--
  Results of cleaning the detections: totals, what each rule removed, and
  the most detected species. Used by the live screen and the demo.
-->
<script lang="ts">
  import Card from '$lib/components/Card.svelte';
  import StatTile from '$lib/components/StatTile.svelte';
  import ProgressBar from '$lib/components/ProgressBar.svelte';
  import type { ProcessSummary } from '$lib/backend/process.svelte';
  import { t } from '$lib/i18n';

  let { summary }: { summary: ProcessSummary } = $props();

  /** pamflow's rule names, shown in plain words (falls back to pamflow's text). */
  function ruleLabel(rule: string): string {
    const key = `process.rules.${rule}`;
    const label = t(key);
    return label === key ? rule : label;
  }

  const isMerge = (rule: string) => rule.startsWith('merged');

  // One row per rule that removed something, with what was left afterwards.
  const funnel = $derived(
    summary.steps
      .filter((s) => s.n_removed > 0 || isMerge(s.rule))
      .map((s) => ({
        label: ruleLabel(s.rule),
        removed: s.n_removed,
        left: s.n_before - s.n_removed,
        merge: isMerge(s.rule)
      }))
  );
  const untouched = $derived(
    summary.steps.filter((s) => s.n_removed === 0 && !isMerge(s.rule)).map((s) => ruleLabel(s.rule))
  );
  const maxSpecies = $derived(Math.max(1, ...summary.species.map((s) => s.events)));
</script>

<div class="grid-4">
  <StatTile value={summary.raw.toLocaleString()} label={t('process.raw')} palette="lavender" />
  <StatTile value={summary.removed.toLocaleString()} label={t('process.removed')} palette="peach" />
  <StatTile value={summary.events.toLocaleString()} label={t('process.events')} palette="sage" />
  <StatTile value={summary.n_species} label={t('process.species')} palette="sky" />
</div>

<div class="layout">
  <Card title={t('process.funnelTitle')} hint={t('process.funnelHint')}>
    <div class="row">
      <div class="between"><span>{t('process.allDetections')}</span><b>{summary.raw.toLocaleString()}</b></div>
      <ProgressBar percent={100} label={t('process.allDetections')} height={12} fill="var(--lavender-ink)" />
    </div>
    {#each funnel as step (step.label)}
      <div class="row">
        <div class="between">
          <span>{step.merge ? t('process.mergedInto') : step.label}</span>
          <span>{#if step.removed > 0}<span class="minus">−{step.removed.toLocaleString()}</span> {/if}<b>{step.left.toLocaleString()}</b></span>
        </div>
        <ProgressBar percent={summary.raw ? (step.left / summary.raw) * 100 : 0} label={step.label}
          height={12} fill={step.merge ? 'var(--sage-ink)' : 'var(--peach-ink)'} />
      </div>
    {/each}
    {#if untouched.length}
      <p class="muted">{t('process.untouched')} {untouched.join(' · ')}</p>
    {/if}
  </Card>

  <Card title={t('process.speciesTitle')} hint={t('process.speciesHint', { n: summary.n_species })}>
    {#if summary.species.length}
      {#each summary.species as sp, i (i)}
        <div class="species">
          <div class="names">
            <span>{sp.common_name}</span>
            <i>{sp.scientific_name}</i>
          </div>
          <ProgressBar percent={(sp.events / maxSpecies) * 100} label={sp.common_name} height={10} />
          <b>{sp.events}</b>
        </div>
      {/each}
    {:else}
      <p class="muted">{t('process.noEvents')}</p>
    {/if}
  </Card>
</div>

<style>
  .layout { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: var(--space-4); align-items: start; }
  @media (max-width: 900px) { .layout { grid-template-columns: minmax(0, 1fr); } }
  .row { display: flex; flex-direction: column; gap: 6px; }
  .between { display: flex; justify-content: space-between; gap: var(--space-3); font-size: var(--text-sm); font-variant-numeric: tabular-nums; }
  .minus { color: var(--peach-ink); margin-right: var(--space-2); }
  .muted { margin: 0; font-size: var(--text-sm); color: var(--muted); }
  .species { display: grid; grid-template-columns: minmax(0, 1.4fr) minmax(0, 1fr) 36px; align-items: center; gap: var(--space-3); font-size: var(--text-sm); }
  .names { display: flex; flex-direction: column; min-width: 0; }
  .names span, .names i { overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
  .names i { font-size: var(--text-xs); color: var(--muted); }
  .species b { text-align: right; font-variant-numeric: tabular-nums; }
</style>
