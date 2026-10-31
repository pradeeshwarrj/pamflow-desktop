<!--
  Small coloured label. <Badge palette="mint">site G0059</Badge>
  With no palette it is neutral grey.
-->
<script lang="ts">
  import type { Snippet } from 'svelte';
  import type { Palette } from '$lib/config/stages';
  import { accentStyle } from '$lib/config/stages';

  let { palette, round = false, children }: { palette?: Palette; round?: boolean; children?: Snippet } = $props();
</script>

<span class="badge" class:round class:neutral={!palette} style={palette ? accentStyle(palette) : undefined}>
  {@render children?.()}
</span>

<style>
  .badge {
    display: inline-flex;
    align-items: center;
    padding: var(--space-1) var(--space-2);
    border-radius: var(--radius-sm);
    font-size: var(--text-xs);
    font-weight: var(--weight-medium);
    background: var(--accent-tint);
    color: var(--accent-ink);
    white-space: nowrap;
  }
  .badge.round { border-radius: var(--radius-pill); padding: 3px 9px; }
  .badge.neutral { background: var(--soft); color: var(--muted); }
</style>
