<!-- Step 2 · Scan: demo version for a plain browser (pnpm dev). Numbers are made up. -->
<script lang="ts">
  import PageHeader from '$lib/components/PageHeader.svelte';
  import Card from '$lib/components/Card.svelte';
  import StatTile from '$lib/components/StatTile.svelte';
  import Badge from '$lib/components/Badge.svelte';
  import Button from '$lib/components/Button.svelte';
  import { t } from '$lib/i18n';

  const issues: [string, number][] = [
    ['invalid_name', 0], ['unreadable', 2], ['truncated', 1], ['short', 14],
    ['duplicate', 0], ['gaps', 6], ['outside_deployment', 0]
  ];
</script>

<PageHeader stage="scan" title={t('scan.title')} intro={t('scan.intro')} />
<Card title={t('scan.runTitle')} hint={t('scan.folder', { folder: 'D:/survey/standardized' })}>
  <div class="actions"><Button variant="primary" size="lg">{t('scan.again')}</Button>
    <span class="muted">{t('scan.updated', { when: '2026-10-30 18:12' })}</span></div>
</Card>
<div class="grid-4">
  <StatTile value="12,480" label={t('scan.files')} />
  <StatTile value={6} label={t('scan.grids')} palette="sky" />
  <StatTile value="10,400" label={t('scan.hours')} palette="lavender" />
  <StatTile value="12,463" label={t('scan.pass')} palette="sage" />
</div>
<Card title={t('scan.checksTitle')} hint={t('scan.checksHint')}>
  <ul>
    {#each issues as [id, n] (id)}
      <li class:ok={n === 0}>
        <span class="name">{t(`scan.issues.${id}`)}</span>
        <span class="muted">{t(`scan.issueHints.${id}`)}</span>
        {#if n === 0}<Badge palette="mint">{t('scan.none')}</Badge>{:else}<Badge palette="peach">{n}</Badge>{/if}
      </li>
    {/each}
  </ul>
</Card>

<style>
  .actions { display: flex; align-items: center; gap: var(--space-3); }
  .muted { font-size: var(--text-sm); color: var(--muted); }
  ul { list-style: none; margin: 0; padding: 0; }
  li { display: grid; grid-template-columns: 200px 1fr auto; align-items: center; gap: var(--space-3);
    min-height: 44px; border-bottom: 1px solid var(--line); font-size: var(--text-sm); }
  li:last-child { border-bottom: 0; }
  .name { font-weight: var(--weight-medium); }
  .ok .name { color: var(--muted); font-weight: var(--weight-regular); }
</style>
