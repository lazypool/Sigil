# Sigil Markup Language Specification v0.1

> A minimal markup language for long-form, reading-oriented emails.  
> Layout belongs to the document. Facts belong to the profile. Rendering belongs to themes. One accent color only.

---

## 0. Design Principles

1. **Minimal by default.** No multi-level headings, no rich text, no hand-written tables, no code blocks.
2. **One theme color.** The entire email shares a single accent color; everything else is neutral gray.
3. **Three text styles only.** `normal`, `strong` (same size, bold), `big` (bold, larger). No italics, underline, strikethrough, or multiple font sizes.
4. **Fixed reading column.** Body content is capped at 640px wide, vertically stacked, compatible with all devices.
5. **Declarations vs. content.** Header directives declare global settings; body content carries only content and placeholders.
6. **Rasterize on send.** Preview may use SVG; on send, formulas, charts, and icons are converted to PNG and embedded via CID for email-client compatibility.
7. **Statically checkable.** Every syntax rule can be validated by the editor, with locatable and fixable diagnostics.

---

## 1. Document Structure

A document consists of two parts:

```text
[Header directives]
(blank line)
[Body]
```

- **Header directive block**: consecutive `@key value` lines at the very beginning of the document. Only the global directives below are allowed.
- **Body**: starts at the first non-`@` line and continues to the end of the document.
- At least one blank line must separate the header block from the body.
- Header directives must not appear in the body. An `@...` line in the body is treated as plain text and produces a warning.

---

## 2. Header Directives

Only the following directives are allowed in the header. Each may appear at most once.

| Directive | Value | Purpose |
|---|---|---|
| `@theme` | Color value, e.g. `#2563EB` | Global accent color |
| `@footer` | Footer theme id | Selects footer theme; appended automatically to the end |
| `@split` | Divider style id | Selects divider style for all `---` |
| `@letter` | Letter theme id | Selects the outer letter frame |
| `@palette` | Chart palette id | Selects the palette used by every chart |

### 2.1 Syntax

```text
@theme #2563EB
@footer legal
@split wave
@letter card
@palette ocean
```

### 2.2 Rules

- Duplicate directive of the same kind → error; keep the first.
- Unknown directive → error; list the four legal directives.
- `@theme` must be a valid hex color or named theme color; otherwise error.
- Once the header block ends, later `@...` lines are no longer parsed as directives.
- The header **does not** contain `@signature`. Signatures are placed in the body via `<sig:...>`.

---

## 3. Body Syntax

The body is split into paragraphs by blank lines. Paragraphs may contain inline elements; paragraphs may be separated by block elements.

### 3.1 Paragraphs and Line Joining

- Consecutive non-blank lines form one paragraph.
- Blank lines separate paragraphs.
- **Internal line breaks do not produce `<br>`.** Lines are joined into one logical line.
- Line joining does **not** blindly insert a space. The joining rule depends on the character types on both sides of the break.

Before joining, trim leading and trailing whitespace on each line to avoid double spaces.

| Left line ends with | Right line starts with | Join behavior |
|---|---|---|
| Han character | Han character | Concatenate directly, **no space** |
| Han character | Full-width punctuation | Concatenate directly |
| Full-width punctuation | Han character | Concatenate directly |
| Full-width punctuation | Full-width punctuation | Concatenate directly |
| Han character | Latin letter / digit | Insert one half-width space |
| Latin letter / digit | Han character | Insert one half-width space |
| Latin letter / digit | Latin letter / digit | Insert one half-width space |
| Full-width punctuation | Latin letter / digit | Concatenate directly |
| Latin letter / digit | Full-width punctuation | Concatenate directly |

In short: **a space is inserted only at boundaries involving Latin letters or digits; pure CJK boundaries are concatenated directly.**

Line joining uses the **same rule engine and the same exception dictionary** as the CJK–Latin spacing linter (§6.1), so joining and linting never contradict each other.

Examples:

```text
使用
Python 开发
```

Joins to `使用 Python 开发` (Han ↔ Latin: one space).

```text
2024
年发布
```

