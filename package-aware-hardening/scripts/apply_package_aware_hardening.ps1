[CmdletBinding()]
param(
    [string]$ClaudeSettingsPath = (Join-Path $HOME '.claude\settings.json'),
    [string]$ClaudeMdPath = (Join-Path $HOME '.claude\CLAUDE.md'),
    [string]$VSCodeSettingsPath = (Join-Path $env:APPDATA 'Code\User\settings.json'),
    [string]$BackupRoot = (Join-Path $HOME '.claude\backups\package-aware-hardening'),
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'

function ConvertTo-NativeValue {
    param([object]$InputObject)

    if ($null -eq $InputObject) {
        return $null
    }

    if ($InputObject -is [System.Collections.IDictionary]) {
        $table = @{}
        foreach ($key in $InputObject.Keys) {
            $table[$key] = ConvertTo-NativeValue -InputObject $InputObject[$key]
        }
        return $table
    }

    if ($InputObject -is [System.Collections.IEnumerable] -and -not ($InputObject -is [string])) {
        $items = @()
        foreach ($item in $InputObject) {
            $items += ,(ConvertTo-NativeValue -InputObject $item)
        }
        return $items
    }

    if ($InputObject.PSObject -and $InputObject.PSObject.Properties.Count -gt 0) {
        $table = @{}
        foreach ($property in $InputObject.PSObject.Properties) {
            $table[$property.Name] = ConvertTo-NativeValue -InputObject $property.Value
        }
        return $table
    }

    return $InputObject
}

function Ensure-ParentDirectory {
    param([string]$Path)
    $parent = Split-Path -Parent $Path
    if ($parent -and -not (Test-Path $parent)) {
        New-Item -ItemType Directory -Force -Path $parent | Out-Null
    }
}

function Load-JsonObject {
    param([string]$Path)
    if (-not (Test-Path $Path)) {
        return @{}
    }
    $raw = Get-Content -Raw -Path $Path
    if ([string]::IsNullOrWhiteSpace($raw)) {
        return @{}
    }
    $parsed = $raw | ConvertFrom-Json
    return (ConvertTo-NativeValue -InputObject $parsed)
}

function Save-JsonObject {
    param(
        [hashtable]$Object,
        [string]$Path
    )
    Ensure-ParentDirectory -Path $Path
    $json = $Object | ConvertTo-Json -Depth 100
    Set-Content -Path $Path -Value $json
}

function Backup-File {
    param(
        [string]$SourcePath,
        [string]$DestinationDirectory
    )
    if (Test-Path $SourcePath) {
        Ensure-ParentDirectory -Path (Join-Path $DestinationDirectory 'placeholder.txt')
        Copy-Item -Force $SourcePath (Join-Path $DestinationDirectory ([IO.Path]::GetFileName($SourcePath) + '.bak'))
    }
}

function Ensure-StringListContains {
    param(
        [object[]]$Existing,
        [string[]]$Required
    )
    $list = @()
    if ($null -ne $Existing) {
        $list = @($Existing)
    }
    foreach ($value in $Required) {
        if ($list -notcontains $value) {
            $list += $value
        }
    }
    return $list
}

$timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$backupDir = Join-Path $BackupRoot $timestamp

$requiredDenyRules = @(
    'Bash(pip install *)',
    'Bash(pip3 install *)',
    'Bash(pip download *)',
    'Bash(pip wheel *)',
    'Bash(pipx install *)',
    'Bash(pipx run *)',
    'Bash(python -m pip install *)',
    'Bash(python3 -m pip install *)',
    'Bash(py -m pip install *)',
    'Bash(uv pip install *)',
    'Bash(uv add *)',
    'Bash(uv sync *)',
    'Bash(uv run *)',
    'Bash(poetry add *)',
    'Bash(poetry install *)',
    'Bash(conda install *)',
    'Bash(mamba install *)',
    'Bash(npm install)',
    'Bash(npm install *)',
    'Bash(npm i *)',
    'Bash(npm i)',
    'Bash(npm add *)',
    'Bash(npm ci *)',
    'Bash(npm ci)',
    'Bash(npm exec *)',
    'Bash(pnpm install *)',
    'Bash(pnpm install)',
    'Bash(pnpm add *)',
    'Bash(pnpm i *)',
    'Bash(pnpm i)',
    'Bash(pnpm exec *)',
    'Bash(pnpm exec)',
    'Bash(pnpm dlx *)',
    'Bash(yarn install)',
    'Bash(yarn install *)',
    'Bash(yarn add *)',
    'Bash(yarn dlx *)',
    'Bash(bun install)',
    'Bash(bun install *)',
    'Bash(bun add *)',
    'Bash(bun x)',
    'Bash(bun x *)',
    'Bash(bunx *)',
    'Bash(npx *)',
    'Bash(npx)',
    'Bash(code --install-extension *)',
    'PowerShell(pip install *)',
    'PowerShell(pip3 install *)',
    'PowerShell(pip download *)',
    'PowerShell(pip wheel *)',
    'PowerShell(pipx install *)',
    'PowerShell(pipx run *)',
    'PowerShell(python -m pip install *)',
    'PowerShell(python3 -m pip install *)',
    'PowerShell(py -m pip install *)',
    'PowerShell(uv pip install *)',
    'PowerShell(uv add *)',
    'PowerShell(uv sync *)',
    'PowerShell(uv run *)',
    'PowerShell(poetry add *)',
    'PowerShell(poetry install *)',
    'PowerShell(conda install *)',
    'PowerShell(mamba install *)',
    'PowerShell(npm install)',
    'PowerShell(npm install *)',
    'PowerShell(npm i *)',
    'PowerShell(npm i)',
    'PowerShell(npm add *)',
    'PowerShell(npm ci *)',
    'PowerShell(npm ci)',
    'PowerShell(npm exec *)',
    'PowerShell(npm exec)',
    'PowerShell(pnpm install *)',
    'PowerShell(pnpm install)',
    'PowerShell(pnpm add *)',
    'PowerShell(pnpm i *)',
    'PowerShell(pnpm i)',
    'PowerShell(pnpm exec *)',
    'PowerShell(pnpm exec)',
    'PowerShell(pnpm dlx *)',
    'PowerShell(yarn install)',
    'PowerShell(yarn install *)',
    'PowerShell(yarn add *)',
    'PowerShell(yarn dlx *)',
    'PowerShell(bun install)',
    'PowerShell(bun install *)',
    'PowerShell(bun add *)',
    'PowerShell(bun x)',
    'PowerShell(bun x *)',
    'PowerShell(bunx *)',
    'PowerShell(npx *)',
    'PowerShell(npx)',
    'PowerShell(code --install-extension *)'
)

$claudeSettings = Load-JsonObject -Path $ClaudeSettingsPath
if (-not $claudeSettings.ContainsKey('env') -or $null -eq $claudeSettings.env) {
    $claudeSettings.env = @{}
}
$claudeSettings.env['DISABLE_AUTOUPDATER'] = '1'
$claudeSettings['autoUpdatesChannel'] = 'stable'
$claudeSettings['allowedHttpHookUrls'] = @()
$claudeSettings['disableBypassPermissionsMode'] = 'disable'

if (-not $claudeSettings.ContainsKey('enabledPlugins') -or $null -eq $claudeSettings.enabledPlugins) {
    $claudeSettings.enabledPlugins = @{}
}
$claudeSettings.enabledPlugins['supabase@claude-plugins-official'] = $false

if (-not $claudeSettings.ContainsKey('permissions') -or $null -eq $claudeSettings.permissions) {
    $claudeSettings.permissions = @{}
}
$claudeSettings.permissions['deny'] = Ensure-StringListContains -Existing $claudeSettings.permissions['deny'] -Required $requiredDenyRules

$managedBlock = @"
<!-- PACKAGE-AWARE-HARDENING:START -->
## Global hardening overrides (2026-05-21)

- Claude Code auto-updating is disabled via `DISABLE_AUTOUPDATER=1`.
- `autoUpdatesChannel` is pinned to `stable`.
- `disableBypassPermissionsMode` is set to `disable` globally.
- Remote HTTP hooks are blocked by default via `allowedHttpHookUrls: []`.
- The Supabase plugin is disabled globally.
- Supabase work should prefer a standalone CLI installation rather than the plugin or `npx supabase`.
- Do not suggest `code --install-extension` without explicit user approval.
- VS Code user settings are expected to keep app and extension updates manual.
<!-- PACKAGE-AWARE-HARDENING:END -->
"@

if (Test-Path $ClaudeMdPath) {
    $claudeMd = Get-Content -Raw -Path $ClaudeMdPath
} else {
    $claudeMd = "# Claude Code - global context`r`n`r`n"
}

$pattern = '<!-- PACKAGE-AWARE-HARDENING:START -->.*?<!-- PACKAGE-AWARE-HARDENING:END -->'
# A hand-written hardening section may use this heading without the managed
# markers. We must NOT overwrite it: on the machine that authored the posture,
# that section is typically richer than this generic block (rollback paths,
# incident notes, per-setting detail). Replacing it would discard real content.
$legacyPattern = '(?ms)^##\s+Global hardening overrides.*?(?=^##\s|\z)'
$claudeMdAction = $null
if ($claudeMd -match $pattern) {
    # Markers present: this block is script-managed, safe to refresh in place.
    $claudeMd = [regex]::Replace($claudeMd, $pattern, $managedBlock, 'Singleline')
    $claudeMdAction = 'updated-managed-block'
} elseif ($claudeMd -match $legacyPattern) {
    # Unmarked hand-written section: leave the file untouched and report it.
    $claudeMdAction = 'skipped-existing-unmarked-section'
} else {
    $claudeMd = $managedBlock + "`r`n`r`n" + $claudeMd
    $claudeMdAction = 'inserted-managed-block'
}

$vscodeSettings = Load-JsonObject -Path $VSCodeSettingsPath
$vscodeSettings['update.mode'] = 'manual'
$vscodeSettings['extensions.autoUpdate'] = $false
$vscodeSettings['extensions.autoCheckUpdates'] = $false

if ($claudeMdAction -eq 'skipped-existing-unmarked-section') {
    Write-Warning ("CLAUDE.md left untouched: an unmarked '## Global hardening overrides' " +
        "section already exists and may contain hand-written detail. Convert it manually by " +
        "wrapping it in <!-- PACKAGE-AWARE-HARDENING:START --> / :END --> markers if you want " +
        "this script to manage it.")
}

if ($DryRun) {
    [pscustomobject]@{
        ClaudeSettingsPath = $ClaudeSettingsPath
        ClaudeMdPath = $ClaudeMdPath
        VSCodeSettingsPath = $VSCodeSettingsPath
        BackupRoot = $BackupRoot
        AddedDenyRules = $requiredDenyRules.Count
        SupabasePluginDisabled = $true
        VSCodeManualUpdates = $true
        ClaudeMdAction = $claudeMdAction
    } | Format-List
    return
}

New-Item -ItemType Directory -Force -Path $backupDir | Out-Null
Backup-File -SourcePath $ClaudeSettingsPath -DestinationDirectory $backupDir
Backup-File -SourcePath $ClaudeMdPath -DestinationDirectory $backupDir
Backup-File -SourcePath $VSCodeSettingsPath -DestinationDirectory $backupDir

Save-JsonObject -Object $claudeSettings -Path $ClaudeSettingsPath
if ($claudeMdAction -ne 'skipped-existing-unmarked-section') {
    Ensure-ParentDirectory -Path $ClaudeMdPath
    Set-Content -Path $ClaudeMdPath -Value $claudeMd
}
Save-JsonObject -Object $vscodeSettings -Path $VSCodeSettingsPath

[pscustomobject]@{
    BackupDirectory = $backupDir
    ClaudeSettingsUpdated = $true
    ClaudeMdAction = $claudeMdAction
    ClaudeMdUpdated = ($claudeMdAction -ne 'skipped-existing-unmarked-section')
    VSCodeSettingsUpdated = $true
} | Format-List
