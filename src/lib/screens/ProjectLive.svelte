<!-- Project step: open a pamflow project and edit its config.yml. -->
<script lang="ts">
  import PageHeader from '$lib/components/PageHeader.svelte';
  import Card from '$lib/components/Card.svelte';
  import StatTile from '$lib/components/StatTile.svelte';
  import Pills from '$lib/components/Pills.svelte';
  import Badge from '$lib/components/Badge.svelte';
  import Button from '$lib/components/Button.svelte';
  import ProjectPicker from './ProjectPicker.svelte';
  import SaveBar from '$lib/components/SaveBar.svelte';
  import ModelCard from '$lib/components/ModelCard.svelte';
  import { pickFolder, pickFile } from '$lib/backend/tauri';
  import { project } from '$lib/backend/project.svelte';
  import { settings, syncDraft, id } from '$lib/backend/settings.svelte';
  import { workflow } from '$lib/workflow/workflow.svelte';
  import { t } from '$lib/i18n';

  const f = $derived(project.facts);
  // A = detection settings, B = soundscape settings; folders and the sheet are shared
  const isA = $derived(workflow.current === 'A');

  // Load the saved values into the form whenever the project facts change.
  $effect(syncDraft);

  const get = (section: string, key: string) => settings.draft[id(section, key)];
  const set = (section: string, key: string, value: unknown) => (settings.draft[id(section, key)] = value);
  const num = (section: string, key: string) => {
    const v = get(section, key);
    return typeof v === 'number' ? v : v === null || v === undefined || v === '' ? '' : Number(v);
  };
  const setNum = (section: string, key: string, raw: string, integer = false) => {
    if (raw.trim() === '') return set(section, key, null);
    const n = Number(raw);
    if (!Number.isFinite(n)) return;
    set(section, key, integer ? Math.round(n) : n);
  };
  const str = (section: string, key: string) => (get(section, key) ?? '') as string;
  const slash = (p: string) => p.replace(/\\/g, '/');


  // ---- worker choices: "Auto" (pamflow: half the physical cores) or a number ----
  const physical = $derived(f?.cores_physical ?? 4);
  const workerChoices = $derived([
    { value: 0, label: t('settings.auto') },
    ...[...new Set([2, 4, 8, 12, Math.max(1, physical - 2)])]
      .filter((n) => n <= Math.max(1, physical - 1))
      .sort((a, b) => a - b)
      .map((n) => ({ value: n, label: String(n) }))
  ]);
  // pills bound straight to the draft ("Auto" = null in config.yml)
  const getWorkers = () => (get('birdnet', 'workers') as number | null) ?? 0;
  const setWorkers = (v: number) => set('birdnet', 'workers', v === 0 ? null : v);
  // day hours [first, last]: counted as day (both included), every other hour is night
  const dayHours = $derived.by(() => {
    const v = get('soundscape', 'day_hours');
    return Array.isArray(v) && v.length === 2 ? v.map(Number) : [6, 17];
  });
  const setDayHour = (i: 0 | 1, raw: string) => {
    const n = Math.round(Number(raw));
    if (raw.trim() === '' || !Number.isFinite(n)) return;
    const next = [...dayHours];
    next[i] = Math.min(23, Math.max(0, n));
    set('soundscape', 'day_hours', next);
  };
  const getSoundWorkers = () => (get('soundscape', 'workers') as number | null) ?? 0;
  const setSoundWorkers = (v: number) => set('soundscape', 'workers', v === 0 ? null : v);
  // the indices switched on, in pamflow's order; saved as soundscape: acoustic_indices:
  const INDICES = ['ACI', 'ADI', 'AEve', 'Bio', 'M', 'NDSI'];
  const chosen = $derived((get('soundscape', 'acoustic_indices') as string[] | null) ?? []);
  const toggleIndex = (name: string, on: boolean) =>
    set('soundscape', 'acoustic_indices', INDICES.filter((n) => (n === name ? on : chosen.includes(n))));
  const getInput = () => ((get('birdnet', 'input') as string) ?? 'standardized') as 'standardized' | 'filtered';
  const setInput = (v: 'standardized' | 'filtered') => set('birdnet', 'input', v);

  async function chooseRecordings() {
    const p = await pickFolder(t('settings.recordingsFolder'));
    if (p) set('paths', 'audio_standardized', slash(p));
  }
  async function chooseSheet() {
    const p = await pickFile(t('settings.sheet'), t('settings.sheetFiles'), ['csv', 'txt']);
    if (p) set('paths', 'deployment_sheet', slash(p));
  }

  const sizeLabel = $derived(
    f?.audio_gb == null ? '–' : f.audio_gb >= 1024 ? `${(f.audio_gb / 1024).toFixed(1)} TB` : `${f.audio_gb.toFixed(1)} GB`
  );
  const ex = $derived(f?.filename_example);
