<!--
  Standardize step: Raven Compass-style triage of the raw recordings
  (pamflow Stage 00). Settings are saved to config.yml; Check is a dry run,
  Standardize writes the files. Raw files are never changed.
-->
<script lang="ts">
  import { onMount } from 'svelte';
  import PageHeader from '$lib/components/PageHeader.svelte';
  import Card from '$lib/components/Card.svelte';
  import StatTile from '$lib/components/StatTile.svelte';
  import Button from '$lib/components/Button.svelte';
  import Badge from '$lib/components/Badge.svelte';
  import Pills from '$lib/components/Pills.svelte';
  import Icon from '$lib/components/Icon.svelte';
  import ProgressBar from '$lib/components/ProgressBar.svelte';
  import SaveBar from '$lib/components/SaveBar.svelte';
  import LongJobPanel from '$lib/components/LongJobPanel.svelte';
  import { pickFolder, showFolder, freeSpace } from '$lib/backend/tauri';
  import { project, refreshProject } from '$lib/backend/project.svelte';
  import { settings, syncDraft, changedSettings, id } from '$lib/backend/settings.svelte';
  import { isActive } from '$lib/backend/longjob.svelte';
  import { detectJob } from '$lib/backend/detect.svelte';
  import { filterJob } from '$lib/backend/filter.svelte';
  import {
    standardize, loadStdState, checkRaw, startStandardize, stopStandardize,
    stdJob, stdMinutesLeft, stdMinutesElapsed
  } from '$lib/backend/standardize.svelte';
  import { t } from '$lib/i18n';

  onMount(() => {
    if (project.folder && !standardize.state) loadStdState(project.folder);
    if (project.folder && !project.facts && !project.checking) refreshProject();
  });
  $effect(syncDraft);

  // After saving settings the plan may no longer match: re-read the state.
  let savedFor = '';
  $effect(() => {
    const key = project.facts ? JSON.stringify(project.facts.settings) : '';
    if (key && savedFor && key !== savedFor && project.folder) loadStdState(project.folder);
    savedFor = key;
  });

  // ---- settings draft helpers ----
  const get = (section: string, key: string) => settings.draft[id(section, key)];
  const set = (section: string, key: string, value: unknown) => (settings.draft[id(section, key)] = value);
  const str = (section: string, key: string) => (get(section, key) ?? '') as string;
  const num = (section: string, key: string) => {
    const v = get(section, key);
    return v === null || v === undefined || v === '' ? '' : Number(v);
  };
  const setNum = (section: string, key: string, raw: string, integer = false) => {
    if (raw.trim() === '') return set(section, key, null);
    const n = Number(raw);
    if (Number.isFinite(n)) set(section, key, integer ? Math.round(n) : n);
  };
  const slash = (p: string) => p.replace(/\\/g, '/');
  async function choose(key: string, title: string) {
    const p = await pickFolder(title);
    if (p) set('paths', key, slash(p));
  }

  const SR = [16000, 22050, 24000, 32000, 44100, 48000];
  const LAYOUTS = ['grid', 'grid_date', 'date', 'preserve', 'flat'];

  // pills bound to the draft
  const format = {
    get value() { return (str('standardization', 'target_format') || 'flac') as 'flac' | 'wav'; },
    set value(v: 'flac' | 'wav') { set('standardization', 'target_format', v); }
  };
  const channels = {
    get value() { return Number(get('standardization', 'channels') ?? 1); },
    set value(v: number) { set('standardization', 'channels', v); }
  };
  const rate = {
    get value() { return Number(get('standardization', 'target_hz') ?? 48000); },
    set value(v: number) { set('standardization', 'target_hz', v); }
  };
  const naming = {
    get value() { return (str('standardization', 'rename_strategy') || 'auto') as 'auto' | 'keep'; },
    set value(v: 'auto' | 'keep') { set('standardization', 'rename_strategy', v); }
  };

  // ---- state ----
  const st = $derived(standardize.state);
  const plan = $derived(st?.plan);
  const last = $derived(st?.last_run);
  const unsaved = $derived(changedSettings().length > 0);
  const running = $derived(isActive(stdJob.status));
  const busyElsewhere = $derived(isActive(detectJob.status) || isActive(filterJob.status));
  const canCheck = $derived(!!st && !st.problems.length && !unsaved && !standardize.checking && !running && !busyElsewhere);
  const canRun = $derived(canCheck && !!plan?.available && (plan.n_files ?? 0) > 0);

  let freeGb = $state<number | null>(null);
  $effect(() => {
    if (st?.settings.standardized_dir) freeSpace(st.settings.standardized_dir).then((g) => (freeGb = g));
  });
  const gb = (x: number) => (x >= 1024 ? `${(x / 1024).toFixed(1)} TB` : `${x.toFixed(1)} GB`);
  const tooSmall = $derived(freeGb !== null && plan?.raw_gb != null && freeGb < plan.raw_gb);
  const n = (x: number | undefined) => (x ?? 0).toLocaleString();
  let showProblems = $state(false);
  let showLog = $state(false);
