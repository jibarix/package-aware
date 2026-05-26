# Changelog

## Unreleased

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
