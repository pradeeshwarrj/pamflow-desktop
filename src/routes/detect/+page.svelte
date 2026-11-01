<!-- Step 4 · Detect: live inside the app, demo in a plain browser. -->
<script lang="ts">
  import { inApp } from '$lib/backend/tauri';
  import DetectLive from '$lib/screens/DetectLive.svelte';
  import DetectDemo from '$lib/screens/DetectDemo.svelte';
</script>

{#if inApp}<DetectLive />{:else}<DetectDemo />{/if}
