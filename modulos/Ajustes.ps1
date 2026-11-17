# Modulo Ajustes: ejecuta los ajustes de la carpeta modulos\Ajustes\ segun config\ajustes.psd1.
# No tiene Extraer: sus valores se definen a mano en config\ajustes.psd1
# (siempre se lee de config\, aunque se use -DirConfig).

@{
    Nombre        = 'Ajustes'
    Descripcion   = 'Menu, terminales, Edge, Explorador, energia y PowerShell'
    Orden         = 10
    DependeDe     = @()
    ArchivoConfig = $null
    Extraer       = $null
    Aplicar       = {
        param($Ctx)
        $rutaCfg = Join-Path $Ctx.Raiz 'config\ajustes.psd1'
        if (-not (Test-Path -LiteralPath $rutaCfg)) { Write-Fallo "No existe $rutaCfg"; return }
        $cfg = Read-ConfigPsd1 $rutaCfg

        $ajustes = @(Get-ChildItem -LiteralPath (Join-Path $Ctx.Raiz 'modulos\Ajustes') -Filter '*.ps1' | Sort-Object Name)
        foreach ($archivo in $ajustes) {
            $a = & $archivo.FullName
            $sec = $cfg[$a.Clave]
            Write-Host ''
            Write-Host ("  > {0} - {1}" -f $archivo.BaseName.Substring(0, 2), $a.Nombre) -ForegroundColor White
            Write-Log "> $($a.Nombre)"
            if (-not $sec -or -not $sec.Activo) {
                Write-Omitido "Desactivado en ajustes.psd1 ($($a.Clave).Activo)"
                continue
            }
            try {
                $null = & $a.Aplicar $sec $Ctx
            } catch {
                Write-Fallo "$($a.Nombre): $($_.Exception.Message)"
            }
        }

        if ($cfg.ReiniciarExplorer) {
            $null = Invoke-Cambio 'Reiniciar el Explorador' { Stop-Process -Name explorer -Force -ErrorAction Stop }
        } else {
            Write-Info 'Cierra sesion o reinicia el Explorador para ver todos los cambios.'
        }
    }
}
