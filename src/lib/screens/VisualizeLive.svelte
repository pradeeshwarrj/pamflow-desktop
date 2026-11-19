<!-- Soundscape plots and HTML report (pamflow Stage 2c), connected through the analysis engine. -->
<script lang="ts">
  import PageHeader from '$lib/components/PageHeader.svelte';
  import Card from '$lib/components/Card.svelte';
  import Button from '$lib/components/Button.svelte';
  import { showFolder, openFile } from '$lib/backend/tauri';
  import { project } from '$lib/backend/project.svelte';
  import { isActive } from '$lib/backend/detect.svelte';
  import { soundscape, soundscapeJob, syncSoundscape, runSoundscapeVis, plotUrl, asList } from '$lib/backend/soundscape.svelte';
  import { t } from '$lib/i18n';

  // the run name in config.yml: a different one means different results
  const runName = $derived(String(project.facts?.settings.find((x) => x.section === 'soundscape' && x.key === 'run_id')?.value ?? ''));
  $effect(() => syncSoundscape(project.folder, runName));

  const info = $derived(soundscape.info);
  const making = $derived(soundscape.status === 'running');
  const blocked = $derived(making || isActive(soundscapeJob.status));
  const canMake = $derived(Boolean(info?.available || info?.has_raw)); // results so far are enough
  const files = $derived(asList(info?.plots));
  // diel_hourly_<index>.png and diel_phase_<index>.png
  const pictures = (prefix: string) =>
    files.filter((f) => f.startsWith(prefix)).map((f) => ({ file: f, name: f.slice(prefix.length).replace(/[.]png$/, '').toUpperCase() }));
  const diel = $derived(pictures('diel_hourly_'));
  const phase = $derived(pictures('diel_phase_'));
</script>

<PageHeader stage="visualize" title={t('visualize.title')} intro={t('visualize.intro')} />

{#if !project.folder}
  <Card title={t('detect.chooseProject')}>
    <div><Button variant="primary" href="/">{t('detect.goProject')}</Button></div>
  </Card>
{:else}
  <Card title={t('visualize.title')}>
    {#if !canMake && soundscape.status !== 'loading'}
      <p class="muted">{t('visualize.needIndices')}</p>
    {:else if info?.n_files}
      <p class="muted">{t('visualize.coverage', { n: info.n_files })}</p>
    {/if}
    <div class="actions">
      <Button variant="primary" size="lg" onclick={() => runSoundscapeVis(project.folder)} disabled={blocked || !canMake}>
        {making ? t('visualize.making') : info?.report || files.length ? t('visualize.remake') : t('visualize.make')}
      </Button>
      {#if info?.report}<Button onclick={() => openFile(info.report!)}>{t('visualize.openReport')}</Button>{/if}
      {#if info?.plots_dir}<Button onclick={() => showFolder(info.plots_dir!)}>{t('detect.openFolder')}</Button>{/if}
    </div>
    {#if soundscape.message}<p class="problem">{soundscape.message}</p>{/if}
  </Card>

  {#each [
    { title: 'dielTitle', hint: 'dielHint', items: diel },
    { title: 'phaseTitle', hint: 'phaseHint', items: phase }
  ] as group (group.title)}
    {#if group.items.length}
      <Card title={t(`visualize.${group.title}`)} hint={t(`visualize.${group.hint}`)}>
        <div class="gallery">
          {#each group.items as p (p.file)}
            <figure>
              <img src={plotUrl(info!, p.file)} alt={`${t(`visualize.${group.title}`)} · ${p.name}`} loading="lazy" />
              <figcaption>{p.name}</figcaption>
            </figure>
          {/each}
        </div>
      </Card>
    {/if}
  {/each}
  {#if info?.available && !files.length && soundscape.status !== 'running'}
    <p class="muted">{t('visualize.none')}</p>
  {/if}
{/if}

<style>
  .actions { display: flex; flex-wrap: wrap; align-items: center; gap: var(--space-3); }
  .muted { font-size: var(--text-sm); color: var(--muted); margin: 0; }
  .problem { margin: 0; color: var(--rose-ink); font-weight: var(--weight-semibold); font-size: var(--text-sm); }
  .gallery { display: grid; grid-template-columns: repeat(auto-fill, minmax(320px, 1fr)); gap: var(--space-4); }
  figure { margin: 0; display: flex; flex-direction: column; gap: var(--space-2); }
  img { width: 100%; height: auto; border-radius: var(--radius-lg); background: #fff; }
  figcaption { font-size: var(--text-sm); font-weight: var(--weight-semibold); }
</style>
