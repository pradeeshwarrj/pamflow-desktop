<!--
  A detection history as a grid: one row per site, one square per occasion.
  Filled = detected (1), pale = surveyed but not detected (0),
  outlined = not surveyed (NA).
-->
<script lang="ts">
  import type { History } from '$lib/backend/occupancy.svelte';
  import { t } from '$lib/i18n';

  let { history }: { history: History } = $props();

  const nOcc = $derived(history.occasions.length);
  const cell = $derived(nOcc > 90 ? 6 : nOcc > 45 ? 9 : nOcc > 20 ? 13 : 18);
</script>

<div class="wrap">
  <div class="scroll">
    <div class="grid" style="grid-template-columns: max-content repeat({nOcc}, {cell}px); --cell: {cell}px">
      {#each history.rows as row, i (history.sites[i])}
        <span class="site">{history.sites[i]}</span>
        {#each row.split('') as v, j (j)}
          <span class="c" class:d={v === '1'} class:n={v === '0'} class:x={v === '.'}
            title="{history.sites[i]} · {history.occasions[j]} · {v === '1' ? t('occupancy.detected') : v === '0' ? t('occupancy.notDetected') : t('occupancy.notSurveyed')}"></span>
        {/each}
      {/each}
    </div>
  </div>
  <div class="axis">
    <span>{history.occasions[0] ?? ''}</span>
    <span>{t('occupancy.nOccasions', { n: nOcc })}</span>
    <span>{history.occasions[nOcc - 1] ?? ''}</span>
  </div>
  <div class="legend">
    <span><i class="c d"></i>{t('occupancy.detected')}</span>
    <span><i class="c n"></i>{t('occupancy.notDetected')}</span>
    <span><i class="c x"></i>{t('occupancy.notSurveyed')}</span>
  </div>
</div>

<style>
  .wrap { display: flex; flex-direction: column; gap: var(--space-2); }
  .scroll { overflow: auto; max-height: 460px; }
  .grid { display: grid; gap: 2px; align-items: center; }
  .site { font-size: 11px; color: var(--muted); padding-right: var(--space-2); font-variant-numeric: tabular-nums; white-space: nowrap; }
  .c { display: inline-block; width: var(--cell, 12px); height: var(--cell, 12px); border-radius: 3px; box-sizing: border-box; }
  .d { background: var(--accent-ink); }
  .n { background: var(--accent-tint); }
  .x { border: 1px dashed var(--line); background: transparent; }
  .axis { display: flex; justify-content: space-between; font-size: 11px; color: var(--muted); }
  .legend { display: flex; flex-wrap: wrap; gap: var(--space-4); font-size: var(--text-xs); color: var(--muted); }
  .legend span { display: inline-flex; align-items: center; gap: var(--space-2); }
  .legend .c { width: 12px; height: 12px; }
</style>