Joins to `2024年发布` (exception dictionary matches `X年`: no space).

```text
你好
世界
```

Joins to `你好世界` (Han ↔ Han: no space).

```text
这是对的，
对吧
```

Joins to `这是对的，对吧` (full-width punctuation ↔ Han: no space).

Implementation notes:

- Joining happens during parsing and produces a single `Text` node whose `range` covers the original multi-line span.
- Subsequent spacing and punctuation checks operate on the joined plain text and do not re-report the line boundary.
- Fixes still map back to source offsets. Accepting an “insert space” fix at a line break is equivalent to replacing the newline with a space.

Edge cases:

- Trailing spaces on a line are trimmed before the join decision; no double spaces.
- If a line ends with `*` or `**`, the delimiter does not participate in the decision; the actual character before the delimiter is used. If the delimiter spans lines, treat it as unclosed and warn.
- If a line ends with `<link:...>`, the last character of the link’s display text participates; the URL does not.
- If a line starts with `<icon:...>`, treat it as a width-1 character on the “Latin/digit” side when determining Han boundaries.
- List items **do not** support line continuation. If the line after a list item is not a new list item, the list ends and that line is parsed as a normal paragraph.

### 3.2 Emphasis

| Syntax | Style | Notes |
|---|---|---|
| `*text*` | strong | Same size, bold |
| `**text**` | big | Bold, larger size |

Parsing rules:

1. **Longest match first**: try `**` before `*`.
2. **Delimiter validity**: the opening delimiter must be followed by a non-whitespace character; the closing delimiter must be preceded by a non-whitespace character; the character before the opening delimiter must not be a letter or digit.
3. **No nesting**: `**big *strong* big**` → error.
4. **Unpaired delimiter**: treat as literal text and emit a warning (“unclosed `*`”).
5. **Escaping**: `\*` outputs a literal `*`.
6. Italics, underline, and strikethrough **do not exist**. Corresponding syntax is treated as plain text.

Example:

```text
This is *strong text*, and this is **big bold text**.
```

### 3.3 Divider

```text
---
```

- A line consisting exactly of `---` (leading/trailing whitespace allowed) renders as a divider.
- The divider style is selected by `@split` in the header.
- Consecutive `---` lines merge into one divider.
- Blank lines around `---` are recommended but not required.

### 3.4 Lists

Only **one level** of lists is supported. Nesting is not allowed.

#### Unordered list

```text
- First item
- Second item
```

#### Ordered list

```text
1. First item
2. Second item
```

Rules:

1. A line starting with `^\d+\.\s+` is an ordered item; a line starting with `^-\s+` is an unordered item.
2. Within one list block, ordered and unordered items **must not be mixed** → error.
3. Indented list items → error: “Lists support only one level.”
4. Empty list items → error.
5. Ordered numbering renders starting from the first item’s number and increments by 1. Non-consecutive numbers produce a warning (“numbers will be renumbered”).
6. List items may contain `*`, `**`, `<link:...>`, and `<icon:...>`.
7. Block insertions such as `<sig:...>` and `<image:...>` inside list items are rendered as literal text. `$$`, `:::`, `---`, and nested lists are not parsed inside list items.

#### List width limits

Width is measured as the **display width of the rendered plain text**, excluding markup syntax.

| Character type | Width |
|---|---|
| Han character, full-width punctuation, full-width letter | 1 |
| Latin letter, digit, half-width punctuation, space | 0.5 |
| `<icon:...>` | 1 |

| Rule | Threshold | Severity |
|---|---|---|
| Minimum item width | ≥ 4 | Error |
| Maximum item width | ≤ 34 | Error |
| Number of items | ≥ 2 | Warning |
| Longest item − shortest item | ≤ 20 | Warning |

Rationale: the 34 upper bound forces every item onto a single line, eliminating long/short lists; the lower bound of 4 eliminates single-character items; the range limit of 20 prevents visual unevenness.

### 3.5 Insertion Syntax `< >`

All insertions use `<>` and **must carry an explicit prefix**. An unprefixed `<>` is always an error.

