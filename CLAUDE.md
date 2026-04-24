# Agent Instructions

**Verbosity:** concise
**Chattiness:** low

## Notes for AI Agents

- This instance runs in a container.
- **Language Policy:** **Always** write code and code comments in English. Communicate with the user in their preferred language, but **never** write code or comments in the user's language. If the user's language distinguishes between formal and informal pronouns, always use the informal form.
- **Nushell: `filter` vs. `where`**: Since Nushell 0.105.0, `filter` is deprecated. Prefer `where` for filtering lists and tables to avoid deprecation warnings.

## Language Usage

Role model: News language.

- Information first.
- Short sentences, strong verbs.
- Be transparent, accountable, reliable and authentic.
- State facts in the indicative mood and uncertainties in the subjunctive mood.
  - *Correct (Fact):* "The file `config.toml` was modified."
  - *Correct (Uncertainty):* "This could potentially cause a race condition if..."
  - *Incorrect:* "I think I have successfully modified the file." (Do not guess about facts).
- **Avoid all-caps emphasis:** Do not use capitalization to emphasize rules, conditions, or importance (e.g., instead of "ALWAYS", use "**always**"). Use Markdown formatting for emphasis instead.
- **No dashes for clauses:** Do not use em-dashes (—) or en-dashes (–) to connect clauses or thoughts. Use commas, colons, or parentheses instead, or write shorter sentences.

## Script Execution
If you need to execute the main script, include the mod path.
Otherwise the main script can't find the Nushell modules (e.g. `use cfg`).

```
nu --include-path /absolute/path/to/mod /absolute/path/to/bin/agentonaut.nu
```

## Admitting Mistakes

Admit mistakes immediately and without sugarcoating.
Do not call a mistake "confusion".

# Design Principles

## Modules: Decoupled, Pure Functions

Modules receive data as parameters, not from global config.

```nushell
# Correct: Data passed as parameter
$data | myapp operation arg1 arg2

# Wrong: Module accesses global config
export def operation [arg1: string, arg2: string] {
    $env.myapp.data | where ...  # Coupled to global state
}
```

Modules are testable, reusable, and independent. No tight coupling to the environment.

### Orchestration: Main Script

The main script handles:

- Loading configuration
- Fetching data from the configuration
- Passing data to modules
- Side effects, logging, error handling

Modules are pure functions, and orchestration is explicit and clear.

### Environment Variable Overrides

Configuration values can be overridden by environment variables using `script "env override"`.
The variable name follows the pattern: `APPNAME_SECTION_KEY` (all uppercase, dots replaced by underscores).

**Example:**

```nushell
# In bin/agentonaut.nu
use script

# This will look for AGENTONAUT_CHAT_BASE_PATH
script "env override" "agentonaut" "chat.base_path"
```

To use it from the shell:
```bash
AGENTONAUT_CHAT_BASE_PATH="/tmp/chat" agentonaut chat
```

### Module Discovery

When running the main script or tests manually, you must include the `mod` directory via `nu --include-path`. Otherwise, the internal modules will not be found. The generated wrapper script handles this automatically using `exec nu --include-path <project_root>/mod ...`.

## Code Comments

### Code Headings

Not like this:

```
# ============================================================================
# Stage 1: Builder
# ============================================================================
```

But like this:

```
#
# Stage 1: Builder
#
```

Or like this:

```
# Stage 2: Configuration
```

### Multi-line Nushell Commands

For multi-line commands (piping, long argument lists), maximize readability:

**Correct:**

```nushell
let result = (
    $data
    | filter { |item| $item.status == "active" }
    | map { |item| { name: $item.name, count: ($item.values | length) } }
    | sort-by count
)
```

**Also correct (for many parameters):**

```nushell
let result = (
    my_function
        $param1
        $param2
        $param3
        --option-one $value1
        --option-two $value2
        --option-three $value3
)
```

**Not like this:**

```nushell
let result = ($data | filter { |item| $item.status == "active" } | map { |item| { name: $item.name, count: ($item.values | length) } } | sort-by count)
```

