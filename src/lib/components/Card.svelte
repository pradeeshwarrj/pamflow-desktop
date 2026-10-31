<!--
  A white (or dark) card with an optional title and one-line hint.
  <Card title="Recordings folder" hint="Searched in all sub-folders" labelFor="rec"> ... </Card>
  `labelFor` turns the title into a <label> for the input with that id.
-->
<script lang="ts">
  import type { Snippet } from 'svelte';

  let { title, hint, labelFor, actions, children, flush = false }: {
    title?: string;
    hint?: string;
    labelFor?: string;
    actions?: Snippet;
    children?: Snippet;
    flush?: boolean;
  } = $props();
</script>

<section class="card" class:flush>
  {#if title || hint || actions}
    <div class="head">
      <div class="titles">
        {#if title}
          {#if labelFor}<label class="title" for={labelFor}>{title}</label>
          {:else}<span class="title">{title}</span>{/if}
        {/if}
        {#if hint}<span class="hint">{hint}</span>{/if}
      </div>
      {#if actions}{@render actions()}{/if}
    </div>
  {/if}
  {@render children?.()}
</section>

<style>
  .card {
    display: flex;
    flex-direction: column;
    gap: var(--space-3);
    padding: var(--space-5);
    border-radius: var(--radius-xl);
    background: var(--surface);
    border: 1px solid var(--line);
    min-width: 0;
  }
  .card.flush { padding: 0; gap: 0; overflow: hidden; }
  .card.flush .head { padding: var(--space-4) var(--space-5); border-bottom: 1px solid var(--line); }
  .head { display: flex; justify-content: space-between; align-items: center; gap: var(--space-3); }
  .titles { display: flex; flex-direction: column; gap: var(--space-1); }
  .title { font-weight: var(--weight-semibold); }
  .hint { font-size: var(--text-sm); color: var(--muted); }
</style>
