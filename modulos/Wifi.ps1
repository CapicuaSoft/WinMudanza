# Modulo Wifi: redes Wi-Fi guardadas, con su contrasena.
# - Extraer: netsh wlan export profile key=clear -> config\wifi\*.xml (la contrasena va en claro;
#   necesita Administrador para incluirla).
# - Aplicar: netsh wlan add profile user=all (para todos los usuarios) de las que falten.
# Va pronto (Orden 12) para tener internet antes de instalar paquetes u Office.

@{
    Nombre        = 'Wifi'
    Descripcion   = 'Redes Wi-Fi guardadas (con contrasena)'
    Orden         = 12
    DependeDe     = @()
    ArchivoConfig = 'wifi.psd1'

    Extraer = {
        param($Ctx)
        $redes = @()
        $svc = Get-Service -Name wlansvc -ErrorAction SilentlyContinue
        $dir = Join-Path $Ctx.DirConfig 'wifi'
        if (-not $svc -or $svc.Status -ne 'Running') {
            Write-Omitido 'Este equipo no usa Wi-Fi (servicio wlansvc detenido o inexistente)'
        } else {
            if (Test-Path -LiteralPath $dir) { Remove-Item -LiteralPath $dir -Recurse -Force }
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
            $out = & netsh.exe wlan export profile key=clear folder="$dir" 2>&1
            if ($LASTEXITCODE -ne 0) { Write-Fallo "netsh wlan export fallo: $(($out | Select-Object -Last 2) -join ' ')" }
            foreach ($f in Get-ChildItem -LiteralPath $dir -Filter '*.xml' -ErrorAction SilentlyContinue | Sort-Object Name) {
                try {
                    [xml]$x = Get-Content -LiteralPath $f.FullName -Raw -Encoding UTF8
                    $nombre = [string]$x.WLANProfile.name
                    $clave = $x.WLANProfile.MSM.security.sharedKey.keyMaterial
                    $redes += [ordered]@{ Nombre = $nombre; Archivo = $f.Name }
                    if ($x.WLANProfile.MSM.security.sharedKey -and -not $clave) {
                        Write-Aviso "${nombre}: sin contrasena (ejecuta Extraer como Administrador para incluirla)"
                    } else {
                        Write-Ok "Red $nombre"
                    }
                } catch { Write-Aviso "$($f.Name): no se pudo leer ($($_.Exception.Message))" }
            }
            if ($redes.Count -eq 0) { Write-Omitido 'No hay redes Wi-Fi guardadas' }
        }
        $ruta = Join-Path $Ctx.DirConfig 'wifi.psd1'
        Write-Psd1 -Ruta $ruta -Datos ([ordered]@{ Redes = $redes }) -Cabecera @(
            "Redes Wi-Fi extraidas de $env:COMPUTERNAME el $(Get-Date -Format 'yyyy-MM-dd HH:mm'):"
            ''
            'Redes: cada red apunta a su perfil en config\wifi\ (XML de Windows con la contrasena EN CLARO).'
            'Para no anadir una red, comenta (#) o borra su bloque. Las que ya existan no se tocan.'
            'ATENCION: config\wifi\ contiene contrasenas. No lo compartas.'
        )
        Write-Info "-> $ruta"
    }

    Aplicar = {
        param($Ctx)
        $cfg = Read-ConfigPsd1 (Join-Path $Ctx.DirConfig 'wifi.psd1')
        $redes = @($cfg.Redes | Where-Object { $_ -and $_.Archivo })
        if ($redes.Count -eq 0) { Write-Omitido 'No hay redes Wi-Fi que anadir'; return }
        $svc = Get-Service -Name wlansvc -ErrorAction SilentlyContinue
        if (-not $svc) { Write-Aviso 'Este equipo no tiene Wi-Fi (no existe el servicio wlansvc); se omiten las redes'; return }
        if ($svc.Status -ne 'Running' -and -not (Test-Simulacion)) {
            try { Start-Service -Name wlansvc -ErrorAction Stop } catch {
                Write-Aviso "No se pudo iniciar el servicio Wi-Fi (wlansvc): $($_.Exception.Message)"; return
            }
        }
        foreach ($r in $redes) {
            $xml = Join-Path (Join-Path $Ctx.DirConfig 'wifi') $r.Archivo
            if (-not (Test-Path -LiteralPath $xml)) { Write-Fallo "$($r.Nombre): no existe $xml"; continue }
            $null = & netsh.exe wlan show profile name="$($r.Nombre)" 2>&1
            if ($LASTEXITCODE -eq 0) { Write-Omitido "Red $($r.Nombre) ya existe"; continue }
            $null = Invoke-Cambio "Anadir red Wi-Fi $($r.Nombre) (todos los usuarios)" {
                $out = & netsh.exe wlan add profile filename="$xml" user=all 2>&1
                if ($LASTEXITCODE -ne 0) { throw (($out | ForEach-Object { [string]$_ } | Where-Object { $_.Trim() }) -join ' ') }
            }
        }
    }
}
