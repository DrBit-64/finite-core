param(
    [int]$Frames = 180
)

$ErrorActionPreference = "Continue"
$projectRoot = Split-Path -Parent $PSScriptRoot
$godotConsole = "D:\Godot\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64_console.exe"
$scenePath = "res://Tests/scenes/building_projectile_destruction_check.tscn"
$logDirectory = Join-Path $projectRoot "debug_exports\logs"
$logFile = Join-Path $logDirectory "building_projectile_destruction.log"

if (-not (Test-Path -LiteralPath $godotConsole)) {
    throw "Godot console not found: $godotConsole"
}

New-Item -ItemType Directory -Force -Path $logDirectory | Out-Null
$output = & $godotConsole --headless --path $projectRoot --log-file $logFile --quit-after $Frames $scenePath 2>&1
$exitCode = $LASTEXITCODE
$output | ForEach-Object { Write-Host $_ }

$failurePatterns = @(
    "SCRIPT ERROR",
    "WARNING:",
    "GDScript::reload:",
    "Invalid call",
    "invalid UID",
    "Parse Error",
    "Resource file not found",
    "signal 11",
    "Segmentation fault",
    "ERROR:"
)

$failureLines = @($output | Where-Object {
    $line = [string]$_
    $failurePatterns | Where-Object { $line -match [regex]::Escape($_) }
})

if ($exitCode -ne 0 -or $failureLines.Count -gt 0) {
    Write-Error "Building projectile destruction check failed. Exit code: $exitCode. Matched lines: $($failureLines.Count)"
    exit 1
}

Write-Host "BUILDING_PROJECTILE_DESTRUCTION_CHECK_OK"
