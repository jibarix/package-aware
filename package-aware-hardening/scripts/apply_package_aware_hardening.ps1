[CmdletBinding()]
param(
    [string]$ClaudeSettingsPath = (Join-Path $HOME '.claude\settings.json'),
    [string]$ClaudeMdPath = (Join-Path $HOME '.claude\CLAUDE.md'),
    [string]$VSCodeSettingsPath = (Join-Path $env:APPDATA 'Code\User\settings.json'),
    [string]$BackupRoot = (Join-Path $HOME '.claude\backups\package-aware-hardening'),
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'

# -----------------------------------------------------------------------------
# Posture (the only keys this script is allowed to write).
# Surgical merge: every change must be listed here. Anything not listed is
# preserved verbatim by the verification gate below; if a change leaks beyond
# this list, the script aborts before writing.
# -----------------------------------------------------------------------------

$claudeScalarSettings = @(
    @{ Path = @('autoUpdatesChannel');             Value = 'stable' },
    @{ Path = @('allowedHttpHookUrls');            Value = @() },
    @{ Path = @('disableBypassPermissionsMode');   Value = 'disable' },
    @{ Path = @('env','DISABLE_AUTOUPDATER');      Value = '1' },
    @{ Path = @('enabledPlugins','supabase@claude-plugins-official'); Value = $false }
)

$claudeDenyAppend = @(
    'Bash(pip install *)','Bash(pip3 install *)','Bash(pip download *)','Bash(pip wheel *)',
    'Bash(pipx install *)','Bash(pipx run *)',
    'Bash(python -m pip install *)','Bash(python3 -m pip install *)','Bash(py -m pip install *)',
    'Bash(uv pip install *)','Bash(uv add *)','Bash(uv sync *)','Bash(uv run *)',
    'Bash(poetry add *)','Bash(poetry install *)',
    'Bash(conda install *)','Bash(mamba install *)',
    'Bash(npm install)','Bash(npm install *)','Bash(npm i *)','Bash(npm i)',
    'Bash(npm add *)','Bash(npm ci *)','Bash(npm ci)','Bash(npm exec *)',
    'Bash(pnpm install *)','Bash(pnpm install)','Bash(pnpm add *)','Bash(pnpm i *)','Bash(pnpm i)',
    'Bash(pnpm exec *)','Bash(pnpm exec)','Bash(pnpm dlx *)',
    'Bash(yarn install)','Bash(yarn install *)','Bash(yarn add *)','Bash(yarn dlx *)',
    'Bash(bun install)','Bash(bun install *)','Bash(bun add *)','Bash(bun x)','Bash(bun x *)','Bash(bunx *)',
    'Bash(npx *)','Bash(npx)',
    'Bash(code --install-extension *)',
    'PowerShell(pip install *)','PowerShell(pip3 install *)','PowerShell(pip download *)','PowerShell(pip wheel *)',
    'PowerShell(pipx install *)','PowerShell(pipx run *)',
    'PowerShell(python -m pip install *)','PowerShell(python3 -m pip install *)','PowerShell(py -m pip install *)',
    'PowerShell(uv pip install *)','PowerShell(uv add *)','PowerShell(uv sync *)','PowerShell(uv run *)',
    'PowerShell(poetry add *)','PowerShell(poetry install *)',
    'PowerShell(conda install *)','PowerShell(mamba install *)',
    'PowerShell(npm install)','PowerShell(npm install *)','PowerShell(npm i *)','PowerShell(npm i)',
    'PowerShell(npm add *)','PowerShell(npm ci *)','PowerShell(npm ci)','PowerShell(npm exec *)','PowerShell(npm exec)',
    'PowerShell(pnpm install *)','PowerShell(pnpm install)','PowerShell(pnpm add *)','PowerShell(pnpm i *)','PowerShell(pnpm i)',
    'PowerShell(pnpm exec *)','PowerShell(pnpm exec)','PowerShell(pnpm dlx *)',
    'PowerShell(yarn install)','PowerShell(yarn install *)','PowerShell(yarn add *)','PowerShell(yarn dlx *)',
    'PowerShell(bun install)','PowerShell(bun install *)','PowerShell(bun add *)','PowerShell(bun x)','PowerShell(bun x *)','PowerShell(bunx *)',
    'PowerShell(npx *)','PowerShell(npx)',
    'PowerShell(code --install-extension *)',
    # OS-level package managers (Windows + cross-platform) and other-language
    # managers. Added 2026-06-09 after a `winget install` was found to slip past
    # the posture, which only covered language package managers (pip/npm/etc.).
    'Bash(winget install *)','Bash(winget upgrade *)',
    'Bash(choco install *)','Bash(choco upgrade *)',
    'Bash(scoop install *)','Bash(scoop update *)',
    'Bash(cargo install *)','Bash(gem install *)','Bash(go install *)',
    'Bash(dotnet add package *)','Bash(dotnet tool install *)',
    'Bash(uv tool install *)',
    'Bash(conda create *)','Bash(conda update *)','Bash(mamba create *)','Bash(mamba update *)',
    'PowerShell(winget install *)','PowerShell(winget upgrade *)',
    'PowerShell(choco install *)','PowerShell(choco upgrade *)',
    'PowerShell(scoop install *)','PowerShell(scoop update *)',
    'PowerShell(cargo install *)','PowerShell(gem install *)','PowerShell(go install *)',
    'PowerShell(dotnet add package *)','PowerShell(dotnet tool install *)',
    'PowerShell(uv tool install *)',
    'PowerShell(conda create *)','PowerShell(conda update *)','PowerShell(mamba create *)','PowerShell(mamba update *)'
)

$vscodeScalarSettings = @(
    @{ Path = @('update.mode');                  Value = 'manual' },
    @{ Path = @('extensions.autoUpdate');        Value = $false },
    @{ Path = @('extensions.autoCheckUpdates');  Value = $false }
)

# Single-quoted here-string: PowerShell does NOT process backticks inside.
# Do not "fix" the @' ... '@ delimiters to @" ... "@ unless you also escape
# every markdown backtick (`autoUpdatesChannel`, `npx supabase`, etc.) -- see
# the bug history that made this script destructive in the first place.
$managedBlock = @'
<!-- PACKAGE-AWARE-HARDENING:START -->
## Global hardening overrides (2026-06-09)

- **No installs.** Never propose or run package/tool installs: pip, conda, npm, pnpm, yarn, bun, npx, pipx, uv, poetry, winget, choco, scoop, cargo, gem, go, dotnet, and the like. Do not ask the user which install method to use. Use only tooling already present on the machine; if a task cannot proceed with what is installed, stop and report exactly what is missing and let the user decide how to provision it. These commands are also denied in `settings.json`; do not attempt to work around the deny rules.
- Claude Code auto-updating is disabled via `DISABLE_AUTOUPDATER=1`.
- `autoUpdatesChannel` is pinned to `stable`.
- `disableBypassPermissionsMode` is set to `disable` globally.
- Remote HTTP hooks are blocked by default via `allowedHttpHookUrls: []`.
- The Supabase plugin is disabled globally.
- Supabase work should prefer a standalone CLI installation rather than the plugin or `npx supabase`.
- Do not suggest `code --install-extension` without explicit user approval.
- VS Code user settings are expected to keep app and extension updates manual.
<!-- PACKAGE-AWARE-HARDENING:END -->
'@

# -----------------------------------------------------------------------------
# Helpers
# -----------------------------------------------------------------------------

function Ensure-ParentDirectory {
    param([string]$Path)
    $parent = Split-Path -Parent $Path
    if ($parent -and -not (Test-Path $parent)) {
        New-Item -ItemType Directory -Force -Path $parent | Out-Null
    }
}

function Confirm-BackupIntegrity {
    # Asserts the backup was actually written and is byte-identical to the
    # source. Throws (writing nothing else) if either check fails -- callers
    # rely on this so the subsequent write of new content cannot proceed with a
    # missing or corrupted recovery copy.
    param(
        [string]$SourcePath,
        [string]$BackupPath
    )
    if (-not (Test-Path -LiteralPath $BackupPath)) {
        throw "ABORT: backup was not created at '$BackupPath'. Original file '$SourcePath' has not been modified."
    }
    $sourceHash = (Get-FileHash -LiteralPath $SourcePath -Algorithm SHA256).Hash
    $backupHash = (Get-FileHash -LiteralPath $BackupPath -Algorithm SHA256).Hash
    if ($sourceHash -ne $backupHash) {
        throw ("ABORT: backup at '$BackupPath' does not match source '$SourcePath' " +
               "(source SHA256=$sourceHash, backup SHA256=$backupHash). " +
               "Original file has not been modified.")
    }
}

function Read-JsonOrEmptyObject {
    # Returns a PSCustomObject. Never mangles strings; if the file is empty
    # or missing, returns an empty object.
    param([string]$Path)
    if (-not (Test-Path $Path)) { return [pscustomobject]@{} }
    $raw = Get-Content -Raw -Path $Path
    if ([string]::IsNullOrWhiteSpace($raw)) { return [pscustomobject]@{} }
    $parsed = $raw | ConvertFrom-Json
    if ($null -eq $parsed) { return [pscustomobject]@{} }
    if ($parsed -is [System.Collections.IEnumerable] -and -not ($parsed -is [string])) {
        throw "Expected a JSON object at $Path, got an array."
    }
    return $parsed
}

function Get-PropertyAt {
    # Navigates a literal-key path on a PSCustomObject. Returns @{Found=$bool; Value=...}.
    # Keys are matched as-is (including "supabase@claude-plugins-official" or "update.mode").
    param([psobject]$Object, [string[]]$Path)
    $current = $Object
    foreach ($key in $Path) {
        if ($null -eq $current) { return @{ Found = $false; Value = $null } }
        $prop = $current.PSObject.Properties[$key]
        if ($null -eq $prop) { return @{ Found = $false; Value = $null } }
        $current = $prop.Value
    }
    return @{ Found = $true; Value = $current }
}

function Set-PropertyAt {
    # Sets a literal-key path on a PSCustomObject, creating intermediate
    # PSCustomObjects as needed. -Force allows overwriting an existing property.
    param([psobject]$Object, [string[]]$Path, $Value)
    $current = $Object
    for ($i = 0; $i -lt ($Path.Count - 1); $i++) {
        $key = $Path[$i]
        $prop = $current.PSObject.Properties[$key]
        if ($null -eq $prop -or -not ($prop.Value -is [psobject]) -or ($prop.Value -is [System.Collections.IEnumerable] -and -not ($prop.Value -is [string]))) {
            $child = [pscustomobject]@{}
            $current | Add-Member -NotePropertyName $key -NotePropertyValue $child -Force
            $current = $child
        } else {
            $current = $prop.Value
        }
    }
    $leaf = $Path[-1]
    $current | Add-Member -NotePropertyName $leaf -NotePropertyValue $Value -Force
}

function Compare-LeafValue {
    # Deep structural equality for JSON-shaped values (strings, numbers, bools,
    # arrays of same, nested PSCustomObjects). Used by the verification gate.
    param($A, $B)
    if ($null -eq $A -and $null -eq $B) { return $true }
    if ($null -eq $A -or $null -eq $B) { return $false }
    if ($A -is [psobject] -and $A.PSObject.TypeNames[0] -eq 'System.Management.Automation.PSCustomObject' -and `
        $B -is [psobject] -and $B.PSObject.TypeNames[0] -eq 'System.Management.Automation.PSCustomObject') {
        $aNames = @($A.PSObject.Properties.Name | Sort-Object)
        $bNames = @($B.PSObject.Properties.Name | Sort-Object)
        if ($aNames.Count -ne $bNames.Count) { return $false }
        for ($i = 0; $i -lt $aNames.Count; $i++) {
            if ($aNames[$i] -ne $bNames[$i]) { return $false }
            if (-not (Compare-LeafValue -A $A.($aNames[$i]) -B $B.($aNames[$i]))) { return $false }
        }
        return $true
    }
    $aIsArr = ($A -is [System.Collections.IEnumerable]) -and -not ($A -is [string])
    $bIsArr = ($B -is [System.Collections.IEnumerable]) -and -not ($B -is [string])
    if ($aIsArr -ne $bIsArr) { return $false }
    if ($aIsArr) {
        $aArr = @($A); $bArr = @($B)
        if ($aArr.Count -ne $bArr.Count) { return $false }
        for ($i = 0; $i -lt $aArr.Count; $i++) {
            if (-not (Compare-LeafValue -A $aArr[$i] -B $bArr[$i])) { return $false }
        }
        return $true
    }
    return ($A.Equals($B))
}

function Path-Key {
    param([string[]]$Path)
    # ASCII Unit Separator (0x1F) as a portable join character.
    # Cannot collide with real JSON keys. Works on PS 5.1 and 7+.
    $sep = [string][char]0x1F
    return ($Path -join $sep)
}

function Test-Verify-Preserved {
    # The safety gate. Given the original parsed PSCustomObject, the proposed
    # new PSCustomObject, and the set of property paths the posture is allowed
    # to touch, verify every original leaf is preserved unless its path is in
    # the allowed-changes set. Returns a list of unexpected diff entries
    # (empty list = safe to write).
    param(
        [psobject]$Original,
        [psobject]$New,
        [string[][]]$AllowedChangedPaths,
        [string[]]$AppendOnlyArrayPathKey  # e.g. 'permissions/deny' as a Path-Key
    )
    $allowed = @{}
    foreach ($p in $AllowedChangedPaths) { $allowed[(Path-Key $p)] = $true }

    $unexpected = @()

    $visit = {
        param($node, [string[]]$path)
        if ($null -eq $node) { return }
        if ($node -is [psobject] -and $node.PSObject.TypeNames[0] -eq 'System.Management.Automation.PSCustomObject') {
            foreach ($prop in $node.PSObject.Properties) {
                & $visit $prop.Value (@($path) + $prop.Name)
            }
            return
        }
        if ($node -is [System.Collections.IEnumerable] -and -not ($node -is [string])) {
            # Treat the whole array as one leaf. Append-only arrays are
            # verified separately below.
            $pathKey = Path-Key $path
            if ($allowed.ContainsKey($pathKey)) { return }
            if ($pathKey -eq $AppendOnlyArrayPathKey) {
                $origArr = @($node)
                $newProbe = Get-PropertyAt -Object $New -Path $path
                if (-not $newProbe.Found) {
                    $script:unexpected += [pscustomobject]@{ Path = ($path -join '.'); Kind = 'array-missing'; Original = $origArr; New = $null }
                    return
                }
                $newArr = @($newProbe.Value)
                if ($newArr.Count -lt $origArr.Count) {
                    $script:unexpected += [pscustomobject]@{ Path = ($path -join '.'); Kind = 'array-shrunk'; Original = $origArr; New = $newArr }
                    return
                }
                for ($i = 0; $i -lt $origArr.Count; $i++) {
                    if (-not (Compare-LeafValue -A $origArr[$i] -B $newArr[$i])) {
                        $script:unexpected += [pscustomobject]@{ Path = "$($path -join '.')[$i]"; Kind = 'array-prefix-changed'; Original = $origArr[$i]; New = $newArr[$i] }
                        return
                    }
                }
                return
            }
            $newProbe = Get-PropertyAt -Object $New -Path $path
            if (-not $newProbe.Found -or -not (Compare-LeafValue -A $node -B $newProbe.Value)) {
                $script:unexpected += [pscustomobject]@{ Path = ($path -join '.'); Kind = 'array-changed'; Original = $node; New = $newProbe.Value }
            }
            return
        }
        # Scalar leaf
        $pathKey = Path-Key $path
        if ($allowed.ContainsKey($pathKey)) { return }
        $newProbe = Get-PropertyAt -Object $New -Path $path
        if (-not $newProbe.Found) {
            $script:unexpected += [pscustomobject]@{ Path = ($path -join '.'); Kind = 'missing'; Original = $node; New = $null }
            return
        }
        if (-not (Compare-LeafValue -A $node -B $newProbe.Value)) {
            $script:unexpected += [pscustomobject]@{ Path = ($path -join '.'); Kind = 'changed'; Original = $node; New = $newProbe.Value }
        }
    }

    $script:unexpected = @()
    & $visit $Original @()
    return ,$script:unexpected
}

function Apply-PostureToJsonFile {
    # Reads $Path, applies the posture (scalar sets + optional deny append),
    # verifies non-targeted keys are preserved, then either prints the planned
    # change set (DryRun) or writes the file with a backup.
    param(
        [string]$Path,
        [hashtable[]]$ScalarSettings,
        [string[]]$DenyAppend,
        [string[]]$DenyPath,
        [string]$BackupTarget,
        [switch]$DryRun
    )
    $original = Read-JsonOrEmptyObject -Path $Path
    # Clone via JSON round-trip -- safe because both sides are PSCustomObject.
    $proposed = ($original | ConvertTo-Json -Depth 100 -Compress) | ConvertFrom-Json
    if ($null -eq $proposed) { $proposed = [pscustomobject]@{} }

    $allowedPaths = @()
    $changeLog = @()

    foreach ($setting in $ScalarSettings) {
        $existing = Get-PropertyAt -Object $proposed -Path $setting.Path
        $needsWrite = -not $existing.Found -or -not (Compare-LeafValue -A $existing.Value -B $setting.Value)
        if ($needsWrite) {
            Set-PropertyAt -Object $proposed -Path $setting.Path -Value $setting.Value
            $changeLog += [pscustomobject]@{
                Path     = ($setting.Path -join '.')
                Action   = if ($existing.Found) { 'update' } else { 'add' }
                Previous = if ($existing.Found) { $existing.Value } else { '<unset>' }
                New      = $setting.Value
            }
        }
        $allowedPaths += ,$setting.Path
    }

    $appendOnlyKey = $null
    if ($DenyAppend -and $DenyAppend.Count -gt 0 -and $DenyPath) {
        $appendOnlyKey = Path-Key $DenyPath
        $existingDeny = Get-PropertyAt -Object $proposed -Path $DenyPath
        $existingArr = if ($existingDeny.Found) { @($existingDeny.Value) } else { @() }
        $combined = @($existingArr)
        $added = @()
        foreach ($rule in $DenyAppend) {
            if ($combined -notcontains $rule) {
                $combined += $rule
                $added += $rule
            }
        }
        if ($added.Count -gt 0) {
            Set-PropertyAt -Object $proposed -Path $DenyPath -Value $combined
            $changeLog += [pscustomobject]@{
                Path     = ($DenyPath -join '.')
                Action   = 'append'
                Previous = "$($existingArr.Count) entries"
                New      = "$($combined.Count) entries (+$($added.Count))"
            }
        }
    }

    # Verification: serialize then re-parse so the saved bytes are what we audit.
    $serialized = $proposed | ConvertTo-Json -Depth 100
    $roundTripped = $serialized | ConvertFrom-Json
    $unexpected = Test-Verify-Preserved -Original $original -New $roundTripped -AllowedChangedPaths $allowedPaths -AppendOnlyArrayPathKey $appendOnlyKey

    if ($unexpected.Count -gt 0) {
        $details = $unexpected | ForEach-Object { "  - $($_.Path): $($_.Kind)" } | Out-String
        throw ("ABORT: serialization would change keys outside the posture's allowed set. " +
               "No file was written. Unexpected changes:`n$details")
    }

    if ($DryRun) {
        return [pscustomobject]@{
            File         = $Path
            Changes      = $changeLog
            Verified     = $true
            BytesBefore  = if (Test-Path $Path) { (Get-Item $Path).Length } else { 0 }
            BackupTarget = '<dry-run, not written>'
        }
    }

    if ($changeLog.Count -eq 0) {
        return [pscustomobject]@{
            File         = $Path
            Changes      = @()
            Verified     = $true
            BackupTarget = '<no change>'
        }
    }

    if (Test-Path $Path) {
        Ensure-ParentDirectory -Path $BackupTarget
        Copy-Item -Force -LiteralPath $Path -Destination $BackupTarget
        Confirm-BackupIntegrity -SourcePath $Path -BackupPath $BackupTarget
    }
    Ensure-ParentDirectory -Path $Path
    # UTF-8 without BOM; PS 5.1's -Encoding UTF8 emits a BOM, which we avoid.
    [System.IO.File]::WriteAllText($Path, $serialized, (New-Object System.Text.UTF8Encoding $false))

    return [pscustomobject]@{
        File         = $Path
        Changes      = $changeLog
        Verified     = $true
        BackupTarget = if (Test-Path $BackupTarget) { $BackupTarget } else { '<no original to back up>' }
    }
}

function Apply-ClaudeMdBlock {
    param(
        [string]$Path,
        [string]$ManagedBlock,
        [string]$BackupTarget,
        [switch]$DryRun
    )
    $existing = if (Test-Path $Path) { Get-Content -Raw -Path $Path } else { $null }
    $action = $null
    $proposed = $null

    $markedPattern = '(?s)<!-- PACKAGE-AWARE-HARDENING:START -->.*?<!-- PACKAGE-AWARE-HARDENING:END -->'
    $unmarkedPattern = '(?ms)^##\s+Global hardening overrides.*?(?=^##\s|\z)'

    if ($null -eq $existing) {
        $proposed = $ManagedBlock + "`r`n`r`n# Claude Code - global context`r`n"
        $action = 'inserted-new-file'
    } elseif ($existing -match $markedPattern) {
        # MatchEvaluator form: the replacement is a literal string with no
        # back-reference interpretation, so a block containing $ or \1 is safe.
        $proposed = [regex]::Replace($existing, $markedPattern, { param($m) $ManagedBlock })
        $action = if ($proposed -ne $existing) { 'refreshed-managed-block' } else { 'no-op-managed-block-current' }
    } elseif ($existing -match $unmarkedPattern) {
        $proposed = $existing
        $action = 'skipped-existing-unmarked-section'
    } else {
        $proposed = $ManagedBlock + "`r`n`r`n" + $existing
        $action = 'prepended-managed-block'
    }

    $willWrite = ($action -ne 'skipped-existing-unmarked-section') -and ($action -ne 'no-op-managed-block-current') -and ($proposed -ne $existing)

    if ($DryRun) {
        return [pscustomobject]@{
            File         = $Path
            Action       = $action
            WillWrite    = [bool]$willWrite
            BackupTarget = '<dry-run, not written>'
        }
    }

    if (-not $willWrite) {
        return [pscustomobject]@{
            File         = $Path
            Action       = $action
            BackupTarget = '<no change>'
        }
    }

    if ($null -ne $existing) {
        Ensure-ParentDirectory -Path $BackupTarget
        Copy-Item -Force -LiteralPath $Path -Destination $BackupTarget
        Confirm-BackupIntegrity -SourcePath $Path -BackupPath $BackupTarget
    }
    Ensure-ParentDirectory -Path $Path
    # UTF-8 without BOM.
    [System.IO.File]::WriteAllText($Path, $proposed, (New-Object System.Text.UTF8Encoding $false))

    return [pscustomobject]@{
        File         = $Path
        Action       = $action
        BackupTarget = if (Test-Path $BackupTarget) { $BackupTarget } else { '<no original to back up>' }
    }
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------

$timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$backupDir = Join-Path $BackupRoot $timestamp

# Distinct backup names so the Claude and VS Code settings.json backups
# cannot collide. (The previous implementation used [IO.Path]::GetFileName
# alone, so the second backup overwrote the first.)
$claudeSettingsBackup = Join-Path $backupDir 'claude_settings.json.bak'
$claudeMdBackup       = Join-Path $backupDir 'claude_CLAUDE.md.bak'
$vscodeSettingsBackup = Join-Path $backupDir 'vscode_settings.json.bak'

$claudeResult = Apply-PostureToJsonFile `
    -Path $ClaudeSettingsPath `
    -ScalarSettings $claudeScalarSettings `
    -DenyAppend $claudeDenyAppend `
    -DenyPath @('permissions','deny') `
    -BackupTarget $claudeSettingsBackup `
    -DryRun:$DryRun

$claudeMdResult = Apply-ClaudeMdBlock `
    -Path $ClaudeMdPath `
    -ManagedBlock $managedBlock `
    -BackupTarget $claudeMdBackup `
    -DryRun:$DryRun

$vscodeResult = Apply-PostureToJsonFile `
    -Path $VSCodeSettingsPath `
    -ScalarSettings $vscodeScalarSettings `
    -DenyAppend @() `
    -DenyPath $null `
    -BackupTarget $vscodeSettingsBackup `
    -DryRun:$DryRun

$summary = [pscustomobject]@{
    DryRun           = [bool]$DryRun
    BackupDirectory  = if ($DryRun) { '<dry-run, not created>' } else { $backupDir }
    ClaudeSettings   = $claudeResult
    ClaudeMd         = $claudeMdResult
    VSCodeSettings   = $vscodeResult
}

# Print a human-readable summary to the host (does not pollute the pipeline).
Write-Host ("=" * 64)
Write-Host "Package-aware hardening -- $(if ($DryRun) { 'DRY-RUN (no writes)' } else { 'APPLIED' })"
Write-Host ("=" * 64)
Write-Host ("Backup directory: {0}" -f $summary.BackupDirectory)
foreach ($section in @(
    @{ Label = 'Claude settings'; Result = $claudeResult },
    @{ Label = 'VS Code settings'; Result = $vscodeResult }
)) {
    Write-Host ""
    Write-Host ("--- {0} ({1}) ---" -f $section.Label, $section.Result.File)
    if ($section.Result.Changes -and $section.Result.Changes.Count -gt 0) {
        $section.Result.Changes | Format-Table -AutoSize Path, Action, Previous, New | Out-String | Write-Host
    } else {
        Write-Host "  (no changes -- posture already current)"
    }
}
Write-Host ""
Write-Host ("--- CLAUDE.md ({0}) ---" -f $claudeMdResult.File)
Write-Host ("  action: {0}" -f $claudeMdResult.Action)
Write-Host ("=" * 64)

# Emit the structured object so callers can also consume it programmatically.
$summary
