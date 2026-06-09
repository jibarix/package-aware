# Changelog

## 2.1.0 - 2026-06-09

### Added

- **Behavioral "no installs" directive in the managed `CLAUDE.md` block.** The
  block previously recorded settings *facts* but never told the agent how to
  behave when a tool was missing, so Claude would still propose installs
  (`pip install ...`, `winget install ...`) and ask the user to pick an install
  method. The block now instructs the agent to never propose or run installs,
  never ask which install method to use, and to stop and report missing tooling
  instead of working around the deny rules. (Deny rules block *execution*; this
  closes the *guidance* gap that lets a bad proposal happen in the first place.)

- **Deny coverage for OS-level and other-language package managers.** Added
  `winget`, `choco`, `scoop`, `cargo`, `gem`, `go install`,
  `dotnet add package` / `dotnet tool install`, `uv tool install`, and the
  `conda` / `mamba` `create` / `update` subcommands to `permissions.deny`, in
  both `Bash()` and `PowerShell()` forms. Closes a gap where `winget install ...`
  was not blocked even though the language package managers were.

### Changed

- Refreshed the shareable summary (`PACKAGE_AWARE_PLATFORM_SETTINGS.md` /
  `references/shareable-template.md`) and `references/settings-map.md` to
  document the broader deny coverage and the no-installs guidance. Bumped the
  managed hardening-block date to `2026-06-09`.

## 2.0.0 - 2026-05-26

### Fixed

- **Data loss in `apply_package_aware_hardening.ps1`.** The previous
  implementation did a full load -> in-memory representation -> full
  re-serialize cycle on `~/.claude/settings.json` and
  `%APPDATA%/Code/User/settings.json`, with a string-mangling bug in
  `ConvertTo-NativeValue` that replaced most pre-existing string values with
  `{"Length": N}` placeholders on every run. This destroyed any prior setting
  that was not explicitly part of the hardening posture. Rewritten to do a
  *surgical merge*: the script only writes the specific keys documented in the
  posture, and a verification gate aborts before writing if the serialized
  output would change any other key.

- **Backup collision in `apply_package_aware_hardening.ps1`.** The previous
  `Backup-File` derived the backup name from `[IO.Path]::GetFileName($Source)`
  alone, so both the Claude and VS Code `settings.json` backups landed at
  `<backupDir>/settings.json.bak` and the second silently overwrote the first.
  Backups now use distinct per-source filenames (`claude_settings.json.bak`,
  `claude_CLAUDE.md.bak`, `vscode_settings.json.bak`).

- **`CLAUDE.md` managed block corruption.** The previous managed-block
  here-string used `@"..."@` (double-quoted), so PowerShell interpreted
  markdown backticks as escape sequences -- `` `a `` became BEL, `` `n ``
  became newline, etc., eating the leading letters of `autoUpdatesChannel`,
  `allowedHttpHookUrls`, and `npx supabase`. Switched to `@'...'@`
  (single-quoted, literal).

- **Unverified backups before overwrite.** A `Confirm-BackupIntegrity` helper
  now asserts each backup was actually written (`Test-Path`) and is
  byte-identical to its source (`Get-FileHash` SHA256) immediately after the
  `Copy-Item`, and throws before any `WriteAllText` runs -- so the original is
  never modified without a verified recovery copy on disk. The two `Copy-Item`
  calls also use `-LiteralPath`/`-Destination` so paths containing wildcard
  metacharacters (`[`, `]`, etc.) are handled correctly.

### Changed

- The apply script now prints a per-key change table for both files and emits
  a structured summary object on the pipeline. The old top-level fields
  (`AddedDenyRules`, `ClaudeMdAction`) have moved into nested
  `$result.ClaudeSettings.Changes[]` and `$result.ClaudeMd.Action`.

- Settings files are now written as UTF-8 without BOM. PowerShell 5.1's
  `Set-Content -Encoding UTF8` emits a BOM; the new code uses
  `[System.IO.File]::WriteAllText` with a `UTF8Encoding $false` instance.

- Backups are no longer created when the script would make no logical changes
  to a file (idempotent re-runs do not produce empty backup folders).
