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
