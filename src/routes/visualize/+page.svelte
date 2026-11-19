<!-- Soundscape plots and report: needs the analysis engine, so there is no browser demo. -->
<script lang="ts">
  import { inApp } from '$lib/backend/tauri';
  import VisualizeLive from '$lib/screens/VisualizeLive.svelte';
  import PageHeader from '$lib/components/PageHeader.svelte';
  import { t } from '$lib/i18n';
</script>

{#if inApp}<VisualizeLive />{:else}<PageHeader stage="visualize" title={t('visualize.title')} intro={t('visualize.intro')} />{/if}
