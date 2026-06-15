<#
.SYNOPSIS
    Tag a version and publish a matching GitHub Release whose notes come from
    CHANGELOG.md -- so the git tag and the GitHub Release never drift apart.

.DESCRIPTION
    The "Latest" badge on GitHub tracks Release objects, not tags. Pushing a
    `git tag` alone leaves the Releases page stale. This script makes the two
    one operation:

      1. Extract the `## <version> - <date>` section from CHANGELOG.md.
      2. Ensure an annotated tag `v<version>` exists at HEAD and is pushed.
      3. Create the GitHub Release for that tag with the extracted notes.

    Use -DryRun to see exactly what would happen (including the resolved notes)
    without tagging, pushing, or publishing anything.

.PARAMETER Version
    The version to release, e.g. "2.3.0" or "v2.3.0" (leading v is optional).
    Must have a matching section in CHANGELOG.md.

.PARAMETER Repo
    The GitHub repo in OWNER/NAME form. Defaults to jibarix/package-aware.

.PARAMETER NotLatest
    Do not mark this Release as "Latest". By default the Release is marked
    latest.

.PARAMETER DryRun
    Print the planned actions and the resolved release notes, then exit without
    changing anything.

.EXAMPLE
    ./release.ps1 -Version 2.3.0 -DryRun
    ./release.ps1 -Version 2.3.0
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Version,

    [string]$Repo = 'jibarix/package-aware',

    [switch]$NotLatest,

    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'

# --- Resolve paths ----------------------------------------------------------
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$skillDir = Split-Path -Parent $scriptDir
$packageAwareDir = Split-Path -Parent $skillDir
$changelogPath = Join-Path $packageAwareDir 'CHANGELOG.md'

# --- Preconditions ----------------------------------------------------------
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    throw 'git is not on PATH.'
}
if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
    throw 'GitHub CLI (gh) is not on PATH. Install it and run `gh auth login`.'
}
if (-not (Test-Path $changelogPath)) {
    throw "Missing CHANGELOG: $changelogPath"
}

# --- Normalize the version --------------------------------------------------
$cleanVersion = $Version.Trim() -replace '^v', ''
if ($cleanVersion -notmatch '^\d+\.\d+\.\d+') {
    throw "Version '$Version' does not look like a semantic version (e.g. 2.3.0)."
}
$tag = "v$cleanVersion"
$title = "$tag - Package-Aware Hardening"

# --- Extract the matching CHANGELOG section ---------------------------------
# Sections look like:  ## 2.2.0 - 2026-06-09  ... up to the next "## " heading.
$changelog = Get-Content -Raw -Path $changelogPath
$escaped = [regex]::Escape($cleanVersion)
$pattern = "(?ms)^##\s+$escaped\b.*?(?=^##\s+|\z)"
$match = [regex]::Match($changelog, $pattern)
if (-not $match.Success) {
    throw "No CHANGELOG section found for version $cleanVersion (looked for a '## $cleanVersion ...' heading)."
}
$notes = $match.Value.TrimEnd()

# --- Check tag state --------------------------------------------------------
$localTagExists = [bool](git tag --list $tag)
$headSha = (git rev-parse HEAD).Trim()
$tagSha = if ($localTagExists) { (git rev-parse "$tag^{commit}").Trim() } else { $null }

# --- Report plan ------------------------------------------------------------
Write-Host ''
Write-Host "Release plan for $tag" -ForegroundColor Cyan
Write-Host "  Repo:        $Repo"
Write-Host "  Title:       $title"
Write-Host "  Mark latest: $(-not $NotLatest)"
if ($localTagExists) {
    Write-Host "  Tag:         exists locally at $tagSha"
    if ($tagSha -ne $headSha) {
        Write-Host "               (note: tag is not at current HEAD $headSha)" -ForegroundColor Yellow
    }
} else {
    Write-Host "  Tag:         will create annotated tag at HEAD $headSha"
}
Write-Host ''
Write-Host '--- release notes ---' -ForegroundColor DarkGray
Write-Host $notes
Write-Host '--- end notes ---' -ForegroundColor DarkGray
Write-Host ''

if ($DryRun) {
    Write-Host 'DryRun: no tag, push, or release was created.' -ForegroundColor Yellow
    return
}

# --- Guard: a published Release for this tag already exists ------------------
gh release view $tag --repo $Repo 2>$null | Out-Null
if ($LASTEXITCODE -eq 0) {
    throw "A GitHub Release for $tag already exists in $Repo. Delete it first or pick a new version."
}

# --- Create + push tag if needed -------------------------------------------
if (-not $localTagExists) {
    git tag -a $tag -m $title
    if ($LASTEXITCODE -ne 0) { throw "Failed to create tag $tag." }
}
git push origin $tag
if ($LASTEXITCODE -ne 0) { throw "Failed to push tag $tag to origin." }

# --- Publish the Release ----------------------------------------------------
$notesFile = Join-Path ([IO.Path]::GetTempPath()) "release-notes-$tag.md"
Set-Content -Path $notesFile -Value $notes -Encoding utf8
try {
    $ghArgs = @('release', 'create', $tag, '--repo', $Repo, '--title', $title, '--notes-file', $notesFile)
    if (-not $NotLatest) { $ghArgs += '--latest' }
    & gh @ghArgs
    if ($LASTEXITCODE -ne 0) { throw "gh release create failed for $tag." }
}
finally {
    Remove-Item -LiteralPath $notesFile -ErrorAction SilentlyContinue
}

Write-Host ''
Write-Host "Published $tag." -ForegroundColor Green
