<!-- Step 6 · Validate: demo version, shown when the interface runs in a plain browser (pnpm dev). -->
<script lang="ts">
  import PageHeader from '$lib/components/PageHeader.svelte';
  import Card from '$lib/components/Card.svelte';
  import ProgressBar from '$lib/components/ProgressBar.svelte';
  import Spectrogram from '$lib/components/Spectrogram.svelte';
  import Button from '$lib/components/Button.svelte';
  import Icon from '$lib/components/Icon.svelte';
  import { validate as v } from '$lib/mock/demo';
  import { accentStyle, type Palette } from '$lib/config/stages';
  import { t } from '$lib/i18n';

  type Verdict = 'correct' | 'wrong' | 'unsure';

  const choices: { id: Verdict; key: string; palette?: Palette }[] = [
    { id: 'correct', key: '1', palette: 'mint' },
    { id: 'wrong', key: '2', palette: 'peach' },
    { id: 'unsure', key: '3' }
  ];

  let verdict = $state<Verdict | null>(null);
  let playing = $state(false);
  let position = $state(1.2);

  const precision = $derived(v.correct / (v.correct + v.wrong));

  function choose(id: Verdict) {
    verdict = verdict === id ? null : id;
  }

  // Keyboard shortcuts: 1 / 2 / 3 to judge, Space to play. Ignored while typing.
  function onKey(e: KeyboardEvent) {
    const tag = (e.target as HTMLElement).tagName;
    if (tag === 'INPUT' || tag === 'SELECT' || tag === 'TEXTAREA') return;
    const choice = choices.find((c) => c.key === e.key);
    if (choice) choose(choice.id);
    if (e.key === ' ') { e.preventDefault(); playing = !playing; }
  }
</script>

<svelte:window onkeydown={onKey} />

