<!-- Step 6 · Validate: live inside the app, demo in a plain browser. -->
<script lang="ts">
  import { inApp } from '$lib/backend/tauri';
  import ValidateLive from '$lib/screens/ValidateLive.svelte';
  import ValidateDemo from '$lib/screens/ValidateDemo.svelte';
</script>

{#if inApp}<ValidateLive />{:else}<ValidateDemo />{/if}
