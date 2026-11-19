# Activa el entorno virtual local de Flutter + Git para App Pixel
# Uso: . .\env.ps1
$ProjectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$FlutterBin = Join-Path $ProjectRoot ".toolchain\flutter\bin"
$GitCmd = Join-Path $ProjectRoot ".toolchain\git\cmd"
$PubCache = Join-Path $ProjectRoot ".toolchain\pub-cache"

$env:PATH = "$FlutterBin;$GitCmd;$env:PATH"
$env:PUB_CACHE = $PubCache

Write-Host "Entorno virtual local activado (Flutter + Git + Pub Cache en .toolchain)" -ForegroundColor Cyan
