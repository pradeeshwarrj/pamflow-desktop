<!-- A folder/file path box with a Browse button. -->
<script lang="ts">
  import Button from './Button.svelte';
  import { t } from '$lib/i18n';

  let { id, value = $bindable(), onbrowse }: {
    id: string;
    value: string;
    onbrowse?: () => void;
  } = $props();
</script>

<div class="row">
  <input {id} class="input" bind:value />
  <Button onclick={onbrowse}>{t('common.browse')}</Button>
</div>

<style>
  .row { display: flex; gap: var(--space-2); }
</style>
