<!-- Step 5 · Process: live inside the app, demo in a plain browser. -->
<script lang="ts">
  import { inApp } from '$lib/backend/tauri';
  import ProcessLive from '$lib/screens/ProcessLive.svelte';
  import ProcessDemo from '$lib/screens/ProcessDemo.svelte';
</script>

{#if inApp}<ProcessLive />{:else}<ProcessDemo />{/if}
