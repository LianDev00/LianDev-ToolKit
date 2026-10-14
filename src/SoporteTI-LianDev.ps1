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

# ==========================================================================
#  DATOS
# ==========================================================================

function NewC {
    param(
        [string]$Cat, [string]$Cmd, [string]$Que, [string]$Cuando,
        [string]$Plat = 'CMD', [switch]$Admin, [string]$Riesgo = 'ok',
        [string]$Run = '@', [string]$Nota = '', [string]$Copy = '@', [switch]$Eleva
    )
    if ($Run -eq '@') { $Run = $Cmd }
    if ($Copy -eq '@') { $Copy = if ($Run) { $Run } else { $Cmd } }
    [pscustomobject]@{
        Cat = $Cat; Cmd = $Cmd; Que = $Que; Cuando = $Cuando; Plat = $Plat
        Admin = [bool]$Admin; Riesgo = $Riesgo; Run = $Run; Nota = $Nota; Copy = $Copy; Eleva = [bool]$Eleva
    }
}

$script:Cats = [ordered]@{
    'red'   = @{ N = 'Red y conectividad';            S = 'Windows - CMD' }
    'diag'  = @{ N = 'Diagnóstico e inventario';      S = 'Windows - PowerShell' }
    'mant'  = @{ N = 'Mantenimiento y reparación';    S = 'Windows - CMD admin' }
    'hora'  = @{ N = 'Fecha y hora';                  S = 'Windows y Linux' }
    'srv'   = @{ N = 'Servidor: estado y servicios';  S = 'Linux - PuTTY/SSH' }
    'disco' = @{ N = 'Servidor: espacio en disco';    S = 'Linux - PuTTY/SSH' }
    'web'   = @{ N = 'Servidor: web, SSL y respaldo'; S = 'Linux - PuTTY/SSH' }
    'ext'   = @{ N = 'Herramientas y licencias';      S = 'Windows - admin' }
}

