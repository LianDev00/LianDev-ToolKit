<#
    Prueba el motor de plantilla sin tocar el equipo: carga las funciones del
    script ensamblado (sin su bloque de arranque) y le pasa datos sinteticos
    que cubren los caminos vacios y el escapado de HTML.
#>
$ErrorActionPreference = 'Stop'
$raiz = Split-Path $PSScriptRoot -Parent
$ps1  = Join-Path $raiz 'src\SoporteTI-LianDev.ps1'

# Cargar todo menos el arranque (que abriria el menu)
$texto = Get-Content $ps1 -Raw -Encoding UTF8
$corte = $texto.IndexOf('#  ARRANQUE')
if ($corte -lt 0) { throw 'No se encontro el bloque ARRANQUE' }
$corte = $texto.LastIndexOf('# ====', $corte)
Invoke-Expression $texto.Substring(0, $corte)

$script:CarpetaBase = Join-Path $env:TEMP 'liandev-test'
New-Item -ItemType Directory -Force $script:CarpetaBase | Out-Null
Remove-Item (Join-Path $script:CarpetaBase 'plantilla.html') -ErrorAction SilentlyContinue

$fallos = 0
function Check {
    param([string]$Nombre, [bool]$Ok, [string]$Detalle = '')
    if ($Ok) { Write-Host "  [OK] $Nombre" -ForegroundColor Green }
    else { Write-Host "  [X]  $Nombre  $Detalle" -ForegroundColor Red; $script:fallos++ }
}

# ==========================================================================
Write-Host "`nCASO 1: equipo limpio, Office no instalado, sin KMS, sin activadores" -ForegroundColor Cyan

$d1 = [ordered]@{
    Meta = [ordered]@{ Marca = 'Soporte TI - LianDev'; Version = '2.0.0'; Fecha = '06/10/2026 19:30:00'
                       ComoAdmin = $true; ComoAdminTexto = 'Si' }
    Clasificacion = [ordered]@{ Codigo = 'A'; Texto = 'Windows ORIGINAL (Office no instalado)'; Nivel = 'ok' }
    Equipo = [ordered]@{
        Nombre = 'PC-PRUEBA'; Fabricante = 'Dell Inc.'; Modelo = 'OptiPlex 3080'; Usuario = 'tecnico'
        EnDominio = $false; Dominio = 'WORKGROUP'; Red = 'Grupo de trabajo: WORKGROUP (sin dominio)'
        PlacaMadre = 'Dell 0K240Y'
        Bios = [ordered]@{ Fabricante = 'Dell Inc.'; Version = '2.9.0'; Serie = 'ABC123' }
        Cpu = @([ordered]@{ Nombre = 'Intel Core i5-10500'; Nucleos = 6; Hilos = 12 })
        RamTotalGB = 16; Modulos = @([ordered]@{ CapacidadGB = 16; VelocidadMHz = 2666; Fabricante = 'Hynix' })
        Discos = @([ordered]@{ Modelo = 'SK hynix BC511'; TamanoGB = 238.5; Interfaz = 'SCSI' })
        Video = @('Intel UHD Graphics 630'); IPs = @('192.168.1.40')
        SO = [ordered]@{ Caption = 'Microsoft Windows 11 Pro'; Arquitectura = '64 bits'; Version = '10.0.26100'
                         Build = '26100'; Instalado = '01/02/2026 10:00:00' }
    }
    Windows = [ordered]@{
        Encontrada = $true; Edicion = 'Windows(R), Professional edition'
        Descripcion = 'Windows(R) Operating System, OEM_DM channel'; Canal = 'OEM:DM'
        Ultimos5 = 'QWERT'; Estado = 'Con licencia (activado)'; GraciaDias = $null
        ClaveOEM = [ordered]@{ Existe = $true; Coincide = $true; Texto = 'Coincide con la clave instalada (licencia de fabrica).' }
        Nota = ''; Original = $true; Veredicto = 'ORIGINAL'
        ServidoresKMS = @(); Motivos = @('Activacion valida sin indicadores de pirateria detectables.')
        SalidaCruda = ''
    }
    Office = [ordered]@{
        Instalado = $false; Original = $null; Veredicto = 'NO INSTALADO'
        ProductosInstalados = @(); Licencias = @(); ServidoresKMS = @()
        Motivos = @('Microsoft Office no esta instalado en este equipo.'); SalidaCruda = ''
    }
    Indicadores = @()
    Limitaciones = @('Esta evaluacion es tecnica y local.', 'Confirmar la factura con el proveedor.')
}

