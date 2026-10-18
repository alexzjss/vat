param([string]$Filter = "")

$godot = $env:GODOT
if (-not $godot -or -not (Test-Path $godot)) {
    $godot = $null
    $pkgs = Join-Path $env:LOCALAPPDATA "Microsoft\WinGet\Packages"
    $found = Get-ChildItem (Join-Path $pkgs "GodotEngine.GodotEngine*") -Recurse -Filter "*console*.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($found) { $godot = $found.FullName }
    if (-not $godot) {
        $cmd = Get-Command godot*console*, godot* -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($cmd) { $godot = $cmd.Source }
    }
}
if (-not $godot) {
    Write-Error "Godot nao encontrado. Defina `$env:GODOT com o caminho do executavel de console ou instale via: winget install --id GodotEngine.GodotEngine -e"
    exit 1
}

# Gera o cache global de classes (class_name) necessario em modo headless.
& $godot --headless --path game --import *> $null

$gutArgs = @("--headless", "--path", "game", "-s", "addons/gut/gut_cmdln.gd", "-gdir=res://tests", "-ginclude_subdirs", "-gexit")
if ($Filter) { $gutArgs += "-gselect=$Filter" }
& $godot @gutArgs
exit $LASTEXITCODE
