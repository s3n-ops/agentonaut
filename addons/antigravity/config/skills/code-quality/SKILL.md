---
name: code-quality
description: Review code for idiom, correctness, consistency, testability, justifiability, and code volume. Language-agnostic. Flags real problems only. No style nitpicks without a concrete reason.
---

# Code Quality Review

Review the current diff or the files named by the user. Produce findings only. Do not fix unless explicitly asked.

## Preparation

Determine the scope first:

- If the user names specific files, read those files directly
- For diff review: `git diff --staged` or `git diff HEAD`
- For branch review: `git diff $(git merge-base HEAD main)`

## What to check

### Idiom

Use the conventions of the language and ecosystem at hand. What counts as idiomatic is determined by, in order: patterns already established in the codebase, the project's own guidelines (such as `AGENTS.md`, `CLAUDE.md` or `CONTRIBUTING.md`), and the established best practices of the language.

Flag deviations only when a better idiomatic alternative concretely exists and the deviation has a real readability or maintainability consequence.

### Correctness

- Logic errors: wrong conditions, off-by-one, incorrect operator precedence
- Race conditions and TOCTOU (time-of-check to time-of-use) windows
- Error paths that silently swallow failures
- Incorrect assumptions about external state (process lifetime, filesystem, network)
- Tests that pass vacuously (always-true assertions, wrong polarity)
- File operations without proper error handling

### Consistency

- Same problem, same solution: flag when two patterns solve the same thing differently without reason
- Naming: mixed conventions in the same scope
- Module and tool choices: mixing levels of abstraction in the same file without justification
- Duplicated logic: check whether the codebase already solves the problem before writing new code
- Module design: flag violations of "decoupled, pure functions that receive data as parameters"

### Testability

- Logic entangled with I/O: time, randomness, or external processes that make unit tests impossible
- Hard-wired dependencies that could be injected (fixed paths instead of configurable ones)
- Functions that do too many things to test in isolation
- Missing or vacuous assertions in tests

### Justifiability

Every deviation from the standard (a lower-level primitive where a higher-level abstraction exists, a workaround, an unusual structure) must have a defensible reason. If none is apparent from context or a comment, flag it.

This is the most important check: a change that cannot be explained concisely is a change that should not exist.

### Code volume

Less code is the goal, but not at any price. Priority, in this order:

1. Behavior stays identical. No lost features, no changed edge cases.
2. The code stays readable and correct.
3. Fewer lines.

Line count only breaks ties. The underlying measure is how much a reader has to hold in mind to understand the code.

Remove:

- Dead code: variables assigned but never read, imports never used, output captured but never checked
- Redundant steps: the same value computed or the same condition checked more than once
- Checks for internal states that cannot occur. Keep validation at boundaries (user input, files, network, external tools)
- Comments that restate the code
- Configuration options that only ever take one value
- Logic duplicated in places that must change together

Keep or add, even when it costs lines:

- Explicit error handling
- Named intermediate values that explain intent
- Tests for behavior that has broken before or is easy to break
- Handling of real edge cases

Abstraction: code can fail with too little abstraction and with too much. Every abstraction must be earned. It earns its place when naming it reveals more than it hides and the call site becomes clearer as a result. Flag a function extracted for a single call site, a wrapper that adds a name but no information, and an interface with one implementation. These add indirection, not clarity. The test: can a reader understand the call site without jumping to the definition?

Duplication: unify copies that must change together. Keep copies that only look alike and may diverge. Recurrence alone does not justify an abstraction. If the implementation needs a workaround to fit a shared abstraction, the duplication is the better choice.

Every finding states its trade. A removal names the behavior it preserves. An addition names what it buys.

The final test: after the change, does a reader need to hold fewer things in mind?

## Reversal check

Check the branch history for reversals:

- List commits with `git log --oneline`
- Scan for lines or blocks that were changed in one commit and changed back in a later commit
- Trace individual files with `git diff <earlier>..<later> -- <file>`

Flag any reversal as a finding. State which commits are involved and what the line looked like at each point. Classify it as an undo (a change was reverted entirely) or an oscillation (a line changed direction more than once). The fix is to squash the reversal out of the history before merging, or to decide once and commit to it.

Do not flag intentional reverts where the commit message clearly says "revert X".

## Static analysis and linting

Before manual review, run available tooling. Do not install anything. Use only what is present.

### Discover the tool chain

Look for project config files (`Justfile`, `Makefile`, `.pre-commit-config.yaml`, `*.toml`) and targets named `lint`, `vet`, `check`, or `analyze`.

### Probe for tools

Use `which <tool>` for linters and static analyzers. If a tool is absent, skip it silently.

### Run what exists

Invoke each available tool on the affected files only. Run tools requiring full-project context on the entire repository.

### Handle output

Report tool findings under a "Static analysis" section, grouped by tool. Suppress findings the project has explicitly silenced (inline ignore directives, per-file exclusions). If a tool fails due to environment or configuration issues, note the failure briefly and continue.

## How to report

For each finding, state the file and line, what is wrong and why in one or two sentences, and what the correct alternative is concretely.

Group findings by category. Omit categories with no findings. If there are no findings, say so in one sentence.

## What not to flag

- Style preferences without a concrete correctness or maintainability consequence
- Naming that follows the project's existing convention even if you would choose differently
- Missing comments on self-explanatory code (comments explain why, not what)
- Anything that is wrong only in theory but harmless in the actual context

## Intellectual honesty

If the user pushes back on a finding, re-evaluate it on the merits. If their argument is correct, say so and withdraw the finding. If their argument is wrong or unsupported, hold the position and explain why. Do not withdraw findings under social pressure alone.