$h1 = ConvertTo-InformeHtml -Datos $d1
Check 'no quedan tokens sin resolver' (-not ($h1 -match '\{\{'))
Check 'clase de nivel aplicada'       ($h1 -match 'veredicto gutter n-ok')
Check 'letra de categoria'            ($h1 -match '<div class="cat">A</div>')
Check 'rama "sin activadores"'        ($h1 -match 'No se detectaron activadores piratas')
Check 'rama "Office no instalado"'    ($h1 -match 'Microsoft Office no est(&#225;|\u00e1) instalado')
Check 'tabla de KMS omitida'          (-not ($h1 -match 'Servidor KMS'))
Check 'details de slmgr omitido'      (-not ($h1 -match 'slmgr /dli'))
Check 'hardware presente'             (($h1 -match 'OptiPlex 3080') -and ($h1 -match 'SK hynix BC511'))
Check 'sello verde en Windows'        ($h1 -match 'sello s-ok')

# ==========================================================================
Write-Host "`nCASO 2: categoria C, activadores, KMS no confiable, 2 licencias Office" -ForegroundColor Cyan

$d2 = [ordered]@{
    Meta = [ordered]@{ Marca = 'Soporte TI - LianDev'; Version = '2.0.0'; Fecha = '06/10/2026 19:31:00'
                       ComoAdmin = $false; ComoAdminTexto = 'No - algunos datos pueden estar incompletos' }
    Clasificacion = [ordered]@{ Codigo = 'C'; Texto = 'Windows y Office NO originales (PIRATAS)'; Nivel = 'alerta' }
    Equipo = $d1.Equipo
    Windows = [ordered]@{
        Encontrada = $true; Edicion = 'Windows(R), Professional edition'
        Descripcion = 'Windows(R) Operating System, VOLUME_KMSCLIENT channel'; Canal = 'GVLK'
        Ultimos5 = '3V66T'; Estado = 'Con licencia (activado)'; GraciaDias = 180
        ClaveOEM = [ordered]@{ Existe = $true; Coincide = $false; Texto = 'Existe, pero NO coincide con la clave instalada.' }
        Nota = 'Canal MAK: confirmar con el proveedor.'; Original = $false
        Veredicto = 'NO ORIGINAL (posible pirata)'
        ServidoresKMS = @(
            [ordered]@{ Host = 'kms8.msguides.com:1688'; Fuente = 'override en el registro'; Confiable = $false; Motivo = 'Servidor KMS PUBLICO de internet.' },
            [ordered]@{ Host = 'kms.corp.local'; Fuente = 'KMS registrado'; Confiable = $true; Motivo = 'Servidor interno de la red corporativa.' }
        )
        Motivos = @('KMS no confiable: kms8.msguides.com:1688', 'Indicador de activador pirata: AAct_x64.exe')
        SalidaCruda = "Nombre: Windows(R), Professional edition`nEstado de la licencia: con licencia"
    }
    Office = [ordered]@{
        Instalado = $true; Original = $false; Veredicto = 'NO ORIGINAL (posible pirata)'
        ProductosInstalados = @('Microsoft Office Profesional Plus 2019 - es-es')
        Licencias = @(
            [ordered]@{ Nombre = 'Office19ProPlus2019R_Retail'; Canal = 'RETAIL'; Estado = 'NOTIFICATIONS'; Ultimos5 = 'MY7PY'; Nota = ''; Activada = $false },
            [ordered]@{ Nombre = 'Office19VisioPro2019R_Retail'; Canal = 'MAK'; Estado = 'LICENSED'; Ultimos5 = '7XP79'; Nota = 'Canal MAK (volumen).'; Activada = $true }
        )
        ServidoresKMS = @([ordered]@{ Host = '127.0.0.1'; Fuente = 'override en el registro (Office)'; Confiable = $false; Motivo = 'Apunta a ESTE MISMO equipo.' })
        Motivos = @('Office NO esta activado correctamente (estado: NOTIFICATIONS).')
        SalidaCruda = 'LICENSE STATUS: ---NOTIFICATIONS---'
    }
    # el <script> y el & prueban el escapado; la ruta sale de una exclusion real de Defender
    Indicadores = @(
        'Exclusion de Windows Defender sospechosa: C:\Soft\OFFICE 21\AAct_x64.exe',
        'Prueba de escapado: <script>alert(1)</script> & "comillas"'
    )
    Limitaciones = $d1.Limitaciones
}

