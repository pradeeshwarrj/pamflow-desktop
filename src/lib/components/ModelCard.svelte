<!--
  The BirdNET model of the project: BirdNET's own global model (downloaded
  once, shared by all projects) or the user's own classifier. Changes go
  into the settings draft; the save bar writes them to the settings file.
-->
<script lang="ts">
  import { onMount } from 'svelte';
  import Card from './Card.svelte';
  import Button from './Button.svelte';
  import Badge from './Badge.svelte';
  import Pills from './Pills.svelte';
  import ProgressBar from './ProgressBar.svelte';
  import { pickFile, showFolder } from '$lib/backend/tauri';
  import { project } from '$lib/backend/project.svelte';
  import { settings, id } from '$lib/backend/settings.svelte';
  import { model, loadModelInfo, downloadModel, stopModelDownload } from '$lib/backend/model.svelte';
  import { t } from '$lib/i18n';

  const f = $derived(project.facts);
  const info = $derived(model.info);

  onMount(() => {
    if (!model.info && project.folder) loadModelInfo(project.folder);
  });

  // ---- the settings draft ----
  const get = (key: string) => settings.draft[id('birdnet', key)];
  const set = (key: string, value: unknown) => (settings.draft[id('birdnet', key)] = value);
  const str = (key: string) => (get(key) ?? '') as string;
  const slash = (p: string) => p.replace(/\\/g, '/');
  const same = (a: string, b: string) => slash(a).replace(/\/+$/, '').toLowerCase() === slash(b).replace(/\/+$/, '').toLowerCase();

  // ---- which model the draft uses ----
  const isDefault = $derived(!!info && same(str('model_dir'), info.dir) && str('classifier_name') === info.name);
  let wantDefault = $state(false); // chosen, but not downloaded yet
  const mode = $derived(isDefault || wantDefault ? 'default' : 'custom');

  const lang = $derived.by(() => {
    const labels = slash(str('labels_file'));
    const m = labels.match(/\/labels\/([^/]+)\.txt$/);
    return m ? m[1] : 'en_us';
  });

  function applyDefault(code = 'en_us') {
    if (!info) return;
    set('model_dir', slash(info.dir));
    set('classifier_name', info.name);
    set('labels_file', `${slash(info.labels_dir)}/${info.languages.includes(code) ? code : (info.languages[0] ?? 'en_us')}.txt`);
    wantDefault = false;
  }

  // Back to the user's own classifier: what the saved settings had, if that was not the default model.
  function applyCustom() {
    const saved = (k: string) => f?.settings.find((s) => s.section === 'birdnet' && s.key === k)?.value as string | undefined;
    const savedDir = saved('model_dir');
    const usable = !!savedDir && !(info && same(savedDir, info.dir));
    set('model_dir', usable ? savedDir : 'models/custom_classifier');
    set('classifier_name', usable ? (saved('classifier_name') ?? 'CustomClassifier') : 'CustomClassifier');
    set('labels_file', null);
    wantDefault = false;
  }

  const choice = {
    get value() { return mode as 'default' | 'custom'; },
    set value(v: 'default' | 'custom') {
      if (v === 'default') { if (info?.downloaded) applyDefault(lang); else wantDefault = true; }
      else applyCustom();
    }
  };

  // a finished download selects the model
  let seen = model.finished;
  $effect(() => {
    if (model.finished !== seen) { seen = model.finished; applyDefault(); }
  });

  async function chooseModel() {
    const p = await pickFile(t('settings.modelFile'), 'BirdNET model', ['tflite']);
    if (!p) return;
    const path = slash(p);
    const cut = path.lastIndexOf('/');
    set('model_dir', path.slice(0, cut));
    set('classifier_name', path.slice(cut + 1).replace(/\.tflite$/i, ''));
    set('labels_file', null);
  }

  // ---- download progress ----
  const mb = (b: number) => (b / 1024 / 1024).toFixed(b > 1e8 ? 0 : 1);
  const percent = $derived(model.total ? (model.done / model.total) * 100 : 0);

  // species-list languages by their own names ("English (US)", "Deutsch")
  const langName = (code: string) => {
    const tag = code.replace('_', '-');
    try {
      const own = new Intl.DisplayNames([tag], { type: 'language' }).of(tag);
      return own && own.toLowerCase() !== tag.toLowerCase() ? `${own} (${code})` : code;
    } catch {
      return code;
    }
  };
