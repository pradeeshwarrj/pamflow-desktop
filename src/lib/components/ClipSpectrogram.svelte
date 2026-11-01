<!--
  Spectrogram of one validation clip, drawn by the app from the audio:
  pastel colours that follow light/dark mode, the detected seconds
  highlighted, a playhead that follows the audio, and click-to-seek.
  A toggle shows pamflow's own picture instead (also the fallback if the
  audio cannot be decoded). pamflow's files are never changed.
-->
<script lang="ts">
  import { onMount } from 'svelte';
  import { computeSpectrogram, paintSpectrogram, type SpectrogramData } from '$lib/audio/spectrogram';
  import { theme } from '$lib/theme/theme.svelte';
  import { t } from '$lib/i18n';

  let { audioSrc, pictureSrc, audio, eventStart, eventEnd, maxHz = 12000, label }: {
    audioSrc: string;
    pictureSrc: string;          // pamflow's spectrogram PNG
    audio: HTMLAudioElement | null;
    eventStart: number;          // seconds into the clip
    eventEnd: number;
    maxHz?: number;
    label: string;
  } = $props();

  const MODE_KEY = 'pamflow-spectrogram-view';
  let mode = $state<'app' | 'pamflow'>(
    (() => { try { return localStorage.getItem(MODE_KEY) === 'pamflow' ? 'pamflow' : 'app'; } catch { return 'app'; } })()
  );
  function setMode(m: 'app' | 'pamflow') {
    mode = m;
    try { localStorage.setItem(MODE_KEY, m); } catch { /* not remembered */ }
  }

  let box = $state<HTMLDivElement | null>(null);
  let canvas = $state<HTMLCanvasElement | null>(null);
  let data = $state<SpectrogramData | null>(null);
  let failed = $state(false);
  let loading = $state(false);
  let playhead = $state(0); // seconds

  // Decode the clip and compute its spectrogram whenever the clip changes.
  let request = 0;
  $effect(() => {
    const src = audioSrc;
    const mine = ++request;
    data = null;
    failed = false;
    loading = true;
    (async () => {
      try {
        const bytes = await (await fetch(src)).arrayBuffer();
        const ctx = new OfflineAudioContext(1, 1, 48000);
        const buffer = await ctx.decodeAudioData(bytes);
        const cols = Math.min(2400, Math.round((box?.clientWidth ?? 900) * (window.devicePixelRatio || 1)));
        const result = computeSpectrogram(buffer, cols, maxHz);
        if (mine === request) data = result;
      } catch {
        if (mine === request) failed = true;
      } finally {
        if (mine === request) loading = false;
      }
    })();
  });

  // Paint (and repaint when the theme changes).
  $effect(() => {
    void theme.mode;
    if (!canvas || !data || !box) return;
    const css = getComputedStyle(box);
    paintSpectrogram(canvas, data, {
      quiet: css.getPropertyValue('--spec-quiet'),
      middle: css.getPropertyValue('--accent-tint'),
      loud: css.getPropertyValue('--accent-ink')
    });
  });

  // Follow the audio position.
  onMount(() => {
    let frame = 0;
    const loop = () => {
      if (audio) playhead = audio.currentTime;
      frame = requestAnimationFrame(loop);
    };
    frame = requestAnimationFrame(loop);
    return () => cancelAnimationFrame(frame);
  });

  const duration = $derived(data?.duration ?? 0);
  const pct = (s: number) => (duration ? Math.max(0, Math.min(100, (s / duration) * 100)) : 0);
  const showApp = $derived(mode === 'app' && !failed);

  const freqTicks = $derived(
    [1, 2 / 3, 1 / 3, 0].map((f) => ({ f, text: `${Math.round(((data?.maxHz ?? maxHz) * f) / 1000)}` }))
  );
  const timeTicks = $derived.by(() => {
    if (!duration) return [] as number[];
    const step = duration <= 12 ? 1 : duration <= 30 ? 2 : 5;
    const ticks: number[] = [];
    for (let s = 0; s <= duration + 1e-6; s += step) ticks.push(s);
    return ticks;
  });

  function seek(e: MouseEvent) {
    if (!audio || !duration || !box) return;
    const rect = (e.currentTarget as HTMLElement).getBoundingClientRect();
    audio.currentTime = ((e.clientX - rect.left) / rect.width) * duration;
  }