</script>

<PageHeader stage="project" title={t('project.title')} intro={t('project.intro')} />

<ProjectPicker />

{#if f}
  <div class="grid-4">
    <StatTile value={f.n_audio == null ? '–' : f.n_audio.toLocaleString()} label={t('project.recordingsFound')} />
    <StatTile value={sizeLabel} label={t('project.ofAudio')} palette="mint" />
    <StatTile value={f.n_deployments ?? '–'} label={t('project.deploymentsInSheet')} palette="lavender" />
    {#if isA}<StatTile value={f.n_labels ?? '–'} label={t('settings.speciesInModel')} palette="peach" />{/if}
  </div>

  <div class="grid-2">
    <Card title={t('settings.recordingsFolder')} hint={t('project.recordingsFolderHint')} labelFor="s-audio">
      <div class="row">
        <input id="s-audio" class="input" value={str('paths', 'audio_standardized')}
          oninput={(e) => set('paths', 'audio_standardized', e.currentTarget.value)} />
        <Button onclick={chooseRecordings}>{t('common.browse')}</Button>
      </div>
      {#if ex}
        <div class="chips">
          <Badge>{ex.file}</Badge>
          {#if ex.valid}
            <Badge palette="mint">{t('settings.grid', { grid: ex.grid ?? '' })}</Badge>
            <Badge palette="mint">{ex.start}</Badge>
          {:else}
            <Badge palette="peach">{t('settings.nameNotRead')}</Badge>
          {/if}
        </div>
        {#if f.n_unreadable_names}
          <Badge palette="peach">{t('settings.unreadableNames', { n: f.n_unreadable_names, of: ex.sample_size })}</Badge>
        {/if}
      {/if}
      <label class="sub" for="s-tz">{t('settings.timezone')}</label>
      <input id="s-tz" class="input" value={str('filenames', 'timezone')} placeholder="Asia/Kolkata"
        oninput={(e) => set('filenames', 'timezone', e.currentTarget.value)} />
    </Card>

    <Card title={t('project.sheet')} hint={t('project.sheetHint')} labelFor="s-sheet">
      <div class="row">
        <input id="s-sheet" class="input" value={str('paths', 'deployment_sheet')}
          oninput={(e) => set('paths', 'deployment_sheet', e.currentTarget.value)} />
        <Button onclick={chooseSheet}>{t('common.browse')}</Button>
      </div>
      {#if f.deployment_sheet_found}
        <span class="muted">{t('project.sheetRows', { n: f.n_deployments ?? '–' })}</span>
      {:else}
        <Badge palette="peach">{t('settings.sheetMissing')}</Badge>
      {/if}
    </Card>

    {#if isA}
    <ModelCard />

    <Card title={t('settings.detection')} hint={t('settings.detectionHint')}>
      <div class="between">
        <label for="s-conf" class="strong">{t('project.confidence')}</label>
        <span class="value">{Number(num('birdnet', 'min_confidence') || 0).toFixed(2)}</span>
      </div>
      <input id="s-conf" type="range" min="0.05" max="0.95" step="0.05" value={num('birdnet', 'min_confidence')}
        oninput={(e) => setNum('birdnet', 'min_confidence', e.currentTarget.value)} />
      <span class="sub">{t('project.workers')}</span>
      <Pills label={t('project.workers')} bind:value={getWorkers, setWorkers} options={workerChoices} />
      <span class="muted">{t('project.workersHint', { n: physical })}</span>
      <div class="pair">
        <div>
          <label class="sub" for="s-overlap">{t('settings.overlap')}</label>
          <input id="s-overlap" class="input" type="number" min="0" max="2.9" step="0.5" value={num('birdnet', 'overlap_s')}
            oninput={(e) => setNum('birdnet', 'overlap_s', e.currentTarget.value)} />
        </div>
        <div>
          <span class="sub">{t('settings.input')}</span>
          <Pills label={t('settings.input')} bind:value={getInput, setInput} options={[
            { value: 'standardized', label: t('settings.inputStandardized') },
            { value: 'filtered', label: t('settings.inputFiltered') }
          ]} />
        </div>
      </div>
    </Card>

    <Card title={t('settings.filterTitle')} hint={t('settings.filterHint')}>
      <label class="check"><input type="checkbox" checked={Boolean(get('filter', 'enabled'))}
        onchange={(e) => set('filter', 'enabled', e.currentTarget.checked)} /> {t('settings.filterOn')}</label>
      <div class="pair">
        <div>
          <label class="sub" for="s-hp">{t('settings.highpass')}</label>
          <input id="s-hp" class="input" type="number" min="0" step="50" value={num('filter', 'highpass_hz')}
            oninput={(e) => setNum('filter', 'highpass_hz', e.currentTarget.value)} />
        </div>
        <div>
          <label class="sub" for="s-order">{t('settings.filterOrder')}</label>
          <input id="s-order" class="input" type="number" min="1" max="12" step="1" value={num('filter', 'order')}
            oninput={(e) => setNum('filter', 'order', e.currentTarget.value, true)} />
        </div>
      </div>
      <label class="sub" for="s-filtered">{t('settings.filteredFolder')}</label>
      <input id="s-filtered" class="input" value={str('paths', 'filtered')}
        oninput={(e) => set('paths', 'filtered', e.currentTarget.value)} />
    </Card>

    <Card title={t('settings.cleaning')} hint={t('settings.cleaningHint')}>
      <div class="pair">
        <div>
          <label class="sub" for="s-pconf">{t('process.minConfidence')}</label>
          <input id="s-pconf" class="input" type="number" min="0" max="1" step="0.05" value={num('processing', 'min_confidence')}
            oninput={(e) => setNum('processing', 'min_confidence', e.currentTarget.value)} />
        </div>
        <div>
          <label class="sub" for="s-gap">{t('settings.mergeGap')}</label>
          <input id="s-gap" class="input" type="number" min="0" step="1" value={num('processing', 'merge_gap_s')}
            oninput={(e) => setNum('processing', 'merge_gap_s', e.currentTarget.value)} />
        </div>
      </div>
      <label class="check"><input type="checkbox" checked={Boolean(get('processing', 'drop_outside_deployment') ?? true)}
        onchange={(e) => set('processing', 'drop_outside_deployment', e.currentTarget.checked)} /> {t('settings.dropOutside')}</label>
    </Card>

    <Card title={t('settings.occupancy')} hint={t('settings.occupancyHint')}>
      <div class="pair">
        <div>
          <label class="sub" for="s-occ">{t('occupancy.occasionLength')}</label>
          <input id="s-occ" class="input" type="number" min="1" step="1" value={num('occupancy', 'occasion_length_days')}
            oninput={(e) => setNum('occupancy', 'occasion_length_days', e.currentTarget.value, true)} />
        </div>
        <div>
          <label class="sub" for="s-eff">{t('occupancy.minEffort')}</label>
          <input id="s-eff" class="input" type="number" min="0" step="0.5" value={num('occupancy', 'min_effort_hours')}
            oninput={(e) => setNum('occupancy', 'min_effort_hours', e.currentTarget.value)} />
        </div>
        <div>
          <label class="sub" for="s-mind">{t('occupancy.minDetections')}</label>
          <input id="s-mind" class="input" type="number" min="1" step="1" value={num('occupancy', 'min_detections')}
            oninput={(e) => setNum('occupancy', 'min_detections', e.currentTarget.value, true)} />
        </div>
        <div>
          <label class="sub" for="s-orun">{t('occupancy.run')}</label>
          <input id="s-orun" class="input" value={str('occupancy', 'run_id')}
            oninput={(e) => set('occupancy', 'run_id', e.currentTarget.value)} />
        </div>
      </div>
    </Card>
    {:else}
    <Card title={t('settings.soundscape')} hint={t('settings.soundscapeHint')}>
      <label class="check"><input type="checkbox" checked={Boolean(get('soundscape', 'enabled'))}
        onchange={(e) => set('soundscape', 'enabled', e.currentTarget.checked)} /> {t('settings.soundscapeOn')}</label>
      <div class="pair">
        <div>
          <label class="sub" for="s-swin">{t('settings.soundscapeWindow')}</label>
          <input id="s-swin" class="input" type="number" min="1" step="1" placeholder={t('soundscape.wholeFile')} value={num('soundscape', 'window_mins')}
            oninput={(e) => setNum('soundscape', 'window_mins', e.currentTarget.value, true)} />
        </div>
        <div>
          <label class="sub" for="s-shp">{t('settings.highpass')}</label>
          <input id="s-shp" class="input" type="number" min="0" step="50" value={num('soundscape', 'low_stop_hz')}
            oninput={(e) => setNum('soundscape', 'low_stop_hz', e.currentTarget.value)} />
        </div>
        <div>
          <label class="sub" for="s-srun">{t('settings.soundscapeRun')}</label>
          <input id="s-srun" class="input" value={str('soundscape', 'run_id')}
            oninput={(e) => set('soundscape', 'run_id', e.currentTarget.value)} />
        </div>
      </div>
      <div class="pair">
        <div>
          <label class="sub" for="s-dstart">{t('settings.soundscapeDayStart')}</label>
          <input id="s-dstart" class="input" type="number" min="0" max="23" step="1" value={dayHours[0]}
            oninput={(e) => setDayHour(0, e.currentTarget.value)} />
        </div>
        <div>
          <label class="sub" for="s-dend">{t('settings.soundscapeDayEnd')}</label>
          <input id="s-dend" class="input" type="number" min="0" max="23" step="1" value={dayHours[1]}
            oninput={(e) => setDayHour(1, e.currentTarget.value)} />
        </div>
      </div>
      <span class="muted">{t('settings.soundscapeDayHint')}</span>
      {#if dayHours[0] > dayHours[1]}<span class="problem">{t('settings.soundscapeDayOrder')}</span>{/if}
      <span class="sub">{t('project.workers')}</span>
      <Pills label={t('project.workers')} bind:value={getSoundWorkers, setSoundWorkers} options={workerChoices} />
      <label class="sub" for="s-sbatch">{t('settings.soundscapeBatch')}</label>
      <input id="s-sbatch" class="input" type="number" min="1" step="10" placeholder="50" value={num('soundscape', 'batch_size')}
        oninput={(e) => setNum('soundscape', 'batch_size', e.currentTarget.value, true)} />
      <span class="muted">{t('settings.soundscapeBatchHint')}</span>
      <span class="sub">{t('settings.soundscapeIndices')}</span>
      <div class="indices">
        {#each INDICES as name (name)}
          <label class="check" title={t(`settings.index.${name}`)}><input type="checkbox" checked={chosen.includes(name)}
            onchange={(e) => toggleIndex(name, e.currentTarget.checked)} /> {name} <span class="muted">{t(`settings.index.${name}`)}</span></label>
        {/each}
      </div>
      {#if !chosen.length}<span class="problem">{t('settings.soundscapeNoIndex')}</span>{/if}
    </Card>
    {/if}

    {#if isA}
    <Card title={t('settings.reviewAndReport')}>
      <div class="pair">
        <div>
          <label class="sub" for="s-rev">{t('validate.reviewer')}</label>
          <input id="s-rev" class="input" value={str('validation', 'reviewer')}
            oninput={(e) => set('validation', 'reviewer', e.currentTarget.value)} />
        </div>
        <div>
          <label class="sub" for="s-author">{t('settings.author')}</label>
          <input id="s-author" class="input" value={str('report', 'author')}
            oninput={(e) => set('report', 'author', e.currentTarget.value)} />
        </div>
      </div>
      <label class="sub" for="s-title">{t('settings.reportTitle')}</label>
      <input id="s-title" class="input" value={str('report', 'title')}
        oninput={(e) => set('report', 'title', e.currentTarget.value)} />
      <label class="check"><input type="checkbox" checked={Boolean(get('validation', 'show_confidence'))}
        onchange={(e) => set('validation', 'show_confidence', e.currentTarget.checked)} /> {t('settings.showConfidence')}</label>
    </Card>
    {/if}
  </div>

  <SaveBar />
{/if}

<style>
  .row { display: flex; gap: var(--space-2); align-items: center; }
  .chips { display: flex; flex-wrap: wrap; gap: var(--space-2); }
  .muted { font-size: var(--text-sm); color: var(--muted); }
  .sub { font-size: var(--text-sm); color: var(--muted); margin-top: var(--space-1); }
  .strong { font-weight: var(--weight-semibold); }
  .between { display: flex; justify-content: space-between; align-items: baseline; }
  .value { font-weight: var(--weight-semibold); color: var(--accent-ink); font-variant-numeric: tabular-nums; }
  input[type='range'] { width: 100%; }
  .pair { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: var(--space-3); }
  .pair > div { display: flex; flex-direction: column; gap: var(--space-1); min-width: 0; }
  .check { display: flex; align-items: center; gap: var(--space-2); min-height: 40px; font-size: var(--text-sm); cursor: pointer; }
  .check input { width: 18px; height: 18px; margin: 0; }
  .indices { display: grid; grid-template-columns: repeat(auto-fill, minmax(230px, 1fr)); gap: 0 var(--space-3); }
  .problem { color: var(--rose-ink); font-weight: var(--weight-semibold); font-size: var(--text-sm); }
</style>
