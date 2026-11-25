<!--
  "More settings": the rest of pamflow's settings (config.yml), folded away.
  Workflow A shows all of them; workflow B only the deployment sheet format.
-->
<script lang="ts">
  import Card from './Card.svelte';
  import Pills from './Pills.svelte';
  import Button from './Button.svelte';
  import { pickFile } from '$lib/backend/tauri';
  import { settings, id } from '$lib/backend/settings.svelte';
  import { asList } from '$lib/backend/soundscape.svelte';
  import { t } from '$lib/i18n';

  let { detection = true }: { detection?: boolean } = $props();

  const get = (section: string, key: string) => settings.draft[id(section, key)];
  const set = (section: string, key: string, value: unknown) => (settings.draft[id(section, key)] = value);
  const num = (section: string, key: string) => {
    const v = get(section, key);
    return typeof v === 'number' ? v : v === null || v === undefined || v === '' ? '' : Number(v);
  };
  const setNum = (section: string, key: string, raw: string, integer = false) => {
    if (raw.trim() === '') return set(section, key, null);
    const n = Number(raw);
    if (Number.isFinite(n)) set(section, key, integer ? Math.round(n) : n);
  };
  const str = (section: string, key: string) => (get(section, key) ?? '') as string;
  // text where empty means "not set" (null in config.yml)
  const setText = (section: string, key: string, raw: string) => set(section, key, raw.trim() === '' ? null : raw);
  const slash = (p: string) => p.replace(/\\/g, '/');

  // lists: one item per line (names) or separated by commas (numbers); read when the field is left
  const lines = (section: string, key: string) => asList(get(section, key) as string[] | string | null).join('\n');
  const setLines = (section: string, key: string, raw: string) =>
    set(section, key, raw.split(/\r?\n/).map((s) => s.trim()).filter(Boolean));
  const csv = (section: string, key: string) => asList(get(section, key) as unknown[] | unknown).join(', ');
  const setCsv = (section: string, key: string, raw: string, numeric = true) => {
    const items = raw.split(',').map((s) => s.trim()).filter(Boolean);
    if (!numeric) return set(section, key, items);
    const nums = items.map(Number);
    if (nums.every(Number.isFinite)) set(section, key, nums);
  };
  const listLen = (section: string, key: string) => asList(get(section, key) as unknown[] | unknown).length;

  const FORMATS = ['html', 'excel', 'pdf'];
  const formats = $derived(asList(get('report', 'formats') as string[] | string | null));
  const toggleFormat = (name: string, on: boolean) =>
    set('report', 'formats', FORMATS.filter((n) => (n === name ? on : formats.includes(n))));

  const getDevice = () => (str('birdnet', 'device') || 'CPU') as 'CPU' | 'GPU';
  const setDevice = (v: 'CPU' | 'GPU') => set('birdnet', 'device', v);
  const getRecallAudio = () => (str('recall', 'audio') || 'standardized') as 'standardized' | 'filtered';
  const setRecallAudio = (v: 'standardized' | 'filtered') => set('recall', 'audio', v);

  async function chooseCsv(section: string, key: string, title: string) {
    const p = await pickFile(title, t('settings.csvFiles'), ['csv', 'txt']);
    if (p) set(section, key, slash(p));
  }
</script>

