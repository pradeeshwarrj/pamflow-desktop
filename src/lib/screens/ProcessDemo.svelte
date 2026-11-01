<!-- Step 5 · Process: demo version, shown when the interface runs in a plain browser (pnpm dev). -->
<script lang="ts">
  import PageHeader from '$lib/components/PageHeader.svelte';
  import ProcessResults from './ProcessResults.svelte';
  import { processSummary } from '$lib/mock/demo';
  import { t } from '$lib/i18n';
</script>

<PageHeader stage="process" title={t('process.title')} intro={t('process.intro')} />
<ProcessResults summary={processSummary} />
