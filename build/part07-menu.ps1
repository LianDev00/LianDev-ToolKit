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
