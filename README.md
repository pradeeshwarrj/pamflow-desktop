# pamflow Desktop

A standalone desktop app (Windows, macOS, Linux) for the pamflow passive
acoustic monitoring workflow. The interface is built with Tauri (Rust) and
SvelteKit; the analysis is done by the pamflow R package, bundled inside the
app so users install nothing else.

**Status:** interface only, with demo data. Connecting it to R is next.

## Run it

```
pnpm install
pnpm tauri dev
```

The first run compiles Rust and takes a few minutes; later runs take seconds.

## Change it

See [HOW-TO-CHANGE.md](HOW-TO-CHANGE.md): colours, text, steps and screens
each have one file.

## Layout

```
src/
  lib/
    theme/       tokens.css (all colours and sizes), base.css, light/dark switch
    config/      stages.ts (the workflow steps)
    i18n/        en.json (all text)
    mock/        demo.ts (demo numbers until R is connected)
    components/  reusable building blocks
  routes/        one folder per screen
src-tauri/       Rust side and app settings (tauri.conf.json)
```
