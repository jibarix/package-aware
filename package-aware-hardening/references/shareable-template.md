# Package-Aware Platform Settings

Date: `2026-05-21`

This document is the shareable summary of the package-aware settings in use
across the main platforms on this machine. It is meant to answer two questions
quickly:

1. What is the effective security posture right now?
2. What should I copy if I want the same posture elsewhere?

This file lives in the `package_aware` folder on purpose even though several
settings are user-level. The goal here is shareability and team visibility.
Machine-specific rollback notes should be kept separately and should not be
included in the shared copy.

## Principles

- Prefer exact pins, reviewed versions, and committed lockfiles.
- Avoid ad-hoc fetch-and-run package execution.
- Avoid silent editor and extension updates.
- Prefer standalone CLIs over plugin or marketplace integrations when the CLI
  is simpler and easier to audit.
- Keep repo-level dependency policy aligned with tool-level deny rules.

## Effective posture by layer

### 1. Claude Code user settings

Current user-level file:

- `~/.claude/settings.json`

Current posture:

- Claude Code auto-updating is disabled with `DISABLE_AUTOUPDATER=1`.
- Fallback update channel is `stable`, not `latest`.
- Remote HTTP hooks are blocked with `allowedHttpHookUrls: []`.
- Permission bypass mode is disabled with
  `disableBypassPermissionsMode: "disable"`.
- The Supabase plugin is disabled.
- Ad-hoc package execution is denied across npm, pnpm, yarn, bun, pip, pipx,
  uv, poetry, conda, and mamba.
- VS Code extension install via shell is denied with
  `code --install-extension`.

Shareable baseline:

```json
{
  "env": {
    "DISABLE_AUTOUPDATER": "1"
  },
  "autoUpdatesChannel": "stable",
  "allowedHttpHookUrls": [],
  "disableBypassPermissionsMode": "disable",
  "enabledPlugins": {
    "supabase@claude-plugins-official": false
  },
  "permissions": {
    "deny": [
      "Bash(npx *)",
      "PowerShell(npx *)",
      "Bash(pipx run *)",
      "PowerShell(pipx run *)",
      "Bash(uv run *)",
      "PowerShell(uv run *)",
      "Bash(code --install-extension *)",
      "PowerShell(code --install-extension *)"
    ]
  }
}
```

Notes:

- The real local file may include a broader deny list than the short snippet
  above. Use your local file as the canonical source if you want the full
  policy.
- This setup is intentionally restrictive for marketplace-driven workflows.

### 2. Claude Code global instructions

Current user-level file:

- `~/.claude/CLAUDE.md`

Current posture:

- Documents the active supply-chain stance for npm and PyPI.
- Calls out persistence indicators to check during incidents.
- Tells Claude not to work around package-manager deny rules.
- Documents that Supabase work should prefer the standalone CLI.

Shareable baseline:

```md
## Package-aware defaults

- Do not propose ad-hoc package execution (`npx`, `pipx run`, `pnpm dlx`,
  `bunx`, `yarn dlx`) unless the user explicitly accepts the risk.
- Prefer exact version pins and committed lockfiles.
- Do not assume `latest` is safe during an active supply-chain incident.
- Prefer standalone audited CLIs over marketplace or plugin paths when practical.
- For Supabase work, prefer the standalone CLI over a plugin or `npx supabase`.
```

### 3. VS Code user settings

Current user-level file:

- `%APPDATA%/Code/User/settings.json`

Current posture:

- VS Code app updates are manual.
- Extension auto-update is disabled.
- Extension auto-check is disabled.

Shareable baseline:

```json
{
  "update.mode": "manual",
  "extensions.autoUpdate": false,
  "extensions.autoCheckUpdates": false
}
```

Why this matters:

- The editor and its extension marketplace are part of the supply chain.
- Disabling background extension updates creates a review window before code
  lands on the machine.

### 4. Package-Aware Repository Contents

This folder is for the Claude Code plus VS Code hardening workflow itself.

Key files:

- `PACKAGE_AWARE_PLATFORM_SETTINGS.md`
- `package-aware-hardening/SKILL.md`
- `package-aware-hardening/scripts/apply_package_aware_hardening.ps1`
- `package-aware-hardening/scripts/export_shareable_settings.ps1`
- `package-aware-hardening/references/settings-map.md`

Current posture:

- The root markdown file is the sanitized shareable summary.
- The skill folder contains the reusable workflow and automation scripts.
- The apply script is for private machine-level changes.
- The export script is for regenerating the public shareable document.

Working rule:

- Keep machine-specific rollback notes private.
- Keep the exported root markdown sanitized and safe to share.

### 5. Package ecosystems

#### npm, pnpm, yarn, bun

Current posture:

- No ad-hoc execution by default.
- No blind install or exec flows through Claude Code.
- No automatic extension-style installs from the shell through Claude.

Working rule:

- Prefer exact versions, committed lockfiles, and deliberate updates.

#### PyPI

Current posture:

- No casual `pip install`, `pipx run`, or `uv run` flows through Claude Code.
- Use dry-run resolution plus audit-first lockfile generation when a fresh
  resolve is truly needed.

Working rule:

- Resolve first, inspect versions, then lock with hashes.

#### Conda and Mamba

Current posture:

- Install commands are also denied through Claude Code by default.

Working rule:

- Treat conda channels as their own supply chain; do not assume they inherit
  PyPI risk patterns or PyPI mitigations.

### 6. Sharing and Version Control

Current posture:

- The shareable root markdown is intended for publication or reuse.
- The skill folder is intended for repeatable local execution and maintenance.
- Any future git repo for this folder should ignore backups, temp files, and
  machine-only artifacts.

Working rule:

- Treat the shareable markdown as public-facing content.
- Keep private rollback paths, usernames, and absolute local paths out of the
  exported document.

### 7. Supabase

Current posture:

- The Claude Supabase plugin is disabled.
- `npx supabase` remains blocked.
- The preferred path is a standalone Supabase CLI installation.

Shareable baseline:

```text
Use a standalone Supabase CLI binary.
Do not default to `npx supabase`.
Prefer the installed binary on PATH, or a known local install path, in agent
sessions when PATH is uncertain.
```

Why this exception exists:

- It preserves a fast CLI-driven workflow without reopening the plugin
  marketplace path.

## What I would share with another setup

If I wanted to reproduce this posture on another machine, I would copy:

1. The Claude Code deny philosophy and updater settings
2. The VS Code manual update settings
3. The repo policy around exact pins and hash-locked installs
4. The standalone Supabase CLI preference

Do not copy machine-specific absolute paths blindly. Replace them with the
appropriate local path on the target machine.

## Local machine specifics

The following values are intentionally local and should be adapted elsewhere:

- `~/.claude/settings.json`
- `~/.claude/CLAUDE.md`
- `%APPDATA%/Code/User/settings.json`
- The local install path of the standalone Supabase CLI

## Exceptions and rollback

Machine-level rollback notes should be kept in a separate private document.
They should not be included in the shareable version.

Typical reasons to make a temporary exception:

- A project genuinely needs an HTTP hook
- A plugin provides value that outweighs its marketplace risk
- A dependency refresh is required and can be audited safely
- A VS Code extension update needs to be applied deliberately

When making an exception:

- Change the minimum necessary setting
- Record why the exception was made
- Prefer a time-bounded or task-bounded exception over a permanent one
