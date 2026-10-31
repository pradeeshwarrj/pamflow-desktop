<!-- Step 4 · Detect -->
<script lang="ts">
  import PageHeader from '$lib/components/PageHeader.svelte';
  import Card from '$lib/components/Card.svelte';
  import StatTile from '$lib/components/StatTile.svelte';
  import ProgressBar from '$lib/components/ProgressBar.svelte';
  import Badge from '$lib/components/Badge.svelte';
  import Button from '$lib/components/Button.svelte';
  import Icon from '$lib/components/Icon.svelte';
  import { detect } from '$lib/mock/demo';
  import type { Palette } from '$lib/config/stages';
  import { t } from '$lib/i18n';

  let paused = $state(false);
  const percent = $derived((detect.done / detect.total) * 100);

  const logColour: Record<string, Palette | undefined> = { ok: 'mint', warn: 'peach', none: undefined };
</script>

<PageHeader stage="detect" title={t('detect.title')} intro={t('detect.intro', { grid: detect.grid })} />

<section class="hero">
  <div class="top">
    <div class="count">
      <span class="status">{paused ? t('detect.paused') : t('detect.running')}</span>
      <span class="big">{detect.done} <small>{t('detect.ofFiles', { n: detect.total })}</small></span>
    </div>
    <div class="buttons">
      <Button variant="accent" onclick={() => (paused = !paused)}>
        <Icon name={paused ? 'play' : 'pause'} size={14} />
        {paused ? t('detect.resume') : t('detect.pause')}
      </Button>
      <Button variant="accent-outline">{t('detect.stop')}</Button>
    </div>
  </div>
  <ProgressBar percent={percent} label={t('detect.progressLabel')} dim={paused} track="var(--hero-track)" />
  <div class="meta">
    <span>{t('detect.left', { n: detect.minutesLeft })}</span>
    <span>{t('detect.elapsed', { n: detect.minutesElapsed })}</span>
    <span>{t('detect.workers', { n: detect.workers })}</span>
  </div>
</section>

<div class="grid-3">
  <StatTile plain value={detect.detections.toLocaleString()} label={t('detect.detectionsSoFar')} />
  <StatTile plain value={detect.minConfidence.toFixed(2)} label={t('detect.minConfidence')} />
  <StatTile plain value={detect.skipped} label={t('detect.skipped')} />
</div>

<Card flush title={t('detect.activity')}>
  {#snippet actions()}<Button size="sm">{t('detect.openFolder')}</Button>{/snippet}
  <ul class="log">
    {#each detect.log as line (line.time)}
      <li>
        <span class="time">{line.time}</span>
        <span class="file mono">{line.file}</span>
        <Badge round palette={logColour[line.kind]}>{line.note}</Badge>
      </li>
    {/each}
  </ul>
</Card>

<style>
  .hero {
    --hero-track: rgba(255, 255, 255, 0.75);
    display: flex; flex-direction: column; gap: var(--space-4);
    padding: var(--space-7);
    border-radius: var(--radius-2xl);
    background: var(--accent-tint);
    color: var(--accent-ink);
  }
  :global([data-theme='dark']) .hero { --hero-track: rgba(255, 255, 255, 0.1); }
  .top { display: flex; flex-wrap: wrap; justify-content: space-between; align-items: flex-end; gap: var(--space-4); }
  .count { display: flex; flex-direction: column; gap: var(--space-1); }
  .status { font-size: var(--text-sm); font-weight: var(--weight-semibold); }
  .big { font-size: var(--text-3xl); font-weight: var(--weight-bold); letter-spacing: -0.03em; line-height: 1; }
  .big small { font-size: 22px; font-weight: var(--weight-semibold); letter-spacing: -0.01em; }
  .buttons { display: flex; gap: var(--space-2); }
  .meta { display: flex; flex-wrap: wrap; gap: var(--space-2) var(--space-6); font-size: var(--text-sm); }

  .log { list-style: none; margin: 0; padding: 0; }
  .log li {
    display: flex; align-items: center; gap: var(--space-4);
    padding: 11px var(--space-5);
    border-bottom: 1px solid var(--line);
    font-size: var(--text-sm);
  }
  .log li:last-child { border-bottom: 0; }
  .time { width: 64px; color: var(--muted); font-variant-numeric: tabular-nums; }
  .file { flex: 1; min-width: 0; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; font-size: 12.5px; }
</style>
