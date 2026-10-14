# ==========================================================================
#  MOTOR DE PLANTILLA
# ==========================================================================
#  Sintaxis minima, suficiente para el informe:
#     {{ruta.al.campo}}                      valor, escapado a HTML
#     {{.}}                                  el elemento actual (listas de texto)
#     {{#cada ruta}} ... {{/cada}}           repite el bloque por elemento
#     {{#si ruta}} ... {{/si}}               incluye si tiene valor
#     {{#no ruta}} ... {{/no}}               incluye si NO tiene valor

function Test-Verdad {
    param($V)
    if ($null -eq $V) { return $false }
    if ($V -is [bool]) { return $V }
    if ($V -is [string]) { return -not [string]::IsNullOrWhiteSpace($V) }
    if ($V -is [System.Collections.IDictionary]) { return ($V.Count -gt 0) }
    if ($V -is [System.Collections.IEnumerable]) { return (@($V).Count -gt 0) }
    return [bool]$V
}

# Resuelve "a.b.c" contra el elemento actual y, si no esta ahi, contra la raiz.
function Resolve-Ruta {
    param($Ctx, $Raiz, [string]$Ruta)
    $Ruta = $Ruta.Trim()
    if ($Ruta -eq '.') { return $Ctx }
    foreach ($base in @($Ctx, $Raiz)) {
        if ($null -eq $base) { continue }
        $val = $base
        $ok  = $true
        foreach ($seg in ($Ruta -split '\.')) {
            if ($null -eq $val) { $ok = $false; break }
            if ($val -is [System.Collections.IDictionary]) {
                if ($val.Contains($seg)) { $val = $val[$seg] } else { $ok = $false; break }
            } else {
                $p = $val.PSObject.Properties[$seg]
                if ($p) { $val = $p.Value } else { $ok = $false; break }
            }
        }
        if ($ok) { return $val }
    }
    return $null
}

function Expand-Tokens {
    param([string]$T, $Ctx, $Raiz)
    $rx = [regex]'\{\{\s*([^#/{}][^{}]*?)\s*\}\}'
    $sb = New-Object System.Text.StringBuilder
    $i  = 0
    while ($true) {
        $m = $rx.Match($T, $i)
        if (-not $m.Success) { [void]$sb.Append($T.Substring($i)); break }
        [void]$sb.Append($T.Substring($i, $m.Index - $i))
        $v = Resolve-Ruta -Ctx $Ctx -Raiz $Raiz -Ruta $m.Groups[1].Value
        [void]$sb.Append([System.Net.WebUtility]::HtmlEncode([string]$v))
        $i = $m.Index + $m.Length
    }
    return $sb.ToString()
}

# Busca el {{/tipo}} que cierra la apertura, contando anidamientos del mismo tipo.
function Find-CierreBloque {
    param([string]$T, [string]$Tipo, [int]$Desde)
    $rx = [regex]('\{\{(#' + $Tipo + '\s[^{}]*?|/' + $Tipo + ')\}\}')
    $prof = 1
    $pos  = $Desde
    while ($true) {
        $m = $rx.Match($T, $pos)
        if (-not $m.Success) { return $null }
        if ($m.Groups[1].Value.StartsWith('/')) {
            $prof--
            if ($prof -eq 0) { return $m }
        } else { $prof++ }
        $pos = $m.Index + $m.Length
    }
}

function Expand-Bloques {
    param([string]$T, $Ctx, $Raiz)
    $rxAbre = [regex]'\{\{#(cada|si|no)\s+([^{}]+?)\s*\}\}'
    $sb = New-Object System.Text.StringBuilder
    $i  = 0
    while ($true) {
        $m = $rxAbre.Match($T, $i)
        if (-not $m.Success) {
            [void]$sb.Append((Expand-Tokens -T $T.Substring($i) -Ctx $Ctx -Raiz $Raiz))
            break
        }
        # el texto previo al bloque se resuelve con el contexto actual
        [void]$sb.Append((Expand-Tokens -T $T.Substring($i, $m.Index - $i) -Ctx $Ctx -Raiz $Raiz))

        $tipo      = $m.Groups[1].Value
        $ruta      = $m.Groups[2].Value
        $iniCuerpo = $m.Index + $m.Length
        $cierre    = Find-CierreBloque -T $T -Tipo $tipo -Desde $iniCuerpo
        if ($null -eq $cierre) {
            # plantilla mal formada: se deja el resto tal cual, visible para corregir
            [void]$sb.Append((Expand-Tokens -T $T.Substring($m.Index) -Ctx $Ctx -Raiz $Raiz))
            break
        }

        $cuerpo = $T.Substring($iniCuerpo, $cierre.Index - $iniCuerpo)
        $val    = Resolve-Ruta -Ctx $Ctx -Raiz $Raiz -Ruta $ruta

        switch ($tipo) {
            'cada' {
                foreach ($it in @($val)) {
                    if ($null -ne $it) { [void]$sb.Append((Expand-Bloques -T $cuerpo -Ctx $it -Raiz $Raiz)) }
                }
            }
            'si' { if (Test-Verdad $val)       { [void]$sb.Append((Expand-Bloques -T $cuerpo -Ctx $Ctx -Raiz $Raiz)) } }
            'no' { if (-not (Test-Verdad $val)) { [void]$sb.Append((Expand-Bloques -T $cuerpo -Ctx $Ctx -Raiz $Raiz)) } }
        }
        $i = $cierre.Index + $cierre.Length
    }
    return $sb.ToString()
}

