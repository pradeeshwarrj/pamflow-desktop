<!-- Step 3 · Filter: demo version for a plain browser (pnpm dev). Numbers are made up. -->
<script lang="ts">
  import PageHeader from '$lib/components/PageHeader.svelte';
  import Card from '$lib/components/Card.svelte';
  import Button from '$lib/components/Button.svelte';
  import Pills from '$lib/components/Pills.svelte';
  import Icon from '$lib/components/Icon.svelte';
  import { t } from '$lib/i18n';

  let workers = $state(4);
</script>

<PageHeader stage="filter" title={t('filter.title')} intro={t('filter.intro')} />
<Card title={t('filter.settingsTitle')} hint={t('filter.settingsHint')}>
  <dl>
    <dt>{t('filter.filter')}</dt><dd>{t('filter.highpass', { hz: 500, order: 4 })}</dd>
    <dt>{t('filter.output')}</dt><dd class="mono">D:/survey/filtered</dd>
    <dt>{t('filter.space')}</dt><dd>{t('filter.needs', { size: '118.4 GB' })} · {t('filter.free', { size: '1.6 TB' })}</dd>
  </dl>
  <div class="field">
    <span class="label">{t('project.workers')}</span>
    <Pills label={t('project.workers')} bind:value={workers}
      options={[2, 4, 8, 12].map((n) => ({ value: n, label: String(n) }))} />
    <span class="muted">{t('filter.workersHint')}</span>
  </div>
  <div><Button variant="primary" size="lg"><Icon name="play" size={14} /> {t('filter.start')}</Button></div>
</Card>

<style>
  dl { margin: 0; display: grid; grid-template-columns: auto 1fr; gap: var(--space-2) var(--space-6); font-size: var(--text-sm); }
  dt { color: var(--muted); }
  dd { margin: 0; }
  .field { display: flex; flex-direction: column; gap: var(--space-2); }
  .label { font-weight: var(--weight-semibold); }
  .muted { font-size: var(--text-sm); color: var(--muted); }
</style>
