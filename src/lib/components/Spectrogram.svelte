<!--
  Spectrogram panel. For now it draws a demo picture; in Phase 2 it will
  show the PNG that pamflow (R) makes for each clip: pass `src`.
-->
<script lang="ts">
  let { src, label, playhead = 0.4, height = 260 }: {
    src?: string;
    label: string;
    playhead?: number; // 0–1 position across the clip
    height?: number;
  } = $props();
</script>

<div class="spec" style="height: {height}px">
  {#if src}
    <img {src} alt={label} />
  {:else}
    <svg viewBox="0 0 600 240" preserveAspectRatio="none" role="img" aria-label={label}>
      <rect x="0" y="212" width="600" height="28" fill="var(--spec-noise)" opacity="0.35" />
      <rect x="0" y="226" width="600" height="14" fill="var(--spec-noise)" opacity="0.4" />
      <g fill="none" stroke="var(--accent-ink)" stroke-linecap="round" stroke-width="7">
        <path d="M120 120 Q140 98 165 132" />
        <path d="M205 118 Q225 96 250 130" />
        <path d="M290 116 Q310 94 335 128" />
        <path d="M375 118 Q395 96 420 130" />
        <path d="M455 124 Q470 108 488 132" stroke-width="5" opacity="0.7" />
      </g>
      <g fill="none" stroke="var(--accent-ink)" stroke-linecap="round" stroke-width="4" opacity="0.4">
        <path d="M120 62 Q140 40 165 76" />
        <path d="M205 60 Q225 38 250 74" />
        <path d="M290 58 Q310 36 335 72" />
        <path d="M375 60 Q395 38 420 74" />
      </g>
      <rect x="100" y="0" width="400" height="240" fill="var(--accent-ink)" opacity="0.06" />
    </svg>
  {/if}
  <div class="playhead" style="left: {playhead * 100}%"></div>
  <div class="axis" aria-hidden="true"><span>12 kHz</span><span>8</span><span>4</span><span>0</span></div>
</div>

<style>
  .spec { position: relative; border-radius: var(--radius-lg); overflow: hidden; background: var(--spec-bg); }
  svg, img { display: block; width: 100%; height: 100%; object-fit: fill; }
  .playhead { position: absolute; top: 0; bottom: 0; width: 1.5px; background: var(--ink); transition: left 0.1s linear; }
  .axis {
    position: absolute; top: var(--space-2); bottom: var(--space-2); left: var(--space-3);
    display: flex; flex-direction: column; justify-content: space-between;
    font-size: 11px; color: var(--muted);
  }
</style>
