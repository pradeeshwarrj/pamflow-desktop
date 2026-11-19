<!-- Soundscape indices: needs the analysis engine, so there is no browser demo. -->
<script lang="ts">
  import { inApp } from '$lib/backend/tauri';
  import SoundscapeLive from '$lib/screens/SoundscapeLive.svelte';
  import PageHeader from '$lib/components/PageHeader.svelte';
  import { t } from '$lib/i18n';
</script>

{#if inApp}<SoundscapeLive />{:else}<PageHeader stage="soundscape" title={t('soundscape.title')} intro={t('soundscape.intro')} />{/if}