</script>

<PageHeader stage="standardize" title={t('standardize.title')} intro={t('standardize.intro')} />

{#if !project.folder}
  <Card title={t('detect.chooseProject')}>
    <div><Button variant="primary" href="/">{t('detect.goProject')}</Button></div>
  </Card>
{:else}
  <div class="skip">
    <span>{t('standardize.skip')}</span>
    <Button variant="ghost" size="sm" href="/scan">{t('standardize.skipButton')}</Button>
  </div>

  {#if !running}
    <Card title={t('standardize.foldersTitle')} hint={t('standardize.foldersHint')}>
      <label class="sub" for="s-raw">{t('standardize.raw')}</label>
      <div class="row">
        <input id="s-raw" class="input" value={str('paths', 'audio_raw')}
          oninput={(e) => set('paths', 'audio_raw', e.currentTarget.value)} />
        <Button onclick={() => choose('audio_raw', t('standardize.raw'))}>{t('common.browse')}</Button>
      </div>
      {#if st && !st.raw_found}<span class="muted">{t('standardize.rawMissing')}</span>
      {:else if st?.n_raw_files != null}<span class="muted">{t('standardize.rawCount', { n: n(st.n_raw_files) })}</span>{/if}
      <div class="pair">
        <div>
          <label class="sub" for="s-std">{t('standardize.out')}</label>
          <div class="row">
            <input id="s-std" class="input" value={str('paths', 'audio_standardized')}
              oninput={(e) => set('paths', 'audio_standardized', e.currentTarget.value)} />
            <Button onclick={() => choose('audio_standardized', t('standardize.out'))}>{t('common.browse')}</Button>
          </div>
        </div>
        <div>
          <label class="sub" for="s-iso">{t('standardize.isolated')}</label>
          <div class="row">
            <input id="s-iso" class="input" value={str('paths', 'audio_isolated')}
              oninput={(e) => set('paths', 'audio_isolated', e.currentTarget.value)} />
            <Button onclick={() => choose('audio_isolated', t('standardize.isolated'))}>{t('common.browse')}</Button>
          </div>
        </div>
      </div>
    </Card>

    <div class="grid-2">
      <Card title={t('standardize.audioTitle')} hint={t('standardize.audioHint')}>
        <span class="sub">{t('standardize.format')}</span>
        <Pills label={t('standardize.format')} bind:value={format.value}
          options={[{ value: 'flac', label: t('standardize.flac') }, { value: 'wav', label: 'WAV' }]} />
        <label class="sub" for="s-rate">{t('standardize.rate')}</label>
        <select id="s-rate" class="input" value={rate.value} onchange={(e) => (rate.value = Number(e.currentTarget.value))}>
          {#each SR as r (r)}<option value={r}>{(r / 1000).toLocaleString()} kHz</option>{/each}
        </select>
        <span class="muted">{t('standardize.rateHint')}</span>
        <span class="sub">{t('standardize.channels')}</span>
        <Pills label={t('standardize.channels')} bind:value={channels.value}
          options={[{ value: 1, label: t('standardize.mono') }, { value: 2, label: t('standardize.stereo') }]} />
      </Card>

      <Card title={t('standardize.triageTitle')} hint={t('standardize.triageHint')}>
        <div class="pair">
          <div>
            <label class="sub" for="s-mindur">{t('standardize.minDuration')}</label>
            <input id="s-mindur" class="input" type="number" min="0" step="10" value={num('standardization', 'min_duration_s')}
              oninput={(e) => setNum('standardization', 'min_duration_s', e.currentTarget.value)} />
          </div>
          <div>
            <label class="sub" for="s-layout">{t('standardize.layout')}</label>
            <select id="s-layout" class="input" value={str('standardization', 'organize_folders') || 'grid'}
              onchange={(e) => set('standardization', 'organize_folders', e.currentTarget.value)}>
              {#each LAYOUTS as l (l)}<option value={l}>{t(`standardize.layouts.${l}`)}</option>{/each}
            </select>
          </div>
        </div>
        <span class="sub">{t('standardize.naming')}</span>
        <Pills label={t('standardize.naming')} bind:value={naming.value}
          options={[{ value: 'auto', label: t('standardize.namingAuto') }, { value: 'keep', label: t('standardize.namingKeep') }]} />
        <label class="sub" for="s-prefix">{t('standardize.prefix')}</label>
        <input id="s-prefix" class="input" value={str('standardization', 'prefix')} placeholder={t('standardize.prefixPlaceholder')}
          oninput={(e) => set('standardization', 'prefix', e.currentTarget.value)} />
        <span class="muted">{t('standardize.prefixHint')}</span>
        <label class="check"><input type="checkbox" checked={get('standardization', 'isolate_short') !== false}
          onchange={(e) => set('standardization', 'isolate_short', e.currentTarget.checked)} /> {t('standardize.isolateShort')}</label>
        <label class="check"><input type="checkbox" checked={get('standardization', 'isolate_non_audio') !== false}
          onchange={(e) => set('standardization', 'isolate_non_audio', e.currentTarget.checked)} /> {t('standardize.isolateNonAudio')}</label>
      </Card>
    </div>

    <SaveBar />
  {/if}

  {#if st?.problems.length}
    {#each st.problems as p (p)}<p class="problem">{p}</p>{/each}
  {/if}

  {#if !running}
    <Card title={t('standardize.checkTitle')} hint={t('standardize.checkHint')}>
      <div class="actions">
        <Button variant={plan?.available ? 'secondary' : 'primary'} size="lg" onclick={() => checkRaw(project.folder)} disabled={!canCheck}>
          {standardize.checking ? t('standardize.checking') : plan?.available ? t('standardize.checkAgain') : t('standardize.check')}
        </Button>
        {#if plan?.available}<span class="muted">{t('standardize.checked', { when: plan.updated ?? '' })}</span>{/if}
        {#if unsaved}<Badge palette="peach">{t('standardize.saveFirst')}</Badge>{/if}
        {#if busyElsewhere}<Badge palette="peach">{t('standardize.busy')}</Badge>{/if}
      </div>
      {#if standardize.checking}
        <ProgressBar percent={standardize.prepTotal ? (standardize.prepDone / standardize.prepTotal) * 100 : 0}
          label={t('standardize.checking')} />
        <span class="muted">{t('standardize.readCount', { done: n(standardize.prepDone), total: n(standardize.prepTotal) })}</span>
      {/if}
      {#if standardize.message}
        <p class="problem">{standardize.message}</p>
        {#if standardize.log.length}
          <div><Button size="sm" onclick={() => (showLog = !showLog)}>{showLog ? t('detect.hideLog') : t('detect.showLog')}</Button></div>
          {#if showLog}<pre class="log">{standardize.log.join('\n')}</pre>{/if}
        {/if}
      {/if}
    </Card>

    {#if plan?.available}
      <div class="grid-4">
        <StatTile value={n(plan.n_recordings)} label={t('standardize.recordings')} palette="mint" />
        <StatTile value={n(plan.n_memos)} label={t('standardize.memos')} palette="butter" />
        <StatTile value={n(plan.n_non_audio)} label={t('standardize.nonAudio')} palette="lavender" />
        <StatTile value={n(plan.n_corrupt)} label={t('standardize.corrupt')} palette="peach" />
      </div>

      <Card title={t('standardize.planTitle')}
        hint={t('standardize.planHint', { convert: n(plan.n_convert), copy: n(plan.n_copy) })}>
        {#if plan.examples?.length}
          <div class="table-wrap">
            <table>
              <thead><tr><th>{t('standardize.from')}</th><th></th><th>{t('standardize.to')}</th></tr></thead>
              <tbody>
                {#each plan.examples as ex, i (i)}
                  <tr><td class="mono">{ex.from}</td><td class="arrow">→</td><td class="mono">{ex.to.split(/[\\/]/).slice(-2).join('/')}</td></tr>
                {/each}
              </tbody>
            </table>
          </div>
        {/if}
        {#if plan.per_grid?.length}
          <div class="chips">
            {#each plan.per_grid as g (g.grid)}<Badge>{g.grid} · {g.files.toLocaleString()}</Badge>{/each}
          </div>
        {/if}
        {#if plan.problems?.length}
          <div><Button size="sm" onclick={() => (showProblems = !showProblems)}>
            {showProblems ? t('standardize.hideSetAside') : t('standardize.showSetAside', { n: n(plan.problems.length) })}
          </Button></div>
          {#if showProblems}
            <div class="table-wrap">
              <table>
                <thead><tr><th>{t('standardize.file')}</th><th>{t('standardize.what')}</th><th>{t('standardize.why')}</th></tr></thead>
                <tbody>
                  {#each plan.problems as p, i (i)}
                    <tr><td class="mono">{p.file}</td><td>{t(`standardize.categories.${p.category}`)}</td><td>{p.message}</td></tr>
                  {/each}
                </tbody>
              </table>
            </div>
          {/if}
        {/if}
      </Card>

      <Card title={t('standardize.runTitle')} hint={t('standardize.runHint')}>
        <dl>
          <dt>{t('filter.space')}</dt>
          <dd>{t('standardize.needs', { size: gb(plan.raw_gb ?? 0) })}{#if freeGb !== null} · {t('filter.free', { size: gb(freeGb) })}{/if}</dd>
          <dt>{t('standardize.out')}</dt><dd class="mono">{st?.settings.standardized_dir}</dd>
        </dl>
        {#if tooSmall}<Badge palette="peach">{t('standardize.notEnoughSpace')}</Badge>{/if}
        <div class="actions">
          <Button variant="primary" size="lg" onclick={() => startStandardize(project.folder)} disabled={!canRun}>
            <Icon name="play" size={14} /> {t('standardize.start', { n: n(plan.n_recordings) })}
          </Button>
        </div>
        <span class="muted">{t('standardize.noResume')}</span>
      </Card>
    {/if}
  {/if}

  {#if stdJob.status !== 'idle'}
    <LongJobPanel job={stdJob} kind="standardize" onstop={stopStandardize}
      minutesLeft={stdMinutesLeft} minutesElapsed={stdMinutesElapsed} />
  {/if}

  {#if last?.available && !running}
    <Card title={t('standardize.lastTitle')} hint={t('standardize.lastHint', { when: last.updated ?? '' })}>
      <p class="summary">
        {t('standardize.lastSummary', { rec: n(last.n_recordings), iso: n((last.n_memos ?? 0) + (last.n_non_audio ?? 0) + (last.n_corrupt ?? 0)), failed: n(last.n_failed) })}
      </p>
      <div class="actions">
        <Button onclick={() => st && showFolder(st.settings.standardized_dir)}>{t('standardize.openOut')}</Button>
        <Button onclick={() => st && showFolder(st.settings.isolated_dir)}>{t('standardize.openIsolated')}</Button>
        <Button variant="primary" href="/scan">{t('standardize.next')}</Button>
      </div>
    </Card>
  {/if}
{/if}

<style>
  .skip { display: flex; align-items: center; justify-content: space-between; gap: var(--space-3);
    padding: var(--space-2) var(--space-5); border-radius: var(--radius-xl); background: var(--soft);
    font-size: var(--text-sm); color: var(--muted); }
  .row { display: flex; gap: var(--space-2); align-items: center; }
  .pair { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: var(--space-3); }
  .pair > div { display: flex; flex-direction: column; gap: var(--space-1); min-width: 0; }
  .sub { font-size: var(--text-sm); color: var(--muted); margin-top: var(--space-1); }
  .muted { font-size: var(--text-sm); color: var(--muted); }
  .check { display: flex; align-items: center; gap: var(--space-2); min-height: 36px; font-size: var(--text-sm); cursor: pointer; }
  .check input { width: 18px; height: 18px; margin: 0; }
  .actions { display: flex; flex-wrap: wrap; align-items: center; gap: var(--space-3); }
  .chips { display: flex; flex-wrap: wrap; gap: var(--space-2); }
  .problem { margin: 0; color: var(--rose-ink); font-weight: var(--weight-semibold); font-size: var(--text-sm); }
  .summary { margin: 0; }
  dl { margin: 0; display: grid; grid-template-columns: auto 1fr; gap: var(--space-2) var(--space-6); font-size: var(--text-sm); }
  dt { color: var(--muted); }
  dd { margin: 0; overflow-wrap: anywhere; }
  .table-wrap { overflow-x: auto; max-height: 360px; }
  table { width: 100%; border-collapse: collapse; font-size: var(--text-sm); }
  th, td { text-align: left; padding: var(--space-2) var(--space-3); border-bottom: 1px solid var(--line); white-space: nowrap; }
  th { color: var(--muted); font-weight: var(--weight-medium); position: sticky; top: 0; background: var(--surface); }
  .arrow { color: var(--muted); width: 1%; }
  .log { margin: 0; max-height: 280px; overflow: auto; padding: var(--space-3); border-radius: var(--radius-md);
    background: var(--soft); font-family: var(--font-mono); font-size: var(--text-xs); white-space: pre-wrap; }
</style>