</script>

<div class="wrap" bind:this={box}>
  <div class="views" role="group" aria-label={t('validate.spectrogramView')}>
    <button type="button" class:on={mode === 'app'} onclick={() => setMode('app')} disabled={failed}>{t('validate.viewApp')}</button>
    <button type="button" class:on={mode === 'pamflow'} onclick={() => setMode('pamflow')}>{t('validate.viewPamflow')}</button>
  </div>

  {#if showApp}
    <div class="plot">
      <div class="freq" aria-hidden="true">
        {#each freqTicks as tick (tick.f)}<span>{tick.text}</span>{/each}
      </div>
      <div class="area">
        <button type="button" class="canvas-btn" onclick={seek} aria-label={label}>
          <canvas bind:this={canvas}></canvas>
          {#if loading}<span class="loading">{t('validate.drawingSpec')}</span>{/if}
          {#if duration}
            <span class="event" style="left: {pct(eventStart)}%; width: {pct(eventEnd) - pct(eventStart)}%"></span>
            <span class="playhead" style="left: {pct(playhead)}%"></span>
          {/if}
        </button>
        <div class="time" aria-hidden="true">
          {#each timeTicks as s (s)}<span style="left: {pct(s)}%">{s}</span>{/each}
        </div>
      </div>
    </div>
    <div class="units" aria-hidden="true"><span>kHz</span><span>s</span></div>
  {:else}
    <img class="picture" src={pictureSrc} alt={label} />
  {/if}
</div>

<style>
  .wrap { position: relative; display: flex; flex-direction: column; gap: var(--space-1); }
  .views {
    align-self: flex-end; display: flex; gap: 2px; padding: 2px;
    border-radius: var(--radius-md); background: var(--soft);
  }
  .views button {
    border: 0; background: transparent; color: var(--muted); cursor: pointer;
    font-size: var(--text-xs); font-weight: var(--weight-medium);
    padding: 4px 10px; border-radius: 8px;
  }
  .views button.on { background: var(--raised); color: var(--ink); box-shadow: var(--shadow-raised); }
  .views button:disabled { opacity: 0.4; cursor: default; }

  .plot { display: flex; gap: var(--space-2); }
  .freq {
    display: flex; flex-direction: column; justify-content: space-between;
    height: 240px; font-size: 11px; color: var(--muted); text-align: right; min-width: 18px;
    font-variant-numeric: tabular-nums;
  }
  .area { flex: 1; min-width: 0; }
  .canvas-btn {
    position: relative; display: block; width: 100%; height: 240px; padding: 0; border: 0;
    border-radius: var(--radius-lg); overflow: hidden; cursor: crosshair; background: var(--spec-quiet);
  }
  canvas { display: block; width: 100%; height: 100%; }
  .event {
    position: absolute; top: 0; bottom: 0;
    background: color-mix(in srgb, var(--accent-ink) 12%, transparent);
    border-left: 2px solid var(--accent-ink); border-right: 2px solid var(--accent-ink);
    pointer-events: none;
  }
  .playhead { position: absolute; top: 0; bottom: 0; width: 2px; margin-left: -1px; background: var(--ink); pointer-events: none; }
  .loading { position: absolute; inset: 0; display: flex; align-items: center; justify-content: center; color: var(--muted); font-size: var(--text-sm); }
  .time { position: relative; height: 16px; font-size: 11px; color: var(--muted); font-variant-numeric: tabular-nums; }
  .time span { position: absolute; transform: translateX(-50%); top: 2px; }
  .time span:first-child { transform: none; }
  .units { display: flex; justify-content: space-between; font-size: 11px; color: var(--muted); }
  .picture { display: block; width: 100%; height: auto; border-radius: var(--radius-lg); background: #000; }
</style>