Rules:

- Opening parenthesis `(` on the same line as `let`/`if`/etc., closing `)` alone on a new line.
- Each pipe `|` on a new line.
- Each parameter/flag on a new line for long argument lists.
- Indentation of 4 spaces for a readable structure.
- Complex expressions in curly braces `{}` can remain inline, but wrap them to multiple lines if they exceed 80 characters.

### Multi-Line Output

For multi-line output in Nushell, use a list of strings with `print --raw`:

**Correct:**

```nushell
[
    "Line 1"
    $"Line 2 with interpolation: ($variable)"
    "  Indented line 3"
] | print --raw
```

**Not like this:**

```nushell
print "Line 1"
print $"Line 2 with interpolation: ($variable)"
print "  Indented line 3"
```

Rules:

- List of strings instead of multiple `print` calls.
- `print --raw` prevents additional formatting.
- Easy to add/remove lines.
- String interpolation with `$"..."` works naturally.
- Indentation directly in strings (e.g., `"  Text"`) instead of helper functions.

### Multi-line RUN Instructions in Containerfiles

For multi-line RUN instructions in Containerfiles (Dockerfile, Containerfile), place operators at the beginning of the line:

**Correct:**

```dockerfile
RUN command1 arg1 arg2 \
    && command2 arg1 \
    && command3 arg1 arg2 arg3
```

**Not like this:**

```dockerfile
RUN command1 arg1 arg2 && \
    command2 arg1 && \
    command3 arg1 arg2 arg3
```

Rules:

- Backslash `\` at the end of each line (except the last).
- Operator `&&` at the beginning of the next line (after indentation).
- Indentation of 4 spaces for continuation lines.
- Increases readability and makes the structure more visible.

## Git Commits

Commit messages must be in English, concise, no emojis, no colons.

Rules:

- Single-line preferred.
- Multi-line only if information does not fit on one line, but keep it brief.
- English.
- No emojis.
- No colon in the message.
- No mention of Gemini, Claude, or Tools.
- Do not execute `git add` or `git commit` commands.

**Correct:**

```
Replace cd with npm --prefix in host module for stateless functions
Add version caching to prevent unnecessary rebuilds
Fix infinite recursion in build function
```

**Not like this:**

```
Refactor: replace cd with npm --prefix  # Colon
Replace cd with npm 🎉                  # Emoji
Add feature with AI assistance          # Mention of tool
```

## Understand Before Improving

New features, functions, or abstractions are welcome and desired. Innovation arises from a deep understanding of grievances and existing systems, not from speculation.

### Blast Radius & Autonomy

- **Blast Radius:** If a proposed refactoring touches more than 3 files or changes the core architecture, you **must** present a brief plan and wait for user approval before modifying files.
- **Dependencies:** Do not introduce new third-party tools, CLI packages, or libraries without explicit user permission. Solve problems using the existing stack. You may *suggest* a new dependency only if the added value is exceptionally high.

### Procedure for Improvement Suggestions

Before suggesting new features:

1. **Understand the existing system:**
   - How is the project structured?
   - What patterns and conventions are established?
   - How does the project already solve similar problems?

2. **Use existing abstractions:**
   - Extend existing systems instead of inventing new ones.
   - Maintain established patterns instead of introducing alternatives.
   - Respect code structure, do not add your own layers.

3. **Recognize the added value of improvement suggestions:**
   - Does it improve maintainability or clarity?
   - Does it reduce complexity or expand it meaningfully?
   - Does it solve a real problem or is it speculation?
   - Does it fit consistently into the existing system?

4. **Minimalist design with system understanding:**
   - Build only what is requested **now** (YAGNI).
   - But build it so that it fits seamlessly into the existing system.
   - Creativity lies in elegant integration, not in new layers.

### Principles

**Wrong (without system understanding):**

- Introducing new layers of abstraction even though existing systems suffice.
- Inventing separate solutions instead of extending existing ones.
- Prophylactically adding features that are not requested.

**Right (System-integrated):**

- Extending existing systems with added value.
- Using consistent patterns in new code.
- Asking before making suggestions, not adding speculatively.

## Naming Conventions

### Variables for Paths and Directories

Consistent naming for clarity:

- **`dir`** in the name: Relative directory
  - Example: `output_dir = "output"`
  - Usage: `let full_path = ($base_path | path join $output_dir)`

- **`path`** in the name: Absolute path (file or directory)
  - Example: `config_path = "/home/user/.config/app/config.toml"`
  - Usage: Directly usable without further expansion

- **`file`** in the name: Relative file
  - Example: `config_file = "config.toml"`
  - Usage: `let full_path = ($dir | path join $config_file)`

- **`file_path`** in the name: Absolute file path
  - Example: `database_file_path = "~/.local/share/app/db.sqlite"`
  - Usage: With `path expand` before use

**Correct:**

```nushell
let config_dir = "conf"                                    # Relative
let config_file = "config.toml"                            # Relative
let config_file_path = "~/.config/app/config.toml"        # Absolute
let database_file_path = "~/.local/share/app/data.db"     # Absolute

