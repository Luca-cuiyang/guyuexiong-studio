# HARD RELEASE POLICY:
# Keep only the current DB Studio MSI packages.

param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^\d+\.\d+\.\d+$')]
    [string]$Version
)

$ErrorActionPreference = "Stop"

$candidateRoots = @(
    "C:\Mac\Home",
    "C:\Mac\Home\Desktop",
    "C:\Mac\Home\Downloads",
    "C:\DBStudio\dist"
)
$patterns = @(
    "*DB*Studio*.msi",
    "*DB*Studio*.exe",
    "*DB*Studio*.win",
    "*DB*Studio*.zip",
    "*DB*Studio*.7z",
    "*DB*Studio*.appx",
    "*DB*Studio*.msix"
)

$candidates = foreach ($root in $candidateRoots) {
    if (Test-Path -LiteralPath $root) {
        foreach ($pattern in $patterns) {
            Get-ChildItem -LiteralPath $root -File -Filter $pattern -ErrorAction SilentlyContinue
        }
    }
}

$candidates = $candidates | Sort-Object FullName -Unique
if (-not $candidates) {
    Write-Output "No DB Studio Windows package candidates found."
    exit 0
}

$keepPaths = @(
    [IO.Path]::GetFullPath("C:\Mac\Home\Desktop\DB Studio.msi"),
    [IO.Path]::GetFullPath("C:\Mac\Home\Desktop\DB-Studio-Windows-$Version.msi")
)

foreach ($candidate in $candidates) {
    $candidatePath = [IO.Path]::GetFullPath($candidate.FullName)
    if ($keepPaths -contains $candidatePath) {
        Write-Output "Keeping current Windows package: $candidatePath"
        continue
    }
    Remove-Item -LiteralPath $candidatePath -Force
    Write-Output "Removed old Windows package: $candidatePath"
}
