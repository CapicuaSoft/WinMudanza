# Modulo UniGetUI: configuracion de UniGetUI (%LOCALAPPDATA%\UniGetUI).
# UniGetUI guarda cada opcion como un archivo en Configuration\:
#   - archivo vacio      -> opcion activada (si existe)
#   - archivo con texto  -> valor de la opcion
#   - DisabledManagers.json -> gestores de paquetes desactivados
# Mas InstallationOptions\ (opciones de instalacion globales y por paquete).
# Se extrae del usuario que ejecuta y se aplica a TODOS los perfiles (y Default).
# No se copian historial, caches, telemetria ni estado temporal.

@{
    Nombre        = 'UniGetUI'
    Descripcion   = 'Configuracion de UniGetUI'
    Orden         = 50
    DependeDe     = @('Paquetes')
    ArchivoConfig = 'unigetui.psd1'

    Extraer = {
        param($Ctx)
        $origen = Join-Path $env:LOCALAPPDATA 'UniGetUI'
        $conf = Join-Path $origen 'Configuration'
        if (-not (Test-Path -LiteralPath $conf)) { Write-Omitido "UniGetUI no tiene configuracion en $origen"; return }

        $excluir = @(
            'OperationHistory.json', 'MaintenanceTaskLastRun.json', 'TelemetryClientToken', 'WindowGeometry',
            'LastKnownBuildNumber', 'WinGetAlreadyUpgradedPackages.json', 'WinGetUpgradeAttempts.json',
            'DisabledManagers.json'
        )
        $destino = Join-Path $Ctx.DirConfig 'unigetui'
        if (Test-Path -LiteralPath $destino) { Remove-Item -LiteralPath $destino -Recurse -Force }
        New-Item -ItemType Directory -Path (Join-Path $destino 'Configuration') -Force | Out-Null

        $opciones = @()
        $valores = @()
        foreach ($f in Get-ChildItem -LiteralPath $conf -File -Force) {
            if ($excluir -contains $f.Name) { continue }
            if ($f.Length -eq 0) {
                $opciones += $f.Name
            } else {
                Copy-Item -LiteralPath $f.FullName -Destination (Join-Path $destino "Configuration\$($f.Name)") -Force
                $valores += $f.Name
            }
        }

        $gestores = [ordered]@{}
        $dm = Join-Path $conf 'DisabledManagers.json'
        if (Test-Path -LiteralPath $dm) {
            $json = Get-Content -LiteralPath $dm -Raw -Encoding UTF8 | ConvertFrom-Json
            foreach ($p in $json.PSObject.Properties) { $gestores[$p.Name] = -not [bool]$p.Value }
        }

        $instOpc = Join-Path $origen 'InstallationOptions'
        $numInst = 0
        if (Test-Path -LiteralPath $instOpc) {
            Copy-Item -LiteralPath $instOpc -Destination (Join-Path $destino 'InstallationOptions') -Recurse -Force
            $numInst = @(Get-ChildItem -LiteralPath $instOpc -File -Recurse).Count
        }

        # Si una tarea programada lanza UniGetUI (p. ej. como administrador al iniciar sesion),
        # se quitara su inicio automatico normal para que no arranque dos veces
        $porTarea = @(Get-TareasUniGetUI).Count -gt 0
        if ($porTarea) { Write-Ok 'UniGetUI se inicia con una tarea programada: se quitara su inicio automatico' }

        $datos = [ordered]@{
            Gestores          = $gestores
            OpcionesActivadas = @($opciones | Sort-Object)
            ArchivosDeValor   = @($valores | Sort-Object)
            OpcionesInstalacion = ($numInst -gt 0)
            QuitarInicioAutomatico = $porTarea
        }
        $ruta = Join-Path $Ctx.DirConfig 'unigetui.psd1'
        Write-Psd1 -Ruta $ruta -Datos $datos -Cabecera @(
            "Configuracion de UniGetUI extraida de $env:USERNAME en $env:COMPUTERNAME el $(Get-Date -Format 'yyyy-MM-dd HH:mm')"
            ''
            'Gestores           : $true = activo, $false = desactivado en UniGetUI.'
            'OpcionesActivadas  : opciones marcadas (cada una es un archivo vacio). Comenta con # para no aplicarla.'
            'ArchivosDeValor    : opciones con valor; se copian desde config\unigetui\Configuration\.'
            'OpcionesInstalacion: $true copia config\unigetui\InstallationOptions\ (opciones por paquete).'
            'QuitarInicioAutomatico: $true quita la entrada Run de UniGetUI (todos los perfiles y equipo),'
            '  porque lo inicia una tarea programada (p. ej. \Personal\, como administrador; modulo Tareas).'
            'Se aplica a todos los perfiles de usuario y al perfil Default. UniGetUI debe estar cerrado.'
        )
        $activos = ($gestores.Keys | Where-Object { $gestores[$_] }) -join ', '
        Write-Ok "Gestores activos: $activos"
        Write-Ok "$($opciones.Count) opciones activadas, $($valores.Count) archivos de valor, $numInst opciones de instalacion"
        Write-Info "-> $ruta + $destino"
    }

    Aplicar = {
        param($Ctx)
        $cfg = Read-ConfigPsd1 (Join-Path $Ctx.DirConfig 'unigetui.psd1')
        $origen = Join-Path $Ctx.DirConfig 'unigetui'

        if (Get-Process -Name 'UniGetUI', 'WingetUI' -ErrorAction SilentlyContinue) {
            if (Test-Simulacion) {
                Write-Aviso 'UniGetUI esta abierto: al aplicar de verdad habra que cerrarlo'
            } else {
                Write-Fallo 'UniGetUI esta abierto: cierralo (tambien desde la bandeja del sistema) y vuelve a ejecutar -Solo UniGetUI'
                return
            }
        }

        $jsonGestores = $null
        if ($cfg.Gestores -and $cfg.Gestores.Count -gt 0) {
            $dis = [ordered]@{}
            foreach ($k in ($cfg.Gestores.Keys | Sort-Object)) { $dis[$k] = -not [bool]$cfg.Gestores[$k] }
            $jsonGestores = $dis | ConvertTo-Json
        }

        foreach ($p in Get-PerfilesUsuario) {
            $dest = Join-Path $p.Ruta 'AppData\Local\UniGetUI'
            $null = Invoke-Cambio "UniGetUI: $($p.Nombre)" {
                $conf = Join-Path $dest 'Configuration'
                if (-not (Test-Path -LiteralPath $conf)) { New-Item -ItemType Directory -Path $conf -Force -ErrorAction Stop | Out-Null }
                if ($jsonGestores) {
                    [IO.File]::WriteAllText((Join-Path $conf 'DisabledManagers.json'), $jsonGestores, (New-Object System.Text.UTF8Encoding $false))
                }
                foreach ($o in @($cfg.OpcionesActivadas | Where-Object { $_ })) {
                    $f = Join-Path $conf $o
                    if (-not (Test-Path -LiteralPath $f)) { New-Item -ItemType File -Path $f -Force -ErrorAction Stop | Out-Null }
                }
                foreach ($v in @($cfg.ArchivosDeValor | Where-Object { $_ })) {
                    $src = Join-Path $origen "Configuration\$v"
                    if (Test-Path -LiteralPath $src) { Copy-Item -LiteralPath $src -Destination (Join-Path $conf $v) -Force -ErrorAction Stop }
                }
                $srcInst = Join-Path $origen 'InstallationOptions'
                if ($cfg.OpcionesInstalacion -and (Test-Path -LiteralPath $srcInst)) {
                    $dInst = Join-Path $dest 'InstallationOptions'
                    if (-not (Test-Path -LiteralPath $dInst)) { New-Item -ItemType Directory -Path $dInst -Force -ErrorAction Stop | Out-Null }
                    Copy-Item -Path (Join-Path $srcInst '*') -Destination $dInst -Recurse -Force -ErrorAction Stop
                }
            }
        }

        # ---------- Inicio automatico ----------
        # Lo inicia una tarea programada: se quita la entrada Run (WingetUI) que crean UniGetUI y su
        # instalador, en el equipo y en cada perfil, para que no arranque dos veces (una sin elevar).
        if ($cfg.QuitarInicioAutomatico) {
            $enConfig = $false
            $dirTareas = Join-Path $Ctx.DirConfig 'tareas'
            if (Test-Path -LiteralPath $dirTareas) {
                $enConfig = @(Get-ChildItem -LiteralPath $dirTareas -Filter '*.xml' -Recurse |
                    Where-Object { (Get-Content -LiteralPath $_.FullName -Raw) -match 'UniGetUI\.exe' }).Count -gt 0
            }
            if (-not $enConfig -and @(Get-TareasUniGetUI).Count -eq 0) {
                Write-Aviso 'UniGetUI: ninguna tarea programada lo inicia (ni en config\tareas\); al quitar su inicio automatico no arrancara al iniciar sesion'
            }
            $quitar = {
                param([string]$Run, [string]$Donde)
                $props = (Get-ItemProperty -LiteralPath $Run -ErrorAction SilentlyContinue).PSObject.Properties |
                    Where-Object { $_.Name -notlike 'PS*' -and [string]$_.Value -match 'UniGetUI\.exe|WingetUI\.exe' }
                foreach ($v in @($props)) {
                    $nombre = $v.Name
                    $null = Invoke-Cambio "UniGetUI: quitar inicio automatico '$nombre' ($Donde)" {
                        Remove-ItemProperty -LiteralPath $Run -Name $nombre -ErrorAction Stop
                    }
                }
                return @($props).Count
            }
            $cuenta = @{ N = 0 }
            $cuenta.N += & $quitar 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run' 'equipo'
            Invoke-EnPerfiles {
                param($P)
                $cuenta.N += & $quitar "$($P.HKCU)\Software\Microsoft\Windows\CurrentVersion\Run" $P.Nombre
            }
            if ($cuenta.N -eq 0) { Write-Omitido 'UniGetUI: sin inicio automatico (lo inicia la tarea programada)' }
        }
    }
}
