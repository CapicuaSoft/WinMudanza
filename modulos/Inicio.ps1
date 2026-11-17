# Modulo Inicio: menu Inicio (anclados), barra de tareas (anclados), escritorio (accesos directos,
# iconos de Windows visibles y posicion de los iconos) y programas que se abren al iniciar sesion
# (carpeta Inicio del menu Inicio), de cada usuario.
# Windows 11 no tiene una forma oficial de cambiar los anclados de un usuario ya creado; se usa
# la copia exacta de sus archivos:
#   Menu Inicio   -> LocalState\start*.bin de StartMenuExperienceHost
#   Barra tareas  -> accesos de "User Pinned\TaskBar" + registro Explorer\Taskband
#   Escritorio    -> accesos (.lnk/.url) del escritorio del usuario y del publico,
#                    HideDesktopIcons\NewStartPanel (Este equipo, Papelera...) y Shell\Bags\1\Desktop
#   Al iniciar    -> carpeta Startup del usuario (y la comun de todos los usuarios)
# - Aplicar: menu Inicio, barra de tareas, iconos de Windows y posiciones se restauran UNA vez por
#   usuario (se marca en HKCU\Software\WinMudanza\Inicio) para no deshacer lo que cambie despues.
#   De los accesos del escritorio y de la carpeta Inicio solo se copian los que falten.
#   Un usuario con sesion abierta que no sea el que ejecuta se salta (su Explorador lo sobrescribiria).

