<!-- Validate step, connected to pamflow's validation files. -->
<script lang="ts">
  import { onMount, tick } from 'svelte';
  import PageHeader from '$lib/components/PageHeader.svelte';
  import Card from '$lib/components/Card.svelte';
  import ProgressBar from '$lib/components/ProgressBar.svelte';
  import ClipSpectrogram from '$lib/components/ClipSpectrogram.svelte';
  import Button from '$lib/components/Button.svelte';
  import Pills from '$lib/components/Pills.svelte';
  import Icon from '$lib/components/Icon.svelte';
  import { showFolder } from '$lib/backend/tauri';
  import { project } from '$lib/backend/project.svelte';
  import {
    validation, loadValidation, drawRound, saveAnswer, nextOpen, loadMetrics, setReviewer,
    clipUrl, specUrl, commonOf, type Verdict
  } from '$lib/backend/validation.svelte';
  import { accentStyle, type Palette } from '$lib/config/stages';
  import { t } from '$lib/i18n';

  onMount(() => {
    if (project.folder && validation.status === 'idle') loadValidation(project.folder);
  });

  const info = $derived(validation.info);
  const samples = $derived(info?.samples ?? []);
  const current = $derived(samples[validation.pos]);
  const answer = $derived(current ? validation.answers[current.sample_id] : undefined);
  const nAnswered = $derived(samples.filter((s) => validation.answers[s.sample_id]).length);
  const tally = $derived.by(() => {
    const c = { correct: 0, incorrect: 0, unsure: 0 };
    for (const s of samples) {
      const a = validation.answers[s.sample_id];
      if (a) c[a.verdict]++;
    }
    return c;
  });
  const precision = $derived(
    tally.correct + tally.incorrect ? tally.correct / (tally.correct + tally.incorrect) : null
  );
  const allDone = $derived(samples.length > 0 && nAnswered === samples.length);

  // ---- drawing a round ----
  let showDraw = $state(false);
  let strategy = $state<'stratified' | 'random' | 'rare'>('stratified');
  let nRandom = $state(100);
  const drawing = $derived(validation.status === 'drawing');

  // ---- audio ----
  let audio = $state<HTMLAudioElement | null>(null);
  let playing = $state(false);
  let position = $state(0);
  let stopAt: number | null = null;

  function playWhole() {
    if (!audio) return;
    stopAt = null;
    if (playing) audio.pause(); else audio.play();
  }
  function playEvent() {
    if (!audio || !current) return;
    stopAt = current.event_end_offset_s;
    audio.currentTime = current.event_offset_s;
    audio.play();
  }
  function onTime() {
    if (!audio) return;
    position = audio.currentTime;
    if (stopAt !== null && audio.currentTime >= stopAt) {
      audio.pause();
      stopAt = null;
    }
  }

  // ---- answering ----
  let trueSpecies = $state('');
  let note = $state('');
  let speciesInput = $state<HTMLInputElement | null>(null);

  $effect(() => {
    // when the sample changes, show its earlier answer (if any) and reset audio
    void current?.sample_id;
    trueSpecies = answer?.true_species ?? '';
    note = answer?.note ?? '';
    playing = false;
    position = 0;
  });

  async function choose(verdict: Verdict) {
    if (!current) return;
    try {
      await saveAnswer(current, verdict, verdict === 'incorrect' ? trueSpecies : '', note);
    } catch {
      return; // error is shown on screen
    }
    if (verdict === 'incorrect') {
      await tick();
      speciesInput?.focus();
    } else {
      nextOpen();
    }
  }

  async function confirmWrong() {
    if (!current) return;
    try {
      await saveAnswer(current, 'incorrect', trueSpecies, note);
      nextOpen();
    } catch { /* shown on screen */ }
  }

  async function saveNote() {
    if (current && answer) {
      try { await saveAnswer(current, answer.verdict, answer.true_species, note); } catch { /* shown */ }
    }
  }

  function onKey(e: KeyboardEvent) {
    const tag = (e.target as HTMLElement).tagName;
    if (tag === 'INPUT' || tag === 'SELECT' || tag === 'TEXTAREA' || !current) return;
    if (e.key === '1') choose('correct');
    else if (e.key === '2') choose('incorrect');
    else if (e.key === '3') choose('unsure');
    else if (e.key === ' ') { e.preventDefault(); playWhole(); }
    else if (e.key === 'e' || e.key === 'E') playEvent();
    else if (e.key === 'ArrowRight') validation.pos = Math.min(samples.length - 1, validation.pos + 1);
    else if (e.key === 'ArrowLeft') validation.pos = Math.max(0, validation.pos - 1);
  }

  const choices: { id: Verdict; key: string; palette?: Palette; label: string }[] = [
    { id: 'correct', key: '1', palette: 'mint', label: 'validate.correct' },
    { id: 'incorrect', key: '2', palette: 'peach', label: 'validate.wrong' },
    { id: 'unsure', key: '3', label: 'validate.unsure' }
  ];

  // common names for the precision table, from the samples and the event pool
  const commonNames = $derived.by(() => {
    const names: Record<string, string> = {};
    for (const s of info?.pool?.species ?? []) names[s.scientific_name] = s.common_name;
    for (const s of samples) names[s.scientific_name] = s.common_name;
    return names;
  });

  const pct = (x: number | null) => (x === null ? '–' : `${Math.round(x * 100)}%`);
