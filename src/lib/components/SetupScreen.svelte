<!--
  Shown once, the first time an installed pamflow starts: unpacks the analysis
  engine (R, Python, BirdNET, ffmpeg) that came inside the installer. Offline.
-->
<script lang="ts">
  import { onMount } from 'svelte';
  import Logo from './Logo.svelte';
  import Button from './Button.svelte';
  import Icon from './Icon.svelte';
  import { setup, startSetup } from '$lib/backend/setup.svelte';
  import { t } from '$lib/i18n';

  const STEPS = ['space', 'unpack', 'extras', 'check'] as const;
  const order = (p: string) => (STEPS as readonly string[]).indexOf(p);

  onMount(() => {
    if (!setup.running && !setup.problem) startSetup();
  });

  // a local clock between events, so the time keeps moving during long steps
  let tick = $state(0);
  let base = 0;
  let baseAt = Date.now();
  $effect(() => { base = setup.seconds; baseAt = Date.now(); });
  onMount(() => {
    const id = setInterval(() => (tick = Math.floor((Date.now() - baseAt) / 1000)), 1000);
    return () => clearInterval(id);
  });
  const shown = $derived(setup.running ? base + tick : setup.seconds);
  const clock = (s: number) => `${Math.floor(s / 60)}:${String(s % 60).padStart(2, '0')}`;
  let showLog = $state(false);
  const failed = $derived(setup.phase === 'failed' || !!setup.problem);
</script>

<div class="wrap">
  <section class="card">
    <div class="head">
      <Logo size={48} />
      <div>
        <h1>{t('setup.title')}</h1>
        <p class="muted">{t('setup.intro')}</p>
      </div>
    </div>

    <ol>
      {#each STEPS as s (s)}
        {@const state = failed && setup.step === s ? 'fail'
          : order(setup.step) > order(s) || setup.step === 'done' ? 'done'
          : setup.step === s ? 'now' : 'todo'}
        <li class={state}>
          <span class="mark">
            {#if state === 'done'}<Icon name="check" size={14} />{:else if state === 'now'}<span class="spin"></span>{:else if state === 'fail'}!{/if}
          </span>
          {t(`setup.steps.${s}`)}
        </li>
      {/each}
    </ol>

    {#if !failed}
      <p class="muted">{t('setup.time', { time: clock(shown) })}</p>
    {:else}
      <p class="problem">{setup.problem || setup.message}</p>
      <div class="actions">
        {#if !setup.problem}<Button variant="primary" onclick={startSetup}>{t('setup.retry')}</Button>{/if}
        {#if setup.log.length}
          <Button onclick={() => (showLog = !showLog)}>{showLog ? t('detect.hideLog') : t('detect.showLog')}</Button>
        {/if}
      </div>
      {#if showLog}<pre class="log">{setup.log.join('\n')}</pre>{/if}
    {/if}
    {#if setup.target}<p class="small mono">{setup.target}</p>{/if}
  </section>
</div>

<style>
  .wrap { min-height: 100vh; display: grid; place-items: center; padding: var(--space-8); }
  .card { width: min(560px, 100%); display: flex; flex-direction: column; gap: var(--space-5);
    padding: var(--space-8); border-radius: var(--radius-xl); background: var(--surface); border: 1px solid var(--line); }
  .head { display: flex; gap: var(--space-4); align-items: center; }
  h1 { margin: 0; font-size: var(--text-xl); }
  .muted { margin: 0; color: var(--muted); font-size: var(--text-sm); }
  .small { margin: 0; color: var(--muted); font-size: var(--text-xs); overflow-wrap: anywhere; }
  ol { list-style: none; margin: 0; padding: 0; display: flex; flex-direction: column; gap: var(--space-3); }
  li { display: flex; align-items: center; gap: var(--space-3); color: var(--muted); }
  li.now, li.done { color: var(--text); }
  li.now { font-weight: var(--weight-semibold); }
  li.fail { color: var(--rose-ink); font-weight: var(--weight-semibold); }
  .mark { width: 24px; height: 24px; border-radius: 50%; display: grid; place-items: center; flex: none;
    background: var(--soft); font-size: var(--text-xs); }
  .done .mark { background: var(--mint-tint); color: var(--mint-ink); }
  .fail .mark { background: var(--rose-tint); color: var(--rose-ink); }
  .spin { width: 12px; height: 12px; border-radius: 50%; border: 2px solid var(--line); border-top-color: var(--sky-ink);
    animation: spin 0.9s linear infinite; }
  @keyframes spin { to { transform: rotate(360deg); } }
  .problem { margin: 0; color: var(--rose-ink); font-weight: var(--weight-semibold); font-size: var(--text-sm); white-space: pre-wrap; }
  .actions { display: flex; gap: var(--space-2); }
  .log { margin: 0; max-height: 240px; overflow: auto; padding: var(--space-3); border-radius: var(--radius-md);
    background: var(--soft); font-family: var(--font-mono); font-size: var(--text-xs); white-space: pre-wrap; }
</style>
