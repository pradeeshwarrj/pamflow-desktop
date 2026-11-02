<!-- Filter step: live inside the app, demo in a plain browser. -->
<script lang="ts">
  import { inApp } from '$lib/backend/tauri';
  import FilterLive from '$lib/screens/FilterLive.svelte';
  import FilterDemo from '$lib/screens/FilterDemo.svelte';
</script>

{#if inApp}<FilterLive />{:else}<FilterDemo />{/if}
