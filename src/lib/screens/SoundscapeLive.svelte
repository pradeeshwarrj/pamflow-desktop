<!-- Soundscape step, connected to pamflow through the analysis engine. -->
<script lang="ts">
  import PageHeader from '$lib/components/PageHeader.svelte';
  import Card from '$lib/components/Card.svelte';
  import Button from '$lib/components/Button.svelte';
  import Badge from '$lib/components/Badge.svelte';
  import { showFolder } from '$lib/backend/tauri';
  import { project } from '$lib/backend/project.svelte';
  import { detectJob, isActive } from '$lib/backend/detect.svelte';
  import { stdJob } from '$lib/backend/standardize.svelte';
  import LongJobPanel from '$lib/components/LongJobPanel.svelte';
  import Icon from '$lib/components/Icon.svelte';
  import { soundscape, syncSoundscape, runSoundscape, asList,
    soundscapeJob, stopSoundscape, soundscapeMinutesLeft, soundscapeMinutesElapsed } from '$lib/backend/soundscape.svelte';
  import { t } from '$lib/i18n';

  // the run name in config.yml: a different one means different results
  const runName = $derived(String(project.facts?.settings.find((x) => x.section === 'soundscape' && x.key === 'run_id')?.value ?? ''));
  $effect(() => syncSoundscape(project.folder, runName));

  const info = $derived(soundscape.info);
  // the saved settings (config.yml), so this follows the Project screen; the run's own copy can be older
  const s = $derived.by(() => {
    const list = project.facts?.settings;
    if (!list) return null;
    const v = (key: string) => list.find((x) => x.section === 'soundscape' && x.key === key)?.value;
    return {
      window_mins: v('window_mins') as number | null, low_stop_hz: v('low_stop_hz') as number | null,
      day_hours: v('day_hours') as number[] | null, indices: v('acoustic_indices') as string[] | null,
      batch_size: v('batch_size') as number | null, workers: v('workers') as number | null
    };
  });
  const computing = $derived(isActive(soundscapeJob.status));
  const running = $derived(computing || soundscape.status === 'running');
  const detecting = $derived(isActive(detectJob.status) || isActive(stdJob.status));
  const columns = $derived(info?.diel?.length ? Object.keys(info.diel[0]).filter((c) => c.endsWith('_mean')) : []);
</script>

<PageHeader stage="soundscape" title={t('soundscape.title')} intro={t('soundscape.intro')} />

{#if !project.folder}
  <Card title={t('detect.chooseProject')}>
    <div><Button variant="primary" href="/">{t('detect.goProject')}</Button></div>
  </Card>
{:else}
  <Card title={t('soundscape.settingsTitle')} hint={t('process.rulesHint')}>
    {#if s}
      <dl>
        <dt>{t('soundscape.window')}</dt>
        <dd>{s.window_mins ? t('soundscape.minutes', { n: s.window_mins }) : t('soundscape.wholeFile')}</dd>
        <dt>{t('soundscape.highpass')}</dt><dd>{t('soundscape.hz', { n: s.low_stop_hz ?? 0 })}</dd>
        <dt>{t('soundscape.dayHours')}</dt><dd>{asList(s.day_hours).join('–')}</dd>
        <dt>{t('soundscape.indices')}</dt><dd>{asList(s.indices).join(', ')}</dd>
        <dt>{t('soundscape.batchSize')}</dt><dd>{t('soundscape.nFiles', { n: s.batch_size ?? 50 })}</dd>
        <dt>{t('project.workers')}</dt><dd>{s.workers ?? t('settings.auto')}</dd>
      </dl>
    {/if}
    <div class="actions">
      <Button variant="primary" size="lg" onclick={() => runSoundscape(project.folder)} disabled={running || detecting}>
        {computing ? t('soundscape.running') : info?.available ? t('soundscape.rerun') : t('soundscape.run')}
      </Button>
      {#if computing}
        <Button variant="accent" onclick={stopSoundscape} disabled={soundscapeJob.status === 'stopping'}>
          <Icon name="pause" size={14} /> {t('detect.stop')}
        </Button>
      {/if}
      {#if info?.available}
        <Button onclick={() => showFolder(info.dir)}>{t('detect.openFolder')}</Button>
        <span class="muted">{t('process.updated', { when: info.updated ?? '' })}</span>
      {/if}
      {#if detecting}<Badge palette="peach">{t('process.waitDetect')}</Badge>{/if}
    </div>
    {#if soundscape.message}<p class="problem">{soundscape.message}</p>{/if}
  </Card>

  {#if soundscapeJob.status !== 'idle'}
    <LongJobPanel job={soundscapeJob} kind="soundscape" onstop={stopSoundscape}
      minutesLeft={soundscapeMinutesLeft} minutesElapsed={soundscapeMinutesElapsed} />
    {#if computing && !soundscapeJob.batch}
      <p class="muted">{t('soundscape.firstBatch', { n: s?.batch_size ?? 50 })}</p>
    {/if}
  {/if}

  {#if info?.available && info.diel}
    <Card title={t('soundscape.resultsTitle')} hint={t('soundscape.resultsHint')}>
      <div class="scroll">
        <table>
          <thead>
            <tr>
              <th>{t('soundscape.site')}</th><th>{t('soundscape.phase')}</th>
              {#each columns as c (c)}<th class="num">{c.replace(/_mean$/, '').toUpperCase()}</th>{/each}
            </tr>
          </thead>
          <tbody>
            {#each info.diel as row (row.grid + '/' + row.diel_phase)}
              <tr>
                <td>{row.grid}</td><td>{row.diel_phase}</td>
                {#each columns as c (c)}<td class="num">{row[c] ?? '–'}</td>{/each}
              </tr>
            {/each}
          </tbody>
        </table>
      </div>
      <p class="muted">{t('soundscape.next')}</p>
      <p class="muted mono">{t('soundscape.files')}: {asList(info.files).join(' · ')}</p>
    </Card>
  {:else if soundscape.status === 'ready'}
    <Card title={t('soundscape.noneTitle')} hint={t('soundscape.noneHint')} />
  {/if}
{/if}

<style>
  dl { margin: 0; display: grid; grid-template-columns: auto 1fr; gap: var(--space-2) var(--space-6); font-size: var(--text-sm); }
  dt { color: var(--muted); }
  dd { margin: 0; }
  .actions { display: flex; flex-wrap: wrap; align-items: center; gap: var(--space-3); margin-top: var(--space-2); }
  .muted { font-size: var(--text-sm); color: var(--muted); margin: 0; }
  .problem { margin: 0; color: var(--rose-ink); font-weight: var(--weight-semibold); font-size: var(--text-sm); }
  .scroll { overflow-x: auto; }
  table { border-collapse: collapse; font-size: var(--text-sm); width: 100%; }
  th, td { padding: var(--space-2) var(--space-3); text-align: left; border-bottom: 1px solid var(--line); }
  .num { text-align: right; font-variant-numeric: tabular-nums; }
</style>
