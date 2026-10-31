<!-- Left sidebar: app name, the workflow steps, theme switch. -->
<script lang="ts">
  import Logo from './Logo.svelte';
  import ThemeSwitch from './ThemeSwitch.svelte';
  import { stages, accentStyle } from '$lib/config/stages';
  import { stageStatus, project } from '$lib/mock/demo';
  import { t } from '$lib/i18n';

  let { current }: { current: string } = $props();
</script>

<nav aria-label={t('common.workflowSteps')}>
  <div class="brand">
    <Logo />
    <div class="names">
      <span class="app">{t('app.name')}</span>
      <span class="project">{project.name}</span>
    </div>
  </div>

  <ol class="steps">
    {#each stages as stage (stage.id)}
      {@const status = stageStatus[stage.id] ?? {}}
      {@const active = stage.id === current}
      <li>
        <a
          href={stage.path}
          class="step"
          class:active
          class:done={status.done}
          style={accentStyle(stage.palette)}
          aria-current={active ? 'page' : undefined}
        >
          <span class="dot"></span>
          <span class="name">{t(`stages.${stage.id}`)}</span>
          <span class="note">{status.done ? t('common.done') : (status.note ?? '')}</span>
        </a>
      </li>
    {/each}
  </ol>

  <div class="foot">
    <ThemeSwitch />
    <span class="version">{t('app.version')}</span>
  </div>
</nav>

<style>
  nav {
    flex: 0 0 var(--sidebar-width);
    display: flex;
    flex-direction: column;
    gap: var(--space-7);
    padding: var(--space-7) var(--space-4);
    background: var(--sidebar);
    border-right: 1px solid var(--line);
    overflow-y: auto;
  }
  .brand { display: flex; align-items: center; gap: var(--space-3); padding: 0 var(--space-2); }
  .names { display: flex; flex-direction: column; }
  .app { font-weight: var(--weight-bold); font-size: var(--text-lg); letter-spacing: -0.01em; }
  .project { font-size: var(--text-xs); color: var(--muted); }

  .steps { list-style: none; margin: 0; padding: 0; display: flex; flex-direction: column; gap: 2px; }
  .step {
    display: flex;
    align-items: center;
    gap: var(--space-3);
    min-height: 40px;
    padding: 0 var(--space-3);
    border-radius: var(--radius-md);
    text-decoration: none;
    font-weight: var(--weight-medium);
  }
  .step:hover { background: var(--soft); }
  .step.active {
    background: var(--accent-tint);
    color: var(--accent-ink);
    font-weight: var(--weight-semibold);
  }
  .dot {
    width: 8px;
    height: 8px;
    border-radius: 50%;
    border: 2px solid var(--muted);
  }
  .step.done .dot, .step.active .dot { border-color: var(--accent-ink); background: var(--accent-ink); }
  .name { flex: 1; }
  .note { font-size: var(--text-xs); color: var(--muted); }
  .step.active .note { color: var(--accent-ink); }

  .foot { margin-top: auto; display: flex; flex-direction: column; gap: var(--space-3); padding: 0 var(--space-2); }
  .version { font-size: var(--text-xs); color: var(--muted); }
</style>