# La plantilla embebida es el valor por defecto; un plantilla.html junto al
# script o al .exe la reemplaza sin recompilar nada.
function Get-Plantilla {
    $externa = Join-Path $script:CarpetaBase 'plantilla.html'
    if (Test-Path $externa) {
        try {
            $t = Get-Content -Path $externa -Raw -Encoding UTF8
            if (-not [string]::IsNullOrWhiteSpace($t)) {
                Write-Host '   [i] Usando plantilla.html externa.' -ForegroundColor DarkGray
                return $t
            }
        } catch {
            Write-Host ('   [!] No se pudo leer plantilla.html, se usa la embebida: ' + $_.Exception.Message) -ForegroundColor Yellow
        }
    }
    return $script:PlantillaEmbebida
}

function ConvertTo-InformeHtml {
    param($Datos)
    return (Expand-Bloques -T (Get-Plantilla) -Ctx $Datos -Raiz $Datos)
}

# ==========================================================================
#  AUDITORIA - EJECUCION Y SALIDAS
# ==========================================================================

# Escribe el contenido en el primer destino donde se pueda.
# Devuelve la ruta final o $null.
function Save-Salida {
    param([string]$Nombre, [string]$Contenido, [string[]]$Destinos)
    foreach ($d in $Destinos) {
        if (-not $d) { continue }
        $p = Join-Path $d $Nombre
        try {
            [System.IO.File]::WriteAllText($p, $Contenido, (New-Object System.Text.UTF8Encoding $true))
            if (Test-Path $p) { return $p }
        } catch {}
    }
    return $null
}

function Invoke-Auditoria {
    param([string]$Salida = '', [string[]]$DominiosKMSConfiables = @(), [switch]$NoPausar)

    Show-Header 'AUDITORIA DE EQUIPO Y LICENCIAS' $script:Marca
    if (-not (Test-Admin)) {
        Write-Host '   [!] Sin permisos de administrador: algunos datos pueden salir incompletos.' -ForegroundColor Yellow
        Write-Host '       Para un informe completo, ejecuta la herramienta como administrador.' -ForegroundColor DarkGray
        Write-Host ''
    }

    $datos = Get-DatosAuditoria -DominiosKMSConfiables $DominiosKMSConfiables

    Write-Host '   Generando informe...' -ForegroundColor DarkGray
    $base = 'Auditoria_{0}_{1}' -f $datos.Equipo.Nombre, (Get-Date).ToString('yyyyMMdd_HHmmss')

    # El Escritorio va primero: el informe queda a la vista en el equipo del
    # cliente, no escondido en el USB. -RutaSalida lo sobreescribe cuando se pasa
    # a proposito (tarea programada, lote de equipos). La carpeta del ejecutable y
    # %TEMP% quedan como respaldo si el Escritorio no acepta escritura.
    $destinos = @($Salida, [Environment]::GetFolderPath('Desktop'), $script:CarpetaBase, $env:TEMP)

    $html = ConvertTo-InformeHtml -Datos $datos
    $json = $datos | ConvertTo-Json -Depth 8

    $rutaHtml = Save-Salida -Nombre ($base + '.html') -Contenido $html -Destinos $destinos
    $rutaJson = Save-Salida -Nombre ($base + '.json') -Contenido $json -Destinos $destinos

    # Resumen en consola
    $colWin = if ($datos.Windows.Original) { 'Green' } else { 'Red' }
    $colOff = if ($datos.Office.Original) { 'Green' } elseif ($null -eq $datos.Office.Original) { 'Gray' } else { 'Red' }
    $colCat = switch ($datos.Clasificacion.Nivel) { 'ok' { 'Green' } 'aviso' { 'Yellow' } default { 'Red' } }

    Write-Host ''
    Show-Sep
    Write-Host '   Windows  : ' -NoNewline; Write-Host $datos.Windows.Veredicto -ForegroundColor $colWin
    Write-Host '   Office   : ' -NoNewline; Write-Host $datos.Office.Veredicto -ForegroundColor $colOff
    Write-Host '   CATEGORIA: ' -NoNewline
    Write-Host ($datos.Clasificacion.Codigo + ' - ' + $datos.Clasificacion.Texto) -ForegroundColor $colCat
    if ($datos.Indicadores.Count -gt 0) {
        Write-Host ('   Activadores piratas detectados: ' + $datos.Indicadores.Count) -ForegroundColor Red
    }
    Show-Sep
    Write-Host ''

    if ($rutaHtml) { Write-Host ('   [OK] Informe : ' + $rutaHtml) -ForegroundColor Green }
    else           { Write-Host '   [X] No se pudo guardar el informe HTML.' -ForegroundColor Red }
    if ($rutaJson) { Write-Host ('   [OK] Datos   : ' + $rutaJson) -ForegroundColor DarkGray }

    if ($rutaHtml -and -not $NoPausar) {
        Write-Host ''
        Write-Host '   Abriendo el informe en el navegador...' -ForegroundColor DarkGray
        try { Start-Process $rutaHtml | Out-Null } catch {
            Write-Host '   [i] Abrelo a mano desde la ruta de arriba.' -ForegroundColor Yellow
        }
    }

    if (-not $NoPausar) { Pause-Key }
    return $datos
}
