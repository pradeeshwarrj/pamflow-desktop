<!-- pamflow mark: a waveform on a soft square. Colours follow the theme. -->
<script lang="ts">
  let { size = 28 }: { size?: number } = $props();
</script>

<svg width={size} height={size} viewBox="0 0 28 28" aria-hidden="true">
  <rect width="28" height="28" rx="8" fill="var(--sky-tint)" />
  <path d="M6 14h3l2-6 3 12 3-9 2 3h3" fill="none" stroke="var(--sky-ink)"
    stroke-width="2" stroke-linecap="round" stroke-linejoin="round" />
</svg>