| Prefix | Type | Position | Example |
|---|---|---|---|
| `sig:` | Signature | Block, must occupy its own line | `<sig:academic>` |
| `image:` | Image | Block, must occupy its own line | `<image:product.png>` |
| `table:` | Table | Block, must occupy its own line | `<table:report.csv>` |
| `chart:` | Chart | Block, must occupy its own line | `<chart:growth.chart>` |
| `icon:` | Built-in icon | Inline | `<icon:mail>` |
| `link:` | Hyperlink | Inline | `<link:https://a.com>` |

#### 3.5.1 Signature `<sig:...>`

```text
<sig:academic>
```

- `sig:` is followed by a signature theme id.
- **Must occupy its own line**; inline occurrence → error.
- **At most once per document**; a second occurrence → error, only the first renders.
- Theme data comes from the user profile. The document contains no personal fields.
- Unknown theme id → warning; render with the default signature theme.
- Empty id or parameters (containing `|`) → error.
- The old `@signature` header directive and `{{signature}}` placeholder are deprecated → error, with a hint to use `<sig:...>`.

#### 3.5.2 Image `<image:...>`

```text
<image:product.png>
<image:https://cdn.example.com/a.png>
```

- **Must occupy its own line**; inline occurrence → error.
- Renders as a block image: centered, `max-width:100%`, `height:auto`.
- Local assets and remote URLs are both allowed. On send, both are downloaded and embedded via CID.
- Local image assets belong to the email's own library. Switching emails switches
  the sidebar image list, and deleting an email deletes its images.
- The old `![]()` syntax → error, with a hint to use `<image:...>`.
- v0.1 does not support alt text.

#### 3.5.3 Table `<table:...>`

```text
<table:report.csv>
```

- **Must occupy its own line**; inline occurrence → error.
- The target is a CSV asset in the workspace table library; the value is the
  asset file name.
- Imported CSV, TSV, XLSX, XLS, ODS, and JSON files are converted to CSV on
  import. Only the first worksheet of a workbook is imported.
- Each email owns its own image and table library. Both are flat lists with
  no folders or categories.

#### 3.5.4 Chart `<chart:...>`

```text
<chart:growth.chart>
```

- **Must occupy its own line**; inline occurrence → error.
- The target is a chart asset in the email's chart library; the value is the
  asset name.
- Chart assets are plain text. Import accepts either a full `:::chart kind`
  block or a `kind: bar` first line followed by chart data.
- New charts can also be created empty in the Charts tab and edited in place.
- Charts use the document `@palette` preset, not the `@theme` color.
- The Images and Tables tabs group their contents by the owning email, so every
  email's library can be browsed and edited from the same tab.
- Library tabs provide an inline preview page for images and tables; they do
  not insert assets.
- In the sidebar, clicking an image or table switches back to the owning
  email's editor and previews the asset in the right preview pane, while its
  `+` button inserts it into the active email. Clicking the email tab or
  sidebar row clears the asset preview and restores the email preview.
- The workspace uses inline views and inline confirmations instead of modal
  dialogs.
- The table preview is an inline editor: cells are editable, rows and columns
  can be added, column widths are derived from cell content, and adding a
  column stops at the hard limit of 5 columns. Its background and controls use
  the application theme.
  Switching emails switches the whole sidebar resource directory; deleting an
  email deletes its tables.
- Tables have a hard limit of 5 columns. Wide tables (more than 5 columns) are
  split into numbered parts; parts after the first repeat the first column as
  a key. Tables with more than 200 data rows are also split by rows, repeating
  the header in each part. The import reports how many tables were created.
- Each cell is limited to 60 characters. Longer cells are truncated on import
  and when older tables are normalized, and the import reports how many cells
  were truncated.
- The CSV is parsed with RFC 4180 quoting and rendered as an email-safe HTML
  table with inline styles and no scripts.
- Tables are centered in the reading column. Header cells use a light tint of
  the theme color, and body rows alternate between white and `#F7F8FA`.
- A missing asset renders a visible `[table:name]` placeholder.

#### 3.5.4 Icon `<icon:...>`

```text
<icon:mail>
<icon:phone>
```

