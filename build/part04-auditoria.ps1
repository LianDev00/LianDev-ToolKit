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