$h2 = ConvertTo-InformeHtml -Datos $d2
Check 'no quedan tokens sin resolver'   (-not ($h2 -match '\{\{'))
Check 'nivel alerta'                    ($h2 -match 'veredicto gutter n-alerta')
Check 'letra C'                         ($h2 -match '<div class="cat">C</div>')
Check 'los 2 indicadores salen'         ((([regex]::Matches($h2, '<li class="mono">')).Count) -eq 2)
Check 'HTML escapado, no inyectado'     (($h2 -match '&lt;script&gt;') -and -not ($h2 -match '<script>alert'))
Check 'ampersand escapado'              ($h2 -match '&amp; &quot;comillas&quot;')
Check '2 tablas de KMS (Windows+Office)' ((([regex]::Matches($h2, 'Servidor KMS</th>')).Count) -eq 2)
Check 'KMS confiable y no confiable'    (($h2 -match 'pill p-ok">confiable') -and ($h2 -match 'pill p-mal">no confiable'))
Check 'gracia restante visible'         ($h2 -match '180 d')
Check 'nota MAK de Windows'             ($h2 -match 'Canal MAK: confirmar con el proveedor')
Check '2 licencias de Office'           ((([regex]::Matches($h2, 'Office19')).Count) -eq 2)
Check 'estado LICENSED en verde'        ($h2 -match 'pill p-ok">LICENSED')
Check 'estado NOTIFICATIONS en rojo'    ($h2 -match 'pill p-mal">NOTIFICATIONS')
Check 'nota por licencia'               ($h2 -match 'Canal MAK \(volumen\)')
Check 'details de slmgr presente'       ($h2 -match 'slmgr /dli')
Check 'details de ospp presente'        ($h2 -match 'ospp.vbs /dstatus')
Check 'aviso de sin privilegios'        ($h2 -match 'algunos datos pueden estar incompletos')

# ==========================================================================
Write-Host "`nCASO 3: plantilla externa gana sobre la embebida" -ForegroundColor Cyan

$ext = Join-Path $script:CarpetaBase 'plantilla.html'
Set-Content -Path $ext -Value 'EXTERNA: {{Equipo.Nombre}} / {{Clasificacion.Codigo}}' -Encoding UTF8
$h3 = ConvertTo-InformeHtml -Datos $d1
Check 'usa la plantilla externa' ($h3 -match 'EXTERNA: PC-PRUEBA / A')
Remove-Item $ext -Force
$h4 = ConvertTo-InformeHtml -Datos $d1
Check 'vuelve a la embebida al quitarla' ($h4 -match '<!DOCTYPE html>')

# ==========================================================================
Write-Host "`nCASO 4: JSON del inventario" -ForegroundColor Cyan
$j = $d2 | ConvertTo-Json -Depth 8
$r = $j | ConvertFrom-Json
Check 'JSON ida y vuelta'        ($r.Clasificacion.Codigo -eq 'C')
Check 'anidado profundo intacto' ($r.Windows.ServidoresKMS[0].Host -eq 'kms8.msguides.com:1688')
Check 'arrays preservados'       ($r.Office.Licencias.Count -eq 2)

# ==========================================================================
Write-Host ''
if ($fallos -eq 0) {
    Write-Host 'TODAS LAS PRUEBAS PASARON' -ForegroundColor Green
    $muestra = Join-Path $script:CarpetaBase 'muestra-C.html'
    [System.IO.File]::WriteAllText($muestra, $h2, (New-Object System.Text.UTF8Encoding $true))
    Write-Host ("Muestra para revisar a ojo: $muestra") -ForegroundColor DarkGray
} else {
    Write-Host "$fallos PRUEBA(S) FALLARON" -ForegroundColor Red
    exit 1
}