- Inline element.
- Only built-in icon whitelist entries are allowed; unknown icon → error.
- Preview uses SVG; on send, converted to a theme-colored PNG.

#### 3.5.5 Link `<link:...>`

```text
<link:https://example.com>
<link:https://example.com|View documentation>
<link:mailto:hello@example.com|Contact me>
```

- Inline element.
- URL must start with `http://`, `https://`, or `mailto:`; other protocols → error.
- Bare domains are not allowed: `<link:example.com>` → error, hint to include the protocol.
- Empty URL → error.
- Display text is separated by `|`; defaults to the URL itself.
- Display text may contain `*` and `**`; nested `<>` is not allowed.
- Links use the theme color only, **no underline**.
- URLs must not contain spaces or `|`.

#### 3.5.6 Security

- Source `<...>` constructs produce only controlled AST nodes; HTML output is always escaped.
- Source `<...>` is never passed through as raw HTML.
- Link `href` values are restricted to the protocol whitelist.

### 3.6 Block Formulas

```text
$$
E = mc^2
$$
```

- **Block formulas only.** `$$` must occupy its own line, with a blank line before and after.
- **Inline formulas are forbidden.** A `$...$` inside a paragraph → error: “Inline formulas are not supported; use a standalone block.”
- Preview uses MathJax/KaTeX to produce SVG, centered.
- On send, rasterized to 2x/3x PNG, embedded via CID, `display:block; margin:0 auto`.

### 3.7 Charts

```text
:::chart bar
title: Monthly growth
A: 10
B: 20
:::
```

- Block element, occupies its own paragraph.
- Inner content is simple line-based data, not a code block.
- Supported types: `bar`, `stacked`, `line`, `area`, `pie`, `donut`,
  `scatter`, `radar`, and `heatmap`.
- Chart colors come from the document-wide `@palette` preset, not from
  `@theme`. Available palettes: `default`, `ocean`, `sunset`, `forest`,
  `berry`, `earth`, `mono`.
- `title: ...` sets the caption and `labels: a, b, c` sets categories.
- Multi-series charts use `series: name = value, value, ...`; a lone
  `label: value` line is shorthand for a single series.
- Scatter points use `x,y; x,y` after `series:`.
- Preview outputs SVG; on send, rasterized to PNG and embedded.
- Unknown chart types render a placeholder instead of failing the document.
- Charts can be stored in the per-email chart library and inserted with
  `<chart:name>`, like `<image:name>` and `<table:name>`.
- A chart library file is plain text: either the same `:::chart kind` block
  used inline, or a first line `kind: bar` followed by chart data.

### 3.8 Plain Text Notes

~~~text
```
Hello!
This block is plain text, not code, and keeps its line breaks.
```
~~~

- A line consisting exactly of three backtick characters starts a plain text block; another such line closes it.
- The block is **not** a code block, and its contents are not parsed as markup or insertions.
- The content renders as escaped plain text in neutral gray, preserving line breaks.
- It is typically used for translations: put an English translation after a Chinese email, or a Chinese translation after an English email.
- The block may appear anywhere in the body; an unclosed block → error.

---

## 4. Profile and Themes

### 4.1 User Profile

Stored globally, maintained once, reused everywhere. The document stores **no personal data**.

Suggested fields:

```json
{
  "name": "Zhang San",
  "alias": "San",
  "email": "zhangsan@example.com",
  "phone": "+86 138 0000 0000",
  "title": "Product Manager",
  "company": "Example Inc.",
  "education": "Example University · Computer Science",
  "website": "https://example.com",
  "avatar": "asset://me.png",
  "socials": [{ "label": "GitHub", "url": "https://github.com/..." }]
}
```

Field types: `text`, `multiline`, `email`, `phone`, `url`, `image`, `list`.

### 4.2 Theme Packs

Four theme categories, each with its own id namespace:

| Category | Selected by | Reads |
|---|---|---|
| Signature `signature` | Body `<sig:xxx>` | Profile |
| Footer `footer` | Header `@footer` | Profile |
| Divider `split` | Header `@split` | Theme color only |
| Letter `letter` | Header `@letter` | Theme color + content HTML |

