<!--
  Pick one option from a few, shown as a segmented pill row.
  <Pills label="CPU workers" options={[{ value: 4, label: '4' }]} bind:value={workers} />
-->
<script lang="ts" generics="T extends string | number">
  let { options, value = $bindable(), label }: {
    options: { value: T; label: string }[];
    value: T;
    label: string;
  } = $props();
</script>

<div class="pills" role="radiogroup" aria-label={label}>
  {#each options as option (option.value)}
    <button
      type="button"
      role="radio"
      aria-checked={option.value === value}
      class:on={option.value === value}
      onclick={() => (value = option.value)}
    >{option.label}</button>
  {/each}
</div>

<style>
  .pills {
    display: flex;
    gap: var(--space-1);
    padding: var(--space-1);
    border-radius: var(--radius-lg);
    background: var(--soft);
  }
  button {
    flex: 1;
    min-height: 40px;
    padding: 0 var(--space-3);
    border-radius: 9px;
    border: 0;
    background: transparent;
    color: var(--muted);
    font-weight: var(--weight-medium);
    cursor: pointer;
  }
  button.on { background: var(--raised); color: var(--ink); box-shadow: var(--shadow-raised); }
</style>
