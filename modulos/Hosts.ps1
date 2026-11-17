# Modulo Hosts: entradas personalizadas del archivo hosts (C:\Windows\System32\drivers\etc\hosts).
# - Extraer: las lineas que no son comentarios ni estan vacias.
# - Aplicar: anade al final las que falten (antes guarda hosts.wmud.bak). Nunca borra lineas.

@{
    Nombre        = 'Hosts'
    Descripcion   = 'Entradas personalizadas del archivo hosts'
    Orden         = 36
    DependeDe     = @()
    ArchivoConfig = 'hosts.psd1'

    Extraer = {
        param($Ctx)
        $archivo = Join-Path $env:SystemRoot 'System32\drivers\etc\hosts'
        $entradas = @()
        if (Test-Path -LiteralPath $archivo) {
            $entradas = @(Get-Content -LiteralPath $archivo -ErrorAction SilentlyContinue |
                Where-Object { $_ -match '^\s*[^#\s]' } | ForEach-Object { ($_ -replace '\s+', ' ').Trim() })
        }
        if ($entradas.Count -eq 0) { Write-Omitido 'El archivo hosts no tiene entradas personalizadas' }
        foreach ($e in $entradas) { Write-Ok $e }
        $ruta = Join-Path $Ctx.DirConfig 'hosts.psd1'
        Write-Psd1 -Ruta $ruta -Datos ([ordered]@{ Entradas = $entradas }) -Cabecera @(
            "Entradas del archivo hosts de $env:COMPUTERNAME el $(Get-Date -Format 'yyyy-MM-dd HH:mm'):"
            ''
            "Entradas: 'IP nombre [nombre2...]'. Se anaden las que falten; nunca se borra ninguna."
            'Comenta (#) o borra las que no quieras.'
        )
        Write-Info "-> $ruta"
    }

    Aplicar = {
        param($Ctx)
        $cfg = Read-ConfigPsd1 (Join-Path $Ctx.DirConfig 'hosts.psd1')
        $entradas = @($cfg.Entradas | Where-Object { $_ })
        if ($entradas.Count -eq 0) { Write-Omitido 'No hay entradas que anadir'; return }
        $archivo = Join-Path $env:SystemRoot 'System32\drivers\etc\hosts'
        $actuales = @()
        if (Test-Path -LiteralPath $archivo) {
            $actuales = @(Get-Content -LiteralPath $archivo | ForEach-Object { ($_ -replace '\s+', ' ').Trim() })
        }
        $faltan = @($entradas | ForEach-Object { ($_ -replace '\s+', ' ').Trim() } | Where-Object { $actuales -notcontains $_ })
        foreach ($e in $entradas) { if ($faltan -notcontains (($e -replace '\s+', ' ').Trim())) { Write-Omitido "$e (ya esta)" } }
        if ($faltan.Count -eq 0) { return }
        $null = Invoke-Cambio "hosts: anadir $($faltan.Count) entradas ($($faltan -join '; '))" {
            if (Test-Path -LiteralPath $archivo) { Copy-Item -LiteralPath $archivo -Destination "$archivo.wmud.bak" -Force -ErrorAction Stop }
            $texto = "`r`n# Anadido por WinMudanza $(Get-Date -Format 'yyyy-MM-dd')`r`n" + ($faltan -join "`r`n") + "`r`n"
            [IO.File]::AppendAllText($archivo, $texto, [Text.Encoding]::ASCII)
        }
        Write-Info 'Si Microsoft Defender avisa de una modificacion de hosts, revisa que entrada lo provoca.'
    }
}
