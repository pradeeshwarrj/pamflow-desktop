<!-- Placeholder for steps whose screen is not built yet. -->
<script lang="ts">
  import PageHeader from './PageHeader.svelte';
  import Card from './Card.svelte';
  import { t } from '$lib/i18n';

  let { stage }: { stage: string } = $props();
</script>

<PageHeader {stage} title={t(`stages.${stage}`)} />
<Card title={t('common.notBuiltTitle')} hint={t('common.notBuiltBody')} />