Each signature/footer theme declares its required fields:

```ts
type FieldSpec = {
  key: string
  label?: string
  type: "text" | "email" | "phone" | "url" | "image" | "list"
  required?: boolean
  fallback?: string
}
```

### 4.3 Missing Fields

- **Required field missing**: editor shows a yellow hint; preview shows a placeholder such as `[Phone]`; a confirmation appears before sending.
- **Optional field missing**: the theme hides that part automatically.
- The app provides a “profile completeness” indicator and one-click navigation to fill in missing fields.

### 4.4 Built-in Themes (v0.1)

- Signature: `classic`, `minimal`, `academic`, `compact`
- Footer: `legal`, `unsubscribe`, `blank`
- Divider: `line`, `dotted`, `wave`, `space`, `ornament`
- Letter: `minimal`, `card`

All themes use only the theme color plus neutral grays.

---

## 5. Layout and Rendering

### 5.1 Structure

```text
[Letter container]
  ├─ Body content (in order)
  │    └─ <sig:xxx> → renders signature at that position
  └─ Footer (appended automatically by @footer)
```

- Signature position is determined by `<sig:...>`.
- Footer position is fixed at the end and cannot be controlled.
- No `<sig:...>` → no signature. No `@footer` → no footer.

### 5.2 Visual Specification

- Outer 100% width table; inner content column `max-width:640px; width:100%; margin:0 auto`.
- Body font size 16px, line-height 1.7, paragraph spacing 14px.
- `strong`: `font-weight:600`.
- `big`: 18–22px, bold.
- Divider: theme color at low opacity; style selected by `@split`.
- Image: `display:block; margin:0 auto; max-width:100%; height:auto; border:0`.
- Link: theme color, no underline.
- All CSS inline. No flex/grid, no JS, no external fonts.

### 5.3 Send Compatibility

- MIME: `multipart/alternative` (plain text + HTML); use `multipart/related` when inline images are present.
- Formulas, charts, icons, and uploaded images are all embedded via CID.
- Remote images are downloaded and embedded to avoid blocking.
- Optional export to `.html` / `.eml` for debugging.

---

## 6. Writing Checks (Linter)

The editor runs checks only on **plain-text AST nodes**. Markup syntax, URLs, formulas, charts, and profile data are all excluded.

### 6.1 CJK–Latin Spacing (Pangu)

**Rule**: There must be exactly one half-width space between a Han character and a Latin letter/digit.

| Left | Right | Behavior |
|---|---|---|
| Han | Latin/digit | Insert space |
| Latin/digit | Han | Insert space |
| Han | Full-width punctuation | No change |
| Full-width punctuation | Latin/digit | No change |
| Han | Han | No change |

- Multiple spaces, full-width spaces, and tabs between Han and Latin/digit are merged/converted to one half-width space.
- Exception dictionary (enabled by default): ordinals (`第X`), time (`X年`, `X月`, `X日`), common measure words (`X个`, `X次`, `X人`). Matches are downgraded to info and not forced.
- Severity: warning; safe auto-fix.

### 6.2 Punctuation Mixing

**Context determination**: split by sentence boundaries (`。！？!?` and line breaks). If a sentence contains at least one Han character, it is a Chinese-context sentence.

| In Chinese context | Suggested | Auto-fix |
|---|---|---|
| `,` | `，` | Suggested (exclude thousands separators, English enumerations) |
| `.` | `。` | Hint only (exclude decimals, versions, domains, abbreviations, ellipses) |
| `!` `?` `;` | `！` `？` `；` | Safe auto-fix |
| `:` | `：` | Suggested (exclude time, URLs, ratios) |
| `()` | `（）` | Suggested; must be paired |
| `"` `'` | `“”` `‘’` | Suggested; must be paired |

- Chinese punctuation inside an English-context sentence → warning; auto-fix to half-width.
- Unpaired paired symbols → error; hint only, no auto-close.
- `...` → `……`, `--` → `——`: info; non-blocking.

### 6.3 Line Joining Consistency

