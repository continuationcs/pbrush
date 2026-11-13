# Copies the mods in this repo into the game's UE4SS Mods folder and enables them.
# Usage: powershell -File src\tools\install.ps1 [-Game <PBZ dir>] [-Mods BossRush,BossRushProbe]
param(
    [string]$Game = 'G:\G\Steam\steamapps\common\PBZ',
    [string[]]$Mods = @('BossRush')
)
$ErrorActionPreference = 'Stop'
$src_root = Split-Path -Parent $PSScriptRoot    # src\
$target = Join-Path $Game 'platform\steam\ue4ss\Mods'
if (-not (Test-Path $target)) { throw "UE4SS Mods folder not found: $target" }
foreach ($m in $Mods) {
    $src = @((Join-Path $src_root "mod\$m"), (Join-Path $src_root "probe\$m")) | Where-Object { Test-Path $_ } | Select-Object -First 1
    if (-not $src) { throw "mod not found in repo: $m" }
    $dst = Join-Path $target $m
    if (Test-Path $dst) { Remove-Item -Recurse -Force $dst }
    Copy-Item -Recurse $src $dst
    Set-Content -Path (Join-Path $dst 'enabled.txt') -Value '' -Encoding ascii
    Write-Output "installed $m -> $dst"
}
