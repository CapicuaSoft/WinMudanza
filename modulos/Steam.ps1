# Modulo Steam: replica la configuracion de Steam (NO instala Steam ni juegos).
#   Imagenes      -> userdata\<cuenta>\config\grid (portadas, heroes, logos, iconos)
#   JuegosNoSteam -> userdata\<cuenta>\config\shortcuts.vdf (emuladores, juegos externos)
#   Colecciones   -> userdata\<cuenta>\config\cloudstorage (Steam tambien las sincroniza en su nube)
#   Lanzamiento   -> opciones de lanzamiento por juego (localconfig.vdf)
# Requisitos al aplicar: Steam instalado, haber iniciado sesion una vez y Steam CERRADO.

@{
    Nombre        = 'Steam'
    Descripcion   = 'Imagenes, juegos no-Steam, colecciones y opciones'
    Orden         = 60
    DependeDe     = @()
    ArchivoConfig = 'steam.psd1'

    Extraer = {
        param($Ctx)
        function Get-RutaSteam {
            $r = (Get-ItemProperty 'HKCU:\Software\Valve\Steam' -ErrorAction SilentlyContinue).SteamPath
            if (-not $r) { $r = (Get-ItemProperty 'HKLM:\SOFTWARE\WOW6432Node\Valve\Steam' -ErrorAction SilentlyContinue).InstallPath }
            if ($r) { return ($r -replace '/', '\') }
            return $null
        }
        $steam = Get-RutaSteam
        if (-not $steam -or -not (Test-Path -LiteralPath (Join-Path $steam 'userdata'))) { Write-Omitido 'Steam no esta instalado'; return }

        $destBase = Join-Path $Ctx.DirConfig 'steam'
        if (Test-Path -LiteralPath $destBase) { Remove-Item -LiteralPath $destBase -Recurse -Force }

        $cuentas = @()
        foreach ($u in Get-ChildItem -LiteralPath (Join-Path $steam 'userdata') -Directory) {
            if ($u.Name -notmatch '^\d+$' -or $u.Name -eq '0') { continue }
            $cfgDir = Join-Path $u.FullName 'config'
            if (-not (Test-Path -LiteralPath $cfgDir)) { continue }
            $dest = Join-Path $destBase $u.Name
            New-Item -ItemType Directory -Path $dest -Force | Out-Null

            # Imagenes
            $numImg = 0
            $grid = Join-Path $cfgDir 'grid'
            if (Test-Path -LiteralPath $grid) {
                Copy-Item -LiteralPath $grid -Destination (Join-Path $dest 'grid') -Recurse -Force
                $numImg = @(Get-ChildItem -LiteralPath $grid -File -Recurse).Count
            }

            # Juegos no-Steam (appid como entero sin signo = nombre de sus imagenes en grid)
            $accesos = @()
            $sc = Join-Path $cfgDir 'shortcuts.vdf'
            if (Test-Path -LiteralPath $sc) {
                try {
                    $vdf = Read-VdfBinario $sc
                    $raizSc = $vdf[(Find-VdfClave $vdf 'shortcuts')]
                    foreach ($k in @($raizSc.Keys)) {
                        $e = $raizSc[$k]
                        $copia = [ordered]@{}
                        foreach ($c in $e.Keys) { $copia[$c] = $e[$c] }
                        $kApp = Find-VdfClave $copia 'appid'
                        if ($kApp) { $copia[$kApp] = [BitConverter]::ToUInt32([BitConverter]::GetBytes([int]$copia[$kApp]), 0) }
                        $accesos += $copia
                    }
                } catch {
                    Write-Fallo "Cuenta $($u.Name): no se pudo leer shortcuts.vdf ($($_.Exception.Message))"
                }
            }

            # Colecciones
            $numCol = 0
            $cs = Join-Path $cfgDir 'cloudstorage'
            if (Test-Path -LiteralPath $cs) {
                Copy-Item -LiteralPath $cs -Destination (Join-Path $dest 'cloudstorage') -Recurse -Force
                $numCol = @(Get-ChildItem -LiteralPath $cs -File).Count
            }

            # Opciones de lanzamiento
            $lanz = [ordered]@{}
            $lc = Join-Path $cfgDir 'localconfig.vdf'
            if (Test-Path -LiteralPath $lc) {
                try {
                    $t = (Read-VdfTexto $lc).Datos
                    $nodo = $t
                    foreach ($paso in 'UserLocalConfigStore', 'Software', 'Valve', 'Steam', 'apps') {
                        $k = Find-VdfClave $nodo $paso
                        if (-not $k) { $nodo = $null; break }
                        $nodo = $nodo[$k]
                    }
                    if ($nodo) {
                        foreach ($app in @($nodo.Keys)) {
                            $kLo = Find-VdfClave $nodo[$app] 'LaunchOptions'
                            if ($kLo -and $nodo[$app][$kLo]) { $lanz[$app] = $nodo[$app][$kLo] }
                        }
                    }
                } catch {
                    Write-Aviso "Cuenta $($u.Name): no se pudo leer localconfig.vdf ($($_.Exception.Message))"
                }
            }

            $cuentas += [ordered]@{
                Id            = $u.Name
                Destino       = 'auto'
                Imagenes      = $true
                JuegosNoSteam = $true
                Colecciones   = $true
                Lanzamiento   = $true
                Accesos       = $accesos
                OpcionesLanzamiento = $lanz
            }
            $nombres = ($accesos | ForEach-Object { $_[(Find-VdfClave $_ 'AppName')] }) -join ', '
            Write-Ok "Cuenta $($u.Name): $numImg imagenes, $($accesos.Count) juegos no-Steam, $numCol archivos de colecciones, $($lanz.Count) opciones de lanzamiento"
            if ($nombres) { Write-Info "Juegos no-Steam: $nombres" }
        }

        if ($cuentas.Count -eq 0) { Write-Omitido 'No hay cuentas de Steam con configuracion'; return }
        $ruta = Join-Path $Ctx.DirConfig 'steam.psd1'
        Write-Psd1 -Ruta $ruta -Datos ([ordered]@{ RutaSteam = ''; Cuentas = $cuentas }) -Cabecera @(
            "Configuracion de Steam extraida de $env:COMPUTERNAME el $(Get-Date -Format 'yyyy-MM-dd HH:mm'):"
            ''
            "RutaSteam: carpeta de Steam en el equipo nuevo. Vacio = detectarla automaticamente."
            'Id       : cuenta de Steam de origen (carpeta userdata\<Id>). Sus archivos estan en config\steam\<Id>\.'
            "Destino  : 'auto' = la misma cuenta si existe, o la unica cuenta del equipo nuevo."
            '           Escribe un Id para forzar otra cuenta.'
            'Imagenes / JuegosNoSteam / Colecciones / Lanzamiento: $false para no aplicar esa parte.'
            'Accesos  : juegos no-Steam. Puedes cambiar Exe y StartDir si el programa esta en otra ruta.'
            '           No cambies appid: es el nombre de sus imagenes en grid.'
            "OpcionesLanzamiento: 'appid' = 'opciones' de juegos de Steam."
            ''
            'Al aplicar: Steam instalado, haber iniciado sesion al menos una vez y Steam cerrado.'
        )
        Write-Info "-> $ruta + $destBase"
    }

    Revisar = {
        param($Ctx)
        $cfg = Read-ConfigPsd1 (Join-Path $Ctx.DirConfig 'steam.psd1')
        foreach ($c in @($cfg.Cuentas)) {
            foreach ($e in @($c.Accesos)) {
                if (-not $e) { continue }
                $exe = ([string]$e['Exe']).Trim('"')
                if (Test-EnUnidadSistema $exe) {
                    Write-Aviso "Juego no-Steam '$($e['AppName'])' en $exe : esta en C:. Copialo y restauralo en la misma ruta (o edita Exe en steam.psd1)."
                }
            }
        }
        Write-Info 'Steam: los juegos de la biblioteca en C: se pierden; mueve la biblioteca a D: o vuelve a descargarlos.'
    }

    Aplicar = {
        param($Ctx)
        $cfg = Read-ConfigPsd1 (Join-Path $Ctx.DirConfig 'steam.psd1')

        $steam = $cfg.RutaSteam
        if (-not $steam) { $steam = (Get-ItemProperty 'HKCU:\Software\Valve\Steam' -ErrorAction SilentlyContinue).SteamPath }
        if (-not $steam) { $steam = (Get-ItemProperty 'HKLM:\SOFTWARE\WOW6432Node\Valve\Steam' -ErrorAction SilentlyContinue).InstallPath }
        if ($steam) { $steam = $steam -replace '/', '\' }
        if (-not $steam -or -not (Test-Path -LiteralPath $steam)) {
            Add-Pendiente 'Instala Steam, inicia sesion y vuelve a ejecutar -Solo Steam'
            return
        }
        if (Get-Process -Name 'steam' -ErrorAction SilentlyContinue) {
            if (Test-Simulacion) {
                Write-Aviso 'Steam esta abierto: al aplicar de verdad habra que cerrarlo (Steam > Salir)'
            } else {
                Write-Fallo 'Steam esta abierto: cierralo (Steam > Salir) y vuelve a ejecutar -Solo Steam'
                return
            }
        } else {
            Write-Ok 'Steam instalado y cerrado'
        }

        $userdata = Join-Path $steam 'userdata'
        $destinos = @()
        if (Test-Path -LiteralPath $userdata) {
            $destinos = @(Get-ChildItem -LiteralPath $userdata -Directory | Where-Object { $_.Name -match '^\d+$' -and $_.Name -ne '0' } | ForEach-Object { $_.Name })
        }
        if ($destinos.Count -eq 0) {
            Add-Pendiente 'Inicia sesion en Steam al menos una vez, cierralo y vuelve a ejecutar -Solo Steam'
            return
        }

        $cuentas = @($cfg.Cuentas | Where-Object { $_ })
        foreach ($c in $cuentas) {
            # ---- Cuenta destino ----
            $dest = $null
            if ($c.Destino -and $c.Destino -ne 'auto') {
                if ($destinos -contains [string]$c.Destino) { $dest = [string]$c.Destino }
                else { Write-Fallo "Cuenta destino $($c.Destino) no existe en $userdata"; continue }
            } elseif ($destinos -contains [string]$c.Id) {
                $dest = [string]$c.Id
            } elseif ($destinos.Count -eq 1 -and $cuentas.Count -eq 1) {
                $dest = $destinos[0]
            } else {
                Write-Fallo "Cuenta $($c.Id): no se sabe a que cuenta aplicarla (hay $($destinos.Count)). Indica Destino en steam.psd1"
                continue
            }
            Write-Info "Cuenta $($c.Id) -> $dest"
            $origen = Join-Path (Join-Path $Ctx.DirConfig 'steam') $c.Id
            $cfgDir = Join-Path (Join-Path $userdata $dest) 'config'

            # ---- Imagenes ----
            $grid = Join-Path $origen 'grid'
            if ($c.Imagenes -and (Test-Path -LiteralPath $grid)) {
                $n = @(Get-ChildItem -LiteralPath $grid -File -Recurse).Count
                $null = Invoke-Cambio "$n imagenes personalizadas" {
                    $dGrid = Join-Path $cfgDir 'grid'
                    if (-not (Test-Path -LiteralPath $dGrid)) { New-Item -ItemType Directory -Path $dGrid -Force -ErrorAction Stop | Out-Null }
                    Copy-Item -Path (Join-Path $grid '*') -Destination $dGrid -Recurse -Force -ErrorAction Stop
                }
            }

            # ---- Juegos no-Steam ----
            $accesos = @($c.Accesos | Where-Object { $_ })
            if ($c.JuegosNoSteam -and $accesos.Count -gt 0) {
                $orden = @('appid', 'AppName', 'Exe', 'StartDir', 'icon', 'ShortcutPath', 'LaunchOptions', 'IsHidden',
                    'AllowDesktopConfig', 'AllowOverlay', 'OpenVR', 'Devkit', 'DevkitGameID', 'DevkitOverrideAppID',
                    'LastPlayTime', 'FlatpakAppID', 'sortas', 'tags')
                $nuevos = [ordered]@{}
                foreach ($a in $accesos) {
                    $e = [ordered]@{}
                    foreach ($k in $orden) { if ($a.ContainsKey($k)) { $e[$k] = $a[$k] } }
                    foreach ($k in $a.Keys) { if (-not $e.Contains($k)) { $e[$k] = $a[$k] } }
                    $kApp = Find-VdfClave $e 'appid'
                    $e[$kApp] = [uint32][long]$e[$kApp]
                    # tags: mapa '0','1'... con cadenas
                    $kTags = Find-VdfClave $e 'tags'
                    if ($kTags) {
                        $t = [ordered]@{}
                        if ($e[$kTags]) { foreach ($tk in ($e[$kTags].Keys | Sort-Object { [int]$_ })) { $t[[string]$tk] = [string]$e[$kTags][$tk] } }
                        $e[$kTags] = $t
                    }
                    foreach ($k in @($e.Keys)) {
                        if ($e[$k] -is [long] -and $k -ne $kApp) { $e[$k] = [int]$e[$k] }
                    }
                    $nuevos[[string]$e[$kApp]] = $e
                    $exe = ([string]$e['Exe']).Trim('"')
                    if ($exe -and -not (Test-Path -LiteralPath $exe)) {
                        Write-Aviso "$($e['AppName']): no existe $exe (el acceso se crea igualmente; restaura el programa o edita Exe)"
                    }
                }

                $sc = Join-Path $cfgDir 'shortcuts.vdf'
                $null = Invoke-Cambio "$($accesos.Count) juegos no-Steam: $(($accesos | ForEach-Object { $_['AppName'] }) -join ', ')" {
                    # Conserva los accesos que ya existan en destino y no esten en la configuracion
                    $final = New-Object System.Collections.ArrayList
                    if (Test-Path -LiteralPath $sc) {
                        $actual = Read-VdfBinario $sc
                        $kRaiz = Find-VdfClave $actual 'shortcuts'
                        if ($kRaiz) {
                            foreach ($k in @($actual[$kRaiz].Keys)) {
                                $e = $actual[$kRaiz][$k]
                                $id = [string][BitConverter]::ToUInt32([BitConverter]::GetBytes([int]$e[(Find-VdfClave $e 'appid')]), 0)
                                if (-not $nuevos.Contains($id)) { [void]$final.Add($e) }
                            }
                        }
                        Copy-Item -LiteralPath $sc -Destination "$sc.wmud.bak" -Force -ErrorAction Stop
                    }
                    foreach ($k in $nuevos.Keys) { [void]$final.Add($nuevos[$k]) }
                    $mapa = [ordered]@{}
                    for ($i = 0; $i -lt $final.Count; $i++) { $mapa[[string]$i] = $final[$i] }
                    if (-not (Test-Path -LiteralPath $cfgDir)) { New-Item -ItemType Directory -Path $cfgDir -Force -ErrorAction Stop | Out-Null }
                    Write-VdfBinario -Datos ([ordered]@{ shortcuts = $mapa }) -Ruta $sc
                }
            }

            # ---- Colecciones ----
            $cs = Join-Path $origen 'cloudstorage'
            if ($c.Colecciones -and (Test-Path -LiteralPath $cs)) {
                $null = Invoke-Cambio 'Colecciones (cloudstorage)' {
                    $dCs = Join-Path $cfgDir 'cloudstorage'
                    if (Test-Path -LiteralPath $dCs) {
                        $bak = "$dCs.wmud.bak"
                        if (Test-Path -LiteralPath $bak) { Remove-Item -LiteralPath $bak -Recurse -Force -ErrorAction Stop }
                        Copy-Item -LiteralPath $dCs -Destination $bak -Recurse -Force -ErrorAction Stop
                    } else {
                        New-Item -ItemType Directory -Path $dCs -Force -ErrorAction Stop | Out-Null
                    }
                    Copy-Item -Path (Join-Path $cs '*') -Destination $dCs -Force -ErrorAction Stop
                }
                Write-Info 'Steam sincroniza las colecciones con su nube: al abrirlo puede imponer la version de la nube.'
            }

            # ---- Opciones de lanzamiento ----
            $opc = $c.OpcionesLanzamiento
            if ($c.Lanzamiento -and $opc -and $opc.Count -gt 0) {
                $lc = Join-Path $cfgDir 'localconfig.vdf'
                if (-not (Test-Path -LiteralPath $lc)) {
                    Add-Pendiente "Opciones de lanzamiento: abre Steam una vez con la cuenta $dest, cierralo y vuelve a ejecutar -Solo Steam"
                } else {
                    $leido = Read-VdfTexto $lc
                    if ($leido.Duplicados) {
                        Write-Aviso 'localconfig.vdf tiene claves duplicadas: no se modifica para no perder datos. Pon las opciones a mano:'
                        foreach ($k in $opc.Keys) { Write-Info "  appid $k -> $($opc[$k])" }
                    } else {
                        $null = Invoke-Cambio "$($opc.Count) opciones de lanzamiento" {
                            $nodo = $leido.Datos
                            foreach ($paso in 'UserLocalConfigStore', 'Software', 'Valve', 'Steam', 'apps') {
                                $k = Find-VdfClave $nodo $paso
                                if (-not $k) { $k = $paso; $nodo[$k] = [ordered]@{} }
                                $nodo = $nodo[$k]
                            }
                            foreach ($app in $opc.Keys) {
                                $kApp = Find-VdfClave $nodo ([string]$app)
                                if (-not $kApp) { $kApp = [string]$app; $nodo[$kApp] = [ordered]@{} }
                                $kLo = Find-VdfClave $nodo[$kApp] 'LaunchOptions'
                                if (-not $kLo) { $kLo = 'LaunchOptions' }
                                $nodo[$kApp][$kLo] = [string]$opc[$app]
                            }
                            Copy-Item -LiteralPath $lc -Destination "$lc.wmud.bak" -Force -ErrorAction Stop
                            Write-VdfTexto -Datos $leido.Datos -Ruta $lc
                        }
                    }
                }
            }
        }
    }
}
