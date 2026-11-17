---
name: obsidian
description: Convert text into a structured Obsidian note with YAML frontmatter, bilingual tags, wikilinks, callouts and highlights. Use when writing or reformatting notes for an Obsidian vault. For README files and documentation in code repositories, use the markdown skill instead.
---

# Obsidian Notes

Convert the provided text into a structured Obsidian note.

Preserve the original wording and content. Restructure, do not rewrite. The style rules at the end apply only to text you write yourself: headings, tags, source entries and the title.

Before writing, run `date -u +%Y-%m-%dT%H:%M:%SZ` and use its output for all timestamps. Never guess the date.

## Document structure

Build every note in this order:

1. YAML frontmatter
2. Title as the only `##` heading at the top
3. `### Sources`, if the content has sources
4. Body sections as `###`, subsections as `####`
5. Footnote definitions
6. `## Tags`

The title and `## Tags` are the only `##` headings. Do not use `#`: Obsidian already shows the filename as the note title.

## Example

````markdown
---
title: Podman Rootless Networking
date created: 2026-11-17T09:30:00Z
date modified: 2026-11-17T09:30:00Z
tags:
  - Podman
  - Rootless_Containers
  - Container_Networking
---
## Podman Rootless Networking

### Sources

- Podman documentation, 2026-10-02, https://docs.podman.io, English

### How pasta works

Rootless containers have no access to host network devices. ==pasta== translates
between the container namespace and the host sockets.[^1]

> [!NOTE]
> Since Podman 5, pasta is the default network mode.

See also [[Podman Pods]].

[^1]: pasta is part of the passt project.

## Tags

#Podman #Rootless_Containers #Container_Networking
````

## YAML frontmatter

- Required keys: `title`, `date created`, `date modified`, `tags`.
- Optional: `aliases`. Use it when the real title contains characters that are not allowed in filenames, or for common alternative names.
- When editing an existing note, keep `date created` and update `date modified`.
- Tags in the frontmatter have no `#` prefix.

## Tags

- Choose 3 to 5 topics that name the primary subject. No generic terms, no secondary details.
- Write each topic as a tag in English and as a tag in the language the user writes in. 3 to 5 topics in two languages give 6 to 10 tags. If the user writes in English, the English tags are enough.
- Replace spaces with underscores: `Music_Production`. Keep a hyphen only where the word itself is hyphenated: `Open-Source_License`, `Real-Time_Systems`.
- List the tags in the frontmatter and again under `## Tags` as space-separated hashtags.

## Filename and location

- The filename, the frontmatter `title` and the `##` title heading are identical.
- Use spaces and normal capitalization, plus `.md`.
- Put the main subject first, so related notes sort together: `Podman Rootless Networking.md`, `Podman Pods.md`.
- Do not start the filename with a dot. Do not use `[`, `]`, `#`, `^` or `|`, they break Obsidian links. Avoid `/`, `\`, `:`, `*`, `?`, `"`, `<` and `>` for compatibility with other systems. If the title needs one of them, keep the full title in `title` and `aliases` and simplify the filename.
- Save the note in the current directory unless the user names another location.

## Sources

If the content is based on external material, add the sources section directly after the title. Name it in the language of the note, for example `### Source` or `### Sources`. List what is available: author, date (ISO 8601), title, URL, language.

## Obsidian syntax

### Links

- Other notes: `[[Note Name]]`, with display text `[[Note Name|Display Text]]`, to a heading `[[Note Name#Heading]]`.
- External links: `[Podman documentation](https://docs.podman.io)`, always with descriptive text.

### Images

- Local images: `![[diagram.png]]`, with width `![[diagram.png|300]]`.
- External images: `![Alt text](https://example.com/image.png)`, with size `![Alt text|300x200](https://example.com/image.png)`.
- Write descriptive alt text for external images.

### Callouts

Use a blockquote with a type: `> [!NOTE]`, `> [!TIP]`, `> [!IMPORTANT]`, `> [!WARNING]`, `> [!CAUTION]`. A title may follow the type: `> [!WARNING] Data loss`.

### Highlights

Use `==highlighted text==` for key concepts or terms that need visual emphasis. Use it sparingly and never for code.

### Footnotes

Reference with `[^1]` in the text. Place the definitions directly before `## Tags`: `[^1]: Definition text.`

## Code

- Use inline code for commands, paths, file names, package names, variables and syntax: `git status`, `~/.config/app.toml`.
- Give every code block a language identifier, for example `bash`, `python`, `toml`, `yaml`, `json`.
- Write code comments in English. Comment the why, not the what.

## Lists, tables and other elements

- Use hyphens (`-`) for bulleted lists, never asterisks.
- Prefer headings over lists with bold prefixes (`- **Topic:** details`) for complex points. Keep lists for simple enumerations.
- Use pipe syntax for tables, with a header row and a separator row.
- Use `**bold**` for emphasis and `_italic_` sparingly.
- Leave one blank line before and after every heading. The title heading follows the frontmatter directly.
- Do not use inline HTML (`<br>`, `<b>`, `<i>`) when Markdown can express the same.
- Write file paths with forward slashes. Use LF line endings.
- Use ISO 8601 for dates: `YYYY-MM-DD`, or `YYYY-MM-DDTHH:mm:ssZ` with time.

## Style for your own text

Follow the `aistyle` skill. In short:

- Information first, short sentences, strong verbs. Calm and factual.
- No emojis.
- No en dashes or em dashes. Use commas, subordinate clauses or separate sentences.
- No sensationalist adjectives, buzzwords or vague jargon.
- Spell out abbreviations in parentheses on first use: TOCTOU (time-of-check to time-of-use).
