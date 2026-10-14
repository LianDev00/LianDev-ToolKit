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
