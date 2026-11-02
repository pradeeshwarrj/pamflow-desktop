<!-- Step 1 · Project: open a pamflow project and edit its config.yml. -->
<script lang="ts">
  import PageHeader from '$lib/components/PageHeader.svelte';
  import Card from '$lib/components/Card.svelte';
  import StatTile from '$lib/components/StatTile.svelte';
  import Pills from '$lib/components/Pills.svelte';
  import Badge from '$lib/components/Badge.svelte';
  import Button from '$lib/components/Button.svelte';
  import ProjectPicker from './ProjectPicker.svelte';
  import { pickFolder, pickFile, showFolder } from '$lib/backend/tauri';
  import { project } from '$lib/backend/project.svelte';
  import { settings, resetDraft, changedSettings, saveSettings, id } from '$lib/backend/settings.svelte';
  import { t } from '$lib/i18n';

  const f = $derived(project.facts);

  // Load the saved values into the form whenever the project facts change.
  let shownFor = '';
  $effect(() => {
    const key = f ? `${f.config}|${JSON.stringify(f.settings)}` : '';
    if (key && key !== shownFor) {
      shownFor = key;
      resetDraft();
    }
  });

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

  const changes = $derived(changedSettings());
  const nChanges = $derived(changes.length);

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
  async function chooseModel() {
    const p = await pickFile(t('settings.modelFile'), 'BirdNET model', ['tflite']);
    if (!p) return;
    const path = slash(p);
    const cut = path.lastIndexOf('/');
    set('birdnet', 'model_dir', path.slice(0, cut));
    set('birdnet', 'classifier_name', path.slice(cut + 1).replace(/\.tflite$/i, ''));
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
    <StatTile value={f.n_labels ?? '–'} label={t('settings.speciesInModel')} palette="peach" />
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

    <Card title={t('project.model')} hint={t('settings.modelHint')}>
      <div class="row">
        <div class="file">
          <span class="mono">{str('birdnet', 'classifier_name') || '–'}.tflite</span>
          <span class="muted small">{str('birdnet', 'model_dir')}</span>
        </div>
        <Button onclick={chooseModel}>{t('settings.chooseModel')}</Button>
      </div>
      {#if f.model_found && f.labels_found}
        <Badge palette="mint">{t('settings.modelReady', { n: f.n_labels ?? 0 })}</Badge>
      {:else}
        <Badge palette="peach">{t('settings.modelNotFound')}</Badge>
      {/if}
      <label class="sub" for="s-run">{t('settings.runName')}</label>
      <input id="s-run" class="input" value={str('birdnet', 'run_id')}
        oninput={(e) => set('birdnet', 'run_id', e.currentTarget.value)} />
    </Card>

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
  </div>

  <div class="savebar" class:dirty={nChanges > 0}>
    {#if nChanges > 0}
      <span>{t('settings.unsaved', { n: nChanges })}</span>
      <div class="actions">
        <Button variant="ghost" onclick={resetDraft} disabled={settings.saving}>{t('settings.discard')}</Button>
        <Button variant="primary" onclick={saveSettings} disabled={settings.saving}>
          {settings.saving ? t('settings.saving') : t('settings.save')}
        </Button>
      </div>
    {:else if settings.message}
      <span>{t('settings.saved', { n: settings.message })}</span>
      <Button variant="ghost" size="sm" onclick={() => showFolder(settings.backup)}>{t('settings.showBackup')}</Button>
    {:else}
      <span class="muted">{t('settings.allSaved')}</span>
    {/if}
  </div>
  {#if settings.error}<p class="problem">{settings.error}</p>{/if}
{/if}

<style>
  .row { display: flex; gap: var(--space-2); align-items: center; }
  .chips { display: flex; flex-wrap: wrap; gap: var(--space-2); }
  .muted { font-size: var(--text-sm); color: var(--muted); }
  .small { font-size: var(--text-xs); overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
  .sub { font-size: var(--text-sm); color: var(--muted); margin-top: var(--space-1); }
  .strong { font-weight: var(--weight-semibold); }
  .between { display: flex; justify-content: space-between; align-items: baseline; }
  .value { font-weight: var(--weight-semibold); color: var(--accent-ink); font-variant-numeric: tabular-nums; }
  input[type='range'] { width: 100%; }
  .file { flex: 1; min-width: 0; display: flex; flex-direction: column; min-height: var(--control-height); justify-content: center;
    padding: 0 var(--space-3); border-radius: var(--radius-md); background: var(--soft); }
  .pair { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: var(--space-3); }
  .pair > div { display: flex; flex-direction: column; gap: var(--space-1); min-width: 0; }
  .check { display: flex; align-items: center; gap: var(--space-2); min-height: 40px; font-size: var(--text-sm); cursor: pointer; }
  .check input { width: 18px; height: 18px; margin: 0; }
  .savebar {
    display: flex; align-items: center; justify-content: space-between; gap: var(--space-3);
    padding: var(--space-3) var(--space-5); border-radius: var(--radius-xl);
    background: var(--surface); border: 1px solid var(--line); font-size: var(--text-sm);
  }
  .savebar.dirty { position: sticky; bottom: 0; z-index: 2; background: var(--accent-tint); color: var(--accent-ink); border-color: transparent; font-weight: var(--weight-semibold); }
  .actions { display: flex; gap: var(--space-2); }
  .problem { margin: 0; color: var(--rose-ink); font-weight: var(--weight-semibold); font-size: var(--text-sm); }
</style>
