# 05 - Plan de energia y rendimiento (equivale al 07 de la v1).
# Corrige la v1: si el plan Alto Rendimiento no existe se crea CON EL MISMO GUID,
# de modo que los ajustes y la activacion posteriores funcionan.

@{
    Clave  = 'Energia'
    Nombre = 'Energia y rendimiento'
    Aplicar = {
        param($Cfg, $Ctx)
        $plan      = '8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c'   # Alto Rendimiento
        $subUSB    = '2a737441-1930-4402-8d77-b2bebba308a3'
        $usbSusp   = '48e6b7a6-50f5-4782-a5d4-53bb8f07e226'
        $subDisco  = '0012ee47-9041-4b5d-9b77-535fba8b1442'
        $discoOff  = '6738e2c4-e8a5-4a42-b16a-e040e769756e'

        function Invoke-Powercfg([string[]]$Argumentos) {
            $salida = & powercfg.exe @Argumentos 2>&1
            if ($LASTEXITCODE -ne 0) { throw "powercfg $($Argumentos -join ' '): $salida" }
        }

        if ($Cfg.PlanAltoRendimiento) {
            $existe = (& powercfg.exe /list) -match $plan
            if (-not $existe) {
                $null = Invoke-Cambio 'Crear plan Alto Rendimiento (oculto por el fabricante)' {
                    Invoke-Powercfg @('/duplicatescheme', $plan, $plan)
                }
            }
            if ($Cfg.SinSuspensionUSB) {
                $null = Invoke-Cambio 'Suspension selectiva de USB desactivada' {
                    Invoke-Powercfg @('/setacvalueindex', $plan, $subUSB, $usbSusp, '0')
                    Invoke-Powercfg @('/setdcvalueindex', $plan, $subUSB, $usbSusp, '0')
                }
            }
            if ($Cfg.DiscoNuncaApagar) {
                $null = Invoke-Cambio 'Disco: nunca apagar por inactividad' {
                    Invoke-Powercfg @('/setacvalueindex', $plan, $subDisco, $discoOff, '0')
                    Invoke-Powercfg @('/setdcvalueindex', $plan, $subDisco, $discoOff, '0')
                }
            }
            $null = Invoke-Cambio 'Plan de energia activo: Alto Rendimiento' {
                Invoke-Powercfg @('/setactive', $plan)
            }
        }

        if ($Cfg.SinPowerThrottling) {
            if (Set-RegValor -Ruta 'HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerThrottling' -Nombre 'PowerThrottlingOff' -Valor 1) {
                if (-not (Test-Simulacion)) { Write-Ok 'Power Throttling desactivado' }
            }
        }

        if ($Cfg.EfectosVisualesRendimiento -or $Cfg.SinGameModeNiGameDVR) {
            Invoke-EnPerfiles {
                param($P)
                $ok = $true
                if ($Cfg.EfectosVisualesRendimiento) {
                    $ok = (Set-RegValor -Ruta "$($P.HKCU)\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" -Nombre 'VisualFXSetting' -Valor 2) -and $ok
                }
                if ($Cfg.SinGameModeNiGameDVR) {
                    $ok = (Set-RegValor -Ruta "$($P.HKCU)\Software\Microsoft\GameBar" -Nombre 'AutoGameModeEnabled' -Valor 0) -and $ok
                    $ok = (Set-RegValor -Ruta "$($P.HKCU)\Software\Microsoft\GameBar" -Nombre 'AllowAutoGameMode' -Valor 0) -and $ok
                    $ok = (Set-RegValor -Ruta "$($P.HKCU)\System\GameConfigStore" -Nombre 'GameDVR_Enabled' -Valor 0) -and $ok
                }
                if ($ok -and -not (Test-Simulacion)) { Write-Ok "Efectos visuales / Game DVR: $($P.Nombre)" }
            }
        }

        if ($Cfg.SinHibernacion) {
            $null = Invoke-Cambio 'Hibernacion desactivada (hiberfil.sys eliminado)' {
                Invoke-Powercfg @('/hibernate', 'off')
            }
        }
    }
}