Line joining (§3.1) uses the same rule engine and exception dictionary as §6.1. Pure CJK boundaries are concatenated directly without inserting a space.

### 6.4 Severity and Sending

| Severity | Sending impact |
|---|---|
| error | Blocks sending; must be fixed |
| warning | Confirmation prompt; may continue |
| info | Non-blocking |

### 6.5 Fix Levels

- **Safe auto-fix**: space insertion/merging, `!` `?` `;` to full-width, Chinese punctuation to half-width in English context.
- **Suggested fix**: `,` `:` to full-width, paired parentheses, paired quotes.
- **Hint only**: `.` to `。`, unpaired symbols, exception dictionary matches.

Fixes apply directly to source offsets. After a fix, re-parse to avoid offset drift. Batch fixes are applied from back to front.

---

## 7. Full Example

```text
@theme #2563EB
@footer legal
@split wave
@letter card

Hello,

This is *strong text*, and this is **big bold text**.

<sig:academic>

---

- First item
- Second item

<image:product.png>

$$
E = mc^2
$$

:::chart bar
title: Monthly growth
A: 10
B: 20
:::

See <link:https://example.com/docs|documentation>, or email <link:mailto:hello@example.com|contact me>.

<icon:mail>
```

Rendered result:

- Letter `card` wraps the entire document; theme color `#2563EB`.
- `<sig:academic>` renders the signature at that position using profile data.
- `---` renders as a wave divider.
- Lists are validated for width and range.
- Image is centered, responsive, and CID-embedded.
- Formula and chart are rasterized and embedded.
- Footer `legal` is appended automatically at the end.

---

## 8. Error and Warning Reference

| Input | Severity | Handling |
|---|---|---|
| `***text***` | Error | Triple emphasis not supported |
| `**big *strong* big**` | Error | Nested emphasis not supported |
| Unclosed `*` | Warning | Treat as literal |
| Indented list | Error | Nesting not supported |
| Mixed ordered/unordered | Error | Same list block must not mix |
| List item width <4 or >34 | Error | Blocks sending |
| List with only 1 item | Warning | Suggest a normal paragraph |
| List range >20 | Warning | Suggest consistent detail level |
| `<sig:...>` twice | Error | Only first renders |
| `<sig:...>` inline | Error | Must occupy its own line |
| `<sig:unknown>` | Warning | Default theme renders |
| `@signature` / `{{signature}}` | Error | Deprecated; use `<sig:...>` |
| `<image:...>` inline | Error | Must occupy its own line |
| `![]()` | Error | Use `<image:...>` |
| `<icon:unknown>` | Error | Unknown icon |
| `<link:example.com>` | Error | Include protocol |
| `<link:javascript:...>` | Error | Unsupported protocol |
| Unprefixed `<...>` | Error | List the four legal prefixes |
| Inline `$...$` | Error | Inline formulas not supported |
| `$$` not as standalone paragraph | Error | Formula must be standalone |
| Duplicate header directive | Error | Keep first |
| Unknown `@palette` preset | Error | Use a built-in palette id |
| `<chart:...>` inline | Error | Must occupy its own line |
| `@` directive in body | Warning | Treat as plain text |
| Missing space between Han and Latin | Warning | Safe auto-fix |
| Half-width comma in Chinese context | Warning | Suggested fix |
| Unpaired parentheses | Error | Hint only |
| Missing required profile field | Warning | Placeholder; confirm before send |

---

## 9. Compatibility Notes

- Email clients are not browsers. Body HTML must not depend on SVG, JS, or external CSS.
- Formulas, charts, and icons may use SVG **in preview**; on **send**, they are rasterized to PNG and embedded via CID.
- All layout uses tables and inline CSS to ensure consistency across Gmail, Outlook, Apple Mail, and other major clients.
- The reading column is fixed at 640px and becomes 100% width on mobile.

---

## 10. Versioning

- **v0.1**: the syntax defined in this document.
- Future extensions must preserve four invariants: header declares only global settings; body carries only content; `<>` always carries an explicit prefix; one theme color only.

---

End of specification.
