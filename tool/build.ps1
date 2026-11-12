<#
.SYNOPSIS
    Builds a signed, obfuscated release bundle for a given version.

.DESCRIPTION
    Runs the release steps from README.md in order:

      1. checks that Flutter is on PATH and that the upload key is configured,
      2. upgrades dependencies to their latest major versions
         (flutter pub upgrade --major-versions), which rewrites pubspec.lock,
      3. builds an obfuscated release App Bundle for Play,
      4. hands the Dart symbol map of that exact build to Crashlytics,
      5. records the version in pubspec.yaml so the next run keeps counting up,
      6. commits everything with the version in the message and pushes it.

    Step 6 stages the whole working tree (git add --all), because a release is
    usually the moment a batch of work gets recorded. Anything else that was
    already uncommitted goes in with it.

    The Crashlytics app id is read from firebase.json, so it cannot drift from the
    configuration the app itself is compiled with; -AppId overrides it.

.PARAMETER Version
    A single number: the last part of the version and the versionCode at once.
    -Version 3 on a 1.0.x project builds version 1.0.3 with versionCode 3, which
    is the number Play wants to see grow with every upload.

.PARAMETER AppId
    The Firebase Android app id for the symbol upload. Defaults to the android
    appId in firebase.json.

.PARAMETER IgnoreToolchainCheck
    Passes --android-skip-build-dependency-validation to Flutter. Only needed if a
    future Flutter SDK rejects the pinned Gradle / AGP versions (see README.md).

.PARAMETER DryRun
    Print the plan and the paths without building, uploading or changing anything.

.PARAMETER NoPush
    Commit the release but leave the push to you, for when the network or the
    credentials are not there.

.EXAMPLE
    ./tool/build.ps1 -Version 3

.EXAMPLE
    ./tool/build.ps1 -Version 4 -DryRun
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [ValidateRange(1, 2100000000)]
    [int] $Version,

    [string] $AppId,

    [switch] $IgnoreToolchainCheck,

    [switch] $NoPush,

    [switch] $DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$pubspec = Join-Path $repoRoot 'pubspec.yaml'
$firebaseJson = Join-Path $repoRoot 'firebase.json'
$keyProperties = Join-Path $repoRoot 'android\key.properties'
$aabPath = Join-Path $repoRoot 'build\app\outputs\bundle\release\app-release.aab'

function Write-Step {
    param([string] $Text)

    Write-Host ''
    Write-Host $Text -ForegroundColor Cyan
}

function Invoke-Tool {
    param([string] $Name, [string[]] $Arguments)

    Write-Host "  $Name $($Arguments -join ' ')" -ForegroundColor DarkGray
    if ($DryRun) { return }

    # Windows PowerShell turns a native command's stderr output into a terminating
    # error while $ErrorActionPreference is 'Stop'. Flutter and git both write
    # warnings there, so relax it for the call and judge by the exit code instead.
    $previous = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        & $Name @Arguments
    } finally {
        $ErrorActionPreference = $previous
    }

    if ($LASTEXITCODE -ne 0) {
        throw "$Name exited with code $LASTEXITCODE."
    }
}

# --- What are we building? -------------------------------------------------

$pubspecText = [System.IO.File]::ReadAllText($pubspec)
$versionLine = [regex]::Match($pubspecText, '(?m)^version:\s*(\S+)\s*$')
if (-not $versionLine.Success) {
    throw "No 'version:' line found in $pubspec."
}

# 1.0.0+2 -> name "1.0.0", versionCode 2
$currentVersion = $versionLine.Groups[1].Value
$currentBuild = 0
$buildSuffix = [regex]::Match($currentVersion, '\+(\d+)$')
if ($buildSuffix.Success) { $currentBuild = [int]$buildSuffix.Groups[1].Value }

$nameSegments = ($currentVersion -split '\+')[0].Split('.')
$prefix = if ($nameSegments.Length -ge 2) { "$($nameSegments[0]).$($nameSegments[1])" } else { '1.0' }

if ($Version -le $currentBuild) {
    throw "Play needs a versionCode above the current $currentBuild; pass a number greater than $currentBuild."
}

$versionName = "$prefix.$Version"
$buildNumber = $Version
$newVersion = "$versionName+$buildNumber"
$symbolsDir = Join-Path (Join-Path $repoRoot 'build\symbols') $newVersion

# Flutter only writes a symbol map when it actually compiles Dart, and the build
# cache skips that when nothing changed - which left the version folder empty on
# a rebuild. The split-debug-info path is part of the build fingerprint, so a
# fresh path per run guarantees a fresh compile and a fresh map for this build.
$stagingDir = Join-Path $repoRoot ('build\symbols\.pending-' + [guid]::NewGuid().ToString('N').Substring(0, 8))

# --- Crashlytics app id ----------------------------------------------------

if (-not $AppId) {
    $config = [System.IO.File]::ReadAllText($firebaseJson)
    $appIdMatch = [regex]::Match($config, '"appId"\s*:\s*"([^"]+)"')
    if (-not $appIdMatch.Success) {
        throw "No android appId in $firebaseJson; pass -AppId."
    }
    $AppId = $appIdMatch.Groups[1].Value
}
$projectMatch = [regex]::Match([System.IO.File]::ReadAllText($firebaseJson), '"projectId"\s*:\s*"([^"]+)"')
$firebaseProject = if ($projectMatch.Success) { $projectMatch.Groups[1].Value } else { '' }

Write-Step "WikiTree Viewer $newVersion"
Write-Host "  crashlytics app  $AppId"

