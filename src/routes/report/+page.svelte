<!-- Step 8 · Report: live inside the app, demo in a plain browser. -->
<script lang="ts">
  import { inApp } from '$lib/backend/tauri';
  import ReportLive from '$lib/screens/ReportLive.svelte';
  import ReportDemo from '$lib/screens/ReportDemo.svelte';
</script>

{#if inApp}<ReportLive />{:else}<ReportDemo />{/if}
