<!-- The frame around every screen: sidebar on the left, the screen on the right. -->
<script lang="ts">
  import '@fontsource-variable/inter';
  import '$lib/theme/tokens.css';
  import '$lib/theme/base.css';
  import type { Snippet } from 'svelte';
  import { page } from '$app/state';
  import Sidebar from '$lib/components/Sidebar.svelte';
  import { stageForPath, accentStyle } from '$lib/config/stages';
  import { theme } from '$lib/theme/theme.svelte';

  let { children }: { children: Snippet } = $props();

  const stage = $derived(stageForPath(page.url.pathname));

  $effect(() => {
    document.documentElement.dataset.theme = theme.mode;
  });
</script>

<div class="app">
  <Sidebar current={stage.id} />
  <main style={accentStyle(stage.palette)}>
    <div class="content">
      {@render children()}
    </div>
  </main>
</div>

<style>
  .app { display: flex; height: 100vh; }
  main { flex: 1; min-width: 0; overflow-y: auto; padding: var(--space-8) var(--space-9) var(--space-9); }
  .content {
    max-width: var(--content-max);
    margin: 0 auto;
    display: flex;
    flex-direction: column;
    gap: var(--space-6);
  }
</style>
