<!-- Scan step: live inside the app, demo in a plain browser. -->
<script lang="ts">
  import { inApp } from '$lib/backend/tauri';
  import ScanLive from '$lib/screens/ScanLive.svelte';
  import ScanDemo from '$lib/screens/ScanDemo.svelte';
</script>

{#if inApp}<ScanLive />{:else}<ScanDemo />{/if}