@{
    Nombre        = 'Inicio'
    Descripcion   = 'Menu Inicio, barra de tareas, escritorio y programas al iniciar sesion'
    Orden         = 58
    DependeDe     = @('Usuarios', 'Paquetes', 'Carpetas')
    ArchivoConfig = 'inicio.psd1'

    Extraer = {
        param($Ctx)
        $dirBase = Join-Path $Ctx.DirConfig 'inicio'
        if (Test-Path -LiteralPath $dirBase) { Remove-Item -LiteralPath $dirBase -Recurse -Force }
        $rutas = Get-RutasInicio
        $usuarios = New-Object System.Collections.ArrayList

        # Copia archivos a una carpeta de config y devuelve sus nombres
        function Copy-AConfig($Archivos, [string]$Destino) {
            if (@($Archivos).Count -eq 0) { return @() }
            New-Item -ItemType Directory -Path $Destino -Force | Out-Null
            foreach ($f in $Archivos) { Copy-Item -LiteralPath $f.FullName -Destination $Destino -Force }
            return @($Archivos | ForEach-Object { $_.Name })
        }
        function Get-Nombres($Archivos) { return (@($Archivos | ForEach-Object { $_.BaseName }) -join ', ') }

        Invoke-EnPerfiles {
            param($P)
            if ($P.EsDefault) { return }
            $destU = Join-Path $dirBase $P.Nombre
            $u = [ordered]@{
                Usuario = $P.Nombre; MenuInicio = $false; BarraTareas = @(); Taskband = [ordered]@{}
                Escritorio = @(); IconosSistema = [ordered]@{}; Posiciones = [ordered]@{}; AlIniciar = @()
            }

            # Menu Inicio
            $bins = @(Get-ChildItem -LiteralPath (Join-Path $P.Ruta $rutas.MenuInicio) -Filter 'start*.bin' -File -ErrorAction SilentlyContinue)
            if ($bins.Count -gt 0) {
                $null = Copy-AConfig $bins (Join-Path $destU 'MenuInicio')
                $u.MenuInicio = $true
                Write-Ok "$($P.Nombre): menu Inicio ($(@($bins | ForEach-Object { $_.Name }) -join ', '))"
            }

            # Barra de tareas: accesos + Taskband
            $lnks = @(Get-ChildItem -LiteralPath (Join-Path $P.Ruta $rutas.BarraTareas) -Filter '*.lnk' -File -Force -ErrorAction SilentlyContinue)
            $u.Taskband = Export-RegValores "$($P.HKCU)\$($rutas.Taskband)"
            if ($lnks.Count -gt 0) {
                $u.BarraTareas = Copy-AConfig $lnks (Join-Path $destU 'BarraTareas')
                Write-Ok "$($P.Nombre): barra de tareas ($($lnks.Count) accesos: $(Get-Nombres $lnks))"
            }

            # Escritorio: accesos directos (si esta fuera del perfil, p. ej. en D:, ya se conserva)
            $esc = Get-EscritorioPerfil $P
            if (-not $esc.EnPerfil -or $esc.EnOneDrive) {
                Write-Omitido "$($P.Nombre): escritorio en $($esc.Ruta) (se conserva alli)"
            } else {
                $acc = @(Get-ChildItem -LiteralPath $esc.Ruta -File -Force -ErrorAction SilentlyContinue | Where-Object { Test-EsAcceso $_ })
                if ($acc.Count -gt 0) {
                    $u.Escritorio = Copy-AConfig $acc (Join-Path $destU 'Escritorio')
                    Write-Ok "$($P.Nombre): escritorio ($($acc.Count) accesos: $(Get-Nombres $acc))"
                }
                $otros = @(Get-ChildItem -LiteralPath $esc.Ruta -Force -ErrorAction SilentlyContinue | Where-Object { $_.Name -ne 'desktop.ini' -and ($_.PSIsContainer -or -not (Test-EsAcceso $_)) })
                if ($otros.Count -gt 0) { Write-Aviso "$($P.Nombre): el escritorio tiene $($otros.Count) archivos o carpetas que no son accesos directos y no se copian; guardalos tu ($($esc.Ruta))" }
            }
            # Iconos de Windows en el escritorio y posicion de los iconos
            $u.IconosSistema = Export-RegValores "$($P.HKCU)\$($rutas.IconosSistema)"
            $u.Posiciones = Export-RegValores "$($P.HKCU)\$($rutas.Posiciones)"
            if ($u.IconosSistema.Count -gt 0 -or $u.Posiciones.Count -gt 0) { Write-Ok "$($P.Nombre): iconos de Windows y posiciones del escritorio" }

            # Al iniciar sesion
            $ini = @(Get-ChildItem -LiteralPath (Join-Path $P.Ruta $rutas.AlIniciar) -File -Force -ErrorAction SilentlyContinue | Where-Object { $_.Name -ne 'desktop.ini' })
            if ($ini.Count -gt 0) {
                $u.AlIniciar = Copy-AConfig $ini (Join-Path $destU 'AlIniciar')
                Write-Ok "$($P.Nombre): al iniciar sesion: $(Get-Nombres $ini)"
            }
            if ($u.MenuInicio -or $u.BarraTareas.Count -gt 0 -or $u.Escritorio.Count -gt 0 -or $u.IconosSistema.Count -gt 0 -or $u.Posiciones.Count -gt 0 -or $u.AlIniciar.Count -gt 0) {
                [void]$usuarios.Add($u)
            }
        }

        # Comunes (todos los usuarios): carpeta Inicio y escritorio publico
        $comun = @(Get-ChildItem -LiteralPath ([Environment]::GetFolderPath('CommonStartup')) -File -Force -ErrorAction SilentlyContinue | Where-Object { $_.Name -ne 'desktop.ini' })
        $alIniciarComun = Copy-AConfig $comun (Join-Path $dirBase '_Comun\AlIniciar')
        if ($comun.Count -gt 0) { Write-Ok "Todos los usuarios: al iniciar sesion: $(Get-Nombres $comun)" }
        $pub = @(Get-ChildItem -LiteralPath ([Environment]::GetFolderPath('CommonDesktopDirectory')) -File -Force -ErrorAction SilentlyContinue | Where-Object { Test-EsAcceso $_ })
        $escritorioComun = Copy-AConfig $pub (Join-Path $dirBase '_Comun\Escritorio')
        if ($pub.Count -gt 0) { Write-Ok "Escritorio publico: $($pub.Count) accesos: $(Get-Nombres $pub)" }

        $ruta = Join-Path $Ctx.DirConfig 'inicio.psd1'
        Write-Psd1 -Ruta $ruta -Datos ([ordered]@{ Usuarios = @($usuarios); AlIniciarComun = $alIniciarComun; EscritorioComun = $escritorioComun }) -Cabecera @(
            "Menu Inicio, barra de tareas, escritorio y programas al iniciar sesion de $env:COMPUTERNAME el $(Get-Date -Format 'yyyy-MM-dd HH:mm'):"
            ''
            'Los archivos estan en config\inicio\<usuario>\ (MenuInicio, BarraTareas, Escritorio, AlIniciar)'
            'y en config\inicio\_Comun\ (escritorio publico y carpeta Inicio de todos los usuarios).'
            'MenuInicio = $false, BarraTareas = @() o Posiciones = @{} para no restaurarlos a ese usuario.'
            'Menu Inicio, barra, iconos de Windows y posiciones se restauran una sola vez por usuario;'
            'de Escritorio y AlIniciar se copian los accesos que falten.'
            'Taskband, IconosSistema, Posiciones: valores del registro (binarios en base64). No editar.'
        )
        Write-Info "-> $ruta"
    }

    Aplicar = {
        param($Ctx)
        $cfg = Read-ConfigPsd1 (Join-Path $Ctx.DirConfig 'inicio.psd1')
        $dirBase = Join-Path $Ctx.DirConfig 'inicio'
        $rutas = Get-RutasInicio
        $config = @{}
        foreach ($u in @($cfg.Usuarios | Where-Object { $_ })) { $config[$u.Usuario] = $u }
        $yo = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
        $estadoInicio = @{ Reiniciar = $false }

        # Copia los archivos de una carpeta que falten en otra
        function Copy-Faltan([string]$Origen, [string]$Destino, [string]$Etiqueta) {
            $faltan = @(Get-ChildItem -LiteralPath $Origen -File -Force -ErrorAction SilentlyContinue |
                Where-Object { -not (Test-Path -LiteralPath (Join-Path $Destino $_.Name)) })
            if ($faltan.Count -eq 0) { Write-Omitido "$Etiqueta (ya estan)"; return }
            $null = Invoke-Cambio "${Etiqueta}: $(($faltan | ForEach-Object { $_.BaseName }) -join ', ')" {
                if (-not (Test-Path -LiteralPath $Destino)) { New-Item -ItemType Directory -Path $Destino -Force -ErrorAction Stop | Out-Null }
                foreach ($f in $faltan) { Copy-Item -LiteralPath $f.FullName -Destination $Destino -Force -ErrorAction Stop }
            }
        }

        $perfiles = @(Get-PerfilesUsuario | Where-Object { -not $_.EsDefault } | ForEach-Object { $_.Nombre })
        foreach ($n in $config.Keys) {
            if ($perfiles -notcontains $n) { Add-Pendiente "Menu Inicio, barra de tareas y escritorio de '$n': aun no tiene perfil. Inicia sesion con esa cuenta una vez y vuelve a ejecutar -Solo Inicio" }
        }

        Invoke-EnPerfiles {
            param($P)
            if ($P.EsDefault -or -not $config.ContainsKey($P.Nombre)) { return }
            $u = $config[$P.Nombre]
            $origenU = Join-Path $dirBase $P.Nombre
            $marca = "$($P.HKCU)\Software\WinMudanza\Inicio"
            $hecho = Get-ItemProperty -LiteralPath $marca -ErrorAction SilentlyContinue
            $esYo = $P.Sid -eq $yo
            $conSesion = $P.Sid -and $P.HKCU -eq "Registry::HKEY_USERS\$($P.Sid)"

            # ---- Lo que se restaura una vez ----
            $tocaMenu = $u.MenuInicio -and -not ($hecho -and $hecho.MenuInicio)
            $tocaBarra = (@($u.BarraTareas).Count -gt 0) -and -not ($hecho -and $hecho.BarraTareas)
            $tocaEsc = ($u.IconosSistema.Count -gt 0 -or $u.Posiciones.Count -gt 0) -and -not ($hecho -and $hecho.Escritorio)
            if ($u.MenuInicio -and -not $tocaMenu) { Write-Omitido "$($P.Nombre): menu Inicio ya restaurado por WinMudanza" }
            if (@($u.BarraTareas).Count -gt 0 -and -not $tocaBarra) { Write-Omitido "$($P.Nombre): barra de tareas ya restaurada por WinMudanza" }
            if (($u.IconosSistema.Count -gt 0 -or $u.Posiciones.Count -gt 0) -and -not $tocaEsc) { Write-Omitido "$($P.Nombre): iconos del escritorio ya restaurados por WinMudanza" }
            if (($tocaMenu -or $tocaBarra -or $tocaEsc) -and $conSesion -and -not $esYo) {
                Write-Aviso "$($P.Nombre) tiene la sesion abierta: cierra su sesion y vuelve a ejecutar -Solo Inicio (su Explorador sobrescribiria el menu, la barra y el escritorio)"
                $tocaMenu = $false; $tocaBarra = $false; $tocaEsc = $false
            }

            if ($tocaMenu) {
                $dest = Join-Path $P.Ruta $rutas.MenuInicio
                $ok = Invoke-Cambio "$($P.Nombre): menu Inicio (anclados)" {
                    if ($esYo) { Get-Process -Name StartMenuExperienceHost -ErrorAction SilentlyContinue | Where-Object { $_.SessionId -eq (Get-Process -Id $PID).SessionId } | Stop-Process -Force -ErrorAction SilentlyContinue }
                    if (-not (Test-Path -LiteralPath $dest)) { New-Item -ItemType Directory -Path $dest -Force -ErrorAction Stop | Out-Null }
                    foreach ($b in Get-ChildItem -LiteralPath (Join-Path $origenU 'MenuInicio') -File) {
                        $d = Join-Path $dest $b.Name
                        if (Test-Path -LiteralPath $d) { Copy-Item -LiteralPath $d -Destination "$d.wmud.bak" -Force -ErrorAction Stop }
                        Copy-Item -LiteralPath $b.FullName -Destination $d -Force -ErrorAction Stop
                    }
                }
                if ($ok) {
                    $null = Set-RegValor -Ruta $marca -Nombre 'MenuInicio' -Valor 1
                    if ($esYo) { $estadoInicio.Reiniciar = $true }
                }
            }

            if ($tocaBarra) {
                $dest = Join-Path $P.Ruta $rutas.BarraTareas
                $ok = Invoke-Cambio "$($P.Nombre): barra de tareas ($(@($u.BarraTareas) -join ', '))" {
                    if (-not (Test-Path -LiteralPath $dest)) { New-Item -ItemType Directory -Path $dest -Force -ErrorAction Stop | Out-Null }
                    foreach ($l in Get-ChildItem -LiteralPath (Join-Path $origenU 'BarraTareas') -Filter '*.lnk' -File -Force -ErrorAction SilentlyContinue) {
                        Copy-Item -LiteralPath $l.FullName -Destination $dest -Force -ErrorAction Stop
                    }
                }
                if ($ok -and (Import-RegValores "$($P.HKCU)\$($rutas.Taskband)" $u.Taskband)) {
                    $null = Set-RegValor -Ruta $marca -Nombre 'BarraTareas' -Valor 1
                    if ($esYo) { $estadoInicio.Reiniciar = $true }
                }
            }

            # ---- Escritorio: accesos que falten (si el escritorio esta en el perfil) ----
            if (@($u.Escritorio).Count -gt 0) {
                $esc = Get-EscritorioPerfil $P
                Copy-Faltan (Join-Path $origenU 'Escritorio') $esc.Ruta "$($P.Nombre): escritorio"
            }
            # Iconos de Windows y posiciones (despues de copiar los accesos)
            if ($tocaEsc) {
                $ok = Import-RegValores "$($P.HKCU)\$($rutas.IconosSistema)" $u.IconosSistema
                if (-not (Import-RegValores "$($P.HKCU)\$($rutas.Posiciones)" $u.Posiciones)) { $ok = $false }
                if ($ok) {
                    $null = Set-RegValor -Ruta $marca -Nombre 'Escritorio' -Valor 1
                    if ($esYo) { $estadoInicio.Reiniciar = $true }
                }
            }

            # ---- Al iniciar sesion: los que falten ----
            if (@($u.AlIniciar).Count -gt 0) {
                Copy-Faltan (Join-Path $origenU 'AlIniciar') (Join-Path $P.Ruta $rutas.AlIniciar) "$($P.Nombre): al iniciar sesion"
            }
        }

        if (@($cfg.AlIniciarComun | Where-Object { $_ }).Count -gt 0) {
            Copy-Faltan (Join-Path $dirBase '_Comun\AlIniciar') ([Environment]::GetFolderPath('CommonStartup')) 'Todos los usuarios: al iniciar sesion'
        }
        if (@($cfg.EscritorioComun | Where-Object { $_ }).Count -gt 0) {
            Copy-Faltan (Join-Path $dirBase '_Comun\Escritorio') ([Environment]::GetFolderPath('CommonDesktopDirectory')) 'Escritorio publico'
        }

        if ($estadoInicio.Reiniciar) {
            # Solo el Explorador de esta sesion (Windows lo vuelve a abrir solo). Se cierra a la fuerza
            # para que no guarde encima las posiciones de los iconos que tiene ahora.
            $null = Invoke-Cambio 'Reiniciar el Explorador (menu Inicio, barra de tareas y escritorio)' {
                $sesion = (Get-Process -Id $PID).SessionId
                Get-Process -Name explorer -ErrorAction Stop | Where-Object { $_.SessionId -eq $sesion } | Stop-Process -Force -ErrorAction Stop
            }
        }
        Write-Info 'Los demas usuarios veran su menu Inicio, su barra de tareas y su escritorio al iniciar sesion.'
    }
}
