<#
    Ensambla src\SoporteTI-LianDev.ps1 a partir de las partes de build\ y,
    si ps2exe esta disponible, compila dist\Soporte TI - LianDev.exe

    Uso:  .\build.ps1            ensambla y compila
          .\build.ps1 -SoloPs1   solo ensambla el .ps1
#>
[CmdletBinding()]
param([switch]$SoloPs1)

$ErrorActionPreference = 'Stop'
$raiz = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
$bld  = Join-Path $raiz 'build'
$src  = Join-Path $raiz 'src'
$dist = Join-Path $raiz 'dist'
New-Item -ItemType Directory -Force $src, $dist | Out-Null

$partesAntes = @(
    'part01-cabecera.ps1',
    'part02-catalogo.ps1',
    'part03-ui.ps1',
    'part04-auditoria.ps1',
    'part05-informe.ps1'
)
$partesDespues = @('part07-menu.ps1')

# --- validaciones previas -------------------------------------------------
foreach ($p in ($partesAntes + $partesDespues)) {
    $f = Join-Path $bld $p
    if (-not (Test-Path $f)) { throw "Falta la parte: $p" }
}
$fPlantilla = Join-Path $bld 'plantilla.html'
if (-not (Test-Path $fPlantilla)) { throw 'Falta build\plantilla.html' }

$html = Get-Content -Path $fPlantilla -Raw -Encoding UTF8

# Un "'@" al principio de una linea cerraria el here-string antes de tiempo.
$malas = @(($html -split "`r?`n") | Where-Object { $_ -match "^\s*'@" })
if ($malas.Count -gt 0) {
    throw "plantilla.html tiene una linea que empieza con '@ y romperia el here-string. Indentala o reescribela."
}

# --- ensamblado ----------------------------------------------------------
$sb = New-Object System.Text.StringBuilder
foreach ($p in $partesAntes) {
    [void]$sb.AppendLine((Get-Content -Path (Join-Path $bld $p) -Raw -Encoding UTF8).TrimEnd())
    [void]$sb.AppendLine()
}

[void]$sb.AppendLine('# ==========================================================================')
[void]$sb.AppendLine('#  PLANTILLA HTML EMBEBIDA')
[void]$sb.AppendLine('# ==========================================================================')
[void]$sb.AppendLine('#  Generada por build.ps1 desde build\plantilla.html: no la edites aqui.')
[void]$sb.AppendLine('#  Para retocar el informe sin recompilar, deja un plantilla.html junto al exe.')
[void]$sb.AppendLine()
[void]$sb.AppendLine('$script:PlantillaEmbebida = @''')
[void]$sb.AppendLine($html.TrimEnd())
[void]$sb.AppendLine('''@')
[void]$sb.AppendLine()

foreach ($p in $partesDespues) {
    [void]$sb.AppendLine((Get-Content -Path (Join-Path $bld $p) -Raw -Encoding UTF8).TrimEnd())
    [void]$sb.AppendLine()
}

$salidaPs1 = Join-Path $src 'SoporteTI-LianDev.ps1'
# BOM UTF-8: es lo que mantiene los acentos en pie al compilar con ps2exe.
[System.IO.File]::WriteAllText($salidaPs1, $sb.ToString(), (New-Object System.Text.UTF8Encoding $true))

$lineas = (Get-Content $salidaPs1 | Measure-Object -Line).Lines
Write-Host ("[OK] src\SoporteTI-LianDev.ps1  ($lineas lineas)") -ForegroundColor Green

# --- comprobacion de sintaxis -------------------------------------------
$errores = $null
[void][System.Management.Automation.Language.Parser]::ParseFile($salidaPs1, [ref]$null, [ref]$errores)
if ($errores -and $errores.Count -gt 0) {
    Write-Host "[X] Errores de sintaxis:" -ForegroundColor Red
    $errores | ForEach-Object { Write-Host ("    linea {0}: {1}" -f $_.Extent.StartLineNumber, $_.Message) -ForegroundColor Red }
    throw 'El script ensamblado no parsea.'
}
Write-Host '[OK] Sintaxis valida' -ForegroundColor Green

if ($SoloPs1) { return }

# --- compilacion ---------------------------------------------------------
if (-not (Get-Module -ListAvailable -Name ps2exe)) {
    Write-Host '[!] ps2exe no esta instalado. Instalalo con:' -ForegroundColor Yellow
    Write-Host '    Install-Module ps2exe -Scope CurrentUser' -ForegroundColor DarkGray
    return
}
Import-Module ps2exe -ErrorAction Stop

$salidaExe = Join-Path $dist 'Soporte TI - LianDev.exe'
# -requireAdmin incrusta requestedExecutionLevel="requireAdministrator" en el
# manifiesto: Windows pide la elevacion al abrir el exe y Test-Admin ya siempre
# devuelve $true, asi que ninguna comprobacion del catalogo ni de la auditoria
# se queda a medias por falta de privilegios.
Invoke-PS2EXE -inputFile $salidaPs1 -outputFile $salidaExe -STA -requireAdmin `
    -title 'Soporte TI - LianDev' `
    -description 'Catalogo de comandos y auditoria de equipo y licencias' `
    -company 'LianDev' `
    -product 'Soporte TI - LianDev' `
    -copyright '(c) 2026 Livio Antonio Cornejo Pereira - MIT' `
    -version '2.0.0.0'

if (Test-Path $salidaExe) {
    $kb = [math]::Round((Get-Item $salidaExe).Length / 1KB, 1)
    Write-Host ("[OK] dist\Soporte TI - LianDev.exe  ($kb KB)") -ForegroundColor Green
} else {
    Write-Host '[X] La compilacion no produjo el .exe' -ForegroundColor Red
}