$script:Cmds = @(
    # ---------- 1. Red y conectividad (CMD) ----------
    (NewC -Cat red -Cmd 'ipconfig' -Plat CMD `
        -Que 'Muestra la IP actual del equipo.' `
        -Cuando 'Ver rápido qué dirección IP tiene una PC.')
    (NewC -Cat red -Cmd 'ipconfig /all' -Plat CMD `
        -Que 'Muestra IP, puerta de enlace, DNS y MAC.' `
        -Cuando 'Primer paso cuando una PC "no tiene internet": ver si tiene IP válida o una 169.254.x.x (no tomó DHCP).')
    (NewC -Cat red -Cmd 'ipconfig /release  +  ipconfig /renew' -Plat CMD -Riesgo cuidado -Run 'ipconfig /release & ipconfig /renew' `
        -Que 'Suelta la IP y pide una nueva al DHCP.' `
        -Cuando 'Cuando la PC quedó con IP 169.254.x.x o sin dirección, para que el router le entregue una buena.' `
        -Nota 'Corta la red unos segundos: no lo uses en una PC que esté en medio de una atención.')
    (NewC -Cat red -Cmd 'ipconfig /flushdns' -Plat CMD `
        -Que 'Limpia la caché de DNS.' `
        -Cuando 'Cuando una página no abre pero otras sí, o después de un cambio de DNS.')
    (NewC -Cat red -Cmd 'ping 8.8.8.8' -Plat CMD `
        -Que 'Prueba si hay internet sin depender del DNS.' `
        -Cuando 'Saber si el problema es de conexión o de DNS.')
    (NewC -Cat red -Cmd 'ping <gateway>' -Plat CMD `
        -Que 'Prueba si la PC llega al router.' `
        -Cuando 'Confirmar que la red local funciona antes de mirar más allá.' `
        -Nota 'El gateway lo sacas de "ipconfig" (Puerta de enlace predeterminada).')
    (NewC -Cat red -Cmd 'ping google.com' -Plat CMD `
        -Que 'Prueba si el DNS resuelve nombres.' `
        -Cuando 'Si 8.8.8.8 responde pero el nombre no, el problema es DNS.')
    (NewC -Cat red -Cmd 'ping -n 50 <destino>' -Plat CMD `
        -Que 'Hace 50 pings seguidos para medir estabilidad.' `
        -Cuando 'Cuando un sistema web va lento y quieres medir pérdida de paquetes y latencia (p. ej. un sistema web que responde lento).')
    (NewC -Cat red -Cmd 'tracert <destino>' -Plat CMD `
        -Que 'Muestra la ruta hasta un servidor y dónde se corta.' `
        -Cuando 'Ver en qué punto del camino se pierde la conexión.')
    (NewC -Cat red -Cmd 'nslookup <dominio>' -Plat CMD `
        -Que 'Consulta a qué IP resuelve un dominio.' `
        -Cuando 'Verificar DNS o averiguar el servidor de un sistema web.')
    (NewC -Cat red -Cmd 'nslookup -type=NS <dominio>' -Plat CMD `
        -Que 'Muestra los servidores DNS (name servers) del dominio.' `
        -Cuando 'Saber dónde se administra el DNS del dominio del cliente.')
    (NewC -Cat red -Cmd 'arp -a' -Plat CMD `
        -Que 'Lista los equipos con los que la PC ha hablado (IP + MAC).' `
        -Cuando 'Chequeo rápido para ver si un equipo está presente en la red.')
    (NewC -Cat red -Cmd 'type C:\Windows\System32\drivers\etc\hosts' -Plat CMD `
        -Que 'Muestra el archivo hosts.' `
        -Cuando 'Cuando "un sitio sí abre y otro no": ver si hay un dominio bloqueado o redirigido a otra IP.')
    (NewC -Cat red -Cmd 'sc query <servicio>' -Plat CMD `
        -Que 'Muestra si un servicio de Windows está corriendo.' `
        -Cuando 'Verificar servicios como AnyDesk (STATE: RUNNING o detenido).')

    # ---------- 2. Diagnostico e inventario (PowerShell) ----------
    (NewC -Cat diag -Cmd 'Get-CimInstance Win32_OperatingSystem' -Plat PS `
        -Que 'Datos del SO: edición, versión, build, arquitectura.' `
        -Cuando 'Inventario de máquinas / saber qué Windows tiene un equipo.')
    (NewC -Cat diag -Cmd 'Get-CimInstance Win32_ComputerSystem' -Plat PS `
        -Que 'Fabricante, modelo, RAM y nombre del equipo.' `
        -Cuando 'Inventario de hardware.')
    (NewC -Cat diag -Cmd '(Get-CimInstance SoftwareLicensingService).OA3xOriginalProductKey' -Plat PS `
        -Que 'Muestra la clave OEM de Windows guardada en el firmware.' `
        -Cuando 'Saber si una PC tiene licencia original (proyecto de licencias / INDECOPI).')
    (NewC -Cat diag -Cmd 'cscript ospp.vbs /dstatus' -Plat CMD -Run '' `
        -Que 'Muestra el estado de licencia de Office.' `
        -Cuando 'Detectar activaciones pirata (KMS) de Office.' `
        -Nota 'Primero ubícate en la carpeta de Office, por ejemplo: cd "C:\Program Files\Microsoft Office\Office16"')
    (NewC -Cat diag -Cmd 'Get-NetIPConfiguration' -Plat PS `
        -Que 'Config de red (IP, gateway) de los adaptadores activos.' `
        -Cuando 'Diagnóstico rápido de red desde PowerShell.')
    (NewC -Cat diag -Cmd 'Get-NetAdapterStatistics' -Plat PS `
        -Que 'Bytes recibidos y enviados por el adaptador.' `
        -Cuando 'Medir el consumo de red de una PC.')
    (NewC -Cat diag -Cmd 'Get-PnpDevice' -Plat PS `
        -Que 'Lista dispositivos y drivers, marcando los que fallan.' `
        -Cuando 'Detectar drivers con problemas.' `
        -Nota 'Para ver solo los que fallan: Get-PnpDevice | Where-Object Status -ne "OK"')
    (NewC -Cat diag -Cmd 'Test-Connection <destino>' -Plat PS `
        -Que 'Ping desde PowerShell (útil dentro de scripts).' `
        -Cuando 'Chequeos automáticos de conectividad.')

    # ---------- 3. Mantenimiento y reparacion (CMD admin) ----------
    (NewC -Cat mant -Cmd 'sfc /scannow' -Plat CMD -Admin -Riesgo cuidado `
        -Que 'Verifica y repara los archivos de sistema de Windows dañados.' `
        -Cuando 'Cuando Windows falla raro, se cierra solo o aparecen errores del sistema. CMD como administrador.')
    (NewC -Cat mant -Cmd 'DISM /Online /Cleanup-Image /RestoreHealth' -Plat CMD -Admin -Riesgo cuidado `
        -Que 'Repara la imagen base de Windows (el respaldo interno que usa sfc).' `
        -Cuando 'Si sfc /scannow no logra reparar: se corre este primero y luego sfc otra vez.' `
        -Nota 'Puede tardar 15-30 minutos y necesita internet.')
    (NewC -Cat mant -Cmd 'DISM /Online /Cleanup-Image /CheckHealth' -Plat CMD -Admin `
        -Que 'Chequeo rápido: indica si la imagen está marcada como dañada.' `
        -Cuando 'Verificación previa antes de lanzar la reparación completa.')
    (NewC -Cat mant -Cmd 'chkdsk C: /f /r' -Plat CMD -Admin -Riesgo cuidado `
        -Que 'Revisa el disco y repara errores lógicos y sectores dañados.' `
        -Cuando 'Cuando una PC se cuelga, no arranca bien o el disco da problemas. Pide reiniciar para ejecutarse.' `
        -Nota 'Programa el chequeo para el próximo arranque y puede tardar horas. Avisa al usuario antes.')
    (NewC -Cat mant -Cmd 'cleanmgr' -Plat CMD `
        -Que 'Abre el Liberador de espacio de Windows.' `
        -Cuando 'Liberar espacio borrando temporales y restos de actualizaciones.')

    # ---------- 4. Fecha y hora ----------
    (NewC -Cat hora -Cmd 'date /t  |  time /t' -Plat CMD -Run 'date /t & time /t' `
        -Que 'Muestran la fecha y la hora del equipo (Windows).' `
        -Cuando 'Chequeo rápido de que la PC tiene la fecha y hora correctas.')
    (NewC -Cat hora -Cmd 'w32tm /query /status' -Plat CMD `
        -Que 'Estado del servicio de hora de Windows y con qué se sincroniza.' `
        -Cuando 'Cuando la hora se desajusta sola o de forma repetida.')
    (NewC -Cat hora -Cmd 'w32tm /resync' -Plat CMD -Admin `
        -Que 'Fuerza la sincronización de la hora con el servidor de tiempo.' `
        -Cuando 'Corregir una PC con la hora mal. CMD como administrador.')
    (NewC -Cat hora -Cmd 'timedatectl' -Plat SSH `
        -Que 'Muestra fecha, hora, zona horaria y estado de NTP (Linux).' `
        -Cuando 'Verificar la hora del servidor por SSH.')
    (NewC -Cat hora -Cmd 'date' -Plat SSH `
        -Que 'Muestra la fecha y hora del servidor (Linux).' `
        -Cuando 'Chequeo rápido de la hora en el servidor.')

    # ---------- 5. Servidor Linux: estado y servicios ----------
    (NewC -Cat srv -Cmd 'hostnamectl' -Plat SSH `
        -Que 'Nombre, SO, versión y tipo de máquina.' `
        -Cuando 'Primer comando al entrar a un servidor que no conoces.')
    (NewC -Cat srv -Cmd 'uptime' -Plat SSH `
        -Que 'Cuánto lleva encendido y la carga actual.' `
        -Cuando 'Ver si el servidor se reinició o está sobrecargado.')
    (NewC -Cat srv -Cmd 'free -h' -Plat SSH `
        -Que 'Memoria RAM usada y libre.' `
        -Cuando 'Descartar la falta de memoria como causa de una caída.')
    (NewC -Cat srv -Cmd 'df -h' -Plat SSH `
        -Que 'Espacio usado y libre por disco.' `
        -Cuando 'Sospecha número 1 cuando un servicio deja de responder: disco lleno.')
    (NewC -Cat srv -Cmd 'nproc' -Plat SSH `
        -Que 'Número de núcleos de CPU.' `
        -Cuando 'Conocer la capacidad de la máquina.')
    (NewC -Cat srv -Cmd 'ss -tlnp' -Plat SSH `
        -Que 'Qué está escuchando y en qué puertos.' `
        -Cuando '"¿Para qué sirve esta máquina?": ver si sirve web, base de datos, SSH, etc.')
    (NewC -Cat srv -Cmd 'systemctl list-units --type=service --state=running' -Plat SSH `
        -Que 'Lista los servicios activos.' `
        -Cuando 'Ver todo lo que está corriendo en el servidor.')
    (NewC -Cat srv -Cmd 'sudo systemctl status tomcat' -Plat SSH `
        -Que 'Estado del servicio: activo, caído y desde cuándo.' `
        -Cuando 'Cuando el sistema antiguo (SMedicO) no carga.')
    (NewC -Cat srv -Cmd 'sudo systemctl restart tomcat' -Plat SSH -Riesgo cuidado `
        -Que 'Reinicia el servicio.' `
        -Cuando 'Levantar Tomcat cuando se colgó y las apps no cargan.' `
        -Nota 'Corta el servicio a todos los usuarios unos segundos. Avisa antes.')
    (NewC -Cat srv -Cmd 'sudo tail -n 100 /opt/tomcat/logs/catalina.out' -Plat SSH `
        -Que 'Muestra las últimas líneas del log de Tomcat.' `
        -Cuando 'Ver por qué se cayó el servicio.' `
        -Nota 'Ojo: la ruta correcta es /opt/tomcat/logs, no /var/log/tomcat.')
    (NewC -Cat srv -Cmd 'sudo journalctl -k | grep -iE "oom|killed"' -Plat SSH `
        -Que 'Busca si el sistema mató un proceso por falta de memoria.' `
        -Cuando 'Descartar que el "OOM killer" tumbó Tomcat.')
    (NewC -Cat srv -Cmd 'curl -I http://localhost:<puerto>/...' -Plat SSH `
        -Que 'Prueba si Tomcat responde localmente.' `
        -Cuando 'Separar si el problema es del servidor o de la red/router.')

    # ---------- 6. Servidor Linux: espacio en disco ----------
    (NewC -Cat disco -Cmd 'df -hT' -Plat SSH `
        -Que 'Uso por partición, con el tipo de sistema de archivos.' `
        -Cuando 'Panorama general del espacio.')
    (NewC -Cat disco -Cmd 'sudo du -h --max-depth=1 / | sort -rh | head' -Plat SSH `
        -Que 'Ordena las carpetas raíz de mayor a menor peso.' `
        -Cuando 'Encontrar qué carpeta se está comiendo el disco.')
    (NewC -Cat disco -Cmd 'sudo find / -xdev -type f -size +500M -exec du -h {} + | sort -rh' -Plat SSH `
        -Que 'Caza archivos sueltos de más de 500 MB.' `
        -Cuando 'Ubicar los "elefantes" (dumps viejos, logs gigantes) para liberar espacio.')
    (NewC -Cat disco -Cmd 'journalctl --disk-usage' -Plat SSH `
        -Que 'Cuánto ocupan los logs de systemd.' `
        -Cuando 'Los logs binarios suelen crecer sin control.')
    (NewC -Cat disco -Cmd 'sudo ncdu -x /' -Plat SSH `
        -Que 'Explorador visual de disco en la terminal.' `
        -Cuando 'Forma cómoda de entender un disco que no conoces.' `
        -Nota 'Instalar con: sudo dnf install ncdu')

    # ---------- 7. Servidor Linux: web, certificados y respaldo ----------
    (NewC -Cat web -Cmd 'sudo nginx -t' -Plat SSH `
        -Que 'Valida la configuración de nginx.' `
        -Cuando 'Antes de recargar nginx, para no romper el servicio.')
    (NewC -Cat web -Cmd 'sudo certbot certificates' -Plat SSH `
        -Que 'Lista los certificados SSL y sus vencimientos.' `
        -Cuando 'Revisar qué certificados están por vencer o vencidos.')
    (NewC -Cat web -Cmd 'sudo certbot certonly --nginx -d <dominio>' -Plat SSH -Riesgo cuidado `
        -Que 'Renueva o emite un certificado usando nginx.' `
        -Cuando 'Arreglar un certificado vencido o mal configurado (pasar de standalone a nginx).')
    (NewC -Cat web -Cmd 'curl -4 -s ifconfig.me' -Plat SSH `
        -Que 'Muestra la IP pública actual del servidor.' `
        -Cuando 'Cuando las URLs por IP dejan de abrir porque el proveedor (Claro/Movistar) cambió la IP pública.')

    # ---------- 8. Herramientas y licencias (Windows) ----------
    (NewC -Cat ext -Cmd 'irm christitus.com/win | iex' -Plat PS -Admin -Eleva -Riesgo cuidado `
        -Run 'Start-WinUtil' -Copy 'irm christitus.com/win | iex' `
        -Que 'Abre WinUtil (Chris Titus): quitar bloatware, ajustar servicios, tweaks y actualizaciones.' `
        -Cuando 'Al preparar una PC nueva o depurar una lenta, para dejarla limpia desde una sola ventana.' `
        -Nota 'Con E se abre en una consola nueva como administrador (aparece el aviso de UAC). Descarga y ejecuta un script de internet: úsalo solo con autorización del área y revisa cada cambio antes de aplicarlo.')
    (NewC -Cat ext -Cmd 'slmgr /dlv' -Plat CMD `
        -Que 'Detalle de la licencia de Windows: edición, canal (OEM/Retail/KMS) y estado.' `
        -Cuando 'Saber cómo está activado un equipo antes de tocar nada.' `
        -Nota 'Abre una ventana emergente de Windows Script Host; ciérrala para continuar.')
    (NewC -Cat ext -Cmd 'slmgr /ipk <clave>' -Plat CMD -Admin -Riesgo cuidado `
        -Que 'Instala una clave de producto de Windows.' `
        -Cuando 'Poner la clave legítima comprada, o la OEM del firmware, cuando el equipo quedó sin activar.' `
        -Nota 'Reemplaza la clave actual. Ten a la mano la clave OEM (categoría Diagnóstico) antes de cambiarla.')
    (NewC -Cat ext -Cmd 'slmgr /ato' -Plat CMD -Admin `
        -Que 'Activa Windows contra los servidores de Microsoft.' `
        -Cuando 'Después de instalar la clave con /ipk, o cuando dice no activado pero la clave es la correcta.' `
        -Nota 'Necesita internet.')
    (NewC -Cat ext -Cmd 'cscript ospp.vbs /inpkey:<clave>  +  /act' -Plat CMD -Admin -Riesgo cuidado -Run '' `
        -Que 'Instala la clave de Office y lo activa con Microsoft.' `
        -Cuando 'Regularizar un Office que aparece con activación KMS pirata y que ya tiene licencia comprada.' `
        -Nota 'Primero ubícate en la carpeta de Office, por ejemplo: cd "C:\Program Files\Microsoft Office\Office16". Luego: cscript ospp.vbs /inpkey:XXXXX-XXXXX-XXXXX-XXXXX-XXXXX y después cscript ospp.vbs /act')

    # ==================================================================
    #   ESPACIO LIBRE - escribe aquí tu propio comando
    # ------------------------------------------------------------------
    #   Rellena lo que va entre las comillas ''. Mientras -Cmd esté
    #   vacío, la entrada no aparece en el menú.
    #     -Cmd      el comando tal cual (es lo que se muestra y se copia)
    #     -Plat     PS = PowerShell   |   CMD = símbolo del sistema
    #     -Que      qué hace, en una línea
    #     -Cuando   en qué situación se usa
    #     -Nota     advertencia o paso previo (opcional)
    #   Modificadores opcionales, se agregan en la primera línea:
    #     -Admin           lo marca como que necesita administrador
    #     -Eleva           al ejecutarlo abre solo una consola admin (UAC)
    #     -Riesgo cuidado  pide escribir SI antes de ejecutar
    #     -Run '<otro>'    lo que se ejecuta, si es distinto de -Cmd
    #     -Run ''          solo mostrar y copiar, nunca ejecutar
    #   Copia este bloque las veces que necesites. Ojo con el acento
    #   grave ` del final de cada línea: es el que une el bloque.
    # ==================================================================
    (NewC -Cat ext -Cmd '' -Plat PS `
        -Que '' `
        -Cuando '' `
        -Nota '')
)

# Las plantillas del espacio libre que sigan vacías no entran al menú.
$script:Cmds = @($script:Cmds | Where-Object { -not [string]::IsNullOrWhiteSpace($_.Cmd) })

$script:Tips = @(
    'Los valores entre < > (por ejemplo <dominio>, <destino>, <servicio>) se reemplazan por el dato real del caso.',
    'Los comandos con sudo y los del servidor se ejecutan por SSH (PuTTY); los de PowerShell, como administrador.',
    'Hora incorrecta = fallas tipicas: certificados SSL con error, los sistemas web rechazan el acceso y los respaldos programados quedan desalineados.',
    'Orden para "no tiene internet": ipconfig /all, ping al gateway, ping 8.8.8.8, ping google.com.',
    'Si sfc /scannow no repara, corre DISM /RestoreHealth y vuelve a pasar sfc.',
    'En el servidor, cuando un servicio muere: df -h (disco lleno) y free -h (memoria) antes que nada.'
)

# ==========================================================================
#  RENDER
# ==========================================================================

function Wrap {
    param([string]$Text, [int]$Width)
    $out = New-Object System.Collections.ArrayList
    $line = ''
    foreach ($word in ($Text -split '\s+')) {
        if ($word -eq '') { continue }
        if ($line.Length -eq 0) { $line = $word }
        elseif (($line.Length + 1 + $word.Length) -le $Width) { $line = "$line $word" }
        else { [void]$out.Add($line); $line = $word }
    }
    if ($line.Length -gt 0) { [void]$out.Add($line) }
    if ($out.Count -eq 0) { [void]$out.Add('') }
    , $out.ToArray()
}

function Cut {
    param([string]$T, [int]$N)
    if ($T.Length -le $N) { return $T }
    return $T.Substring(0, [Math]::Max(0, $N - 3)) + '...'
}

function Show-Header {
    param([string]$Title, [string]$Sub = '')
    # Clear-Host falla con "controlador no valido" cuando la salida esta
    # redirigida (tarea programada, WinRM, tuberia): no es motivo para abortar.
    try { Clear-Host } catch {}
    $inner = $script:W - 2
    Write-Host (' +' + ('-' * $inner) + '+') -ForegroundColor DarkCyan
    Write-Host ' | ' -NoNewline -ForegroundColor DarkCyan
    Write-Host ((Cut $Title ($inner - 2)).PadRight($inner - 1)) -NoNewline -ForegroundColor White
    Write-Host '|' -ForegroundColor DarkCyan
    Write-Host (' +' + ('-' * $inner) + '+') -ForegroundColor DarkCyan
    if ($Sub) { Write-Host ('   ' + $Sub) -ForegroundColor DarkGray }
    Write-Host ''
}

function Show-Sep { Write-Host ('   ' + ('-' * ($script:W - 4))) -ForegroundColor DarkGray }

function Show-Bar {
    param([string]$Text)
    Write-Host ''
    Show-Sep
    Write-Host ('   ' + $Text) -ForegroundColor DarkGray
}

function Get-Badge {
    param($Item)
    switch ($Item.Plat) {
        'CMD' { 'CMD' }
        'PS'  { 'PowerShell' }
        'SSH' { 'SSH/Linux' }
        default { [string]$Item.Plat }
    }
}

function Get-PlatColor {
    param($Item)
    switch ($Item.Plat) {
        'CMD' { [ConsoleColor]::Cyan }
        'PS'  { [ConsoleColor]::Blue }
        'SSH' { [ConsoleColor]::Green }
        default { [ConsoleColor]::Gray }
    }
}

function Read-Key { [Console]::ReadKey($true) }

function Pause-Key {
    param([string]$Msg = 'Presiona cualquier tecla para continuar...')
    Write-Host ''
    Write-Host ('   ' + $Msg) -ForegroundColor DarkGray
    [void](Read-Key)
}

function Test-Admin {
    try {
        $id = [Security.Principal.WindowsIdentity]::GetCurrent()
        return (New-Object Security.Principal.WindowsPrincipal $id).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    } catch { return $false }
}

# ==========================================================================
#  ACCIONES
# ==========================================================================

function Copy-Cmd {
    param($Item)
    $text = if ($Item.Copy) { $Item.Copy } elseif ($Item.Run) { $Item.Run } else { $Item.Cmd }
    $ok = $false
    try { Set-Clipboard -Value $text; $ok = $true } catch {
        try { $text | clip.exe; $ok = $true } catch { $ok = $false }
    }
    Write-Host ''
    if ($ok) { Write-Host '   [OK] Comando copiado al portapapeles.' -ForegroundColor Green }
    else { Write-Host '   [!] No se pudo copiar. Copialo a mano.' -ForegroundColor Red }
    Start-Sleep -Milliseconds 750
}

function Start-WinUtil {
    $cmd = 'irm christitus.com/win | iex'
    if (Test-Admin) {
        Write-Host ''
        Write-Host '   Descargando WinUtil (Chris Titus)...' -ForegroundColor DarkGray
        Invoke-Expression $cmd
        return
    }
    Write-Host ''
    Write-Host '   Se abrira WinUtil en una consola nueva como administrador.' -ForegroundColor Yellow
    Write-Host '   Acepta el aviso de Control de cuentas de usuario (UAC).' -ForegroundColor DarkGray
    try {
        $psArgs = '-NoProfile -ExecutionPolicy Bypass -Command "' + $cmd + '"'
        Start-Process -FilePath 'powershell.exe' -Verb RunAs -ArgumentList $psArgs | Out-Null
        Write-Host '   [OK] WinUtil se abre en la otra ventana.' -ForegroundColor Green
    } catch {
        Write-Host ('   [X] No se pudo elevar: ' + $_.Exception.Message) -ForegroundColor Red
        Write-Host '   Abre PowerShell como administrador y pega:  irm christitus.com/win | iex' -ForegroundColor DarkGray
    }
}

function Invoke-CmdItem {
    param($Item)

    if ($Item.Plat -eq 'SSH') {
        Write-Host ''
        Write-Host '   [i] Este comando corre en el servidor Linux (PuTTY / SSH).' -ForegroundColor Yellow
        Write-Host '       Usa "C" para copiarlo y pegalo en la sesion SSH.' -ForegroundColor DarkGray
        Pause-Key
        return
    }
    if (-not $Item.Run) {
        Write-Host ''
        Write-Host '   [i] Este comando necesita preparacion manual (revisa la NOTA).' -ForegroundColor Yellow
        Pause-Key
        return
    }

    $cmdText = $Item.Run
    $phs = @([regex]::Matches($cmdText, '<[^>]+>') | ForEach-Object { $_.Value } | Select-Object -Unique)
    if ($phs.Count -gt 0) {
        Write-Host ''
        Write-Host '   Completa los datos del comando:' -ForegroundColor White
        foreach ($p in $phs) {
            $v = Read-Host ('   ' + $p)
            if ([string]::IsNullOrWhiteSpace($v)) {
                Write-Host '   Cancelado.' -ForegroundColor DarkGray
                Start-Sleep -Milliseconds 700
                return
            }
            $cmdText = $cmdText.Replace($p, $v.Trim())
        }
    }

    if ($Item.Admin -and -not $Item.Eleva -and -not (Test-Admin)) {
        Write-Host ''
        Write-Host '   [!] Este comando requiere una consola COMO ADMINISTRADOR.' -ForegroundColor Yellow
        Write-Host '       Cierra esto, abre PowerShell con boton derecho >' -ForegroundColor DarkGray
        Write-Host '       "Ejecutar como administrador" y vuelve a lanzar la guia.' -ForegroundColor DarkGray
        Write-Host ''
        Write-Host '   Intentar de todos modos? (s/N): ' -NoNewline -ForegroundColor White
        $r = Read-Host
        if ($r -notmatch '^[sS]') { return }
    }

    if ($Item.Riesgo -eq 'cuidado') {
        Write-Host ''
        Write-Host '   *** COMANDO DELICADO ***' -ForegroundColor Red
        if ($Item.Nota) {
            foreach ($l in (Wrap $Item.Nota ($script:W - 10))) { Write-Host ('       ' + $l) -ForegroundColor Yellow }
        }
        Write-Host ''
        Write-Host '   Escribe SI (mayusculas) para ejecutar: ' -NoNewline -ForegroundColor White
        $r = Read-Host
        if ($r -ne 'SI') {
            Write-Host '   Cancelado.' -ForegroundColor DarkGray
            Start-Sleep -Milliseconds 700
            return
        }
    }

    Show-Header ('>  ' + $cmdText) 'Salida del comando'
    try {
        if ($Item.Plat -eq 'PS') { Invoke-Expression $cmdText | Out-Host }
        else { & cmd.exe /c $cmdText 2>&1 | Out-Host }
    } catch {
        Write-Host ('   [X] Error: ' + $_.Exception.Message) -ForegroundColor Red
    }
    Write-Host ''
    Show-Sep
    Pause-Key 'Fin de la salida. Presiona cualquier tecla para volver.'
}

# ==========================================================================
#  VISTA DETALLE
# ==========================================================================

function Show-Detail {
    param($Item)
    while ($true) {
        $catName = $script:Cats[$Item.Cat].N
        Show-Header ('$  ' + $Item.Cmd)

        Write-Host '   ' -NoNewline
        Write-Host (' ' + (Get-Badge $Item) + ' ') -NoNewline -ForegroundColor Black -BackgroundColor (Get-PlatColor $Item)
        Write-Host ('  ' + $catName) -NoNewline -ForegroundColor DarkGray
        if ($Item.Admin) { Write-Host '  - requiere administrador' -NoNewline -ForegroundColor Yellow }
        if ($Item.Eleva) { Write-Host '  - se eleva solo (UAC)' -NoNewline -ForegroundColor DarkYellow }
        if ($Item.Riesgo -eq 'cuidado') { Write-Host '  - delicado' -NoNewline -ForegroundColor Red }
        Write-Host ''
        Write-Host ''

        Write-Host '   QUE HACE' -ForegroundColor Cyan
        foreach ($l in (Wrap $Item.Que ($script:W - 8))) { Write-Host ('     ' + $l) -ForegroundColor Gray }
        Write-Host ''
        Write-Host '   CUANDO SE USA' -ForegroundColor Cyan
        foreach ($l in (Wrap $Item.Cuando ($script:W - 8))) { Write-Host ('     ' + $l) -ForegroundColor Gray }
        if ($Item.Nota) {
            Write-Host ''
            Write-Host '   NOTA' -ForegroundColor Yellow
            foreach ($l in (Wrap $Item.Nota ($script:W - 8))) { Write-Host ('     ' + $l) -ForegroundColor DarkYellow }
        }

        Show-Bar 'C copiar    E ejecutar    Esc / <- volver'
        $k = Read-Key
        $ch = ([string]$k.KeyChar).ToUpper()
        if ($k.Key -eq [ConsoleKey]::Escape -or $k.Key -eq [ConsoleKey]::LeftArrow -or $k.Key -eq [ConsoleKey]::Backspace) { return }
        elseif ($ch -eq 'C') { Copy-Cmd $Item }
        elseif ($ch -eq 'E') { Invoke-CmdItem $Item }
        elseif ($ch -eq 'Q') { return }
    }
}

# ==========================================================================
#  VISTA LISTA
# ==========================================================================

function Show-List {
    param([array]$Items, [string]$Title, [string]$Sub = '', [string]$Filter = '')

    $sel = 0
    while ($true) {
        $view = if ($Filter) {
            @($Items | Where-Object { ("$($_.Cmd) $($_.Que) $($_.Cuando) $($_.Nota)") -like "*$Filter*" })
        } else { @($Items) }

        if ($sel -ge $view.Count) { $sel = [Math]::Max(0, $view.Count - 1) }
        if ($sel -lt 0) { $sel = 0 }

        $rows = 14
        try { $rows = [Math]::Max(5, [Console]::WindowHeight - 14) } catch {}
        $top = 0
        if ($view.Count -gt $rows) {
            $top = [Math]::Max(0, [Math]::Min($sel - [int]($rows / 2), $view.Count - $rows))
        }

        Show-Header $Title $Sub
        if ($Filter) {
            Write-Host ('   Buscar: ' + $Filter + '_') -ForegroundColor Yellow
            Write-Host ''
        }
        if ($view.Count -eq 0) {
            Write-Host '   Sin resultados para esa busqueda. (Esc limpia el filtro)' -ForegroundColor DarkGray
        }

        for ($i = $top; $i -lt [Math]::Min($top + $rows, $view.Count); $i++) {
            $it = $view[$i]
            $isSel = ($i -eq $sel)
            if ($isSel) { $mark = ' > '; $fg = [ConsoleColor]::White } else { $mark = '   '; $fg = [ConsoleColor]::Gray }

            Write-Host $mark -NoNewline -ForegroundColor Cyan
            Write-Host ((Cut $it.Cmd 46).PadRight(47)) -NoNewline -ForegroundColor $fg
            Write-Host ((Get-Badge $it).PadRight(11)) -NoNewline -ForegroundColor (Get-PlatColor $it)
            $flag = ''
            if ($it.Admin) { $flag += 'admin ' }
            if ($it.Riesgo -eq 'cuidado') { $flag += '(!)' }
            Write-Host $flag -ForegroundColor Yellow
            if ($isSel) { Write-Host ('       ' + (Cut $it.Que ($script:W - 12))) -ForegroundColor DarkCyan }
        }

        if ($view.Count -gt $rows) {
            Write-Host ''
            Write-Host ('   [' + ($sel + 1) + '/' + $view.Count + ']') -ForegroundColor DarkGray
        }

        Show-Bar 'Flechas mover  Enter detalle  C copiar  escribe para buscar  Esc volver'
        $k = Read-Key

        if ($k.Key -eq [ConsoleKey]::UpArrow) { $sel--; if ($sel -lt 0) { $sel = [Math]::Max(0, $view.Count - 1) } }
        elseif ($k.Key -eq [ConsoleKey]::DownArrow) { $sel++; if ($sel -ge $view.Count) { $sel = 0 } }
        elseif ($k.Key -eq [ConsoleKey]::PageUp) { $sel = [Math]::Max(0, $sel - $rows) }
        elseif ($k.Key -eq [ConsoleKey]::PageDown) { $sel = [Math]::Min($view.Count - 1, $sel + $rows) }
        elseif ($k.Key -eq [ConsoleKey]::Home) { $sel = 0 }
        elseif ($k.Key -eq [ConsoleKey]::End) { $sel = $view.Count - 1 }
        elseif ($k.Key -eq [ConsoleKey]::Enter -or $k.Key -eq [ConsoleKey]::RightArrow) {
            if ($view.Count -gt 0) { Show-Detail $view[$sel] }
        }
        elseif ($k.Key -eq [ConsoleKey]::Escape) {
            if ($Filter) { $Filter = ''; $sel = 0 } else { return }
        }
        elseif ($k.Key -eq [ConsoleKey]::Backspace) {
            if ($Filter.Length -gt 0) { $Filter = $Filter.Substring(0, $Filter.Length - 1); $sel = 0 }
        }
        elseif ($k.Key -eq [ConsoleKey]::F2) {
            if ($view.Count -gt 0) { Copy-Cmd $view[$sel] }
        }
        elseif ([int]$k.KeyChar -ge 32) {
            $Filter += $k.KeyChar
            $sel = 0
        }
    }
}

# ==========================================================================
#  AYUDA
# ==========================================================================

function Show-Help {
    Show-Header 'Como usar esta herramienta' $script:Marca
    Write-Host '   TECLAS' -ForegroundColor Cyan
    Write-Host '     Flechas      moverse por la lista'
    Write-Host '     Enter / ->   abrir el detalle del comando'
    Write-Host '     Esc / <-     volver atras (o limpiar la busqueda)'
    Write-Host '     letras       filtran la lista mientras escribes'
    Write-Host '     C            copiar el comando (dentro del detalle)'
    Write-Host '     F2           copiar el comando marcado (dentro de la lista)'
    Write-Host '     E            ejecutar el comando (dentro del detalle)'
    Write-Host '     A            (en el menu principal) auditoria de equipo y licencias'
    Write-Host ''
    Write-Host '   ETIQUETAS' -ForegroundColor Cyan
    Write-Host '     CMD          se corre en el Simbolo del sistema (cmd)'
    Write-Host '     PowerShell   se corre en PowerShell'
    Write-Host '     SSH/Linux    se corre en el servidor por PuTTY/SSH (aqui solo se copia)'
    Write-Host '     admin        necesita consola como administrador'
    Write-Host '     (!)          delicado: corta servicio, tarda mucho o afecta a usuarios'
    Write-Host ''
    Write-Host '   REGLAS DE ORO' -ForegroundColor Cyan
    foreach ($t in $script:Tips) {
        foreach ($l in (Wrap ('- ' + $t) ($script:W - 8))) { Write-Host ('     ' + $l) -ForegroundColor Gray }
    }
    Show-Bar 'Cualquier tecla para volver'
    [void](Read-Key)
}

# ==========================================================================
#  AUDITORIA - EVALUACION
# ==========================================================================
#  La logica de deteccion es la ya probada en campo: no se cambia el criterio,
#  solo donde aterrizan los resultados (objetos, no renglones de texto).

function Get-EvaluacionKMS {
    param([string]$Servidor)
    $h = ($Servidor -replace '^\w+://', '' -replace ':\d+$', '').Trim().ToLower()
    $res = [ordered]@{ Host = $Servidor; Fuente = ''; Confiable = $false; Motivo = '' }

    foreach ($c in $script:Confiables) {
        if ($c -and $h -like "*$($c.ToLower())*") {
            $res.Confiable = $true
            $res.Motivo = "Coincide con la lista de servidores KMS confiables ($c)."
            return $res
        }
    }

    $pc = $script:NombrePC.ToLower()
    if ($h -eq 'localhost' -or $h -like '127.*' -or $h -eq '::1' -or $h -eq '0.0.0.0' -or $h -eq $pc -or $h -like "$pc.*" -or ($script:IpsLocales -contains $h)) {
        $res.Motivo = "El KMS apunta a ESTE MISMO equipo: es tipico de emuladores KMS (KMSpico, KMSAuto, vlmcsd)."
        return $res
    }

    $ipPrivada  = $h -match '^(10\.|192\.168\.|172\.(1[6-9]|2[0-9]|3[0-1])\.)'
    $sinPunto   = ($h -notmatch '\.') -and ($h -notmatch ':')
    $sufInterno = $h -match '\.(local|lan|corp|internal|intra|intranet|home|localdomain)$'
    $enDominio  = $false
    if ($script:Cs.PartOfDomain -and $script:Cs.Domain) {
        $dom = $script:Cs.Domain.ToLower()
        $enDominio = ($h -eq $dom) -or $h.EndsWith(".$dom")
    }
    if ($ipPrivada -or $sinPunto -or $sufInterno -or $enDominio) {
        if ($script:Cs.PartOfDomain) {
            $res.Confiable = $true
            $res.Motivo = "Servidor interno de la red corporativa (equipo unido a dominio). Confirmar con el area de TI."
        } else {
            $res.Motivo = "Equipo SIN dominio apuntando a un KMS de red local. Si es un KMS legitimo, agregalo a kms_confiables.txt."
        }
        return $res
    }

    $res.Motivo = "Servidor KMS PUBLICO de internet ($h). Los KMS legitimos de licencias por volumen son internos de la organizacion; usar uno publico es un metodo tipico de activacion pirata."
    return $res
}

# slmgr y ospp son scripts de Windows Script Host, y cscript escribe su salida
# en la pagina de codigos OEM del sistema (850 en Windows en espanol) aunque la
# consola este en UTF-8. Si se decodifica como UTF-8, "Descripcion" vuelve con un
# caracter de reemplazo. Comprobado: 850 acierta, 65001 y 1252 no.
function Get-SalidaNativa {
    param([string]$Script, [string[]]$Argumentos = @())
    $prev = $null
    try { $prev = [Console]::OutputEncoding } catch {}
    try {
        $cpOem = [System.Globalization.CultureInfo]::CurrentCulture.TextInfo.OEMCodePage
        [Console]::OutputEncoding = [System.Text.Encoding]::GetEncoding($cpOem)
    } catch {}
    try {
        return ((cscript //nologo $Script @Argumentos) 2>$null) -join "`n"
    } catch {
        return ''
    } finally {
        if ($prev) { try { [Console]::OutputEncoding = $prev } catch {} }
    }
}

function Get-IndicadoresCrack {
    $r = New-Object System.Collections.Generic.List[string]
    $rx = 'KMSELDI|KMSpico|KMS-?Auto|AutoPico|AAct|Service_KMS|KMService|vlmcsd|Re-?Loader|Ratiborus|HWIDGEN|SppExtComObj'

    Get-Service | Where-Object { $_.Name -match $rx -or $_.DisplayName -match $rx } |
        ForEach-Object { $r.Add("Servicio de activador: $($_.Name) ($($_.DisplayName))") }

    Get-ScheduledTask | Where-Object { $_.TaskName -match $rx -or $_.TaskPath -match $rx } |
        ForEach-Object { $r.Add("Tarea programada de activador: $($_.TaskPath)$($_.TaskName)") }

    $rutas = @(
        "$env:ProgramFiles\KMSpico", "${env:ProgramFiles(x86)}\KMSpico", "$env:ProgramFiles\AutoPico",
        "$env:windir\KMSAutoS", "$env:ProgramData\KMSAutoS", "$env:windir\AAct_Tools",
        "$env:windir\SECOH-QAD.exe", "$env:windir\System32\SppExtComObjHook.dll",
        "$env:windir\System32\SppExtComObjPatcher.exe"
    )
    foreach ($p in $rutas) { if ($p -and (Test-Path $p)) { $r.Add("Archivo/carpeta de activador: $p") } }

    if (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\SppExtComObj.exe') {
        $r.Add("Hook en el registro sobre SppExtComObj.exe (tecnica usada por KMSAuto/KMSpico).")
    }

    $excl = @((Get-MpPreference).ExclusionPath) | Where-Object { $_ -match 'KMS|pico|AAct|Activat|Ratiborus' }
    foreach ($e in $excl) { $r.Add("Exclusion de Windows Defender sospechosa: $e") }

    return $r
}

# ==========================================================================
#  AUDITORIA - RECOLECCION
# ==========================================================================
#  Devuelve un objeto con TODOS los datos del equipo. Nada de formato aqui:
#  de esto come tanto la plantilla HTML como el JSON de inventario.

function Get-DatosAuditoria {
    param([string[]]$DominiosKMSConfiables = @())

    # Consultar WMI y el registro deja errores por rutas que no existen en todos
    # los equipos (p.ej. SoftwareProtectionPlatform sin Office por volumen).
    # Silenciarlos aqui, no en todo el script: el ejecutor de comandos del
    # catalogo si debe mostrar los suyos.
    $ErrorActionPreference = 'SilentlyContinue'

    $esAdmin  = Test-Admin
    $ahora    = Get-Date
    $script:NombrePC = $env:COMPUTERNAME

    # Lista blanca de KMS: parametro + archivo opcional junto al script/exe
    $script:Confiables = @($DominiosKMSConfiables | Where-Object { $_ })
    $archivoKms = Join-Path $script:CarpetaBase 'kms_confiables.txt'
    if (Test-Path $archivoKms) {
        $script:Confiables += @(Get-Content $archivoKms | ForEach-Object { $_.Trim() } | Where-Object { $_ -and -not $_.StartsWith('#') })
    }

    # ------------------------------------------------------------------
    # 1. HARDWARE
    # ------------------------------------------------------------------
    Write-Host '   [1/4] Leyendo hardware...' -ForegroundColor DarkGray

    $script:Cs = Get-CimInstance Win32_ComputerSystem
    $bios = Get-CimInstance Win32_BIOS
    $cpu  = @(Get-CimInstance Win32_Processor)
    $ram  = @(Get-CimInstance Win32_PhysicalMemory)
    $disk = @(Get-CimInstance Win32_DiskDrive)
    $gpu  = @(Get-CimInstance Win32_VideoController)
    $mb   = Get-CimInstance Win32_BaseBoard
    $os   = Get-CimInstance Win32_OperatingSystem
    $script:IpsLocales = @(Get-CimInstance Win32_NetworkAdapterConfiguration -Filter "IPEnabled=TRUE" | ForEach-Object { $_.IPAddress } | Where-Object { $_ })

    $ramTotal = 0
    if ($ram.Count -gt 0) { $ramTotal = [math]::Round((($ram | Measure-Object Capacity -Sum).Sum) / 1GB, 2) }

    $equipo = [ordered]@{
        Nombre      = $script:NombrePC
        Fabricante  = "$($script:Cs.Manufacturer)".Trim()
        Modelo      = "$($script:Cs.Model)".Trim()
        Usuario     = $env:USERNAME
        EnDominio   = [bool]$script:Cs.PartOfDomain
        Dominio     = "$($script:Cs.Domain)"
        PlacaMadre  = "$($mb.Manufacturer) $($mb.Product)".Trim()
        Bios        = [ordered]@{
            Fabricante = "$($bios.Manufacturer)".Trim()
            Version    = "$($bios.SMBIOSBIOSVersion)".Trim()
            Serie      = "$($bios.SerialNumber)".Trim()
        }
        Cpu         = @(foreach ($c in $cpu) { [ordered]@{
            Nombre  = "$($c.Name)".Trim()
            Nucleos = [int]$c.NumberOfCores
            Hilos   = [int]$c.NumberOfLogicalProcessors
        } })
        RamTotalGB  = $ramTotal
        Modulos     = @(foreach ($m in $ram) { [ordered]@{
            CapacidadGB   = [math]::Round($m.Capacity / 1GB, 0)
            VelocidadMHz  = [int]$m.Speed
            Fabricante    = "$($m.Manufacturer)".Trim()
        } })
        Discos      = @(foreach ($d in $disk) { [ordered]@{
            Modelo   = "$($d.Model)".Trim()
            TamanoGB = [math]::Round($d.Size / 1GB, 1)
            Interfaz = "$($d.InterfaceType)"
        } })
        Video       = @(foreach ($g in $gpu) { "$($g.Name)".Trim() })
        IPs         = @($script:IpsLocales)
        SO          = [ordered]@{
            Caption      = "$($os.Caption)".Trim()
            Arquitectura = "$($os.OSArchitecture)"
            Version      = "$($os.Version)"
            Build        = "$($os.BuildNumber)"
            Instalado    = if ($os.InstallDate) { ([datetime]$os.InstallDate).ToString('dd/MM/yyyy HH:mm:ss') } else { '' }
        }
    }
    $equipo.Red = if ($equipo.EnDominio) { "Dominio: $($equipo.Dominio)" } else { "Grupo de trabajo: $($equipo.Dominio) (sin dominio)" }

    # ------------------------------------------------------------------
    # 2. ACTIVADORES PIRATAS
    # ------------------------------------------------------------------
    Write-Host '   [2/4] Buscando indicadores de activadores piratas...' -ForegroundColor DarkGray
    $indicadores = @(Get-IndicadoresCrack)

    # ------------------------------------------------------------------
    # 3. WINDOWS
    # ------------------------------------------------------------------
    Write-Host '   [3/4] Evaluando licencia de Windows...' -ForegroundColor DarkGray

    $estadosLic = @{ 0 = 'Sin licencia'; 1 = 'Con licencia (activado)'; 2 = 'Periodo de gracia inicial'; 3 = 'Periodo de gracia (OOT)'; 4 = 'Gracia por copia NO GENUINA'; 5 = 'Notificacion (NO activado)'; 6 = 'Gracia extendida' }

    $winProds = @(Get-CimInstance SoftwareLicensingProduct -Filter "ApplicationID='55c92734-d682-4d71-983e-d6ec3f16059f' AND PartialProductKey IS NOT NULL")
    $winP = $winProds | Where-Object { $_.LicenseStatus -eq 1 } | Select-Object -First 1
    if (-not $winP) { $winP = $winProds | Select-Object -First 1 }
    $slSvc = Get-CimInstance SoftwareLicensingService

    $winMotivos  = New-Object System.Collections.Generic.List[string]
    $winKms      = New-Object System.Collections.Generic.List[object]
    $winOriginal = $true

    $win = [ordered]@{
        Encontrada = [bool]$winP
        Edicion = ''; Descripcion = ''; Canal = ''; Ultimos5 = ''; Estado = ''
        GraciaDias = $null
        ClaveOEM = [ordered]@{ Existe = $false; Coincide = $false; Texto = '' }
        Nota = ''
    }

    if (-not $winP) {
        $winOriginal = $false
        $winMotivos.Add("No se encontro ninguna licencia de Windows instalada.")
    } else {
        $canal = "$($winP.ProductKeyChannel)"
        $esKMS = ($canal -match 'GVLK') -or ($winP.Description -match 'KMSCLIENT')

        $win.Edicion     = "$($winP.Name)"
        $win.Descripcion = "$($winP.Description)"
        $win.Canal       = $canal
        $win.Ultimos5    = "$($winP.PartialProductKey)"
        $win.Estado      = $estadosLic[[int]$winP.LicenseStatus]
        if ($esKMS -and $winP.GracePeriodRemaining) { $win.GraciaDias = [math]::Round($winP.GracePeriodRemaining / 1440, 0) }

        # Clave OEM incrustada en BIOS/UEFI: si coincide, es indicio fuerte de licencia legitima
        $oa3 = "$($slSvc.OA3xOriginalProductKey)"
        if ($oa3.Length -ge 5) {
            $win.ClaveOEM.Existe = $true
            if ($oa3.Substring($oa3.Length - 5) -eq $winP.PartialProductKey) {
                $win.ClaveOEM.Coincide = $true
                $win.ClaveOEM.Texto = 'Coincide con la clave instalada (licencia de fabrica).'
            } else {
                $win.ClaveOEM.Texto = 'Existe, pero NO coincide con la clave instalada (Windows reactivado con otra clave).'
            }
        }

        if ($winP.LicenseStatus -ne 1) {
            $winOriginal = $false
            $winMotivos.Add("Windows NO esta activado (estado: $($win.Estado)).")
        }

        # Servidores KMS declarados, por todas las fuentes posibles
        $hosts = @{}
        function Add-KmsHost($srv, $port, $fuente) {
            if ([string]::IsNullOrWhiteSpace($srv)) { return }
            $txt = "$srv"
            if ($port -and $port -ne 0 -and $txt -notmatch ':\d+$') { $txt = "${txt}:$port" }
            if ($hosts.ContainsKey($txt)) { $hosts[$txt] += "; $fuente" } else { $hosts[$txt] = $fuente }
        }
        Add-KmsHost $slSvc.KeyManagementServiceMachine $slSvc.KeyManagementServicePort 'override manual (servicio de licencias)'
        Add-KmsHost $winP.KeyManagementServiceMachine $winP.KeyManagementServicePort 'KMS registrado'
        Add-KmsHost $winP.DiscoveredKeyManagementServiceMachineName $winP.DiscoveredKeyManagementServiceMachinePort 'KMS descubierto por DNS'
        foreach ($rp in @('HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SoftwareProtectionPlatform', 'HKLM:\SOFTWARE\Microsoft\SoftwareProtectionPlatform')) {
            $rk = Get-ItemProperty -Path $rp
            if ($rk.KeyManagementServiceName) { Add-KmsHost $rk.KeyManagementServiceName $rk.KeyManagementServicePort 'override en el registro' }
        }

        foreach ($k in $hosts.Keys) {
            $ev = Get-EvaluacionKMS -Servidor $k
            $ev.Fuente = $hosts[$k]
            $winKms.Add($ev)
            if (-not $ev.Confiable) { $winOriginal = $false; $winMotivos.Add("KMS no confiable: $k - $($ev.Motivo)") }
        }

        if ($esKMS -and $winP.LicenseStatus -eq 1 -and $hosts.Count -eq 0) {
            if ($script:Cs.PartOfDomain) {
                $win.Nota = 'Cliente KMS sin servidor visible (equipo en dominio): verificar con TI que el KMS es el corporativo.'
            } else {
                $winOriginal = $false
                $winMotivos.Add("Activacion por volumen (KMS) en un equipo sin dominio y sin servidor KMS identificable: no verificable como legitima.")
            }
        }
        if ($canal -match 'MAK') { $win.Nota = 'Canal MAK (licencia por volumen). Confirmar con el proveedor que la clave es legitima.' }
    }

    if ($indicadores.Count -gt 0) {
        $winOriginal = $false
        foreach ($i in $indicadores) { $winMotivos.Add("Indicador de activador pirata: $i") }
    }
    if ($winOriginal) { $winMotivos.Add("Activacion valida sin indicadores de pirateria detectables.") }

    $win.Original      = $winOriginal
    $win.ServidoresKMS = $winKms.ToArray()
    $win.Motivos       = $winMotivos.ToArray()
    $win.SalidaCruda   = Get-SalidaNativa -Script "$env:windir\System32\slmgr.vbs" -Argumentos @('/dli')

    # ------------------------------------------------------------------
    # 4. OFFICE
    # ------------------------------------------------------------------
    Write-Host '   [4/4] Evaluando licencia de Office...' -ForegroundColor DarkGray

    $officeInstalado = $false
    $officeOriginal  = $null
    $offMotivos  = New-Object System.Collections.Generic.List[string]
    $offLic      = New-Object System.Collections.Generic.List[object]
    $offKms      = New-Object System.Collections.Generic.List[object]
    $osppTxt     = ''

    $bases = @("$env:ProgramFiles\Microsoft Office", "${env:ProgramFiles(x86)}\Microsoft Office") | Where-Object { $_ -and (Test-Path $_) }
    $ospp = $null
    foreach ($b in $bases) {
        $f = Get-ChildItem -Path $b -Filter 'OSPP.VBS' -Recurse -Depth 3 | Select-Object -First 1
        if ($f) { $ospp = $f.FullName; break }
    }

    $uninst = Get-ItemProperty @('HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*', 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*') |
        Where-Object { $_.DisplayName -match '^Microsoft (Office|365)' } | Select-Object -ExpandProperty DisplayName -Unique
    $productos = @($uninst | Select-Object -First 4)

    if ($ospp) {
        $officeInstalado = $true
        $osppTxt = Get-SalidaNativa -Script $ospp -Argumentos @('/dstatus')
        $bloques = @([regex]::Split($osppTxt, '(?m)^(?=PRODUCT ID:)') | Where-Object { $_ -match '^PRODUCT ID:' })

        $officeOriginal = $true
        $hayLicenciado  = $false
        foreach ($b in $bloques) {
            $lic = [ordered]@{
                Nombre   = ([regex]::Match($b, 'LICENSE NAME:\s*(.+)')).Groups[1].Value.Trim()
                Canal    = ([regex]::Match($b, 'LICENSE DESCRIPTION:\s*(.+)')).Groups[1].Value.Trim()
                Estado   = ([regex]::Match($b, 'LICENSE STATUS:\s*-*([A-Z_ ]+)')).Groups[1].Value.Trim()
                Ultimos5 = ([regex]::Match($b, 'Last 5 characters of installed product key:\s*(\S+)')).Groups[1].Value
                Nota     = ''
                Activada = $false
            }
            if ($lic.Estado -eq 'LICENSED') { $hayLicenciado = $true; $lic.Activada = $true }
            else { $officeOriginal = $false; $offMotivos.Add("Office NO esta activado correctamente (estado: $($lic.Estado)).") }
            if ($lic.Canal -match 'TIMEBASED|TRIAL') { $officeOriginal = $false; $offMotivos.Add("Office con licencia de prueba/temporal.") }
            if ($lic.Canal -match 'MAK') { $lic.Nota = 'Canal MAK (volumen). Confirmar con el proveedor que la clave es legitima.' }
            $offLic.Add($lic)
        }
        if ($bloques.Count -eq 0) { $officeOriginal = $false; $offMotivos.Add("Office instalado pero sin ninguna licencia activa detectada.") }
        elseif (-not $hayLicenciado -and $offMotivos.Count -eq 0) { $officeOriginal = $false; $offMotivos.Add("Ninguna licencia de Office figura como activada.") }

        # Servidores KMS de Office
        $hostsOff = @{}
        foreach ($m in [regex]::Matches($osppTxt, 'KMS machine registry override defined:\s*(\S+)')) { $hostsOff[$m.Groups[1].Value] = 'override en el registro' }
        foreach ($m in [regex]::Matches($osppTxt, 'Registered KMS machine name:\s*(\S+)'))          { if (-not $hostsOff.ContainsKey($m.Groups[1].Value)) { $hostsOff[$m.Groups[1].Value] = 'KMS registrado' } }
        foreach ($m in [regex]::Matches($osppTxt, 'KMS machine name from DNS:\s*(\S+)'))            { if (-not $hostsOff.ContainsKey($m.Groups[1].Value)) { $hostsOff[$m.Groups[1].Value] = 'KMS descubierto por DNS' } }
        foreach ($rp in @('HKLM:\SOFTWARE\Microsoft\OfficeSoftwareProtectionPlatform', 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\OfficeSoftwareProtectionPlatform')) {
            $rk = Get-ItemProperty -Path $rp
            if ($rk.KeyManagementServiceName) {
                $t = $rk.KeyManagementServiceName
                if ($rk.KeyManagementServicePort) { $t = "${t}:$($rk.KeyManagementServicePort)" }
                if (-not $hostsOff.ContainsKey($t)) { $hostsOff[$t] = 'override en el registro (Office)' }
            }
        }
        foreach ($k in $hostsOff.Keys) {
            $ev = Get-EvaluacionKMS -Servidor $k
            $ev.Fuente = $hostsOff[$k]
            $offKms.Add($ev)
            if (-not $ev.Confiable) { $officeOriginal = $false; $offMotivos.Add("KMS no confiable: $k - $($ev.Motivo)") }
        }
        if ($osppTxt -match 'VOLUME_KMSCLIENT' -and $hostsOff.Count -eq 0 -and -not $script:Cs.PartOfDomain) {
            $officeOriginal = $false
            $offMotivos.Add("Office activado por KMS en un equipo sin dominio y sin servidor KMS identificable: no verificable como legitimo.")
        }

        if ($indicadores.Count -gt 0) {
            $officeOriginal = $false
            $offMotivos.Add("Se detectaron activadores piratas en el equipo (ver seccion de Windows); suelen activar tambien Office.")
        }
        if ($officeOriginal) { $offMotivos.Add("Activacion valida sin indicadores de pirateria detectables.") }
    }
    elseif ($uninst) {
        $officeInstalado = $true
        $officeOriginal  = $false
        $offMotivos.Add("Office esta instalado pero no se pudo consultar su licencia (OSPP.VBS no encontrado): NO VERIFICABLE, revisar manualmente (Archivo > Cuenta).")
    }
    else {
        $offMotivos.Add("Microsoft Office no esta instalado en este equipo.")
    }

    $off = [ordered]@{
        Instalado           = $officeInstalado
        Original            = $officeOriginal
        ProductosInstalados = $productos
        Licencias           = $offLic.ToArray()
        ServidoresKMS       = $offKms.ToArray()
        Motivos             = $offMotivos.ToArray()
        SalidaCruda         = $osppTxt
    }

    # ------------------------------------------------------------------
    # 5. CLASIFICACION A / B / C
    # ------------------------------------------------------------------
    if ($null -eq $officeOriginal -and -not $officeInstalado) {
        if ($winOriginal) { $cat = 'A'; $catTxt = 'Windows ORIGINAL (Office no instalado)' }
        else              { $cat = 'C'; $catTxt = 'Windows NO original (Office no instalado)' }
    }
    elseif ($winOriginal -and $officeOriginal) { $cat = 'A'; $catTxt = 'Windows y Office ORIGINALES' }
    elseif ($winOriginal -or $officeOriginal) {
        $cat = 'B'
        if ($winOriginal) { $catTxt = 'Solo Windows es ORIGINAL (Office NO original / no verificable)' }
        else              { $catTxt = 'Solo Office es ORIGINAL (Windows NO original)' }
    }
    else { $cat = 'C'; $catTxt = 'Windows y Office NO originales (PIRATAS)' }

    $nivel = switch ($cat) { 'A' { 'ok' } 'B' { 'aviso' } default { 'alerta' } }

    $win.Veredicto = Get-Veredicto $winOriginal
    $off.Veredicto = Get-Veredicto $officeOriginal

    # ------------------------------------------------------------------
    # 6. OBJETO FINAL
    # ------------------------------------------------------------------
    [ordered]@{
        Meta = [ordered]@{
            Marca          = $script:Marca
            Version        = $script:Version
            Fecha          = $ahora.ToString('dd/MM/yyyy HH:mm:ss')
            FechaISO       = $ahora.ToString('s')
            ComoAdmin      = $esAdmin
            ComoAdminTexto = if ($esAdmin) { 'Si' } else { 'No - algunos datos pueden estar incompletos' }
        }
        Clasificacion = [ordered]@{
            Codigo = $cat
            Texto  = $catTxt
            Nivel  = $nivel
        }
        Equipo       = $equipo
        Windows      = $win
        Office       = $off
        Indicadores  = @($indicadores)
        Limitaciones = @(
            'Esta evaluacion es tecnica y local; no reemplaza una verificacion de Microsoft.',
            'Detecta activacion por KMS externo o local, activadores conocidos y licencias no activadas.',
            'NO puede distinguir con certeza una licencia digital obtenida con herramientas tipo HWID/MAS, ni una clave MAK o Retail filtrada que aun figura como activada.',
            'Ante un resultado "no verificable" o un canal MAK, confirmar la factura o la clave con el proveedor.'
        )
    }
}

function Get-Veredicto {
    param($v)
    if ($null -eq $v) { return 'NO INSTALADO' }
    elseif ($v)       { return 'ORIGINAL' }
    else              { return 'NO ORIGINAL (posible pirata)' }
}

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

# ==========================================================================
#  PLANTILLA HTML EMBEBIDA
# ==========================================================================
#  Generada por build.ps1 desde build\plantilla.html: no la edites aqui.
#  Para retocar el informe sin recompilar, deja un plantilla.html junto al exe.

$script:PlantillaEmbebida = @'
<!DOCTYPE html>
<html lang="es">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Auditoría de licencias &mdash; {{Equipo.Nombre}}</title>
<style>
/* ==========================================================================
   Sistema de diseño Lian-Dev — https://claude.ai/artifact/WHDKSRQADjH8SYZ8nNeY4u
   Los tokens de abajo son un espejo literal de project/tokens.json del sistema.
   Van embebidos porque el informe tiene que abrir sin conexión en el equipo
   del cliente. Si cambias un valor aquí, cámbialo también en el sistema.
   ========================================================================== */
:root {
  /* color — tema claro */
  --surface-base:    #ffffff;
  --surface-raised:  #f5f5f7;
  --surface-sunken:  #fafafc;
  --surface-overlay: #ffffff;
  --ink-primary:     #1d1d1f;
  --ink-secondary:   #515154;
  --ink-tertiary:    #6e6e73;
  --ink-inverse:     #ffffff;
  --accent:          #0071e3;
  --accent-soft:     #e8f2fd;
  --success:         #248a3d;
  --warning:         #8f5a00;
  --danger:          #d70015;
  --border-subtle:   #d2d2d7;
  --border-strong:   #86868b;

  /* espacio */
  --space-1: 4px;  --space-2: 8px;  --space-3: 12px; --space-4: 16px; --space-5: 24px;
  --space-6: 32px; --space-7: 48px; --space-8: 64px; --space-9: 96px;

  /* radio */
  --radius-xs: 6px; --radius-sm: 10px; --radius-md: 12px; --radius-lg: 18px;
  --radius-full: 980px;

  /* ancho */
  --measure-content: 980px;
  --gutter: 48px;

  /* tipografía: Inter si está instalada, si no la del sistema.
     Sin @font-face — el informe no puede depender de la red. */
  --font-sans: Inter, -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
  --font-mono: "JetBrains Mono", ui-monospace, "Cascadia Mono", Consolas, Menlo, monospace;
}

@media (prefers-color-scheme: dark) {
  :root {
    --surface-base:    #000000;
    --surface-raised:  #1d1d1f;
    --surface-sunken:  #141416;
    --surface-overlay: #2c2c2e;
    --ink-primary:     #f5f5f7;
    --ink-secondary:   #c7c7cc;
    --ink-tertiary:    #a1a1a6;
    --ink-inverse:     #1d1d1f;
    --accent:          #2997ff;
    --accent-soft:     #0a2a4d;
    --success:         #30d158;
    --warning:         #ffd60a;
    --danger:          #ff453a;
    --border-subtle:   #38383a;
    --border-strong:   #636366;
  }
}

* { box-sizing: border-box; }

body {
  margin: 0;
  background: var(--surface-raised);
  color: var(--ink-primary);
  font-family: var(--font-sans);
  font-size: 17px;
  line-height: 26px;
  letter-spacing: -0.004em;
  -webkit-font-smoothing: antialiased;
  -moz-osx-font-smoothing: grayscale;
  -webkit-print-color-adjust: exact;
  print-color-adjust: exact;
}

.hoja {
  max-width: var(--measure-content);
  margin: 0 auto;
  background: var(--surface-base);
  padding-bottom: var(--space-9);
}

.gutter { padding-left: var(--gutter); padding-right: var(--gutter); }

/* ---------- Encabezado de marca ----------
   Tipo sola sobre papel y una línea fina. Lian-Dev no tiene logo, y una banda
   de color aquí sería lo más ruidoso del informe. */
.marca {
  padding-top: var(--space-8);
  padding-bottom: var(--space-5);
  border-bottom: 1px solid var(--border-subtle);
}
.marca h1 {
  margin: 0;
  font-size: 32px;
  line-height: 38px;
  font-weight: 600;
  letter-spacing: -0.018em;
  color: var(--ink-primary);
}
.marca p {
  margin: var(--space-2) 0 0;
  font-size: 19px;
  line-height: 29px;
  letter-spacing: -0.004em;
  color: var(--ink-secondary);
}

/* ---------- Banda de veredicto ----------
   El bloque A/B/C va relleno en el color de estado con texto ink-inverse, así
   funciona igual en claro y en oscuro, y en escala de grises conserva la letra. */
.veredicto {
  display: flex;
  align-items: center;
  gap: var(--space-5);
  padding-top: var(--space-7);
  padding-bottom: var(--space-7);
  border-bottom: 1px solid var(--border-subtle);
}
.cat {
  flex: 0 0 auto;
  width: 76px; height: 76px;
  border-radius: var(--radius-lg);
  display: grid; place-items: center;
  font-size: 40px; line-height: 1; font-weight: 600; letter-spacing: -0.02em;
  color: var(--ink-inverse);
}
.veredicto h2 {
  margin: 0;
  font-size: 24px; line-height: 30px; font-weight: 600; letter-spacing: -0.012em;
}
.veredicto .pie {
  margin: var(--space-2) 0 0;
  font-size: 13px; line-height: 18px; letter-spacing: 0;
  color: var(--ink-tertiary);
}
.n-ok     .cat { background: var(--success); }
.n-aviso  .cat { background: var(--warning); }
.n-alerta .cat { background: var(--danger); }

/* ---------- Ficha de cabecera ---------- */
.ficha {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(190px, 1fr));
  gap: 0 var(--space-6);
  padding-top: var(--space-6);
  padding-bottom: var(--space-5);
  border-bottom: 1px solid var(--border-subtle);
}
.ficha dt {
  font-size: 12px; line-height: 16px; font-weight: 600;
  letter-spacing: 0.07em; text-transform: uppercase;
  color: var(--ink-tertiary);
}
.ficha dd {
  margin: var(--space-1) 0 var(--space-5);
  font-size: 15px; line-height: 22px; font-weight: 500;
  color: var(--ink-primary);
}

/* ---------- Secciones ---------- */
section { padding-top: var(--space-8); }
h3 {
  margin: 0 0 var(--space-5);
  padding-bottom: var(--space-3);
  border-bottom: 1px solid var(--border-subtle);
  font-size: 21px; line-height: 27px; font-weight: 600; letter-spacing: -0.01em;
  color: var(--ink-primary);
}

/* ---------- Tarjetas de producto ---------- */
.productos { display: grid; grid-template-columns: 1fr 1fr; gap: var(--space-5); }
.tarjeta {
  border: 1px solid var(--border-subtle);
  border-radius: var(--radius-md);
  padding: var(--space-5);
}
.tarjeta .titulo {
  font-size: 12px; line-height: 16px; font-weight: 600;
  letter-spacing: 0.07em; text-transform: uppercase;
  color: var(--ink-tertiary);
}
/* La píldora de veredicto: contorno en el color de estado, fondo transparente. */
.sello {
  display: inline-block;
  margin: var(--space-3) 0 var(--space-4);
  padding: 3px var(--space-3);
  border-radius: var(--radius-full);
  border: 1px solid;
  font-size: 13px; line-height: 18px; font-weight: 600; letter-spacing: 0.01em;
  background: transparent;
}
.s-ok     { color: var(--success); border-color: var(--success); }
.s-aviso  { color: var(--warning); border-color: var(--warning); }
.s-alerta { color: var(--danger);  border-color: var(--danger); }
.motivos {
  margin: 0; padding-left: 20px;
  font-size: 15px; line-height: 22px;
  color: var(--ink-secondary);
}
.motivos li { margin-bottom: var(--space-2); }

/* ---------- Tablas ----------
   Sin zebra: la línea fina hace el trabajo y deja el color para los estados. */
.scroll {
  overflow-x: auto;
  border: 1px solid var(--border-subtle);
  border-radius: var(--radius-md);
}
table {
  width: 100%;
  border-collapse: collapse;
  font-size: 15px; line-height: 22px;
}
th, td {
  text-align: left;
  padding: var(--space-3) var(--space-4);
  border-bottom: 1px solid var(--border-subtle);
  vertical-align: top;
}
th {
  font-size: 12px; line-height: 16px; font-weight: 600;
  letter-spacing: 0.07em; text-transform: uppercase;
  color: var(--ink-tertiary);
  white-space: nowrap;
}
td.k { color: var(--ink-tertiary); width: 220px; white-space: nowrap; }
tr:last-child td { border-bottom: 0; }
tbody tr:last-child td { border-bottom: 0; }
.mono {
  font-family: var(--font-mono);
  font-size: 13px; line-height: 21px; letter-spacing: 0;
}

.pill {
  display: inline-block;
  padding: 1px var(--space-2);
  border-radius: var(--radius-xs);
  border: 1px solid;
  font-size: 12px; line-height: 16px; font-weight: 600; letter-spacing: 0.01em;
  background: transparent;
}
.p-ok  { color: var(--success); border-color: var(--success); }
.p-mal { color: var(--danger);  border-color: var(--danger); }

/* ---------- Avisos ----------
   El sistema no tiene un callout rojo porque en producto sería demasiado. Aquí
   sí: el hallazgo de activadores ES el veredicto del informe. Se resuelve con
   contorno sobre fondo hundido, no con un bloque de color ni una barra lateral. */
.aviso-caja {
  border: 1px solid var(--danger);
  background: var(--surface-sunken);
  border-radius: var(--radius-md);
  padding: var(--space-5);
  font-size: 15px; line-height: 22px;
}
.aviso-caja strong { color: var(--danger); font-weight: 600; }
.aviso-caja ul { margin: var(--space-3) 0 0; padding-left: 20px; color: var(--ink-secondary); }
.aviso-caja li { margin-bottom: var(--space-2); }
.aviso-caja .mono { word-break: break-all; }
.limpio {
  border: 1px solid var(--success);
  background: var(--surface-sunken);
  border-radius: var(--radius-md);
  padding: var(--space-5);
  font-size: 15px; line-height: 22px;
  color: var(--ink-secondary);
}
.nota {
  margin-top: var(--space-3);
  font-size: 13px; line-height: 18px;
  color: var(--ink-tertiary);
}
.vacio { font-size: 15px; line-height: 22px; color: var(--ink-tertiary); }

/* ---------- Salida cruda ---------- */
details {
  margin-top: var(--space-4);
  border: 1px solid var(--border-subtle);
  border-radius: var(--radius-sm);
}
summary {
  cursor: pointer;
  padding: var(--space-3) var(--space-4);
  font-size: 15px; line-height: 22px; font-weight: 500;
  color: var(--accent);
}
summary:hover { text-decoration: underline; text-underline-offset: 3px; }
details pre {
  margin: 0;
  padding: var(--space-4);
  border-top: 1px solid var(--border-subtle);
  background: var(--surface-sunken);
  color: var(--ink-primary);
  font-family: var(--font-mono);
  font-size: 13px; line-height: 21px;
  white-space: pre-wrap; word-break: break-word;
}

/* ---------- Limitaciones y pie ---------- */
.limites {
  background: var(--surface-raised);
  border-radius: var(--radius-md);
  padding: var(--space-5);
  font-size: 15px; line-height: 22px;
  color: var(--ink-secondary);
}
.limites ul { margin: 0; padding-left: 20px; }
.limites li { margin-bottom: var(--space-2); }
.limites li:last-child { margin-bottom: 0; }
footer {
  margin-top: var(--space-9);
  padding-top: var(--space-4);
  border-top: 1px solid var(--border-subtle);
  font-size: 13px; line-height: 18px; letter-spacing: 0;
  color: var(--ink-tertiary);
  display: flex; justify-content: space-between; gap: var(--space-3); flex-wrap: wrap;
}

/* ---------- Pantallas angostas ---------- */
@media (max-width: 680px) {
  :root { --gutter: 22px; }
  body { font-size: 15px; line-height: 22px; }
  .marca h1 { font-size: 26px; line-height: 32px; }
  .marca p { font-size: 17px; line-height: 26px; }
  .productos { grid-template-columns: 1fr; }
  .veredicto { gap: var(--space-4); }
  .cat { width: 60px; height: 60px; font-size: 30px; border-radius: var(--radius-md); }
  .veredicto h2 { font-size: 21px; line-height: 27px; }
  td.k { width: auto; white-space: normal; }
}

/* ---------- Impresión a PDF ----------
   Siempre en claro: el informe se imprime y se archiva. */
@media print {
  :root {
    --surface-base:    #ffffff;
    --surface-raised:  #f5f5f7;
    --surface-sunken:  #fafafc;
    --ink-primary:     #1d1d1f;
    --ink-secondary:   #515154;
    --ink-tertiary:    #6e6e73;
    --ink-inverse:     #ffffff;
    --accent:          #0071e3;
    --success:         #248a3d;
    --warning:         #8f5a00;
    --danger:          #d70015;
    --border-subtle:   #d2d2d7;
    --gutter: 0px;
  }
  body { background: #fff; font-size: 10.5pt; line-height: 1.5; }
  .hoja { max-width: none; padding-bottom: 0; }
  .marca { padding-top: 0; }
  section, .tarjeta, .aviso-caja, .limpio, .limites, table { break-inside: avoid; page-break-inside: avoid; }
  details { border: 0; }
  details pre { max-height: none; border-top: 1px solid var(--border-subtle); }
  summary { display: none; }
  details[open] pre, details pre { display: block; }
  .scroll { border: 1px solid var(--border-subtle); }
  footer { position: static; margin-top: var(--space-7); }
  @page { margin: 14mm; }
}
</style>
</head>
<body>
<div class="hoja">

  <header class="marca gutter">
    <h1>{{Meta.Marca}}</h1>
    <p>Auditoría de equipo y licencias de software</p>
  </header>

  <div class="veredicto gutter n-{{Clasificacion.Nivel}}">
    <div class="cat">{{Clasificacion.Codigo}}</div>
    <div>
      <h2>{{Clasificacion.Texto}}</h2>
      <p class="pie">A = Windows y Office originales &middot; B = solo uno de los dos &middot; C = ambos no originales</p>
    </div>
  </div>

  <dl class="ficha gutter">
    <div><dt>Equipo</dt><dd>{{Equipo.Nombre}}</dd></div>
    <div><dt>Marca y modelo</dt><dd>{{Equipo.Fabricante}} {{Equipo.Modelo}}</dd></div>
    <div><dt>Usuario</dt><dd>{{Equipo.Usuario}}</dd></div>
    <div><dt>Fecha de la auditoría</dt><dd>{{Meta.Fecha}}</dd></div>
    <div><dt>Ejecutado como administrador</dt><dd>{{Meta.ComoAdminTexto}}</dd></div>
  </dl>

  <section class="gutter">
    <h3>Resultado por producto</h3>
    <div class="productos">

      <div class="tarjeta">
        <div class="titulo">Windows</div>
        {{#si Windows.Original}}<span class="sello s-ok">{{Windows.Veredicto}}</span>{{/si}}
        {{#no Windows.Original}}<span class="sello s-alerta">{{Windows.Veredicto}}</span>{{/no}}
        <ul class="motivos">
          {{#cada Windows.Motivos}}<li>{{.}}</li>{{/cada}}
        </ul>
      </div>

      <div class="tarjeta">
        <div class="titulo">Microsoft Office</div>
        {{#no Office.Instalado}}<span class="sello s-aviso">{{Office.Veredicto}}</span>{{/no}}
        {{#si Office.Instalado}}
          {{#si Office.Original}}<span class="sello s-ok">{{Office.Veredicto}}</span>{{/si}}
          {{#no Office.Original}}<span class="sello s-alerta">{{Office.Veredicto}}</span>{{/no}}
        {{/si}}
        <ul class="motivos">
          {{#cada Office.Motivos}}<li>{{.}}</li>{{/cada}}
        </ul>
      </div>

    </div>
  </section>

  <section class="gutter">
    <h3>Indicadores de activadores piratas</h3>
    {{#si Indicadores}}
    <div class="aviso-caja">
      <strong>Se encontraron rastros de herramientas de activación no autorizadas en este equipo.</strong>
      <ul>
        {{#cada Indicadores}}<li class="mono">{{.}}</li>{{/cada}}
      </ul>
    </div>
    {{/si}}
    {{#no Indicadores}}
    <div class="limpio">No se detectaron activadores piratas conocidos en este equipo.</div>
    {{/no}}
  </section>

  <section class="gutter">
    <h3>Hardware</h3>
    <div class="scroll">
      <table>
        <tr><td class="k">Equipo</td><td>{{Equipo.Fabricante}} {{Equipo.Modelo}}</td></tr>
        <tr><td class="k">Nombre en red</td><td>{{Equipo.Nombre}}</td></tr>
        <tr><td class="k">Red</td><td>{{Equipo.Red}}</td></tr>
        <tr><td class="k">Placa madre</td><td>{{Equipo.PlacaMadre}}</td></tr>
        <tr><td class="k">BIOS</td><td>{{Equipo.Bios.Fabricante}} {{Equipo.Bios.Version}} &middot; N/S <span class="mono">{{Equipo.Bios.Serie}}</span></td></tr>
        {{#cada Equipo.Cpu}}
        <tr><td class="k">Procesador</td><td>{{Nombre}} &middot; {{Nucleos}} núcleos / {{Hilos}} hilos</td></tr>
        {{/cada}}
        <tr><td class="k">Memoria RAM</td><td>{{Equipo.RamTotalGB}} GB{{#cada Equipo.Modulos}} &middot; {{CapacidadGB}} GB {{VelocidadMHz}} MHz {{Fabricante}}{{/cada}}</td></tr>
        {{#cada Equipo.Discos}}
        <tr><td class="k">Disco</td><td>{{Modelo}} &middot; {{TamanoGB}} GB [{{Interfaz}}]</td></tr>
        {{/cada}}
        {{#cada Equipo.Video}}
        <tr><td class="k">Video</td><td>{{.}}</td></tr>
        {{/cada}}
        <tr><td class="k">Sistema operativo</td><td>{{Equipo.SO.Caption}} {{Equipo.SO.Arquitectura}} &middot; versión {{Equipo.SO.Version}} (build {{Equipo.SO.Build}})</td></tr>
        <tr><td class="k">Instalado el</td><td>{{Equipo.SO.Instalado}}</td></tr>
      </table>
    </div>
  </section>

  <section class="gutter">
    <h3>Detalle de la licencia de Windows</h3>
    {{#si Windows.Encontrada}}
    <div class="scroll">
      <table>
        <tr><td class="k">Edición</td><td>{{Windows.Edicion}}</td></tr>
        <tr><td class="k">Descripción</td><td>{{Windows.Descripcion}}</td></tr>
        <tr><td class="k">Canal de la clave</td><td>{{Windows.Canal}}</td></tr>
        <tr><td class="k">Últimos 5 caracteres</td><td class="mono">{{Windows.Ultimos5}}</td></tr>
        <tr><td class="k">Estado</td><td>{{Windows.Estado}}</td></tr>
        {{#si Windows.GraciaDias}}<tr><td class="k">Gracia restante</td><td>{{Windows.GraciaDias}} día(s)</td></tr>{{/si}}
        {{#si Windows.ClaveOEM.Existe}}<tr><td class="k">Clave OEM en el BIOS</td><td>{{Windows.ClaveOEM.Texto}}</td></tr>{{/si}}
      </table>
    </div>
    {{#si Windows.Nota}}<p class="nota">{{Windows.Nota}}</p>{{/si}}
    {{#si Windows.ServidoresKMS}}
    <div class="scroll">
      <table>
        <thead><tr><th>Servidor KMS</th><th>Detectado en</th><th>Confianza</th><th>Evaluación</th></tr></thead>
        <tbody>
        {{#cada Windows.ServidoresKMS}}
          <tr>
            <td class="mono">{{Host}}</td>
            <td>{{Fuente}}</td>
            <td>{{#si Confiable}}<span class="pill p-ok">confiable</span>{{/si}}{{#no Confiable}}<span class="pill p-mal">no confiable</span>{{/no}}</td>
            <td>{{Motivo}}</td>
          </tr>
        {{/cada}}
        </tbody>
      </table>
    </div>
    {{/si}}
    {{#si Windows.SalidaCruda}}
    <details><summary>Ver salida de slmgr /dli</summary><pre>{{Windows.SalidaCruda}}</pre></details>
    {{/si}}
    {{/si}}
    {{#no Windows.Encontrada}}
    <p class="vacio">No se encontró ninguna licencia de Windows instalada en este equipo.</p>
    {{/no}}
  </section>

  <section class="gutter">
    <h3>Detalle de la licencia de Office</h3>
    {{#no Office.Instalado}}
    <p class="vacio">Microsoft Office no está instalado en este equipo.</p>
    {{/no}}
    {{#si Office.Instalado}}
      {{#si Office.ProductosInstalados}}
      <div class="scroll">
        <table>
          {{#cada Office.ProductosInstalados}}<tr><td class="k">Producto instalado</td><td>{{.}}</td></tr>{{/cada}}
        </table>
      </div>
      {{/si}}
      {{#si Office.Licencias}}
      <div class="scroll">
        <table>
          <thead><tr><th>Licencia</th><th>Canal</th><th>Estado</th><th>Clave</th></tr></thead>
          <tbody>
          {{#cada Office.Licencias}}
            <tr>
              <td>{{Nombre}}{{#si Nota}}<div class="nota">{{Nota}}</div>{{/si}}</td>
              <td>{{Canal}}</td>
              <td>{{#si Activada}}<span class="pill p-ok">{{Estado}}</span>{{/si}}{{#no Activada}}<span class="pill p-mal">{{Estado}}</span>{{/no}}</td>
              <td class="mono">{{Ultimos5}}</td>
            </tr>
          {{/cada}}
          </tbody>
        </table>
      </div>
      {{/si}}
      {{#si Office.ServidoresKMS}}
      <div class="scroll">
        <table>
          <thead><tr><th>Servidor KMS</th><th>Detectado en</th><th>Confianza</th><th>Evaluación</th></tr></thead>
          <tbody>
          {{#cada Office.ServidoresKMS}}
            <tr>
              <td class="mono">{{Host}}</td>
              <td>{{Fuente}}</td>
              <td>{{#si Confiable}}<span class="pill p-ok">confiable</span>{{/si}}{{#no Confiable}}<span class="pill p-mal">no confiable</span>{{/no}}</td>
              <td>{{Motivo}}</td>
            </tr>
          {{/cada}}
          </tbody>
        </table>
      </div>
      {{/si}}
      {{#si Office.SalidaCruda}}
      <details><summary>Ver salida de ospp.vbs /dstatus</summary><pre>{{Office.SalidaCruda}}</pre></details>
      {{/si}}
    {{/si}}
  </section>

  <section class="gutter">
    <h3>Alcance y limitaciones</h3>
    <div class="limites">
      <ul>
        {{#cada Limitaciones}}<li>{{.}}</li>{{/cada}}
      </ul>
    </div>
  </section>

  <footer class="gutter">
    <span>{{Meta.Marca}} &middot; informe generado automáticamente el {{Meta.Fecha}}</span>
    <span>v{{Meta.Version}}</span>
  </footer>

</div>
</body>
</html>
'@

# ==========================================================================
#  MENU PRINCIPAL
# ==========================================================================

function Show-Menu {
    $keys  = @($script:Cats.Keys)
    $opts  = @(
        'A   Auditoria de equipo y licencias   (genera informe HTML + JSON)',
        'T   Todos los comandos',
        '/   Buscar en todo',
        'H   Como usar esta guia / reglas de oro'
    )
    $extra = $opts.Count
    $sel   = 0

    while ($true) {
        Show-Header $script:Marca ('Referencia rapida - ' + $script:Cmds.Count + ' comandos catalogados - v' + $script:Version)

        Write-Host '   CATEGORIAS' -ForegroundColor Cyan
        Show-Sep
        for ($i = 0; $i -lt $keys.Count; $i++) {
            $ck = $keys[$i]
            $c = $script:Cats[$ck]
            $n = @($script:Cmds | Where-Object { $_.Cat -eq $ck }).Count
            $isSel = ($i -eq $sel)
            if ($isSel) { $mark = ' > '; $fg = [ConsoleColor]::White } else { $mark = '   '; $fg = [ConsoleColor]::Gray }
            Write-Host $mark -NoNewline -ForegroundColor Cyan
            Write-Host (($i + 1).ToString() + '  ') -NoNewline -ForegroundColor DarkGray
            Write-Host ((Cut $c.N 34).PadRight(35)) -NoNewline -ForegroundColor $fg
            Write-Host ($c.S.PadRight(24)) -NoNewline -ForegroundColor DarkCyan
            Write-Host ($n.ToString().PadLeft(3) + ' cmds') -ForegroundColor DarkGray
        }
        Write-Host ''
        Show-Sep
        for ($j = 0; $j -lt $opts.Count; $j++) {
            $i = $keys.Count + $j
            $isSel = ($i -eq $sel)
            if ($isSel) { $mark = ' > '; $fg = [ConsoleColor]::White } else { $mark = '   '; $fg = [ConsoleColor]::Gray }
            # la auditoria resalta porque es la herramienta, no una lista
            if ($j -eq 0 -and -not $isSel) { $fg = [ConsoleColor]::Yellow }
            Write-Host $mark -NoNewline -ForegroundColor Cyan
            Write-Host $opts[$j] -ForegroundColor $fg
        }

        Show-Bar ('Flechas mover  Enter abrir  1-' + $keys.Count + ' atajo  A auditoria  T todos  / buscar  H ayuda  Q salir')
        $k = Read-Key
        $ch = ([string]$k.KeyChar).ToUpper()
        $total = $keys.Count + $extra

        if ($k.Key -eq [ConsoleKey]::UpArrow) { $sel--; if ($sel -lt 0) { $sel = $total - 1 } }
        elseif ($k.Key -eq [ConsoleKey]::DownArrow) { $sel++; if ($sel -ge $total) { $sel = 0 } }
        elseif ($k.Key -eq [ConsoleKey]::Enter -or $k.Key -eq [ConsoleKey]::RightArrow) {
            if ($sel -lt $keys.Count) {
                $ck = $keys[$sel]
                Show-List @($script:Cmds | Where-Object { $_.Cat -eq $ck }) $script:Cats[$ck].N $script:Cats[$ck].S
            }
            elseif ($sel -eq $keys.Count)       { Start-Auditoria }
            elseif ($sel -eq ($keys.Count + 1)) { Show-List $script:Cmds 'Todos los comandos' 'Escribe para filtrar por comando, descripcion o situacion' }
            elseif ($sel -eq ($keys.Count + 2)) { Show-List $script:Cmds 'Buscar en todo' 'Escribe lo que buscas: dns, disco, licencia, hora...' }
            else { Show-Help }
        }
        elseif ($ch -match '^[1-9]$' -and [int]$ch -le $keys.Count) {
            $ck = $keys[[int]$ch - 1]
            $sel = [int]$ch - 1
            Show-List @($script:Cmds | Where-Object { $_.Cat -eq $ck }) $script:Cats[$ck].N $script:Cats[$ck].S
        }
        elseif ($ch -eq 'A') { Start-Auditoria }
        elseif ($ch -eq 'T') { Show-List $script:Cmds 'Todos los comandos' 'Escribe para filtrar' }
        elseif ($k.KeyChar -eq '/') { Show-List $script:Cmds 'Buscar en todo' 'Escribe lo que buscas: dns, disco, licencia, hora...' }
        elseif ($ch -eq 'H') { Show-Help }
        elseif ($ch -eq 'Q' -or $k.Key -eq [ConsoleKey]::Escape) {
            Clear-Host
            Write-Host ''
            Write-Host ('   Hasta luego. ' + $script:Marca) -ForegroundColor DarkCyan
            Write-Host ''
            return
        }
    }
}

function Start-Auditoria {
    Invoke-Auditoria -Salida $script:RutaSalida -DominiosKMSConfiables $script:KmsParam | Out-Null
}

# ==========================================================================
#  ARRANQUE
# ==========================================================================

$script:RutaSalida = $RutaSalida
$script:KmsParam   = @($DominiosKMSConfiables)

try { $Host.UI.RawUI.WindowTitle = $script:Marca } catch {}

if ($Auditoria) {
    Invoke-Auditoria -Salida $script:RutaSalida -DominiosKMSConfiables $script:KmsParam -NoPausar:$SinPausa | Out-Null
} else {
    Show-Menu
}

