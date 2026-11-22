# 04 - Explorador de archivos, barra de tareas y menu Inicio.
# - Ajustes de usuario: todos los perfiles + Default.
# - Ajustes de equipo (directivas HKLM): una sola vez.
# - Anclar/desanclar carpetas: solo el usuario que ejecuta (Windows no lo permite para otros perfiles).

@{
    Clave  = 'Explorador'
    Nombre = 'Explorador, barra de tareas e Inicio'
    Aplicar = {
        param($Cfg, $Ctx)

        # ---------- Ajustes de usuario ----------
        Invoke-EnPerfiles {
            param($P)
            $adv = "$($P.HKCU)\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
            $ok = $true
            if ($Cfg.MostrarOcultos)         { $ok = (Set-RegValor -Ruta $adv -Nombre 'Hidden' -Valor 1) -and $ok }
            if ($Cfg.MostrarExtensiones)     { $ok = (Set-RegValor -Ruta $adv -Nombre 'HideFileExt' -Valor 0) -and $ok }
            if ($Cfg.MostrarArchivosSistema) { $ok = (Set-RegValor -Ruta $adv -Nombre 'ShowSuperHidden' -Valor 1) -and $ok }
            if ($Cfg.AbrirEnEsteEquipo)      { $ok = (Set-RegValor -Ruta $adv -Nombre 'LaunchTo' -Valor 1) -and $ok }
            if ($Cfg.VistaCompacta)          { $ok = (Set-RegValor -Ruta $adv -Nombre 'UseCompactMode' -Valor 1) -and $ok }
            if ($Cfg.SegundosEnReloj)        { $ok = (Set-RegValor -Ruta $adv -Nombre 'ShowSecondsInSystemClock' -Valor 1) -and $ok }
            if ($Cfg.RutaCompletaEnTitulo) {
                $ok = (Set-RegValor -Ruta "$($P.HKCU)\Software\Microsoft\Windows\CurrentVersion\Explorer\CabinetState" -Nombre 'FullPath' -Valor 1) -and $ok
            }
            if ($Cfg.OcultarSpotlightEscritorio) {
                $ok = (Set-RegValor -Ruta $adv -Nombre 'ShowSpotlightDesktop' -Valor 0 -FalloComoAviso) -and $ok
                $ok = (Set-RegValor -Ruta "$($P.HKCU)\Software\Microsoft\Windows\CurrentVersion\Explorer\HideDesktopIcons\NewStartPanel" `
                    -Nombre '{2cc5ca98-6485-489a-920e-b3e88a6ccce3}' -Valor 1) -and $ok
            }
            # Windows 11 24H2+ protege algunas de estas claves: si fallan se avisa y se continua.
            if ($Cfg.IconosCentrados)      { $null = Set-RegValor -Ruta $adv -Nombre 'TaskbarAl' -Valor 1 -FalloComoAviso }
            if ($Cfg.OcultarBotonWidgets)  { $null = Set-RegValor -Ruta $adv -Nombre 'TaskbarDa' -Valor 0 -FalloComoAviso }
            if ($Cfg.OcultarBotonChat)     { $null = Set-RegValor -Ruta $adv -Nombre 'TaskbarMn' -Valor 0 -FalloComoAviso }
            if ($Cfg.FinalizarTareaEnBarra) {
                $null = Set-RegValor -Ruta "$adv\TaskbarDeveloperSettings" -Nombre 'TaskbarEndTask' -Valor 1 -FalloComoAviso
            }
            if ($Cfg.OcultarBusquedaBarra) {
                $null = Set-RegValor -Ruta "$($P.HKCU)\Software\Microsoft\Windows\CurrentVersion\Search" -Nombre 'SearchboxTaskbarMode' -Valor 0 -FalloComoAviso
            }
            if ($Cfg.OcultarOneDriveNavegacion) {
                $onedrive = 'CLSID\{018D5C66-4533-4307-9B53-224DE2ED1FE6}'
                if ($P.Clases) {
                    $ok = (Set-RegValor -Ruta "$($P.Clases)\$onedrive" -Nombre 'System.IsPinnedToNamespaceTree' -Valor 0) -and $ok
                } else {
                    $ok = (Set-RunOnce $P.HKCU 'WMUD_OneDrive' "reg.exe add `"HKCU\Software\Classes\$onedrive`" /v System.IsPinnedToNamespaceTree /t REG_DWORD /d 0 /f") -and $ok
                }
            }
            if ($ok -and -not (Test-Simulacion)) { Write-Ok "Explorador y barra de tareas: $($P.Nombre)" }
        }

        # ---------- Directivas de equipo ----------
        if ($Cfg.DeshabilitarWidgets) {
            if (Set-RegValor -Ruta 'HKLM:\SOFTWARE\Policies\Microsoft\Dsh' -Nombre 'AllowNewsAndInterests' -Valor 0) {
                if (-not (Test-Simulacion)) { Write-Ok 'Widgets deshabilitados (directiva)' }
            }
        }
        if ($Cfg.OcultarSpotlightEscritorio) {
            $null = Set-RegValor -Ruta 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent' -Nombre 'DisableWindowsSpotlightOnDesktop' -Valor 1
        }
        if ($Cfg.QuitarRecomendadosInicio) {
            if (Set-RegValor -Ruta 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer' -Nombre 'HideRecommendedSection' -Valor 1) {
                if (-not (Test-Simulacion)) { Write-Ok 'Seccion Recomendados del menu Inicio oculta (directiva)' }
            }
        }

        # ---------- Anclados (solo usuario actual) ----------
        $carpetas = @($Cfg.DesanclarCarpetas | Where-Object { $_ })
        if ($carpetas.Count -gt 0 -or $Cfg.DesanclarGaleria) {
            $rutas = @($carpetas | ForEach-Object { [Environment]::GetFolderPath($_) })
            $null = Invoke-Cambio "Desanclar de Inicio ($env:USERNAME): $($carpetas -join ', ')" {
                $shell = New-Object -ComObject Shell.Application
                $inicio = $shell.Namespace('shell:::{679f85cb-0220-4080-b29b-5540cc05aab6}')
                if (-not $inicio) { throw 'No se pudo abrir el panel Inicio del Explorador' }
                foreach ($item in @($inicio.Items())) {
                    $esCarpeta = $item.IsFolder -and ($rutas -contains $item.Path)
                    $esGaleria = $Cfg.DesanclarGaleria -and $item.IsFolder -and ($item.Name -in @('Galería', 'Galeria', 'Gallery'))
                    if ($esCarpeta -or $esGaleria) { $item.InvokeVerb('unpinfromhome') }
                }
            } -FalloComoAviso
        }
        if ($Cfg.AnclarCarpetaPersonal) {
            $null = Invoke-Cambio "Anclar carpeta personal ($env:USERNAME)" {
                $shell = New-Object -ComObject Shell.Application
                $shell.Namespace([Environment]::GetFolderPath('UserProfile')).Self.InvokeVerb('pintohome')
            } -FalloComoAviso
        }
    }
}
