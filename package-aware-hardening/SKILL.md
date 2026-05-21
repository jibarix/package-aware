---
name: package-aware-hardening
description: Apply, verify, and document package-aware hardening for Claude Code and VS Code. Use when Claude needs to inspect current Claude Code or VS Code settings, back up user-level config, disable risky auto-update or plugin paths, enforce package-manager guardrails, export a sanitized shareable settings document, or maintain the Claude Code plus VS Code hardening workflow over time.
license: MIT
compatibility: Requires Windows with PowerShell 5.1+ and Claude Code. The bundled scripts edit Windows user-level paths (~/.claude and %APPDATA%/Code/User/settings.json) and are not portable to macOS/Linux or to Claude.ai/API surfaces without adaptation.
metadata:
  author: jibarix
  version: 1.0.0
---

# Package-Aware Hardening

## Overview

Use this skill to harden the Claude Code plus VS Code combination with a
package-aware posture, then produce a sanitized document that can be shared
without leaking usernames, home paths, or machine-specific details.

Prefer the bundled PowerShell scripts over manual editing. They are designed to
back up settings, apply idempotent changes, and keep the shareable document free
of local identifiers.

## Workflow

1. Inspect the current state before changing anything.
2. Read `references/settings-map.md` when you need the rationale, affected keys,
   or rollback scope.
3. Use `scripts/apply_package_aware_hardening.ps1` to update Claude Code and VS
   Code settings.
4. Use `scripts/export_shareable_settings.ps1` to generate or refresh the public
   settings summary in the parent `package_aware` folder.
5. Verify the exported file does not contain usernames, home directories, or
   absolute machine-specific paths.

## Quick Start

Inspect only:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\apply_package_aware_hardening.ps1 -DryRun
```

Apply hardening:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\apply_package_aware_hardening.ps1
```

Refresh the sanitized shareable document:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\export_shareable_settings.ps1
```

## What the apply script changes

The apply script hardens these user-level files:

- `~/.claude/settings.json`
- `~/.claude/CLAUDE.md`
- `%APPDATA%/Code/User/settings.json`

It applies these defaults:

- Disable Claude Code auto-updates with `DISABLE_AUTOUPDATER=1`
- Set Claude Code `autoUpdatesChannel` to `stable`
- Block remote HTTP hooks with `allowedHttpHookUrls: []`
- Disable bypass-permissions mode
- Disable the Supabase plugin
- Add deny rules for risky package-manager and extension-install commands
- Set VS Code updates and extension updates to manual
- Insert or refresh a managed hardening block in `~/.claude/CLAUDE.md`
- Create timestamped backups before writing changes

## Shareable document rules

The exported public document must stay sanitized.

Never include:

- usernames
- home-directory paths
- absolute repo paths
- machine-specific backup locations
- local standalone CLI install paths

Use placeholders instead:

- `~/.claude/settings.json`
- `~/.claude/CLAUDE.md`
- `%APPDATA%/Code/User/settings.json`
- `standalone Supabase CLI installation`

If you need the exact policy language or the rationale for a specific setting,
read `references/settings-map.md`.

## Notes

- Prefer the apply script over hand-editing JSON unless you are debugging the
  script itself.
- Treat the shareable document as public-facing. Keep rollback notes private.
- If a user wants only the public document refreshed, skip the apply script and
  run only `scripts/export_shareable_settings.ps1`.

## Examples

### Example 1: Inspect before changing anything

User says: "Show me what hardening would change on this machine, but don't touch
anything."

Actions:

1. Run `apply_package_aware_hardening.ps1 -DryRun`.
2. Report the returned object — especially `AddedDenyRules` and `ClaudeMdAction`.

Result: The user sees the planned changes (and which `CLAUDE.md` branch will run)
with no files written.

### Example 2: Apply the posture on a fresh machine

User says: "Set up my package-aware defaults on this new laptop."

Actions:

1. Run `apply_package_aware_hardening.ps1` (no `-DryRun`).
2. Confirm `ClaudeMdAction: inserted-managed-block` and note the backup directory.

Result: Claude Code and VS Code settings are hardened; the managed block is added
to `CLAUDE.md`; originals are backed up under
`~/.claude/backups/package-aware-hardening/<timestamp>/`.

### Example 3: Refresh only the public document

User says: "I edited the template — regenerate the shareable summary."

Actions:

1. Run `export_shareable_settings.ps1`.
2. Confirm `Sanitized: true` in the output.

Result: `PACKAGE_AWARE_PLATFORM_SETTINGS.md` is rebuilt from the template, and the
script aborts if any machine-specific identifier slipped in.

## Troubleshooting

### Error: `ConvertFrom-Json` fails when loading settings

Cause: `settings.json` contains JSONC features (comments or trailing commas).
Windows PowerShell 5.1's `ConvertFrom-Json` does not accept them.

Solution: Remove comments/trailing commas from the file, or run the script under
PowerShell 7+ which tolerates them. Re-run with `-DryRun` to confirm it parses.

### VS Code settings are not updated

Cause: VS Code is installed to a non-default location, so
`%APPDATA%/Code/User/settings.json` does not exist (e.g. Insiders, portable, or
a Linux/macOS host).

Solution: Pass the real path via `-VSCodeSettingsPath`. Confirm the resolved path
in the `-DryRun` output first.

### `CLAUDE.md` was not changed

Cause: This is expected when an unmarked `## Global hardening overrides` section
already exists — the script reports `ClaudeMdAction: skipped-existing-unmarked-section`
and leaves hand-written content untouched.

Solution: If you want the script to manage that section, wrap it in
`<!-- PACKAGE-AWARE-HARDENING:START -->` / `<!-- PACKAGE-AWARE-HARDENING:END -->`
markers; the next run will refresh it in place.

### Export aborts with a sanitization error

Cause: The template (`references/shareable-template.md`) contains a username, a
home path, or `C:\Users\...`.

Solution: Replace the offending value with a placeholder (`~/.claude/...`,
`%APPDATA%/...`) and re-run the export.
