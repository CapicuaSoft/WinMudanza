# Modulo Caracteristicas: caracteristicas opcionales de Windows
# ("Activar o desactivar las caracteristicas de Windows": Hyper-V, WSL, Sandbox, .NET 3.5...).
# - Extraer guarda las que estan activadas (se lee con CIM, no necesita Administrador).
# - Aplicar SOLO ACTIVA las que falten; nunca desactiva ninguna.
# - Muchas requieren reiniciar: queda como pendiente.
# Va antes de Paquetes para que la virtualizacion (WSL, Hyper-V) este lista antes de instalar
# programas que la usan (Docker...).

@{
    Nombre        = 'Caracteristicas'
    Descripcion   = 'Caracteristicas de Windows (Hyper-V, WSL, Sandbox, .NET 3.5...)'
    Orden         = 15
    DependeDe     = @()
    ArchivoConfig = 'caracteristicas.psd1'

    Extraer = {
        param($Ctx)
        try {
            $activas = @(Get-CimInstance -ClassName Win32_OptionalFeature -ErrorAction Stop |
                Where-Object { $_.InstallState -eq 1 } | Sort-Object Name)
        } catch {
            Write-Fallo "No se pudieron leer las caracteristicas de Windows ($($_.Exception.Message))"
            return
        }
        foreach ($f in $activas) { Write-Ok ("{0,-50} {1}" -f $f.Name, $f.Caption) }

        $leyenda = @($activas | ForEach-Object { '  {0,-50} {1}' -f $_.Name, $_.Caption })
        $ruta = Join-Path $Ctx.DirConfig 'caracteristicas.psd1'
        Write-Psd1 -Ruta $ruta -Datos ([ordered]@{ Activar = @($activas | ForEach-Object { [string]$_.Name }) }) -Cabecera (@(
            "Caracteristicas de Windows activadas en $env:COMPUTERNAME el $(Get-Date -Format 'yyyy-MM-dd HH:mm'):"
            ''
            'Activar: se activan las que falten en el equipo nuevo. NUNCA se desactiva ninguna.'
            'Muchas ya vienen activadas en Windows 11 (impresion a PDF, Windows Search, multimedia...);'
            'esas se saltan. Para no activar una, comenta su linea con # o borrala.'
            'Las que no existan en la edicion de Windows de destino (p. ej. Hyper-V en Home) se avisan y se saltan.'
            ''
            '  Nombre                                             Descripcion'
        ) + $leyenda)
        Write-Info "-> $ruta"
    }

    Aplicar = {
        param($Ctx)
        $cfg = Read-ConfigPsd1 (Join-Path $Ctx.DirConfig 'caracteristicas.psd1')
        $lista = @($cfg.Activar | Where-Object { $_ })
        if ($lista.Count -eq 0) { Write-Omitido 'No hay caracteristicas que activar'; return }

        $estado = @{}
        try {
            foreach ($f in Get-CimInstance -ClassName Win32_OptionalFeature -ErrorAction Stop) { $estado[$f.Name.ToLower()] = $f }
        } catch {
            Write-Fallo "No se pudieron leer las caracteristicas de Windows ($($_.Exception.Message))"
            return
        }

        $reiniciar = @()
        $marca = @{ Reinicio = $false }   # tabla: se puede modificar desde dentro de Invoke-Cambio
        foreach ($nombre in $lista) {
            $f = $estado[([string]$nombre).ToLower()]
            if (-not $f) { Write-Aviso "${nombre}: no existe en esta edicion de Windows; se omite"; continue }
            if ($f.InstallState -eq 1) { Write-Omitido "$nombre ya activada"; continue }
            $desc = "Activar $nombre ($($f.Caption))"
            if ($nombre -eq 'NetFx3') { $desc += ' - se descarga de Windows Update' }
            $null = Invoke-Cambio $desc {
                $r = Enable-WindowsOptionalFeature -Online -FeatureName $nombre -All -NoRestart -WarningAction SilentlyContinue -ErrorAction Stop
                if ($r.RestartNeeded) { $marca.Reinicio = $true }
            }
            if ($marca.Reinicio) { $reiniciar += $nombre; $marca.Reinicio = $false }
        }
        if ($reiniciar.Count -gt 0) {
            Add-Pendiente "Reinicia el equipo para terminar de activar: $($reiniciar -join ', ')"
            # Los modulos siguientes (Paquetes: Docker, WSL...) pueden necesitarlas ya activas
            Set-ReinicioNecesario "activar $($reiniciar -join ', ')"
        }
    }
}
