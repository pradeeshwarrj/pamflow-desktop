<!--
  A big number with a label.
  <StatTile value="63" label="recordings" palette="sky" />   pastel tile
  <StatTile value="63" label="recordings" plain />           white card tile
  With no palette it uses the current step's colour.
-->
<script lang="ts">
  import type { Palette } from '$lib/config/stages';
  import { accentStyle } from '$lib/config/stages';

  let { value, label, palette, plain = false }: {
    value: string | number;
    label: string;
    palette?: Palette;
    plain?: boolean;
  } = $props();
</script>

<div class="tile" class:plain style={palette ? accentStyle(palette) : undefined}>
  <div class="value">{value}</div>
  <div class="label">{label}</div>
</div>

<style>
  .tile {
    padding: var(--space-4) var(--space-5);
    border-radius: var(--radius-xl);
    background: var(--accent-tint);
    color: var(--accent-ink);
  }
  .tile.plain { background: var(--surface); border: 1px solid var(--line); color: var(--ink); }
  .value { font-size: var(--text-xl); font-weight: var(--weight-bold); letter-spacing: -0.02em; }
  .label { font-size: var(--text-sm); }
  .plain .label { color: var(--muted); }
</style>
