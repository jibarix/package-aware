# Settings Map

## Claude Code settings

File:

- `~/.claude/settings.json`

Managed keys:

- `env.DISABLE_AUTOUPDATER = "1"`
- `autoUpdatesChannel = "stable"`
- `allowedHttpHookUrls = []`
- `disableBypassPermissionsMode = "disable"`
- `enabledPlugins["supabase@claude-plugins-official"] = false`
- `permissions.deny += risky package-manager and extension-install patterns`

Important deny patterns added by the script:

- `npx`
- `pipx run`
- `uv run`
- `code --install-extension`

## Claude Code global instructions

File:

- `~/.claude/CLAUDE.md`

Managed block:

- The script maintains one marked hardening block.
- Re-running the script updates that block instead of duplicating it.

Purpose:

- Record the package-aware defaults in the file Claude actually loads.
- Keep the Supabase CLI preference visible.

## VS Code user settings

File:

- `%APPDATA%/Code/User/settings.json`

Managed keys:

- `update.mode = "manual"`
- `extensions.autoUpdate = false`
- `extensions.autoCheckUpdates = false`

## Backups

The apply script writes backups under a timestamped folder rooted at:

- `~/.claude/backups/package-aware-hardening/`

Each run can back up:

- `settings.json`
- `CLAUDE.md`
- VS Code `settings.json`

## Shareable export rules

The public export must not contain:

- usernames
- `C:\Users\...`
- repo-specific absolute paths
- private rollback locations
- exact local Supabase CLI install paths

The public export should contain:

- generic placeholders
- the effective policy
- copyable baseline snippets
- generic file locations such as `~/.claude/...` and `%APPDATA%/...`

## When to make exceptions

Typical exceptions:

- a project needs an HTTP hook
- a plugin is worth enabling temporarily
- a dependency refresh is required and can be audited
- a VS Code extension update needs to be applied deliberately

If making an exception:

- change the minimum necessary setting
- record why the exception exists
- prefer time-bounded exceptions
