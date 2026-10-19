param([int]$Runs = 0, [string]$Out = "")

$godot = $env:GODOT
if (-not $godot -or -not (Test-Path $godot)) {
    $godot = $null
    $pkgs = Join-Path $env:LOCALAPPDATA "Microsoft\WinGet\Packages"
    $found = Get-ChildItem (Join-Path $pkgs "GodotEngine.GodotEngine*") -Recurse -Filter "*console*.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($found) { $godot = $found.FullName }
    if (-not $godot) {
        # So executaveis de console: o executavel de GUI nao devolve saida nem codigo de saida ao terminal.
        $cmd = Get-Command "godot*console*.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($cmd) { $godot = $cmd.Source }
    }
}
if (-not $godot) {
    Write-Error "Godot nao encontrado. Defina `$env:GODOT com o caminho do executavel de console ou instale via: winget install --id GodotEngine.GodotEngine -e"
    exit 1
}

$project = Join-Path $PSScriptRoot "game"

# Gera o cache global de classes (class_name) necessario em modo headless.
$importOut = & $godot --headless --path $project --import 2>&1
if ($LASTEXITCODE -ne 0) {
    $importOut | ForEach-Object { Write-Host $_ }
    Write-Error "Falha no passo de importacao do Godot (codigo $LASTEXITCODE)."
    exit $LASTEXITCODE
}

$simArgs = @("--headless", "--path", $project, "-s", "tools/sim/run_sim.gd", "--")
if ($Runs -gt 0) { $simArgs += @("-runs", "$Runs") }
if ($Out) {
    if (-not [System.IO.Path]::IsPathRooted($Out)) { $Out = Join-Path (Get-Location).Path $Out }
    $simArgs += @("-out", $Out)
}
& $godot @simArgs
exit $LASTEXITCODE