<details class="more">
  <summary>{t('settings.more')}</summary>
  <p class="muted">{t('settings.moreHint')}</p>
  <div class="grid-2">
    <Card title={t('settings.sheetFormat')} hint={t('settings.sheetFormatHint')}>
      <label class="check"><input type="checkbox" checked={Boolean(get('deployments', 'has_header') ?? true)}
        onchange={(e) => set('deployments', 'has_header', e.currentTarget.checked)} /> {t('settings.sheetHeader')}</label>
      <div class="pair">
        <div>
          <label class="sub" for="m-gp">{t('settings.gridPrefix')}</label>
          <input id="m-gp" class="input" value={str('deployments', 'grid_prefix')}
            oninput={(e) => set('deployments', 'grid_prefix', e.currentTarget.value)} />
        </div>
        <div>
          <label class="sub" for="m-rt">{t('settings.recoveryTime')}</label>
          <input id="m-rt" class="input" value={str('deployments', 'default_recovery_time')} placeholder="23:59"
            oninput={(e) => set('deployments', 'default_recovery_time', e.currentTarget.value)} />
        </div>
        <div>
          <label class="sub" for="m-df">{t('settings.dateFormat')}</label>
          <input id="m-df" class="input" value={str('deployments', 'date_format')} placeholder="%d-%m-%Y"
            oninput={(e) => set('deployments', 'date_format', e.currentTarget.value)} />
        </div>
        <div>
          <label class="sub" for="m-tf">{t('settings.timeFormat')}</label>
          <input id="m-tf" class="input" value={str('deployments', 'time_format')} placeholder="%H:%M"
            oninput={(e) => set('deployments', 'time_format', e.currentTarget.value)} />
        </div>
      </div>
      <label class="sub" for="m-cols">{t('settings.sheetColumns')}</label>
      <textarea id="m-cols" class="input" rows="3" value={csv('deployments', 'columns')}
        onchange={(e) => setCsv('deployments', 'columns', e.currentTarget.value, false)}></textarea>
      <span class="muted">{t('settings.sheetColumnsHint')}</span>
    </Card>

    {#if detection}
      <Card title={t('settings.speciesTitle')} hint={t('settings.speciesHint')}>
        <label class="sub" for="m-wl">{t('settings.whitelist')}</label>
        <textarea id="m-wl" class="input" rows="3" value={lines('processing', 'species_whitelist')}
          onchange={(e) => setLines('processing', 'species_whitelist', e.currentTarget.value)}></textarea>
        <label class="sub" for="m-bl">{t('settings.blacklist')}</label>
        <textarea id="m-bl" class="input" rows="3" value={lines('processing', 'species_blacklist')}
          onchange={(e) => setLines('processing', 'species_blacklist', e.currentTarget.value)}></textarea>
        <span class="muted">{t('settings.speciesNamesHint')}</span>
        <label class="sub" for="m-dr">{t('settings.dateRange')}</label>
        <input id="m-dr" class="input" value={csv('processing', 'date_range')} placeholder="2026-03-26, 2026-04-20"
          onchange={(e) => setCsv('processing', 'date_range', e.currentTarget.value, false)} />
        {#if listLen('processing', 'date_range') === 1}<span class="problem">{t('settings.dateRangeTwo')}</span>{/if}
        <label class="sub" for="m-thr">{t('settings.thresholdsFile')}</label>
        <div class="row">
          <input id="m-thr" class="input" value={str('processing', 'species_thresholds_file')}
            oninput={(e) => setText('processing', 'species_thresholds_file', e.currentTarget.value)} />
          <Button onclick={() => chooseCsv('processing', 'species_thresholds_file', t('settings.thresholdsFile'))}>{t('common.browse')}</Button>
        </div>
        <label class="sub" for="m-season">{t('settings.seasonFile')}</label>
        <div class="row">
          <input id="m-season" class="input" value={str('processing', 'species_season_file')}
            oninput={(e) => setText('processing', 'species_season_file', e.currentTarget.value)} />
          <Button onclick={() => chooseCsv('processing', 'species_season_file', t('settings.seasonFile'))}>{t('common.browse')}</Button>
        </div>
        <label class="sub" for="m-over">{t('settings.maxOverrun')}</label>
        <input id="m-over" class="input" type="number" min="0" step="1" value={num('processing', 'max_overrun_s')}
          oninput={(e) => setNum('processing', 'max_overrun_s', e.currentTarget.value)} />
      </Card>

      <Card title={t('settings.birdnetMore')} hint={t('settings.birdnetMoreHint')}>
        <div class="pair">
          <div>
            <label class="sub" for="m-topk">{t('settings.topK')}</label>
            <input id="m-topk" class="input" type="number" min="1" step="1" placeholder={t('settings.topKAll')} value={num('birdnet', 'top_k')}
              oninput={(e) => setNum('birdnet', 'top_k', e.currentTarget.value, true)} />
          </div>
          <div>
            <label class="sub" for="m-sig">{t('settings.sensitivity')}</label>
            <input id="m-sig" class="input" type="number" min="0.5" max="1.5" step="0.05" value={num('birdnet', 'sigmoid_sensitivity')}
              oninput={(e) => setNum('birdnet', 'sigmoid_sensitivity', e.currentTarget.value)} />
          </div>
          <div>
            <label class="sub" for="m-pyb">{t('settings.pyBatch')}</label>
            <input id="m-pyb" class="input" type="number" min="1" step="1" value={num('birdnet', 'py_batch_size')}
              oninput={(e) => setNum('birdnet', 'py_batch_size', e.currentTarget.value, true)} />
          </div>
          <div>
            <label class="sub" for="m-prod">{t('settings.producers')}</label>
            <input id="m-prod" class="input" type="number" min="1" step="1" value={num('birdnet', 'n_producers')}
              oninput={(e) => setNum('birdnet', 'n_producers', e.currentTarget.value, true)} />
          </div>
        </div>
        <span class="sub">{t('settings.device')}</span>
        <Pills label={t('settings.device')} bind:value={getDevice, setDevice} options={[
          { value: 'CPU', label: 'CPU' }, { value: 'GPU', label: 'GPU' }]} />
        <span class="muted">{t('settings.deviceHint')}</span>
        <label class="check"><input type="checkbox" checked={Boolean(get('birdnet', 'use_bandpass') ?? true)}
          onchange={(e) => set('birdnet', 'use_bandpass', e.currentTarget.checked)} /> {t('settings.bandpass')}</label>
        <div class="pair">
          <div>
            <label class="sub" for="m-bpmin">{t('settings.bandpassMin')}</label>
            <input id="m-bpmin" class="input" type="number" min="0" step="100" value={num('birdnet', 'bandpass_fmin')}
              oninput={(e) => setNum('birdnet', 'bandpass_fmin', e.currentTarget.value)} />
          </div>
          <div>
            <label class="sub" for="m-bpmax">{t('settings.bandpassMax')}</label>
            <input id="m-bpmax" class="input" type="number" min="0" step="100" value={num('birdnet', 'bandpass_fmax')}
              oninput={(e) => setNum('birdnet', 'bandpass_fmax', e.currentTarget.value)} />
          </div>
        </div>
      </Card>

      <Card title={t('settings.validationMore')} hint={t('settings.validationMoreHint')}>
        <label class="sub" for="m-bands">{t('settings.bands')}</label>
        <input id="m-bands" class="input" value={csv('validation', 'bands')} placeholder="0.3, 0.4, 0.5, 0.7, 1.0"
          onchange={(e) => setCsv('validation', 'bands', e.currentTarget.value)} />
        <div class="pair">
          <div>
            <label class="sub" for="m-npc">{t('settings.nPerCell')}</label>
            <input id="m-npc" class="input" type="number" min="1" step="1" value={num('validation', 'n_per_cell')}
              oninput={(e) => setNum('validation', 'n_per_cell', e.currentTarget.value, true)} />
          </div>
          <div>
            <label class="sub" for="m-pad">{t('settings.clipPad')}</label>
            <input id="m-pad" class="input" type="number" min="0" step="1" value={num('validation', 'clip_pad_s')}
              oninput={(e) => setNum('validation', 'clip_pad_s', e.currentTarget.value)} />
          </div>
          <div>
            <label class="sub" for="m-rmax">{t('settings.rareMax')}</label>
            <input id="m-rmax" class="input" type="number" min="1" step="1" value={num('validation', 'rare_max_events')}
              oninput={(e) => setNum('validation', 'rare_max_events', e.currentTarget.value, true)} />
          </div>
          <div>
            <label class="sub" for="m-rn">{t('settings.rareN')}</label>
            <input id="m-rn" class="input" type="number" min="1" step="1" value={num('validation', 'rare_n')}
              oninput={(e) => setNum('validation', 'rare_n', e.currentTarget.value, true)} />
          </div>
          <div>
            <label class="sub" for="m-vhz">{t('settings.specMaxHz')}</label>
            <input id="m-vhz" class="input" type="number" min="1000" step="500" value={num('validation', 'spec_max_hz')}
              oninput={(e) => setNum('validation', 'spec_max_hz', e.currentTarget.value)} />
          </div>
          <div>
            <label class="sub" for="m-vseed">{t('settings.seed')}</label>
            <input id="m-vseed" class="input" type="number" step="1" value={num('validation', 'seed')}
              oninput={(e) => setNum('validation', 'seed', e.currentTarget.value, true)} />
          </div>
        </div>
        <label class="sub" for="m-vpx">{t('settings.specPx')}</label>
        <input id="m-vpx" class="input" value={csv('validation', 'spec_px')} placeholder="900, 360"
          onchange={(e) => setCsv('validation', 'spec_px', e.currentTarget.value)} />
        {#if listLen('validation', 'spec_px') !== 2}<span class="problem">{t('settings.specPxTwo')}</span>{/if}
      </Card>

      <Card title={t('settings.recallTitle')} hint={t('settings.recallHint')}>
        <div class="pair">
          <div>
            <label class="sub" for="m-rseg">{t('settings.segmentS')}</label>
            <input id="m-rseg" class="input" type="number" min="1" step="10" value={num('recall', 'segment_s')}
              oninput={(e) => setNum('recall', 'segment_s', e.currentTarget.value)} />
          </div>
          <div>
            <label class="sub" for="m-rn2">{t('settings.nSegments')}</label>
            <input id="m-rn2" class="input" type="number" min="1" step="1" value={num('recall', 'n_segments')}
              oninput={(e) => setNum('recall', 'n_segments', e.currentTarget.value, true)} />
          </div>
          <div>
            <label class="sub" for="m-rhz">{t('settings.specMaxHz')}</label>
            <input id="m-rhz" class="input" type="number" min="1000" step="500" value={num('recall', 'spec_max_hz')}
              oninput={(e) => setNum('recall', 'spec_max_hz', e.currentTarget.value)} />
          </div>
          <div>
            <label class="sub" for="m-rseed">{t('settings.seed')}</label>
            <input id="m-rseed" class="input" type="number" step="1" value={num('recall', 'seed')}
              oninput={(e) => setNum('recall', 'seed', e.currentTarget.value, true)} />
          </div>
        </div>
        <label class="sub" for="m-rhours">{t('settings.recallHours')}</label>
        <input id="m-rhours" class="input" value={csv('recall', 'hours')} placeholder="4, 18"
          onchange={(e) => setCsv('recall', 'hours', e.currentTarget.value)} />
        <span class="muted">{t('settings.recallHoursHint')}</span>
        <label class="sub" for="m-rpx">{t('settings.specPx')}</label>
        <input id="m-rpx" class="input" value={csv('recall', 'spec_px')} placeholder="1600, 400"
          onchange={(e) => setCsv('recall', 'spec_px', e.currentTarget.value)} />
        {#if listLen('recall', 'spec_px') !== 2}<span class="problem">{t('settings.specPxTwo')}</span>{/if}
        <span class="sub">{t('settings.recallAudio')}</span>
        <Pills label={t('settings.recallAudio')} bind:value={getRecallAudio, setRecallAudio} options={[
          { value: 'standardized', label: t('settings.inputStandardized') },
          { value: 'filtered', label: t('settings.inputFiltered') }]} />
        <label class="sub" for="m-rrev">{t('validate.reviewer')}</label>
        <input id="m-rrev" class="input" value={str('recall', 'reviewer')}
          oninput={(e) => set('recall', 'reviewer', e.currentTarget.value)} />
      </Card>

      <Card title={t('settings.formatsTitle')} hint={t('settings.formatsHint')}>
        <div class="formats">
          {#each FORMATS as name (name)}
            <label class="check"><input type="checkbox" checked={formats.includes(name)}
              onchange={(e) => toggleFormat(name, e.currentTarget.checked)} /> {t(`settings.format.${name}`)}</label>
          {/each}
        </div>
        {#if !formats.length}<span class="problem">{t('settings.formatsNone')}</span>{/if}
      </Card>
    {/if}
  </div>
</details>

<style>
  .more { display: flex; flex-direction: column; gap: var(--space-3); }
  summary { cursor: pointer; font-weight: var(--weight-semibold); padding: var(--space-2) 0; }
  .more[open] summary { margin-bottom: var(--space-2); }
  .row { display: flex; gap: var(--space-2); align-items: center; }
  .row .input { flex: 1; min-width: 0; }
  .muted { font-size: var(--text-sm); color: var(--muted); margin: 0 0 var(--space-3); }
  .sub { font-size: var(--text-sm); color: var(--muted); margin-top: var(--space-1); }
  .pair { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: var(--space-3); }
  .pair > div { display: flex; flex-direction: column; gap: var(--space-1); min-width: 0; }
  .check { display: flex; align-items: center; gap: var(--space-2); min-height: 40px; font-size: var(--text-sm); cursor: pointer; }
  .check input { width: 18px; height: 18px; margin: 0; }
  .formats { display: flex; flex-wrap: wrap; gap: var(--space-5); }
  .problem { color: var(--rose-ink); font-weight: var(--weight-semibold); font-size: var(--text-sm); }
  textarea.input { resize: vertical; font-family: inherit; }
</style>