</script>

<svelte:window onkeydown={onKey} />

{#if !project.folder}
  <PageHeader stage="validate" title={t('validate.titleLive')} />
  <Card title={t('detect.chooseProject')}>
    <div><Button variant="primary" href="/">{t('detect.goProject')}</Button></div>
  </Card>
{:else if validation.status === 'loading' || validation.status === 'idle'}
  <PageHeader stage="validate" title={t('validate.titleLive')} />
  <p class="muted">{t('validate.loading')}</p>
{:else}
  {#if current && !showDraw}
    <PageHeader stage="validate" title={t('validate.question', { species: current.common_name })}>
      {#snippet aside()}
        <div class="progress">
          <span class="muted">{t('validate.checked', { done: nAnswered, total: samples.length })}</span>
          <div class="bar"><ProgressBar percent={samples.length ? (nAnswered / samples.length) * 100 : 0}
            label={t('validate.checked', { done: nAnswered, total: samples.length })} height={6} track="var(--line)" /></div>
        </div>
      {/snippet}
    </PageHeader>
  {:else}
    <PageHeader stage="validate" title={t('validate.titleLive')} intro={t('validate.introLive')} />
  {/if}

  {#if validation.message}<p class="problem">{validation.message}</p>{/if}

  {#if showDraw || !samples.length}
    <Card title={t('validate.drawTitle')} hint={info?.pool ? t('validate.poolHint', { n: info.pool.n_events, s: info.pool.species.length }) : ''}>
      <Pills label={t('validate.drawTitle')} bind:value={strategy} options={[
        { value: 'stratified', label: t('validate.byConfidence') },
        { value: 'random', label: t('validate.random') },
        { value: 'rare', label: t('validate.rare') }
      ]} />
      <p class="muted">{t(`validate.${strategy}Hint`)}</p>
      {#if strategy === 'random'}
        <label class="inline">{t('validate.howMany')}
          <input class="input small" type="number" min="1" max="2000" bind:value={nRandom} />
        </label>
      {/if}
      <div class="actions">
        <Button variant="primary" size="lg" disabled={drawing}
          onclick={async () => { await drawRound(project.folder, strategy, nRandom); showDraw = false; }}>
          {drawing ? (validation.drawLabel || t('validate.drawing')) : t('validate.draw')}
        </Button>
        {#if samples.length}<Button variant="ghost" onclick={() => (showDraw = false)} disabled={drawing}>{t('validate.backToReview')}</Button>{/if}
      </div>
    </Card>
  {:else if current}
    <div class="layout">
      <div class="main">
        <Card>
          <audio bind:this={audio} src={clipUrl(current)} preload="auto"
            onplay={() => (playing = true)} onpause={() => (playing = false)} onended={() => (playing = false)}
            ontimeupdate={onTime}></audio>
          <ClipSpectrogram audioSrc={clipUrl(current)} pictureSrc={specUrl(current)} {audio}
            eventStart={current.event_offset_s} eventEnd={current.event_end_offset_s}
            maxHz={info?.spec_max_hz ?? 12000} label={t('validate.spectrogramLabel')} />
          <div class="player">
            <button type="button" class="play" aria-label={playing ? t('validate.pause') : t('validate.play')} onclick={playWhole}>
              <Icon name={playing ? 'pause' : 'play'} size={14} />
            </button>
            <label for="scrub" class="visually-hidden">{t('validate.position')}</label>
            <input id="scrub" type="range" min="0" max={current.clip_dur_s} step="0.05" value={position}
              oninput={(e) => audio && (audio.currentTime = Number((e.target as HTMLInputElement).value))} />
            <span class="muted time">{position.toFixed(1)} / {current.clip_dur_s.toFixed(1)} s</span>
            <Button size="sm" onclick={playEvent}>{t('validate.playEvent')}</Button>
          </div>
          <span class="muted">{t('validate.eventAt', { from: current.event_offset_s.toFixed(1), to: current.event_end_offset_s.toFixed(1) })}</span>
        </Card>

        <div class="grid-3">
          {#each choices as c (c.id)}
            <button type="button" class="choice" class:neutral={!c.palette} class:on={answer?.verdict === c.id}
              aria-pressed={answer?.verdict === c.id} style={c.palette ? accentStyle(c.palette) : undefined}
              onclick={() => choose(c.id)}>
              <span class="key">{c.key}</span>{t(c.label)}
            </button>
          {/each}
        </div>

        {#if answer?.verdict === 'incorrect'}
          <div class="which" style={accentStyle('peach')}>
            <label for="truesp">{t('validate.whatIsIt')}</label>
            <input id="truesp" class="input" list="species-list" bind:this={speciesInput} bind:value={trueSpecies}
              placeholder={t('validate.chooseSpecies')}
              onkeydown={(e) => e.key === 'Enter' && confirmWrong()} />
            <datalist id="species-list">
              <option value="(none: noise or no animal sound)"></option>
              {#each info?.labels ?? [] as label (label)}<option value={label}>{commonOf(label)}</option>{/each}
              <option value="(other / unknown)"></option>
            </datalist>
            <Button variant="accent" onclick={confirmWrong}>{t('validate.saveNext')}</Button>
          </div>
        {/if}

        <div class="note">
          <label for="note" class="muted">{t('validate.note')}</label>
          <input id="note" class="input" bind:value={note} onchange={saveNote} placeholder={t('validate.notePlaceholder')} />
        </div>
        {#if validation.saveError}<p class="problem">{t('validate.notSaved')} {validation.saveError}</p>{/if}

        <div class="nav">
          <Button variant="ghost" onclick={() => (validation.pos = Math.max(0, validation.pos - 1))}>{t('validate.previous')}</Button>
          <span class="muted">{validation.pos + 1} / {samples.length}</span>
          <Button variant="ghost" onclick={() => (validation.pos = Math.min(samples.length - 1, validation.pos + 1))}>{t('validate.skip')}</Button>
        </div>
      </div>

      <aside>
        <Card title={t('validate.thisDetection')}>
          <dl>
            <dt>{t('validate.birdnet')}</dt><dd>{current.common_name}<br /><i class="muted">{current.scientific_name}</i></dd>
            {#if info?.show_confidence}<dt>{t('validate.confidence')}</dt><dd class="accent">{current.confidence.toFixed(2)}</dd>{/if}
            <dt>{t('validate.site')}</dt><dd>{current.grid}</dd>
            {#if current.recorder}<dt>{t('validate.recorder')}</dt><dd>{current.recorder}</dd>{/if}
            <dt>{t('validate.recorded')}</dt><dd>{current.detection_datetime}</dd>
            <dt>{t('validate.round')}</dt><dd>{current.round} · {current.strategy}</dd>
          </dl>
        </Card>
        <Card title={t('validate.session')}>
          <div class="tally">
            <div style={accentStyle('mint')}><b>{tally.correct}</b>{t('validate.correctCount')}</div>
            <div style={accentStyle('peach')}><b>{tally.incorrect}</b>{t('validate.wrongCount')}</div>
            <div class="neutral"><b>{tally.unsure}</b>{t('validate.unsureCount')}</div>
          </div>
          <span class="muted">{t('validate.precision')} <b class="ink">{pct(precision)}</b> · {t('validate.saved')}</span>
        </Card>
        <Card title={t('validate.reviewer')} labelFor="reviewer">
          <input id="reviewer" class="input" value={validation.reviewer}
            onchange={(e) => setReviewer((e.target as HTMLInputElement).value)} placeholder={t('validate.reviewerHint')} />
        </Card>
        <div class="side-actions">
          <Button onclick={() => (showDraw = true)}>{t('validate.drawMore')}</Button>
          <Button variant="ghost" onclick={() => info && showFolder(info.val_dir)}>{t('detect.openFolder')}</Button>
        </div>
        <span class="muted keys">{t('validate.keysLive')}</span>
      </aside>
    </div>

    {#if allDone}
      <Card title={t('validate.allDone', { n: samples.length })} hint={t('validate.allDoneHint')} />
    {/if}

    <Card title={t('validate.precisionTitle')} hint={t('validate.precisionHint')}>
      {#snippet actions()}
        <Button size="sm" onclick={() => loadMetrics(project.folder)} disabled={validation.metricsStatus === 'loading' || !nAnswered}>
          {validation.metricsStatus === 'loading' ? t('validate.calculating') : t('validate.calculate')}
        </Button>
      {/snippet}
      {#if validation.metrics?.length}
        <div class="table-wrap">
          <table>
            <thead><tr>
              <th>{t('validate.species')}</th><th>{t('validate.colReviewed')}</th><th>{t('validate.correct')}</th>
              <th>{t('validate.colWrong')}</th><th>{t('validate.colUnsure')}</th><th>{t('validate.colPrecision')}</th>
            </tr></thead>
            <tbody>
              {#each validation.metrics as m (m.scientific_name)}
                <tr>
                  <td>{#if commonNames[m.scientific_name]}{commonNames[m.scientific_name]}<br />{/if}<i class="muted">{m.scientific_name}</i></td><td>{m.n_reviewed}</td><td>{m.n_correct}</td>
                  <td>{m.n_incorrect}</td><td>{m.n_unsure}</td>
                  <td><b>{pct(m.precision)}</b>
                    {#if m.ci_low !== null && m.ci_high !== null}<span class="muted"> ({pct(m.ci_low)}–{pct(m.ci_high)})</span>{/if}</td>
                </tr>
              {/each}
            </tbody>
          </table>
        </div>
        <span class="muted">{t('validate.tablesSaved')}</span>
      {:else if validation.metricsStatus === 'failed'}
        <p class="problem">{t('validate.metricsFailed')}</p>
      {/if}
    </Card>
  {/if}
{/if}

<style>
  .progress { display: flex; flex-direction: column; align-items: flex-end; gap: var(--space-2); }
  .bar { width: 200px; }
  .muted { font-size: var(--text-sm); color: var(--muted); }
  .ink { color: var(--ink); }
  .problem { margin: 0; color: var(--rose-ink); font-weight: var(--weight-semibold); font-size: var(--text-sm); }
  .actions, .side-actions { display: flex; flex-wrap: wrap; align-items: center; gap: var(--space-3); }
  .inline { display: flex; align-items: center; gap: var(--space-3); font-size: var(--text-sm); }
  .small { width: 110px; }

  .layout { display: flex; flex-wrap: wrap; gap: var(--space-5); align-items: flex-start; }
  .main { flex: 999 1 520px; min-width: 0; display: flex; flex-direction: column; gap: var(--space-4); }
  aside { flex: 1 1 260px; min-width: 0; display: flex; flex-direction: column; gap: var(--space-4); }

  .player { display: flex; align-items: center; gap: var(--space-4); }
  .player input { flex: 1; min-width: 0; }
  .play {
    width: 44px; height: 44px; flex: none; border-radius: 50%; border: 0;
    display: flex; align-items: center; justify-content: center;
    background: var(--ink); color: var(--surface); cursor: pointer;
  }
  .time { font-variant-numeric: tabular-nums; white-space: nowrap; }

  .choice {
    display: flex; align-items: center; justify-content: center; gap: var(--space-3);
    min-height: 56px; border-radius: var(--radius-xl); border: 2px solid transparent;
    background: var(--accent-tint); color: var(--accent-ink);
    font-weight: var(--weight-semibold); cursor: pointer;
  }
  .choice.neutral { background: var(--soft); color: var(--ink); }
  .choice.on { border-color: currentColor; }
  .key {
    width: 22px; height: 22px; border-radius: 6px; display: inline-flex; align-items: center; justify-content: center;
    font-size: var(--text-xs); background: rgba(255, 255, 255, 0.7);
  }
  :global([data-theme='dark']) .key { background: rgba(0, 0, 0, 0.25); }

  .which {
    display: flex; flex-wrap: wrap; align-items: center; gap: var(--space-3);
    padding: var(--space-3) var(--space-4); border-radius: var(--radius-xl);
    background: var(--accent-tint); color: var(--accent-ink); font-weight: var(--weight-semibold);
  }
  .which input { flex: 1; min-width: 220px; width: auto; background: var(--surface); color: var(--ink); font-weight: var(--weight-regular); }
  .note { display: flex; flex-direction: column; gap: var(--space-1); }
  .nav { display: flex; justify-content: space-between; align-items: center; }

  dl { margin: 0; display: grid; grid-template-columns: auto 1fr; gap: var(--space-2) var(--space-4); font-size: var(--text-sm); }
  dt { color: var(--muted); }
  dd { margin: 0; }
  .accent { color: var(--accent-ink); font-weight: var(--weight-semibold); }
  .tally { display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); gap: var(--space-2); text-align: center; }
  .tally div { display: flex; flex-direction: column; padding: 10px var(--space-1); border-radius: var(--radius-lg);
    background: var(--accent-tint); color: var(--accent-ink); font-size: var(--text-xs); }
  .tally div.neutral { background: var(--soft); color: var(--muted); }
  .tally b { font-size: 20px; }
  .tally .neutral b { color: var(--ink); }
  .keys { padding: 0 var(--space-1); font-size: var(--text-xs); }

  .table-wrap { overflow-x: auto; }
  table { width: 100%; border-collapse: collapse; font-size: var(--text-sm); }
  th, td { text-align: left; padding: var(--space-2) var(--space-3); border-bottom: 1px solid var(--line); white-space: nowrap; }
  th { color: var(--muted); font-weight: var(--weight-medium); }
</style>
