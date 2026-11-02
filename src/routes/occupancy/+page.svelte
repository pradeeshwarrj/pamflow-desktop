<!-- Step 7 · Occupancy: live inside the app, demo in a plain browser. -->
<script lang="ts">
  import { inApp } from '$lib/backend/tauri';
  import OccupancyLive from '$lib/screens/OccupancyLive.svelte';
  import OccupancyDemo from '$lib/screens/OccupancyDemo.svelte';
</script>

{#if inApp}<OccupancyLive />{:else}<OccupancyDemo />{/if}
