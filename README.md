# Sigil

A minimal markup-based email composer built with MoonBit and Proton.

Stage 0 provides a workspace shell: a VS Code-style title bar, activity rail,
tabbed editor, resizable editor/preview split, autosaved local workspace, an
inline Profile tab, and an image library. Documents, open tabs, split position,
profile fields, and imported images persist in browser storage until native
storage is added in a later stage. Images are imported once and inserted as
`<image:...>` lines, so users never paste absolute paths. Parsing, linting,
themes, and SMTP are intentionally not implemented yet.

## Requirements

- MoonBit toolchain (`moon`)
- Proton CLI and runtime: `moon install moonbit-community/proton_cli`
- Warren frontend dev server: `moon install moonbit-community/warren@0.4.5`

`proton_cli setup` prepares the shared CEF runtime used by the desktop window.
Install the native build prerequisites for your platform (for example GTK 3 and
CEF dependencies on Linux) before running the app.

## Commands

```sh
moon check        # type-check all workspace modules
moon test         # run core and workspace tests
proton_cli dev    # start Warren and open the Sigil desktop window
```

Optional build and packaging checks:

```sh
proton_cli build
proton_cli package --dry-run
```

Proton 0.9 reads `proton.project.json`. `proton.conf.json` is kept as a
compatibility symlink to the same file.

## Directory layout

```text
sigil/
├── moon.mod            # root module: core logic
├── moon.mod.json       # legacy module descriptor required by the task
├── moon.work           # workspace: root, src/frontend, src/backend
├── proton.project.json # Proton project configuration
├── proton.conf.json    # symlink to proton.project.json
├── docs/SPEC.md
├── src/
│   ├── core/           # pure MoonBit logic, no GUI or platform imports
│   │   ├── types/      # AST, diagnostics, and profile types
│   │   ├── parser/     # handwritten Sigil markup parser
│   │   ├── render/     # email-safe HTML renderer and preview shell
│   │   ├── linter/     # reserved for the linter stage
│   │   └── themes/     # reserved for the themes stage
│   ├── frontend/       # Rabbita JS target: workspace, tabs, editor, preview
│   └── backend/        # Proton native target: desktop window shell
├── tests/
└── README.md
```

## Workspace behavior

- The tab strip holds multiple email documents plus Profile and Images tabs.
- The Documents list in the sidebar reopens closed files without losing them.
- Profile is a real tab with sectioned settings, not a modal dialog.
- The Images tab and sidebar organize images into nested workspace folders.
  Imports go into the selected folder, each card has a folder menu to move it,
  and inserting an image adds `<image:name>` at the editor cursor.
- The editor and preview stay in sync as you type. Parsing is best-effort so an
  incomplete document still previews valid parts, with diagnostics shown under
  the editor.
- The editor highlights Sigil syntax: header directives, dividers, list markers,
  emphasis, insertions, links, and plain-text, formula, and chart blocks.
- The Export button writes the rendered email-safe HTML through the browser save
  dialog.
- Workspace metadata autosaves on edits; image payloads are stored separately
  so ordinary typing does not rewrite large data URLs.
- Profile supports an uploaded avatar, shown in the title bar and signature.
- Letter styles include minimal and card; footers include legal,
  unsubscribe, and blank; dividers include line, wave, and ornament;
  signatures include classic, minimal, academic, and compact.
- New emails start from a bilingual Sigil template: an introduction, a
  component guide, a signature, and a gray plain-text translation block.
- The title-bar language button toggles English and Chinese UI chrome. Document
  names, profile values, and image names are treated as user content.
- The Styles tab previews and applies the basic letter, footer, divider, and
  signature styles to the selected document.
- The gear icon in the left activity rail opens the Settings tab.
- The Settings tab controls application appearance: dark/light theme, accent
  color, comfortable/compact density, editor font size, and language. It never
  changes the email theme color in the document header.

## Preview and export

The preview iframe uses the sandbox value `allow-same-origin`. Its document is
rebuilt from the current markup on every edit. The shell implements SPEC.md §5.2: a 100% width outer table, a centered
`max-width:640px` reading column, 16px body text at 1.7 line height, 14px
paragraph spacing, and inline CSS. It contains no script element.
