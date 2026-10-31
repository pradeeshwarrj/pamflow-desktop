<!-- Top of every screen: step chip, title, optional intro and right-side content. -->
<script lang="ts">
  import type { Snippet } from 'svelte';
  import { stageNumber } from '$lib/config/stages';
  import { t } from '$lib/i18n';

  let { stage, title, intro, aside }: {
    stage: string;
    title: string;
    intro?: string;
    aside?: Snippet;
  } = $props();
</script>

<header>
  <div class="text">
    <span class="chip">{t('common.step', { n: stageNumber(stage), name: t(`stages.${stage}`) })}</span>
    <h1>{title}</h1>
    {#if intro}<p>{intro}</p>{/if}
  </div>
  {#if aside}<div class="aside">{@render aside()}</div>{/if}
</header>

<style>
  header { display: flex; flex-wrap: wrap; justify-content: space-between; align-items: flex-end; gap: var(--space-4); }
  .text { display: flex; flex-direction: column; gap: var(--space-3); }
  .chip {
    align-self: flex-start;
    padding: var(--space-1) var(--space-3);
    border-radius: var(--radius-pill);
    font-size: var(--text-xs);
    font-weight: var(--weight-semibold);
    background: var(--accent-tint);
    color: var(--accent-ink);
  }
  h1 { font-size: var(--text-2xl); font-weight: var(--weight-bold); letter-spacing: -0.02em; line-height: 1.2; }
  p { max-width: 580px; color: var(--muted); line-height: 1.55; }
</style>
