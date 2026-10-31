<!--
  All icons in one place. Use: <Icon name="play" />
  To add an icon, add its SVG path(s) to `paths` (24×24 grid, stroke style).
-->
<script lang="ts" module>
  const paths = {
    sun: 'M12 8a4 4 0 1 0 0 8a4 4 0 1 0 0-8z M12 2v2 M12 20v2 M4.9 4.9l1.4 1.4 M17.7 17.7l1.4 1.4 M2 12h2 M20 12h2 M4.9 19.1l1.4-1.4 M17.7 6.3l1.4-1.4',
    moon: 'M20 14.5A8 8 0 0 1 9.5 4a8 8 0 1 0 10.5 10.5z',
    arrowRight: 'M5 12h14 M13 6l6 6-6 6',
    sheet: 'M6 3h12a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2z M4 9h16 M4 15h16 M10 3v18',
    folder: 'M3 7a2 2 0 0 1 2-2h4l2 2h8a2 2 0 0 1 2 2v8a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z',
    check: 'M5 12l5 5 9-10'
  } as const;

  /** Icons drawn as solid shapes rather than lines. */
  const solid = {
    play: 'M7 4l13 8-13 8z',
    pause: 'M6 4h4v16H6z M14 4h4v16h-4z'
  } as const;

  export type IconName = keyof typeof paths | keyof typeof solid;
</script>

<script lang="ts">
  let { name, size = 18 }: { name: IconName; size?: number } = $props();
</script>

{#if name in solid}
  <svg width={size} height={size} viewBox="0 0 24 24" fill="currentColor" aria-hidden="true">
    <path d={solid[name as keyof typeof solid]} />
  </svg>
{:else}
  <svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke="currentColor"
    stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
    <path d={paths[name as keyof typeof paths]} />
  </svg>
{/if}