</script>

<Card title={t('project.model')} hint={t('settings.modelHint')}>
  <Pills label={t('project.model')} bind:value={choice.value}
    options={[{ value: 'default', label: t('model.default') }, { value: 'custom', label: t('model.custom') }]} />

  {#if mode === 'default'}
    <p class="muted">{t('model.defaultAbout')}</p>

    {#if info?.downloaded}
      <div class="row">
        <Badge palette="mint">{t('model.ready', { version: info.version, n: (info.n_species ?? 0).toLocaleString() })}</Badge>
        <Button variant="ghost" size="sm" onclick={() => showFolder(info.model_file)}>{t('model.showFolder')}</Button>
      </div>
      {#if info.languages.length > 1}
        <label class="sub" for="s-lang">{t('model.language')}</label>
        <select id="s-lang" class="input" value={lang} disabled={!isDefault}
          onchange={(e) => applyDefault(e.currentTarget.value)}>
          {#each info.languages as code (code)}<option value={code}>{langName(code)}</option>{/each}
        </select>
      {/if}
    {:else if model.downloading}
      <ProgressBar percent={model.phase === 'extract' ? 100 : percent} label={t('model.downloading')} />
      <div class="row">
        <span class="muted">
          {model.phase === 'extract' ? t('model.unpacking') : t('model.downloadingOf', { done: mb(model.done), total: mb(model.total) })}
        </span>
        <Button size="sm" onclick={stopModelDownload}>{t('model.cancel')}</Button>
      </div>
    {:else}
      <div class="row">
        <Button variant="primary" onclick={() => downloadModel(project.folder)} disabled={!project.folder}>
          {model.message ? t('model.again') : t('model.download')}
        </Button>
        <span class="muted">{t('model.downloadSize')}</span>
      </div>
      {#if model.message}<p class="problem">{model.message}</p>{/if}
    {/if}
    <p class="muted small">{t('model.license')}</p>
  {:else}
    <div class="row">
      <div class="file">
        <span class="mono">{str('classifier_name') || '–'}.tflite</span>
        <span class="muted small">{str('model_dir')}</span>
      </div>
      <Button onclick={chooseModel}>{t('settings.chooseModel')}</Button>
    </div>
    {#if f?.model_found && f?.labels_found}
      <Badge palette="mint">{t('settings.modelReady', { n: f.n_labels ?? 0 })}</Badge>
    {:else}
      <Badge palette="peach">{t('settings.modelNotFound')}</Badge>
    {/if}
  {/if}

  <label class="sub" for="s-run">{t('settings.runName')}</label>
  <input id="s-run" class="input" value={str('run_id')}
    oninput={(e) => set('run_id', e.currentTarget.value)} />
</Card>

<style>
  .row { display: flex; gap: var(--space-2); align-items: center; flex-wrap: wrap; }
  .file { flex: 1; min-width: 0; display: flex; flex-direction: column; min-height: var(--control-height); justify-content: center;
    padding: 0 var(--space-3); border-radius: var(--radius-md); background: var(--soft); }
  .muted { margin: 0; font-size: var(--text-sm); color: var(--muted); }
  .small { font-size: var(--text-xs); overflow: hidden; text-overflow: ellipsis; }
  .sub { font-size: var(--text-sm); color: var(--muted); margin-top: var(--space-1); }
  .problem { margin: 0; color: var(--rose-ink); font-weight: var(--weight-semibold); font-size: var(--text-sm); white-space: pre-wrap; }
</style>
