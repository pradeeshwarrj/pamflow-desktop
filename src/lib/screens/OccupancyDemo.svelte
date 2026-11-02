<!-- Occupancy step: demo version, shown when the interface runs in a plain browser (pnpm dev). -->
<script lang="ts">
  import PageHeader from '$lib/components/PageHeader.svelte';
  import OccupancyResults from './OccupancyResults.svelte';
  import { occupancyInfo } from '$lib/mock/demo';
  import { t } from '$lib/i18n';

  let selected = $state(occupancyInfo.summary[0].species);
</script>

<PageHeader stage="occupancy" title={t('occupancy.title')} intro={t('occupancy.intro')} />
<OccupancyResults info={occupancyInfo} bind:selected />
