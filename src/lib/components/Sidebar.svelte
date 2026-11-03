<!-- Left sidebar: app name, the workflow steps, theme switch. -->
<script lang="ts">
  import Logo from './Logo.svelte';
  import ThemeSwitch from './ThemeSwitch.svelte';
  import { stages, accentStyle } from '$lib/config/stages';
  import { stageStatus as demoStatus, project as demoProject } from '$lib/mock/demo';
  import { inApp } from '$lib/backend/tauri';
  import { project } from '$lib/backend/project.svelte';
  import { detectJob, isActive } from '$lib/backend/detect.svelte';
  import { filterJob, filterInfo } from '$lib/backend/filter.svelte';
  import { scan } from '$lib/backend/scan.svelte';
  import { appInfo, saveDiagnostics } from '$lib/backend/appinfo.svelte';
  import { stdJob, standardize } from '$lib/backend/standardize.svelte';
  import { processJob } from '$lib/backend/process.svelte';
  import { validation } from '$lib/backend/validation.svelte';
  import { occupancy } from '$lib/backend/occupancy.svelte';
  import { report } from '$lib/backend/report.svelte';
  import { t } from '$lib/i18n';

  let { current }: { current: string } = $props();

  type Status = { done?: boolean; note?: string };

  // Inside the app: what is known about this project. In a plain browser: the demo.
  const status = $derived.by((): Record<string, Status> => {
    if (!inApp) return demoStatus;
    const f = project.facts;
    const out: Record<string, Status> = {};
    if (f) out.project = { done: true };
    if (isActive(stdJob.status)) {
      out.standardize = stdJob.total
        ? { note: `${Math.floor(((stdJob.done + stdJob.failed) / stdJob.total) * 100)}%` } : { note: '…' };
    } else if (stdJob.status === 'finished' || standardize.state?.last_run.available) out.standardize = { done: true };
    if (scan.status === 'scanning') out.scan = { note: '…' };
    else if (f?.scanned || scan.summary?.available) out.scan = { done: true };
    if (isActive(filterJob.status) && filterJob.total) {
      out.filter = { note: `${Math.floor(((filterJob.done + filterJob.failed) / filterJob.total) * 100)}%` };
    } else if (filterJob.status === 'finished' || (filterInfo.settings?.already_done ?? 0) > 0) out.filter = { done: true };
    if (isActive(detectJob.status) && detectJob.total) {
      out.detect = { note: `${Math.floor(((detectJob.done + detectJob.failed) / detectJob.total) * 100)}%` };
    } else if (detectJob.status === 'finished') out.detect = { done: true };
    if (processJob.summary?.available) out.process = { done: true };
    const samples = validation.info?.samples ?? [];
    if (samples.length) {
      const answered = samples.filter((s) => validation.answers[s.sample_id]).length;
      out.validate = answered === samples.length ? { done: true } : { note: `${answered}/${samples.length}` };
    }
    if (occupancy.info?.available) out.occupancy = { done: true };
    if (report.preview?.files.some((x) => x.exists)) out.report = { done: true };
    return out;
  });

  const projectName = $derived(
    inApp ? (project.facts?.root ?? project.folder).split(/[\\/]/).filter(Boolean).pop() ?? '' : demoProject.name
  );
</script>

<nav aria-label={t('common.workflowSteps')}>
  <div class="brand">
    <Logo />
    <div class="names">
      <span class="app">{t('app.name')}</span>
      <span class="project">{projectName}</span>
    </div>
  </div>

  <ol class="steps">
    {#each stages as stage (stage.id)}
      {@const st = status[stage.id] ?? {}}
      {@const active = stage.id === current}
      <li>
        <a
          href={stage.path}
          class="step"
          class:active
          class:done={st.done}
          style={accentStyle(stage.palette)}
          aria-current={active ? 'page' : undefined}
        >
          <span class="dot"></span>
          <span class="name">{t(`stages.${stage.id}`)}</span>
          <span class="note">{st.done ? t('common.done') : (st.note ?? '')}</span>
        </a>
      </li>
    {/each}
  </ol>

  <div class="foot">
    <ThemeSwitch />
    {#if !inApp}
      <span class="version">{t('app.version')}</span>
    {:else}
      {#if appInfo.runtimeFound === false}
        <span class="version warn" title={appInfo.runtimeMessage}>{t('app.runtimeMissing')}</span>
      {/if}
      <span class="version">
        {t('app.versionLine', { app: appInfo.app || '–' })}{appInfo.pamflow ? ` · pamflow ${appInfo.pamflow}` : ''}
      </span>
      <button class="link" onclick={() => saveDiagnostics(project.folder, { title: t('app.diagnosticsTitle'), kind: t('app.textFiles') })}
        disabled={appInfo.diagnosticsBusy}>
        {appInfo.diagnosticsBusy ? t('app.diagnosticsBusy') : t('app.diagnostics')}
      </button>
      {#if appInfo.diagnosticsError}<span class="version warn">{appInfo.diagnosticsError}</span>{/if}
    {/if}
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
  .version.warn { color: var(--rose-ink); font-weight: var(--weight-semibold); overflow-wrap: anywhere; }
  .link { align-self: flex-start; padding: 0; border: 0; background: none; font: inherit; font-size: var(--text-xs);
    color: var(--muted); text-decoration: underline; cursor: pointer; }
  .link:hover:not(:disabled) { color: var(--text); }
  .link:disabled { cursor: default; opacity: 0.6; }
</style>