# --- Preflight -------------------------------------------------------------

if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
    throw 'flutter is not on PATH.'
}

if (-not $DryRun -and -not (Test-Path -LiteralPath $keyProperties)) {
    throw 'android\key.properties is missing: a release build would fall back to the debug key, and Play rejects that.'
}

if ((Get-Command git -ErrorAction SilentlyContinue) -and -not $DryRun) {
    $dirty = @(& git -C $repoRoot status --porcelain 2>$null)
    if ($dirty.Count -gt 0) {
        Write-Warning 'The working tree has uncommitted changes: this build is not exactly a commit.'
    }
}

# --- Dependencies ----------------------------------------------------------

Write-Step 'Upgrading dependencies to their latest major versions'
Invoke-Tool flutter @('pub', 'upgrade', '--major-versions')

# --- Build -----------------------------------------------------------------

$common = @(
    '--release'
    "--build-name=$versionName"
    "--build-number=$buildNumber"
    '--obfuscate'
    "--split-debug-info=$stagingDir"
)

if ($IgnoreToolchainCheck) {
    Write-Warning "Skipping Flutter's toolchain version check."
    $common += '--android-skip-build-dependency-validation'
}

Write-Step 'Building the release App Bundle'
Invoke-Tool flutter (@('build', 'appbundle') + $common)

# --- Symbols: keep them, and hand them to Crashlytics ----------------------

$symbolFiles = @()
if (-not $DryRun) {
    $symbolFiles = @(Get-ChildItem -LiteralPath $stagingDir -Filter 'app.android-*.symbols' -File -ErrorAction SilentlyContinue)
    if ($symbolFiles.Count -eq 0) {
        throw "No Dart symbols were written to $stagingDir. Without them a crash from this build cannot be read."
    }
    foreach ($file in $symbolFiles) {
        if ($file.Length -eq 0) { throw "Symbol file $($file.Name) is empty." }
    }

    New-Item -ItemType Directory -Force -Path $symbolsDir | Out-Null
    foreach ($file in $symbolFiles) {
        Copy-Item -LiteralPath $file.FullName -Destination (Join-Path $symbolsDir $file.Name) -Force
    }
    Remove-Item -LiteralPath $stagingDir -Recurse -Force
    $symbolFiles = @(Get-ChildItem -LiteralPath $symbolsDir -Filter 'app.android-*.symbols' -File)
}

Write-Step 'Uploading the Dart symbols to Crashlytics'
$upload = @('crashlytics:symbols:upload', "--app=$AppId")
if ($firebaseProject) { $upload += "--project=$firebaseProject" }
if ($DryRun) {
    $upload += "$symbolsDir\app.android-*.symbols"
} else {
    $upload += $symbolFiles | ForEach-Object { $_.FullName }
}
Invoke-Tool firebase $upload

# --- Record the version ----------------------------------------------------

if (-not $DryRun) {
    # Re-read: the upgrade above may have rewritten dependency constraints.
    $text = [System.IO.File]::ReadAllText($pubspec)
    $updated = [regex]::Replace($text, '(?m)^version:\s*\S+\s*$', "version: $newVersion")
    [System.IO.File]::WriteAllText($pubspec, $updated, (New-Object System.Text.UTF8Encoding($false)))
}

# --- Commit and push -------------------------------------------------------

# After the build, never before: a failed build leaves the repository untouched,
# and what is committed is exactly the tree the bundle was built from.
$commitMessage = "Release $newVersion"

if ($DryRun) {
    Write-Step 'Committing and pushing'
    Write-Host "  git add --all" -ForegroundColor DarkGray
    Write-Host "  git commit -m `"$commitMessage`"" -ForegroundColor DarkGray
    if ($NoPush) {
        Write-Host '  (push skipped: -NoPush)' -ForegroundColor DarkGray
    } else {
        Write-Host '  git push origin HEAD' -ForegroundColor DarkGray
    }
} else {
    Write-Step 'Committing and pushing'

    $pending = @(& git -C $repoRoot status --porcelain 2>$null)
    if ($pending.Count -eq 0) {
        Write-Host '  nothing to commit: the tree already matches this release.'
    } else {
        Write-Host "  $($pending.Count) changed path(s)" -ForegroundColor DarkGray
        Invoke-Tool git @('-C', $repoRoot, 'add', '--all')
        Invoke-Tool git @('-C', $repoRoot, 'commit', '-m', $commitMessage)

        if ($NoPush) {
            Write-Host '  committed locally; push skipped (-NoPush)'
        } else {
            # origin HEAD works whether or not the branch tracks an upstream.
            Invoke-Tool git @('-C', $repoRoot, 'push', 'origin', 'HEAD')
        }
    }
}

# --- What now? -------------------------------------------------------------

Write-Step 'Built'

Write-Host "  version   $newVersion"
Write-Host "  bundle    $aabPath"
Write-Host "  symbols   $symbolsDir"
Write-Host "  commit    `"$commitMessage`""

Write-Host ''
Write-Host '  Upload the bundle to Play (internal testing first).'
Write-Host '  Keep the symbols folder somewhere durable: it is the only way back from'
Write-Host '  an obfuscated stack trace, and "flutter clean" deletes it.'
Write-Host ''
Write-Host '  Crashlytics now has the symbol map for this build, so new reports should'
Write-Host '  arrive readable. For a trace already pasted out of the console:'
Write-Host "    flutter symbolize -i stack.txt -d `"$(Join-Path $symbolsDir 'app.android-arm64.symbols')`""

