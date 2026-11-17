# 03 - Configura Microsoft Edge mediante directivas (HKLM\SOFTWARE\Policies\Microsoft\Edge).
# Con TipoDirectiva = 'Recomendada' la pagina de inicio y el buscador se escriben en ...\Edge\Recommended
# (valores iniciales que el usuario puede cambiar).
# Nota: Edge muestra "Administrado por tu organizacion" mientras existan directivas.

@{
    Clave  = 'Edge'
    Nombre = 'Microsoft Edge'
    Aplicar = {
        param($Cfg, $Ctx)
        $obligatoria = 'HKLM:\SOFTWARE\Policies\Microsoft\Edge'
        $base = $obligatoria
        if ($Cfg.TipoDirectiva -eq 'Recomendada') { $base = "$obligatoria\Recommended" }

        # --- Pagina de inicio y arranque ---
        if ($Cfg.PaginaInicio) {
            $ok = Set-RegValor -Ruta $base -Nombre 'HomepageLocation' -Valor $Cfg.PaginaInicio -Tipo String
            $ok = (Set-RegValor -Ruta $base -Nombre 'HomepageIsNewTabPage' -Valor 0) -and $ok
            $ok = (Set-RegValor -Ruta $base -Nombre 'RestoreOnStartup' -Valor 4) -and $ok       # 4 = abrir URLs concretas
            $ok = (Set-RegValor -Ruta "$base\RestoreOnStartupURLs" -Nombre '1' -Valor $Cfg.PaginaInicio -Tipo String) -and $ok
            if ($ok -and -not (Test-Simulacion)) { Write-Ok "Pagina de inicio: $($Cfg.PaginaInicio) ($($Cfg.TipoDirectiva))" }
        }
        if ($Cfg.BotonInicio) {
            $null = Set-RegValor -Ruta $base -Nombre 'ShowHomeButton' -Valor 1
        }

        # --- Buscador predeterminado ---
        $bus = $Cfg.Buscador
        if ($bus -and $bus.Nombre) {
            $ok = Set-RegValor -Ruta $base -Nombre 'DefaultSearchProviderEnabled' -Valor 1
            $ok = (Set-RegValor -Ruta $base -Nombre 'DefaultSearchProviderName'       -Valor $bus.Nombre  -Tipo String) -and $ok
            $ok = (Set-RegValor -Ruta $base -Nombre 'DefaultSearchProviderKeyword'    -Valor $bus.Palabra -Tipo String) -and $ok
            $ok = (Set-RegValor -Ruta $base -Nombre 'DefaultSearchProviderSearchURL'  -Valor $bus.Url     -Tipo String) -and $ok
            if ($bus.Sugerir) { $ok = (Set-RegValor -Ruta $base -Nombre 'DefaultSearchProviderSuggestURL' -Valor $bus.Sugerir -Tipo String) -and $ok }
            if ($bus.Icono)   { $ok = (Set-RegValor -Ruta $base -Nombre 'DefaultSearchProviderIconURL'    -Valor $bus.Icono   -Tipo String) -and $ok }
            if ($ok -and -not (Test-Simulacion)) { Write-Ok "Buscador: $($bus.Nombre)" }
        }

        # --- Nueva pestana y barra de direcciones (siempre obligatorias) ---
        if ($Cfg.SinFeedNuevaPestana) {
            $ok = Set-RegValor -Ruta $obligatoria -Nombre 'NewTabPageContentEnabled' -Valor 0
            $ok = (Set-RegValor -Ruta $obligatoria -Nombre 'NewTabPageHideDefaultTopSites' -Valor 1) -and $ok
            if ($ok -and -not (Test-Simulacion)) { Write-Ok 'Nueva pestana sin noticias ni sitios sugeridos' }
        }
        if ($Cfg.SinSugerenciasBing) {
            $ok = Set-RegValor -Ruta $obligatoria -Nombre 'AddressBarMicrosoftSearchInBingProviderEnabled' -Valor 0
            if ($ok -and -not (Test-Simulacion)) { Write-Ok 'Sin sugerencias de Bing en la barra de direcciones' }
        }

        if ($Cfg.CerrarEdge -and (Get-Process -Name msedge -ErrorAction SilentlyContinue)) {
            $null = Invoke-Cambio 'Cerrar Edge para que aplique las directivas' {
                Get-Process -Name msedge -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction Stop
            }
        }
        Write-Info 'Comprueba en edge://policy que las directivas aparecen como "Correcto".'
    }
}
