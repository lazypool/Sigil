# AGENTS.md

Guidance for agents working in this repository.

## Project

Sigil is a MoonBit, markup-based email composer built with Proton and Rabbita.
The language spec is `docs/SPEC.md`; the user-facing overview is `README.md`.

## Layout

- `src/core/` — `types`, `parser`, `highlight`, `render`, `linter`, `themes`.
- `src/frontend/` — Rabbita workspace (tabs, editor, preview).
- `src/backend/` — Proton native desktop shell.
- `src/contract/` — shared mail types between frontend and backend.
- `tests/` — workspace tests.

## Commands

- `moon check` — type-check the workspace.
- `moon test` — run the test suite.
- `proton_cli build` — build the desktop app.
- `proton_cli dev` — run the app in development mode.
- `proton_cli package --dry-run` — verify packaging.
- `warren -C src/frontend build --browser-entry main` — build only the
  frontend bundle (the step `proton_cli build` runs for the frontend). The
  `-C` flag is required: warren resolves the browser entry against the
  workspace root, not the current directory.

Run `moon check` and `moon test` after code changes. Run the build when
touching the frontend or backend.

## Git conventions

### Commit message format

Use Conventional Commits with a **required** scope:

```txt
<type>(<scope>): <subject>

<body>

<trailer>
```

- **Type** — one of `feat`, `fix`, `chore`, `docs`, `refactor`, `test`,
  `style`, `perf`, `build`, `ci`, `revert`.
- **Scope** — required. Use the affected area: `app`, `core`, `contract`,
  `frontend`, `backend`, `readme`, `docs`, `build`, or `ci`. Never omit the
  scope, even for `docs` or `chore`.
- **Subject** — imperative mood, lowercase, no trailing period, at most 72
  characters. Describe the change, not the file.

### Body

- Required for non-trivial changes, separated from the subject by one blank
  line.
- Explain what changed and why, wrapped at 72 characters. Use paragraphs and
  `-` bullet lists; do not narrate the diff line by line.

### Trailers

- End every commit with a `Signed-off-by` trailer using your configured Git
  identity, separated from the body by one blank line:

  ```txt
  Signed-off-by: Your Name <you@example.com>
  ```

- Place other trailers (for example `Co-authored-by`) above `Signed-off-by`,
  one per line.

### Rules

- Keep one logical change per commit; do not mix refactors with behavior
  changes.
- Do not commit generated artifacts: `_build/`, `.mooncakes/`, `.moonagent/`,
  `src/frontend/dist/`, or `pkg.generated.mbti`.
- Never rewrite or force-push published history unless explicitly requested.
- Do not commit, amend, or push unless the user asks.
