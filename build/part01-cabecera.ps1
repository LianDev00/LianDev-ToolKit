<#
    SOPORTE TI - LianDev
    Herramienta portable de soporte tecnico. Dos modulos en un solo archivo:

      1. Catalogo de comandos  - referencia rapida navegable, con copiar y ejecutar.
      2. Auditoria de equipo   - hardware, licencia de Windows y Office, deteccion
                                 de activadores piratas, clasificacion A/B/C e
                                 informe HTML + JSON autorrellenados.

    Uso:  doble clic en "Soporte TI - LianDev.exe"   (portable, sin instalacion)
          o  powershell -NoProfile -ExecutionPolicy Bypass -File .\SoporteTI-LianDev.ps1

    Desatendido (sin menu, solo auditoria):
          .\"Soporte TI - LianDev.exe" -Auditoria -SinPausa -RutaSalida C:\Informes

    Plantilla del informe:
          La plantilla HTML viaja embebida en este archivo. Si colocas un
          "plantilla.html" junto al script/exe, esa gana y no hace falta recompilar.

    Lista blanca de KMS:
          Un "kms_confiables.txt" junto al script/exe (un servidor por linea)
          marca los KMS legitimos de la organizacion auditada.

    Para regenerar el .exe:
          Install-Module ps2exe -Scope CurrentUser
          .\build.ps1
#>
[CmdletBinding()]
param(
    [switch]$Auditoria,
    [string]$RutaSalida = '',
    [string[]]$DominiosKMSConfiables = @(),
    [switch]$SinPausa
)

try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}
$ErrorActionPreference = 'Continue'

# ==========================================================================
#  MARCA Y CONFIGURACION
# ==========================================================================

$script:Marca   = 'Soporte TI - LianDev'
$script:Version = '2.0.0'
$script:W       = 78

# Carpeta del script o del .exe. Compilado con ps2exe, $PSScriptRoot viene
# vacio, de ahi los dos respaldos.
function Get-CarpetaBase {
    if ($PSScriptRoot) { return $PSScriptRoot }
    try {
        $b = [System.AppDomain]::CurrentDomain.BaseDirectory
        if ($b) { return $b.TrimEnd('\') }
    } catch {}
    return (Get-Location).Path
}

$script:CarpetaBase = Get-CarpetaBase
