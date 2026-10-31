# How to change pamflow Desktop

Every kind of change has **one place** to make it. Run `pnpm tauri dev` and
keep the window open: when you save a file, the app updates by itself.

| I want to change… | Edit this file |
|---|---|
| A colour, font, size, spacing, corner roundness | `src/lib/theme/tokens.css` |
| Dark-mode colours | `src/lib/theme/tokens.css` → the `[data-theme='dark']` block |
| Any text on screen (titles, buttons, hints) | `src/lib/i18n/en.json` |
| The order of steps, or which pastel a step uses | `src/lib/config/stages.ts` |
| The demo numbers shown on screen | `src/lib/mock/demo.ts` |
| An icon, or add a new one | `src/lib/components/Icon.svelte` |
| The logo | `src/lib/components/Logo.svelte` |
| The look of all buttons / cards / pills | `src/lib/components/Button.svelte`, `Card.svelte`, `Pills.svelte` |
| What is on one screen | `src/routes/<step>/+page.svelte` (Project is `src/routes/+page.svelte`) |
| Window size and title | `src-tauri/tauri.conf.json` → `app.windows` |

## Examples

**Make the Detect step mint instead of lavender**
In `src/lib/config/stages.ts` change `palette: 'lavender'` to `palette: 'mint'`
on the `detect` line. The sidebar, chip, progress panel and buttons all follow.

**Make the lavender softer**
In `tokens.css` change `--lavender-tint` (background) and `--lavender-ink`
(text on it). Do it in both the light block and the dark block.

**Rename a button**
Find the text in `en.json` (for example `"save": "Save and scan recordings"`)
and change only the part on the right of the colon. Keep `{placeholders}` like
`{n}` as they are; the app fills them in.

**Rounder corners everywhere**
In `tokens.css` raise `--radius-xl` (cards) and `--radius-lg` (buttons).

## Rules that keep it easy

- Screens never contain colours or text directly: colours come from
  `tokens.css`, text from `en.json`. Keep it that way when adding things.
- Inside a step's screen, `var(--accent-tint)` and `var(--accent-ink)`
  always mean "this step's pastel". Use them instead of a named colour.
- New screens are built from the pieces in `src/lib/components`.

## Building blocks (src/lib/components)

| Piece | Used for |
|---|---|
| `PageHeader` | Step chip, title, intro at the top of a screen |
| `Card` | Any white box with a title and one-line hint |
| `StatTile` | A big number with a label |
| `Button` | All buttons: primary, secondary, ghost, accent, accent-outline |
| `Pills` | Choose one of a few options |
| `PathField` | Folder/file box with a Browse button |
| `ProgressBar` | Any progress or bar chart bar |
| `Badge` | Small coloured label |
| `Spectrogram` | Spectrogram panel (demo picture now, real image later) |
| `ThemeSwitch`, `Sidebar`, `Logo`, `Icon` | App frame |
| `ComingSoon` | Placeholder for steps not built yet |
