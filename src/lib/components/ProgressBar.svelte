<!-- A rounded progress bar. `percent` is 0–100. -->
<script lang="ts">
  let { percent, label, height = 10, dim = false, track = 'var(--soft)', fill = 'var(--accent-ink)' }: {
    percent: number;
    label: string;
    height?: number;
    dim?: boolean;
    track?: string;
    fill?: string;
  } = $props();

  const clamped = $derived(Math.max(0, Math.min(100, percent)));
</script>

<div class="bar" role="progressbar" aria-label={label} aria-valuenow={Math.round(clamped)}
  aria-valuemin="0" aria-valuemax="100" style="height: {height}px; background: {track}">
  <div class="fill" class:dim style="width: {clamped}%; background: {fill}"></div>
</div>

<style>
  .bar { border-radius: var(--radius-pill); overflow: hidden; }
  .fill { height: 100%; min-width: 6px; border-radius: var(--radius-pill); transition: width 0.3s, opacity 0.2s; }
  .fill.dim { opacity: 0.45; }
</style>
