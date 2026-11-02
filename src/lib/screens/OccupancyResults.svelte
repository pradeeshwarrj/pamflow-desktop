<!--
  Detection histories: per-species summary (naive occupancy) and the history
  grid of the chosen species. Used by the live screen and the demo.
-->
<script lang="ts">
  import Card from '$lib/components/Card.svelte';
  import StatTile from '$lib/components/StatTile.svelte';
  import ProgressBar from '$lib/components/ProgressBar.svelte';
  import HistoryGrid from '$lib/components/HistoryGrid.svelte';
  import type { OccupancyInfo } from '$lib/backend/occupancy.svelte';
  import { splitSpecies } from '$lib/species';
  import { t } from '$lib/i18n';

  let { info, selected = $bindable() }: { info: OccupancyInfo; selected: string } = $props();

  const summary = $derived(info.summary ?? []);
  const histories = $derived(info.histories ?? []);
  const current = $derived(histories.find((h) => h.species === selected) ?? histories[0]);
  const nSites = $derived(summary[0]?.n_sites ?? 0);
  const nOcc = $derived(summary[0]?.n_occasions ?? 0);
  const surveyed = $derived.by(() => {
    const h = histories[0];
    if (!h) return null;
    const cells = h.rows.join('');
    return cells.length ? 1 - (cells.split('.').length - 1) / cells.length : null;
  });
</script>

<div class="grid-4">
  <StatTile value={summary.length} label={t('occupancy.species')} palette="butter" />
  <StatTile value={nSites} label={t('occupancy.sites')} palette="sky" />
  <StatTile value={nOcc} label={t('occupancy.occasions')} palette="mint" />
  <StatTile value={surveyed === null ? '–' : `${Math.round(surveyed * 100)}%`} label={t('occupancy.surveyed')} palette="lavender" />
</div>

<Card title={t('occupancy.summaryTitle')} hint={t('occupancy.summaryHint')}>
  <div class="table-wrap">
    <table>
      <thead><tr>
        <th>{t('occupancy.colSpecies')}</th><th>{t('occupancy.colSites')}</th>
        <th class="wide">{t('occupancy.colNaive')}</th><th>{t('occupancy.colThreshold')}</th>
      </tr></thead>
      <tbody>
        {#each summary as row (row.species)}
          {@const name = splitSpecies(row.species)}
          <tr class:on={row.species === (current?.species ?? '')}>
            <td>
              <button type="button" class="pick" onclick={() => (selected = row.species)}>
                <span>{name.common}</span><i>{name.scientific}</i>
              </button>
            </td>
            <td>{row.n_sites_detected} / {row.n_sites}</td>
            <td class="wide">
              <div class="naive">
                <ProgressBar percent={row.naive_occupancy * 100} label={name.common} height={8} />
                <b>{row.naive_occupancy.toFixed(2)}</b>
              </div>
            </td>
            <td>{row.threshold_used}</td>
          </tr>
        {/each}
      </tbody>
    </table>
  </div>
</Card>

{#if current}
  {@const name = splitSpecies(current.species)}
  <Card title={t('occupancy.historyTitle', { species: name.common })} hint={t('occupancy.historyHint')}>
    <HistoryGrid history={current} />
  </Card>
{/if}

<style>
  .table-wrap { overflow-x: auto; }
  table { width: 100%; border-collapse: collapse; font-size: var(--text-sm); }
  th, td { text-align: left; padding: var(--space-2) var(--space-3); border-bottom: 1px solid var(--line); white-space: nowrap; }
  th { color: var(--muted); font-weight: var(--weight-medium); }
  .wide { width: 40%; }
  tr.on td { background: var(--accent-tint); }
  .pick { display: flex; flex-direction: column; align-items: flex-start; border: 0; background: none; padding: 0; color: inherit; font: inherit; cursor: pointer; text-align: left; }
  .pick i { font-size: var(--text-xs); color: var(--muted); }
  .naive { display: grid; grid-template-columns: 1fr 40px; align-items: center; gap: var(--space-3); }
  .naive b { text-align: right; font-variant-numeric: tabular-nums; }
</style>
