[CmdletBinding()]
param(
    [string]$OutputPath
)

$ErrorActionPreference = 'Stop'

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$skillDir = Split-Path -Parent $scriptDir
$packageAwareDir = Split-Path -Parent $skillDir
$templatePath = Join-Path $skillDir 'references\shareable-template.md'

if (-not $PSBoundParameters.ContainsKey('OutputPath') -or [string]::IsNullOrWhiteSpace($OutputPath)) {
    $OutputPath = Join-Path $packageAwareDir 'PACKAGE_AWARE_PLATFORM_SETTINGS.md'
}

function Ensure-ParentDirectory {
    param([string]$Path)
    $parent = Split-Path -Parent $Path
    if ($parent -and -not (Test-Path $parent)) {
        New-Item -ItemType Directory -Force -Path $parent | Out-Null
    }
}

if (-not (Test-Path $templatePath)) {
    throw "Missing shareable template: $templatePath"
}

$doc = Get-Content -Raw -Path $templatePath
Ensure-ParentDirectory -Path $OutputPath
Set-Content -Path $OutputPath -Value $doc

$written = Get-Content -Raw -Path $OutputPath
$homePath = [regex]::Escape($HOME)
$username = [regex]::Escape($env:USERNAME)
if ($written -match 'C:\\Users\\' -or $written -match $homePath -or $written -match $username) {
    throw 'Sanitization check failed: shareable document contains machine-specific identifiers.'
}

[pscustomobject]@{
    OutputPath = $OutputPath
    TemplatePath = $templatePath
    Sanitized = $true
} | Format-List
