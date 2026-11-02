<!-- Step 1 · Project: live inside the app, demo in a plain browser. -->
<script lang="ts">
  import { inApp } from '$lib/backend/tauri';
  import ProjectLive from '$lib/screens/ProjectLive.svelte';
  import ProjectDemo from '$lib/screens/ProjectDemo.svelte';
</script>

{#if inApp}<ProjectLive />{:else}<ProjectDemo />{/if}
