<!--
  One button style for the whole app.
  variant: primary (dark solid) | secondary (outlined) | ghost (text only)
           | accent (step colour, solid) | accent-outline (step colour, outlined)
  Give `href` to make it a link that looks like a button.
-->
<script lang="ts">
  import type { Snippet } from 'svelte';

  type Variant = 'primary' | 'secondary' | 'ghost' | 'accent' | 'accent-outline';

  let { variant = 'secondary', size = 'md', href, onclick, type = 'button', full = false, children, ...rest }: {
    variant?: Variant;
    size?: 'sm' | 'md' | 'lg';
    href?: string;
    onclick?: (e: MouseEvent) => void;
    type?: 'button' | 'submit';
    full?: boolean;
    children?: Snippet;
    [attr: string]: unknown;
  } = $props();
</script>

{#if href}
  <a {href} class="btn {variant} {size}" class:full {...rest}>{@render children?.()}</a>
{:else}
  <button {type} class="btn {variant} {size}" class:full {onclick} {...rest}>{@render children?.()}</button>
{/if}

<style>
  .btn {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    gap: var(--space-2);
    min-height: var(--control-height);
    padding: 0 var(--space-4);
    border-radius: var(--radius-lg);
    border: 1px solid transparent;
    font-weight: var(--weight-semibold);
    text-decoration: none;
    cursor: pointer;
    white-space: nowrap;
    transition: opacity 0.15s, background 0.15s;
  }
  .btn:hover { opacity: 0.88; }
  .sm { min-height: 36px; padding: 0 var(--space-3); font-size: var(--text-sm); font-weight: var(--weight-medium); border-radius: var(--radius-md); }
  .lg { min-height: 48px; padding: 0 var(--space-6); }
  .full { width: 100%; }

  .primary { background: var(--ink); color: var(--bg); }
  .secondary { background: var(--surface); color: var(--ink); border-color: var(--line); }
  .ghost { background: transparent; color: var(--muted); font-weight: var(--weight-medium); }
  .ghost:hover { color: var(--ink); opacity: 1; }
  .accent { background: var(--accent-ink); color: var(--accent-tint); }
  .accent-outline { background: transparent; color: var(--accent-ink); border: 1.5px solid var(--accent-ink); }
</style>
