<!-- Standardize step: live inside the app, demo in a plain browser. -->
<script lang="ts">
  import { inApp } from '$lib/backend/tauri';
  import StandardizeLive from '$lib/screens/StandardizeLive.svelte';
  import StandardizeDemo from '$lib/screens/StandardizeDemo.svelte';
</script>

{#if inApp}<StandardizeLive />{:else}<StandardizeDemo />{/if}
