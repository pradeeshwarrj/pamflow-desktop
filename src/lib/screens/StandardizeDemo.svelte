<!-- Standardize step: demo version for a plain browser (pnpm dev). Numbers are made up. -->
<script lang="ts">
  import PageHeader from '$lib/components/PageHeader.svelte';
  import Card from '$lib/components/Card.svelte';
  import StatTile from '$lib/components/StatTile.svelte';
  import Button from '$lib/components/Button.svelte';
  import Pills from '$lib/components/Pills.svelte';
  import Icon from '$lib/components/Icon.svelte';
  import { t } from '$lib/i18n';

  let format = $state<'flac' | 'wav'>('flac');
  let rate = $state(48000);
  let channels = $state(1);
  const examples = [
    ['MEMO_20260405_182425.WAV', 'G0059/G0059_20260405_182425.flac'],
    ['MEMO_20260405_192425.WAV', 'G0059/G0059_20260405_192425.flac'],
    ['MEMO_20260406_060000.WAV', 'G0263/G0263_20260406_060000.flac']
  ];
</script>

<PageHeader stage="standardize" title={t('standardize.title')} intro={t('standardize.intro')} />
<div class="grid-2">
  <Card title={t('standardize.audioTitle')} hint={t('standardize.audioHint')}>
    <span class="sub">{t('standardize.format')}</span>
    <Pills label={t('standardize.format')} bind:value={format}
      options={[{ value: 'flac', label: t('standardize.flac') }, { value: 'wav', label: 'WAV' }]} />
    <span class="sub">{t('standardize.rate')}</span>
    <Pills label={t('standardize.rate')} bind:value={rate}
      options={[24000, 32000, 44100, 48000].map((r) => ({ value: r, label: `${r / 1000} kHz` }))} />
    <span class="sub">{t('standardize.channels')}</span>
    <Pills label={t('standardize.channels')} bind:value={channels}
      options={[{ value: 1, label: t('standardize.mono') }, { value: 2, label: t('standardize.stereo') }]} />
  </Card>
  <Card title={t('standardize.checkTitle')} hint={t('standardize.checkHint')}>
    <div><Button size="lg">{t('standardize.checkAgain')}</Button></div>
    <span class="sub">{t('standardize.checked', { when: '2026-10-30 17:05' })}</span>
  </Card>
</div>
<div class="grid-4">
  <StatTile value="12,480" label={t('standardize.recordings')} palette="mint" />
  <StatTile value={37} label={t('standardize.memos')} palette="butter" />
  <StatTile value={12} label={t('standardize.nonAudio')} palette="lavender" />
  <StatTile value={2} label={t('standardize.corrupt')} palette="peach" />
</div>
<Card title={t('standardize.planTitle')} hint={t('standardize.planHint', { convert: '12,480', copy: 0 })}>
  <table>
    <thead><tr><th>{t('standardize.from')}</th><th></th><th>{t('standardize.to')}</th></tr></thead>
    <tbody>{#each examples as [a, b] (a)}<tr><td class="mono">{a}</td><td>→</td><td class="mono">{b}</td></tr>{/each}</tbody>
  </table>
  <div><Button variant="primary" size="lg"><Icon name="play" size={14} /> {t('standardize.start', { n: '12,480' })}</Button></div>
</Card>

<style>
  .sub { font-size: var(--text-sm); color: var(--muted); margin-top: var(--space-1); }
  table { width: 100%; border-collapse: collapse; font-size: var(--text-sm); }
  th, td { text-align: left; padding: var(--space-2) var(--space-3); border-bottom: 1px solid var(--line); }
  th { color: var(--muted); font-weight: var(--weight-medium); }
</style>
