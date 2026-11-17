---
name: markdown
description: Convert text into clean, portable Markdown (GitHub Flavored Markdown) for README files, documentation and reports in code repositories. Use when the result is read on GitHub, GitLab or in an editor. For Obsidian notes, use the obsidian skill instead.
---

# Markdown Formatting

Convert the provided text into structured Markdown that renders the same on GitHub, GitLab and in common editors. Use only GitHub Flavored Markdown (GFM). Do not use syntax that only one tool understands, such as wikilinks or `==highlights==`.

Preserve the original wording and content. Restructure, do not rewrite. The style rules at the end apply only to text you write yourself: headings, link texts, captions.

## Project conventions first

Before writing, look at existing Markdown files in the project. Their conventions for file names, heading style, frontmatter and line length take precedence over the defaults below.

## File names

- Keep standard names as they are: `README.md`, `CONTRIBUTING.md`, `CHANGELOG.md`, `LICENSE`.
- For other files, follow the naming of existing files. Without a pattern, use lowercase words with hyphens: `container-networking.md`.
- Avoid spaces and the characters `/`, `\`, `:`, `*`, `?`, `"`, `<`, `>`, `|`.

## Headings

- Start with exactly one `#` heading as the document title. Use `##` for sections and `###` for subsections. Do not skip levels.
- Leave one blank line before and after every heading.
- Prefer headings over lists with bold prefixes (`- **Topic:** details`) for complex points. Keep lists for simple enumerations.

## Frontmatter

Do not add YAML frontmatter unless the project already uses it, for example for a static site generator.

## Links and images

- Link files in the repository with relative paths: `[Setup](./docs/setup.md)`. Link sections with anchors: `[Installation](#installation)`.
- External links use absolute URLs and descriptive text: `[Podman documentation](https://docs.podman.io)`. Never "click here".
- Images use relative paths and descriptive alt text: `![Pod network diagram](./images/pod-network.png)`.

## Callouts

Use GitHub alerts. Only these five types exist, and they take no title:

```markdown
> [!NOTE]
> Useful information the reader should notice.
```

Types: `[!NOTE]`, `[!TIP]`, `[!IMPORTANT]`, `[!WARNING]`, `[!CAUTION]`.

## Code

- Use inline code for commands, paths, file names, package names, variables and syntax: `git status`, `~/.config/app.toml`.
- Give every code block a language identifier, for example `bash`, `python`, `toml`, `yaml`, `json`.
- Write code comments in English. Comment the why, not the what.

## Lists, tables and other elements

- Use hyphens (`-`) for bulleted lists, never asterisks.
- Use pipe syntax for tables, with a header row and a separator row.
- Use `**bold**` for emphasis and `_italic_` sparingly.
- Footnotes work on GitHub: `[^1]` in the text, `[^1]: Definition.` at the end of the document.
- Do not use inline HTML (`<br>`, `<b>`, `<i>`) when Markdown can express the same.
- Write file paths with forward slashes. Use LF line endings.
- Use ISO 8601 for dates: `YYYY-MM-DD`, or `YYYY-MM-DDTHH:mm:ssZ` with time. Get the current date with `date -u +%Y-%m-%d`, never guess it.

## Style for your own text

Follow the `aistyle` skill. In short:

- Information first, short sentences, strong verbs. Calm and factual.
- No emojis.
- No en dashes or em dashes. Use commas, subordinate clauses or separate sentences.
- No sensationalist adjectives, buzzwords or vague jargon.
- Spell out abbreviations in parentheses on first use: TOCTOU (time-of-check to time-of-use).