let full_path = ($base | path join $config_dir $config_file)
let expanded = ($config_file_path | path expand)
```

**Not like this:**

```nushell
let config = "conf"                    # Unclear: File or directory?
let db = "~/.local/share/app/data.db" # Unclear: Relative or absolute?
```

## Tool Usage

### Nushell MCP vs. Bash tool

Use the **Nushell MCP** (`mcp__mcp-nushell__evaluate`) when the task needs only Nushell built-ins and no workspace writes.
Use the **Bash tool** (with `nu -c` if needed) when external tools (`rg`, `git`, `gh`, `sqlite3`, etc.) or workspace file writes are required.

The Nushell MCP container has a minimal package set (`ca-certificates`, `libssl3`, `jq`, `curl`, `tar`, `gzip`, Nushell). Tools like `rg`, `git`, `gh`, `sqlite3`, `mu`, and `rsync` are not available there. `/workspace` is read-only inside the container; `/tmp` is writable for intermediate results.

### Web Fetching

Use `web_fetch` (native tool) instead of `fetch_url` (provided by `docs-mcp-server`).
Reason: `docs-mcp-server`'s `fetch_url` produces excessive output consuming too many tokens.

## Nushell String Interpolation

Within double-quoted strings `$"..."`, expressions enclosed in parentheses `()` are evaluated. To use literal parentheses `(` `)` without them being interpreted as code execution, they must be escaped with a backslash: `\(` and `\)`.

**CRITICAL: Never use `$("...")`.** This is **not** valid interpolation. Nushell interprets the `(` immediately after `$` as a subshell execution, leading to "Command not found" or "expected valid variable name" errors.

**Correct:**

```nushell
let my_var = "world"
let message = $"Hello (my_var)!" # Evaluates my_var
let literal = $"This is literal \(text\)." # Prints "This is literal (text)."
```

**Incorrect:**

```nushell
let message = $"Hello (world)!" # Attempts to execute a command named 'world'
let message = $("Hello world") # ERROR: Incorrect syntax, treats string as command
```

## Nushell Strings & Bare Words

To ensure maximum safety and consistency, especially when dealing with multiple AI agents and external CLI tools, we use a hybrid approach for strings.

### 1. Always Use Quotes for Values and Arguments
For all command arguments, file paths, and variable assignments, use explicit double quotes. This prevents collision with Nushell commands (e.g., `stop` being seen as a command instead of an argument) and ensures reliability for AI-generated code.

**Correct:**
```nushell
cfg init "agentonaut"
let mode = "container"
git download "upstream"
```

**Avoid (Bare Words for Arguments):**
```nushell
cfg init agentonaut
let mode = container
```

### 2. Use Bare Words for Record Keys
For readability and alignment with standard Nushell idioms, use bare words for keys in records and tables unless they contain special characters (like dots or spaces).

**Correct:**
```nushell
let record = { id: "gemini", type: "container" }
```

**Avoid (Quoted Keys):**
```nushell
let record = { "id": "gemini", "type": "container" }
```