<PageHeader stage="validate" title={t('validate.question', { species: v.species })}>
  {#snippet aside()}
    <div class="progress">
      <span class="muted">{t('validate.checked', { done: v.checked, total: v.total })}</span>
      <div class="bar"><ProgressBar percent={(v.checked / v.total) * 100} label={t('validate.checked', { done: v.checked, total: v.total })} height={6} track="var(--line)" /></div>
    </div>
  {/snippet}
</PageHeader>

<div class="layout">
  <div class="main">
    <Card>
      <Spectrogram label={t('validate.spectrogramLabel')} playhead={position / v.clipSeconds} />
      <div class="player">
        <button type="button" class="play" aria-label={playing ? t('validate.pause') : t('validate.play')}
          onclick={() => (playing = !playing)}>
          <Icon name={playing ? 'pause' : 'play'} size={14} />
        </button>
        <label for="scrub" class="visually-hidden">{t('validate.position')}</label>
        <input id="scrub" type="range" min="0" max={v.clipSeconds} step="0.1" bind:value={position} />
        <span class="muted time">{position.toFixed(1)} / {v.clipSeconds.toFixed(1)} s</span>
      </div>
    </Card>

    <div class="grid-3">
      {#each choices as c (c.id)}
        <button type="button" class="choice" class:neutral={!c.palette} class:on={verdict === c.id}
          aria-pressed={verdict === c.id} style={c.palette ? accentStyle(c.palette) : undefined}
          onclick={() => choose(c.id)}>
          <span class="key">{c.key}</span>{t(`validate.${c.id}`)}
        </button>
      {/each}
    </div>

    {#if verdict === 'wrong'}
      <div class="which" style={accentStyle('peach')}>
        <label for="truesp">{t('validate.whatIsIt')}</label>
        <select id="truesp" class="input">
          <option>{t('validate.chooseSpecies')}</option>
          <option>{t('validate.noise')}</option>
        </select>
      </div>
    {/if}

    <div class="nav">
      <Button variant="ghost">{t('validate.previous')}</Button>
      <Button variant="ghost">{t('validate.skip')}</Button>
    </div>
  </div>

  <aside>
    <Card title={t('validate.thisDetection')}>
      <dl>
        <dt>{t('validate.birdnet')}</dt><dd>{v.species}</dd>
        <dt>{t('validate.confidence')}</dt><dd class="accent">{v.confidence.toFixed(2)}</dd>
        <dt>{t('validate.site')}</dt><dd>{v.site}</dd>
        <dt>{t('validate.recorded')}</dt><dd>{v.recorded}</dd>
        <dt>{t('validate.clip')}</dt><dd>{v.clip}</dd>
      </dl>
    </Card>
    <Card title={t('validate.session')}>
      <div class="tally">
        <div style={accentStyle('mint')}><b>{v.correct}</b>{t('validate.correctCount')}</div>
        <div style={accentStyle('peach')}><b>{v.wrong}</b>{t('validate.wrongCount')}</div>
        <div class="neutral"><b>{v.unsure}</b>{t('validate.unsureCount')}</div>
      </div>
      <span class="muted">{t('validate.precision')} <b class="ink">{precision.toFixed(2)}</b> · {t('validate.saved')}</span>
    </Card>
    <span class="muted keys">{t('validate.keys')}</span>
  </aside>
</div>

<style>
  .progress { display: flex; flex-direction: column; align-items: flex-end; gap: var(--space-2); }
  .bar { width: 200px; }
  .muted { font-size: var(--text-sm); color: var(--muted); }
  .ink { color: var(--ink); }

  .layout { display: flex; flex-wrap: wrap; gap: var(--space-5); align-items: flex-start; }
  .main { flex: 999 1 520px; min-width: 0; display: flex; flex-direction: column; gap: var(--space-4); }
  aside { flex: 1 1 260px; min-width: 0; display: flex; flex-direction: column; gap: var(--space-4); }

  .player { display: flex; align-items: center; gap: var(--space-4); }
  .player input { flex: 1; }
  .play {
    width: 44px; height: 44px; flex: none; border-radius: 50%; border: 0;
    display: flex; align-items: center; justify-content: center;
    background: var(--ink); color: var(--surface); cursor: pointer;
  }
  .time { font-variant-numeric: tabular-nums; }

  .choice {
    display: flex; align-items: center; justify-content: center; gap: var(--space-3);
    min-height: 56px; border-radius: var(--radius-xl);
    border: 2px solid transparent;
    background: var(--accent-tint); color: var(--accent-ink);
    font-weight: var(--weight-semibold); cursor: pointer;
  }
  .choice.neutral { background: var(--soft); color: var(--ink); }
  .choice.on { border-color: currentColor; }
  .key {
    width: 22px; height: 22px; border-radius: 6px;
    display: inline-flex; align-items: center; justify-content: center;
    font-size: var(--text-xs); background: rgba(255, 255, 255, 0.7);
  }
  :global([data-theme='dark']) .key { background: rgba(0, 0, 0, 0.25); }

  .which {
    display: flex; flex-wrap: wrap; align-items: center; gap: var(--space-3);
    padding: var(--space-3) var(--space-4); border-radius: var(--radius-xl);
    background: var(--accent-tint); color: var(--accent-ink); font-weight: var(--weight-semibold);
  }
  .which select { flex: 1; min-width: 200px; background: var(--surface); color: var(--ink); font-weight: var(--weight-regular); }
  .nav { display: flex; justify-content: space-between; }

  dl { margin: 0; display: grid; grid-template-columns: auto 1fr; gap: var(--space-2) var(--space-4); font-size: var(--text-sm); }
  dt { color: var(--muted); }
  dd { margin: 0; }
  .accent { color: var(--accent-ink); font-weight: var(--weight-semibold); }

  .tally { display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); gap: var(--space-2); text-align: center; }
  .tally div {
    display: flex; flex-direction: column; padding: 10px var(--space-1);
    border-radius: var(--radius-lg); background: var(--accent-tint); color: var(--accent-ink);
    font-size: var(--text-xs);
  }
  .tally div.neutral { background: var(--soft); color: var(--muted); }
  .tally b { font-size: 20px; }
  .tally .neutral b { color: var(--ink); }
  .keys { padding: 0 var(--space-1); font-size: var(--text-xs); }
</style>
